import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

// One-click llama.cpp server switch for the bar.
//
// Polls the active state of a systemd user unit every 2s; clicking runs
// `systemctl --user start|stop <unit>` detached, so the inference server stops
// hogging the CPU/GPU the moment you sit down to a game. Everything is done
// through systemd, so the widget never touches the llama process directly and
// picks up crashes/restarts automatically.
//
// Point it at a different unit with:
//   omarchy bar set dev.thesilentbear.llama-toggle unit llama-35b.service
BarWidget {
  id: root
  moduleName: "dev.thesilentbear.llama-toggle"

  readonly property string unit: root.setting("unit", "llama-35b.service")

  // True while the unit reports "active" (loading counts as on).
  property bool active: false
  property bool probing: false

  readonly property color colMain: bar ? bar.foreground : Color.foreground
  readonly property color colDim: Qt.darker(colMain, 1.5)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function tooltip() {
    var lines = []
    lines.push("Llama server")
    lines.push("—")
    lines.push(String(root.unit))
    lines.push(root.active ? "running" : "stopped")
    lines.push("")
    lines.push(root.active ? "Click to stop (before a game)" : "Click to start")
    return lines.join("\n")
  }

  Process {
    id: probe
    command: ["systemctl", "--user", "is-active", root.unit]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.probing = false
        root.active = text.trim() === "active"
      }
    }
  }
  Timer {
    id: poll
    interval: 2000
    repeat: true
    running: true
    onTriggered: probeNow()
  }

  function probeNow() {
    if (root.probing) return
    root.probing = true
    probe.running = true
  }

  function toggle() {
    var action = root.active ? "stop" : "start"
    Quickshell.execDetached(["systemctl", "--user", action, root.unit])
    // Optimistic flip so the click feels instant; the next probe corrects it.
    root.active = !root.active
    probeDelay.restart()
  }

  Timer {
    id: probeDelay
    interval: 500
    onTriggered: probeNow()
  }

  Component.onCompleted: probeNow()

  implicitWidth: row.implicitWidth + Style.space(12)
  implicitHeight: barSize

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.space(6)

    Text {
      id: glyph
      textFormat: Text.PlainText
      anchors.verticalCenter: parent.verticalCenter
      text: "\uf544" // fa-robot
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      color: root.active ? root.colMain : root.colDim
      opacity: root.probing ? 0.6 : 1
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton

    onClicked: root.toggle()
    onEntered: if (root.bar) root.bar.showTooltip(root, root.tooltip())
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  IpcHandler {
    target: root.moduleName
    function toggle(): void { root.toggle() }
    function status(): string { return root.active ? "running" : "stopped" }
  }
}