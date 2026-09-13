#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

migration="$ROOT/migrations/1786380259.sh"
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/bin" "$test_dir/omarchy-install/helpers"

# The migration picks sudo vs run0 by sourcing distro-secureblue.sh and calling
# is_secureblue(). This fake stands in for the real one so the scenarios below
# can force that answer deterministically, regardless of what OS the test
# itself happens to run on (this file runs unmodified on a real secureblue
# machine too, where the real is_secureblue() would otherwise always win).
cat >"$test_dir/omarchy-install/helpers/distro-secureblue.sh" <<'SH'
is_secureblue() { [[ ${TEST_IS_SECUREBLUE:-0} == 1 ]]; }
is_ostree() { [[ ${TEST_IS_SECUREBLUE:-0} == 1 ]]; }
SH

# sudo runs the real command, so sed acts on the redirected main.conf below and
# the elevated power calls land in the stub beside it.
cat >"$test_dir/bin/sudo" <<'STUB'
#!/bin/bash

printf 'sudo %s\n' "$*" >>"$CALLS"
exec "$@"
STUB

cat >"$test_dir/bin/run0" <<'STUB'
#!/bin/bash

printf 'run0 %s\n' "$*" >>"$CALLS"
exec "$@"
STUB

cat >"$test_dir/bin/omarchy-bluetooth-power" <<'STUB'
#!/bin/bash

printf 'omarchy-bluetooth-power %s\n' "$*" >>"$CALLS"
[[ $1 == "is-on" ]] || exit 0
[[ ${POWERED:-} == "yes" ]]
STUB

chmod +x "$test_dir/bin/"*

export CALLS="$test_dir/calls"

marker="$test_dir/marker"
main_conf="$test_dir/main.conf"

reset_machine() {
  rm -f "$marker"
  printf '[Policy]\nAutoEnable=false\n' >"$main_conf"
}

run_migration() {
  : >"$CALLS"

  OMARCHY_BLUETOOTH_MIGRATION_MARKER="$marker" \
    OMARCHY_BLUETOOTH_MAIN_CONF="$main_conf" \
    OMARCHY_INSTALL="$test_dir/omarchy-install" \
    TEST_IS_SECUREBLUE="$esc_is_secureblue" \
    PATH="$test_dir/bin:$PATH" \
    bash -euo pipefail "$migration" >/dev/null
}

# Every scenario below runs twice: once as a plain sudo-capable Fedora/Arch
# machine, once as secureblue (which has no sudo, only run0). Both are real
# escalation paths this migration takes depending on the host, not just
# whichever one this test happens to run on.
for esc in sudo run0; do
  if [[ $esc == run0 ]]; then esc_is_secureblue=1; else esc_is_secureblue=0; fi

  # An adapter that is powered right now is one the user turned on, so it stays on.
  reset_machine
  POWERED=yes run_migration

  grep -qx "$esc omarchy-bluetooth-power on" "$CALLS" ||
    fail "[$esc] migration keeps a powered adapter on" "$(cat "$CALLS")"
  pass "[$esc] migration keeps a powered adapter on"

  grep -qx '#AutoEnable=true' "$main_conf" ||
    fail "[$esc] migration puts AutoEnable back to its default" "$(cat "$main_conf")"
  pass "[$esc] migration puts AutoEnable back to its default"

  [[ -e $marker ]] || fail "[$esc] migration records the machine as done"
  pass "[$esc] migration records the machine as done"

  # Anything else is a machine that has been booting with Bluetooth off, and the
  # block is what carries that over now AutoEnable no longer holds the adapter down.
  reset_machine
  POWERED=no run_migration

  grep -qx "$esc omarchy-bluetooth-power off" "$CALLS" ||
    fail "[$esc] migration carries an unpowered adapter over to the block" "$(cat "$CALLS")"
  pass "[$esc] migration carries an unpowered adapter over to the block"

  # No daemon to ask reads the same way: off is what the machine has been doing.
  reset_machine
  run_migration

  grep -qx "$esc omarchy-bluetooth-power off" "$CALLS" ||
    fail "[$esc] migration blocks when no adapter can be read" "$(cat "$CALLS")"
  pass "[$esc] migration blocks when no adapter can be read"

  # /dev/rfkill is only writable unelevated from an active graphical seat, so an
  # update run over SSH would abort here and abort again on every retry.
  grep -qx "$esc omarchy-bluetooth-power off" "$CALLS" ||
    fail "[$esc] migration changes the radio through $esc" "$(cat "$CALLS")"
  pass "[$esc] migration changes the radio through $esc"

  # A second account must not undo an administrator's later choice, since migration
  # completion is recorded per user.
  printf '[Policy]\nAutoEnable=false\n' >"$main_conf"
  POWERED=yes run_migration

  grep -qx 'AutoEnable=false' "$main_conf" ||
    fail "[$esc] migration leaves a later opt-out alone" "$(cat "$main_conf")"
  pass "[$esc] migration leaves a later opt-out alone"

  [[ ! -s $CALLS ]] ||
    fail "[$esc] migration touches no radio state on a second run" "$(cat "$CALLS")"
  pass "[$esc] migration touches no radio state on a second run"

  # Only the exact line Omarchy wrote is reverted, so a hand-edited opt-out stands.
  reset_machine
  printf '[Policy]\nAutoEnable = false\n' >"$main_conf"
  POWERED=yes run_migration

  grep -qx 'AutoEnable = false' "$main_conf" ||
    fail "[$esc] migration keeps a hand-edited AutoEnable" "$(cat "$main_conf")"
  pass "[$esc] migration keeps a hand-edited AutoEnable"
done
