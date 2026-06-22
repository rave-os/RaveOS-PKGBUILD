// Config created by Keyitdev https://git.rp1.hu/gabeszm/sddm-rave-theme
// Copyright (C) 2022-2025 Keyitdev
// Distributed under the GPLv3+ License https://www.gnu.org/licenses/gpl-3.0.html

import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: toastRoot

    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    width: parent.width
    height: toastRect.height + root.font.pointSize * 2
    z: 100

    property string message: ""
    property bool showing: false

    function show(msg) {
        message = msg
        showing = true
        hideTimer.restart()
    }

    function hide() {
        showing = false
    }

    Rectangle {
        id: toastRect

        anchors.horizontalCenter: parent.horizontalCenter
        y: toastRoot.showing ? root.font.pointSize * 2 : -height - 10

        Behavior on y {
            NumberAnimation { duration: 380; easing.type: Easing.OutBack }
        }

        width: toastRow.implicitWidth + root.font.pointSize * 3
        height: root.font.pointSize * 3
        radius: height / 2

        color: Qt.rgba(0.75, 0.08, 0.08, 0.88)
        border.color: Qt.rgba(1, 0.35, 0.35, 0.65)
        border.width: 1

        // Pulse animation border
        SequentialAnimation on border.color {
            running: toastRoot.showing
            loops: Animation.Infinite
            ColorAnimation { to: Qt.rgba(1, 0.5, 0.5, 0.9);  duration: 600; easing.type: Easing.InOutSine }
            ColorAnimation { to: Qt.rgba(1, 0.25, 0.25, 0.5); duration: 600; easing.type: Easing.InOutSine }
        }

        Row {
            id: toastRow
            anchors.centerIn: parent
            spacing: root.font.pointSize * 0.6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "⚠"
                color: "#ff8888"
                font.pointSize: root.font.pointSize * 0.9
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: toastRoot.message
                color: "#ffffff"
                font.pointSize: root.font.pointSize * 0.85
                font.family: root.font.family
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 3000
        onTriggered: toastRoot.hide()
    }
}
