// Config created by Keyitdev https://git.rp1.hu/gabeszm/sddm-rave-theme
// Copyright (C) 2022-2025 Keyitdev
// Based on https://github.com/MarianArlt/sddm-sugar-dark
// Distributed under the GPLv3+ License https://www.gnu.org/licenses/gpl-3.0.html

import QtQuick 2.15
import QtQuick.Layouts 1.15
import SddmComponents 2.0 as SDDM

ColumnLayout {
    id: formContainer
    SDDM.TextConstants { id: textConstants }

    property int p: config.ScreenPadding == "" ? 0 : config.ScreenPadding
    property string a: config.FormPosition

    spacing: 15

    Clock {
        id: clock

        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: clock.implicitHeight
        Layout.leftMargin: p != "0" ? a == "left" ? -p : a == "right" ? p : 0 : 0
    }

    // Akkumulátor + Hálózat jelzők
    RowLayout {
        id: statusRow

        Layout.alignment: Qt.AlignHCenter
        Layout.leftMargin: p != "0" ? a == "left" ? -p : a == "right" ? p : 0 : 0
        Layout.bottomMargin: visible ? 4 : 0
        visible: (batteryIndicator.batteryLevel >= 0) || networkIndicator.isConnected

        spacing: root.font.pointSize * 1.2

        BatteryIndicator {
            id: batteryIndicator
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: batteryIndicator.implicitWidth
            Layout.preferredHeight: batteryIndicator.implicitHeight
            visible: batteryIndicator.batteryLevel >= 0
        }

        NetworkIndicator {
            id: networkIndicator
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: networkIndicator.implicitWidth
            Layout.preferredHeight: networkIndicator.implicitHeight
            visible: networkIndicator.isConnected
        }
    }

    // Billentyűzet kiosztás jelző (külön sorban, hogy akksi/wifi hiányában is látszódjon)
    KeyboardLayoutIndicator {
        id: keyboardLayoutIndicator

        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: keyboardLayoutIndicator.implicitHeight
        Layout.leftMargin: p != "0" ? a == "left" ? -p : a == "right" ? p : 0 : 0
        Layout.bottomMargin: visible ? 4 : 0
    }

    Input {
        id: input

        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: input.implicitHeight
        Layout.leftMargin: p != "0" ? a == "left" ? -p : a == "right" ? p : 0 : 0
        Layout.topMargin:  0
    }

    SessionButton {
        id: sessionSelect

        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: sessionSelect.height
        Layout.leftMargin: p != "0" ? a == "left" ? -p : a == "right" ? p : 0 : 0
    }

    VirtualKeyboardButton {
        id: virtualKeyboardButton

        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: root.font.pointSize * 2
        Layout.leftMargin: p != "0" ? a == "left" ? -p : a == "right" ? p : 0 : 0
    }
}
