pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick

QtObject {
  // ── Colors (from bar) ────────────────────────────────────────────
  readonly property color bg: "#1a1b26"
  readonly property color bgAlt: "#1e1e2e"
  readonly property color fg: "#e1e2e7"
  readonly property color accent: "#7aa2f7"
  readonly property color urgent: "#ff757f"
  readonly property color surface: "#24283b"
  readonly property color surfaceHover: "#2a2e44"
  readonly property color border: "#3b4261"
  readonly property color dim: "#55000000"

  // ── Fonts ──────────────────────────────────────────────────────────
  readonly property string nerdFont: "Symbols Nerd Font"
  readonly property string monoFont: "RobotoMono Nerd Font"

  // ── Radius ─────────────────────────────────────────────────────────
  readonly property int radiusSm: 6
  readonly property int radiusMd: 10
  readonly property int radiusLg: 14
  readonly property int radiusXl: 20
}
