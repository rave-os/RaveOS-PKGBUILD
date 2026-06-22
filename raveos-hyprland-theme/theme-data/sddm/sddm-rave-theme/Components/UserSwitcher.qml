// Config created by Keyitdev https://git.rp1.hu/gabeszm/sddm-rave-theme
// Copyright (C) 2022-2025 Keyitdev
// Distributed under the GPLv3+ License https://www.gnu.org/licenses/gpl-3.0.html

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Effects

Item {
    id: userSwitcher

    // Csak akkor látható ha több mint 1 felhasználó van
    visible: userModel.count > 1

    width:  switchBtn.implicitWidth  + root.font.pointSize * 2
    height: switchBtn.implicitHeight + root.font.pointSize * 0.6

    // Kiválasztott felhasználó indexe (kívülről beállítható)
    property int  selectedIndex: 0
    property string selectedName: {
        if (userModel.count < 1) return ""
        var n = userModel.data(userModel.index(selectedIndex, 0), Qt.UserRole + 1)
        return n ? n : ""
    }

    signal userSwitched(int idx, string name)

    // ── Segédfüggvények ───────────────────────────────────────────────────────────────────
    function isImagePath(p) {
        return p && p !== ""
    }

    function getUserIcon(idx) {
        // Qt.UserRole+4 = IconRole (ebben az SDDM verziban a Home = +3)
        var icon = userModel.data(userModel.index(idx, 0), Qt.UserRole + 4)
        return isImagePath(icon) ? icon : ""
    }

    function getUserName(idx) {
        return userModel.data(userModel.index(idx, 0), Qt.UserRole + 1) || ""
    }

    // ── Gomb (chip stílus) ────────────────────────────────────────────────────
    Rectangle {
        id: switchBtn
        anchors.centerIn: parent
        implicitWidth:  btnRow.implicitWidth  + root.font.pointSize * 1.6
        implicitHeight: btnRow.implicitHeight + root.font.pointSize * 0.7
        radius: implicitHeight / 2

        color: btnArea.pressed
               ? Qt.rgba(1, 1, 1, 0.18)
               : btnArea.containsMouse
                 ? Qt.rgba(1, 1, 1, 0.12)
                 : Qt.rgba(1, 1, 1, 0.07)
        border.color: btnArea.containsMouse
                      ? Qt.rgba(1, 1, 1, 0.45)
                      : Qt.rgba(1, 1, 1, 0.22)
        border.width: 1

        Behavior on color       { ColorAnimation { duration: 150 } }
        Behavior on border.color{ ColorAnimation { duration: 150 } }

        Row {
            id: btnRow
            anchors.centerIn: parent
            spacing: root.font.pointSize * 0.5

            // Mini avatar kör
            Rectangle {
                id: miniAvatarCircle
                width:  root.font.pointSize * 1.6
                height: root.font.pointSize * 1.6
                radius: width / 2
                clip:   true
                color:  Qt.rgba(0.10, 0.10, 0.18, 0.70)
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    id: miniPhoto
                    anchors.fill: parent
                    source: userSwitcher.getUserIcon(userSwitcher.selectedIndex)
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    visible: false
                }
                
                Item {
                    id: miniMask
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.width / 2
                        color: "black"
                    }
                }
                
                MultiEffect {
                    anchors.fill: parent
                    source: miniPhoto
                    visible: miniPhoto.status === Image.Ready && miniPhoto.source !== ""
                    maskEnabled: true
                    maskSource: miniMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }

                Image {
                    anchors.centerIn: parent
                    width:  parent.width  * 0.70
                    height: parent.height * 0.70
                    source: Qt.resolvedUrl("../Assets/User.svg")
                    fillMode: Image.PreserveAspectFit
                    visible: miniPhoto.status !== Image.Ready || miniPhoto.source === ""
                    opacity: 0.80
                }
            }

            // Felhasználónév
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text:           userSwitcher.selectedName
                color:          "#ffffff"
                font.pointSize: root.font.pointSize * 0.82
                font.family:    root.font.family
            }

            // Nyíl ikon
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text:           "⌄"
                color:          Qt.rgba(1, 1, 1, 0.70)
                font.pointSize: root.font.pointSize * 0.85
                font.family:    root.font.family
                // Csak ha több user van, akkor látszik a nyíl
                visible:        userModel.count > 1

                rotation:              popup.visible ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }
        }

        MouseArea {
            id: btnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor
            // Csak akkor nyit popup-ot ha több felhasználó van
            onClicked: if (userModel.count > 1) { popup.visible ? popup.close() : popup.open() }
        }
    }

    // ── Felhasználó-lista popup ───────────────────────────────────────────────
    Popup {
        id: popup

        parent: Overlay.overlay
        x: (parent.width  - width)  / 2
        y: (parent.height - height) / 2

        width:   root.font.pointSize * 18
        padding: root.font.pointSize * 0.6

        modal:      true
        focus:      true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale";   from: 0.92; to: 1; duration: 200; easing.type: Easing.OutCubic }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 160; easing.type: Easing.InCubic }
        }

        background: Rectangle {
            radius: config.RoundCorners !== "" ? parseInt(config.RoundCorners) : 16
            color:  config.BackgroundColor
            border.color: Qt.rgba(1, 1, 1, 0.18)
            border.width: 1
        }

        // Fejléc
        Column {
            width:   parent.width
            spacing: root.font.pointSize * 0.4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           "Felhasználó váltás"
                color:          Qt.rgba(1, 1, 1, 0.55)
                font.pointSize: root.font.pointSize * 0.75
                font.family:    root.font.family
                bottomPadding:  root.font.pointSize * 0.2
            }

            // Elválasztó vonal
            Rectangle {
                width:  parent.width
                height: 1
                color:  Qt.rgba(1, 1, 1, 0.12)
            }

            // Felhasználók listája
            ListView {
                id: userList
                width:        parent.width
                height:       Math.min(contentHeight, root.font.pointSize * 22)
                model:        userModel
                clip:         true
                spacing:      2
                boundsBehavior: Flickable.StopAtBounds

                ScrollIndicator.vertical: ScrollIndicator { }

                delegate: Rectangle {
                    id: delegateRect
                    width:  userList.width
                    height: root.font.pointSize * 4
                    radius: config.RoundCorners !== "" ? parseInt(config.RoundCorners) / 2 : 8

                    // Kiemelés: aktív felhasználó
                    property bool isActive: index === userSwitcher.selectedIndex
                    color: isActive
                           ? Qt.rgba(1, 1, 1, 0.12)
                           : delegateMouse.containsMouse
                             ? Qt.rgba(1, 1, 1, 0.07)
                             : "transparent"

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: root.font.pointSize * 0.7
                        spacing: root.font.pointSize * 0.8

                        // Avatar kör
                        Rectangle {
                            id: delegateAvatarCircle
                            width:  root.font.pointSize * 3
                            height: root.font.pointSize * 3
                            radius: width / 2
                            clip:   true
                            color:  Qt.rgba(0.12, 0.12, 0.20, 0.80)
                            anchors.verticalCenter: parent.verticalCenter

                            property string iconPath: userSwitcher.getUserIcon(index)

                            Image {
                                id: delegatePhoto
                                anchors.fill: parent
                                source:      parent.iconPath
                                fillMode:    Image.PreserveAspectCrop
                                smooth:      true
                                visible:     false
                            }
                            
                            Item {
                                id: delegateMask
                                anchors.fill: parent
                                visible: false
                                layer.enabled: true
                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.width / 2
                                    color: "black"
                                }
                            }
                            
                            MultiEffect {
                                anchors.fill: parent
                                source: delegatePhoto
                                visible: delegatePhoto.status === Image.Ready && parent.iconPath !== ""
                                maskEnabled: true
                                maskSource: delegateMask
                                maskThresholdMin: 0.5
                                maskSpreadAtMin: 1.0
                            }

                            Image {
                                anchors.centerIn: parent
                                width:   parent.width  * 0.65
                                height:  parent.height * 0.65
                                source:  Qt.resolvedUrl("../Assets/User.svg")
                                fillMode: Image.PreserveAspectFit
                                visible: delegatePhoto.status !== Image.Ready || parent.iconPath === ""
                                opacity: 0.75
                            }
                        }

                        // Felhasználónév
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text:           userSwitcher.getUserName(index)
                            color:          delegateRect.isActive ? "#ffffff" : Qt.rgba(1,1,1,0.80)
                            font.pointSize: root.font.pointSize * 0.88
                            font.family:    root.font.family
                            font.bold:      delegateRect.isActive
                        }
                    }

                    // Aktív jelző csík a bal oldalon
                    Rectangle {
                        visible:  delegateRect.isActive
                        width:    3
                        height:   parent.height * 0.55
                        radius:   2
                        color:    Qt.rgba(74/255, 222/255, 128/255, 0.90)
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left:           parent.left
                        anchors.leftMargin:     2
                    }

                    MouseArea {
                        id: delegateMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked: {
                            userSwitcher.selectedIndex = index
                            userSwitcher.userSwitched(index, userSwitcher.getUserName(index))
                            popup.close()
                        }
                    }
                }
            }
        }
    }
}
