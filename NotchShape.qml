pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

// SekaiPop system notch & floating island vector shape with organic morphing,
// 2.5D extruded side-wall thickness, multi-plane parallax, and smooth ColorAnimations.
Item {
    id: root

    property var sekaiTheme: null
    property real s: 1.0
    property bool expanded: false
    property bool settingsOpen: false
    property bool floatingMode: false
    property bool musicMode: false
    property bool showHalftone: true
    property bool showSlants: true
    property real progressRatio: 0.0
    property real bounceOvershoot: 1.65

    // ── 2.5D Properties (User-configurable) ──
    property bool enable25D: true
    property real depth25D: 1.0
    property real parallaxX: 0.0 // Normalized [-1.0 .. +1.0]
    property real parallaxY: 0.0 // Normalized [-1.0 .. +1.0]
    property real trackIntensity: 0.0 // Cursor-tracking intensity for the notch itself (0 = none)

    readonly property real pFactor: root.enable25D ? root.depth25D : 0.0
    readonly property real extrudeDz: root.enable25D
        ? Math.max(2, Math.round((root.expanded ? 4.5 : 3.0) * root.s * root.depth25D))
        : 0

    // Smooth morph factor (0.0 = standard notch, 1.0 = cute vinyl-pod music shape)
    property real musicMorph: (root.musicMode && !root.expanded) ? 1.0 : 0.0
    Behavior on musicMorph {
        NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: root.bounceOvershoot }
    }

    property real slantShift: root.expanded ? 1.0 : 0.0
    Behavior on slantShift {
        NumberAnimation { duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
    }

    property real topRadius: Math.round(8 * s)
    property real bottomRadius: Math.round(14 * s)

    property color fillColor: sekaiTheme ? sekaiTheme.pSurface : "#ffffff"
    property color strokeColor: sekaiTheme ? sekaiTheme.pLine : "#555473"
    property color ringColor: sekaiTheme ? sekaiTheme.pRingWhite : "#ffffff"
    property color shadowColor: sekaiTheme ? sekaiTheme.pLineShadow : "#555473"
    property color extrudeColor: Qt.darker(root.strokeColor, 1.38)
    property color colorTop: sekaiTheme ? sekaiTheme.accentMint : "#00ffcb"
    property color colorBottom: sekaiTheme ? sekaiTheme.accentCyan : "#04feee"
    property color colorCutePink: "#FF9ECB"
    property color dividerColor: sekaiTheme ? sekaiTheme.pSurfaceDivider : "#e4e4ec"

    Behavior on fillColor   { ColorAnimation { duration: 260; easing.type: Easing.OutQuad } }
    Behavior on strokeColor { ColorAnimation { duration: 260; easing.type: Easing.OutQuad } }
    Behavior on ringColor   { ColorAnimation { duration: 260; easing.type: Easing.OutQuad } }
    Behavior on shadowColor { ColorAnimation { duration: 260; easing.type: Easing.OutQuad } }
    Behavior on colorTop    { ColorAnimation { duration: 300; easing.type: Easing.OutQuad } }
    Behavior on colorBottom { ColorAnimation { duration: 300; easing.type: Easing.OutQuad } }

    readonly property real chromeScale: root.expanded ? 1.0 : 0.82
    property real strokeWidth: Math.max(2, Math.round((sekaiTheme ? sekaiTheme.borderWidth : 3) * s * chromeScale))
    property real ringWidth: Math.max(1, Math.round((sekaiTheme ? sekaiTheme.whiteLine : 2) * s * chromeScale))
    property real innerStrokeWidth: Math.max(1, Math.round((sekaiTheme ? sekaiTheme.whiteLine : 2) * s * chromeScale))
    property real shadowOffset: Math.max(2, Math.round((sekaiTheme ? sekaiTheme.shadowOffset : 4) * s * chromeScale))

    readonly property real bodyHeight: Math.max(18, root.height - root.shadowOffset - root.extrudeDz)
    readonly property real ringInset: root.strokeWidth
    readonly property real innerBorderInset: root.strokeWidth + root.ringWidth
    readonly property real surfaceInset: root.strokeWidth + root.ringWidth + root.innerStrokeWidth

    readonly property real topContentInset: root.floatingMode ? root.surfaceInset : 0
    readonly property real bottomContentInset: root.shadowOffset + root.extrudeDz + root.surfaceInset
    readonly property real sideContentInset: root.surfaceInset + (root.floatingMode ? Math.round(4 * root.s) : root.topRadius)
    readonly property real innerSurfaceHeight: Math.max(12, root.bodyHeight - root.surfaceInset - root.topContentInset)
    readonly property real vinylPodStep: Math.round(12 * root.s * root.musicMorph)
    readonly property real plateHeight: root.expanded
        ? Math.round(28 * root.s)
        : root.innerSurfaceHeight

    implicitWidth: parent ? parent.width : 238
    implicitHeight: parent ? parent.height : 40

    component NotchSilhouette: Shape {
        id: sil
        property real inset: 0
        property real targetHeight: root.bodyHeight
        property color fill: "#ffffff"
        property bool useHeaderGradient: false
        property real offsetX: 0
        property real offsetY: 0

        x: sil.offsetX
        y: sil.offsetY
        width: root.width
        height: root.height
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        property ShapeGradient headerGrad: LinearGradient {
                id: headerGrad
                x1: 0
                y1: 0
                x2: root.width
                y2: 0
                GradientStop { position: 0.0; color: root.musicMorph > 0.1 ? root.colorCutePink : root.colorTop }
                GradientStop { position: 0.45; color: root.colorTop }
                GradientStop { position: 1.0; color: root.colorBottom }
            }

        ShapePath {
            id: sp
            strokeWidth: -1
            strokeColor: "transparent"
            fillColor: sil.fill
            fillGradient: sil.useHeaderGradient ? sil.headerGrad : null
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.FlatCap

            readonly property real w: root.width
            readonly property real h: Math.max(6, sil.targetHeight)
            readonly property real ins: sil.inset
            readonly property real topIns: root.floatingMode ? sil.inset : 0
            readonly property real tr: root.floatingMode
                ? 0
                : Math.max(0, Math.min(root.topRadius, (w - 2 * ins) / 5))

            readonly property real hRight: Math.max(topIns + 16, h - root.vinylPodStep)
            readonly property real brLeft: Math.max(3, Math.min(
                (root.bottomRadius + 10 * root.musicMorph * root.s) - ins * 0.6,
                (w - 2 * ins - 2 * tr) / 3,
                (h - topIns) * 0.78
            ))
            readonly property real brRight: Math.max(3, Math.min(
                (root.bottomRadius + 4 * root.musicMorph * root.s) - ins * 0.6,
                (w - 2 * ins - 2 * tr) / 3,
                (hRight - topIns) * 0.75
            ))
            readonly property real podEnd: Math.max(ins + tr + brLeft + 4, Math.min(w * 0.34, Math.round(92 * root.s)))
            readonly property real waveSpan: Math.round(28 * root.s)

            startX: root.floatingMode ? (ins + brLeft) : ins
            startY: topIns

            PathCubic {
                x: root.floatingMode ? sp.ins : (sp.ins + sp.tr)
                y: root.floatingMode ? (sp.topIns + sp.brLeft) : sp.tr
                control1X: root.floatingMode ? (sp.ins + sp.brLeft * 0.4477) : (sp.ins + sp.tr * 0.5523)
                control1Y: sp.topIns
                control2X: root.floatingMode ? sp.ins : (sp.ins + sp.tr)
                control2Y: root.floatingMode ? (sp.topIns + sp.brLeft * 0.4477) : (sp.tr * 0.4477)
            }
            PathLine { x: sp.ins + sp.tr; y: sp.h - sp.brLeft }
            PathCubic {
                x: sp.ins + sp.tr + sp.brLeft
                y: sp.h
                control1X: sp.ins + sp.tr
                control1Y: sp.h - sp.brLeft * 0.4477
                control2X: sp.ins + sp.tr + sp.brLeft * 0.4477
                control2Y: sp.h
            }
            PathLine { x: sp.podEnd; y: sp.h }
            PathCubic {
                x: sp.podEnd + sp.waveSpan
                y: sp.hRight
                control1X: sp.podEnd + sp.waveSpan * 0.5
                control1Y: sp.h
                control2X: sp.podEnd + sp.waveSpan * 0.5
                control2Y: sp.hRight
            }
            PathLine { x: sp.w - sp.ins - sp.tr - sp.brRight; y: sp.hRight }
            PathCubic {
                x: sp.w - sp.ins - sp.tr
                y: sp.hRight - sp.brRight
                control1X: sp.w - sp.ins - sp.tr - sp.brRight * 0.4477
                control1Y: sp.hRight
                control2X: sp.w - sp.ins - sp.tr
                control2Y: sp.hRight - sp.brRight * 0.4477
            }
            PathLine {
                x: sp.w - sp.ins - sp.tr
                y: root.floatingMode ? (sp.topIns + sp.brRight) : sp.tr
            }
            PathCubic {
                x: root.floatingMode ? (sp.w - sp.ins - sp.brRight) : (sp.w - sp.ins)
                y: sp.topIns
                control1X: sp.w - sp.ins - sp.tr
                control1Y: root.floatingMode ? (sp.topIns + sp.brRight * 0.4477) : (sp.tr * 0.4477)
                control2X: root.floatingMode ? (sp.w - sp.ins - sp.brRight * 0.4477) : (sp.w - sp.ins - sp.tr * 0.5523)
                control2Y: sp.topIns
            }
            PathLine {
                x: root.floatingMode ? (sp.ins + sp.brLeft) : sp.ins
                y: sp.topIns
            }
        }
    }

    // 1. Dynamic 2.5D Hard Drop Shadow (shifts opposite to cursor for floating depth)
    NotchSilhouette {
        inset: 0
        targetHeight: root.height
        offsetX: Math.round(-(root.parallaxX * root.trackIntensity) * 3.5 * root.pFactor * root.s)
        offsetY: Math.round((root.parallaxY * root.trackIntensity) * 2.0 * root.pFactor * root.s)
        fill: root.shadowColor
    }

    // 2. 2.5D Extruded Side-Wall / Bevel Block (physical thickness between face & shadow)
    NotchSilhouette {
        visible: root.enable25D
        inset: 0
        targetHeight: root.bodyHeight + root.extrudeDz
        offsetX: Math.round(-(root.parallaxX * root.trackIntensity) * 1.6 * root.pFactor * root.s)
        fill: root.extrudeColor
    }

    // 3. Outer Pill border
    NotchSilhouette {
        inset: 0
        targetHeight: root.bodyHeight
        fill: root.strokeColor
    }

    // 4. White / surface ring
    NotchSilhouette {
        inset: root.ringInset
        targetHeight: root.bodyHeight - root.ringInset
        fill: root.ringColor
    }

    // 5. Inner border around surface
    NotchSilhouette {
        inset: root.innerBorderInset
        targetHeight: root.bodyHeight - root.innerBorderInset
        fill: root.strokeColor
    }

    // 6. Main inner surface
    NotchSilhouette {
        inset: root.surfaceInset
        targetHeight: root.bodyHeight - root.surfaceInset
        fill: root.fillColor
    }

    // 7. Top SekaiPlate Gradient Banner with 2.5D Parallax Slant Stripes
    Item {
        id: headerPlateClip
        x: 0
        y: 0
        width: root.width
        height: root.expanded
            ? (root.topContentInset + root.plateHeight)
            : (root.bodyHeight - root.surfaceInset)
        clip: true

        NotchSilhouette {
            width: root.width
            height: root.height
            inset: root.surfaceInset
            targetHeight: root.bodyHeight - root.surfaceInset
            useHeaderGradient: true
        }

        // 2.5D Specular Glint Bar along the top rim
        Rectangle {
            visible: root.enable25D
            x: root.sideContentInset + Math.round((root.parallaxX * root.trackIntensity) * 10 * root.pFactor * root.s)
            y: root.topContentInset + Math.round(1 * root.s)
            width: Math.max(0, root.width - root.sideContentInset * 2)
            height: Math.max(1, Math.round(2 * root.s))
            radius: height / 2
            color: "#ffffff"
            opacity: 0.55
        }

        Item {
            x: root.sideContentInset
            y: root.topContentInset
            width: Math.max(0, root.width - root.sideContentInset * 2)
            height: parent.height - root.topContentInset
            clip: true
            visible: root.showSlants

            Repeater {
                model: 8
                Rectangle {
                    id: slantBar
                    required property int index
                    width: Math.round(10 * root.s)
                    height: Math.round(88 * root.s)
                    x: Math.round((14 + slantBar.index * 28 + root.slantShift * 8 + (root.parallaxX * root.trackIntensity) * 7 * root.pFactor) * root.s)
                    y: -Math.round(18 * root.s) + Math.round((root.parallaxY * root.trackIntensity) * 3 * root.pFactor * root.s)
                    rotation: 28
                    color: slantBar.index % 2 === 0 ? "#ffffff" : root.strokeColor
                    opacity: slantBar.index % 2 === 0 ? 0.28 : 0.12
                }
            }
        }

        Rectangle {
            visible: root.expanded
            x: root.sideContentInset
            width: Math.max(0, root.width - root.sideContentInset * 2)
            anchors.bottom: parent.bottom
            height: Math.max(1, Math.round(root.ringWidth))
            color: root.strokeColor
        }
    }

    // 8. Expanded Surface Decorations with 2.5D Depth Parallax
    Item {
        id: innerDecor
        x: root.sideContentInset
        y: root.topContentInset
        width: Math.max(0, root.width - root.sideContentInset * 2)
        height: Math.max(0, root.innerSurfaceHeight - root.vinylPodStep)
        clip: true

        Item {
            id: dotField
            visible: root.showHalftone
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: Math.round((8 - (root.parallaxX * root.trackIntensity) * 5 * root.pFactor) * root.s)
            anchors.bottomMargin: Math.round((6 - (root.parallaxY * root.trackIntensity) * 4 * root.pFactor) * root.s)
            width: Math.round(68 * root.s)
            height: Math.round(46 * root.s)
            opacity: root.expanded ? 0.55 : 0.0
            scale: root.expanded ? 1.0 : 0.75
            transformOrigin: Item.BottomRight

            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
            Behavior on scale { NumberAnimation { duration: 360; easing.type: Easing.OutBack; easing.overshoot: 1.8 } }

            Repeater {
                model: 15
                Rectangle {
                    id: dotItem
                    required property int index
                    readonly property int row: Math.floor(dotItem.index / 5)
                    readonly property int col: dotItem.index % 5
                    readonly property real distFactor: (row + col) / 6.0
                    readonly property real dotSize: Math.max(2, Math.round((2.5 + distFactor * 3.5) * root.s))

                    x: Math.round(col * 12 * root.s) - dotSize / 2
                    y: Math.round(row * 12 * root.s) - dotSize / 2
                    width: dotSize
                    height: dotSize
                    radius: dotSize / 2
                    color: (row + col) % 2 === 0 ? root.colorBottom : root.colorTop
                    opacity: 0.25 + distFactor * 0.45
                }
            }
        }

        Item {
            visible: root.showSlants
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: Math.round(58 * root.s)
            height: Math.round(38 * root.s)
            clip: true
            opacity: root.expanded ? 0.35 : 0.0
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }

            Repeater {
                model: 3
                Rectangle {
                    id: bottomSlant
                    required property int index
                    width: Math.round(6 * root.s)
                    height: Math.round(58 * root.s)
                    x: Math.round((6 + bottomSlant.index * 12 - root.slantShift * 4 + (root.parallaxX * root.trackIntensity) * 4 * root.pFactor) * root.s)
                    y: -Math.round(8 * root.s)
                    rotation: 28
                    color: bottomSlant.index === 0 ? root.colorTop : (bottomSlant.index === 1 ? root.colorBottom : root.dividerColor)
                }
            }
        }

        Rectangle {
            visible: root.progressRatio > 0.005 && root.musicMorph < 0.2
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: Math.round(parent.width * Math.max(0, Math.min(1, root.progressRatio)))
            height: Math.max(2, Math.round(3 * root.s))
            radius: height / 2
            color: root.strokeColor
            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }
    }
}