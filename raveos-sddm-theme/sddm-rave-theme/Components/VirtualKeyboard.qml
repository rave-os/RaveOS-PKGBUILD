import QtQuick 2.15
import QtQuick.VirtualKeyboard
import QtQuick.VirtualKeyboard.Settings

InputPanel {
    id: virtualKeyboard
    
    property bool activated: false
    visible: true

    Component.onCompleted: {
        VirtualKeyboardSettings.activeLocales = ["en_US", "hu_HU"]
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {} // Consume clicks so they don't fall through to the background and steal focus
    }
}
