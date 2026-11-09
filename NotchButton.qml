pragma ComponentBehavior: Bound

import QtQuick

// SekaiPop keycap button with 2.5D perspective tilt (Rotation X/Y + extruded bevel),
// Squash & Stretch jelly physics, and staggered entrance animation.
Item {
    id: root

    property var sekaiTheme: null
    property real s: 1.0
    property real buttonWidthScale: 1.0
    property real buttonHeightScale: 1.0
    property real bounceOvershoot: 2.2
    property bool showSlants: true
    property bool enable25D: true
    property int staggerIndex: 0
    property bool entranceActive: true

    property string actionId: ""
    property string icon: ""
    property string label: ""
    property bool pending: false
    property bool editMode: false
    property bool canRemove: true
    property bool isDropTarget: false
    property bool isInsertMode: false
    property bool isBeingDragged: false

    property int accentIndex: 0
    readonly property color accentColor: {
        const cols = root.sekaiTheme ? root.sekaiTheme.attributeColors : null
        return (cols && cols.length > 0)
            ? Qt.color(cols[root.accentIndex % cols.length])
            : (root.sekaiTheme ? root.sekaiTheme.accentMint : "#00ffcb")
    }

    signal clicked()
    signal removeRequested()
    signal dragStarted(real globalX, real globalY)
    signal dragMoved(real globalX, real globalY)
    signal dragEnded(real globalX, real globalY)

    readonly property bool pressed: ma.pressed && !root._dragging
    readonly property bool hovered: ma.containsMouse
    readonly property real baseShadow: Math.max(1, Math.round((root.sekaiTheme ? root.sekaiTheme.shadowOffset : 4) * root.s))
    readonly property real shadowDy: root.enable25D ? Math.round(root.baseShadow * 1.35) : root.baseShadow
    readonly property real borderW: Math.max(1, Math.round((root.sekaiTheme ? root.sekaiTheme.borderWidth : 3) * root.s))
    readonly property real ringW: Math.max(1, Math.round((root.sekaiTheme ? root.sekaiTheme.whiteLine : 2) * root.s))
    readonly property real cornerR: Math.round(11 * root.s)

    // 2.5D Mouse Tilt Angles
    readonly property real normX: (root.hovered && root.width > 0) ? ((ma.mouseX / root.width) - 0.5) * 2.0 : 0.0
    readonly property real normY: (root.hovered && root.height > 0) ? ((ma.mouseY / root.height) - 0.5) * 2.0 : 0.0

    property real jellyX: 1.0
    property real jellyY: 1.0
    property real entranceScale: 1.0
    property real iconWiggle: 0.0

    property bool _dragging: false
    property real _pressX: 0
    property real _pressY: 0

    function triggerJellyPop(): void {
        jellyAnim.restart()
        wiggleAnim.restart()
    }

    onPendingChanged: root.triggerJellyPop()
    onIsDropTargetChanged: if (root.isDropTarget) root.triggerJellyPop()
    onHoveredChanged: if (root.hovered && !root.pressed) wiggleAnim.restart()
    onEntranceActiveChanged: {
        if (root.entranceActive) {
            root.entranceScale = 0.72
            staggerTimer.restart()
        }
    }

    Timer {
        id: staggerTimer
        interval: Math.min(220, root.staggerIndex * 24)
        onTriggered: entranceAnim.restart()
    }

    NumberAnimation {
        id: entranceAnim
        target: root; property: "entranceScale"
        from: 0.72; to: 1.0; duration: 320
        easing.type: Easing.OutBack; easing.overshoot: root.bounceOvershoot
    }

    ParallelAnimation {
        id: jellyAnim
        SequentialAnimation {
            NumberAnimation { target: root; property: "jellyX"; to: 1.12; duration: 75; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "jellyX"; to: 0.94; duration: 110; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "jellyX"; to: 1.0; duration: 240; easing.type: Easing.OutBack; easing.overshoot: root.bounceOvershoot }
        }
        SequentialAnimation {
            NumberAnimation { target: root; property: "jellyY"; to: 0.86; duration: 75; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "jellyY"; to: 1.08; duration: 110; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "jellyY"; to: 1.0; duration: 240; easing.type: Easing.OutBack; easing.overshoot: root.bounceOvershoot }
        }
    }

    SequentialAnimation {
        id: wiggleAnim
        NumberAnimation { target: root; property: "iconWiggle"; to: -14; duration: 65; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "iconWiggle"; to: 12; duration: 85; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "iconWiggle"; to: -6; duration: 75; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "iconWiggle"; to: 0; duration: 120; easing.type: Easing.OutBack; easing.overshoot: 2.0 }
    }

    implicitWidth: Math.round(110 * root.s * root.buttonWidthScale)
    implicitHeight: Math.round(32 * root.s * root.buttonHeightScale) + root.shadowDy

    opacity: root.isBeingDragged ? 0.35 : 1.0
    rotation: root.pending ? -2.2 : (root.editMode ? (root.accentIndex % 2 === 0 ? -1.0 : 1.0) : 0.0)

    Behavior on opacity { NumberAnimation { duration: 120 } }
    Behavior on rotation { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: root.bounceOvershoot } }

    transform: [
        Scale {
            origin.x: root.width / 2; origin.y: root.height / 2
            xScale: root.entranceScale * (root.pressed ? 1.06 : (root.isDropTarget ? 1.06 : (root.hovered ? 1.03 : 1.0))) * root.jellyX
            yScale: root.entranceScale * (root.pressed ? 0.88 : (root.isDropTarget ? 1.06 : (root.hovered ? 1.03 : 1.0))) * root.jellyY
            Behavior on xScale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: root.bounceOvershoot } }
            Behavior on yScale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: root.bounceOvershoot } }
        },
        Rotation {
            origin.x: root.width / 2; origin.y: root.height / 2
            axis { x: 1; y: 0; z: 0 }
            angle: root.enable25D ? (root.pressed ? 9 : -root.normY * 11) : 0
            Behavior on angle { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        },
        Rotation {
            origin.x: root.width / 2; origin.y: root.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: root.enable25D ? (root.normX * 13) : 0
            Behavior on angle { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }
    ]

    Rectangle {
        visible: root.isDropTarget && root.isInsertMode
        x: -Math.round(5 * root.s); y: Math.round(2 * root.s)
        width: Math.round(4 * root.s)
        height: parent.height - root.shadowDy - Math.round(4 * root.s)
        radius: width / 2
        color: root.sekaiTheme ? root.sekaiTheme.accentMint : "#00ffcb"
        border.width: 1; border.color: root.sekaiTheme ? root.sekaiTheme.colBorder : "#555473"
        z: 10
    }

    // 2.5D Extruded Keycap Shadow
    Rectangle {
        id: shadowRect
        x: root.enable25D ? Math.round(-root.normX * 2.5 * root.s) : 0
        y: root.shadowDy
        width: parent.width
        height: parent.height - root.shadowDy
        radius: root.cornerR
        color: root.sekaiTheme ? root.sekaiTheme.pLineShadow : "#555473"
        Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
    }

    Item {
        id: keycap
        x: root.isDropTarget && root.isInsertMode ? Math.round(4 * root.s) : 0
        y: root.pressed ? Math.max(1, root.shadowDy - 1) : (root.hovered ? -Math.round((root.enable25D ? 2.5 : 1.5) * root.s) : 0)
        width: parent.width
        height: parent.height - root.shadowDy

        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.8 } }
        Behavior on y { NumberAnimation { duration: 130; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

        Rectangle {
            anchors.fill: parent
            radius: root.cornerR
            color: root.isDropTarget
                ? (root.sekaiTheme ? root.sekaiTheme.accentMint : "#00ffcb")
                : (root.sekaiTheme ? root.sekaiTheme.pLine : "#555473")
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: root.borderW
            radius: Math.max(2, root.cornerR - root.borderW)
            color: root.isDropTarget
                ? (root.sekaiTheme ? root.sekaiTheme.accentCyan : "#04feee")
                : (root.sekaiTheme ? root.sekaiTheme.pRingWhite : "#ffffff")
        }

        Rectangle {
            id: face
            anchors.fill: parent
            anchors.margins: root.borderW + root.ringW
            radius: Math.max(2, root.cornerR - root.borderW - root.ringW)
            clip: true
            color: {
                const baseFill = root.sekaiTheme ? root.sekaiTheme.chipFill : "#555473"
                const warn = root.sekaiTheme ? root.sekaiTheme.warnFill : "#ffb74d"
                if (root.pending) return warn
                if (root.isDropTarget) return Qt.lighter(baseFill, 1.28)
                return root.hovered ? Qt.lighter(baseFill, 1.18) : baseFill
            }

            Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }

            // 2.5D Top Bevel Highlight
            Rectangle {
                visible: root.enable25D
                anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                height: Math.round(parent.height * 0.42)
                radius: parent.radius
                color: "#ffffff"
                opacity: root.hovered ? 0.16 : 0.08
            }

            Rectangle {
                visible: root.showSlants
                width: Math.round(14 * root.s)
                height: parent.height * 2.2
                x: root.hovered ? Math.round(parent.width * 0.76) : Math.round(parent.width * 0.58)
                y: -parent.height * 0.5
                rotation: 26
                color: root.pending ? "#ffffff" : root.accentColor
                opacity: root.pending ? 0.38 : (root.hovered ? 0.32 : 0.14)
                Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
            }

            Item {
                anchors.left: parent.left; anchors.leftMargin: Math.round(5 * root.s)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(10 * root.s); height: Math.round(10 * root.s)

                Rectangle {
                    visible: !root.editMode
                    anchors.centerIn: parent
                    width: Math.round(6 * root.s); height: Math.round(6 * win_s)
                    readonly property real win_s: root.s
                    radius: Math.round(1.5 * root.s)
                    rotation: root.hovered ? 135 : 45
                    scale: root.hovered ? 1.2 : 1.0
                    color: root.pending ? (root.sekaiTheme ? root.sekaiTheme.colBorder : "#555473") : root.accentColor
                    border.width: 1
                    border.color: root.pending ? "#ffffff" : (root.sekaiTheme ? root.sekaiTheme.pRingWhite : "#ffffff")
                    Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }
                }

                Text {
                    visible: root.editMode
                    anchors.centerIn: parent
                    text: "drag_indicator"
                    color: root.accentColor
                    font.family: root.sekaiTheme ? root.sekaiTheme.iconFont : "Material Symbols Rounded"
                    font.pixelSize: Math.round(12 * root.s)
                }
            }

            Row {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: Math.round(2 * root.s)
                spacing: Math.round(4 * root.s)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.pending ? "warning" : root.icon
                    rotation: root.iconWiggle
                    color: root.pending ? (root.sekaiTheme ? root.sekaiTheme.colBorder : "#555473") : (root.sekaiTheme ? root.sekaiTheme.chipInk : "#ffffff")
                    font.family: root.sekaiTheme ? root.sekaiTheme.iconFont : "Material Symbols Rounded"
                    font.pixelSize: Math.round(14 * root.s)
                    font.weight: Font.Bold
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.pending ? "Confirm?" : root.label
                    color: root.pending ? (root.sekaiTheme ? root.sekaiTheme.colBorder : "#555473") : (root.sekaiTheme ? root.sekaiTheme.chipInk : "#ffffff")
                    font.family: root.sekaiTheme ? root.sekaiTheme.fontFamily : "Noto Sans"
                    font.pixelSize: Math.round(10.5 * root.s)
                    font.weight: Font.ExtraBold
                    font.styleName: root.sekaiTheme ? root.sekaiTheme.fontStyleBold : "ExtraBold"
                }
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: root.editMode
        cursorShape: root.editMode ? (root._dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.PointingHandCursor

        onPressed: mouse => {
            root._pressX = mouse.x; root._pressY = mouse.y; root._dragging = false
        }
        onPositionChanged: mouse => {
            if (!pressed || !root.editMode) return
            const dx = mouse.x - root._pressX; const dy = mouse.y - root._pressY
            const pt = root.mapToItem(null, mouse.x, mouse.y)
            if (!root._dragging && (dx * dx + dy * dy) > 25) {
                root._dragging = true; root.dragStarted(pt.x, pt.y)
            }
            if (root._dragging) root.dragMoved(pt.x, pt.y)
        }
        onReleased: mouse => {
            if (root._dragging) {
                const pt = root.mapToItem(null, mouse.x, mouse.y)
                root._dragging = false; root.dragEnded(pt.x, pt.y)
                return
            }
            root.triggerJellyPop()
            if (!root.editMode) root.clicked()
        }
        onCanceled: {
            if (root._dragging) { root._dragging = false; root.dragEnded(-1, -1) }
        }
    }

    Rectangle {
        id: removeBadge
        visible: root.editMode && root.canRemove && !root.isBeingDragged
        anchors.top: parent.top; anchors.right: parent.right
        anchors.topMargin: -Math.round(3 * root.s); anchors.rightMargin: -Math.round(3 * root.s)
        width: Math.round(16 * root.s); height: Math.round(16 * root.s); radius: width / 2
        color: "#ff5c9a"
        border.width: Math.max(1, Math.round(1.5 * root.s))
        border.color: root.sekaiTheme ? root.sekaiTheme.colBorder : "#555473"
        scale: remMa.containsMouse ? 1.18 : 1.0
        z: 5

        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

        Text {
            anchors.centerIn: parent; text: "close"; color: "#ffffff"
            font.family: root.sekaiTheme ? root.sekaiTheme.iconFont : "Material Symbols Rounded"
            font.pixelSize: Math.round(10 * root.s); font.weight: Font.Bold
        }

        MouseArea {
            id: remMa
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: root.removeRequested()
        }
    }
}