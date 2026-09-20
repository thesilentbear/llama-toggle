import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

// Llama Server Switch — one click opens a small menu with an ON/OFF switch
// for a systemd user unit running a llama.cpp server.
//
// The bar button is a small state pill (power glyph + ON/OFF, colored from the
// installed theme); clicking it opens a Menu panel titled "Llama Server Switch"
// with a real switch. The server state is polled every 2s through systemd, so
// the widget never touches the llama process directly and picks up
// crashes/restarts automatically.
//
// Point it at a different unit with:
//   omarchy bar set dev.thesilentbear.llama-toggle unit llama-35b.service
BarWidget {
  id: root
  moduleName: "dev.thesilentbear.llama-toggle"

  readonly property string unit: root.setting("unit", "llama-35b.service")

  // True while the unit reports "active" (loading counts as running).
  property bool active: false
  property bool probing: false
  property bool popupOpen: false
  property var registeredBar: null

  readonly property color colMain: bar ? bar.foreground : Color.foreground
  readonly property color colDim: Qt.darker(colMain, 1.5)
  readonly property color colAccent: Color.accent
  readonly property color colUrgent: bar && bar.urgent ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function tooltip() {
    var lines = []
    lines.push("Llama Server Switch")
    lines.push("—")
    lines.push(String(root.unit))
    lines.push(root.active ? "running" : "stopped")
    lines.push("")
    lines.push("Click to switch it")
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

  // Flip the server (start if stopped, stop if running). Runs via systemd,
  // detached, with an optimistic state flip so the switch feels instant; the
  // next probe corrects it.
  function toggle() {
    var action = root.active ? "stop" : "start"
    Quickshell.execDetached(["systemctl", "--user", action, root.unit])
    root.active = !root.active
    probeDelay.restart()
  }

  Timer {
    id: probeDelay
    interval: 500
    onTriggered: probeNow()
  }

  Component.onCompleted: probeNow()

  function open() { root.popupOpen = true }
  function close() { root.popupOpen = false }

  // Registered as a click target like the built-in WidgetButtons, so the bar
  // paints the hand cursor over us and click targets resolve at this widget.
  function syncClickRegistration() {
    if (root.registeredBar && root.registeredBar.unregisterClickTarget) root.registeredBar.unregisterClickTarget(root)
    root.registeredBar = root.bar
    if (root.registeredBar && root.registeredBar.registerClickTarget) root.registeredBar.registerClickTarget(root)
  }

  onBarChanged: syncClickRegistration()
  Component.onDestruction: if (root.registeredBar && root.registeredBar.unregisterClickTarget) root.registeredBar.unregisterClickTarget(root)

  // Opening/closing mirrors the stock omarchy click path: the composed CLICK
  // (release) routes through triggerPress, so each click both opens and closes
  // the menu UI like every other widget.
  function triggerPress(mbutton) {
    if (root.bar) root.bar.hideTooltip(root)
    root.handlePress(mbutton)
  }
  function handlePress(mbutton) {
    if (root.popupOpen) { root.close(); return }
    root.open()
  }

  implicitWidth: row.implicitWidth + Style.space(12)
  implicitHeight: barSize

  // ── Bar button: a small pill spelling the state out ─────────────────────
  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.space(6)
    opacity: root.probing ? 0.6 : 1

    Rectangle {
      id: pill
      anchors.verticalCenter: parent.verticalCenter
      implicitWidth: pillContent.implicitWidth + pillPadding * 2
      implicitHeight: pillContent.implicitHeight + Style.space(4)
      radius: Math.round(implicitHeight / 2)
      color: root.active ? "transparent" : root.colUrgent
      border.color: root.active ? Qt.darker(root.colMain, 1.8) : root.colUrgent
      border.width: 1

      readonly property int pillPadding: Style.space(5)

      Row {
        id: pillContent
        anchors.centerIn: parent
        spacing: Style.space(4)

        Text {
          id: glyph
          textFormat: Text.PlainText
          anchors.verticalCenter: parent.verticalCenter
          text: "\uef04" // nerd-font glyph, verified present in the bar's font
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          color: root.active ? root.colAccent : root.colMain
        }

        Text {
          id: stateText
          textFormat: Text.PlainText
          anchors.verticalCenter: parent.verticalCenter
          text: root.active ? "ON" : "OFF"
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          color: root.colMain
        }
      }
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton

    onClicked: function(mouse) { root.triggerPress(mouse.button) }
    onEntered: if (root.bar) root.bar.showTooltip(root, root.tooltip())
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  // ── Menu with the ON/OFF switch ─────────────────────────────────────────
  // Layer-surface menu (like the stock clock/network panels), so the pill
  // stays clickable to close it and any outside press dismisses it.
  KeyboardPanel {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(300))
    contentHeight: popup.fittedContentHeight(column.implicitHeight, Style.space(240))

    Column {
      id: column
      width: popup.contentWidth - Style.space(20) * 2
      spacing: Style.space(10)

      Text {
        textFormat: Text.PlainText
        text: "Llama Server Switch"
        color: root.colMain
        font.family: root.fontFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
        elide: Text.ElideRight
        width: parent.width
      }

      Text {
        textFormat: Text.PlainText
        text: root.active ? "The server is running" : "The server is stopped"
        color: root.active ? root.colAccent : root.colUrgent
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        width: parent.width
      }

      Toggle {
        width: parent.width
        label: root.active ? "Server on" : "Server off"
        description: String(root.unit)
        checked: root.active
        foreground: root.colMain
        accent: root.colAccent
        fontFamily: root.fontFamily
        // The ToggleSwitch is stateless: the caller owns `checked`. Derive
        // the request from the real state (pre-click) so each click maps to
        // exactly one start/stop decision.
        onClicked: root.toggle()
      }

      Text {
        textFormat: Text.PlainText
        width: parent.width
        text: "Started through systemd, so it returns automatically on boot. Click the bar pill to close."
        color: root.colDim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
    }
  }

  IpcHandler {
    target: root.moduleName
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function status(): string { return root.active ? "running" : "stopped" }
  }
}