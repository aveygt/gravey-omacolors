import QtQuick
import qs.Commons
import "ColorModel.js" as ColorModel

Item {
  id: root

  property real hue: 210
  property real saturation: 0.52
  property real value: 0.97
  property color ringColor: Color.foreground
  property int pickerHeight: Style.space(148)
  property int hueBarHeight: Style.space(16)
  property int gap: Style.space(14)
  property real previewRatio: 0.34

  readonly property color hueColor: ColorModel.hexFromHsv(hue, 1, 1)
  readonly property color currentColor: ColorModel.hexFromHsv(hue, saturation, value)
  readonly property int handleSize: Style.space(16)
  readonly property var svPoint: ColorModel.pointerFromSv(saturation, value, svField.width, svField.height)

  signal hsvEdited(real hue, real saturation, real value)

  implicitWidth: Style.space(320)
  implicitHeight: pickerHeight + gap + hueBarHeight + Style.space(8)

  function applySv(mouseX, mouseY) {
    var sv = ColorModel.svFromPointer(mouseX, mouseY, svField.width, svField.height)
    root.hsvEdited(root.hue, sv.s, sv.v)
  }

  function applyHue(mouseX) {
    root.hsvEdited(ColorModel.hueFromPointer(mouseX, hueTrack.width), root.saturation, root.value)
  }

  Rectangle {
    id: stage
    width: parent.width
    height: root.pickerHeight
    radius: Style.space(14)
    clip: true
    color: root.currentColor

    Row {
      anchors.fill: parent

      Item {
        width: Math.round(stage.width * root.previewRatio)
        height: parent.height
      }

      Item {
        id: svField
        width: stage.width - Math.round(stage.width * root.previewRatio)
        height: parent.height

        Rectangle {
          anchors.fill: parent
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "#FFFFFF" }
            GradientStop { position: 1; color: root.hueColor }
          }
        }

        Rectangle {
          anchors.fill: parent
          gradient: Gradient {
            GradientStop { position: 0; color: "#00000000" }
            GradientStop { position: 1; color: "#FF000000" }
          }
        }

        Rectangle {
          width: root.handleSize
          height: root.handleSize
          radius: width / 2
          x: ColorModel.clamp(root.svPoint.x - width / 2, 1, svField.width - width - 1)
          y: ColorModel.clamp(root.svPoint.y - height / 2, 1, svField.height - height - 1)
          color: "transparent"
          border.width: Math.max(2, Style.space(2))
          border.color: "#FFFFFF"
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.CrossCursor
          onPressed: function(mouse) { root.applySv(mouse.x, mouse.y) }
          onPositionChanged: function(mouse) {
            if (pressed) root.applySv(mouse.x, mouse.y)
          }
        }
      }
    }
  }

  Item {
    id: hueBar
    width: parent.width
    height: root.hueBarHeight + Style.space(8)
    anchors.top: stage.bottom
    anchors.topMargin: root.gap

    Rectangle {
      id: hueTrack
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width
      height: root.hueBarHeight
      radius: height / 2
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: "#FF0000" }
        GradientStop { position: 0.17; color: "#FFFF00" }
        GradientStop { position: 0.33; color: "#00FF00" }
        GradientStop { position: 0.50; color: "#00FFFF" }
        GradientStop { position: 0.67; color: "#0000FF" }
        GradientStop { position: 0.83; color: "#FF00FF" }
        GradientStop { position: 1; color: "#FF0000" }
      }
    }

    Rectangle {
      width: root.handleSize
      height: root.handleSize
      radius: width / 2
      anchors.verticalCenter: hueTrack.verticalCenter
      x: ColorModel.clamp((root.hue / 360) * hueTrack.width - width / 2, 0, hueTrack.width - width)
      color: root.hueColor
      border.width: Math.max(2, Style.space(2))
      border.color: "#FFFFFF"
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.SizeHorCursor
      onPressed: function(mouse) { root.applyHue(mouse.x) }
      onPositionChanged: function(mouse) {
        if (pressed) root.applyHue(mouse.x)
      }
    }
  }
}
