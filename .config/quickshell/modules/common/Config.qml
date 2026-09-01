pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

QtObject {
  // ── Shared (used outside bar) ──────────────────────────────────────
  // barHeight is used by Bar, AppLauncher and PowerMenu for exclusion
  readonly property int barHeight: 24
}
