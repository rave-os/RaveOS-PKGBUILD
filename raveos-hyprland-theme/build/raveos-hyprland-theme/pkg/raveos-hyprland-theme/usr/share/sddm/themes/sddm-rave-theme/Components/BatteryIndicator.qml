import QtQuick 2.15
import Qt.labs.folderlistmodel 2.15

Row {
    id: batteryIndicator

    height: root.font.pointSize * 1.6
    spacing: root.font.pointSize * 0.5

    // -1 = nincs akkumulátor / nem laptop
    property int  batteryLevel:  -1
    property bool isCharging:    false
    property bool isFull:        false
    property string batteryPath: ""

    visible: batteryLevel >= 0

    // Ismert akksi elérési utak
    property var tryPaths: [
        "/sys/class/power_supply/BAT0/",
        "/sys/class/power_supply/BAT1/",
        "/sys/class/power_supply/BAT2/",
        "/sys/class/power_supply/battery/",
        "/sys/class/power_supply/BATT/"
    ]

    // Dinamikus akkumulátor kereső (pl. kontroller, UPS, egyéb külső akkuk észleléséhez)
    FolderListModel {
        id: powerSupplyScanner
        folder: "file:///sys/class/power_supply"
        showDirs: true
        showFiles: false
        
        onCountChanged: scan()
        onFolderChanged: scan()
        
        function scan() {
            var defaults = [
                "/sys/class/power_supply/BAT0/",
                "/sys/class/power_supply/BAT1/",
                "/sys/class/power_supply/BAT2/",
                "/sys/class/power_supply/battery/",
                "/sys/class/power_supply/BATT/"
            ]
            for (var i = 0; i < count; i++) {
                var name = get(i, "fileName")
                if (name && name !== "." && name !== "..") {
                    // Csak a tipikus laptop akkumulátor elnevezések (pl. BAT0, BAT1, BATT, battery)
                    var isLaptopBat = /^bat/i.test(name) || /^battery/i.test(name)
                    if (isLaptopBat) {
                        var fullPath = "/sys/class/power_supply/" + name + "/"
                        if (defaults.indexOf(fullPath) === -1) {
                            defaults.push(fullPath)
                        }
                    }
                }
            }
            tryPaths = defaults
            detectBattery(0)
        }
    }

    // ── Fájl olvasó ──────────────────────────────────────────────────────────
    function readFile(path, cb) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "file://" + path, true)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE)
                cb(xhr.responseText && xhr.responseText.trim() !== "" ? xhr.responseText.trim() : null)
        }
        xhr.send()
    }

    // ── Akkumulátor keresés és frissítés ─────────────────────────────────────
    function detectBattery(idx) {
        if (idx >= tryPaths.length) { batteryLevel = -1; return }
        readFile(tryPaths[idx] + "capacity", function(cap) {
            if (cap !== null) {
                batteryPath = tryPaths[idx]
                batteryLevel = Math.max(0, Math.min(100, parseInt(cap) || 0))
                readFile(batteryPath + "status", function(st) {
                    var s = st ? st.toLowerCase() : ""
                    isFull      = (s === "full")
                    isCharging  = (s === "charging") || isFull
                    batteryCanvas.requestPaint()
                })
            } else {
                detectBattery(idx + 1)
            }
        })
    }

    // ── Akkumulátor frissítés ────────────────────────────────────────────────
    function refresh() {
        if (batteryPath !== "") {
            readFile(batteryPath + "capacity", function(cap) {
                if (cap !== null) {
                    batteryLevel = Math.max(0, Math.min(100, parseInt(cap) || 0))
                    readFile(batteryPath + "status", function(st) {
                        var s = st ? st.toLowerCase() : ""
                        isFull     = (s === "full")
                        isCharging = (s === "charging") || isFull
                        batteryCanvas.requestPaint()
                    })
                }
            })
        } else {
            powerSupplyScanner.scan()
        }
    }

    Component.onCompleted: powerSupplyScanner.scan()

    Timer {
        interval: 30000
        repeat:   true
        running:  true
        onTriggered: batteryIndicator.refresh()
    }

    // ── Szín a töltési szint alapján ─────────────────────────────────────────
    function levelColor(lvl, charging) {
        if (charging) return "#4ade80"          // zöld – tölt
        if (lvl > 60)  return "#ffffff"          // fehér – ok
        if (lvl > 30)  return "#facc15"          // sárga – közepes
        if (lvl > 15)  return "#fb923c"          // narancs – alacsony
        return "#f87171"                         // piros – kritikus
    }

    // ── UI ───────────────────────────────────────────────────────────────────
    Canvas {
        id: batteryCanvas
        width:  root.font.pointSize * 3.2
        height: root.font.pointSize * 1.6
        anchors.verticalCenter: parent.verticalCenter

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            // Qt Canvas nem támogatja ctx.roundRect() – saját helper
            function rr(c, x, y, w, h, r) {
                r = Math.min(Math.max(r, 0), Math.min(w, h) / 2)
                c.beginPath()
                c.moveTo(x + r, y)
                c.arcTo(x + w, y,     x + w, y + h, r)
                c.arcTo(x + w, y + h, x,     y + h, r)
                c.arcTo(x,     y + h, x,     y,     r)
                c.arcTo(x,     y,     x + w, y,     r)
                c.closePath()
            }

            var lvl      = batteryIndicator.batteryLevel
            var charging = batteryIndicator.isCharging
            var full     = batteryIndicator.isFull
            var col      = batteryIndicator.levelColor(lvl, charging)

            var bw = width * 0.84   // akksi test szélessége
            var bh = height * 0.72  // akksi test magassága
            var bx = 0
            var by = (height - bh) / 2
            var r  = bh * 0.22      // sarokkerekítés
            var tw = width * 0.07   // terminál szélessége
            var th = bh * 0.44      // terminál magassága
            var tx = bw             // terminál x
            var ty = (height - th) / 2

            // Terminál (+ pólus)
            rr(ctx, tx, ty, tw, th, 2)
            ctx.fillStyle = col
            ctx.globalAlpha = 0.7
            ctx.fill()
            ctx.globalAlpha = 1.0

            // Keret (akksi test)
            rr(ctx, bx, by, bw, bh, r)
            ctx.strokeStyle = col
            ctx.lineWidth = 1.5
            ctx.stroke()

            // Töltési szint kitöltés
            var padding = 3
            var fillW = Math.max(0, (bw - padding * 2) * lvl / 100)
            if (fillW > 0) {
                rr(ctx, bx + padding, by + padding,
                   fillW, bh - padding * 2,
                   Math.max(0, r - padding * 0.5))
                ctx.fillStyle = col
                ctx.globalAlpha = 0.85
                ctx.fill()
                ctx.globalAlpha = 1.0
            }

            // Villám jel (töltés közben)
            if (charging && !full) {
                var cx = bw / 2
                var cy = height / 2
                var s  = bh * 0.52
                ctx.beginPath()
                ctx.moveTo(cx + s * 0.18,  cy - s * 0.5)
                ctx.lineTo(cx - s * 0.08,  cy + s * 0.05)
                ctx.lineTo(cx + s * 0.10,  cy + s * 0.05)
                ctx.lineTo(cx - s * 0.18,  cy + s * 0.5)
                ctx.lineTo(cx + s * 0.08,  cy - s * 0.05)
                ctx.lineTo(cx - s * 0.10,  cy - s * 0.05)
                ctx.closePath()
                ctx.fillStyle = "#ffffff"
                ctx.globalAlpha = 0.95
                ctx.fill()
                ctx.globalAlpha = 1.0
            }

            // Tele jel (checkbox-szerű pipával)
            if (full) {
                ctx.beginPath()
                ctx.moveTo(bw * 0.32, by + bh / 2)
                ctx.lineTo(bw * 0.46, by + bh * 0.68)
                ctx.lineTo(bw * 0.68, by + bh * 0.28)
                ctx.strokeStyle = "#ffffff"
                ctx.lineWidth = 1.8
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.globalAlpha = 0.95
                ctx.stroke()
                ctx.globalAlpha = 1.0
            }
        }
    }

    // Százalék szöveg
    Text {
        id: batteryText
        anchors.verticalCenter: parent.verticalCenter
        text: {
            if (batteryIndicator.isFull)      return "100%"
            if (batteryIndicator.isCharging)  return batteryIndicator.batteryLevel + "% ↑"
            return batteryIndicator.batteryLevel + "%"
        }
        color:            batteryIndicator.levelColor(batteryIndicator.batteryLevel, batteryIndicator.isCharging)
        font.pointSize:   root.font.pointSize * 0.82
        font.family:      root.font.family
        font.bold:        batteryIndicator.batteryLevel <= 15 && !batteryIndicator.isCharging

        // Pulzáló animáció kritikus töltésnél
        SequentialAnimation on opacity {
            running: batteryIndicator.batteryLevel <= 15 && !batteryIndicator.isCharging
            loops:   Animation.Infinite
            NumberAnimation { to: 0.3; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
        }
    }

    // Szint változáskor újrafest
    onBatteryLevelChanged: batteryCanvas.requestPaint()
    onIsChargingChanged:   batteryCanvas.requestPaint()
    onIsFullChanged:       batteryCanvas.requestPaint()
}
