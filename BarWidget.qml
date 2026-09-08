import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "gravey.omacolors"

  readonly property bool opened: panelItem ? panelItem.opened === true : false
  readonly property bool popoutSwitchClosing: panelItem ? panelItem.popoutSwitchClosing === true : false
  readonly property string currentHex: panelItem && panelItem.currentHex ? panelItem.currentHex : "#7AA2F7"
  readonly property color swatchColor: currentHex

  function open() { if (panelItem) panelItem.open() }
  function close() { if (panelItem) panelItem.close() }
  function togglePanel() { if (panelItem) panelItem.toggle() }
  function closeForPopoutSwitch() { if (panelItem) panelItem.closeForPopoutSwitch() }
  function saveHex(hex) {
    if (panelItem && typeof panelItem.importPickedHex === "function")
      panelItem.importPickedHex(hex)
  }

  property var panelItem: null

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    panelItem = target
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  readonly property real openPanelIndicatorWidth: Math.max(Style.space(10), swatch.implicitWidth)

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "gravey.omacolors"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function saveHex(hex: string): void { root.saveHex(hex) }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: false
    hasVisualContent: true
    tooltipText: root.currentHex
    fixedWidth: root.vertical ? -1 : swatch.implicitWidth + Style.space(18)
    fixedHeight: root.vertical ? swatch.implicitHeight + Style.space(8) : -1

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton) {
        if (panelItem) panelItem.copyValue(root.currentHex, "hex")
      } else {
        root.togglePanel()
      }
    }

    Rectangle {
      id: swatch
      implicitWidth: Style.bar.statusSlot
      implicitHeight: Style.bar.statusSlot
      width: Style.bar.statusSlot
      height: Style.bar.statusSlot
      anchors.centerIn: parent
      radius: Style.space(6)
      color: root.swatchColor
      border.width: 1
      border.color: Util.alpha(button.foreground, 0.35)
    }
  }
}
