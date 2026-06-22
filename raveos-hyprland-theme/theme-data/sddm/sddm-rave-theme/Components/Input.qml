// Config created by Keyitdev https://git.rp1.hu/gabeszm/sddm-rave-theme
// Copyright (C) 2022-2025 Keyitdev
// Based on https://github.com/MarianArlt/sddm-sugar-dark
// Distributed under the GPLv3+ License https://www.gnu.org/licenses/gpl-3.0.html

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import QtQuick.Effects

Column {
    id: inputContainer

    Layout.fillWidth: true

    property ComboBox exposeSession: sessionSelect.exposeSession
    property bool failed

    Item {
        id: errorMessageField

        // change also in selectSession
        height: root.font.pointSize * 2
        width: parent.width / 2
        anchors.horizontalCenter: parent.horizontalCenter

        Label {
            id: errorMessage

            width: parent.width
            horizontalAlignment: Text.AlignHCenter

            text: failed ? config.TranslateLoginFailedWarning || textConstants.loginFailed + "!" : keyboard.capsLock ? config.TranslateCapslockWarning || textConstants.capslockWarning : null
            font.pointSize: root.font.pointSize * 0.8
            font.italic: true
            color: config.WarningColor
            opacity: 0

            states: [
                State {
                    name: "fail"
                    when: failed
                    PropertyChanges {
                        target: errorMessage
                        opacity: 1
                    }
                },
                State {
                    name: "capslock"
                    when: keyboard.capsLock
                    PropertyChanges {
                        target: errorMessage
                        opacity: 1
                    }
                }
            ]
            transitions: [
                Transition {
                    PropertyAnimation {
                        properties: "opacity"
                        duration: 100
                    }
                }
            ]
        }
    }

    // Profilkép + felhasználóváltó
    Item {
        id: avatarField

        height: root.font.pointSize * 12
        width: parent.width / 2
        anchors.horizontalCenter: parent.horizontalCenter

        property string userIconPath: {
            var icon = userModel.data(userModel.index(selectUser.currentIndex, 0), Qt.UserRole + 4)
            return (icon && icon !== "") ? icon : ""
        }

        Column {
            anchors.centerIn: parent
            spacing: root.font.pointSize * 0.8

            // Avatar kör
            Rectangle {
                id: avatarCircle
                anchors.horizontalCenter: parent.horizontalCenter
                width:  root.font.pointSize * 7
                height: root.font.pointSize * 7
                radius: width / 2
                clip:   true
                color:  Qt.rgba(0.10, 0.10, 0.15, 0.65)

                // The source image (invisible)
                Image {
                    id: avatarPhoto
                    anchors.fill: parent
                    source:   avatarField.userIconPath !== "" ? avatarField.userIconPath : ""
                    fillMode: Image.PreserveAspectCrop
                    smooth:   true
                    mipmap:   true
                    visible:  false
                }

                // The mask source
                Item {
                    id: avatarMask
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.width / 2
                        color: "black"
                    }
                }

                // Apply MultiEffect to mask the avatarPhoto
                MultiEffect {
                    anchors.fill: parent
                    source: avatarPhoto
                    visible: avatarPhoto.status === Image.Ready && avatarField.userIconPath !== ""
                    maskEnabled: true
                    maskSource: avatarMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }

                Image {
                    id: avatarFallback
                    anchors.centerIn: parent
                    width:    parent.width  * 0.55
                    height:   parent.height * 0.55
                    source:   Qt.resolvedUrl("../Assets/User.svg")
                    fillMode: Image.PreserveAspectFit
                    smooth:   true
                    visible:  avatarField.userIconPath === "" || avatarPhoto.status !== Image.Ready
                    opacity:  0.75
                }

                // Draw the border on top of everything!
                Rectangle {
                    anchors.fill: parent
                    radius: parent.width / 2
                    color: "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.30)
                    border.width: 2
                }
            }

            // Felhasználóváltó gomb (csak ha több user van)
            UserSwitcher {
                id: userSwitcher
                anchors.horizontalCenter: parent.horizontalCenter
                selectedIndex: selectUser.currentIndex

                onUserSwitched: function(idx, name) {
                    selectUser.currentIndex = idx
                    username.text = name
                }
            }
        }
    }


    Item {
        id: usernameField

        height: root.font.pointSize * 4.5
        width: parent.width / 2
        anchors.horizontalCenter: parent.horizontalCenter

        Button {
            id: staticUserIcon

            width: parent.height
            height: parent.height
            anchors.left: parent.left
            z: 2
            visible: userModel.count <= 1
            enabled: false

            icon.height: parent.height * 0.25
            icon.width: parent.height * 0.25
            icon.color: config.UserIconColor
            icon.source: Qt.resolvedUrl("../Assets/User.svg")

            background: Rectangle {
                color: "transparent"
                border.color: "transparent"
            }
        }

        ComboBox {
            id: selectUser

            width: parent.height
            height: parent.height
            anchors.left: parent.left
            z: 2
            visible: userModel.count > 1

            model: userModel
            currentIndex: model.lastIndex
            textRole: "name"
            hoverEnabled: true
            onActivated: {
                username.text = currentText;
            }

            property var popkey: config.RightToLeftLayout == "true" ? Qt.Key_Right : Qt.Key_Left
            Keys.onPressed: function (event) {
                if (event.key == Qt.Key_Down && !popup.opened)
                    username.forceActiveFocus();
                if ((event.key == Qt.Key_Up || event.key == popkey) && !popup.opened)
                    popup.open();
            }
            KeyNavigation.down: username
            KeyNavigation.right: username

            delegate: ItemDelegate {
                //  minus padding
                width: popupHandler.width - 20
                anchors.horizontalCenter: popupHandler.horizontalCenter

                contentItem: Text {
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter

                    text: model.name
                    font.pointSize: root.font.pointSize * 0.8
                    font.capitalization: Font.AllLowercase
                    font.family: root.font.family
                    color: config.DropdownTextColor
                }

                background: Rectangle {
                    color: selectUser.highlightedIndex === index ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                    radius: config.RoundCorners !== "" ? parseInt(config.RoundCorners) / 4 : 5
                }
            }

            indicator: Button {
                id: usernameIcon

                width: selectUser.height * 1
                height: parent.height
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: selectUser.height * 0

                icon.height: parent.height * 0.25
                icon.width: parent.height * 0.25
                enabled: false
                icon.color: config.UserIconColor
                icon.source: Qt.resolvedUrl("../Assets/User.svg")

                background: Rectangle {
                    color: "transparent"
                    border.color: "transparent"
                }
            }

            background: Rectangle {
                color: "transparent"
                border.color: "transparent"
            }

            popup: Popup {
                id: popupHandler

                implicitHeight: contentItem.implicitHeight
                width: usernameField.width
                y: parent.height - username.height / 3
                x: config.RightToLeftLayout == "true" ? -loginButton.width + selectUser.width : 0
                rightMargin: config.RightToLeftLayout == "true" ? root.padding + usernameField.width / 2 : undefined
                padding: 10

                contentItem: ListView {
                    implicitHeight: contentHeight + 20

                    clip: true
                    model: selectUser.popup.visible ? selectUser.delegateModel : null
                    currentIndex: selectUser.highlightedIndex
                    ScrollIndicator.vertical: ScrollIndicator {}
                }

                background: Rectangle {
                    radius: config.RoundCorners !== "" ? parseInt(config.RoundCorners) / 2 : 10
                    color: Qt.rgba(1, 1, 1, 0.08)
                    border.color: Qt.rgba(1, 1, 1, 0.18)
                    border.width: 1
                    layer.enabled: true
                }

                enter: Transition {
                    NumberAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                    }
                }
            }

            states: [
                State {
                    name: "pressed"
                    when: selectUser.down
                    PropertyChanges {
                        target: usernameIcon
                        icon.color: Qt.lighter(config.HoverUserIconColor, 1.1)
                    }
                },
                State {
                    name: "hovered"
                    when: selectUser.hovered
                    PropertyChanges {
                        target: usernameIcon
                        icon.color: Qt.lighter(config.HoverUserIconColor, 1.2)
                    }
                },
                State {
                    name: "focused"
                    when: selectUser.activeFocus
                    PropertyChanges {
                        target: usernameIcon
                        icon.color: config.HoverUserIconColor
                    }
                }
            ]
            transitions: [
                Transition {
                    PropertyAnimation {
                        properties: "color, border.color, icon.color"
                        duration: 150
                    }
                }
            ]
        }

        TextField {
            id: username

            anchors.centerIn: parent
            height: root.font.pointSize * 3
            width: parent.width
            horizontalAlignment: TextInput.AlignHCenter
            z: 1

            text: config.ForceLastUser == "true" ? selectUser.currentText : null
            color: config.LoginFieldTextColor
            font.bold: true
            font.capitalization: config.AllowUppercaseLettersInUsernames == "false" ? Font.AllLowercase : Font.MixedCase
            placeholderText: config.TranslatePlaceholderUsername || textConstants.userName
            placeholderTextColor: config.PlaceholderTextColor
            selectByMouse: true
            renderType: Text.QtRendering

            onFocusChanged: {
                if (focus)
                    selectAll();
            }

            background: Rectangle {
                color: username.activeFocus ? Qt.rgba(0, 0, 0, 0.35) : Qt.rgba(0, 0, 0, 0.2)
                border.color: username.activeFocus ? Qt.rgba(255, 255, 255, 0.3) : Qt.rgba(255, 255, 255, 0.12)
                border.width: username.activeFocus ? 1.5 : 1
                radius: config.RoundCorners !== "" ? parseInt(config.RoundCorners) : 10
                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
                Behavior on border.color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }

            onAccepted: config.AllowUppercaseLettersInUsernames == "false" ? sddm.login(username.text.toLowerCase(), password.text, sessionSelect.selectedSession) : sddm.login(username.text, password.text, sessionSelect.selectedSession)
            KeyNavigation.down: passwordIcon

            states: [
                State {
                    name: "focused"
                    when: username.activeFocus
                    PropertyChanges {
                        target: username
                        color: Qt.lighter(config.LoginFieldTextColor, 1.15)
                    }
                }
            ]
        }
    }

    Item {
        id: passwordField

        height: root.font.pointSize * 4.5
        width: parent.width / 2
        anchors.horizontalCenter: parent.horizontalCenter

        Button {
            id: passwordIcon

            height: parent.height
            width: selectUser.height * 1
            anchors.left: parent.left
            anchors.leftMargin: selectUser.height * 0
            anchors.verticalCenter: parent.verticalCenter
            z: 2

            icon.height: parent.height * 0.25
            icon.width: parent.height * 0.25
            icon.color: config.PasswordIconColor
            icon.source: Qt.resolvedUrl("../Assets/Password2.svg")

            background: Rectangle {
                color: "transparent"
                border.color: "transparent"
            }

            states: [
                State {
                    name: "visiblePasswordFocused"
                    when: passwordIcon.checked && passwordIcon.activeFocus
                    PropertyChanges {
                        target: passwordIcon
                        icon.source: Qt.resolvedUrl("../Assets/Password.svg")
                        icon.color: config.HoverPasswordIconColor
                    }
                },
                State {
                    name: "visiblePasswordHovered"
                    when: passwordIcon.checked && passwordIcon.hovered
                    PropertyChanges {
                        target: passwordIcon
                        icon.source: Qt.resolvedUrl("../Assets/Password.svg")
                        icon.color: config.HoverPasswordIconColor
                    }
                },
                State {
                    name: "visiblePassword"
                    when: passwordIcon.checked
                    PropertyChanges {
                        target: passwordIcon
                        icon.source: Qt.resolvedUrl("../Assets/Password.svg")
                    }
                },
                State {
                    name: "hiddenPasswordFocused"
                    when: passwordIcon.enabled && passwordIcon.activeFocus
                    PropertyChanges {
                        target: passwordIcon
                        icon.source: Qt.resolvedUrl("../Assets/Password2.svg")
                        icon.color: config.HoverPasswordIconColor
                    }
                },
                State {
                    name: "hiddenPasswordHovered"
                    when: passwordIcon.hovered
                    PropertyChanges {
                        target: passwordIcon
                        icon.source: Qt.resolvedUrl("../Assets/Password2.svg")
                        icon.color: config.HoverPasswordIconColor
                    }
                }
            ]

            onClicked: toggle()
            Keys.onReturnPressed: toggle()
            Keys.onEnterPressed: toggle()
            KeyNavigation.down: password
        }

        TextField {
            id: password

            height: root.font.pointSize * 3
            width: parent.width
            anchors.centerIn: parent
            horizontalAlignment: TextInput.AlignHCenter

            font.bold: true
            color: config.PasswordFieldTextColor
            focus: config.PasswordFocus == "true" ? true : false
            echoMode: passwordIcon.checked ? TextInput.Normal : TextInput.Password
            placeholderText: config.TranslatePlaceholderPassword || textConstants.password
            placeholderTextColor: config.PlaceholderTextColor
            passwordCharacter: "•"
            passwordMaskDelay: config.HideCompletePassword == "true" ? undefined : 1000
            renderType: Text.QtRendering
            selectByMouse: true

            background: Rectangle {
                color: password.activeFocus ? Qt.rgba(0, 0, 0, 0.35) : Qt.rgba(0, 0, 0, 0.2)
                border.color: password.activeFocus ? Qt.rgba(255, 255, 255, 0.3) : Qt.rgba(255, 255, 255, 0.12)
                border.width: password.activeFocus ? 1.5 : 1
                radius: config.RoundCorners !== "" ? parseInt(config.RoundCorners) : 10
                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
                Behavior on border.color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }
            onAccepted: config.AllowUppercaseLettersInUsernames == "false" ? sddm.login(username.text.toLowerCase(), password.text, sessionSelect.selectedSession) : sddm.login(username.text, password.text, sessionSelect.selectedSession)
            KeyNavigation.down: loginButton
        }

        states: [
            State {
                name: "focused"
                when: password.activeFocus
                PropertyChanges {
                    target: password
                    color: Qt.lighter(config.LoginFieldTextColor, 1.15)
                }
            }
        ]
        transitions: [
            Transition {
                PropertyAnimation {
                    properties: "color, border.color"
                    duration: 150
                }
            }
        ]
    }

    Item {
        id: login

        // important
        // try 4 or 9 ...
        height: root.font.pointSize * 9
        width: parent.width / 2
        anchors.horizontalCenter: parent.horizontalCenter

        visible: config.HideLoginButton == "true" ? false : true

        Item {
            id: loginButton

            height: root.font.pointSize * 3
            width: parent.width
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter

            focus: true
            activeFocusOnTab: true

            property bool hovered: hoverArea.containsMouse
            property bool down: hoverArea.pressed

            signal clicked()

            onClicked: config.AllowUppercaseLettersInUsernames == "false" ? sddm.login(username.text.toLowerCase(), password.text, sessionSelect.selectedSession) : sddm.login(username.text, password.text, sessionSelect.selectedSession)

            Keys.onReturnPressed: clicked()
            Keys.onEnterPressed: clicked()

            KeyNavigation.down: rebootBtn

            Rectangle {
                id: buttonBackground
                anchors.fill: parent

                radius: config.RoundCorners !== "" ? parseInt(config.RoundCorners) : 10
                border.width: loginButton.activeFocus ? 1.5 : 1

                border.color: loginButton.down ? Qt.rgba(21/255, 128/255, 61/255, 0.95) : (loginButton.hovered ? Qt.rgba(34/255, 197/255, 94/255, 0.85) : Qt.rgba(74/255, 222/255, 128/255, 0.65))

                color: loginButton.down ? Qt.rgba(21/255, 128/255, 61/255, 0.80) : (loginButton.hovered ? Qt.rgba(34/255, 197/255, 94/255, 0.65) : Qt.rgba(74/255, 222/255, 128/255, 0.40))

                Behavior on border.color {
                    ColorAnimation {
                        duration: 150
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }

            Text {
                id: loginButtonText
                anchors.centerIn: parent

                font.bold: true
                font.pointSize: root.font.pointSize
                font.family: root.font.family
                color: "#ffffff"
                text: config.TranslateLogin || textConstants.login
                opacity: 1.0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }
                }
            }

            MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: parent.clicked()
            }
        }
    }

    Item {
        id: powerButtonsRow

        height: root.font.pointSize * 10
        width: parent.width / 2
        anchors.horizontalCenter: parent.horizontalCenter

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.font.pointSize * 3

            // Reboot gomb
            Column {
                spacing: root.font.pointSize * 0.6

                RoundButton {
                    id: rebootBtn

                    width: root.font.pointSize * 6
                    height: root.font.pointSize * 6

                    activeFocusOnTab: true
                    Keys.onReturnPressed: sddm.reboot()
                    Keys.onEnterPressed: sddm.reboot()
                    KeyNavigation.right: shutdownBtn
                    hoverEnabled: true

                    icon.source: Qt.resolvedUrl("../Assets/Reboot.svg")
                    icon.width: root.font.pointSize * 3
                    icon.height: root.font.pointSize * 3
                    icon.color: "#ffffff"

                    opacity: rebootBtn.hovered || rebootBtn.activeFocus ? 1.0 : 0.75
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    scale: rebootBtn.pressed ? 0.88 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    background: Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: rebootBtn.pressed ? Qt.rgba(1, 0.45, 0.0, 0.35) : (rebootBtn.hovered ? Qt.rgba(1, 0.55, 0.0, 0.22) : "transparent")
                        border.color: "transparent"
                        border.width: 0
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    onClicked: sddm.reboot()
                }

                Text {
                    anchors.horizontalCenter: parent.children[0].horizontalCenter
                    text: config.TranslateReboot || textConstants.reboot
                    color: "#ffffff"
                    font.pointSize: root.font.pointSize * 0.8
                    font.family: root.font.family
                    horizontalAlignment: Text.AlignHCenter
                    opacity: rebootBtn.hovered || rebootBtn.activeFocus ? 1.0 : 0.75
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
            }

            // Shutdown gomb
            Column {
                spacing: root.font.pointSize * 0.6

                RoundButton {
                    id: shutdownBtn

                    width: root.font.pointSize * 6
                    height: root.font.pointSize * 6

                    activeFocusOnTab: true
                    Keys.onReturnPressed: sddm.powerOff()
                    Keys.onEnterPressed: sddm.powerOff()
                    KeyNavigation.left: rebootBtn
                    hoverEnabled: true

                    icon.source: Qt.resolvedUrl("../Assets/Shutdown.svg")
                    icon.width: root.font.pointSize * 3
                    icon.height: root.font.pointSize * 3
                    icon.color: "#ffffff"

                    opacity: shutdownBtn.hovered || shutdownBtn.activeFocus ? 1.0 : 0.75
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    scale: shutdownBtn.pressed ? 0.88 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    background: Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: shutdownBtn.pressed ? Qt.rgba(0.8, 0.1, 0.1, 0.40) : (shutdownBtn.hovered ? Qt.rgba(0.8, 0.1, 0.1, 0.25) : "transparent")
                        border.color: "transparent"
                        border.width: 0
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    onClicked: sddm.powerOff()
                }

                Text {
                    anchors.horizontalCenter: parent.children[0].horizontalCenter
                    text: config.TranslateShutdown || textConstants.shutdown
                    color: "#ffffff"
                    font.pointSize: root.font.pointSize * 0.8
                    font.family: root.font.family
                    horizontalAlignment: Text.AlignHCenter
                    opacity: shutdownBtn.hovered || shutdownBtn.activeFocus ? 1.0 : 0.75
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
            }
        }
    }

    Connections {
        target: sddm
        function onLoginSucceeded() {
        }
        function onLoginFailed() {
            failed = true;
            resetError.running ? resetError.stop() && resetError.start() : resetError.start();
        }
    }

    Timer {
        id: resetError
        interval: 2000
        onTriggered: failed = false
        running: false
    }
}
