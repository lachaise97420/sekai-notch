pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
// Standalone: no Ryoku dependency. Uses built-in Sekai theme tokens.
import Ryoku.PluginKit.Singletons

PanelWindow {
    id: win

    property var targetScreen: null
    screen: targetScreen

    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.namespace: "sekai-notch"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors { top: true; left: true; right: true }
    implicitHeight: Math.round(780 * s)

    // ════════════════════════════════════════════════════════════════════════
    // 1. SCALING, GEOMETRY & CUSTOMIZATION PROPERTIES
    // ════════════════════════════════════════════════════════════════════════
    readonly property real uiScale: 1.0
    readonly property real baseScale: Math.max(0.85, Math.min(1.35, uiScale))

    property real userScale: 1.0           // Slider "TAILLE" (0.80 .. 1.35)
    property real widthFactor: 1.0         // Slider "LARGEUR" (0.80 .. 1.55)
    property real heightFactor: 1.0        // Slider "LONGUEUR" (0.85 .. 1.45)

    property bool floatingMode: false      // Floating Island mode vs Attached Notch
    property bool musicNotchEnabled: true  // Morph into Cute Vinyl-Pod Shape when music plays
    property real horizOffset: 0.0         // Horizontal alignment (-0.35 Left .. 0.0 Center .. +0.35 Right)
    property int gridColumns: 4            // Actions grid columns (horizontal)

    property int customTopRadius: 10       // Top flare radius
    property int customBottomRadius: 15    // Bottom corner radius
    property int customBorderWidth: 3      // Outer/inner navy outline width
    property int customShadowOffset: 4     // Hard shadow offset

    property bool showHalftone: true       // DotField halftone toggle
    property bool showSlants: true         // Slant oblique stripes toggle

    property string surfaceMode: "classic" // "classic" | "dark" | "darker"
    property string selectedUnitTheme: "vs"// "vs" | "nightcord" | "vbs" | "wxs" | "mmj" | "leoneed" | "mono" | "matugen"
    property string collapsedMode: "sekai" // "sekai" | "clock" | "media" | "stats"

    property bool pinned: false            // Pin notch open (disables autoclose)
    property int autoCloseDelay: 700       // Autoclose delay in ms (300 .. 2500)
    property real bounceOvershoot: 1.75    // Easing.OutBack overshoot (1.0 .. 2.6)

    readonly property real s: baseScale * userScale
    readonly property bool cuteMusicCollapsed: !win.expanded && win.mediaPlaying && win.musicNotchEnabled

    // ════════════════════════════════════════════════════════════════════════
    // 2. ORGANIC JELLY PHYSICS, PAGE TRANSITIONS & BURST PARTICLES
    // ════════════════════════════════════════════════════════════════════════
    property real notchJellyX: 1.0
    property real notchJellyY: 1.0
    property real pageSlideOffset: 0.0
    property real pageTransitionScale: 1.0
    property real pageTransitionOpacity: 1.0
    property real burstProgress: 1.0

    // Trigger organic Squash & Stretch on the whole Notch container
    function triggerNotchJelly(intensity: real): void {
        notchExpandJelly.stop()
        jellyStepX1.to = 1.0 + 0.055 * intensity
        jellyStepY1.to = 1.0 - 0.050 * intensity
        jellyStepX2.to = 1.0 - 0.028 * intensity
        jellyStepY2.to = 1.0 + 0.032 * intensity
        notchExpandJelly.start()
    }

    ParallelAnimation {
        id: notchExpandJelly
        SequentialAnimation {
            NumberAnimation { id: jellyStepX1; target: win; property: "notchJellyX"; to: 1.05; duration: 85; easing.type: Easing.OutQuad }
            NumberAnimation { id: jellyStepX2; target: win; property: "notchJellyX"; to: 0.97; duration: 115; easing.type: Easing.InOutQuad }
            NumberAnimation { target: win; property: "notchJellyX"; to: 1.0; duration: 320; easing.type: Easing.OutBack; easing.overshoot: win.bounceOvershoot }
        }
        SequentialAnimation {
            NumberAnimation { id: jellyStepY1; target: win; property: "notchJellyY"; to: 0.95; duration: 85; easing.type: Easing.OutQuad }
            NumberAnimation { id: jellyStepY2; target: win; property: "notchJellyY"; to: 1.03; duration: 115; easing.type: Easing.InOutQuad }
            NumberAnimation { target: win; property: "notchJellyY"; to: 1.0; duration: 320; easing.type: Easing.OutBack; easing.overshoot: win.bounceOvershoot }
        }
    }

    // Directional Slide + Pop Transition when switching pages
    ParallelAnimation {
        id: pageSwitchAnim
        NumberAnimation {
            target: win
            property: "pageSlideOffset"
            to: 0.0
            duration: 310
            easing.type: Easing.OutBack
            easing.overshoot: win.bounceOvershoot
        }
        NumberAnimation {
            target: win
            property: "pageTransitionScale"
            from: 0.93
            to: 1.0
            duration: 290
            easing.type: Easing.OutBack
            easing.overshoot: win.bounceOvershoot
        }
        NumberAnimation {
            target: win
            property: "pageTransitionOpacity"
            from: 0.35
            to: 1.0
            duration: 180
            easing.type: Easing.OutQuad
        }
    }

    // Cute Star/Heart Burst Particle Animation on Cheer or Music Event
    NumberAnimation {
        id: burstAnim
        target: win
        property: "burstProgress"
        from: 0.0
        to: 1.0
        duration: 540
        easing.type: Easing.OutCubic
    }

    property int currentPage: 0
    property real pageOpacity: 1.0
    property real pageShift: 0.0
    onCurrentPageChanged: {
        if (!win.expanded) { win.pageOpacity = 1.0; win.pageShift = 0.0; return; }
        win.pageOpacity = 0.0
        win.pageShift = -28
        pageFadeTimer.restart()
    }
    Timer { id: pageFadeTimer; interval: 110; onTriggered: { win.pageOpacity = 1.0; win.pageShift = 0.0 } }
    property int settingsTab: 0 // 0 = LAYOUT, 1 = STYLE, 2 = ACTIONS

    property string musicDisplayMode: "vinyl" // "vinyl" | "tape" | "stage"
    property int musicCombo: 39
    property string musicJudgeText: "PERFECT! ★"
    property real judgePopScale: 1.0

    function triggerMusicCheer(judgeLabel: string): void {
        win.musicCombo++
        win.musicJudgeText = judgeLabel
        judgePopAnim.restart()
        burstAnim.restart()
        win.triggerNotchJelly(0.75)
        leftDiamond.triggerBeat()
        rightDiamond.triggerBeat()
    }

    NumberAnimation {
        id: judgePopAnim
        target: win
        property: "judgePopScale"
        from: 1.48
        to: 1.0
        duration: 360
        easing.type: Easing.OutBack
        easing.overshoot: 2.5
    }

    readonly property var pageTabs: [
        { idx: 0, icon: "grid_view",       label: "ACT" },
        { idx: 1, icon: "music_note",      label: "MUS" },
        { idx: 2, icon: "space_dashboard", label: "WKS" },
        { idx: 3, icon: "schedule",        label: "CLK" },
        { idx: 4, icon: "monitoring",      label: "SYS" },
        { idx: 5, icon: "inventory_2",     label: "DRP" }
    ]

    function switchPage(nextPage: int): void {
        const count = win.pageTabs.length
        const target = ((nextPage % count) + count) % count
        if (target === win.currentPage)
            return
        const dir = target > win.currentPage ? 1 : -1
        win.currentPage = target
        win.pageSlideOffset = dir * Math.round(28 * win.s)
        pageSwitchAnim.restart()
        win.triggerNotchJelly(0.65)
        leftDiamond.triggerBeat()
        rightDiamond.triggerBeat()
        win.refreshLiveState()
    }

    // ════════════════════════════════════════════════════════════════════════
    // 3. CLOCK, POMODORO TIMER & AUDIO VISUALIZER / TURNTABLE STATE
    // ════════════════════════════════════════════════════════════════════════
    property bool enable25D: true          // Master 2.5D toggle
    property real parallaxX: 0.0
    property real parallaxY: 0.0
    property real notchTrack25D: 0.0       // Slider "SUIVI NOTCH" (0.00 .. 1.80) - 0 = notch stays static
    property real cursorTrack25D: 1.0      // Slider "SUIVI CURSEUR" (0.00 .. 1.80)
    property var now: new Date()
    property bool use24h: true
    readonly property int hh: win.now.getHours()
    readonly property int mm: win.now.getMinutes()
    readonly property int ss: win.now.getSeconds()
    readonly property bool pm: win.hh >= 12
    readonly property string hhStr: {
        const h = win.use24h ? win.hh : (win.hh % 12 === 0 ? 12 : win.hh % 12)
        return (h < 10 ? "0" : "") + h
    }
    readonly property string mmStr: (win.mm < 10 ? "0" : "") + win.mm
    readonly property string ssStr: (win.ss < 10 ? "0" : "") + win.ss

    property int pomoTotalSec: 1500
    property int pomoRemainSec: 1500
    property bool pomoRunning: false
    readonly property real pomoProgress: win.pomoTotalSec > 0
        ? Math.max(0.0, Math.min(1.0, (win.pomoTotalSec - win.pomoRemainSec) / win.pomoTotalSec))
        : 0.0
    readonly property string pomoMinStr: {
        const m = Math.floor(win.pomoRemainSec / 60)
        return (m < 10 ? "0" : "") + m
    }
    readonly property string pomoSecStr: {
        const sc = win.pomoRemainSec % 60
        return (sc < 10 ? "0" : "") + sc
    }

    function setPomoPreset(minutes: int): void {
        win.pomoRunning = false
        win.pomoTotalSec = Math.max(60, minutes * 60)
        win.pomoRemainSec = win.pomoTotalSec
        win.triggerNotchJelly(0.6)
        leftDiamond.triggerBeat()
        rightDiamond.triggerBeat()
    }

    function addPomoMinute(): void {
        win.pomoTotalSec += 60
        win.pomoRemainSec += 60
        win.triggerNotchJelly(0.5)
        leftDiamond.triggerBeat()
    }

    property string visualizerStyle: "bars"
    property int vizPhase: 0
    property real discAngle: 0
    property var vizPoints: [0.25, 0.55, 0.85, 0.40, 0.70, 0.95, 0.50, 0.30, 0.75, 0.60, 0.35, 0.80]

    Timer {
        id: clockAndPomoTimer
        interval: 1000
        repeat: true
        running: win.expanded || win.pomoRunning || win.collapsedMode === "clock"
        onTriggered: {
            win.now = new Date()
            if (win.pomoRunning) {
                if (win.pomoRemainSec > 0) {
                    win.pomoRemainSec--
                } else {
                    win.pomoRunning = false
                    win.triggerMusicCheer("TIME UP! ★")
                }
            }
        }
    }

    Timer {
        id: vizTimer
        interval: 110
        repeat: true
        running: win.mediaPlaying && (win.expanded || win.musicNotchEnabled || win.collapsedMode === "media")
        onTriggered: {
            win.vizPhase = (win.vizPhase + 1) % 360
            win.discAngle = (win.discAngle + 6) % 360
            const pts = []
            for (let i = 0; i < 12; i++) {
                const v = 0.22 + 0.38 * Math.abs(Math.sin((win.vizPhase * 0.45) + i * 0.7))
                               + 0.35 * Math.abs(Math.cos((win.vizPhase * 0.25) - i * 1.1))
                pts.push(Math.min(1.0, v))
            }
            win.vizPoints = pts
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // 4. LIVE SYSTEM STATE (WORKSPACES, MPRIS, CONNECTIVITY, STATS, CLIPBOARD)
    // ════════════════════════════════════════════════════════════════════════
    readonly property string liveStatePath: "/tmp/sekai-notch-live.json"
    property int activeWorkspace: 1
    property var workspacesList: [
        { id: 1, idx: 1, active: true,  occupied: true,  windows: 1 },
        { id: 2, idx: 2, active: false, occupied: false, windows: 0 },
        { id: 3, idx: 3, active: false, occupied: false, windows: 0 },
        { id: 4, idx: 4, active: false, occupied: false, windows: 0 },
        { id: 5, idx: 5, active: false, occupied: false, windows: 0 },
        { id: 6, idx: 6, active: false, occupied: false, windows: 0 }
    ]

    property bool mediaActive: false
    property bool mediaPlaying: false
    property string mediaTitle: "Tell Your World"
    property string mediaArtist: "Virtual Singer ★ Sekai"
    property string mediaArtUrl: ""
    property string mediaPlayerName: "Sekai Stage"
    property real mediaPosSec: 0
    property real mediaLenSec: 0
    property string mediaLyricLine: "♪ Sing a song across the Sekai! ♡"
    readonly property real mediaProgress: win.mediaLenSec > 0
        ? Math.max(0.0, Math.min(1.0, win.mediaPosSec / win.mediaLenSec))
        : 0.35

    readonly property string mediaPosFormatted: {
        const m = Math.floor(win.mediaPosSec / 60)
        const sc = Math.floor(win.mediaPosSec % 60)
        return m + ":" + (sc < 10 ? "0" : "") + sc
    }
    readonly property string mediaLenFormatted: {
        if (win.mediaLenSec <= 0) return "--:--"
        const m = Math.floor(win.mediaLenSec / 60)
        const sc = Math.floor(win.mediaLenSec % 60)
        return m + ":" + (sc < 10 ? "0" : "") + sc
    }

    property bool wifiEnabled: true
    property bool btEnabled: true
    property bool dndEnabled: false
    property int volumePct: 65
    property bool volumeMuted: false
    property int brightnessPct: 80

    property int cpuPct: 14
    property int ramPct: 42
    property int gpuPct: 18
    property int tempC: 48

    property var clipboardItems: ["sekai-notch", "hyprctl reload", "rgba(4, 254, 238, 1.0)"]
    property var droppedShelfItems: []

    FileView {
        id: liveStateFile
        path: win.liveStatePath
        watchChanges: true
        printErrors: false
        onLoaded: win._parseLiveState()
        onFileChanged: liveStateFile.reload()
    }

    Process {
        id: pollStateProc
        command: [
            "sh", "-c",
            "python3 -c '
import json, subprocess, os, glob

out = {
    \"activeWs\": 1,
    \"workspaces\": [],
    \"media\": {\"active\": False, \"playing\": False, \"title\": \"\", \"artist\": \"\", \"artUrl\": \"\", \"player\": \"\", \"pos\": 0.0, \"len\": 0.0, \"lyric\": \"\"},
    \"conn\": {\"wifi\": True, \"ssid\": \"Wi-Fi\", \"bt\": False, \"dnd\": False, \"vol\": 65, \"muted\": False, \"bright\": 80},
    \"stats\": {\"cpu\": 12, \"ram\": 40, \"gpu\": 10, \"temp\": 46},
    \"clips\": []
}

def run(cmd):
    try:
        return subprocess.check_output(cmd, stderr=subprocess.DEVNULL, timeout=0.7).decode(\"utf-8\", \"ignore\").strip()
    except Exception:
        return \"\"

# 1. Workspaces (Niri & Hyprland)
ws_map = {}
active_ws = 1
if os.environ.get(\"NIRI_SOCKET\"):
    raw = run([\"niri\", \"msg\", \"-j\", \"workspaces\"])
    if raw:
        try:
            for w in json.loads(raw):
                idx = int(w.get(\"idx\", w.get(\"id\", 1)))
                is_act = bool(w.get(\"is_active\", False))
                is_occ = bool(w.get(\"active_window_id\") is not None or is_act)
                if is_act: active_ws = idx
                ws_map[idx] = {\"id\": idx, \"idx\": idx, \"active\": is_act, \"occupied\": is_occ, \"windows\": 1 if is_occ else 0}
        except Exception:
            pass
elif os.environ.get(\"HYPRLAND_INSTANCE_SIGNATURE\"):
    raw_act = run([\"hyprctl\", \"activeworkspace\", \"-j\"])
    if raw_act:
        try: active_ws = int(json.loads(raw_act).get(\"id\", 1))
        except Exception: pass
    raw_ws = run([\"hyprctl\", \"workspaces\", \"-j\"])
    if raw_ws:
        try:
            for w in json.loads(raw_ws):
                wid = int(w.get(\"id\", 1))
                if wid > 0:
                    wins = int(w.get(\"windows\", 0))
                    ws_map[wid] = {\"id\": wid, \"idx\": wid, \"active\": wid == active_ws, \"occupied\": wins > 0 or wid == active_ws, \"windows\": wins}
        except Exception:
            pass

max_ws = min(10, max([6, active_ws] + list(ws_map.keys())))
for i in range(1, max_ws + 1):
    if i in ws_map:
        ws_map[i][\"active\"] = (i == active_ws)
        out[\"workspaces\"].append(ws_map[i])
    else:
        out[\"workspaces\"].append({\"id\": i, \"idx\": i, \"active\": i == active_ws, \"occupied\": i == active_ws, \"windows\": 0})
out[\"activeWs\"] = active_ws

# 2. MPRIS Media + Position + Lyrics metadata
m_raw = run([\"playerctl\", \"metadata\", \"--format\", \"{{status}}\\t{{playerName}}\\t{{title}}\\t{{artist}}\\t{{mpris:artUrl}}\\t{{position}}\\t{{mpris:length}}\\t{{xesam:asText}}\"])
if m_raw:
    parts = m_raw.splitlines()[0].split(\"\\t\")
    if len(parts) >= 7:
        st, pl, ti, ar, art, pos_s, len_s = parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], parts[6]
        lyric_s = parts[7] if len(parts) > 7 and parts[7] else f\"♪ {ar or pl} — {ti} ♡\"
        try: pos_v = float(pos_s) / 1000000.0
        except Exception: pos_v = 0.0
        try: len_v = float(len_s) / 1000000.0
        except Exception: len_v = 0.0
        out[\"media\"] = {
            \"active\": st in (\"Playing\", \"Paused\"),
            \"playing\": st == \"Playing\",
            \"title\": ti or \"Unknown Track\",
            \"artist\": ar or pl,
            \"artUrl\": art or \"\",
            \"player\": pl or \"\",
            \"pos\": round(pos_v, 1),
            \"len\": round(len_v, 1),
            \"lyric\": lyric_s[:64]
        }

# 3. Connectivity, Volume & Brightness
vol_raw = run([\"wpctl\", \"get-volume\", \"@DEFAULT_AUDIO_SINK@\"])
if vol_raw:
    out[\"conn\"][\"muted\"] = (\"MUTED\" in vol_raw)
    try:
        v_num = float(vol_raw.split(\":\")[1].strip().split()[0])
        out[\"conn\"][\"vol\"] = max(0, min(100, int(round(v_num * 100))))
    except Exception:
        pass

br_raw = run([\"brightnessctl\", \"-m\"])
if br_raw:
    try:
        for p in br_raw.split(\",\"):
            if p.endswith(\"%\"):
                out[\"conn\"][\"bright\"] = int(p[:-1])
                break
    except Exception:
        pass

# 4. System Stage Stats (CPU / RAM / Temp / GPU)
try:
    with open(\"/proc/meminfo\") as f:
        mem = {}
        for line in f:
            k, v = line.split(\":\", 1)
            mem[k.strip()] = int(v.strip().split()[0])
        total = mem.get(\"MemTotal\", 1)
        avail = mem.get(\"MemAvailable\", total // 2)
        out[\"stats\"][\"ram\"] = int(round((total - avail) * 100.0 / total))
except Exception:
    pass

try:
    with open(\"/proc/loadavg\") as f:
        ld = float(f.read().split()[0])
        cpus = os.cpu_count() or 8
        out[\"stats\"][\"cpu\"] = max(2, min(100, int(round((ld / cpus) * 100))))
except Exception:
    pass

for tpath in glob.glob(\"/sys/class/thermal/thermal_zone*/temp\"):
    try:
        with open(tpath) as f:
            tv = int(f.read().strip()) // 1000
            if 25 <= tv <= 110:
                out[\"stats\"][\"temp\"] = tv
                break
    except Exception:
        pass

nv_raw = run([\"nvidia-smi\", \"--query-gpu=utilization.gpu,temperature.gpu\", \"--format=csv,noheader,nounits\"])
if nv_raw:
    try:
        g_u, g_t = [int(x.strip()) for x in nv_raw.splitlines()[0].split(\",\")]
        out[\"stats\"][\"gpu\"] = g_u
        out[\"stats\"][\"temp\"] = max(out[\"stats\"][\"temp\"], g_t)
    except Exception:
        pass

# 5. Clipboard History (cliphist or wl-paste)
cl_raw = run([\"cliphist\", \"list\"])
if cl_raw:
    items = []
    for ln in cl_raw.splitlines()[:5]:
        txt = ln.split(\"\\t\", 1)[-1].strip()
        if txt and not txt.startswith(\"[[ binary\"):
            items.append(txt[:48])
    if items:
        out[\"clips\"] = items
else:
    wp = run([\"wl-paste\", \"-n\"])
    if wp:
        out[\"clips\"] = [wp.splitlines()[0][:48]]

tmp_path = \"/tmp/sekai-notch-live.json.tmp\"
final_path = \"/tmp/sekai-notch-live.json\"
with open(tmp_path, \"w\") as f:
    json.dump(out, f)
os.replace(tmp_path, final_path)
'"
        ]
        onRunningChanged: {
            if (!running)
                liveStateFile.reload()
        }
    }

    function refreshLiveState(): void {
        if (!pollStateProc.running)
            pollStateProc.running = true
    }

    function _parseLiveState(): void {
        try {
            const raw = String(liveStateFile.text()).trim()
            if (!raw.length)
                return
            const d = JSON.parse(raw)
            if (typeof d.activeWs === "number")
                win.activeWorkspace = d.activeWs
            if (Array.isArray(d.workspaces) && d.workspaces.length > 0)
                win.workspacesList = d.workspaces
            if (d.media && typeof d.media === "object") {
                const prevTitle = win.mediaTitle
                const prevPlaying = win.mediaPlaying
                win.mediaActive = Boolean(d.media.active)
                win.mediaPlaying = Boolean(d.media.playing)
                win.mediaTitle = String(d.media.title || "Nothing Playing")
                win.mediaArtist = String(d.media.artist || "")
                win.mediaArtUrl = String(d.media.artUrl || "")
                win.mediaPlayerName = String(d.media.player || "")
                win.mediaPosSec = Number(d.media.pos || 0)
                win.mediaLenSec = Number(d.media.len || 0)
                win.mediaLyricLine = String(d.media.lyric || "♪ Sing along in Sekai! ♡")
                if (win.mediaActive && (prevTitle !== win.mediaTitle || prevPlaying !== win.mediaPlaying))
                    win.triggerMusicCheer(win.mediaPlaying ? "STAGE ON! ★" : "PAUSED ♪")
            }
            if (d.conn && typeof d.conn === "object") {
                win.volumePct = Number(d.conn.vol ?? 65)
                win.volumeMuted = Boolean(d.conn.muted)
                win.brightnessPct = Number(d.conn.bright ?? 80)
            }
            if (d.stats && typeof d.stats === "object") {
                win.cpuPct = Number(d.stats.cpu ?? 12)
                win.ramPct = Number(d.stats.ram ?? 40)
                win.gpuPct = Number(d.stats.gpu ?? 10)
                win.tempC = Number(d.stats.temp ?? 46)
            }
            if (Array.isArray(d.clips) && d.clips.length > 0)
                win.clipboardItems = d.clips
        } catch (e) {
        }
    }

    Timer {
        id: livePollTimer
        interval: (win.expanded || win.cuteMusicCollapsed) ? 1400 : 3500
        repeat: true
        running: true
        onTriggered: win.refreshLiveState()
    }

    Process { id: wsSwitchProc; command: []; onRunningChanged: if (!running) win.refreshLiveState() }
    Process { id: mediaCmdProc; command: []; onRunningChanged: if (!running) win.refreshLiveState() }
    Process { id: volSetProc; command: [] }
    Process { id: brightSetProc; command: [] }
    Process { id: clipCopyProc; command: [] }
    Process { id: customShellProc; command: [] }

    function focusWorkspace(idx: int): void {
        wsSwitchProc.command = [
            "sh", "-c",
            "if [ -n \"$NIRI_SOCKET\" ]; then niri msg action focus-workspace \"$1\"; elif [ -n \"$HYPRLAND_INSTANCE_SIGNATURE\" ]; then hyprctl dispatch workspace \"$1\"; fi",
            "--", String(idx)
        ]
        wsSwitchProc.running = true
        win.activeWorkspace = idx
        win.triggerNotchJelly(0.55)
        leftDiamond.triggerBeat()
        rightDiamond.triggerBeat()
    }

    function focusRelativeWorkspace(delta: int): void {
        win.focusWorkspace(Math.max(1, win.activeWorkspace + delta))
    }

    function sendMediaCommand(cmd: string): void {
        mediaCmdProc.command = ["playerctl", cmd]
        mediaCmdProc.running = true
        win.triggerMusicCheer(cmd === "play-pause" ? "STAGE ON! ♪" : "SKIP! ★")
    }

    function seekMediaToRatio(r: real): void {
        if (win.mediaLenSec <= 0)
            return
        const targetSec = Math.max(0, Math.min(win.mediaLenSec, r * win.mediaLenSec))
        win.mediaPosSec = targetSec
        mediaCmdProc.command = ["playerctl", "position", String(Math.round(targetSec))]
        mediaCmdProc.running = true
    }

    function setSystemVolume(pct: int): void {
        const clamped = Math.max(0, Math.min(100, Math.round(pct)))
        win.volumePct = clamped
        volSetProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", (clamped / 100.0).toFixed(2)]
        volSetProc.running = true
    }

    function setSystemBrightness(pct: int): void {
        const clamped = Math.max(5, Math.min(100, Math.round(pct)))
        win.brightnessPct = clamped
        brightSetProc.command = ["brightnessctl", "set", clamped + "%"]
        brightSetProc.running = true
    }

    function copyTextToClipboard(txt: string): void {
        clipCopyProc.command = ["wl-copy", "--", txt]
        clipCopyProc.running = true
        win.triggerMusicCheer("COPIED! ★")
    }

    // ════════════════════════════════════════════════════════════════════════
    // 5. SEKAI POP PALETTES & SURFACE MODES (CLASSIC / DARK / DARKER / MONO)
    // ════════════════════════════════════════════════════════════════════════
    property var pal: ({})

    FileView {
        id: colorsFile
        path: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/ryoku/colors.json"
        watchChanges: true
        printErrors: false
        onLoaded: win._parseColors()
        onFileChanged: colorsFile.reload()
    }
    function _parseColors(): void {
        try {
            const t = colorsFile.text()
            win.pal = (t && t.length) ? (JSON.parse(t) || {}) : ({})
        } catch (e) {
            win.pal = ({})
        }
    }

    QtObject {
        id: sekaiTheme

        readonly property var palettes: ({
            vs:        { label: "VS",  border: "#555473", A: "#04feee", B: "#00ffcb", deep: "#232235", divider: "#e4e4ec", wallLight: "#b3b2d4", glint: "#8EE3EF" },
            nightcord: { label: "N25", border: "#43285f", A: "#c08cf2", B: "#e2b5ff", deep: "#2b1a3d", divider: "#e8dff1", wallLight: "#c3abdb", glint: "#e2b5ff" },
            vbs:       { label: "VBS", border: "#561938", A: "#ff5c9a", B: "#ff96c0", deep: "#43142c", divider: "#f5dbe8", wallLight: "#e4a2c4", glint: "#ff96c0" },
            wxs:       { label: "WxS", border: "#6a3c11", A: "#ffa51f", B: "#ffd54a", deep: "#4b2a0c", divider: "#f9e7d7", wallLight: "#eec298", glint: "#ffd54a" },
            mmj:       { label: "MMJ", border: "#39662d", A: "#a4ee55", B: "#7fe9a8", deep: "#223c1b", divider: "#e3f1df", wallLight: "#b6daac", glint: "#7fe9a8" },
            leoneed:   { label: "L/n", border: "#2d3775", A: "#8ea3ff", B: "#9fd8ff", deep: "#181e3f", divider: "#dee1f2", wallLight: "#a8b0de", glint: "#9fd8ff" },
            mono:      { label: "MNO", border: "#444444", A: "#f4f4f4", B: "#bdbdbd", deep: "#1a1a1a", divider: "#ececec", wallLight: "#bcbcbc", glint: "#e4e4e4", mono: true },
            matugen:   {
                label: "RYO",
                border: (win.pal && win.pal.outline) ? win.pal.outline : "#555473",
                A: (win.pal && win.pal.primary) ? win.pal.primary : "#04feee",
                B: (win.pal && win.pal.tertiary) ? win.pal.tertiary : "#00ffcb",
                deep: (win.pal && win.pal.surfaceContainer) ? win.pal.surfaceContainer : "#232235",
                divider: (win.pal && win.pal.surfaceVariant) ? win.pal.surfaceVariant : "#e4e4ec",
                wallLight: (win.pal && win.pal.secondary) ? win.pal.secondary : "#b3b2d4",
                glint: (win.pal && win.pal.primary) ? win.pal.primary : "#8EE3EF"
            }
        })

        readonly property var unitPal: palettes[win.selectedUnitTheme] ? palettes[win.selectedUnitTheme] : palettes.vs
        readonly property bool isClassic: win.surfaceMode === "classic"
        readonly property bool isDarker: win.surfaceMode === "darker"

        readonly property color colBorder: Qt.color(unitPal.border)
        readonly property color accentCyan: Qt.color(unitPal.A)
        readonly property color accentMint: Qt.color(unitPal.B)
        readonly property color colDeep: Qt.color(unitPal.deep)
        readonly property color colOuterRing: "#d9d9d9"
        readonly property color ringWhite: "#ffffff"
        readonly property color warnFill: "#ffb74d"
        readonly property color cutePink: "#FF9ECB"
        readonly property color cuteYellow: "#FFE066"
        readonly property color cuteLavender: "#B39DDB"

        readonly property color pSurface: isClassic
            ? Qt.color("#ffffff")
            : (isDarker ? Qt.darker(colDeep, 1.35) : Qt.lighter(colDeep, 1.15))
        readonly property color pSurfaceHover: isClassic
            ? Qt.color("#f2f2f2")
            : Qt.lighter(pSurface, 1.28)
        readonly property color pSurfaceDivider: isClassic
            ? Qt.color(unitPal.divider)
            : Qt.lighter(pSurface, 1.65)
        readonly property color pRingWhite: isClassic
            ? Qt.color("#ffffff")
            : Qt.lighter(pSurface, 1.95)
        readonly property color pLine: isDarker ? Qt.darker(colBorder, 1.25) : colBorder
        readonly property color pLineShadow: isDarker ? Qt.darker(colBorder, 1.65) : colBorder
        readonly property color pInk: isClassic ? colBorder : Qt.color(unitPal.divider)
        readonly property color colSubText: Qt.rgba(pInk.r, pInk.g, pInk.b, 0.68)
        readonly property color chipFill: isDarker ? Qt.darker(colBorder, 1.25) : colBorder
        readonly property color chipInk: "#ffffff"

        readonly property var attributeColors: unitPal.mono
            ? ["#e4e4e4", "#b0b0b0", "#f6f6f6", "#8c8c8c", "#cecece"]
            : ["#8EE3EF", "#FF9ECB", "#FFE066", "#B39DDB", "#A5E6A5"]
        readonly property var capWsColors: [accentCyan, Qt.color(unitPal.glint), accentMint, Qt.color(unitPal.wallLight), Qt.color(unitPal.divider)]

        readonly property int radiusOuter: win.customBottomRadius
        readonly property int radiusBadge: win.customBottomRadius + 2
        readonly property int borderWidth: win.customBorderWidth
        readonly property int whiteLine: 2
        readonly property int shadowOffset: win.customShadowOffset
        readonly property int outerRingWidth: 4
        readonly property int pillHeight: 36

        readonly property string fontFamily: "Noto Sans"
        readonly property string fontStyleBold: "ExtraBold"
        readonly property string iconFont: "Material Symbols Rounded"
    }

    // ════════════════════════════════════════════════════════════════════════
    // 6. PERSISTENT SETTINGS & CUSTOM ACTIONS CATALOG
    // ════════════════════════════════════════════════════════════════════════
    readonly property string configPath: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/ryoku/sekai-notch.json"
    property bool _configLoaded: false

    readonly property var baseActionCatalog: [
        { action: "lock",        icon: "lock",                label: "Lock",       accentIdx: 0, confirm: false, cmd: "" },
        { action: "suspend",     icon: "bedtime",             label: "Suspend",    accentIdx: 3, confirm: false, cmd: "" },
        { action: "restart",     icon: "restart_alt",         label: "Restart",    accentIdx: 2, confirm: true,  cmd: "" },
        { action: "shutdown",    icon: "power_settings_new",  label: "Shutdown",   accentIdx: 1, confirm: true,  cmd: "" },
        { action: "logout",      icon: "logout",              label: "Logout",     accentIdx: 1, confirm: true,  cmd: "" },
        { action: "screenshot",  icon: "screenshot_region",   label: "Shot",       accentIdx: 4, confirm: false, cmd: "" },
        { action: "mute",        icon: "volume_off",          label: "Mute",       accentIdx: 0, confirm: false, cmd: "" },
        { action: "mic",         icon: "mic_off",             label: "Mic Mute",   accentIdx: 2, confirm: false, cmd: "" },
        { action: "colorpicker", icon: "colorize",            label: "Picker",     accentIdx: 3, confirm: false, cmd: "" },
        { action: "reload",      icon: "sync",                label: "Reload UI",  accentIdx: 4, confirm: false, cmd: "" },
        { action: "files",       icon: "folder_open",         label: "Files",      accentIdx: 0, confirm: false, cmd: "" },
        { action: "terminal",    icon: "terminal",            label: "Terminal",   accentIdx: 2, confirm: false, cmd: "" }
    ]

    property var customActions: []
    readonly property var actionCatalog: win.baseActionCatalog.concat(win.customActions)
    property var activeActionIds: ["lock", "suspend", "restart", "shutdown"]

    readonly property var activeActionsModel: {
        const res = []
        for (let i = 0; i < win.activeActionIds.length; i++) {
            const item = win.getActionById(win.activeActionIds[i])
            if (item) res.push(item)
        }
        return res
    }

    readonly property var poolActionsModel: {
        const res = []
        for (let i = 0; i < win.actionCatalog.length; i++) {
            const item = win.actionCatalog[i]
            if (win.activeActionIds.indexOf(item.action) < 0)
                res.push(item)
        }
        return res
    }

    function getActionById(id: string): var {
        for (let i = 0; i < win.actionCatalog.length; i++) {
            if (win.actionCatalog[i].action === id)
                return win.actionCatalog[i]
        }
        return null
    }

    function addActionAt(id: string, targetIndex: int): void {
        if (!win.getActionById(id))
            return
        const list = win.activeActionIds.slice()
        const existingIdx = list.indexOf(id)
        if (existingIdx >= 0)
            list.splice(existingIdx, 1)
        if (targetIndex >= 0 && targetIndex <= list.length)
            list.splice(targetIndex, 0, id)
        else
            list.push(id)
        win.activeActionIds = list
        win.requestSaveConfig()
        win.triggerNotchJelly(0.7)
        leftDiamond.triggerBeat()
        rightDiamond.triggerBeat()
    }

    function addAllPoolActions(): void {
        const list = win.activeActionIds.slice()
        for (let i = 0; i < win.actionCatalog.length; i++) {
            const actId = win.actionCatalog[i].action
            if (list.indexOf(actId) < 0)
                list.push(actId)
        }
        win.activeActionIds = list
        win.requestSaveConfig()
        win.triggerNotchJelly(0.85)
        leftDiamond.triggerBeat()
        rightDiamond.triggerBeat()
    }

    function createCustomAction(label: string, icon: string, shellCmd: string): void {
        const cleanLabel = label.trim()
        const cleanCmd = shellCmd.trim()
        if (!cleanLabel.length || !cleanCmd.length)
            return
        const newId = "custom_" + Date.now()
        const newEntry = {
            action: newId,
            icon: icon.trim() || "bolt",
            label: cleanLabel,
            accentIdx: win.customActions.length % 5,
            confirm: false,
            cmd: cleanCmd
        }
        const nextCustom = win.customActions.slice()
        nextCustom.push(newEntry)
        win.customActions = nextCustom
        win.addActionAt(newId, -1)
    }

    function removeActionById(id: string): void {
        if (win.activeActionIds.length <= 1)
            return
        const list = win.activeActionIds.slice()
        const idx = list.indexOf(id)
        if (idx >= 0) {
            list.splice(idx, 1)
            win.activeActionIds = list
            win.requestSaveConfig()
            win.triggerNotchJelly(0.6)
            leftDiamond.triggerBeat()
            rightDiamond.triggerBeat()
        }
    }

    function moveOrInsertAction(fromIdx: int, toIdx: int): void {
        const list = win.activeActionIds.slice()
        if (fromIdx < 0 || fromIdx >= list.length || toIdx < 0 || toIdx >= list.length || fromIdx === toIdx)
            return
        const moved = list.splice(fromIdx, 1)[0]
        list.splice(toIdx, 0, moved)
        win.activeActionIds = list
        win.requestSaveConfig()
        win.triggerNotchJelly(0.55)
        leftDiamond.triggerBeat()
        rightDiamond.triggerBeat()
    }

    function resetCustomization(): void {
        win.userScale = 1.0
        win.widthFactor = 1.0
        win.heightFactor = 1.0
        win.floatingMode = false
        win.musicNotchEnabled = true
        win.horizOffset = 0.0
        win.gridColumns = 4
        win.customTopRadius = 10
        win.customBottomRadius = 15
        win.customBorderWidth = 3
        win.customShadowOffset = 4
        win.showHalftone = true
        win.showSlants = true
        win.surfaceMode = "classic"
        win.selectedUnitTheme = "vs"
        win.collapsedMode = "sekai"
        win.musicDisplayMode = "vinyl"
        win.autoCloseDelay = 700
        win.bounceOvershoot = 1.75
        win.enable25D = true
        win.notchTrack25D = 0.0
        win.cursorTrack25D = 1.0
        win.activeActionIds = ["lock", "suspend", "restart", "shutdown"]
        win.requestSaveConfig()
        win.triggerNotchJelly(0.9)
        leftDiamond.triggerBeat()
        rightDiamond.triggerBeat()
    }

    FileView {
        id: configFile
        path: win.configPath
        printErrors: false
        onLoaded: win._loadConfig()
    }

    Process { id: saveConfigProc; command: [] }
    Timer { id: saveDebounce; interval: 250; onTriggered: win._saveConfigNow() }

    function requestSaveConfig(): void {
        if (!win._configLoaded)
            return
        saveDebounce.restart()
    }

    function _loadConfig(): void {
        try {
            const raw = String(configFile.text()).trim()
            if (raw.length > 0) {
                const data = JSON.parse(raw)
                if (typeof data.userScale === "number") win.userScale = Math.max(0.70, Math.min(1.60, data.userScale))
                if (typeof data.widthFactor === "number") win.widthFactor = Math.max(0.80, Math.min(1.55, data.widthFactor))
                if (typeof data.heightFactor === "number") win.heightFactor = Math.max(0.85, Math.min(1.45, data.heightFactor))
                if (typeof data.floatingMode === "boolean") win.floatingMode = data.floatingMode
                if (typeof data.musicNotchEnabled === "boolean") win.musicNotchEnabled = data.musicNotchEnabled
                if (typeof data.horizOffset === "number") win.horizOffset = Math.max(-0.35, Math.min(0.35, data.horizOffset))
                if (typeof data.gridColumns === "number") win.gridColumns = Math.max(1, Math.min(4, Math.round(data.gridColumns)))
                if (typeof data.customTopRadius === "number") win.customTopRadius = Math.max(0, Math.min(24, Math.round(data.customTopRadius)))
                if (typeof data.customBottomRadius === "number") win.customBottomRadius = Math.max(4, Math.min(28, Math.round(data.customBottomRadius)))
                if (typeof data.customBorderWidth === "number") win.customBorderWidth = Math.max(1, Math.min(6, Math.round(data.customBorderWidth)))
                if (typeof data.customShadowOffset === "number") win.customShadowOffset = Math.max(1, Math.min(8, Math.round(data.customShadowOffset)))
                if (typeof data.showHalftone === "boolean") win.showHalftone = data.showHalftone
                if (typeof data.showSlants === "boolean") win.showSlants = data.showSlants
                if (typeof data.surfaceMode === "string") win.surfaceMode = data.surfaceMode
                if (typeof data.unitTheme === "string" && sekaiTheme.palettes[data.unitTheme]) win.selectedUnitTheme = data.unitTheme
                if (typeof data.collapsedMode === "string") win.collapsedMode = data.collapsedMode
                if (typeof data.musicDisplayMode === "string") win.musicDisplayMode = data.musicDisplayMode
                if (typeof data.autoCloseDelay === "number") win.autoCloseDelay = Math.max(300, Math.min(2500, Math.round(data.autoCloseDelay)))
                if (typeof data.enable25D === "boolean") win.enable25D = data.enable25D
                if (typeof data.notchTrack25D === "number") win.notchTrack25D = Math.max(0.00, Math.min(1.80, data.notchTrack25D))
                if (typeof data.cursorTrack25D === "number") win.cursorTrack25D = Math.max(0.00, Math.min(1.80, data.cursorTrack25D))
                if (typeof data.bounceOvershoot === "number") win.bounceOvershoot = Math.max(1.0, Math.min(2.6, data.bounceOvershoot))
                if (typeof data.use24h === "boolean") win.use24h = data.use24h
                if (Array.isArray(data.customActions)) win.customActions = data.customActions
                if (Array.isArray(data.activeActionIds) && data.activeActionIds.length > 0) {
                    const valid = []
                    for (let i = 0; i < data.activeActionIds.length; i++) {
                        const id = String(data.activeActionIds[i])
                        if (win.getActionById(id) && valid.indexOf(id) < 0)
                            valid.push(id)
                    }
                    if (valid.length > 0)
                        win.activeActionIds = valid
                }
            }
        } catch (e) {
        }
        win._configLoaded = true
    }

    function _saveConfigNow(): void {
        const payload = JSON.stringify({
            userScale: Math.round(win.userScale * 100) / 100,
            widthFactor: Math.round(win.widthFactor * 100) / 100,
            heightFactor: Math.round(win.heightFactor * 100) / 100,
            floatingMode: win.floatingMode,
            musicNotchEnabled: win.musicNotchEnabled,
            horizOffset: Math.round(win.horizOffset * 100) / 100,
            gridColumns: win.gridColumns,
            customTopRadius: win.customTopRadius,
            customBottomRadius: win.customBottomRadius,
            customBorderWidth: win.customBorderWidth,
            customShadowOffset: win.customShadowOffset,
            showHalftone: win.showHalftone,
            showSlants: win.showSlants,
            surfaceMode: win.surfaceMode,
            unitTheme: win.selectedUnitTheme,
            collapsedMode: win.collapsedMode,
            musicDisplayMode: win.musicDisplayMode,
            autoCloseDelay: win.autoCloseDelay,
            enable25D: win.enable25D,
            notchTrack25D: Math.round(win.notchTrack25D * 100) / 100,
            cursorTrack25D: Math.round(win.cursorTrack25D * 100) / 100,
            bounceOvershoot: Math.round(win.bounceOvershoot * 100) / 100,
            use24h: win.use24h,
            customActions: win.customActions,
            activeActionIds: win.activeActionIds
        })
        saveConfigProc.command = [
            "sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\"",
            "--", win.configPath, payload
        ]
        saveConfigProc.running = true
    }

    Component.onCompleted: {
        win._parseColors()
        win._loadConfig()
        win.refreshLiveState()
    }

    // ════════════════════════════════════════════════════════════════════════
    // 7. DRAG & DROP STATE MACHINE
    // ════════════════════════════════════════════════════════════════════════
    property bool dragActive: false
    property string dragSourceType: ""
    property int dragSourceIndex: -1
    property string dragActionId: ""
    property real dragX: 0
    property real dragY: 0
    property int hoveredDropSlot: -1
    property bool hoveredPoolDrop: false
    property bool hoveredGridDrop: false

    readonly property var draggedActionObj: win.getActionById(win.dragActionId)

    function startDrag(sourceType: string, sourceIndex: int, actionId: string, gx: real, gy: real): void {
        win.dragSourceType = sourceType
        win.dragSourceIndex = sourceIndex
        win.dragActionId = actionId
        const localPt = notchContainer.mapFromItem(null, gx, gy)
        win.dragX = localPt.x
        win.dragY = localPt.y
        win.dragActive = true
        win.updateDropTargets(gx, gy)
    }

    function updateDrag(gx: real, gy: real): void {
        if (!win.dragActive)
            return
        const localPt = notchContainer.mapFromItem(null, gx, gy)
        win.dragX = localPt.x
        win.dragY = localPt.y
        win.updateDropTargets(gx, gy)
    }

    function updateDropTargets(gx: real, gy: real): void {
        let foundSlot = -1
        for (let i = 0; i < activeRepeater.count; i++) {
            const item = activeRepeater.itemAt(i)
            if (!item) continue
            const pt = item.mapFromItem(null, gx, gy)
            if (pt.x >= -6 && pt.x <= item.width + 6 && pt.y >= -6 && pt.y <= item.height + 6) {
                foundSlot = i
                break
            }
        }
        win.hoveredDropSlot = foundSlot

        const gridPt = activeGridContainer.mapFromItem(null, gx, gy)
        win.hoveredGridDrop = (gridPt.x >= -16 && gridPt.x <= activeGridContainer.width + 16 &&
                               gridPt.y >= -16 && gridPt.y <= activeGridContainer.height + 24)

        const poolPt = poolSection.mapFromItem(null, gx, gy)
        win.hoveredPoolDrop = (poolPt.x >= -8 && poolPt.x <= poolSection.width + 8 &&
                               poolPt.y >= -8 && poolPt.y <= poolSection.height + 8)
    }

    function endDrag(gx: real, gy: real): void {
        if (!win.dragActive)
            return
        if (gx >= 0 && gy >= 0)
            win.updateDropTargets(gx, gy)

        if (win.dragSourceType === "active") {
            if (win.hoveredPoolDrop && win.activeActionIds.length > 1) {
                win.removeActionById(win.dragActionId)
            } else if (win.hoveredDropSlot >= 0 && win.hoveredDropSlot !== win.dragSourceIndex) {
                win.moveOrInsertAction(win.dragSourceIndex, win.hoveredDropSlot)
            }
        } else if (win.dragSourceType === "pool") {
            if (win.hoveredDropSlot >= 0) {
                win.addActionAt(win.dragActionId, win.hoveredDropSlot)
            } else if (win.hoveredGridDrop || !win.hoveredPoolDrop) {
                win.addActionAt(win.dragActionId, -1)
            }
        }

        win.dragActive = false
        win.dragSourceType = ""
        win.dragSourceIndex = -1
        win.dragActionId = ""
        win.hoveredDropSlot = -1
        win.hoveredPoolDrop = false
        win.hoveredGridDrop = false
    }

    // ════════════════════════════════════════════════════════════════════════
    // 8. EXPANSION, PINNING & HOVER LIFECYCLE
    // ════════════════════════════════════════════════════════════════════════
    property bool expanded: false
    property bool controlsShown: false
    property bool settingsOpen: false
    property bool _hovering: activationHover.hovered || notchHover.hovered

    on_HoveringChanged: {
        if (_hovering) {
            collapseTimer.stop()
            contractTimer.stop()
            if (!expanded) {
                expanded = true
                win.triggerNotchJelly(1.0)
                win.refreshLiveState()
                controlsTimer.restart()
            } else {
                controlsShown = true
            }
        } else if (!win.dragActive && !win.pinned) {
            collapseTimer.interval = win.settingsOpen ? Math.max(1500, win.autoCloseDelay) : win.autoCloseDelay
            collapseTimer.restart()
        }
    }

    Timer { id: controlsTimer; interval: 70; onTriggered: if (win.expanded) win.controlsShown = true }
    Timer {
        id: collapseTimer
        interval: win.autoCloseDelay
        onTriggered: {
            if (win.dragActive || win._hovering || win.pinned)
                return
            win.controlsShown = false
            win.settingsOpen = false
            win.pendingAction = ""
            contractTimer.restart()
        }
    }
    Timer {
        id: contractTimer
        interval: 160
        onTriggered: {
            if (!win.pinned) {
                win.expanded = false
                win.triggerNotchJelly(0.75)
            }
        }
    }

    readonly property int totalGridSlots: win.activeActionsModel.length + (win.settingsOpen && win.poolActionsModel.length > 0 ? 1 : 0)
    readonly property int gridRows: Math.max(1, Math.ceil(win.totalGridSlots / Math.max(1, win.gridColumns)))
    readonly property real buttonStepH: Math.round(40 * win.s * win.heightFactor)
    readonly property real actionsPageH: Math.round(92 * win.s) + win.gridRows * win.buttonStepH
    readonly property real mediaPageH: Math.round(232 * win.s * win.heightFactor)
    readonly property int spacesRows: Math.max(1, Math.ceil(win.workspacesList.length / 4))
    readonly property real spacesPageH: Math.round(68 * win.s) + win.spacesRows * Math.round(44 * win.s * win.heightFactor)
    readonly property real clockPageH: Math.round(196 * win.s * win.heightFactor)
    readonly property real statsPageH: Math.round(164 * win.s * win.heightFactor)
    readonly property real trayPageH: Math.round(176 * win.s * win.heightFactor)

    readonly property real activePageContentH: {
        if (win.currentPage === 0) return win.actionsPageH
        if (win.currentPage === 1) return win.mediaPageH
        if (win.currentPage === 2) return win.spacesPageH
        if (win.currentPage === 3) return win.clockPageH
        if (win.currentPage === 4) return win.statsPageH
        return win.trayPageH
    }

    readonly property real settingsDrawerHeight: win.settingsOpen ? Math.round(232 * win.s) : 0
    readonly property real minCollapsedHeaderW: leftHeaderRow.implicitWidth + centerHeaderRow.implicitWidth + rightHeaderRow.implicitWidth + Math.round(64 * win.s)

    readonly property real collapsedW: win.cuteMusicCollapsed
        ? Math.round(316 * win.s * win.widthFactor)
        : Math.max(Math.round(238 * win.s * win.widthFactor), win.minCollapsedHeaderW)
    readonly property real expandedW: Math.round(Math.max(324, win.gridColumns * 124 + 56) * win.s * win.widthFactor)
    readonly property real collapsedH: win.cuteMusicCollapsed
        ? Math.round((win.floatingMode ? 74 : 70) * win.s)
        : Math.round((win.floatingMode ? 48 : 44) * win.s)
    readonly property real expandedH: Math.round((90 * win.s) * win.heightFactor + win.activePageContentH + win.settingsDrawerHeight)

    // ════════════════════════════════════════════════════════════════════════
    // 9. SYSTEM ACTION EXECUTION
    // ════════════════════════════════════════════════════════════════════════
    property string pendingAction: ""
    Timer { id: pendingTimer; interval: 3000; onTriggered: win.pendingAction = "" }

    function runAction(action: string): void {
        const meta = win.getActionById(action)
        if (meta && meta.confirm) {
            if (win.pendingAction !== action) {
                win.pendingAction = action
                pendingTimer.restart()
                return
            }
            win.pendingAction = ""
            pendingTimer.stop()
        }

        if (meta && meta.cmd && String(meta.cmd).length > 0) {
            customShellProc.command = ["sh", "-c", String(meta.cmd)]
            customShellProc.running = true
            return
        }

        if (action === "lock") {
            lockProc.running = true
        } else if (action === "suspend") {
            suspendProc.running = true
        } else if (action === "restart") {
            rebootProc.running = true
        } else if (action === "shutdown") {
            poweroffProc.running = true
        } else if (action === "logout") {
            logoutProc.running = true
        } else if (action === "screenshot") {
            screenshotProc.running = true
        } else if (action === "mute") {
            muteProc.running = true
        } else if (action === "mic") {
            micProc.running = true
        } else if (action === "colorpicker") {
            pickerProc.running = true
        } else if (action === "reload") {
            reloadProc.running = true
        } else if (action === "files") {
            filesProc.running = true
        } else if (action === "terminal") {
            termProc.running = true
        }
    }

    Process { id: lockProc; command: ["loginctl", "lock-session"] }
    Process { id: suspendProc; command: ["systemctl", "suspend"] }
    Process { id: rebootProc; command: ["systemctl", "reboot"] }
    Process { id: poweroffProc; command: ["systemctl", "poweroff"] }
    Process { id: logoutProc; command: ["sh", "-c", "loginctl terminate-user \"$USER\""] }
    Process { id: screenshotProc; command: ["sh", "-c", "grim -g \"$(slurp)\" - | wl-copy"] }
    Process { id: muteProc; command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]; onRunningChanged: if (!running) win.refreshLiveState() }
    Process { id: micProc; command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"] }
    Process { id: pickerProc; command: ["sh", "-c", "hyprpicker -a || wl-color-picker"] }
    Process { id: reloadProc; command: ["sh", "-c", "pkill -USR1 quickshell || hyprctl reload"] }
    Process { id: filesProc; command: ["sh", "-c", "xdg-open \"$HOME\""] }
    Process { id: termProc; command: ["sh", "-c", "kitty || foot || alacritty"] }
    Process { id: dndProc; command: ["sh", "-c", "makoctl mode -t do-not-disturb || swaync-client -d -sw"] }

    // ════════════════════════════════════════════════════════════════════════
    // 10. INLINE SEKAI POP UI COMPONENTS
    // ════════════════════════════════════════════════════════════════════════
    component GlyphRingText: Item {
        id: gr
        property string value: ""
        property int pixelSize: Math.round(10.5 * win.s)
        property color fillColor: sekaiTheme.colBorder
        property real ringRadius: Math.max(1.5, 2.2 * win.s)
        property int steps: 8
        property real textPop: 1.0

        onValueChanged: textPopAnim.restart()

        NumberAnimation {
            id: textPopAnim
            target: gr
            property: "textPop"
            from: 0.84
            to: 1.0
            duration: 280
            easing.type: Easing.OutBack
            easing.overshoot: 2.2
        }

        scale: gr.textPop
        implicitWidth: centerLabel.implicitWidth + Math.round(8 * win.s)
        implicitHeight: centerLabel.implicitHeight + Math.round(4 * win.s)

        Repeater {
            model: gr.steps
            Text {
                id: outerGlyph
                required property int index
                x: Math.round(1.5 * win.s) + Math.cos(outerGlyph.index * 2 * Math.PI / gr.steps) * (gr.ringRadius + 1.2 * win.s)
                y: Math.round(2.0 * win.s) + Math.sin(outerGlyph.index * 2 * Math.PI / gr.steps) * (gr.ringRadius + 1.2 * win.s)
                width: gr.width
                height: gr.height
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: gr.value
                color: sekaiTheme.colBorder
                font.family: sekaiTheme.fontFamily
                font.pixelSize: gr.pixelSize
                font.weight: Font.ExtraBold
                font.styleName: sekaiTheme.fontStyleBold
            }
        }

        Repeater {
            model: gr.steps
            Text {
                id: innerGlyph
                required property int index
                x: Math.cos(innerGlyph.index * 2 * Math.PI / gr.steps) * gr.ringRadius
                y: Math.sin(innerGlyph.index * 2 * Math.PI / gr.steps) * gr.ringRadius
                width: gr.width
                height: gr.height
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: gr.value
                color: "#ffffff"
                font.family: sekaiTheme.fontFamily
                font.pixelSize: gr.pixelSize
                font.weight: Font.ExtraBold
                font.styleName: sekaiTheme.fontStyleBold
            }
        }

        Text {
            id: centerLabel
            anchors.centerIn: parent
            text: gr.value
            color: gr.fillColor
            font.family: sekaiTheme.fontFamily
            font.pixelSize: gr.pixelSize
            font.weight: Font.ExtraBold
            font.styleName: sekaiTheme.fontStyleBold
        }
    }

    component StickerDigit: Item {
        id: sd
        property string value: "0"
        property color fillColor: sekaiTheme.accentMint
        property real tilt: 0
        property real pop: 1.0
        property real digitScale: win.s * 0.62

        width: Math.round(52 * digitScale)
        height: Math.round(78 * digitScale)
        rotation: sd.tilt
        scale: sd.pop
        transformOrigin: Item.Center

        onValueChanged: digitPopAnim.restart()

        NumberAnimation {
            id: digitPopAnim
            target: sd
            property: "pop"
            from: 0.82
            to: 1.0
            duration: 340
            easing.type: Easing.OutBack
            easing.overshoot: 2.4
        }

        GlyphRingText {
            anchors.centerIn: parent
            value: sd.value
            pixelSize: Math.round(58 * sd.digitScale)
            fillColor: sd.fillColor
            ringRadius: Math.max(2, 3.2 * sd.digitScale)
        }
    }

    component BeatDiamond: Rectangle {
        id: bd
        property bool lit: true
        property color litColor: sekaiTheme.accentMint
        property int size: Math.round(8.5 * win.s)
        property real pop: 1.0
        property real spinOffset: 45

        width: size
        height: size
        radius: Math.max(1, Math.round(2 * win.s))
        rotation: bd.spinOffset
        scale: bd.pop
        color: bd.lit ? bd.litColor : sekaiTheme.pSurfaceDivider
        border.width: Math.max(1, Math.round(1.5 * win.s))
        border.color: sekaiTheme.colBorder

        Behavior on color { ColorAnimation { duration: 180 } }

        function triggerBeat(): void {
            beatPop.restart()
        }

        ParallelAnimation {
            id: beatPop
            NumberAnimation {
                target: bd
                property: "pop"
                from: 1.75
                to: 1.0
                duration: 360
                easing.type: Easing.OutBack
                easing.overshoot: 2.3
            }
            NumberAnimation {
                target: bd
                property: "spinOffset"
                from: 135
                to: 45
                duration: 360
                easing.type: Easing.OutBack
                easing.overshoot: 1.8
            }
        }
    }

    component CassetteReel: Item {
        id: reel
        property real reelRotation: 0
        width: Math.round(34 * win.s)
        height: Math.round(34 * win.s)
        rotation: reel.reelRotation

        Behavior on rotation {
            NumberAnimation { duration: 115; easing.type: Easing.Linear }
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "#ffffff"
            border.width: Math.max(2, Math.round(2.5 * win.s))
            border.color: sekaiTheme.colBorder

            Repeater {
                model: 3
                Rectangle {
                    id: spokeItem
                    required property int index
                    anchors.centerIn: parent
                    width: parent.width - Math.round(6 * win.s)
                    height: Math.round(3.5 * win.s)
                    radius: height / 2
                    rotation: spokeItem.index * 60
                    color: sekaiTheme.colBorder
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.round(12 * win.s)
                height: Math.round(12 * win.s)
                radius: width / 2
                color: sekaiTheme.accentMint
                border.width: Math.max(1, Math.round(1.5 * win.s))
                border.color: sekaiTheme.colBorder
            }
        }
    }

    component WorkspaceCapsuleStrip: Rectangle {
        id: wsStrip
        readonly property real stripH: Math.round(24 * win.s)
        implicitWidth: wsRow.implicitWidth + Math.round(16 * win.s)
        implicitHeight: stripH
        radius: stripH / 2
        color: sekaiTheme.pSurfaceHover
        border.width: Math.max(1, Math.round(2 * win.s))
        border.color: sekaiTheme.colBorder

        Rectangle {
            z: -1
            x: 0
            y: Math.round(2 * win.s)
            width: parent.width
            height: parent.height
            radius: parent.radius
            color: sekaiTheme.pLineShadow
            opacity: 0.45
        }

        Row {
            id: wsRow
            anchors.centerIn: parent
            spacing: Math.round(5 * win.s)

            Repeater {
                model: win.workspacesList
                delegate: Item {
                    id: wsDotDel
                    required property var modelData
                    required property int index

                    readonly property bool isAct: Boolean(wsDotDel.modelData.active)
                    readonly property bool isOcc: Boolean(wsDotDel.modelData.occupied)
                    readonly property color dotCol: sekaiTheme.capWsColors[wsDotDel.index % sekaiTheme.capWsColors.length]

                    width: isAct ? Math.round(28 * win.s) : Math.round(14 * win.s)
                    height: Math.round(14 * win.s)
                    scale: dotMa.pressed ? 0.86 : (dotMa.containsMouse ? 1.12 : 1.0)

                    Behavior on width {
                        NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: win.bounceOvershoot }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: wsDotDel.isAct
                            ? wsDotDel.dotCol
                            : (wsDotDel.isOcc ? sekaiTheme.colBorder : sekaiTheme.pSurfaceDivider)
                        border.width: Math.max(1, Math.round(1.5 * win.s))
                        border.color: wsDotDel.isAct ? sekaiTheme.colBorder : "#ffffff"

                        Behavior on color { ColorAnimation { duration: 180 } }

                        Text {
                            anchors.centerIn: parent
                            visible: wsDotDel.isAct
                            text: String(wsDotDel.modelData.idx)
                            color: sekaiTheme.colBorder
                            font.family: sekaiTheme.fontFamily
                            font.pixelSize: Math.round(8 * win.s)
                            font.weight: Font.ExtraBold
                            font.styleName: sekaiTheme.fontStyleBold
                        }
                    }

                    MouseArea {
                        id: dotMa
                        anchors.fill: parent
                        anchors.margins: -2
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.focusWorkspace(wsDotDel.modelData.idx)
                    }
                }
            }
        }
    }

    component SekaiSlider: Item {
        id: sl
        property string label: "SIZE"
        property string icon: "straighten"
        property real from: 0.8
        property real to: 1.4
        property real stepSize: 0.05
        property real value: 1.0
        property string suffix: "%"
        property real displayMultiplier: 100
        signal moved(real newValue)

        readonly property real ratio: Math.max(0, Math.min(1, (sl.value - sl.from) / Math.max(0.0001, sl.to - sl.from)))
        implicitWidth: Math.round(256 * win.s * win.widthFactor)
        implicitHeight: Math.round(20 * win.s)

        Row {
            anchors.fill: parent
            spacing: Math.round(6 * win.s)

            Item {
                width: Math.round(68 * win.s)
                height: parent.height

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.round(3 * win.s)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: sl.icon
                        rotation: sliderMa.pressed ? -15 : 0
                        color: sekaiTheme.pInk
                        font.family: sekaiTheme.iconFont
                        font.pixelSize: Math.round(12 * win.s)
                        Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: sl.label
                        color: sekaiTheme.pInk
                        font.family: sekaiTheme.fontFamily
                        font.pixelSize: Math.round(8.5 * win.s)
                        font.weight: Font.ExtraBold
                        font.styleName: sekaiTheme.fontStyleBold
                    }
                }
            }

            Item {
                id: trackArea
                width: parent.width - Math.round(110 * win.s)
                height: Math.round(13 * win.s)
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    x: 0
                    y: Math.round(2 * win.s)
                    width: parent.width
                    height: parent.height
                    radius: height / 2
                    color: sekaiTheme.pLineShadow
                    opacity: 0.55
                }

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: sekaiTheme.pSurfaceDivider
                    border.width: Math.max(1, Math.round(2 * win.s))
                    border.color: sekaiTheme.colBorder
                    clip: true

                    Rectangle {
                        width: Math.max(parent.height, parent.width * sl.ratio)
                        height: parent.height
                        radius: height / 2
                        border.width: Math.max(1, Math.round(1.5 * win.s))
                        border.color: sekaiTheme.colBorder
                        Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: sekaiTheme.accentMint }
                            GradientStop { position: 1.0; color: sekaiTheme.accentCyan }
                        }
                    }
                }

                Rectangle {
                    x: Math.round((trackArea.width - width) * sl.ratio)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(13 * win.s)
                    height: Math.round(13 * win.s)
                    radius: Math.round(4 * win.s)
                    rotation: sliderMa.pressed ? 45 : (sliderMa.containsMouse ? 24 : 12)
                    scale: sliderMa.pressed ? 1.26 : (sliderMa.containsMouse ? 1.12 : 1.0)
                    color: "#ffffff"
                    border.width: Math.max(2, Math.round(2 * win.s))
                    border.color: sekaiTheme.colBorder

                    Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2.4 } }
                }

                MouseArea {
                    id: sliderMa
                    anchors.fill: parent
                    anchors.margins: -Math.round(4 * win.s)
                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: Qt.PointingHandCursor

                    function updateFromMouse(mx: real): void {
                        const clamped = Math.max(0, Math.min(1, (mx - 4 * win.s) / Math.max(1, trackArea.width)))
                        const rawVal = sl.from + clamped * (sl.to - sl.from)
                        const stepped = sl.stepSize > 0 ? Math.round(rawVal / sl.stepSize) * sl.stepSize : rawVal
                        sl.moved(stepped)
                    }

                    onPressed: mouse => updateFromMouse(mouse.x)
                    onPositionChanged: mouse => { if (pressed) updateFromMouse(mouse.x) }
                }
            }

            Rectangle {
                width: Math.round(34 * win.s)
                height: Math.round(15 * win.s)
                anchors.verticalCenter: parent.verticalCenter
                radius: Math.round(5 * win.s)
                scale: sliderMa.pressed ? 1.08 : 1.0
                color: sekaiTheme.chipFill

                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

                Text {
                    anchors.centerIn: parent
                    text: Math.round(sl.value * sl.displayMultiplier) + sl.suffix
                    color: sekaiTheme.chipInk
                    font.family: sekaiTheme.fontFamily
                    font.pixelSize: Math.round(7.5 * win.s)
                    font.weight: Font.ExtraBold
                    font.styleName: sekaiTheme.fontStyleBold
                }
            }
        }
    }

    component StageStatBar: Item {
        id: stBar
        property string label: "CPU"
        property string icon: "memory"
        property int pct: 20
        property string valueText: pct + "%"
        property bool warn: pct >= 80

        implicitWidth: Math.round(252 * win.s * win.widthFactor)
        implicitHeight: Math.round(26 * win.s)

        Row {
            anchors.fill: parent
            spacing: Math.round(6 * win.s)

            Row {
                width: Math.round(58 * win.s)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(3 * win.s)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: stBar.icon
                    color: stBar.warn ? sekaiTheme.warnFill : sekaiTheme.pInk
                    font.family: sekaiTheme.iconFont
                    font.pixelSize: Math.round(13 * win.s)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: stBar.label
                    color: stBar.warn ? sekaiTheme.warnFill : sekaiTheme.pInk
                    font.family: sekaiTheme.fontFamily
                    font.pixelSize: Math.round(9.5 * win.s)
                    font.weight: Font.ExtraBold
                    font.styleName: sekaiTheme.fontStyleBold
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(3 * win.s)

                Repeater {
                    model: 12
                    Rectangle {
                        id: segItem
                        required property int index
                        readonly property bool lit: (segItem.index / 12.0) * 100 < stBar.pct
                        width: Math.round(9 * win.s * win.widthFactor)
                        height: Math.round(14 * win.s)
                        radius: Math.round(3 * win.s)
                        rotation: 12
                        scale: lit ? 1.0 : 0.88
                        color: segItem.lit
                            ? (stBar.warn ? sekaiTheme.warnFill : (segItem.index < 6 ? sekaiTheme.accentMint : sekaiTheme.accentCyan))
                            : sekaiTheme.pSurfaceDivider
                        border.width: 1
                        border.color: sekaiTheme.colBorder

                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                }
            }

            Rectangle {
                width: Math.round(42 * win.s)
                height: Math.round(18 * win.s)
                anchors.verticalCenter: parent.verticalCenter
                radius: Math.round(5 * win.s)
                color: stBar.warn ? sekaiTheme.warnFill : sekaiTheme.chipFill

                Text {
                    anchors.centerIn: parent
                    text: stBar.valueText
                    color: stBar.warn ? sekaiTheme.colBorder : "#ffffff"
                    font.family: sekaiTheme.fontFamily
                    font.pixelSize: Math.round(8.5 * win.s)
                    font.weight: Font.ExtraBold
                    font.styleName: sekaiTheme.fontStyleBold
                }
            }
        }
    }

    component PoolActionChip: Item {
        id: pc
        property var actionData
        property int poolIndex: 0
        property bool _dragging: false
        property real _pressX: 0
        property real _pressY: 0

        implicitWidth: chipRow.implicitWidth + Math.round(14 * win.s)
        implicitHeight: Math.round(21 * win.s)

        scale: chipMa.pressed ? 0.90 : (chipMa.containsMouse ? 1.07 : 1.0)
        rotation: chipMa.containsMouse ? -2.0 : 0.0
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
        Behavior on rotation { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

        Rectangle {
            anchors.fill: parent
            radius: Math.round(7 * win.s)
            color: chipMa.containsMouse ? sekaiTheme.accentMint : sekaiTheme.pSurface
            border.width: Math.max(1, Math.round(1.5 * win.s))
            border.color: sekaiTheme.colBorder

            Behavior on color { ColorAnimation { duration: 140 } }

            Rectangle {
                z: -1
                x: Math.round(1.5 * win.s)
                y: Math.round(2 * win.s)
                width: parent.width
                height: parent.height
                radius: parent.radius
                color: sekaiTheme.pLineShadow
                opacity: 0.45
            }

            Row {
                id: chipRow
                anchors.centerIn: parent
                spacing: Math.round(3 * win.s)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "add"
                    color: sekaiTheme.colBorder
                    font.family: sekaiTheme.iconFont
                    font.pixelSize: Math.round(10 * win.s)
                    font.weight: Font.Bold
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: pc.actionData ? pc.actionData.icon : "add"
                    color: sekaiTheme.colBorder
                    font.family: sekaiTheme.iconFont
                    font.pixelSize: Math.round(11 * win.s)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: pc.actionData ? pc.actionData.label : ""
                    color: sekaiTheme.colBorder
                    font.family: sekaiTheme.fontFamily
                    font.pixelSize: Math.round(8.5 * win.s)
                    font.weight: Font.ExtraBold
                    font.styleName: sekaiTheme.fontStyleBold
                }
            }
        }

        MouseArea {
            id: chipMa
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: pc._dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

            onPressed: mouse => {
                pc._pressX = mouse.x
                pc._pressY = mouse.y
                pc._dragging = false
            }

            onPositionChanged: mouse => {
                if (!pressed || !pc.actionData)
                    return
                const dx = mouse.x - pc._pressX
                const dy = mouse.y - pc._pressY
                const pt = pc.mapToItem(null, mouse.x, mouse.y)
                if (!pc._dragging && (dx * dx + dy * dy) > 20) {
                    pc._dragging = true
                    win.startDrag("pool", pc.poolIndex, pc.actionData.action, pt.x, pt.y)
                }
                if (pc._dragging) {
                    win.updateDrag(pt.x, pt.y)
                }
            }

            onReleased: mouse => {
                if (pc._dragging) {
                    const pt = pc.mapToItem(null, mouse.x, mouse.y)
                    pc._dragging = false
                    win.endDrag(pt.x, pt.y)
                    return
                }
                if (pc.actionData) {
                    win.addActionAt(pc.actionData.action, -1)
                }
            }

            onCanceled: {
                if (pc._dragging) {
                    pc._dragging = false
                    win.endDrag(-1, -1)
                }
            }
        }
    }

    onExpandedChanged: {
        leftDiamond.triggerBeat()
        rightDiamond.triggerBeat()
    }

    onSettingsOpenChanged: {
        win.triggerNotchJelly(0.75)
        leftDiamond.triggerBeat()
        rightDiamond.triggerBeat()
    }

    onPendingActionChanged: {
        if (pendingAction !== "") {
            win.triggerNotchJelly(0.8)
            leftDiamond.triggerBeat()
            rightDiamond.triggerBeat()
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // 11. NOTCH CONTAINER WITH ORGANIC JELLY TRANSFORM & BURST PARTICLES
    // ════════════════════════════════════════════════════════════════════════
    Item {
        id: activationZone
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: Math.round(win.width * win.horizOffset)
        width: Math.max(win.collapsedW, Math.round(280 * win.s))
        height: Math.round(52 * win.s)
        opacity: 0
    }

    Item {
        id: notchContainer
        anchors.top: parent.top
        anchors.topMargin: win.floatingMode ? Math.round(8 * win.s) : 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: Math.round(win.width * win.horizOffset)
        width: win.expanded ? win.expandedW : win.collapsedW
        height: win.expanded ? win.expandedH : win.collapsedH

        // Organic Squash & Stretch anchored to the top center of the notch!
        transform: Scale {
            origin.x: notchContainer.width / 2
            origin.y: 0
            xScale: win.notchJellyX
            yScale: win.notchJellyY
        }

        Behavior on anchors.topMargin {
            NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
        }
        Behavior on anchors.horizontalCenterOffset {
            NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.35 }
        }
        // Asymmetric width & height spring timings for natural liquid morphing
        Behavior on width {
            NumberAnimation { duration: 310; easing.type: Easing.OutBack; easing.overshoot: win.bounceOvershoot }
        }
        Behavior on height {
            NumberAnimation { duration: 360; easing.type: Easing.OutBack; easing.overshoot: win.bounceOvershoot * 0.92 }
        }

        DropArea {
            id: globalDropArea
            anchors.fill: parent
            onEntered: {
                win.expanded = true
                win.controlsShown = true
                win.switchPage(5)
            }
            onDropped: drop => {
                const nextList = win.droppedShelfItems.slice()
                if (drop.hasUrls) {
                    for (let i = 0; i < drop.urls.length; i++) {
                        const u = String(drop.urls[i]).replace("file://", "")
                        if (u.length > 0 && nextList.indexOf(u) < 0)
                            nextList.unshift(u)
                    }
                } else if (drop.hasText && String(drop.text).trim().length > 0) {
                    nextList.unshift(String(drop.text).trim().slice(0, 64))
                }
                win.droppedShelfItems = nextList.slice(0, 8)
                win.triggerMusicCheer("STASHED! ★")
            }
        }

        NotchShape {
            id: notchShape
            anchors.fill: parent
            sekaiTheme: sekaiTheme
            s: win.s
            expanded: win.expanded
            settingsOpen: win.settingsOpen
            floatingMode: win.floatingMode
            musicMode: win.cuteMusicCollapsed
            showHalftone: win.showHalftone
            showSlants: win.showSlants
            parallaxX: win.parallaxX
            parallaxY: win.parallaxY
            trackIntensity: win.notchTrack25D
            progressRatio: win.expanded
                ? (win.pomoRunning ? win.pomoProgress : 0.0)
                : 0.0
            topRadius: win.expanded
                ? Math.round(win.customTopRadius * win.s)
                : Math.round(Math.min(8, win.customTopRadius * 0.7) * win.s)
            bottomRadius: win.expanded
                ? Math.round((win.customBottomRadius + 2) * win.s)
                : Math.round(win.customBottomRadius * win.s)
            strokeWidth: Math.max(1, Math.round(win.customBorderWidth * win.s * notchShape.chromeScale))
            shadowOffset: Math.max(1, Math.round(win.customShadowOffset * win.s * notchShape.chromeScale))
            fillColor: sekaiTheme.pSurface
            strokeColor: sekaiTheme.pLine
            ringColor: sekaiTheme.pRingWhite
            shadowColor: sekaiTheme.pLineShadow
            colorTop: sekaiTheme.accentMint
            colorBottom: sekaiTheme.accentCyan

            Behavior on topRadius { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
            Behavior on bottomRadius { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
        }

        // Cute Burst Particles Layer (Triggered on Cheer / Song Switch / Copy)
        Item {
            anchors.fill: parent
            visible: win.burstProgress < 0.99
            z: 50

            Repeater {
                model: [
                    { sym: "★", ang: -2.6, col: "#FFE066" },
                    { sym: "♡", ang: -2.0, col: "#FF9ECB" },
                    { sym: "♪", ang: -1.5, col: "#00ffcb" },
                    { sym: "✦", ang: -1.1, col: "#04feee" },
                    { sym: "★", ang: -0.5, col: "#FFE066" }
                ]
                delegate: Text {
                    id: burstPart
                    required property var modelData
                    readonly property real dist: win.burstProgress * Math.round(62 * win.s)
                    x: parent.width / 2 + Math.cos(burstPart.modelData.ang) * dist - width / 2
                    y: Math.round(32 * win.s) - Math.sin(burstPart.modelData.ang) * dist * 0.5
                    text: burstPart.modelData.sym
                    color: burstPart.modelData.col
                    opacity: 1.0 - win.burstProgress
                    scale: 0.6 + Math.sin(win.burstProgress * Math.PI) * 0.9
                    rotation: win.burstProgress * 120
                    font.family: sekaiTheme.fontFamily
                    font.pixelSize: Math.round(13 * win.s)
                    font.weight: Font.ExtraBold
                }
            }
        }

        HoverHandler {
            id: notchHover
            onPointChanged: {
                if (hovered && notchContainer.width > 0 && notchContainer.height > 0) {
                    const px = (point.position.x / notchContainer.width) * 2.0 - 1.0
                    const py = (point.position.y / notchContainer.height) * 2.0 - 1.0
                    win.parallaxX = Math.max(-1.0, Math.min(1.0, px))
                    win.parallaxY = Math.max(-1.0, Math.min(1.0, py))
                }
            }
            onHoveredChanged: {
                if (!hovered) { win.parallaxX = 0.0; win.parallaxY = 0.0 }
            }
        }

        WheelHandler {
            onWheel: event => {
                if (Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y) && event.angleDelta.x !== 0) {
                    event.accepted = true
                    if (event.angleDelta.x < 0) win.switchPage(win.currentPage + 1)
                    else win.switchPage(win.currentPage - 1)
                } else {
                    event.accepted = false
                }
            }
        }

        // ════════════════════════════════════════════════════════════════════
        // 11A. CUTE MORPHED COLLAPSED MUSIC DISPLAY (VINYL POD + CLOUD PILL)
        // ════════════════════════════════════════════════════════════════════
        Item {
            id: cuteCollapsedMusicBar
            x: notchShape.sideContentInset + Math.round(2 * win.s)
            y: notchShape.topContentInset
            width: Math.max(0, parent.width - (notchShape.sideContentInset + Math.round(2 * win.s)) * 2)
            height: notchShape.innerSurfaceHeight
            opacity: win.cuteMusicCollapsed ? 1.0 : 0.0
            scale: win.cuteMusicCollapsed ? 1.0 : 0.86
            visible: opacity > 0.01
            clip: true

            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
            Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: win.bounceOvershoot } }

            Repeater {
                model: ["♪", "★", "♡"]
                delegate: Text {
                    id: miniFloatSparkle
                    required property string modelData
                    required property int index
                    x: Math.round((72 + miniFloatSparkle.index * 78) * win.s * win.widthFactor)
                    y: Math.round(2 * win.s + Math.sin(win.vizPhase * 0.4 + miniFloatSparkle.index) * 2.5 * win.s)
                    text: miniFloatSparkle.modelData
                    color: "#ffffff"
                    opacity: 0.85
                    font.family: sekaiTheme.fontFamily
                    font.pixelSize: Math.round(10 * win.s)
                    font.weight: Font.ExtraBold
                }
            }

            // Left Vinyl Pod: Spinning Record + Album Art + Cute Bobbing Heart Badge
            Item {
                id: collapsedVinylPod
                x: Math.round(4 * win.s)
                y: Math.round((parent.height - height) / 2)
                width: Math.round(52 * win.s)
                height: Math.round(52 * win.s)

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    rotation: win.discAngle
                    color: sekaiTheme.colDeep
                    border.width: Math.max(2, Math.round(2 * win.s))
                    border.color: "#ffffff"

                    Behavior on rotation { NumberAnimation { duration: 115; easing.type: Easing.Linear } }

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - Math.round(8 * win.s)
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: sekaiTheme.accentCyan
                        opacity: 0.5
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.round(24 * win.s)
                        height: width
                        radius: width / 2
                        color: sekaiTheme.cuteYellow
                        border.width: Math.max(1, Math.round(1.5 * win.s))
                        border.color: "#ffffff"
                        clip: true

                        Image {
                            id: miniPodArt
                            anchors.fill: parent
                            source: win.mediaActive ? win.mediaArtUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                            visible: status === Image.Ready
                        }

                        Text {
                            visible: !miniPodArt.visible
                            anchors.centerIn: parent
                            text: "music_note"
                            color: sekaiTheme.colBorder
                            font.family: sekaiTheme.iconFont
                            font.pixelSize: Math.round(11 * win.s)
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.round(6 * win.s)
                        height: width
                        radius: width / 2
                        color: "#ffffff"
                        border.width: 1
                        border.color: sekaiTheme.colBorder
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: Math.round(16 * win.s)
                    height: Math.round(16 * win.s)
                    radius: width / 2
                    rotation: 10
                    scale: 1.0 + (win.vizPoints[0] || 0.2) * 0.18
                    color: sekaiTheme.cutePink
                    border.width: Math.max(1, Math.round(1.5 * win.s))
                    border.color: sekaiTheme.colBorder

                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                    Text {
                        anchors.centerIn: parent
                        text: "♡"
                        color: sekaiTheme.colBorder
                        font.family: sekaiTheme.fontFamily
                        font.pixelSize: Math.round(8.5 * win.s)
                        font.weight: Font.ExtraBold
                    }
                }
            }

            // Right Cloud Pill Area: Track Title, Artist, Sticker Tag, Equalizer & Candy Progress
            Column {
                anchors.left: collapsedVinylPod.right
                anchors.leftMargin: Math.round(12 * win.s)
                anchors.right: parent.right
                anchors.rightMargin: Math.round(6 * win.s)
                y: Math.round(3 * win.s)
                spacing: Math.round(1.5 * win.s)

                Row {
                    width: parent.width
                    spacing: Math.round(5 * win.s)

                    Rectangle {
                        width: Math.round(22 * win.s)
                        height: Math.round(13 * win.s)
                        anchors.verticalCenter: parent.verticalCenter
                        radius: Math.round(4 * win.s)
                        color: sekaiTheme.colBorder
                        border.width: 1
                        border.color: "#ffffff"

                        Text {
                            anchors.centerIn: parent
                            text: "W" + win.activeWorkspace
                            color: sekaiTheme.accentMint
                            font.family: sekaiTheme.fontFamily
                            font.pixelSize: Math.round(7 * win.s)
                            font.weight: Font.ExtraBold
                        }
                    }

                    Rectangle {
                        width: Math.round(54 * win.s)
                        height: Math.round(13 * win.s)
                        anchors.verticalCenter: parent.verticalCenter
                        radius: Math.round(4 * win.s)
                        rotation: -2
                        color: sekaiTheme.cuteYellow
                        border.width: 1
                        border.color: sekaiTheme.colBorder

                        Text {
                            anchors.centerIn: parent
                            text: "★ ON AIR ♪"
                            color: sekaiTheme.colBorder
                            font.family: sekaiTheme.fontFamily
                            font.pixelSize: Math.round(6.5 * win.s)
                            font.weight: Font.ExtraBold
                            font.styleName: sekaiTheme.fontStyleBold
                        }
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Math.round(2 * win.s)

                        Repeater {
                            model: 6
                            Rectangle {
                                id: cEqBar
                                required property int index
                                readonly property real amp: win.vizPoints[cEqBar.index] || 0.35
                                width: Math.max(2, Math.round(3 * win.s))
                                height: Math.max(3, Math.round(11 * win.s * amp))
                                anchors.verticalCenter: parent.verticalCenter
                                radius: width / 2
                                color: cEqBar.index % 2 === 0 ? sekaiTheme.colBorder : "#ffffff"
                                Behavior on height { NumberAnimation { duration: 105; easing.type: Easing.OutQuad } }
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: win.mediaTitle
                    color: sekaiTheme.colBorder
                    font.family: sekaiTheme.fontFamily
                    font.pixelSize: Math.round(10 * win.s)
                    font.weight: Font.ExtraBold
                    font.styleName: sekaiTheme.fontStyleBold
                }

                Row {
                    width: parent.width
                    spacing: Math.round(6 * win.s)

                    Text {
                        width: Math.round(parent.width * 0.52)
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: win.mediaArtist !== "" ? win.mediaArtist : win.mediaPlayerName
                        color: sekaiTheme.colBorder
                        opacity: 0.8
                        font.family: sekaiTheme.fontFamily
                        font.pixelSize: Math.round(7.5 * win.s)
                        font.weight: Font.Bold
                    }

                    Item {
                        width: Math.round(parent.width * 0.42)
                        height: Math.round(7 * win.s)
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: "#ffffff"
                            border.width: 1
                            border.color: sekaiTheme.colBorder
                            clip: true

                            Rectangle {
                                width: Math.max(parent.height, parent.width * win.mediaProgress)
                                height: parent.height
                                radius: height / 2
                                color: sekaiTheme.cutePink
                                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            }
                        }

                        Text {
                            x: Math.round((parent.width - width) * win.mediaProgress)
                            anchors.verticalCenter: parent.verticalCenter
                            text: "★"
                            color: sekaiTheme.colBorder
                            font.pixelSize: Math.round(8 * win.s)
                            font.weight: Font.ExtraBold
                            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }
        }

        // ════════════════════════════════════════════════════════════════════
        // 11B. STANDARD HEADER BAR
        // ════════════════════════════════════════════════════════════════════
        Item {
            id: headerBar
            x: notchShape.sideContentInset + Math.round(6 * win.s)
            y: notchShape.topContentInset + Math.round((notchShape.plateHeight - height) / 2)
            width: Math.max(0, parent.width - (notchShape.sideContentInset + Math.round(6 * win.s)) * 2)
            height: Math.round(20 * win.s)
            opacity: win.cuteMusicCollapsed ? 0.0 : 1.0
            visible: opacity > 0.01
            clip: true

            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    if (wheel.angleDelta.y < 0 || wheel.angleDelta.x > 0)
                        win.switchPage(win.currentPage + 1)
                    else if (wheel.angleDelta.y > 0 || wheel.angleDelta.x < 0)
                        win.switchPage(win.currentPage - 1)
                }
            }

            Row {
                id: leftHeaderRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(5 * win.s)

                Rectangle {
                    width: Math.round(28 * win.s)
                    height: Math.round(18 * win.s)
                    radius: Math.round(6 * win.s)
                    scale: wsHdrMa.pressed ? 0.88 : (wsHdrMa.containsMouse ? 1.08 : 1.0)
                    color: sekaiTheme.colBorder
                    border.width: Math.max(1, Math.round(1.5 * win.s))
                    border.color: "#ffffff"

                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

                    Text {
                        anchors.centerIn: parent
                        text: "W" + win.activeWorkspace
                        color: sekaiTheme.accentMint
                        font.family: sekaiTheme.fontFamily
                        font.pixelSize: Math.round(8.5 * win.s)
                        font.weight: Font.ExtraBold
                        font.styleName: sekaiTheme.fontStyleBold
                    }

                    MouseArea {
                        id: wsHdrMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.switchPage(2)
                    }
                }

                Row {
                    visible: !win.expanded && win.mediaPlaying
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.round(2 * win.s)

                    Repeater {
                        model: 4
                        Rectangle {
                            id: miniEqBar
                            required property int index
                            readonly property real amp: win.vizPoints[miniEqBar.index] || 0.3
                            width: Math.max(2, Math.round(2.5 * win.s))
                            height: Math.max(4, Math.round(13 * win.s * amp))
                            anchors.verticalCenter: parent.verticalCenter
                            radius: width / 2
                            color: sekaiTheme.colBorder
                            Behavior on height { NumberAnimation { duration: 105; easing.type: Easing.OutQuad } }
                        }
                    }
                }
            }

            Row {
                id: centerHeaderRow
                anchors.centerIn: parent
                spacing: Math.round(6 * win.s)

                BeatDiamond {
                    id: leftDiamond
                    anchors.verticalCenter: parent.verticalCenter
                    lit: true
                    litColor: win.pendingAction !== "" ? sekaiTheme.warnFill : sekaiTheme.accentMint
                }

                GlyphRingText {
                    anchors.verticalCenter: parent.verticalCenter
                    value: {
                        if (win.dragActive) return "INSERT ACTION"
                        if (win.pendingAction !== "") return "CONFIRM"
                        if (win.settingsOpen) return "CUSTOMIZE"
                        if (!win.expanded) {
                            if (win.pomoRunning) return win.pomoMinStr + ":" + win.pomoSecStr
                            if (win.collapsedMode === "clock") return win.hhStr + ":" + win.mmStr
                            if (win.collapsedMode === "stats") return "C" + win.cpuPct + "% R" + win.ramPct + "%"
                            if (win.collapsedMode === "media" && win.mediaActive) return win.mediaTitle.slice(0, 12).toUpperCase()
                            return win.mediaPlaying ? "PLAYING ♪" : "SEKAI POP"
                        }
                        return win.pageTabs[win.currentPage].label
                    }
                    pixelSize: Math.round(10 * win.s)
                    fillColor: win.pendingAction !== "" ? sekaiTheme.warnFill : sekaiTheme.colBorder
                }

                BeatDiamond {
                    id: rightDiamond
                    anchors.verticalCenter: parent.verticalCenter
                    lit: true
                    litColor: win.pendingAction !== "" ? sekaiTheme.warnFill : sekaiTheme.accentCyan
                }
            }

            Row {
                id: rightHeaderRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(4 * win.s)

                Rectangle {
                    visible: win.expanded
                    width: Math.round(20 * win.s)
                    height: Math.round(18 * win.s)
                    radius: Math.round(6 * win.s)
                    scale: pinMa.pressed ? 0.88 : (pinMa.containsMouse ? 1.10 : 1.0)
                    color: win.pinned ? sekaiTheme.colBorder : Qt.rgba(1, 1, 1, 0.85)
                    border.width: Math.max(1, Math.round(1.5 * win.s))
                    border.color: sekaiTheme.colBorder

                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "push_pin"
                        rotation: win.pinned ? 0 : 45
                        color: win.pinned ? sekaiTheme.accentCyan : sekaiTheme.colBorder
                        font.family: sekaiTheme.iconFont
                        font.pixelSize: Math.round(10.5 * win.s)
                        Behavior on rotation { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
                    }

                    MouseArea {
                        id: pinMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            win.pinned = !win.pinned
                            win.triggerNotchJelly(0.6)
                            leftDiamond.triggerBeat()
                        }
                    }
                }

                Rectangle {
                    visible: win.expanded
                    width: Math.round(32 * win.s)
                    height: Math.round(18 * win.s)
                    radius: Math.round(6 * win.s)
                    color: win.enable25D ? sekaiTheme.cuteYellow : Qt.rgba(1, 1, 1, 0.78)
                    border.width: Math.max(1, Math.round(1.5 * win.s))
                    border.color: sekaiTheme.colBorder

                    Text {
                        anchors.centerIn: parent
                        text: "2.5D"
                        color: sekaiTheme.colBorder
                        font.family: sekaiTheme.fontFamily
                        font.pixelSize: Math.round(7.5 * win.s)
                        font.weight: Font.ExtraBold
                        font.styleName: sekaiTheme.fontStyleBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            win.enable25D = !win.enable25D
                            win.requestSaveConfig()
                            win.triggerMusicCheer(win.enable25D ? "2.5D ON! ★" : "FLAT 2D!")
                        }
                    }
                }

                Rectangle {
                    id: gearBtn
                    width: Math.round(24 * win.s)
                    height: Math.round(18 * win.s)
                    radius: Math.round(6 * win.s)
                    scale: gearMa.pressed ? 0.88 : (gearMa.containsMouse ? 1.10 : 1.0)
                    color: win.expanded
                        ? (win.settingsOpen ? sekaiTheme.colBorder : (gearMa.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.85)))
                        : (win.mediaPlaying ? sekaiTheme.colBorder : Qt.rgba(1, 1, 1, 0.78))
                    border.width: Math.max(1, Math.round(1.5 * win.s))
                    border.color: sekaiTheme.colBorder

                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: win.expanded
                            ? (win.settingsOpen ? "check" : "tune")
                            : (win.mediaPlaying ? "music_note" : "more_horiz")
                        rotation: win.settingsOpen ? 180 : 0
                        color: (win.expanded && win.settingsOpen) || (!win.expanded && win.mediaPlaying)
                            ? sekaiTheme.accentMint
                            : sekaiTheme.colBorder
                        font.family: sekaiTheme.iconFont
                        font.pixelSize: Math.round(11 * win.s)
                        font.weight: Font.Bold
                        Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }
                    }

                    MouseArea {
                        id: gearMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.settingsOpen = !win.settingsOpen
                    }
                }
            }
        }

        // ════════════════════════════════════════════════════════════════════
        // 12. STRICTLY CLIPPED EXPANDED MULTI-PAGE BODY WITH DIRECTIONAL SLIDE
        // ════════════════════════════════════════════════════════════════════
        Item {
            id: expandedBodyClip
            x: notchShape.surfaceInset
            y: notchShape.topContentInset + notchShape.plateHeight
            width: Math.max(0, parent.width - notchShape.surfaceInset * 2)
            height: Math.max(0, parent.height - y - notchShape.bottomContentInset)
            clip: true
            visible: win.expanded || win.controlsShown

            Column {
                id: controlsCol
                anchors.top: parent.top
                anchors.topMargin: Math.round(6 * win.s)
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(6 * win.s * win.heightFactor)
                transformOrigin: Item.Top
                opacity: win.controlsShown ? win.pageOpacity : 0.0
                scale: win.controlsShown ? 1.0 : 0.85
                visible: opacity > 0.01
                anchors.horizontalCenterOffset: win.pageShift

                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
                Behavior on anchors.horizontalCenterOffset { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on scale {
                    NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: win.bounceOvershoot }
                }

                // ── 6-Page Navigation Pill Bar ──
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Math.round(4 * win.s)

                    Repeater {
                        model: win.pageTabs
                        delegate: Rectangle {
                            id: navTabDel
                            required property var modelData
                            readonly property bool isCurrent: win.currentPage === navTabDel.modelData.idx

                            width: Math.round(42 * win.s * win.widthFactor)
                            height: Math.round(22 * win.s)
                            radius: Math.round(7 * win.s)
                            y: isCurrent ? -Math.round(1.5 * win.s) : (tabMa.containsMouse ? -Math.round(1 * win.s) : 0)
                            color: isCurrent
                                ? sekaiTheme.colBorder
                                : (tabMa.containsMouse ? sekaiTheme.pSurfaceDivider : sekaiTheme.pSurfaceHover)
                            border.width: Math.max(1, Math.round(1.5 * win.s))
                            border.color: sekaiTheme.colBorder
                            scale: tabMa.pressed ? 0.90 : (isCurrent ? 1.05 : (tabMa.containsMouse ? 1.03 : 1.0))

                            Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }
                            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
                            Behavior on color { ColorAnimation { duration: 140 } }

                            Rectangle {
                                visible: navTabDel.isCurrent
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: Math.round(2 * win.s)
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.round(16 * win.s)
                                height: Math.round(2 * win.s)
                                radius: height / 2
                                color: sekaiTheme.accentMint
                            }

                            Row {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: navTabDel.isCurrent ? -Math.round(1 * win.s) : 0
                                spacing: Math.round(2 * win.s)

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: navTabDel.modelData.icon
                                    color: navTabDel.isCurrent ? sekaiTheme.accentMint : sekaiTheme.pInk
                                    font.family: sekaiTheme.iconFont
                                    font.pixelSize: Math.round(11 * win.s)
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: navTabDel.modelData.label
                                    color: navTabDel.isCurrent ? "#ffffff" : sekaiTheme.pInk
                                    font.family: sekaiTheme.fontFamily
                                    font.pixelSize: Math.round(7.5 * win.s)
                                    font.weight: Font.ExtraBold
                                    font.styleName: sekaiTheme.fontStyleBold
                                }
                            }

                            MouseArea {
                                id: tabMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.switchPage(navTabDel.modelData.idx)
                                onWheel: wheel => {
                                    if (wheel.angleDelta.y < 0) win.switchPage(win.currentPage + 1)
                                    else if (wheel.angleDelta.y > 0) win.switchPage(win.currentPage - 1)
                                }
                            }
                        }
                    }
                }

                // ── Animated Page Stage Container (Directional Slide + Scale + Fade) ──
                Item {
                    id: pageStageWrapper
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: Math.round(win.pageSlideOffset)
                    width: Math.round(272 * win.s * win.widthFactor)
                    height: activePageCol.implicitHeight
                    scale: win.pageTransitionScale
                    opacity: win.pageTransitionOpacity
                    transformOrigin: Item.Top

                    Column {
                        id: activePageCol
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Math.round(5 * win.s * win.heightFactor)

                        // ════════════════════════════════════════════════════════
                        // PAGE 0: ACTIONS + SEKAIPLATE STATUS PILL + AUDIO/BRIGHT
                        // ════════════════════════════════════════════════════════
                        Column {
                            id: pageActions
                            visible: win.currentPage === 0
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Math.round(5 * win.s * win.heightFactor)

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: Math.round(6 * win.s)

                                WorkspaceCapsuleStrip {
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: Math.round(24 * win.s)
                                    width: connRow.implicitWidth + Math.round(14 * win.s)
                                    radius: height / 2
                                    color: sekaiTheme.chipFill
                                    border.width: Math.max(1, Math.round(2 * win.s))
                                    border.color: sekaiTheme.pRingWhite

                                    Rectangle {
                                        z: -1
                                        x: 0
                                        y: Math.round(2 * win.s)
                                        width: parent.width
                                        height: parent.height
                                        radius: parent.radius
                                        color: sekaiTheme.pLineShadow
                                    }

                                    Row {
                                        id: connRow
                                        anchors.centerIn: parent
                                        spacing: Math.round(6 * win.s)

                                        Text {
                                            text: win.wifiEnabled ? "wifi" : "wifi_off"
                                            color: win.wifiEnabled ? sekaiTheme.accentMint : "#ffffff"
                                            opacity: win.wifiEnabled ? 1.0 : 0.45
                                            font.family: sekaiTheme.iconFont
                                            font.pixelSize: Math.round(13 * win.s)
                                            Behavior on opacity { NumberAnimation { duration: 180 } }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: win.wifiEnabled = !win.wifiEnabled
                                            }
                                        }
                                        Text {
                                            text: win.btEnabled ? "bluetooth" : "bluetooth_disabled"
                                            color: win.btEnabled ? sekaiTheme.accentCyan : "#ffffff"
                                            opacity: win.btEnabled ? 1.0 : 0.45
                                            font.family: sekaiTheme.iconFont
                                            font.pixelSize: Math.round(13 * win.s)
                                            Behavior on opacity { NumberAnimation { duration: 180 } }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: win.btEnabled = !win.btEnabled
                                            }
                                        }
                                        Text {
                                            text: win.dndEnabled ? "notifications_off" : "notifications_active"
                                            color: win.dndEnabled ? sekaiTheme.warnFill : "#ffffff"
                                            font.family: sekaiTheme.iconFont
                                            font.pixelSize: Math.round(13 * win.s)
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    win.dndEnabled = !win.dndEnabled
                                                    dndProc.running = true
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Column {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: Math.round(3 * win.s)

                                SekaiSlider {
                                    label: win.volumeMuted ? "MUTED" : "VOLUME"
                                    icon: win.volumeMuted ? "volume_off" : "volume_up"
                                    from: 0
                                    to: 100
                                    stepSize: 2
                                    value: win.volumePct
                                    displayMultiplier: 1
                                    suffix: "%"
                                    onMoved: newValue => win.setSystemVolume(Math.round(newValue))
                                }

                                SekaiSlider {
                                    label: "BRIGHT"
                                    icon: "light_mode"
                                    from: 5
                                    to: 100
                                    stepSize: 2
                                    value: win.brightnessPct
                                    displayMultiplier: 1
                                    suffix: "%"
                                    onMoved: newValue => win.setSystemBrightness(Math.round(newValue))
                                }
                            }

                            Item {
                                id: activeGridContainer
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: activeGrid.implicitWidth
                                height: activeGrid.implicitHeight

                                Rectangle {
                                    visible: win.dragActive && win.dragSourceType === "pool" && win.hoveredGridDrop
                                    anchors.fill: parent
                                    anchors.margins: -Math.round(4 * win.s)
                                    radius: Math.round(12 * win.s)
                                    color: Qt.rgba(sekaiTheme.accentMint.r, sekaiTheme.accentMint.g, sekaiTheme.accentMint.b, 0.18)
                                    border.width: Math.max(1, Math.round(2 * win.s))
                                    border.color: sekaiTheme.accentMint
                                }

                                Grid {
                                    id: activeGrid
                                    anchors.centerIn: parent
                                    columns: Math.max(1, win.gridColumns)
                                    rowSpacing: Math.round(6 * win.s * win.heightFactor)
                                    columnSpacing: Math.round(8 * win.s * win.widthFactor)

                                    Repeater {
                                        id: activeRepeater
                                        model: win.activeActionsModel
                                        delegate: NotchButton {
                                            id: actBtnDel
                                            required property var modelData
                                            required property int index

                                            sekaiTheme: sekaiTheme
                                            s: win.s
                                            buttonWidthScale: win.widthFactor
                                            buttonHeightScale: win.heightFactor
                                            bounceOvershoot: win.bounceOvershoot
                                            showSlants: win.showSlants
                                            enable25D: win.enable25D
                                            // staggerIndex removed (unsupported)
                                            // entranceActive removed (unsupported by current NotchShape)
                                            actionId: actBtnDel.modelData.action
                                            icon: actBtnDel.modelData.icon
                                            label: actBtnDel.modelData.label
                                            accentIndex: actBtnDel.modelData.accentIdx
                                            pending: win.pendingAction === actBtnDel.modelData.action
                                            editMode: win.settingsOpen
                                            canRemove: win.activeActionIds.length > 1
                                            isInsertMode: win.dragSourceType === "pool"
                                            isDropTarget: win.dragActive && win.hoveredDropSlot === actBtnDel.index &&
                                                          !(win.dragSourceType === "active" && win.dragSourceIndex === actBtnDel.index)
                                            isBeingDragged: win.dragActive && win.dragSourceType === "active" && win.dragSourceIndex === actBtnDel.index

                                            onClicked: win.runAction(actBtnDel.modelData.action)
                                            onRemoveRequested: win.removeActionById(actBtnDel.modelData.action)
                                            onDragStarted: (gx, gy) => win.startDrag("active", actBtnDel.index, actBtnDel.modelData.action, gx, gy)
                                            onDragMoved: (gx, gy) => win.updateDrag(gx, gy)
                                            onDragEnded: (gx, gy) => win.endDrag(gx, gy)
                                        }
                                    }

                                    Rectangle {
                                        visible: win.settingsOpen && win.poolActionsModel.length > 0
                                        width: Math.round(110 * win.s * win.widthFactor)
                                        height: Math.round(32 * win.s * win.heightFactor)
                                        radius: Math.round(11 * win.s)
                                        scale: addHereMa.containsMouse ? 1.05 : 1.0
                                        color: (win.dragActive && win.dragSourceType === "pool" && win.hoveredDropSlot < 0 && win.hoveredGridDrop)
                                            ? Qt.rgba(sekaiTheme.accentMint.r, sekaiTheme.accentMint.g, sekaiTheme.accentMint.b, 0.35)
                                            : sekaiTheme.pSurfaceHover
                                        border.width: Math.max(2, Math.round(2 * win.s))
                                        border.color: sekaiTheme.accentMint

                                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: Math.round(4 * win.s)

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "add_circle"
                                                color: sekaiTheme.pInk
                                                font.family: sekaiTheme.iconFont
                                                font.pixelSize: Math.round(14 * win.s)
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "ADD HERE"
                                                color: sekaiTheme.pInk
                                                font.family: sekaiTheme.fontFamily
                                                font.pixelSize: Math.round(9.5 * win.s)
                                                font.weight: Font.ExtraBold
                                                font.styleName: sekaiTheme.fontStyleBold
                                            }
                                        }

                                        MouseArea {
                                            id: addHereMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (win.poolActionsModel.length > 0)
                                                    win.addActionAt(win.poolActionsModel[0].action, -1)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ════════════════════════════════════════════════════════
                        // PAGE 1: CUTE & FUN SEKAI STAGE MUSIC PLAYER
                        // ════════════════════════════════════════════════════════
                        Column {
                            id: pageMedia
                            visible: win.currentPage === 1
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Math.round(6 * win.s * win.heightFactor)

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: Math.round(4 * win.s)

                                Repeater {
                                    model: [
                                        { id: "vinyl", icon: "album",        label: "DISC"  },
                                        { id: "tape",  icon: "voicemail",    label: "TAPE"  },
                                        { id: "stage", icon: "auto_awesome", label: "STAGE" }
                                    ]
                                    delegate: Rectangle {
                                        id: mModeDel
                                        required property var modelData
                                        readonly property bool active: win.musicDisplayMode === mModeDel.modelData.id

                                        width: Math.round(48 * win.s * win.widthFactor)
                                        height: Math.round(19 * win.s)
                                        radius: height / 2
                                        rotation: active ? -2.0 : 0.0
                                        scale: mModeMa.pressed ? 0.90 : (active ? 1.05 : (mModeMa.containsMouse ? 1.04 : 1.0))
                                        color: active ? sekaiTheme.accentMint : sekaiTheme.pSurfaceHover
                                        border.width: Math.max(1, Math.round(1.5 * win.s))
                                        border.color: sekaiTheme.colBorder

                                        Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
                                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
                                        Behavior on color { ColorAnimation { duration: 150 } }

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: Math.round(2 * win.s)

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: mModeDel.modelData.icon
                                                color: mModeDel.active ? sekaiTheme.colBorder : sekaiTheme.pInk
                                                font.family: sekaiTheme.iconFont
                                                font.pixelSize: Math.round(10 * win.s)
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: mModeDel.modelData.label
                                                color: mModeDel.active ? sekaiTheme.colBorder : sekaiTheme.pInk
                                                font.family: sekaiTheme.fontFamily
                                                font.pixelSize: Math.round(7 * win.s)
                                                font.weight: Font.ExtraBold
                                                font.styleName: sekaiTheme.fontStyleBold
                                            }
                                        }

                                        MouseArea {
                                            id: mModeMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                win.musicDisplayMode = mModeDel.modelData.id
                                                win.requestSaveConfig()
                                                win.triggerMusicCheer("STYLE UP! ★")
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: Math.round(58 * win.s * win.widthFactor)
                                    height: Math.round(19 * win.s)
                                    radius: height / 2
                                    color: win.musicNotchEnabled ? sekaiTheme.cuteYellow : sekaiTheme.pSurfaceHover
                                    border.width: Math.max(1, Math.round(1.5 * win.s))
                                    border.color: sekaiTheme.colBorder

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: win.musicNotchEnabled ? "MORPH: ON" : "MORPH: OFF"
                                        color: win.musicNotchEnabled ? sekaiTheme.colBorder : sekaiTheme.pInk
                                        font.family: sekaiTheme.fontFamily
                                        font.pixelSize: Math.round(6.8 * win.s)
                                        font.weight: Font.ExtraBold
                                        font.styleName: sekaiTheme.fontStyleBold
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            win.musicNotchEnabled = !win.musicNotchEnabled
                                            win.requestSaveConfig()
                                            win.triggerMusicCheer(win.musicNotchEnabled ? "CUTE NOTCH! ♡" : "CLASSIC! ★")
                                        }
                                    }
                                }

                                Rectangle {
                                    id: cheerComboBadge
                                    width: Math.round(52 * win.s * win.widthFactor)
                                    height: Math.round(19 * win.s)
                                    radius: height / 2
                                    rotation: 2.5
                                    scale: win.judgePopScale
                                    color: sekaiTheme.cutePink
                                    border.width: Math.max(1, Math.round(1.5 * win.s))
                                    border.color: sekaiTheme.colBorder

                                    Text {
                                        anchors.centerIn: parent
                                        text: "♡ x" + win.musicCombo
                                        color: sekaiTheme.colBorder
                                        font.family: sekaiTheme.fontFamily
                                        font.pixelSize: Math.round(7.5 * win.s)
                                        font.weight: Font.ExtraBold
                                        font.styleName: sekaiTheme.fontStyleBold
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: win.triggerMusicCheer("KIRA KIRA! ♡")
                                    }
                                }
                            }

                            // MAIN CUTE STAGE CARD
                            Item {
                                id: cuteStageCard
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.round(268 * win.s * win.widthFactor)
                                height: Math.round(108 * win.s * win.heightFactor)

                                readonly property real shadowDy: Math.max(2, Math.round(sekaiTheme.shadowOffset * win.s))
                                readonly property real borderW: Math.max(2, Math.round(sekaiTheme.borderWidth * win.s))
                                readonly property real ringW: Math.max(2, Math.round(2.5 * win.s))
                                readonly property real cornerR: Math.round(sekaiTheme.radiusBadge * win.s)

                                Rectangle {
                                    x: 0
                                    y: cuteStageCard.shadowDy
                                    width: parent.width
                                    height: parent.height - cuteStageCard.shadowDy
                                    radius: cuteStageCard.cornerR
                                    color: sekaiTheme.pLineShadow
                                }

                                Rectangle {
                                    width: parent.width
                                    height: parent.height - cuteStageCard.shadowDy
                                    radius: cuteStageCard.cornerR
                                    color: sekaiTheme.colBorder

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: cuteStageCard.borderW
                                        radius: Math.max(3, cuteStageCard.cornerR - cuteStageCard.borderW)
                                        color: sekaiTheme.pRingWhite

                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.margins: cuteStageCard.ringW
                                            radius: Math.max(2, cuteStageCard.cornerR - cuteStageCard.borderW - cuteStageCard.ringW)
                                            clip: true
                                            border.width: Math.max(1, Math.round(1.5 * win.s))
                                            border.color: sekaiTheme.colBorder

                                            gradient: Gradient {
                                                orientation: Gradient.Horizontal
                                                GradientStop { position: 0.0; color: sekaiTheme.accentMint }
                                                GradientStop { position: 1.0; color: sekaiTheme.accentCyan }
                                            }

                                            Repeater {
                                                model: ["♪", "★", "♫", "♡", "✦"]
                                                delegate: Text {
                                                    id: floatNote
                                                    required property string modelData
                                                    required property int index
                                                    readonly property real bounceY: win.mediaPlaying
                                                        ? Math.sin(win.vizPhase * 0.35 + floatNote.index * 1.3) * 4 * win.s
                                                        : 0
                                                    x: Math.round((12 + floatNote.index * 54) * win.s * win.widthFactor)
                                                    y: Math.round(6 * win.s) + bounceY
                                                    text: floatNote.modelData
                                                    color: "#ffffff"
                                                    opacity: 0.55
                                                    font.family: sekaiTheme.fontFamily
                                                    font.pixelSize: Math.round(11 * win.s)
                                                    font.weight: Font.ExtraBold
                                                    Behavior on y { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }
                                                }
                                            }

                                            // MODE A: "VINYL" — KAWAII TURNTABLE + MANGA LYRICS BUBBLE
                                            Item {
                                                visible: win.musicDisplayMode === "vinyl"
                                                anchors.fill: parent
                                                anchors.margins: Math.round(6 * win.s)

                                                Item {
                                                    id: turntableBox
                                                    anchors.left: parent.left
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: Math.round(88 * win.s)
                                                    height: Math.round(82 * win.s)

                                                    Rectangle {
                                                        x: 0
                                                        y: Math.round(6 * win.s)
                                                        width: Math.round(44 * win.s)
                                                        height: Math.round(68 * win.s)
                                                        radius: Math.round(8 * win.s)
                                                        rotation: -6
                                                        color: sekaiTheme.cutePink
                                                        border.width: Math.max(1, Math.round(2 * win.s))
                                                        border.color: sekaiTheme.colBorder

                                                        Text {
                                                            anchors.left: parent.left
                                                            anchors.leftMargin: Math.round(4 * win.s)
                                                            anchors.bottom: parent.bottom
                                                            anchors.bottomMargin: Math.round(4 * win.s)
                                                            text: "★39"
                                                            color: sekaiTheme.colBorder
                                                            font.family: sekaiTheme.fontFamily
                                                            font.pixelSize: Math.round(7.5 * win.s)
                                                            font.weight: Font.ExtraBold
                                                        }
                                                    }

                                                    Item {
                                                        id: vinylDisc
                                                        x: Math.round(12 * win.s)
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: Math.round(68 * win.s)
                                                        height: Math.round(68 * win.s)
                                                        rotation: win.discAngle

                                                        Behavior on rotation { NumberAnimation { duration: 115; easing.type: Easing.Linear } }

                                                        Rectangle {
                                                            anchors.fill: parent
                                                            radius: width / 2
                                                            color: sekaiTheme.colDeep
                                                            border.width: Math.max(2, Math.round(2.5 * win.s))
                                                            border.color: "#ffffff"

                                                            Rectangle {
                                                                anchors.centerIn: parent
                                                                width: parent.width - Math.round(10 * win.s)
                                                                height: width
                                                                radius: width / 2
                                                                color: "transparent"
                                                                border.width: Math.max(1, Math.round(1.5 * win.s))
                                                                border.color: sekaiTheme.accentCyan
                                                                opacity: 0.45
                                                            }

                                                            Rectangle {
                                                                anchors.centerIn: parent
                                                                width: parent.width - Math.round(6 * win.s)
                                                                height: Math.round(6 * win.s)
                                                                rotation: 45
                                                                color: "#ffffff"
                                                                opacity: 0.18
                                                            }

                                                            Rectangle {
                                                                anchors.centerIn: parent
                                                                width: Math.round(36 * win.s)
                                                                height: width
                                                                radius: width / 2
                                                                color: sekaiTheme.cuteYellow
                                                                border.width: Math.max(1, Math.round(2 * win.s))
                                                                border.color: "#ffffff"
                                                                clip: true

                                                                Image {
                                                                    id: discArtImg
                                                                    anchors.fill: parent
                                                                    source: win.mediaActive ? win.mediaArtUrl : ""
                                                                    fillMode: Image.PreserveAspectCrop
                                                                    asynchronous: true
                                                                    smooth: true
                                                                    visible: status === Image.Ready
                                                                }

                                                                Text {
                                                                    visible: !discArtImg.visible
                                                                    anchors.centerIn: parent
                                                                    text: "music_note"
                                                                    color: sekaiTheme.colBorder
                                                                    font.family: sekaiTheme.iconFont
                                                                    font.pixelSize: Math.round(15 * win.s)
                                                                }
                                                            }

                                                            Rectangle {
                                                                anchors.centerIn: parent
                                                                width: Math.round(9 * win.s)
                                                                height: width
                                                                radius: width / 2
                                                                color: "#ffffff"
                                                                border.width: Math.max(1, Math.round(2 * win.s))
                                                                border.color: sekaiTheme.colBorder
                                                            }
                                                        }
                                                    }

                                                    Item {
                                                        x: Math.round(72 * win.s)
                                                        y: Math.round(6 * win.s)
                                                        width: Math.round(14 * win.s)
                                                        height: Math.round(48 * win.s)
                                                        transformOrigin: Item.Top
                                                        rotation: win.mediaPlaying ? 24 : -6

                                                        Behavior on rotation {
                                                            NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.9 }
                                                        }

                                                        Rectangle {
                                                            anchors.top: parent.top
                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                            width: Math.round(12 * win.s)
                                                            height: Math.round(12 * win.s)
                                                            radius: width / 2
                                                            color: "#ffffff"
                                                            border.width: Math.max(1, Math.round(2 * win.s))
                                                            border.color: sekaiTheme.colBorder
                                                        }

                                                        Rectangle {
                                                            anchors.top: parent.top
                                                            anchors.topMargin: Math.round(8 * win.s)
                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                            width: Math.round(4 * win.s)
                                                            height: Math.round(32 * win.s)
                                                            radius: width / 2
                                                            color: "#ffffff"
                                                            border.width: 1
                                                            border.color: sekaiTheme.colBorder
                                                        }

                                                        Rectangle {
                                                            anchors.bottom: parent.bottom
                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                            width: Math.round(10 * win.s)
                                                            height: Math.round(10 * win.s)
                                                            radius: Math.round(2.5 * win.s)
                                                            rotation: 45
                                                            color: sekaiTheme.cutePink
                                                            border.width: Math.max(1, Math.round(1.5 * win.s))
                                                            border.color: sekaiTheme.colBorder
                                                        }
                                                    }
                                                }

                                                Column {
                                                    anchors.left: turntableBox.right
                                                    anchors.leftMargin: Math.round(4 * win.s)
                                                    anchors.right: parent.right
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    spacing: Math.round(4 * win.s)

                                                    Row {
                                                        spacing: Math.round(5 * win.s)

                                                        Rectangle {
                                                            width: Math.round(62 * win.s)
                                                            height: Math.round(14 * win.s)
                                                            radius: Math.round(4 * win.s)
                                                            rotation: -2
                                                            color: sekaiTheme.cuteYellow
                                                            border.width: 1
                                                            border.color: sekaiTheme.colBorder

                                                            Text {
                                                                anchors.centerIn: parent
                                                                text: win.mediaPlaying ? "★ ON STAGE" : "☆ PAUSED"
                                                                color: sekaiTheme.colBorder
                                                                font.family: sekaiTheme.fontFamily
                                                                font.pixelSize: Math.round(7 * win.s)
                                                                font.weight: Font.ExtraBold
                                                                font.styleName: sekaiTheme.fontStyleBold
                                                            }
                                                        }

                                                        Row {
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            spacing: Math.round(2 * win.s)

                                                            Repeater {
                                                                model: 6
                                                                Rectangle {
                                                                    id: eqPill
                                                                    required property int index
                                                                    readonly property real amp: win.mediaPlaying ? (win.vizPoints[eqPill.index] || 0.3) : 0.25
                                                                    width: Math.round(3.5 * win.s)
                                                                    height: Math.max(4, Math.round(13 * win.s * amp))
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                    radius: width / 2
                                                                    color: eqPill.index % 2 === 0 ? sekaiTheme.colBorder : "#ffffff"
                                                                    Behavior on height { NumberAnimation { duration: 105; easing.type: Easing.OutQuad } }
                                                                }
                                                            }
                                                        }
                                                    }

                                                    Text {
                                                        width: parent.width
                                                        elide: Text.ElideRight
                                                        text: win.mediaActive ? win.mediaTitle : "Tell Your World ★"
                                                        color: sekaiTheme.colBorder
                                                        font.family: sekaiTheme.fontFamily
                                                        font.pixelSize: Math.round(11 * win.s)
                                                        font.weight: Font.ExtraBold
                                                        font.styleName: sekaiTheme.fontStyleBold
                                                    }

                                                    Text {
                                                        width: parent.width
                                                        elide: Text.ElideRight
                                                        text: win.mediaActive
                                                            ? (win.mediaArtist !== "" ? win.mediaArtist : win.mediaPlayerName)
                                                            : "Virtual Singer • Scroll for Vol"
                                                        color: sekaiTheme.colBorder
                                                        opacity: 0.78
                                                        font.family: sekaiTheme.fontFamily
                                                        font.pixelSize: Math.round(8 * win.s)
                                                        font.weight: Font.Bold
                                                    }

                                                    Rectangle {
                                                        width: parent.width
                                                        height: Math.round(22 * win.s)
                                                        radius: Math.round(8 * win.s)
                                                        color: "#ffffff"
                                                        border.width: Math.max(1, Math.round(1.5 * win.s))
                                                        border.color: sekaiTheme.colBorder

                                                        Rectangle {
                                                            x: -Math.round(3 * win.s)
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            width: Math.round(7 * win.s)
                                                            height: Math.round(7 * win.s)
                                                            rotation: 45
                                                            color: "#ffffff"
                                                            border.width: 1
                                                            border.color: sekaiTheme.colBorder
                                                        }

                                                        Row {
                                                            anchors.fill: parent
                                                            anchors.leftMargin: Math.round(6 * win.s)
                                                            anchors.rightMargin: Math.round(6 * win.s)
                                                            spacing: Math.round(4 * win.s)

                                                            Text {
                                                                anchors.verticalCenter: parent.verticalCenter
                                                                text: "💬"
                                                                font.pixelSize: Math.round(9 * win.s)
                                                            }

                                                            Text {
                                                                width: parent.width - Math.round(18 * win.s)
                                                                anchors.verticalCenter: parent.verticalCenter
                                                                elide: Text.ElideRight
                                                                text: win.mediaLyricLine
                                                                color: sekaiTheme.colBorder
                                                                font.family: sekaiTheme.fontFamily
                                                                font.pixelSize: Math.round(7.5 * win.s)
                                                                font.weight: Font.ExtraBold
                                                                font.styleName: sekaiTheme.fontStyleBold
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            // MODE B: "TAPE" — RETRO-CUTE Y2K SEKAI CASSETTE
                                            Item {
                                                visible: win.musicDisplayMode === "tape"
                                                anchors.fill: parent
                                                anchors.margins: Math.round(6 * win.s)

                                                Repeater {
                                                    model: 4
                                                    delegate: Rectangle {
                                                        id: screwDel
                                                        required property int index
                                                        x: (screwDel.index % 2 === 0) ? Math.round(2 * win.s) : (parent.width - width - Math.round(2 * win.s))
                                                        y: (screwDel.index < 2) ? Math.round(2 * win.s) : (parent.height - height - Math.round(2 * win.s))
                                                        width: Math.round(6 * win.s)
                                                        height: Math.round(6 * win.s)
                                                        radius: width / 2
                                                        color: "#ffffff"
                                                        border.width: 1
                                                        border.color: sekaiTheme.colBorder
                                                    }
                                                }

                                                Rectangle {
                                                    anchors.top: parent.top
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    width: parent.width - Math.round(22 * win.s)
                                                    height: Math.round(26 * win.s)
                                                    radius: Math.round(6 * win.s)
                                                    color: "#ffffff"
                                                    border.width: Math.max(1, Math.round(1.5 * win.s))
                                                    border.color: sekaiTheme.colBorder

                                                    Row {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: Math.round(6 * win.s)
                                                        anchors.rightMargin: Math.round(6 * win.s)
                                                        spacing: Math.round(6 * win.s)

                                                        Rectangle {
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            width: Math.round(28 * win.s)
                                                            height: Math.round(16 * win.s)
                                                            radius: Math.round(4 * win.s)
                                                            color: sekaiTheme.cutePink
                                                            border.width: 1
                                                            border.color: sekaiTheme.colBorder
                                                            Text {
                                                                anchors.centerIn: parent
                                                                text: "A-39"
                                                                color: sekaiTheme.colBorder
                                                                font.family: sekaiTheme.fontFamily
                                                                font.pixelSize: Math.round(7.5 * win.s)
                                                                font.weight: Font.ExtraBold
                                                            }
                                                        }

                                                        Column {
                                                            width: parent.width - Math.round(42 * win.s)
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            Text {
                                                                width: parent.width
                                                                elide: Text.ElideRight
                                                                text: win.mediaActive ? win.mediaTitle : "Sekai Mixtape Vol.1 ★"
                                                                color: sekaiTheme.colBorder
                                                                font.family: sekaiTheme.fontFamily
                                                                font.pixelSize: Math.round(9.5 * win.s)
                                                                font.weight: Font.ExtraBold
                                                                font.styleName: sekaiTheme.fontStyleBold
                                                            }
                                                            Text {
                                                                width: parent.width
                                                                elide: Text.ElideRight
                                                                text: win.mediaActive ? win.mediaArtist : "Hatsune Miku & Friends"
                                                                color: sekaiTheme.colBorder
                                                                opacity: 0.72
                                                                font.family: sekaiTheme.fontFamily
                                                                font.pixelSize: Math.round(7.5 * win.s)
                                                                font.weight: Font.Bold
                                                            }
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    anchors.bottom: parent.bottom
                                                    anchors.bottomMargin: Math.round(4 * win.s)
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    width: parent.width - Math.round(32 * win.s)
                                                    height: Math.round(44 * win.s)
                                                    radius: height / 2
                                                    color: sekaiTheme.colDeep
                                                    border.width: Math.max(2, Math.round(2 * win.s))
                                                    border.color: "#ffffff"

                                                    Row {
                                                        anchors.centerIn: parent
                                                        spacing: Math.round(14 * win.s)

                                                        CassetteReel {
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            reelRotation: win.discAngle
                                                        }

                                                        Row {
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            spacing: Math.round(2.5 * win.s)

                                                            Repeater {
                                                                model: 6
                                                                Rectangle {
                                                                    id: tapeEq
                                                                    required property int index
                                                                    readonly property real amp: win.mediaPlaying ? (win.vizPoints[tapeEq.index] || 0.35) : 0.25
                                                                    width: Math.round(4 * win.s)
                                                                    height: Math.max(5, Math.round(24 * win.s * amp))
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                    radius: width / 2
                                                                    color: tapeEq.index % 2 === 0 ? sekaiTheme.accentMint : sekaiTheme.cutePink
                                                                    Behavior on height { NumberAnimation { duration: 105; easing.type: Easing.OutQuad } }
                                                                }
                                                            }
                                                        }

                                                        CassetteReel {
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            reelRotation: win.discAngle
                                                        }
                                                    }
                                                }
                                            }

                                            // MODE C: "STAGE" — PROJECT SEKAI RHYTHM GAME LANES
                                            Item {
                                                visible: win.musicDisplayMode === "stage"
                                                anchors.fill: parent
                                                anchors.margins: Math.round(6 * win.s)

                                                Row {
                                                    anchors.fill: parent
                                                    spacing: Math.round(4 * win.s)

                                                    Repeater {
                                                        model: 4
                                                        delegate: Rectangle {
                                                            id: laneDel
                                                            required property int index
                                                            width: (parent.width - Math.round(12 * win.s)) / 4
                                                            height: parent.height
                                                            radius: Math.round(7 * win.s)
                                                            color: Qt.rgba(0.14, 0.13, 0.21, 0.78)
                                                            border.width: Math.max(1, Math.round(1.5 * win.s))
                                                            border.color: "#ffffff"
                                                            clip: true

                                                            readonly property real notePos: win.mediaPlaying
                                                                ? ((win.vizPhase * 7 + laneDel.index * 29) % 100) / 100.0
                                                                : (0.25 + laneDel.index * 0.15)

                                                            Rectangle {
                                                                anchors.horizontalCenter: parent.horizontalCenter
                                                                y: Math.round(laneDel.notePos * (parent.height - Math.round(24 * win.s)))
                                                                width: parent.width - Math.round(8 * win.s)
                                                                height: Math.round(13 * win.s)
                                                                radius: height / 2
                                                                color: laneDel.index === 1
                                                                    ? sekaiTheme.cutePink
                                                                    : (laneDel.index === 2 ? sekaiTheme.cuteYellow : sekaiTheme.accentMint)
                                                                border.width: Math.max(1, Math.round(1.5 * win.s))
                                                                border.color: "#ffffff"

                                                                Text {
                                                                    anchors.centerIn: parent
                                                                    text: laneDel.index === 1 ? "▲ FLICK" : (laneDel.index === 2 ? "★ GOLD" : "● TAP")
                                                                    color: sekaiTheme.colBorder
                                                                    font.family: sekaiTheme.fontFamily
                                                                    font.pixelSize: Math.round(6.5 * win.s)
                                                                    font.weight: Font.ExtraBold
                                                                }
                                                            }

                                                            Rectangle {
                                                                anchors.bottom: parent.bottom
                                                                anchors.bottomMargin: Math.round(6 * win.s)
                                                                anchors.horizontalCenter: parent.horizontalCenter
                                                                width: parent.width - Math.round(4 * win.s)
                                                                height: Math.round(5 * win.s)
                                                                radius: height / 2
                                                                color: sekaiTheme.accentCyan
                                                            }

                                                            MouseArea {
                                                                anchors.fill: parent
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: win.triggerMusicCheer(laneDel.index % 2 === 0 ? "PERFECT! ★" : "GREAT! ♡")
                                                            }
                                                        }
                                                    }
                                                }

                                                Column {
                                                    anchors.centerIn: parent
                                                    spacing: Math.round(2 * win.s)
                                                    scale: win.judgePopScale

                                                    GlyphRingText {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        value: win.musicJudgeText
                                                        pixelSize: Math.round(12 * win.s)
                                                        fillColor: sekaiTheme.cuteYellow
                                                    }

                                                    Rectangle {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        width: Math.min(Math.round(210 * win.s), stageTitleTxt.implicitWidth + Math.round(14 * win.s))
                                                        height: Math.round(18 * win.s)
                                                        radius: height / 2
                                                        color: "#ffffff"
                                                        border.width: Math.max(1, Math.round(1.5 * win.s))
                                                        border.color: sekaiTheme.colBorder

                                                        Text {
                                                            id: stageTitleTxt
                                                            anchors.centerIn: parent
                                                            width: Math.min(Math.round(196 * win.s), implicitWidth)
                                                            elide: Text.ElideRight
                                                            text: "♪ " + (win.mediaActive ? win.mediaTitle : "Tell Your World")
                                                            color: sekaiTheme.colBorder
                                                            font.family: sekaiTheme.fontFamily
                                                            font.pixelSize: Math.round(8.5 * win.s)
                                                            font.weight: Font.ExtraBold
                                                            font.styleName: sekaiTheme.fontStyleBold
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.MiddleButton
                                    onClicked: win.sendMediaCommand("play-pause")
                                    onWheel: wheel => {
                                        const step = wheel.angleDelta.y > 0 ? 5 : -5
                                        win.setSystemVolume(win.volumePct + step)
                                    }
                                }
                            }

                            // CUTE CANDY / STAR SEEK BAR
                            Item {
                                id: cuteSeekBar
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.round(264 * win.s * win.widthFactor)
                                height: Math.round(20 * win.s)

                                Row {
                                    anchors.fill: parent
                                    spacing: Math.round(6 * win.s)

                                    Rectangle {
                                        width: Math.round(36 * win.s)
                                        height: Math.round(16 * win.s)
                                        anchors.verticalCenter: parent.verticalCenter
                                        radius: height / 2
                                        color: sekaiTheme.chipFill

                                        Text {
                                            anchors.centerIn: parent
                                            text: win.mediaPosFormatted
                                            color: "#ffffff"
                                            font.family: sekaiTheme.fontFamily
                                            font.pixelSize: Math.round(7.5 * win.s)
                                            font.weight: Font.ExtraBold
                                        }
                                    }

                                    Item {
                                        id: mediaSeekTrack
                                        width: parent.width - Math.round(84 * win.s)
                                        height: Math.round(12 * win.s)
                                        anchors.verticalCenter: parent.verticalCenter

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: height / 2
                                            color: sekaiTheme.pSurfaceDivider
                                            border.width: Math.max(1, Math.round(2 * win.s))
                                            border.color: sekaiTheme.colBorder
                                            clip: true

                                            Rectangle {
                                                width: Math.max(parent.height, parent.width * win.mediaProgress)
                                                height: parent.height
                                                radius: height / 2
                                                border.width: 1
                                                border.color: sekaiTheme.colBorder
                                                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                                gradient: Gradient {
                                                    orientation: Gradient.Horizontal
                                                    GradientStop { position: 0.0; color: sekaiTheme.cutePink }
                                                    GradientStop { position: 0.5; color: sekaiTheme.accentMint }
                                                    GradientStop { position: 1.0; color: sekaiTheme.accentCyan }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            x: Math.round((mediaSeekTrack.width - width) * win.mediaProgress)
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: Math.round(16 * win.s)
                                            height: Math.round(16 * win.s)
                                            radius: Math.round(5 * win.s)
                                            rotation: win.mediaPlaying ? (win.discAngle % 90) : 45
                                            scale: seekMa.containsMouse ? 1.18 : 1.0
                                            color: sekaiTheme.cuteYellow
                                            border.width: Math.max(1, Math.round(2 * win.s))
                                            border.color: sekaiTheme.colBorder

                                            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "★"
                                                color: sekaiTheme.colBorder
                                                font.pixelSize: Math.round(8 * win.s)
                                                font.weight: Font.ExtraBold
                                                visible: !win.cuteMusicCollapsed
                                            }
                                        }

                                        MouseArea {
                                            id: seekMa
                                            anchors.fill: parent
                                            anchors.margins: -Math.round(4 * win.s)
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onPressed: mouse => {
                                                const r = Math.max(0, Math.min(1, mouse.x / Math.max(1, mediaSeekTrack.width)))
                                                win.seekMediaToRatio(r)
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: Math.round(36 * win.s)
                                        height: Math.round(16 * win.s)
                                        anchors.verticalCenter: parent.verticalCenter
                                        radius: height / 2
                                        color: sekaiTheme.pSurfaceHover
                                        border.width: 1
                                        border.color: sekaiTheme.colBorder

                                        Text {
                                            anchors.centerIn: parent
                                            text: win.mediaLenFormatted
                                            color: sekaiTheme.pInk
                                            font.family: sekaiTheme.fontFamily
                                            font.pixelSize: Math.round(7.5 * win.s)
                                            font.weight: Font.ExtraBold
                                        }
                                    }
                                }
                            }

                            // CUTE BOUNCY STICKER TRANSPORT PILLS
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: Math.round(8 * win.s * win.widthFactor)

                                Repeater {
                                    model: [
                                        { cmd: "previous",   icon: "skip_previous", label: "PREV", isMain: false, tilt: -2.0, col: sekaiTheme.chipFill },
                                        { cmd: "play-pause", icon: win.mediaPlaying ? "pause" : "play_arrow", label: win.mediaPlaying ? "PAUSE ♪" : "PLAY ★", isMain: true, tilt: 1.5, col: sekaiTheme.accentMint },
                                        { cmd: "next",       icon: "skip_next",     label: "NEXT", isMain: false, tilt: -1.5, col: sekaiTheme.chipFill }
                                    ]
                                    delegate: Rectangle {
                                        id: mTransDel
                                        required property var modelData
                                        width: Math.round((mTransDel.modelData.isMain ? 96 : 74) * win.s * win.widthFactor)
                                        height: Math.round(30 * win.s * win.heightFactor)
                                        radius: height / 2
                                        rotation: mBtnMa.containsMouse ? -mTransDel.modelData.tilt : mTransDel.modelData.tilt
                                        color: mBtnMa.containsMouse ? Qt.lighter(mTransDel.modelData.col, 1.15) : mTransDel.modelData.col
                                        border.width: Math.max(2, Math.round(2 * win.s))
                                        border.color: mTransDel.modelData.isMain ? sekaiTheme.colBorder : sekaiTheme.pRingWhite
                                        scale: mBtnMa.pressed ? 0.88 : (mBtnMa.containsMouse ? 1.07 : 1.0)

                                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2.3 } }
                                        Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

                                        Rectangle {
                                            z: -1
                                            x: 0
                                            y: Math.round(3 * win.s)
                                            width: parent.width
                                            height: parent.height
                                            radius: parent.radius
                                            color: sekaiTheme.pLineShadow
                                        }

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: Math.round(4 * win.s)

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: mTransDel.modelData.icon
                                                color: mTransDel.modelData.isMain ? sekaiTheme.colBorder : sekaiTheme.accentMint
                                                font.family: sekaiTheme.iconFont
                                                font.pixelSize: Math.round(15 * win.s)
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: mTransDel.modelData.label
                                                color: mTransDel.modelData.isMain ? sekaiTheme.colBorder : "#ffffff"
                                                font.family: sekaiTheme.fontFamily
                                                font.pixelSize: Math.round(9 * win.s)
                                                font.weight: Font.ExtraBold
                                                font.styleName: sekaiTheme.fontStyleBold
                                            }
                                        }

                                        MouseArea {
                                            id: mBtnMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: win.sendMediaCommand(mTransDel.modelData.cmd)
                                        }
                                    }
                                }
                            }
                        }

                        // ════════════════════════════════════════════════════════
                        // PAGE 2: WORKSPACES MATRIX VIEW
                        // ════════════════════════════════════════════════════════
                        Column {
                            id: pageSpaces
                            visible: win.currentPage === 2
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Math.round(8 * win.s * win.heightFactor)

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: Math.round(6 * win.s)

                                Rectangle {
                                    width: Math.round(24 * win.s)
                                    height: Math.round(24 * win.s)
                                    radius: height / 2
                                    scale: prevWsMa.pressed ? 0.88 : (prevWsMa.containsMouse ? 1.10 : 1.0)
                                    color: prevWsMa.containsMouse ? sekaiTheme.accentMint : sekaiTheme.chipFill
                                    border.width: Math.max(1, Math.round(1.5 * win.s))
                                    border.color: sekaiTheme.colBorder

                                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "chevron_left"
                                        color: prevWsMa.containsMouse ? sekaiTheme.colBorder : "#ffffff"
                                        font.family: sekaiTheme.iconFont
                                        font.pixelSize: Math.round(14 * win.s)
                                    }

                                    MouseArea {
                                        id: prevWsMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: win.focusRelativeWorkspace(-1)
                                    }
                                }

                                WorkspaceCapsuleStrip {
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Rectangle {
                                    width: Math.round(24 * win.s)
                                    height: Math.round(24 * win.s)
                                    radius: height / 2
                                    scale: nextWsMa.pressed ? 0.88 : (nextWsMa.containsMouse ? 1.10 : 1.0)
                                    color: nextWsMa.containsMouse ? sekaiTheme.accentMint : sekaiTheme.chipFill
                                    border.width: Math.max(1, Math.round(1.5 * win.s))
                                    border.color: sekaiTheme.colBorder

                                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "chevron_right"
                                        color: nextWsMa.containsMouse ? sekaiTheme.colBorder : "#ffffff"
                                        font.family: sekaiTheme.iconFont
                                        font.pixelSize: Math.round(14 * win.s)
                                    }

                                    MouseArea {
                                        id: nextWsMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: win.focusRelativeWorkspace(1)
                                    }
                                }
                            }

                            Grid {
                                anchors.horizontalCenter: parent.horizontalCenter
                                columns: 4
                                rowSpacing: Math.round(6 * win.s * win.heightFactor)
                                columnSpacing: Math.round(6 * win.s * win.widthFactor)

                                Repeater {
                                    model: win.workspacesList
                                    delegate: Item {
                                        id: wsCardDel
                                        required property var modelData
                                        required property int index

                                        readonly property bool isAct: Boolean(wsCardDel.modelData.active)
                                        readonly property bool isOcc: Boolean(wsCardDel.modelData.occupied)
                                        readonly property color wsCol: sekaiTheme.capWsColors[wsCardDel.index % sekaiTheme.capWsColors.length]

                                        width: Math.round(58 * win.s * win.widthFactor)
                                        height: Math.round(36 * win.s * win.heightFactor)

                                        scale: wsCardMa.pressed ? 0.90 : (isAct ? 1.06 : (wsCardMa.containsMouse ? 1.04 : 1.0))
                                        rotation: isAct ? -2.5 : (wsCardMa.containsMouse ? 1.5 : 0.0)
                                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: win.bounceOvershoot } }
                                        Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: win.bounceOvershoot } }

                                        Rectangle {
                                            x: 0
                                            y: Math.round(3 * win.s)
                                            width: parent.width
                                            height: parent.height - Math.round(3 * win.s)
                                            radius: Math.round(9 * win.s)
                                            color: sekaiTheme.pLineShadow
                                        }

                                        Rectangle {
                                            width: parent.width
                                            height: parent.height - Math.round(3 * win.s)
                                            radius: Math.round(9 * win.s)
                                            color: wsCardDel.isAct
                                                ? wsCardDel.wsCol
                                                : (wsCardDel.isOcc ? sekaiTheme.chipFill : sekaiTheme.pSurfaceHover)
                                            border.width: Math.max(2, Math.round(2 * win.s))
                                            border.color: sekaiTheme.colBorder

                                            Behavior on color { ColorAnimation { duration: 160 } }

                                            Rectangle {
                                                visible: wsCardDel.isOcc
                                                anchors.top: parent.top
                                                anchors.right: parent.right
                                                anchors.margins: Math.round(4 * win.s)
                                                width: Math.round(5 * win.s)
                                                height: Math.round(5 * win.s)
                                                radius: width / 2
                                                color: wsCardDel.isAct ? sekaiTheme.colBorder : sekaiTheme.accentMint
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: String(wsCardDel.modelData.idx)
                                                color: wsCardDel.isAct
                                                    ? sekaiTheme.colBorder
                                                    : (wsCardDel.isOcc ? "#ffffff" : sekaiTheme.pInk)
                                                font.family: sekaiTheme.fontFamily
                                                font.pixelSize: Math.round(13 * win.s)
                                                font.weight: Font.ExtraBold
                                                font.styleName: sekaiTheme.fontStyleBold
                                            }
                                        }

                                        MouseArea {
                                            id: wsCardMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: win.focusWorkspace(wsCardDel.modelData.idx)
                                        }
                                    }
                                }
                            }
                        }

                        // ════════════════════════════════════════════════════════
                        // PAGE 3: SEKAI STICKER CLOCK & POMODORO TIMER
                        // ════════════════════════════════════════════════════════
                        Column {
                            id: pageClock
                            visible: win.currentPage === 3
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Math.round(6 * win.s * win.heightFactor)

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: Math.round(4 * win.s)

                                StickerDigit { value: win.hhStr.charAt(0); fillColor: sekaiTheme.accentMint; tilt: -5 }
                                StickerDigit { value: win.hhStr.charAt(1); fillColor: sekaiTheme.accentMint; tilt: -2 }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Math.round(6 * win.s)
                                    BeatDiamond { lit: win.ss % 2 === 0; litColor: sekaiTheme.accentMint; size: Math.round(9 * win.s) }
                                    BeatDiamond { lit: win.ss % 2 !== 0; litColor: sekaiTheme.accentCyan; size: Math.round(9 * win.s) }
                                }

                                StickerDigit { value: win.mmStr.charAt(0); fillColor: sekaiTheme.accentCyan; tilt: 2 }
                                StickerDigit { value: win.mmStr.charAt(1); fillColor: sekaiTheme.accentCyan; tilt: 5 }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.round(34 * win.s)
                                    height: Math.round(24 * win.s)
                                    radius: Math.round(8 * win.s)
                                    rotation: amPmMa.containsMouse ? -4 : 4
                                    scale: amPmMa.pressed ? 0.90 : (amPmMa.containsMouse ? 1.08 : 1.0)
                                    color: sekaiTheme.accentMint
                                    border.width: Math.max(2, Math.round(2 * win.s))
                                    border.color: sekaiTheme.colBorder

                                    Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
                                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

                                    Rectangle {
                                        z: -1
                                        x: Math.round(2 * win.s)
                                        y: Math.round(3 * win.s)
                                        width: parent.width
                                        height: parent.height
                                        radius: parent.radius
                                        color: sekaiTheme.pLineShadow
                                        opacity: 0.65
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: win.use24h ? "24H" : (win.pm ? "PM" : "AM")
                                        color: sekaiTheme.colBorder
                                        font.family: sekaiTheme.fontFamily
                                        font.pixelSize: Math.round(9.5 * win.s)
                                        font.weight: Font.ExtraBold
                                        font.styleName: sekaiTheme.fontStyleBold
                                    }

                                    MouseArea {
                                        id: amPmMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            win.use24h = !win.use24h
                                            win.requestSaveConfig()
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.round(256 * win.s * win.widthFactor)
                                height: Math.round(58 * win.s * win.heightFactor)
                                radius: Math.round(11 * win.s)
                                color: sekaiTheme.pSurfaceHover
                                border.width: Math.max(2, Math.round(2 * win.s))
                                border.color: sekaiTheme.colBorder

                                Column {
                                    anchors.centerIn: parent
                                    spacing: Math.round(5 * win.s)

                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: Math.round(8 * win.s)

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "timer"
                                            color: win.pomoRunning ? sekaiTheme.accentMint : sekaiTheme.pInk
                                            font.family: sekaiTheme.iconFont
                                            font.pixelSize: Math.round(15 * win.s)
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "POMODORO  " + win.pomoMinStr + ":" + win.pomoSecStr
                                            color: sekaiTheme.pInk
                                            font.family: sekaiTheme.fontFamily
                                            font.pixelSize: Math.round(11 * win.s)
                                            font.weight: Font.ExtraBold
                                            font.styleName: sekaiTheme.fontStyleBold
                                        }
                                    }

                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: Math.round(5 * win.s)

                                        Repeater {
                                            model: [
                                                { label: win.pomoRunning ? "PAUSE" : "START", act: "toggle" },
                                                { label: "25M", act: "25" },
                                                { label: "5M",  act: "5" },
                                                { label: "+1M", act: "plus" },
                                                { label: "RST", act: "reset" }
                                            ]
                                            delegate: Rectangle {
                                                id: pomoBtnDel
                                                required property var modelData
                                                width: Math.round(44 * win.s * win.widthFactor)
                                                height: Math.round(19 * win.s)
                                                radius: Math.round(6 * win.s)
                                                scale: pomoMa.pressed ? 0.90 : (pomoMa.containsMouse ? 1.07 : 1.0)
                                                color: pomoBtnDel.modelData.act === "toggle"
                                                    ? (win.pomoRunning ? sekaiTheme.warnFill : sekaiTheme.accentMint)
                                                    : sekaiTheme.chipFill
                                                border.width: 1
                                                border.color: sekaiTheme.colBorder

                                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: pomoBtnDel.modelData.label
                                                    color: pomoBtnDel.modelData.act === "toggle" ? sekaiTheme.colBorder : "#ffffff"
                                                    font.family: sekaiTheme.fontFamily
                                                    font.pixelSize: Math.round(8 * win.s)
                                                    font.weight: Font.ExtraBold
                                                    font.styleName: sekaiTheme.fontStyleBold
                                                }

                                                MouseArea {
                                                    id: pomoMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        const a = pomoBtnDel.modelData.act
                                                        if (a === "toggle") win.pomoRunning = !win.pomoRunning
                                                        else if (a === "25") win.setPomoPreset(25)
                                                        else if (a === "5") win.setPomoPreset(5)
                                                        else if (a === "plus") win.addPomoMinute()
                                                        else if (a === "reset") win.setPomoPreset(25)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ════════════════════════════════════════════════════════
                        // PAGE 4: STAGE STATS (CPU / RAM / GPU / TEMP MONITORING)
                        // ════════════════════════════════════════════════════════
                        Column {
                            id: pageStats
                            visible: win.currentPage === 4
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Math.round(6 * win.s * win.heightFactor)

                            StageStatBar { label: "CPU";  icon: "developer_board"; pct: win.cpuPct }
                            StageStatBar { label: "RAM";  icon: "memory";          pct: win.ramPct }
                            StageStatBar { label: "GPU";  icon: "videogame_asset"; pct: win.gpuPct }
                            StageStatBar {
                                label: "TEMP"
                                icon: "thermostat"
                                pct: win.tempC
                                valueText: win.tempC + "°C"
                                warn: win.tempC >= 78
                            }
                        }

                        // ════════════════════════════════════════════════════════
                        // PAGE 5: CLIPBOARD HISTORY & FILE DROP SHELF
                        // ════════════════════════════════════════════════════════
                        Column {
                            id: pageTray
                            visible: win.currentPage === 5
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Math.round(6 * win.s * win.heightFactor)

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.round(256 * win.s * win.widthFactor)
                                height: Math.round(64 * win.s * win.heightFactor)
                                radius: Math.round(10 * win.s)
                                color: globalDropArea.containsDrag
                                    ? Qt.rgba(sekaiTheme.accentMint.r, sekaiTheme.accentMint.g, sekaiTheme.accentMint.b, 0.28)
                                    : sekaiTheme.pSurfaceHover
                                border.width: Math.max(2, Math.round(2 * win.s))
                                border.color: globalDropArea.containsDrag ? sekaiTheme.accentMint : sekaiTheme.colBorder

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: Math.round(6 * win.s)
                                    spacing: Math.round(4 * win.s)

                                    Row {
                                        spacing: Math.round(4 * win.s)
                                        Text {
                                            text: "Drive_File_Move"
                                            color: sekaiTheme.pInk
                                            font.family: sekaiTheme.iconFont
                                            font.pixelSize: Math.round(12 * win.s)
                                        }
                                        Text {
                                            text: win.droppedShelfItems.length > 0
                                                ? "DROP SHELF (CLICK TO COPY PATH)"
                                                : "DRAG FILES OR TEXT HERE TO STASH"
                                            color: sekaiTheme.pInk
                                            font.family: sekaiTheme.fontFamily
                                            font.pixelSize: Math.round(8 * win.s)
                                            font.weight: Font.ExtraBold
                                            font.styleName: sekaiTheme.fontStyleBold
                                        }
                                    }

                                    Flow {
                                        width: parent.width
                                        spacing: Math.round(4 * win.s)

                                        Repeater {
                                            model: win.droppedShelfItems
                                            delegate: Rectangle {
                                                id: shelfDel
                                                required property string modelData
                                                width: Math.min(parent.width, shelfTxt.implicitWidth + Math.round(12 * win.s))
                                                height: Math.round(18 * win.s)
                                                radius: Math.round(5 * win.s)
                                                color: sekaiTheme.accentMint
                                                border.width: 1
                                                border.color: sekaiTheme.colBorder

                                                Text {
                                                    id: shelfTxt
                                                    anchors.centerIn: parent
                                                    text: shelfDel.modelData.split("/").pop() || shelfDel.modelData
                                                    color: sekaiTheme.colBorder
                                                    font.family: sekaiTheme.fontFamily
                                                    font.pixelSize: Math.round(8 * win.s)
                                                    font.weight: Font.ExtraBold
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: win.copyTextToClipboard(shelfDel.modelData)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Column {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: Math.round(4 * win.s)

                                Repeater {
                                    model: win.clipboardItems.slice(0, 3)
                                    delegate: Rectangle {
                                        id: clipDel
                                        required property string modelData
                                        width: Math.round(256 * win.s * win.widthFactor)
                                        height: Math.round(22 * win.s)
                                        radius: Math.round(7 * win.s)
                                        scale: clipMa.pressed ? 0.95 : (clipMa.containsMouse ? 1.03 : 1.0)
                                        color: clipMa.containsMouse ? sekaiTheme.accentCyan : sekaiTheme.chipFill
                                        border.width: 1
                                        border.color: sekaiTheme.colBorder

                                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
                                        Behavior on color { ColorAnimation { duration: 140 } }

                                        Row {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.margins: Math.round(8 * win.s)
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: Math.round(5 * win.s)

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "content_paste"
                                                color: clipMa.containsMouse ? sekaiTheme.colBorder : sekaiTheme.accentMint
                                                font.family: sekaiTheme.iconFont
                                                font.pixelSize: Math.round(11 * win.s)
                                            }
Text {
                                                width: parent.width - Math.round(20 * win.s)
                                                anchors.verticalCenter: parent.verticalCenter
                                                elide: Text.ElideRight
                                                text: clipDel.modelData
                                                color: clipMa.containsMouse ? sekaiTheme.colBorder : "#ffffff"
                                                font.family: sekaiTheme.fontFamily
                                                font.pixelSize: Math.round(8.5 * win.s)
                                                font.weight: Font.Bold
                                            }
                                        }

                                        MouseArea {
                                            id: clipMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: win.copyTextToClipboard(clipDel.modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ════════════════════════════════════════════════════════════
                // 13. INTEGRATED 3-TAB CUSTOMIZATION DRAWER (ELASTIC UNFOLD)
                // ════════════════════════════════════════════════════════════
                Column {
                    id: settingsDrawer
                    visible: win.settingsOpen
                    opacity: visible ? 1.0 : 0.0
                    scale: visible ? 1.0 : 0.88
                    transformOrigin: Item.Top
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Math.round(5 * win.s)

                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                    Behavior on scale {
                        NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: win.bounceOvershoot }
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.round(252 * win.s * win.widthFactor)
                        height: Math.max(1, Math.round(sekaiTheme.whiteLine * win.s))
                        radius: height / 2
                        color: sekaiTheme.pSurfaceDivider
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Math.round(5 * win.s)

                        Repeater {
                            model: [
                                { idx: 0, label: "GEOMETRY & LAYOUT" },
                                { idx: 1, label: "THEME & FX" },
                                { idx: 2, label: "ACTIONS POOL" }
                            ]
                            delegate: Rectangle {
                                id: sTabDel
                                required property var modelData
                                readonly property bool active: win.settingsTab === sTabDel.modelData.idx

                                width: Math.round(80 * win.s * win.widthFactor)
                                height: Math.round(18 * win.s)
                                radius: Math.round(6 * win.s)
                                scale: sTabMa.pressed ? 0.90 : (active ? 1.04 : (sTabMa.containsMouse ? 1.03 : 1.0))
                                color: active ? sekaiTheme.accentMint : sekaiTheme.chipFill
                                border.width: 1
                                border.color: sekaiTheme.colBorder

                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
                                Behavior on color { ColorAnimation { duration: 140 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: sTabDel.modelData.label
                                    color: sTabDel.active ? sekaiTheme.colBorder : "#ffffff"
                                    font.family: sekaiTheme.fontFamily
                                    font.pixelSize: Math.round(7 * win.s)
                                    font.weight: Font.ExtraBold
                                    font.styleName: sekaiTheme.fontStyleBold
                                }

                                MouseArea {
                                    id: sTabMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        win.settingsTab = sTabDel.modelData.idx
                                        win.triggerNotchJelly(0.45)
                                    }
                                }
                            }
                        }
                    }

                    // TAB 0: GEOMETRY, ISLAND MODE, MUSIC SHAPE TOGGLE & COLUMNS
                    Column {
                        visible: win.settingsTab === 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Math.round(4 * win.s)

                        SekaiSlider {
                            label: "SCALE"
                            icon: "zoom_out_map"
                            from: 0.70; to: 1.60; stepSize: 0.05
                            value: win.userScale
                            onMoved: v => { win.userScale = v; win.requestSaveConfig() }
                        }
                        SekaiSlider {
                            label: "LARGEUR"
                            icon: "swap_horiz"
                            from: 0.80; to: 1.55; stepSize: 0.05
                            value: win.widthFactor
                            onMoved: v => { win.widthFactor = v; win.requestSaveConfig() }
                        }
                        SekaiSlider {
                            label: "LONGUEUR"
                            icon: "swap_vert"
                            from: 0.85; to: 1.45; stepSize: 0.05
                            value: win.heightFactor
                            onMoved: v => { win.heightFactor = v; win.requestSaveConfig() }
                        }
                        SekaiSlider {
                            label: "POSITION X"
                            icon: "open_with"
                            from: -0.35; to: 0.35; stepSize: 0.05
                            value: win.horizOffset
                            onMoved: v => { win.horizOffset = v; win.requestSaveConfig() }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Math.round(4 * win.s)

                            Rectangle {
                                width: Math.round(52 * win.s)
                                height: Math.round(18 * win.s)
                                radius: Math.round(6 * win.s)
                                scale: islMa.pressed ? 0.90 : (islMa.containsMouse ? 1.06 : 1.0)
                                color: win.floatingMode ? sekaiTheme.accentMint : sekaiTheme.chipFill
                                border.width: 1; border.color: sekaiTheme.colBorder

                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: win.floatingMode ? "ISLAND" : "ATTACH"
                                    color: win.floatingMode ? sekaiTheme.colBorder : "#ffffff"
                                    font.family: sekaiTheme.fontFamily; font.pixelSize: Math.round(7 * win.s); font.weight: Font.ExtraBold
                                }
                                MouseArea {
                                    id: islMa
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        win.floatingMode = !win.floatingMode
                                        win.triggerNotchJelly(0.75)
                                        win.requestSaveConfig()
                                    }
                                }
                            }

                            Rectangle {
                                width: Math.round(86 * win.s)
                                height: Math.round(18 * win.s)
                                radius: Math.round(6 * win.s)
                                scale: mShapeMa.pressed ? 0.90 : (mShapeMa.containsMouse ? 1.06 : 1.0)
                                color: win.musicNotchEnabled ? sekaiTheme.cutePink : sekaiTheme.chipFill
                                border.width: 1; border.color: sekaiTheme.colBorder

                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: win.musicNotchEnabled ? "♪ SHAPE: ON" : "♪ SHAPE: OFF"
                                    color: win.musicNotchEnabled ? sekaiTheme.colBorder : "#ffffff"
                                    font.family: sekaiTheme.fontFamily; font.pixelSize: Math.round(7 * win.s); font.weight: Font.ExtraBold
                                }
                                MouseArea {
                                    id: mShapeMa
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        win.musicNotchEnabled = !win.musicNotchEnabled
                                        win.triggerNotchJelly(0.75)
                                        win.requestSaveConfig()
                                        leftDiamond.triggerBeat()
                                    }
                                }
                            }

                            Repeater {
                                model: [1, 2, 3, 4]
                                delegate: Rectangle {
                                    id: colBtnDel
                                    required property int modelData
                                    width: Math.round(24 * win.s)
                                    height: Math.round(18 * win.s)
                                    radius: Math.round(6 * win.s)
                                    scale: colMa.pressed ? 0.88 : (colMa.containsMouse ? 1.08 : 1.0)
                                    color: win.gridColumns === colBtnDel.modelData ? sekaiTheme.accentCyan : sekaiTheme.chipFill
                                    border.width: 1; border.color: sekaiTheme.colBorder

                                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: colBtnDel.modelData + "C"
                                        color: win.gridColumns === colBtnDel.modelData ? sekaiTheme.colBorder : "#ffffff"
                                        font.family: sekaiTheme.fontFamily; font.pixelSize: Math.round(7 * win.s); font.weight: Font.ExtraBold
                                    }
                                    MouseArea {
                                        id: colMa
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            win.gridColumns = colBtnDel.modelData
                                            win.triggerNotchJelly(0.65)
                                            win.requestSaveConfig()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // TAB 1: SURFACE MODES, RADII, BORDERS, BOUNCE OVERSHOOT & FX
                    Column {
                        visible: win.settingsTab === 1
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Math.round(4 * win.s)

                        SekaiSlider {
                            label: "COURBURE"
                            icon: "rounded_corner"
                            from: 4; to: 26; stepSize: 1
                            value: win.customBottomRadius
                            displayMultiplier: 1; suffix: "px"
                            onMoved: v => { win.customBottomRadius = Math.round(v); win.requestSaveConfig() }
                        }
                        SekaiSlider {
                            label: "REBOND"
                            icon: "animation"
                            from: 1.0; to: 2.6; stepSize: 0.1
                            value: win.bounceOvershoot
                            displayMultiplier: 100; suffix: "%"
                            onMoved: v => {
                                win.bounceOvershoot = v
                                win.triggerNotchJelly(0.6)
                                win.requestSaveConfig()
                            }
                        }
                        SekaiSlider {
                            label: "DELAI FERM"
                            icon: "timer"
                            from: 300; to: 2500; stepSize: 100
                            value: win.autoCloseDelay
                            displayMultiplier: 1; suffix: "ms"
                            onMoved: v => { win.autoCloseDelay = Math.round(v); win.requestSaveConfig() }
                        }
                        SekaiSlider {
                            label: "SUIVI NOTCH"
                            icon: "3d_rotation"
                            from: 0.0; to: 1.8; stepSize: 0.1
                            value: win.notchTrack25D
                            displayMultiplier: 100; suffix: "%"
                            onMoved: v => { win.notchTrack25D = v; win.requestSaveConfig() }
                        }
                        SekaiSlider {
                            label: "SUIVI CURSEUR"
                            icon: "3d_rotation"
                            from: 0.0; to: 1.8; stepSize: 0.1
                            value: win.cursorTrack25D
                            displayMultiplier: 100; suffix: "%"
                            onMoved: v => { win.cursorTrack25D = v; win.requestSaveConfig() }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Math.round(4 * win.s)

                            Repeater {
                                model: ["classic", "dark", "darker"]
                                delegate: Rectangle {
                                    id: surfDel
                                    required property string modelData
                                    width: Math.round(46 * win.s)
                                    height: Math.round(18 * win.s)
                                    radius: Math.round(6 * win.s)
                                    scale: surfMa.pressed ? 0.90 : (surfMa.containsMouse ? 1.06 : 1.0)
                                    color: win.surfaceMode === surfDel.modelData ? sekaiTheme.accentMint : sekaiTheme.chipFill
                                    border.width: 1; border.color: sekaiTheme.colBorder

                                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: surfDel.modelData.toUpperCase()
                                        color: win.surfaceMode === surfDel.modelData ? sekaiTheme.colBorder : "#ffffff"
                                        font.family: sekaiTheme.fontFamily; font.pixelSize: Math.round(6.8 * win.s); font.weight: Font.ExtraBold
                                    }
                                    MouseArea {
                                        id: surfMa
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { win.surfaceMode = surfDel.modelData; win.requestSaveConfig() }
                                    }
                                }
                            }

                            Rectangle {
                                width: Math.round(40 * win.s); height: Math.round(18 * win.s); radius: Math.round(6 * win.s)
                                color: win.showHalftone ? sekaiTheme.accentCyan : sekaiTheme.chipFill
                                border.width: 1; border.color: sekaiTheme.colBorder
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text {
                                    anchors.centerIn: parent; text: "DOTS"
                                    color: win.showHalftone ? sekaiTheme.colBorder : "#ffffff"
                                    font.family: sekaiTheme.fontFamily; font.pixelSize: Math.round(6.8 * win.s); font.weight: Font.ExtraBold
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: { win.showHalftone = !win.showHalftone; win.requestSaveConfig() }
                                }
                            }

                            Rectangle {
                                width: Math.round(64 * win.s); height: Math.round(18 * win.s); radius: Math.round(6 * win.s)
                                color: win.musicNotchEnabled ? sekaiTheme.cutePink : sekaiTheme.chipFill
                                border.width: 1; border.color: sekaiTheme.colBorder
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text {
                                    anchors.centerIn: parent; text: win.musicNotchEnabled ? "♪ MORPH ON" : "♪ MORPH OFF"
                                    color: win.musicNotchEnabled ? sekaiTheme.colBorder : "#ffffff"
                                    font.family: sekaiTheme.fontFamily; font.pixelSize: Math.round(6.8 * win.s); font.weight: Font.ExtraBold
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: { win.musicNotchEnabled = !win.musicNotchEnabled; win.requestSaveConfig() }
                                }
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Math.round(3 * win.s)

                            Repeater {
                                model: ["vs", "nightcord", "vbs", "wxs", "mmj", "leoneed", "mono", "matugen"]
                                delegate: Rectangle {
                                    id: palDel
                                    required property string modelData
                                    readonly property var p: sekaiTheme.palettes[palDel.modelData]
                                    readonly property bool active: win.selectedUnitTheme === palDel.modelData

                                    width: Math.round(24 * win.s)
                                    height: Math.round(18 * win.s)
                                    radius: Math.round(5 * win.s)
                                    scale: palMa.pressed ? 0.88 : (active ? 1.08 : (palMa.containsMouse ? 1.05 : 1.0))
                                    color: active ? p.B : p.border
                                    border.width: 1; border.color: sekaiTheme.colBorder

                                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: palDel.p.label
                                        color: palDel.active ? palDel.p.border : "#ffffff"
                                        font.family: sekaiTheme.fontFamily
                                        font.pixelSize: Math.round(7 * win.s)
                                        font.weight: Font.ExtraBold
                                    }

                                    MouseArea {
                                        id: palMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            win.selectedUnitTheme = palDel.modelData
                                            win.requestSaveConfig()
                                            win.triggerNotchJelly(0.55)
                                            leftDiamond.triggerBeat()
                                            rightDiamond.triggerBeat()
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: Math.round(36 * win.s); height: Math.round(18 * win.s); radius: Math.round(5 * win.s)
                                scale: rstMa.pressed ? 0.88 : (rstMa.containsMouse ? 1.08 : 1.0)
                                color: sekaiTheme.warnFill; border.width: 1; border.color: sekaiTheme.colBorder
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
                                Text {
                                    anchors.centerIn: parent; text: "RST"; color: sekaiTheme.colBorder
                                    font.family: sekaiTheme.fontFamily; font.pixelSize: Math.round(7 * win.s); font.weight: Font.ExtraBold
                                }
                                MouseArea {
                                    id: rstMa
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: win.resetCustomization()
                                }
                            }
                        }
                    }

                    // TAB 2: ADDITIVE ACTION POOL & CUSTOM COMMAND CREATOR
                    Column {
                        visible: win.settingsTab === 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Math.round(5 * win.s)

                        Rectangle {
                            id: poolSection
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.round(256 * win.s * win.widthFactor)
                            height: Math.round(88 * win.s)
                            radius: Math.round(10 * win.s)
                            color: (win.dragActive && win.dragSourceType === "active" && win.hoveredPoolDrop)
                                ? Qt.rgba(sekaiTheme.warnFill.r, sekaiTheme.warnFill.g, sekaiTheme.warnFill.b, 0.25)
                                : sekaiTheme.pSurfaceHover
                            border.width: Math.max(1, Math.round(2 * win.s))
                            border.color: (win.dragActive && win.dragSourceType === "active" && win.hoveredPoolDrop)
                                ? sekaiTheme.warnFill
                                : sekaiTheme.pSurfaceDivider

                            Behavior on color { ColorAnimation { duration: 150 } }

                            Column {
                                anchors.fill: parent
                                anchors.margins: Math.round(6 * win.s)
                                spacing: Math.round(4 * win.s)

                                Row {
                                    width: parent.width
                                    spacing: Math.round(4 * win.s)

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "add_box"
                                        color: sekaiTheme.pInk
                                        font.family: sekaiTheme.iconFont
                                        font.pixelSize: Math.round(11 * win.s)
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: (win.dragActive && win.dragSourceType === "active")
                                            ? "DROP HERE TO REMOVE ACTION"
                                            : "CLICK OR DRAG TO ADD (NO REPLACE)"
                                        color: sekaiTheme.pInk
                                        font.family: sekaiTheme.fontFamily
                                        font.pixelSize: Math.round(7.5 * win.s)
                                        font.weight: Font.ExtraBold
                                    }

                                    Rectangle {
                                        visible: win.poolActionsModel.length > 0 && !win.dragActive
                                        width: Math.round(42 * win.s)
                                        height: Math.round(14 * win.s)
                                        radius: Math.round(4 * win.s)
                                        color: sekaiTheme.accentMint
                                        border.width: 1; border.color: sekaiTheme.colBorder

                                        Text {
                                            anchors.centerIn: parent
                                            text: "+ ALL"
                                            color: sekaiTheme.colBorder
                                            font.family: sekaiTheme.fontFamily
                                            font.pixelSize: Math.round(7 * win.s)
                                            font.weight: Font.ExtraBold
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: win.addAllPoolActions()
                                        }
                                    }
                                }

                                Flow {
                                    width: parent.width
                                    spacing: Math.round(4 * win.s)

                                    Repeater {
                                        model: win.poolActionsModel
                                        delegate: PoolActionChip {
                                            id: poolChipDel
                                            required property var modelData
                                            required property int index
                                            actionData: poolChipDel.modelData
                                            poolIndex: poolChipDel.index
                                        }
                                    }
                                }
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Math.round(4 * win.s)

                            Rectangle {
                                width: Math.round(68 * win.s * win.widthFactor)
                                height: Math.round(20 * win.s)
                                radius: Math.round(6 * win.s)
                                color: sekaiTheme.pSurfaceHover
                                border.width: 1; border.color: sekaiTheme.colBorder

                                TextInput {
                                    id: customLabelInput
                                    anchors.fill: parent
                                    anchors.margins: Math.round(4 * win.s)
                                    verticalAlignment: TextInput.AlignVCenter
                                    clip: true
                                    text: "Btop"
                                    color: sekaiTheme.pInk
                                    font.family: sekaiTheme.fontFamily
                                    font.pixelSize: Math.round(8 * win.s)
                                    font.weight: Font.Bold
                                }
                            }

                            Rectangle {
                                width: Math.round(124 * win.s * win.widthFactor)
                                height: Math.round(20 * win.s)
                                radius: Math.round(6 * win.s)
                                color: sekaiTheme.pSurfaceHover
                                border.width: 1; border.color: sekaiTheme.colBorder

                                TextInput {
                                    id: customCmdInput
                                    anchors.fill: parent
                                    anchors.margins: Math.round(4 * win.s)
                                    verticalAlignment: TextInput.AlignVCenter
                                    clip: true
                                    text: "kitty -e btop"
                                    color: sekaiTheme.pInk
                                    font.family: sekaiTheme.fontFamily
                                    font.pixelSize: Math.round(8 * win.s)
                                }
                            }

                            Rectangle {
                                width: Math.round(52 * win.s)
                                height: Math.round(20 * win.s)
                                radius: Math.round(6 * win.s)
                                scale: addCmdMa.pressed ? 0.90 : (addCmdMa.containsMouse ? 1.06 : 1.0)
                                color: sekaiTheme.accentMint
                                border.width: 1; border.color: sekaiTheme.colBorder

                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "+ CMD"
                                    color: sekaiTheme.colBorder
                                    font.family: sekaiTheme.fontFamily
                                    font.pixelSize: Math.round(8 * win.s)
                                    font.weight: Font.ExtraBold
                                }

                                MouseArea {
                                    id: addCmdMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.createCustomAction(customLabelInput.text, "bolt", customCmdInput.text)
                                }
                            }
                        }
                    }
                }

                // ── SekaiPop Footer Badge (Bouncy Tilt & Scale) ──
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Math.round(8 * win.s)

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(48 * win.s * win.widthFactor)
                        height: Math.max(1, Math.round(sekaiTheme.whiteLine * win.s))
                        radius: height / 2
                        color: sekaiTheme.pSurfaceDivider
                    }

                    Rectangle {
                        id: footerChip
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(88 * win.s)
                        height: Math.round(16 * win.s)
                        radius: Math.round(5 * win.s)
                        rotation: win.settingsOpen ? -2.5 : (footerMa.containsMouse ? -1.5 : 2.0)
                        scale: footerMa.pressed ? 0.90 : (footerMa.containsMouse ? 1.08 : 1.0)
                        color: win.settingsOpen ? sekaiTheme.accentCyan : sekaiTheme.accentMint
                        border.width: Math.max(1, Math.round(1.5 * win.s))
                        border.color: sekaiTheme.colBorder

                        Behavior on rotation { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
                        Behavior on color { ColorAnimation { duration: 160 } }

                        Rectangle {
                            z: -1
                            x: Math.round(1.5 * win.s)
                            y: Math.round(2 * win.s)
                            width: parent.width
                            height: parent.height
                            radius: parent.radius
                            color: sekaiTheme.pLineShadow
                            opacity: 0.65
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: Math.round(3 * win.s)

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: win.settingsOpen ? "done_all" : "tune"
                                color: sekaiTheme.colBorder
                                font.family: sekaiTheme.iconFont
                                font.pixelSize: Math.round(9 * win.s)
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: win.settingsOpen ? "DONE EDIT" : "CUSTOMIZE"
                                color: sekaiTheme.colBorder
                                font.family: sekaiTheme.fontFamily
                                font.pixelSize: Math.round(7.5 * win.s)
                                font.weight: Font.ExtraBold
                                font.styleName: sekaiTheme.fontStyleBold
                            }
                        }

                        MouseArea {
                            id: footerMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.settingsOpen = !win.settingsOpen
                        }
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(48 * win.s * win.widthFactor)
                        height: Math.max(1, Math.round(sekaiTheme.whiteLine * win.s))
                        radius: height / 2
                        color: sekaiTheme.pSurfaceDivider
                    }
                }
            }
        }

        // ── Floating Sticker Drag Ghost (Smooth Elastic Follow) ──
        Rectangle {
            id: dragGhost
            visible: win.dragActive && win.draggedActionObj !== null
            x: win.dragX - width / 2
            y: win.dragY - height / 2
            width: Math.round(98 * win.s)
            height: Math.round(28 * win.s)
            radius: Math.round(9 * win.s)
            rotation: -5
            scale: win.dragActive ? 1.12 : 0.8
            z: 99
            color: sekaiTheme.accentMint
            border.width: Math.max(2, Math.round(2 * win.s))
            border.color: sekaiTheme.colBorder

            Behavior on x { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
            Behavior on y { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

            Rectangle {
                z: -1
                x: Math.round(3 * win.s)
                y: Math.round(4 * win.s)
                width: parent.width
                height: parent.height
                radius: parent.radius
                color: sekaiTheme.pLineShadow
                opacity: 0.75
            }

            Row {
                anchors.centerIn: parent
                spacing: Math.round(4 * win.s)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.draggedActionObj ? win.draggedActionObj.icon : ""
                    color: sekaiTheme.colBorder
                    font.family: sekaiTheme.iconFont
                    font.pixelSize: Math.round(13 * win.s)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.draggedActionObj ? win.draggedActionObj.label : ""
                    color: sekaiTheme.colBorder
                    font.family: sekaiTheme.fontFamily
                    font.pixelSize: Math.round(9.5 * win.s)
                    font.weight: Font.ExtraBold
                    font.styleName: sekaiTheme.fontStyleBold
                }
            }
        }
    }

    HoverHandler { id: activationHover; target: activationZone }

    mask: Region {
        Region { item: activationZone }
        Region { item: notchContainer }
    }
}