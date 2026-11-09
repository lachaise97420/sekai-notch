pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    id: app

    Component.onCompleted: Quickshell.watchFiles = !Quickshell.shellDir.startsWith(
        (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/quickshell/")

    property var portraitScreens: {
        var candidates = [];
        for (var i = 0; i < Quickshell.screens.length; i++) {
            var s = Quickshell.screens[i];
            if (s && s.width > 0 && s.height > s.width)
                candidates.push(s);
        }
        if (candidates.length === 0) return [];
        // pick the leftmost portrait monitor
        var leftmost = candidates[0];
        for (var j = 1; j < candidates.length; j++) {
            if (candidates[j].x < leftmost.x) leftmost = candidates[j];
        }
        return [leftmost];
    }

    Variants {
        model: app.portraitScreens
        Notch {
            required property var modelData
            targetScreen: modelData
        }
    }
}