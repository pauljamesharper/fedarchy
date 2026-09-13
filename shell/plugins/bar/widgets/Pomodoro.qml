import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// GNOME Pomodoro status/control pill. Talks to org.gnome.Pomodoro directly
// over gdbus (Quickshell has no built-in binding for it, unlike UPower/Mpris/
// Pipewire): one GetAll call to seed state, then a standing `gdbus monitor`
// whose PropertiesChanged lines are parsed for State/Elapsed/StateDuration/
// IsPaused. gnome-pomodoro emits Elapsed once a second while running, so this
// widget just renders on each signal rather than keeping its own tick timer.
BarWidget {
  id: root
  moduleName: "omarchy.pomodoro"

  property string state: "null"
  property real elapsed: 0
  property real stateDuration: 0
  property bool isPaused: false

  readonly property bool idle: state === "null"
  readonly property bool onBreak: state === "short-break" || state === "long-break"
  readonly property real remaining: Math.max(0, stateDuration - elapsed)

  function formatRemaining(seconds) {
    var total = Math.max(0, Math.round(seconds))
    var m = Math.floor(total / 60)
    var s = total % 60
    return m + ":" + (s < 10 ? "0" + s : String(s))
  }

  // Nerd Font "md-timer" glyph (U+F13AB) instead of the tomato emoji: emoji
  // render from the system color-emoji font regardless of Text.color, which
  // is why it never matched the rest of the bar's themed, monochrome icons.
  readonly property string timerGlyph: "󱎫"
  readonly property string displayText: idle ? timerGlyph : (timerGlyph + " " + formatRemaining(remaining))

  // Only overwrite properties this line actually reports — PropertiesChanged
  // carries just the keys that changed, and GetAll's reply carries all of
  // them in the same shape, so one parser serves both.
  function applyProperties(line) {
    var m
    m = line.match(/'State':\s*<'([^']*)'>/); if (m) root.state = m[1]
    m = line.match(/'Elapsed':\s*<([-0-9.eE]+)>/); if (m) root.elapsed = parseFloat(m[1])
    m = line.match(/'StateDuration':\s*<([-0-9.eE]+)>/); if (m) root.stateDuration = parseFloat(m[1])
    m = line.match(/'IsPaused':\s*<(true|false)>/); if (m) root.isPaused = m[1] === "true"
  }

  function call(method) {
    callProc.command = ["gdbus", "call", "--session", "--dest", "org.gnome.Pomodoro",
      "--object-path", "/org/gnome/Pomodoro", "--method", "org.gnome.Pomodoro." + method]
    callProc.running = true
  }

  function refresh() {
    if (!getAllProc.running) getAllProc.running = true
  }

  function start() { call("Start") }
  function pause() { call("Pause") }
  function resume() { call("Resume") }
  function skip() { call("Skip") }
  function reset() { call("Reset") }

  function toggle() {
    if (idle) start()
    else if (isPaused) resume()
    else pause()
  }

  // Relaunching the already-running --no-default-window instance just
  // activates it, which raises its main window.
  function showMainWindow() {
    showProc.running = true
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: {
    root.refresh()
    monitorProc.running = true
  }

  Process {
    id: getAllProc
    command: ["gdbus", "call", "--session", "--dest", "org.gnome.Pomodoro",
      "--object-path", "/org/gnome/Pomodoro", "--method",
      "org.freedesktop.DBus.Properties.GetAll", "org.gnome.Pomodoro"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyProperties(text)
    }
  }

  Process { id: callProc }
  Process { id: showProc; command: ["gnome-pomodoro"] }

  Process {
    id: monitorProc
    command: ["gdbus", "monitor", "--session", "--dest", "org.gnome.Pomodoro",
      "--object-path", "/org/gnome/Pomodoro"]
    stdout: SplitParser {
      onRead: function(line) {
        if (line.indexOf("PropertiesChanged") === -1) return
        root.applyProperties(line)
      }
    }
  }

  IpcHandler {
    target: "omarchy.pomodoro"

    function refresh(): void { root.refresh() }
    function start(): void { root.start() }
    function pause(): void { root.pause() }
    function resume(): void { root.resume() }
    function skip(): void { root.skip() }
    function reset(): void { root.reset() }
    function toggle(): void { root.toggle() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.displayText
    active: !root.idle && !root.onBreak
    dimmed: root.isPaused
    tooltipText: root.idle
      ? "Start Pomodoro"
      : (root.isPaused ? "Paused — click to resume" : (root.onBreak ? "On break" : "Pomodoro running"))

    onPressed: function(b) {
      if (b === Qt.RightButton) root.skip()
      else if (b === Qt.MiddleButton) root.showMainWindow()
      else root.toggle()
    }
  }
}
