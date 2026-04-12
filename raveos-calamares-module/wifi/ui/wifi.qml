import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "." as WifiModule

Rectangle {
    id: root
    color: WifiModule.Style.backgroundColor

    property string selectedSsid: ""
    property bool showHiddenNetwork: false
    property bool isConnecting: false

    // Function to update language - called from C++
    function updateLanguage() {
        WifiModule.Translations.setLanguage(systemLocale)
    }

    // Initialize translations on load
    Component.onCompleted: {
        WifiModule.Translations.setLanguage(systemLocale)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: WifiModule.Style.margin
        spacing: WifiModule.Style.spacing

        // Header
        Label {
            text: WifiModule.Translations.title
            font.pixelSize: WifiModule.Style.fontSizeTitle
            font.bold: true
            color: WifiModule.Style.textColor
            Layout.alignment: Qt.AlignHCenter
        }

        Label {
            text: WifiModule.Translations.subtitle
            font.pixelSize: WifiModule.Style.fontSizeSubtitle
            color: WifiModule.Style.textSecondaryColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
        }

        // Connection status banner
        Rectangle {
            Layout.fillWidth: true
            height: 40
            radius: WifiModule.Style.borderRadius
            color: nm.connected ? WifiModule.Style.successColor : WifiModule.Style.progressColor
            visible: nm.connected || isConnecting

            RowLayout {
                anchors.centerIn: parent
                spacing: 10

                BusyIndicator {
                    running: isConnecting && !nm.connected
                    visible: isConnecting && !nm.connected
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                }

                Label {
                    text: nm.connected ? WifiModule.Translations.connected : WifiModule.Translations.connecting
                    color: WifiModule.Style.textColor
                    font.pixelSize: WifiModule.Style.fontSizeNormal
                    font.bold: true
                }
            }
        }

        // Network list
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: WifiModule.Style.listBackgroundColor
            radius: WifiModule.Style.borderRadiusLarge
            border.color: WifiModule.Style.borderColor
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 1
                spacing: 0

                // List header with refresh button
                Rectangle {
                    Layout.fillWidth: true
                    height: 44
                    color: WifiModule.Style.listHeaderColor
                    radius: WifiModule.Style.borderRadiusLarge

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 8
                        color: parent.color
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8

                        Label {
                            text: WifiModule.Translations.availableNetworks
                            color: WifiModule.Style.textColor
                            font.pixelSize: WifiModule.Style.fontSizeSmall
                            font.bold: true
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            text: WifiModule.Translations.refresh
                            Layout.preferredHeight: 32
                            onClicked: nm.scan()

                            background: Rectangle {
                                color: parent.hovered ? WifiModule.Style.buttonSecondaryHoverColor : WifiModule.Style.buttonSecondaryColor
                                radius: 4
                            }

                            contentItem: Label {
                                text: parent.text
                                color: WifiModule.Style.textColor
                                font.pixelSize: WifiModule.Style.fontSizeSmall
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }

                // WiFi list
                ListView {
                    id: networkList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: nm.networks

                    delegate: Rectangle {
                        width: networkList.width
                        height: WifiModule.Style.listItemHeight
                        color: modelData === selectedSsid ? WifiModule.Style.itemSelectedColor :
                               (mouseArea.containsMouse ? WifiModule.Style.itemHoverColor : "transparent")

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 12

                            Label {
                                text: ""
                                font.pixelSize: 18
                            }

                            Label {
                                text: modelData
                                color: WifiModule.Style.textColor
                                font.pixelSize: WifiModule.Style.fontSizeNormal
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Label {
                                text: modelData === selectedSsid ? "✓" : ""
                                color: WifiModule.Style.successCheckColor
                                font.pixelSize: 16
                                font.bold: true
                            }
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                selectedSsid = modelData
                                showHiddenNetwork = false
                                ssidField.text = modelData
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            height: 1
                            color: WifiModule.Style.separatorColor
                        }
                    }

                    Label {
                        anchors.centerIn: parent
                        text: WifiModule.Translations.noNetworks
                        color: WifiModule.Style.textMutedColor
                        font.pixelSize: WifiModule.Style.fontSizeSmall
                        horizontalAlignment: Text.AlignHCenter
                        visible: nm.networks.length === 0
                    }
                }
            }
        }

        // Hidden network toggle
        Rectangle {
            Layout.fillWidth: true
            height: WifiModule.Style.inputHeight
            color: "#3d7839"
            radius: WifiModule.Style.borderRadius

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    showHiddenNetwork = !showHiddenNetwork
                    if (showHiddenNetwork) {
                        selectedSsid = ""
                        ssidField.text = ""
                        ssidField.focus = true
                    }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16

                Label {
                    text: WifiModule.Translations.hiddenNetwork
                    color: WifiModule.Style.textColor
                    font.pixelSize: WifiModule.Style.fontSizeNormal
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 44
                    height: 24
                    radius: 12
                    color: showHiddenNetwork ? WifiModule.Style.toggleOnColor : WifiModule.Style.toggleOffColor

                    Rectangle {
                        width: 20
                        height: 20
                        radius: 10
                        color: WifiModule.Style.textColor
                        x: showHiddenNetwork ? 22 : 2
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on x {
                            NumberAnimation { duration: 150 }
                        }
                    }
                }
            }
        }

        // SSID field (for hidden networks)
        TextField {
            id: ssidField
            Layout.fillWidth: true
            placeholderText: WifiModule.Translations.ssidPlaceholder
            visible: showHiddenNetwork
            color: WifiModule.Style.textColor
            placeholderTextColor: WifiModule.Style.inputPlaceholderColor
            font.pixelSize: WifiModule.Style.fontSizeNormal

            background: Rectangle {
                color: WifiModule.Style.inputBackgroundColor
                radius: WifiModule.Style.borderRadius
                border.color: ssidField.focus ? WifiModule.Style.inputFocusBorderColor : WifiModule.Style.inputBorderColor
                border.width: 1
            }
        }

        // Password field
        TextField {
            id: passField
            Layout.fillWidth: true
            placeholderText: WifiModule.Translations.passwordPlaceholder
            echoMode: TextInput.Password
            color: WifiModule.Style.textColor
            placeholderTextColor: WifiModule.Style.inputPlaceholderColor
            font.pixelSize: WifiModule.Style.fontSizeNormal
            enabled: selectedSsid !== "" || showHiddenNetwork
            opacity: 1

            background: Rectangle {
                color: passField.enabled ? WifiModule.Style.inputBackgroundColor : WifiModule.Style.inputDisabledColor
                radius: WifiModule.Style.borderRadius
                border.color: passField.focus ? WifiModule.Style.inputFocusBorderColor : WifiModule.Style.inputBorderColor
                border.width: 1
            }
        }

        // Connect button
        Button {
            Layout.fillWidth: true
            Layout.preferredHeight: WifiModule.Style.buttonHeight
            text: WifiModule.Translations.connect
            enabled: (selectedSsid !== "" || (showHiddenNetwork && ssidField.text !== "")) &&
                     passField.text !== "" && !isConnecting && !nm.connected

            onClicked: {
                isConnecting = true
                var ssid = showHiddenNetwork ? ssidField.text : selectedSsid
                nm.connectTo(ssid, passField.text)
            }

            background: Rectangle {
                color: parent.enabled ? (parent.hovered ? WifiModule.Style.buttonPrimaryHoverColor : WifiModule.Style.buttonPrimaryColor) : WifiModule.Style.buttonDisabledColor
                radius: WifiModule.Style.borderRadius
            }

            contentItem: Label {
                text: parent.text
                color: parent.enabled ? WifiModule.Style.textColor : WifiModule.Style.textDisabledColor
                font.pixelSize: 15
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        // Skip info
        Label {
            text: nm.connected ?
                  WifiModule.Translations.clickNextToContinue :
                  WifiModule.Translations.canSkipWithEthernet
            color: WifiModule.Style.textMutedColor
            font.pixelSize: WifiModule.Style.fontSizeTiny
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // Connection state change handler
    Connections {
        target: nm
        function onConnectionChanged() {
            if (nm.connected) {
                isConnecting = false
            }
        }
        function onConnectionFailed(error) {
            isConnecting = false
            console.log("Connection failed: " + error)
        }
    }

    // Timer to reset connecting state if it takes too long
    Timer {
        id: connectTimeout
        interval: 30000
        running: isConnecting
        onTriggered: {
            if (!nm.connected) {
                isConnecting = false
            }
        }
    }
}