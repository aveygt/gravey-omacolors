import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "ColorModel.js" as ColorModel

Panel {
  id: root
  moduleName: "gravey.omacolors"
  ipcTarget: "gravey.omacolors"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color hoverFill: bar
    ? Style.hoverFillFor(bar.foreground, Color.accent)
    : "transparent"
  readonly property color fieldFill: Util.alpha(contentForeground, 0.08)
  readonly property int panelWidth: Style.space(460)
  readonly property int historySize: 8
  readonly property int historySlot: Style.space(24)
  readonly property int fieldHeight: Style.space(34)

  property string palettePath: Quickshell.env("HOME") + "/.local/state/omarchy/omacolors-palette.json"
  property real hue: 210
  property real saturation: 0.52
  property real value: 0.97
  property var history: ColorModel.emptyHistory()
  property string copiedKey: ""
  property bool loaded: false
  property bool persistScheduled: false
  property bool picking: false
  property bool reopenAfterPick: false
  property bool pickHandled: false

  readonly property string currentHex: ColorModel.hexFromHsv(hue, saturation, value)
  readonly property var formatRows: ColorModel.formatRows(currentHex)
  readonly property color currentColor: currentHex
  readonly property string tooltipLabel: currentHex

  function open() {
    root.controller.show()
    Qt.callLater(function() {
      if (root.opened && keyCatcher) keyCatcher.forceActiveFocus()
    })
  }

  function openFromHotkey() {
    root.open()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function applyHsv(nextHue, nextSat, nextValue) {
    root.hue = nextHue
    root.saturation = nextSat
    root.value = nextValue
    root.schedulePersist()
  }

  function applyHex(hex) {
    var normalized = ColorModel.extractHex(hex)
    if (!normalized) return false
    var hsv = ColorModel.hsvFromHex(normalized)
    root.applyHsv(hsv.h, hsv.s, hsv.v)
    return true
  }

  function applyPickedHex(raw) {
    var normalized = ColorModel.extractHex(raw)
    if (!normalized) return false
    var hsv = ColorModel.hsvFromHex(normalized)
    root.hue = hsv.h
    root.saturation = hsv.s
    root.value = hsv.v
    root.history = ColorModel.saveToHistory(root.history, normalized)
    root.copiedKey = "save"
    copiedClear.restart()
    if (root.loaded) {
      root.persistScheduled = true
      root.persistState()
    }
    return true
  }

  function importPickedHex(raw) {
    return root.applyPickedHex(raw)
  }

  function copyValue(value, key) {
    if (!value) return
    Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(value) + " | wl-copy"])
    root.copiedKey = key || ""
    copiedClear.restart()
  }

  function confirmHex() {
    root.copyValue(ColorModel.formatsForHex(root.currentHex).hexLower, "hex")
    root.close()
  }

  function activateHistory(index) {
    var hex = ColorModel.normalizeHex(root.history[index])
    if (hex) root.applyHex(hex)
    else root.saveHistory(index)
  }

  function saveHistory(index) {
    root.history = ColorModel.setHistorySlot(root.history, index, root.currentHex)
    root.schedulePersist()
  }

  function saveCurrentToHistory() {
    root.history = ColorModel.saveToHistory(root.history, root.currentHex)
    root.copiedKey = "save"
    copiedClear.restart()
    root.schedulePersist()
  }

  function clearHistory(index) {
    root.history = ColorModel.setHistorySlot(root.history, index, "")
    root.schedulePersist()
  }

  function startEyedropper() {
    if (root.picking || pickerProc.running || pasteProc.running) return
    root.picking = true
    root.pickHandled = false
    root.reopenAfterPick = true
    root.close()
    pickerStart.restart()
  }

  function finishPick(raw) {
    if (root.pickHandled) return true
    if (root.applyPickedHex(raw)) {
      root.pickHandled = true
      return true
    }
    return false
  }

  function endPick() {
    root.picking = false
    if (root.reopenAfterPick) {
      root.reopenAfterPick = false
      root.open()
    }
  }

  function loadState(raw) {
    var state = ColorModel.parseState(raw)
    root.history = state.history
    var hsv = ColorModel.hsvFromHex(state.current)
    root.hue = hsv.h
    root.saturation = hsv.s
    root.value = hsv.v
    root.loaded = true
  }

  function schedulePersist() {
    if (!root.loaded) return
    root.persistScheduled = true
    persistTimer.restart()
  }

  function persistState() {
    if (!root.loaded) return
    paletteFile.setText(JSON.stringify({
      current: root.currentHex,
      history: root.history
    }, null, 2) + "\n")
    root.persistScheduled = false
  }

  function fieldFor(key) {
    for (var i = 0; i < root.formatRows.length; i++) {
      if (root.formatRows[i].key === key) return root.formatRows[i]
    }
    return { key: key, label: key, value: "", display: "" }
  }

  FileView {
    id: paletteFile
    path: root.palettePath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: {
      if (root.persistScheduled || root.picking) return
      root.loadState(text())
    }
    onLoadFailed: {
      if (!root.loaded) root.loadState("{}")
    }
    onFileChanged: reload()
  }

  Timer {
    id: persistTimer
    interval: 180
    repeat: false
    onTriggered: root.persistState()
  }

  Timer {
    id: copiedClear
    interval: 1200
    repeat: false
    onTriggered: root.copiedKey = ""
  }

  Timer {
    id: pickerStart
    interval: 120
    repeat: false
    onTriggered: {
      pickerProc.command = ["hyprpicker", "-a", "-f", "hex", "-b", "-q"]
      pickerProc.running = true
    }
  }

  Process {
    id: pickerProc
    running: false
    stdout: StdioCollector {
      id: pickerOut
      waitForEnd: true
      onStreamFinished: root.finishPick(text)
    }
    stderr: StdioCollector {
      id: pickerErr
      waitForEnd: true
    }
    onExited: {
      if (root.finishPick(pickerOut.text) || root.finishPick(pickerErr.text)) {
        root.endPick()
        return
      }
      pasteProc.command = ["wl-paste", "-n"]
      pasteProc.running = true
    }
  }

  Process {
    id: pasteProc
    running: false
    stdout: StdioCollector {
      id: pasteOut
      waitForEnd: true
      onStreamFinished: root.finishPick(text)
    }
    onExited: {
      root.finishPick(pasteOut.text)
      root.endPick()
    }
  }

  component ValueField: Column {
    property var field: ({ key: "", label: "", value: "", display: "" })
    width: parent ? (parent.width - Style.space(16)) / 3 : Style.space(120)
    spacing: Style.space(5)

    Text {
      textFormat: Text.PlainText
      text: root.copiedKey === field.key ? "COPIED" : field.label
      color: root.copiedKey === field.key ? Color.accent : Util.alpha(root.contentForeground, 0.55)
      font.family: root.contentFontFamily
      font.pixelSize: Style.font.caption
      font.weight: Font.DemiBold
    }

    Rectangle {
      width: parent.width
      height: root.fieldHeight
      radius: height / 2
      color: fieldMouse.containsMouse ? root.hoverFill : root.fieldFill

      Text {
        anchors.fill: parent
        anchors.leftMargin: Style.space(12)
        anchors.rightMargin: Style.space(12)
        verticalAlignment: Text.AlignVCenter
        textFormat: Text.PlainText
        text: field.display
        color: root.contentForeground
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      MouseArea {
        id: fieldMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.copyValue(field.value, field.key)
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(root.panelWidth)
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onActivateRequested: root.confirmHex()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "e" || t === "E") root.startEyedropper()
        else if (t === "s" || t === "S") root.saveCurrentToHistory()
        else if ("12345678".indexOf(t) >= 0)
          root.activateHistory(Number(t) - 1)
      }

      Column {
        id: panelColumn
        width: parent.width
        spacing: Style.space(16)

        Row {
          width: parent.width
          spacing: Style.space(12)

          Column {
            id: mainColumn
            width: parent.width - root.historySlot - Style.space(12)
            spacing: Style.space(16)

            Item {
              width: parent.width
              height: picker.implicitHeight

              Wheel {
                id: picker
                width: parent.width
                hue: root.hue
                saturation: root.saturation
                value: root.value
                ringColor: root.contentForeground
                onHsvEdited: function(nextHue, nextSat, nextValue) {
                  root.applyHsv(nextHue, nextSat, nextValue)
                }
              }

              Rectangle {
                width: Style.space(28)
                height: Style.space(28)
                radius: width / 2
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.leftMargin: Style.space(10)
                anchors.topMargin: Style.space(10)
                color: dropperMouse.containsMouse ? root.hoverFill : Util.alpha(Color.background, 0.55)
                border.width: 1
                border.color: Util.alpha(root.contentForeground, 0.22)

                OpticalGlyph {
                  anchors.centerIn: parent
                  width: Style.space(16)
                  height: Style.space(16)
                  text: "󰈊"
                  fontFamily: root.contentFontFamily
                  fontSize: Style.font.body
                  color: root.value > 0.55 ? "#1A1B26" : "#FFFFFF"
                }

                MouseArea {
                  id: dropperMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.startEyedropper()
                }
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(10)

              Row {
                width: parent.width
                spacing: Style.space(8)
                ValueField { field: root.fieldFor("hex") }
                ValueField { field: root.fieldFor("rgb") }
                ValueField { field: root.fieldFor("cmyk") }
              }

              Row {
                width: parent.width
                spacing: Style.space(8)
                ValueField { field: root.fieldFor("hsv") }
                ValueField { field: root.fieldFor("hsl") }

                Column {
                  width: parent.width ? (parent.width - Style.space(16)) / 3 : Style.space(120)
                  spacing: Style.space(5)

                  Text {
                    textFormat: Text.PlainText
                    text: root.copiedKey === "save" ? "SAVED" : "SAVE"
                    color: root.copiedKey === "save" ? Color.accent : Util.alpha(root.contentForeground, 0.55)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.weight: Font.DemiBold
                  }

                  Rectangle {
                    width: parent.width
                    height: root.fieldHeight
                    radius: height / 2
                    color: saveMouse.containsMouse ? root.hoverFill : root.fieldFill

                    Text {
                      anchors.centerIn: parent
                      textFormat: Text.PlainText
                      text: root.copiedKey === "save" ? "Saved" : "Save"
                      color: root.contentForeground
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.body
                      font.weight: Font.DemiBold
                    }

                    MouseArea {
                      id: saveMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.saveCurrentToHistory()
                    }
                  }
                }
              }
            }
          }

          Item {
            width: root.historySlot
            height: mainColumn.implicitHeight

            Repeater {
              model: root.historySize

              delegate: Item {
                required property int index
                readonly property string slotHex: ColorModel.normalizeHex(root.history[index] || "")
                readonly property bool filled: slotHex !== ""
                readonly property real slotStep: root.historySize > 1
                  ? (parent.height - root.historySlot) / (root.historySize - 1)
                  : 0
                width: root.historySlot
                height: root.historySlot
                y: index * slotStep

                Rectangle {
                  anchors.fill: parent
                  radius: width / 2
                  color: filled ? slotHex : Util.alpha(root.contentForeground, 0.08)
                  border.width: filled && slotHex === root.currentHex ? 2 : 1
                  border.color: filled && slotHex === root.currentHex
                    ? Color.accent
                    : Util.alpha(root.contentForeground, filled ? 0.28 : 0.22)
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  acceptedButtons: Qt.LeftButton | Qt.RightButton
                  cursorShape: Qt.PointingHandCursor
                  onClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton) root.clearHistory(index)
                    else root.activateHistory(index)
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
