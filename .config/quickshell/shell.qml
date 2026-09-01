pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import "modules/bar"
import "modules/launcher"
import "modules/powermenu"
import "modules/wallpaper"
import "modules/appkiller"

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

  // ── Wallpaper (native awww replacement, mirrored) ────────────────
  WallpaperBackground {
    id: wallpaperBg
  }
  WallpaperChooser {
    id: wallpaper
  }

  // ── App Killer (theme, replaces ~/Scripts/app_kill.sh) ───────────
  AppKiller {
    id: appkiller
  }
}
