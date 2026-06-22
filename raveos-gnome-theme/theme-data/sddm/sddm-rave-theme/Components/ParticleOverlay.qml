// Config created by Keyitdev https://git.rp1.hu/gabeszm/sddm-rave-theme
// Copyright (C) 2022-2025 Keyitdev
// Distributed under the GPLv3+ License https://www.gnu.org/licenses/gpl-3.0.html

import QtQuick 2.15

Canvas {
    id: particleCanvas

    anchors.fill: parent

    property int particleCount: 55
    property var particles: []
    property real time: 0

    function initParticles() {
        var arr = []
        for (var i = 0; i < particleCount; i++) {
            arr.push({
                x:          Math.random() * width,
                y:          Math.random() * height,
                vx:         (Math.random() - 0.5) * 0.35,
                vy:         (Math.random() - 0.5) * 0.35,
                baseR:      Math.random() * 2.0 + 0.8,
                hue:        Math.random() * 360,
                hueSpeed:   (Math.random() - 0.5) * 0.4,
                phase:      Math.random() * Math.PI * 2,
                opacity:    Math.random() * 0.45 + 0.15,
                glowR:      Math.random() * 18 + 8
            })
        }
        particles = arr
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)

        for (var i = 0; i < particles.length; i++) {
            var p = particles[i]
            var r = p.baseR * (0.75 + 0.25 * Math.sin(p.phase + time * 2.2))

            // Glow halo
            var grd = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, p.glowR)
            grd.addColorStop(0, "hsla(" + p.hue + ",100%,72%," + (p.opacity * 0.55) + ")")
            grd.addColorStop(1, "hsla(" + p.hue + ",100%,72%,0)")
            ctx.beginPath()
            ctx.arc(p.x, p.y, p.glowR, 0, Math.PI * 2)
            ctx.fillStyle = grd
            ctx.fill()

            // Core dot
            ctx.beginPath()
            ctx.arc(p.x, p.y, r, 0, Math.PI * 2)
            ctx.fillStyle = "hsla(" + p.hue + ",100%,88%," + p.opacity + ")"
            ctx.fill()
        }
    }

    Timer {
        interval: 16
        repeat: true
        running: true
        onTriggered: {
            particleCanvas.time += 0.016
            var pts = particleCanvas.particles
            var W = particleCanvas.width
            var H = particleCanvas.height
            var t = particleCanvas.time
            for (var i = 0; i < pts.length; i++) {
                var p = pts[i]
                p.x += p.vx + Math.sin(t * 0.9 + p.phase) * 0.28
                p.y += p.vy + Math.cos(t * 0.7 + p.phase) * 0.28
                p.hue  += p.hueSpeed
                p.phase += 0.008
                var margin = p.glowR
                if (p.x < -margin)  p.x = W + margin
                if (p.x > W + margin) p.x = -margin
                if (p.y < -margin)  p.y = H + margin
                if (p.y > H + margin) p.y = -margin
            }
            particleCanvas.requestPaint()
        }
    }

    Component.onCompleted: {
        // kis késleltetés hogy a méret biztosan kész legyen
        Qt.callLater(initParticles)
    }
}
