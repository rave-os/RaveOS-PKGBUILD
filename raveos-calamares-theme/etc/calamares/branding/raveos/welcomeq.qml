import QtQuick 2.10

Item {
    id: welcomeRoot
    anchors.fill: parent

    Image {
        anchors.fill: parent
        source: "images/raveos-welcome.png"
        fillMode: Image.Stretch
        horizontalAlignment: Image.AlignHCenter
        verticalAlignment: Image.AlignVCenter
        smooth: true
    }
}
