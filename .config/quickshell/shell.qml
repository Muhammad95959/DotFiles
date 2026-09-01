pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import "modules/bar"
import "modules/launcher"
import "modules/powermenu"

ShellRoot {
  id: root

  // ── Bar ────────────────────────────────────────────────────────────
  Bar {
    id: bar
    onLauncherRequested: launcher.toggle()
    onPowermenuRequested: powermenu.toggle()
  }

  // ── Launcher ───────────────────────────────────────────────────────
  AppLauncher {
    id: launcher
  }

  // ── Power Menu ─────────────────────────────────────────────────────
  PowerMenu {
    id: powermenu
  }
}
