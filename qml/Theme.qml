pragma Singleton
import QtQuick

// Design tokens. All text/background pairs meet WCAG AA (>= 4.5:1).
QtObject {
    readonly property color bg: "#0B0F1A"
    readonly property color surface: "#141A2C"
    readonly property color field: "#1D2644"
    readonly property color surfaceHi: "#232D52"
    readonly property color border: "#34416B"

    readonly property color text: "#FFFFFF"
    readonly property color textSecondary: "#C9D1EE"   // labels, meta
    readonly property color textMuted: "#9CA7D0"        // hints, done items
    readonly property color placeholder: "#9AA5CF"

    readonly property color accent: "#6C4BFF"
    readonly property color accentHi: "#9B86FF"
    readonly property color accentDark: "#5636E6"
    readonly property color success: "#34D399"
    readonly property color warning: "#FBBF24"
    readonly property color danger: "#FF7A8C"
    readonly property color onBright: "#0B0F1A"          // text on success/warning/danger fills

    readonly property int radius: 18

    function priorityColor(p) { return p === 3 ? danger : (p === 2 ? warning : success) }
    function priorityName(p) { return p === 3 ? "High" : (p === 2 ? "Normal" : "Low") }
}
