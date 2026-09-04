pragma ComponentBehavior: Bound
import QtQuick

import Quickshell

import "modules/appkiller"
import "modules/bar"
import "modules/braveHistory"
import "modules/clipboard"
import "modules/corners"
import "modules/launcher"
import "modules/liveWall"
import "modules/mpvHistory"
import "modules/notifications"
import "modules/osd"
import "modules/powermenu"
import "modules/glyphPicker"
import "modules/pass"
import "modules/qmenu"
import "modules/systemd"
import "modules/reload"
import "modules/resize"
import "modules/translate"
import "modules/urlMpv"
import "modules/virtManager"
import "modules/wallpaper"
import "modules/zathuraHistory"
import "modules/zathuraRecolor"

ShellRoot {
  // ── Bar ────────────────────────────────────────────────────────────
  Bar {
    onLauncherRequested: launcher.toggle()
    onPowermenuRequested: powermenu.toggle()
  }

  // ── Launcher ───────────────────────────────────────────────────────
  AppLauncher { id: launcher }

  // ── Power Menu ─────────────────────────────────────────────────────
  PowerMenu { id: powermenu }

  // ── Reload Popup ───────────────────────────────────────────────────
  ReloadPopup {}

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
  BraveHistory {}

  // ── Theming ────────────────────────────────────────────────────────
  ZathuraRecolor {}

  // ── VirtManager ────────────────────────────────────────────────────
  VirtManager {}

  // ── Live Wallpapers ────────────────────────────────────────────────
  LiveWallpaperBackground {}
  LiveWall {}

  // ── Generic Qmenu  ─────────────────────────────────────────────────
  Qmenu {}

  // ── Glyph Picker (emoji + nerd + unicode) ──────────────────────────
  GlyphPicker {}

  // ── Systemd  ───────────────────────────────────────────────────────
  Systemd {}

  // ── Pass  ──────────────────────────────────────────────────────────
  Pass {}

}
