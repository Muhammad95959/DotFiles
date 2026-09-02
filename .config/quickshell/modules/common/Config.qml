pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick

QtObject {
  // ── Shared (used outside bar) ──────────────────────────────────────
  // barHeight is used by Bar, AppLauncher and PowerMenu for exclusion
  readonly property int barHeight: 24
}
