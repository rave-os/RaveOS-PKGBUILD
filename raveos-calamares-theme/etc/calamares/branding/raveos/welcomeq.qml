import QtQuick 2.10
import QtQuick.Controls 2.3
import QtQuick.Layouts 1.3

Item {
    id: welcomeRoot
    anchors.fill: parent

    // Adaptive background image
    Image {
        anchors.fill: parent
        source: "images/raveos-welcome.png"
        fillMode: Image.Stretch
        smooth: true
        mipmap: true
    }

    // Bottom overlay for language selector
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 56
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#002B2B2B" }
            GradientStop { position: 1.0; color: "#DD2B2B2B" }
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: 10

            Image {
                source: "qrc:/welcome/language-icon-48px.png"
                width: 22
                height: 22
                smooth: true
            }

            ComboBox {
                id: languageCombo
                currentIndex: config.localeIndex
                onActivated: function(idx) {
                    console.log("QML: activating locale idx=" + idx);
                    config.localeIndex = idx;
                    console.log("QML: after set, localeIndex=" + config.localeIndex);
                }
                implicitWidth: 260
                implicitHeight: 36

                Component.onCompleted: {
                    var m = config.languagesModel;
                    var items = [];
                    for (var i = 0; i < m.rowCount(); i++) {
                        var idx = m.index(i, 0);
                        var val = m.data(idx, Qt.DisplayRole);
                        items.push(val !== undefined ? val : m.data(idx, Qt.UserRole));
                    }
                    model = items;
                    currentIndex = config.localeIndex;
                }
            }

            Connections {
                target: config
                function onLocaleIndexChanged() {
                    console.log("QML: localeIndexChanged signal fired! new=" + config.localeIndex);
                    languageCombo.currentIndex = config.localeIndex;
                }
            }
        }
    }
}
