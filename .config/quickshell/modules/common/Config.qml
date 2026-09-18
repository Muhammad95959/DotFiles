pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick

QtObject {
  // ── Shared (used outside bar) ──────────────────────────────────────
  // barHeight is used by Bar, Launcher and PowerMenu for exclusion
  readonly property int barHeight: 24
}
