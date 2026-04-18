import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: root
    color: "black"

    property int stage

    Image {
        anchors.fill: parent
        source: "images/background.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    Rectangle {
        anchors.fill: parent
        color: "#66000000"
    }

    Item {
        anchors.fill: parent
        opacity: stage >= 2 ? 1 : 0

        Image {
            id: logo
            anchors.centerIn: parent
            source: "images/new-RP-logo.png"
            asynchronous: true
            sourceSize.width: Kirigami.Units.gridUnit * 12
            sourceSize.height: Kirigami.Units.gridUnit * 12
            fillMode: Image.PreserveAspectFit
        }

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: logo.bottom
            anchors.topMargin: Kirigami.Units.largeSpacing * 2
            source: "/usr/share/plasma/look-and-feel/org.kde.breeze.desktop/contents/splash/images/busywidget.svgz"
            sourceSize.width: Kirigami.Units.gridUnit * 2
            sourceSize.height: Kirigami.Units.gridUnit * 2
            asynchronous: true
            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 2000
                loops: Animation.Infinite
                running: stage >= 2 && Kirigami.Units.longDuration > 1
            }
        }
    }
}
