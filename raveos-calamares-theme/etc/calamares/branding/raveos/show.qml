/* === This file is part of Calamares - <https://calamares.io> ===
 *
 *   SPDX-FileCopyrightText: 2015 Teo Mrnjavac <teo@kde.org>
 *   SPDX-FileCopyrightText: 2018 Adriaan de Groot <groot@kde.org>
 *   SPDX-License-Identifier: GPL-3.0-or-later
 *
 *   Calamares is Free Software: see the License-Identifier above.
 *
 */

import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation
{
    id: presentation

    Rectangle {
        anchors.fill: parent
        color: "#2c3e50"
        z: -1 
    }

    function nextSlide() {
        console.log("QML Component (default slideshow) Next slide");
        presentation.goToNextSlide();
    }

    Timer {
        id: advanceTimer
        interval: 10000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: nextSlide()
    }

    Slide {

    anchors.fill: parent
    anchors.verticalCenterOffset: 0

    Image {
        id: background1
        source: "images/2.png"
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        smooth: true
    	}
    }

    Slide {

    anchors.fill: parent
    anchors.verticalCenterOffset: 0

    Image {
        id: background2
        source: "images/3.png"
        width: 815; height: 815
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        smooth: true
    	}
    }
    
    Slide {

    anchors.fill: parent
    anchors.verticalCenterOffset: 0

    Image {
        id: background3
        source: "images/4.png"
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        smooth: true
    	}
    }
    
    Slide {

    anchors.fill: parent
    anchors.verticalCenterOffset: 0

    Image {
        id: background4
        source: "images/5.png"
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        smooth: true
    	}
    }
    
    Slide {

    anchors.fill: parent
    anchors.verticalCenterOffset: 0

    Image {
        id: background5
        source: "images/6.png"
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        smooth: true
    	}
    }
    
    Slide {

    anchors.fill: parent
    anchors.verticalCenterOffset: 0

    Image {
        id: background6
        source: "images/7.png"
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        smooth: true
    	}
    }
    
    Slide {

    anchors.fill: parent
    anchors.verticalCenterOffset: 0

    Image {
        id: background7
        source: "images/8.png"
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        smooth: true
    	}
    }


    // When this slideshow is loaded as a V1 slideshow, only
    // activatedInCalamares is set, which starts the timer (see above).
    //
    // In V2, also the onActivate() and onLeave() methods are called.
    // These example functions log a message (and re-start the slides
    // from the first).
    function onActivate() {
        console.log("QML Component (default slideshow) activated");
        presentation.currentSlide = 0;
    }

    function onLeave() {
        console.log("QML Component (default slideshow) deactivated");
    }

}