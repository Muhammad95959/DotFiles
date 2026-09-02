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
import "modules/braveHistory"
import "modules/zathuraRecolor"
import "modules/virtManager"
import "modules/liveWall"
import "modules/qmenu"

ShellRoot {
  // ── Bar ────────────────────────────────────────────────────────────
  Bar {
    onLauncherRequested: launcher.toggle()
    onPowermenuRequested: powermenu.toggle()
  }

  // ── Reload Popup ───────────────────────────────────────────────────
  ReloadPopup {}

  // ── Launcher ───────────────────────────────────────────────────────
  AppLauncher { id: launcher }

  // ── Power Menu ─────────────────────────────────────────────────────
  PowerMenu { id: powermenu }

  // ── Wallpaper ──────────────────────────────────────────────────────
  WallpaperBackground {}
  WallpaperChooser {}

  // ── App Killer ─────────────────────────────────────────────────────
  AppKiller {}

  // ── OSD ────────────────────────────────────────────────────────────
  Osd {}

  // ── Clipboard ──────────────────────────────────────────────────────
  Clipboard {}

  // ── Notifications  ─────────────────────────────────────────────────
  Notifications {}

  // ── Media History ──────────────────────────────────────────────────
  MpvHistory {}
  ZathuraHistory {}

  // ── URL → MPV ──────────────────────────────────────────────────────
  UrlMpv {}

  // ── Translate ──────────────────────────────────────────────────────
  Translate {}

  // ── Window Ops ─────────────────────────────────────────────────────
  Resize {}
  Corners {}

  // ── Brave ──────────────────────────────────────────────────────────
  Bookmarks {}
  BraveHistory {}

  // ── Theming ────────────────────────────────────────────────────────
  ZathuraRecolor {}

  // ── VirtManager ────────────────────────────────────────────────────
  VirtManager {}

  // ── Live Wallpapers ────────────────────────────────────────────────
  LiveWall {}

  // ── Generic Qmenu (rofi replacement) ─────────────────────────────────
  Qmenu {}
}
