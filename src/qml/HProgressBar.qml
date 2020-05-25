/*
 * SPDX-FileCopyrightText: 2020 George Florea Bănuș <georgefb899@gmail.com>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQml 2.13
import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import QtQuick.Shapes 1.13
import org.kde.kirigami 2.11 as Kirigami
import AppSettings 1.0

Slider {
    id: root

    property var chapters
    property bool seekStarted: false

    from: 0
    to: mpv.duration
    implicitWidth: 200
    implicitHeight: 25
    leftPadding: 0
    rightPadding: 0

    handle: Item { visible: false }

    background: Rectangle {
        id: progressBarBackground
        color: Kirigami.Theme.alternateBackgroundColor

        Rectangle {
            width: visualPosition * parent.width
            height: parent.height
            color: Kirigami.Theme.highlightColor
            radius: 0
        }

        ToolTip {
            id: progressBarToolTip

            visible: progressBarMouseArea.containsMouse
            timeout: -1
            delay: 0
        }

        MouseArea {
            id: progressBarMouseArea

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.MiddleButton | Qt.RightButton

            onClicked: {
                if (mouse.button === Qt.MiddleButton) {
                    const time = mouseX * 100 / progressBarBackground.width * root.to / 100
                    const chapters = mpv.getProperty("chapter-list")
                    const nextChapter = chapters.findIndex(chapter => chapter.time > time)
                    mpv.setProperty("chapter", nextChapter)
                }
                if (mouse.button === Qt.RightButton && root.chapters.length > 0) {
                    const menuX = mouse.x-chaptersMenu.width * 0.5
                    const menuY = -((chaptersMenu.count - 1) * chaptersMenu.menuItemHeight + 15)
                    chaptersMenu.popup(root, menuX, menuY)
                }
            }

            onMouseXChanged: {
                progressBarToolTip.x = mouseX - (progressBarToolTip.width * 0.5)

                const time = mouseX * 100 / progressBarBackground.width * root.to / 100
                progressBarToolTip.text = app.formatTime(time)
            }

            onEntered: {
                progressBarToolTip.x = mouseX - (progressBarToolTip.width * 0.5)
                progressBarToolTip.y = root.height
            }
        }
    }

    // create markers for the chapters
    Instantiator {
        id: chaptersInstantiator
        model: chapters
        delegate: Shape {
            id: chapterMarkerShape

            // modelData.time * 100 / mpv.duration is chapter-time percentage
            //  multiplied with progressBarBackground.width / 100 is the percentage at which
            // the chapter marker shoud be positioned on the progress bar
            property int position: modelData.time * 100 / mpv.duration * progressBarBackground.width / 100

            antialiasing: true
            parent: progressBarBackground
            ShapePath {
                id: shape
                strokeWidth: 1
                strokeColor: Kirigami.Theme.textColor
                startX: chapterMarkerShape.position
                startY: root.height
                fillColor: Kirigami.Theme.textColor
                PathLine { x: shape.startX; y: -1 }
                PathLine { x: shape.startX + 6; y: -7 }
                PathLine { x: shape.startX - 7; y: -7 }
                PathLine { x: shape.startX - 1; y: -1 }
            }
            Rectangle {
                x: chapterMarkerShape.position - 8
                y: -11
                width: 15
                height: 11
                color: "transparent"
                ToolTip {
                    id: chapterTitleToolTip
                    text: modelData.title
                    visible: false
                    delay: 0
                    timeout: 10000
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: chapterTitleToolTip.visible = true
                    onExited: chapterTitleToolTip.visible = false
                    onClicked: mpv.setProperty("chapter", index)
                }
            }
        }
    }

    onToChanged: value = mpv.position
    onPressedChanged: {
        if (pressed) {
            seekStarted = true
        } else {
            mpv.command(["seek", value, "absolute"])
            seekStarted = false
        }
    }

    Menu {
        id: chaptersMenu

        property int menuItemHeight
        property var checkedItem

        width: 0
        modal: true

        MenuSeparator {}

        MenuItem {
            id: skipChaptersMenuItem
            text: qsTr("Skip Chapters")
            checkable: true
            checked: AppSettings.skipChapters
            onCheckedChanged: AppSettings.skipChapters = checked
        }

        Instantiator {
            model: root.chapters
            delegate: MenuItem {
                id: menuitem

                checkable: true
                checked: index === chaptersMenu.checkedItem
                text: `${app.formatTime(modelData.time)} - ${modelData.title}`
                Component.onCompleted: {
                    chaptersMenu.width = menuitem.width > chaptersMenu.width
                            ? menuitem.width
                            : chaptersMenu.width
                    chaptersMenu.menuItemHeight = height
                }
                onClicked: {
                    mpv.setProperty("chapter", index)
                }
            }
            onObjectAdded: chaptersMenu.insertItem(index, object)
            onObjectRemoved: chaptersMenu.removeItem(object)
        }
    }

    Connections {
        target: mpv
        onFileLoaded: chapters = mpv.getProperty("chapter-list")
        onChapterChanged: {
            chaptersMenu.checkedItem = mpv.chapter
        }
        onPositionChanged: {
            if (!root.seekStarted) {
                root.value = mpv.position
            }
        }
    }
}
