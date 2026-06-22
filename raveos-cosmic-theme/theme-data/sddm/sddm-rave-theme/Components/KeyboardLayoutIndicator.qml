// Keyboard Layout Indicator component
// Displays the current locale/layout and switches between them when clicked (if multiple are available)

import QtQuick 2.15
import QtQml 2.15
import QtQuick.Controls 2.15

Item {
    id: layoutIndicator

    implicitWidth: layoutRow.implicitWidth
    implicitHeight: layoutRow.implicitHeight
    width:  implicitWidth
    height: implicitHeight

    // Number of available layouts
    property int layoutsCount: (typeof keyboard !== "undefined" && keyboard && keyboard.layouts) ? keyboard.layouts.length : 0

    // Show if we have layout info or a valid locale fallback
    visible: currentShortName !== ""

    // Get current layout shortname (e.g. "US", "HU")
    property string currentShortName: ""

    function updateCurrentShortName() {
        if (layoutsCount > 0) {
            var idx = keyboard.currentLayout
            if (idx >= 0 && idx < layoutsCount) {
                var layoutObj = keyboard.layouts[idx]
                if (layoutObj && layoutObj.shortName) {
                    currentShortName = layoutObj.shortName.toUpperCase()
                    return
                }
            }
        }
        
        // Fallback to config locale or system locale
        var loc = config.Locale || Qt.locale().name
        if (loc) {
            var parts = loc.split("_")
            if (parts.length > 0 && parts[0]) {
                currentShortName = parts[0].toUpperCase()
                return
            }
        }
        currentShortName = ""
    }

    Component.onCompleted: updateCurrentShortName()

    // Colors matched to the theme config
    property color textColor: config.UserIconColor || "#ffffff"
    property color hoverColor: config.HoverUserIconColor || "#b7cef1"

    Row {
        id: layoutRow
        height: root.font.pointSize * 1.1
        spacing: root.font.pointSize * 0.4
        // Removed anchors.centerIn to prevent circular binding loop with parent width/height

        // Keyboard icon
        Canvas {
            id: kbdCanvas
            width:  root.font.pointSize * 1.5
            height: root.font.pointSize * 1.1
            anchors.verticalCenter: parent.verticalCenter

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                
                var canHover = layoutsCount >= 1
                var col = (layoutMouseArea.containsMouse && canHover) ? layoutIndicator.hoverColor : layoutIndicator.textColor
                
                ctx.strokeStyle = col
                ctx.fillStyle = col
                ctx.lineWidth = height * 0.08
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.globalAlpha = 0.85

                // Draw keyboard outline
                var r = height * 0.15
                var bx = ctx.lineWidth / 2
                var by = ctx.lineWidth / 2
                var bw = width - ctx.lineWidth
                var bh = height - ctx.lineWidth

                ctx.beginPath()
                ctx.moveTo(bx + r, by)
                ctx.arcTo(bx + bw, by,     bx + bw, by + bh, r)
                ctx.arcTo(bx + bw, by + bh, bx,     by + bh, r)
                ctx.arcTo(bx,     by + bh, bx,     by,     r)
                ctx.arcTo(bx,     by,     bx + bw, by,     r)
                ctx.closePath()
                ctx.stroke()

                // Draw simple key grid
                ctx.lineWidth = height * 0.06
                var kw = bw / 6
                var kh = bh / 4
                // Row 1 & 2 keys
                for (var i = 0; i < 4; i++) {
                    ctx.fillRect(bx + kw * (i + 1), by + kh, kw * 0.6, kh * 0.6)
                    ctx.fillRect(bx + kw * (i + 0.5), by + kh * 2, kw * 0.6, kh * 0.6)
                }
                // Spacebar
                ctx.fillRect(bx + kw * 1.5, by + kh * 3, kw * 3, kh * 0.6)

                ctx.globalAlpha = 1.0
            }

            Connections {
                target: layoutMouseArea
                function onContainsMouseChanged() { kbdCanvas.requestPaint() }
            }
        }

        // Layout Short Name (e.g. US, HU)
        Text {
            id: layoutText
            anchors.verticalCenter: parent.verticalCenter
            text: layoutIndicator.currentShortName
            
            color: {
                var canHover = layoutsCount >= 1
                return (layoutMouseArea.containsMouse && canHover) ? layoutIndicator.hoverColor : layoutIndicator.textColor
            }
            
            font.pointSize: root.font.pointSize * 0.82
            font.family:      root.font.family
            font.bold:        true
        }
    }

    MouseArea {
        id: layoutMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: (layoutsCount >= 1) ? Qt.PointingHandCursor : Qt.ArrowCursor
        
        onClicked: {
            if (layoutsCount >= 1) {
                layoutPopup.open()
            }
        }
    }

    Popup {
        id: layoutPopup
        y: parent.height + 5
        x: -width / 2 + parent.width / 2
        width: Math.max(160, layoutRow.width * 1.5)
        padding: 5
        
        background: Rectangle {
            radius: config.RoundCorners !== "" ? parseInt(config.RoundCorners) / 2 : 10
            color: config.BackgroundColor || "#1a1a1a"
            border.color: Qt.rgba(1, 1, 1, 0.20)
            border.width: 1
        }
        
        contentItem: ListView {
            id: layoutListView
            implicitHeight: Math.min(200, contentHeight)
            clip: true
            model: layoutsCount
            ScrollIndicator.vertical: ScrollIndicator { }
            
            delegate: Rectangle {
                id: delegateItem
                width: parent.width
                height: root.font.pointSize * 2
                color: delegateMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                radius: config.RoundCorners !== "" ? parseInt(config.RoundCorners) / 4 : 5
                
                // Get layout object safely
                property var layoutObj: (typeof keyboard !== "undefined" && keyboard && keyboard.layouts) ? keyboard.layouts[index] : null
                property string shortName: layoutObj && layoutObj.shortName ? layoutObj.shortName.toUpperCase() : ""
                property string longName: layoutObj && layoutObj.longName ? layoutObj.longName : ""
                
                Row {
                    spacing: 8
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    
                    Text {
                        text: delegateItem.shortName
                        color: index === keyboard.currentLayout ? (config.HoverUserIconColor || "#b7cef1") : (config.UserIconColor || "#ffffff")
                        font.pointSize: root.font.pointSize * 0.8
                        font.family: root.font.family
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    Text {
                        text: delegateItem.longName
                        color: index === keyboard.currentLayout ? (config.HoverUserIconColor || "#b7cef1") : (config.UserIconColor || "#ffffff")
                        font.pointSize: root.font.pointSize * 0.8
                        font.family: root.font.family
                        elide: Text.ElideRight
                        width: parent.width - x - 10
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                
                MouseArea {
                    id: delegateMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        keyboard.currentLayout = index
                        layoutPopup.close()
                    }
                }
            }
        }
        
        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 150 }
        }
    }

    Connections {
        target: keyboard
        ignoreUnknownSignals: true
        function onCurrentLayoutChanged() {
            kbdCanvas.requestPaint()
            updateCurrentShortName()
        }
    }
}
