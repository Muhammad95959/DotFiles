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
import "modules/notifications"
import "modules/reload"
import "modules/mpvHistory"
import "modules/zathuraHistory"
import "modules/urlMpv"
import "modules/translate"
import "modules/resize"
import "modules/corners"
import "modules/bookmarks"

ShellRoot {
  id: root

  // ── Bar ────────────────────────────────────────────────────────────
  Bar {
    id: bar
    onLauncherRequested: launcher.toggle()
    onPowermenuRequested: powermenu.toggle()
  }

  // ── Reload Popup ───────────────────────────────────────────────────
  ReloadPopup {
    id: reloadPopup
  }

  // ── Launcher ───────────────────────────────────────────────────────
  AppLauncher { id: launcher }

  // ── Power Menu ─────────────────────────────────────────────────────
  PowerMenu { id: powermenu }

  // ── Wallpaper ──────────────────────────────────────────────────────
  WallpaperBackground { id: wallpaperBg }
  WallpaperChooser { id: wallpaper }

  // ── App Killer ─────────────────────────────────────────────────────
  AppKiller { id: appkiller }

  // ── OSD ────────────────────────────────────────────────────────────
  Osd { id: osd }

  // ── Clipboard ──────────────────────────────────────────────────────
  Clipboard { id: clipboard }

  // ── Notifications  ─────────────────────────────────────────────────
  Notifications { id: notifications }

  // ── Media History ──────────────────────────────────────────────────
  MpvHistory { id: mpvHistory }
  ZathuraHistory { id: zathuraHistory }

  // ── URL → MPV ──────────────────────────────────────────────────────
  UrlMpv { id: urlMpv }

  // ── Translate ──────────────────────────────────────────────────────
  Translate { id: translate }

  // ── Window Ops ─────────────────────────────────────────────────────
  Resize { id: winResize }
  Corners { id: winCorners }

  // ── Brave ──────────────────────────────────────────────────────────
  Bookmarks { id: bookmarks }

}
