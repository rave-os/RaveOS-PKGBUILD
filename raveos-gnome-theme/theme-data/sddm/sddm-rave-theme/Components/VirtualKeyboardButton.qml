// Config created by Keyitdev https://git.rp1.hu/gabeszm/sddm-rave-theme
// Copyright (C) 2022-2025 Keyitdev
// Distributed under the GPLv3+ License https://www.gnu.org/licenses/gpl-3.0.html

import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    Button {
        id: virtualKeyboardButton

        anchors.horizontalCenter: parent.horizontalCenter
        z: 1
        focusPolicy: Qt.TabFocus

        visible: virtualKeyboard.status == Loader.Ready && config.HideVirtualKeyboard == "false"
        checkable: true
        onClicked: virtualKeyboard.switchState()
        
        Keys.onReturnPressed: {
            toggle();
            virtualKeyboard.switchState();
        }
        Keys.onEnterPressed: {
            toggle();
            virtualKeyboard.switchState();
        }

        contentItem: Text {
            id: virtualKeyboardButtonText

            text: config.TranslateVirtualKeyboardButtonOff || "Virtual Keyboard (off)"
            font.pointSize: root.font.pointSize * 0.8
            font.family: root.font.family
            color: parent.visualFocus ? config.HoverVirtualKeyboardButtonTextColor : config.VirtualKeyboardButtonTextColor
        }

        background: Rectangle {
            id: virtualKeyboardButtonBackground

            anchors.fill: parent
            radius: config.RoundCorners !== "" ? parseInt(config.RoundCorners) : 10
            color: virtualKeyboardButton.down ? Qt.rgba(1, 1, 1, 0.12) : (virtualKeyboardButton.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
            border.color: virtualKeyboardButton.visualFocus ? Qt.rgba(1, 1, 1, 0.60) : (virtualKeyboardButton.hovered ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.18))
            border.width: virtualKeyboardButton.visualFocus ? 1.5 : 1

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }
        }
        states: [
            State {
                name: "HoveredAndChecked"
                when: virtualKeyboardButton.checked && virtualKeyboardButton.hovered
                PropertyChanges {
                    target: virtualKeyboardButtonText
                    text: config.TranslateVirtualKeyboardButtonOn || "Virtual Keyboard (on)"
                    color: config.HoverVirtualKeyboardButtonTextColor
                }
            },
            State {
                name: "checked"
                when: virtualKeyboardButton.checked
                PropertyChanges {
                    target: virtualKeyboardButtonText
                    text: config.TranslateVirtualKeyboardButtonOn || "Virtual Keyboard (on)"
                }
            },
            State {
                name: "hovered"
                when: virtualKeyboardButton.hovered
                PropertyChanges {
                    target: virtualKeyboardButtonText
                    text: config.TranslateVirtualKeyboardButtonOff || "Virtual Keyboard (off)"
                    color: config.HoverVirtualKeyboardButtonTextColor
                }
            }
        ]
    }
}