// Config created by Keyitdev https://git.rp1.hu/gabeszm/sddm-rave-theme
// Copyright (C) 2022-2025 Keyitdev
// Distributed under the GPLv3+ License https://www.gnu.org/licenses/gpl-3.0.html

import QtQuick 2.15

Row {
    id: networkIndicator

    height: root.font.pointSize * 1.6
    spacing: root.font.pointSize * 0.5

    // "none" | "wifi" | "ethernet"
    property string netType:     "none"
    property int    wifiQuality: 0         // 0-100
    property string activeIface: ""
    property bool   isConnected: netType !== "none"

    visible: isConnected

    property var wifiIfaces: [
        "wlan0","wlan1","wlp1s0","wlp2s0","wlp3s0",
        "wlp4s0","wlp5s0","wlp6s0","wlp0s20f3"
    ]
    property var ethIfaces: [
        "eth0","eth1","eno1","eno2",
        "enp1s0","enp2s0","enp3s0","enp4s0",
        "enp0s3","enp0s31f6","ens33","ens3","ens18"
    ]

    // ── Fájl olvasó ──────────────────────────────────────────────────────────
    function readFile(path, cb) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "file://" + path, true)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                var res = xhr.responseText && xhr.responseText.trim() !== ""
                   ? xhr.responseText.trim() : null
                cb(res)
            }
        }
        xhr.send()
    }

    // ── WiFi jelerősség /proc/net/wireless-ből ───────────────────────────────
    function readWifiSignal(iface) {
        readFile("/proc/net/wireless", function(content) {
            if (!content) { wifiQuality = 60; netCanvas.requestPaint(); return }
            var lines = content.split("\n")
            for (var i = 0; i < lines.length; i++) {
                if (lines[i].indexOf(iface + ":") !== -1) {
                    // formátum: "wlan0: 0000  61.  -49.  -256  ..."
                    var parts = lines[i].trim().replace(/\./g,"").split(/\s+/)
                    // parts[2] = link quality (0–70 tartomány általában)
                    var q = parseFloat(parts[2]) || 0
                    wifiQuality = Math.min(100, Math.round(q / 70 * 100))
                    break
                }
            }
            netCanvas.requestPaint()
        })
    }

    // ── Interfész keresők ────────────────────────────────────────────────────
    function checkWifi(idx) {
        if (idx >= wifiIfaces.length) { checkEth(0); return }
        readFile("/sys/class/net/" + wifiIfaces[idx] + "/operstate", function(st) {
            if (st === "up") {
                activeIface = wifiIfaces[idx]
                netType     = "wifi"
                readWifiSignal(wifiIfaces[idx])
            } else {
                checkWifi(idx + 1)
            }
        })
    }

    // ── Ethernet keresés ─────────────────────────────────────────────────────
    function checkEth(idx) {
        if (idx >= ethIfaces.length) { netType = "none"; return }
        readFile("/sys/class/net/" + ethIfaces[idx] + "/operstate", function(st) {
            if (st === "up") {
                activeIface = ethIfaces[idx]
                netType     = "ethernet"
                netCanvas.requestPaint()
            } else {
                checkEth(idx + 1)
            }
        })
    }

    function refresh() { checkWifi(0) }

    Component.onCompleted: refresh()

    Timer {
        interval: 15000
        repeat:   true
        running:  true
        onTriggered: networkIndicator.refresh()
    }

    // ── Szín ─────────────────────────────────────────────────────────────────
    function signalColor(q) {
        if (q >= 65) return "#4ade80"  // zöld – erős
        if (q >= 40) return "#facc15"  // sárga – közepes
        return "#fb923c"               // narancs – gyenge
    }

    // ── UI ───────────────────────────────────────────────────────────────────
    Canvas {
        id: netCanvas
        width:  root.font.pointSize * 2.0
        height: root.font.pointSize * 1.6
        anchors.verticalCenter: parent.verticalCenter

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

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            if (networkIndicator.netType === "wifi")
                drawWifi(ctx)
            else if (networkIndicator.netType === "ethernet")
                drawEthernet(ctx)
        }

        // ── WiFi antenna ikon (4 ívelt sáv) ─────────────────────────────
        function drawWifi(ctx) {
            var q    = networkIndicator.wifiQuality
            var cx   = width  / 2
            var base = height * 0.96
            var dot  = height * 0.08

            // Sávok száma a minőség alapján
            var bars = q >= 70 ? 4 : q >= 45 ? 3 : q >= 20 ? 2 : 1
            var col  = networkIndicator.signalColor(q)

            var radii    = [height*0.14, height*0.32, height*0.54, height*0.76]
            var arcStart = Math.PI * 1.25
            var arcEnd   = Math.PI * 1.75

            for (var i = 0; i < 4; i++) {
                ctx.beginPath()
                ctx.arc(cx, base, radii[i], arcStart, arcEnd)
                ctx.strokeStyle = col
                ctx.globalAlpha = i < bars ? 0.90 : 0.22
                ctx.lineWidth   = height * 0.10
                ctx.lineCap     = "round"
                ctx.stroke()
            }

            // Középső pont (antenna)
            ctx.beginPath()
            ctx.arc(cx, base, dot, 0, Math.PI * 2)
            ctx.fillStyle   = col
            ctx.globalAlpha = 0.95
            ctx.fill()
            ctx.globalAlpha = 1.0
        }

        // ── Ethernet dugó ikon ───────────────────────────────────────────
        function drawEthernet(ctx) {
            var col = "#4ade80"
            var lw  = height * 0.09
            ctx.strokeStyle = col
            ctx.fillStyle   = col
            ctx.lineWidth   = lw
            ctx.lineCap     = "round"
            ctx.lineJoin    = "round"
            ctx.globalAlpha = 0.90

            var cx  = width  / 2
            var cy  = height / 2

            // Kábel test (felső téglalap)
            var bw = width  * 0.70
            var bh = height * 0.38
            var bx = cx - bw / 2
            var by = cy - height * 0.30
            rr(ctx, bx, by, bw, bh, height * 0.06)
            ctx.stroke()

            // 3 érintkező pin a téglalapban
            var pinW  = width * 0.08
            var pinH  = height * 0.22
            var pinY  = by - pinH + lw
            var gap   = bw / 4
            for (var p = 0; p < 3; p++) {
                rr(ctx, bx + gap * (p + 0.5) - pinW/2, pinY, pinW, pinH, 2)
                ctx.fill()
            }

            // Kábel vonala lefelé
            ctx.beginPath()
            ctx.moveTo(cx, by + bh)
            ctx.lineTo(cx, cy + height * 0.38)
            ctx.stroke()

            // Dugó alap vonal
            ctx.lineWidth = lw * 1.5
            ctx.beginPath()
            ctx.moveTo(cx - width * 0.22, cy + height * 0.38)
            ctx.lineTo(cx + width * 0.22, cy + height * 0.38)
            ctx.stroke()

            ctx.globalAlpha = 1.0
        }
    }

    // Felirat
    Text {
        id: netLabel
        anchors.verticalCenter: parent.verticalCenter
        text: {
            if (networkIndicator.netType === "ethernet") return "Ethernet"
            return networkIndicator.wifiQuality + "%"
        }
        color:          networkIndicator.netType === "ethernet"
                        ? "#4ade80"
                        : networkIndicator.signalColor(networkIndicator.wifiQuality)
        font.pointSize: root.font.pointSize * 0.82
        font.family:    root.font.family
    }

    onNetTypeChanged: {
        netCanvas.requestPaint()
    }
    onWifiQualityChanged: {
        netCanvas.requestPaint()
    }
}
