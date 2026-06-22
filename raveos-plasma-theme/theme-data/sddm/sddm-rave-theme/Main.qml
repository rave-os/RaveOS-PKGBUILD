// Config created by gabeszm https://git.rp1.hu/gabeszm/sddm-rave-theme
// Copyright (C) 2022-2025 gabeszm
// Based on https://github.com/MarianArlt/sddm-sugar-dark
// Distributed under the GPLv3+ License https://www.gnu.org/licenses/gpl-3.0.html

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import QtQuick.Effects
import QtMultimedia

import "Components"

Pane {
    id: root

    height: config.ScreenHeight || Screen.height
    width: config.ScreenWidth || Screen.ScreenWidth
    padding: config.ScreenPadding

    LayoutMirroring.enabled: config.RightToLeftLayout == "true" ? true : Qt.application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    palette.window: config.BackgroundColor
    palette.highlight: config.HighlightBackgroundColor
    palette.highlightedText: config.HighlightTextColor
    palette.buttonText: config.HoverSystemButtonsIconsColor

    font.family: config.Font
    font.pointSize: config.FontSize !== "" ? config.FontSize : parseInt(height / 80) || 13

    focus: true

    property bool leftleft: config.HaveFormBackground == "true" &&
                            config.PartialBlur == "false" &&
                            config.FormPosition == "left" &&
                            config.BackgroundHorizontalAlignment == "left"

    property bool leftcenter: config.HaveFormBackground == "true" &&
                              config.PartialBlur == "false" &&
                              config.FormPosition == "left" &&
                              config.BackgroundHorizontalAlignment == "center"

    property bool rightright: config.HaveFormBackground == "true" &&
                              config.PartialBlur == "false" &&
                              config.FormPosition == "right" &&
                              config.BackgroundHorizontalAlignment == "right"

    property bool rightcenter: config.HaveFormBackground == "true" &&
                               config.PartialBlur == "false" &&
                               config.FormPosition == "right" &&
                               config.BackgroundHorizontalAlignment == "center"

    Item {
        id: sizeHelper

        height: parent.height
        width: parent.width
        anchors.fill: parent

        Rectangle {
            id: tintLayer

            height: parent.height
            width: parent.width
            anchors.fill: parent
            z: 1
            color: config.DimBackgroundColor
            opacity: config.DimBackground
        }


        Canvas {
            id: animatedBorder

            width: form.width / 2 + 60 + 6
            height: form.height + 60 + 6
            anchors.centerIn: form
            z: 3

            property real angle: 0
            property real radius: config.RoundCorners !== "" ? parseInt(config.RoundCorners) : 20

            onAngleChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.clearRect(0, 0, width, height);

                var r = radius;
                var x = 3;
                var y = 3;
                var w = width - 6;
                var h = height - 6;

                ctx.beginPath();
                ctx.arc(x + r, y + r, r, Math.PI, 1.5 * Math.PI);
                ctx.lineTo(x + w - r, y);
                ctx.arc(x + w - r, y + r, r, 1.5 * Math.PI, 2 * Math.PI);
                ctx.lineTo(x + w, y + h - r);
                ctx.arc(x + w - r, y + h - r, r, 0, 0.5 * Math.PI);
                ctx.lineTo(x + r, y + h);
                ctx.arc(x + r, y + h - r, r, 0.5 * Math.PI, Math.PI);
                ctx.closePath();

                ctx.save();
                ctx.translate(width / 2, height / 2);
                ctx.rotate(angle);

                var grad = ctx.createLinearGradient(-width / 2, -height / 2, width / 2, height / 2);
                grad.addColorStop(0, "rgba(255, 255, 255, 0.45)");
                grad.addColorStop(0.5, "rgba(255, 255, 255, 0.12)");
                grad.addColorStop(1, "rgba(255, 255, 255, 0.45)");

                ctx.strokeStyle = grad;
                ctx.lineWidth = 2;
                ctx.stroke();
                ctx.restore();
            }

            NumberAnimation on angle {
                loops: Animation.Infinite
                from: 0
                to: 2 * Math.PI
                duration: 5000
            }

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { from: 0.5; to: 0.9; duration: 2500; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 0.9; to: 0.5; duration: 2500; easing.type: Easing.InOutQuad }
            }
        }

        Rectangle {
            id: formBackground

            width: form.width / 2 + 60
            height: form.height + 60
            anchors.centerIn: form
            z: 4

            color: Qt.rgba(1, 1, 1, 0.08)
            border.color: Qt.rgba(1, 1, 1, 0.18)
            border.width: 1
            radius: config.RoundCorners !== "" ? parseInt(config.RoundCorners) : 20
            visible: true
        }

        LoginForm {
            id: form

            height: implicitHeight
            width: parent.width / 2.5
            anchors.left: config.FormPosition == "left" ? parent.left : undefined
            anchors.horizontalCenter: config.FormPosition == "center" ? parent.horizontalCenter : undefined
            anchors.right: config.FormPosition == "right" ? parent.right : undefined
            anchors.verticalCenter: parent.verticalCenter
            z: 5
        }

        Loader {
            id: virtualKeyboard
            source: "Components/VirtualKeyboard.qml"

            // x * 0.4 = x / 2.5
            width: config.KeyboardSize == "" ? parent.width * 0.4 : parent.width * config.KeyboardSize
            anchors.left: config.VirtualKeyboardPosition == "left" ? parent.left : undefined;
            anchors.horizontalCenter: config.VirtualKeyboardPosition == "center" ? parent.horizontalCenter : undefined;
            anchors.right: config.VirtualKeyboardPosition == "right" ? parent.right : undefined;
            z: 100

            state: "hidden"
            property bool keyboardActive: item ? item.active : false

            function switchState() { state = state == "hidden" ? "visible" : "hidden"}
            states: [
                State {
                    name: "visible"
                    PropertyChanges {
                        target: virtualKeyboard
                        y: root.height - virtualKeyboard.height
                        opacity: 1
                    }
                },
                State {
                    name: "hidden"
                    PropertyChanges {
                        target: virtualKeyboard
                        y: root.height - root.height/4
                        opacity: 0
                    }
                }
            ]
            transitions: [
                Transition {
                    from: "hidden"
                    to: "visible"
                    SequentialAnimation {
                        ScriptAction {
                            script: {
                                virtualKeyboard.item.activated = true;
                                Qt.inputMethod.show();
                            }
                        }
                        ParallelAnimation {
                            NumberAnimation {
                                target: virtualKeyboard
                                property: "y"
                                duration: 100
                                easing.type: Easing.OutQuad
                            }
                            OpacityAnimator {
                                target: virtualKeyboard
                                duration: 100
                                easing.type: Easing.OutQuad
                            }
                        }
                    }
                },
                Transition {
                    from: "visible"
                    to: "hidden"
                    SequentialAnimation {
                        ParallelAnimation {
                            NumberAnimation {
                                target: virtualKeyboard
                                property: "y"
                                duration: 100
                                easing.type: Easing.InQuad
                            }
                            OpacityAnimator {
                                target: virtualKeyboard
                                duration: 100
                                easing.type: Easing.InQuad
                            }
                        }
                        ScriptAction {
                            script: {
                                virtualKeyboard.item.activated = false;
                                Qt.inputMethod.hide();
                            }
                        }
                    }
                }
            ]
        }

        Image {
            id: backgroundPlaceholderImage

            z: 10
            source: config.BackgroundPlaceholder
            visible: false
        }

        AnimatedImage {
            id: backgroundImage

            MediaPlayer {
                id: player

                videoOutput: videoOutput
                autoPlay: true
                playbackRate: config.BackgroundSpeed == "" ? 1.0 : config.BackgroundSpeed
                loops: -1
                onPlayingChanged: {
                    console.log("Video started.")
                    backgroundPlaceholderImage.visible = false;
                }
            }

            VideoOutput {
                id: videoOutput

                fillMode: config.CropBackground == "true" ? VideoOutput.PreserveAspectCrop : VideoOutput.PreserveAspectFit
                anchors.fill: parent
            }

            height: parent.height
            width: config.HaveFormBackground == "true" && config.FormPosition != "center" && config.PartialBlur != "true" ? parent.width - formBackground.width : parent.width
            anchors.left: leftleft || leftcenter ? formBackground.right : undefined
            anchors.right: rightright || rightcenter ? formBackground.left : undefined

            horizontalAlignment: config.BackgroundHorizontalAlignment == "left" ?
                                 Image.AlignLeft :
                                 config.BackgroundHorizontalAlignment == "right" ?
                                 Image.AlignRight : Image.AlignHCenter

            verticalAlignment: config.BackgroundVerticalAlignment == "top" ?
                               Image.AlignTop :
                               config.BackgroundVerticalAlignment == "bottom" ?
                               Image.AlignBottom : Image.AlignVCenter

            speed: config.BackgroundSpeed == "" ? 1.0 : config.BackgroundSpeed
            paused: config.PauseBackground == "true" ? 1 : 0
            fillMode: config.CropBackground == "true" ? Image.PreserveAspectCrop : Image.PreserveAspectFit
            asynchronous: true
            cache: true
            clip: true
            mipmap: true

            Component.onCompleted:{
                var fileType = config.Background.substring(config.Background.lastIndexOf(".") + 1)
                const videoFileTypes = ["avi", "mp4", "mov", "mkv", "m4v", "webm"];
                if (videoFileTypes.includes(fileType)) {
                    backgroundPlaceholderImage.visible = true;
                    player.source = Qt.resolvedUrl(config.Background)
                    player.play();
                }
                else{
                    backgroundImage.source = config.background || config.Background
                }
            }
        }

        MouseArea {
            anchors.fill: backgroundImage
            onClicked: parent.forceActiveFocus()
        }

        ShaderEffectSource {
            id: blurMask

            height: form.height + 60
            width: form.width / 2 + 60
            anchors.centerIn: form

            sourceItem: backgroundImage
            sourceRect: Qt.rect(x,y,width,height)
            visible: true
        }

        ShaderEffectSource {
            id: blurMaskItem

            sourceItem: Rectangle {
                width: blurMask.width
                height: blurMask.height
                radius: config.RoundCorners !== "" ? parseInt(config.RoundCorners) : 20
                color: "black"
            }
            hideSource: true
            visible: false
        }

        MultiEffect {
            id: blur
            z: 2

            height: config.FullBlur == "true" ? parent.height : blurMask.height
            width: config.FullBlur == "true" ? parent.width : blurMask.width
            anchors.centerIn: config.FullBlur == "true" ? backgroundImage : form

            source: config.FullBlur == "true" ? backgroundImage : blurMask
            blurEnabled: true
            autoPaddingEnabled: false
            blur: config.Blur == "" ? 2.5 : config.Blur
            blurMax: config.BlurMax == "" ? 48 : config.BlurMax
            visible: true

            maskEnabled: config.FullBlur == "true" ? false : true
            maskSource: blurMaskItem
        }

        ToastNotification {
            id: toast
        }

        Connections {
            target: sddm
            function onLoginFailed() {
                toast.show(config.TranslateLoginFailedWarning || textConstants.loginFailed + "!")
            }
        }
    }
}
