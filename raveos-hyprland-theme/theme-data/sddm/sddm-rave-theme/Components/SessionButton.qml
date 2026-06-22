// Config created by Keyitdev https://git.rp1.hu/gabeszm/sddm-rave-theme
// Copyright (C) 2022-2025 Keyitdev
// Based on https://github.com/MarianArlt/sddm-sugar-dark
// Distributed under the GPLv3+ License https://www.gnu.org/licenses/gpl-3.0.html

import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: sessionButton

    height: root.font.pointSize * 2
    width: parent.width / 2
    
    property var selectedSession: selectSession.currentIndex
    property string textConstantSession
    property int loginButtonWidth
    property ComboBox exposeSession: selectSession

    ComboBox {
        id: selectSession

        // important
        // change also in errorMessage
        height: root.font.pointSize * 2
        anchors.horizontalCenter: parent.horizontalCenter

        hoverEnabled: true
        model: sessionModel
        currentIndex: model.lastIndex
        textRole: "name"
        
        Keys.onPressed: function(event) {
            if ((event.key == Qt.Key_Left || event.key == Qt.Key_Right) && !popup.opened) {
                popup.open();
            }
        }

        delegate: ItemDelegate {
            // minus padding
            width: popupHandler.width - 20
            anchors.horizontalCenter: popupHandler.horizontalCenter
            
            contentItem: Text {
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter

                text: model.name
                font.pointSize: root.font.pointSize * 0.8
                font.family: root.font.family
                color: config.DropdownTextColor
            }
            
            background: Rectangle {
                color: selectSession.highlightedIndex === index ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                radius: config.RoundCorners !== "" ? parseInt(config.RoundCorners) / 4 : 5
            }
        }

        indicator {
            visible: false
        }

        contentItem: Text {
            id: displayedItem

            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            leftPadding: root.font.pointSize * 0.8
            rightPadding: root.font.pointSize * 0.8

            text: (config.TranslateSessionSelection || "Session") + ": " + selectSession.currentText
            color: config.SessionButtonTextColor
            font.pointSize: root.font.pointSize * 0.8
            font.family: root.font.family

            Keys.onReleased: parent.popup.open()
        }

        background: Rectangle {
            anchors.fill: parent
            radius: config.RoundCorners !== "" ? parseInt(config.RoundCorners) : 10
            color: selectSession.down ? Qt.rgba(1, 1, 1, 0.12) : (selectSession.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
            border.color: selectSession.visualFocus ? Qt.rgba(1, 1, 1, 0.60) : (selectSession.hovered ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.18))
            border.width: selectSession.visualFocus ? 1.5 : 1

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }
        }

        popup: Popup {
            id: popupHandler

            implicitHeight: contentItem.implicitHeight
            width: sessionButton.width
            y: parent.height - 1
            x:  -popupHandler.width/2 + displayedItem.width/2
            padding: 10

            contentItem: ListView {
                implicitHeight: contentHeight + 20

                clip: true
                model: selectSession.popup.visible ? selectSession.delegateModel : null
                currentIndex: selectSession.highlightedIndex
                ScrollIndicator.vertical: ScrollIndicator { }
            }

            background: Rectangle {
                radius: config.RoundCorners !== "" ? parseInt(config.RoundCorners) / 2 : 10
                color: config.BackgroundColor
                border.color: Qt.rgba(1, 1, 1, 0.20)
                border.width: 1
            }

            enter: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1 }
            }
        }

        states: [
            State {
                name: "pressed"
                when: selectSession.down
                PropertyChanges {
                    target: displayedItem
                    color: Qt.darker(config.HoverSessionButtonTextColor, 1.1)
                }
            },
            State {
                name: "hovered"
                when: selectSession.hovered
                PropertyChanges {
                    target: displayedItem
                    color: Qt.lighter(config.HoverSessionButtonTextColor, 1.1)
                }
            },
            State {
                name: "focused"
                when: selectSession.visualFocus
                PropertyChanges {
                    target: displayedItem
                    color: config.HoverSessionButtonTextColor
                }
            }
        ]
        transitions: [
            Transition {
                PropertyAnimation {
                    properties: "color"
                    duration: 150
                }
            }
        ]

    }

}
