import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "#404040"

    // Nagy külső keret — cím, banner, kártyák mind benne
    Rectangle {
        anchors.fill: parent
        anchors.margins: 20
        color: "#2B2B2B"
        radius: 10

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            // Cím
            Text {
                text: "Desktop kiválasztása"
                font.pixelSize: 24
                font.bold: true
                color: "#ffffff"
            }

            // Figyelmeztető banner
            Rectangle {
                Layout.fillWidth: true
                height: 50
                color: "#1e1e1e"
                border.color: "#e67e22"
                border.width: 2
                radius: 6

                Text {
                    anchors.centerIn: parent
                    text: "Válassz egy desktop környezetet. Csak egyet választhatsz!"
                    color: "#e0e0e0"
                    font.pixelSize: 13
                }
            }

            // Kártyák
            ListView {
                id: desktopList
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8
                clip: true
                model: backend.desktops

                delegate: Rectangle {
                    width: desktopList.width
                    height: 78
                    radius: 8
                    color: backend.selectedIndex === index ? "#2a4a2a" : "#333333"
                    border.color: backend.selectedIndex === index ? "#5cb85c" : "#555555"
                    border.width: 2

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12

                        Column {
                            Layout.fillWidth: true
                            spacing: 5

                            Text {
                                text: modelData.name || ""
                                color: "#ffffff"
                                font.pixelSize: 15
                                font.bold: true
                            }

                            Text {
                                text: modelData.description || ""
                                color: "#b2b2b2"
                                font.pixelSize: 12
                                width: parent.width
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            width: badgeText.implicitWidth + 20
                            height: 28
                            radius: 4
                            color: modelData.badge_color || "#555555"

                            Text {
                                id: badgeText
                                anchors.centerIn: parent
                                text: modelData.badge || ""
                                color: "#ffffff"
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.selectDesktop(index)
                    }
                }
            }
        }
    }
}
