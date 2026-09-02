pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import "modules/bar"
import "modules/launcher"
import "modules/powermenu"
import "modules/wallpaper"
import "modules/appkiller"
import "modules/osd"
import "modules/clipboard"

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

  // ── Wallpaper ──────────────────────────────────────────────────────
  WallpaperBackground {
    id: wallpaperBg
  }
  WallpaperChooser {
    id: wallpaper
  }

  // ── App Killer ─────────────────────────────────────────────────────
  AppKiller {
    id: appkiller
  }

  // ── OSD ────────────────────────────────────────────────────────────
  Osd {
    id: osd
  }

  // ── Clipboard ──────────────────────────────────────────────────────
  Clipboard {
    id: clipboard
  }

}
