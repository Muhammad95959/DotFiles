#!/usr/bin/env bash
# Redroid control helper for the QuickShell module.
set -u

export PATH="$HOME/.android/Sdk/cmdline-tools/latest/bin:$HOME/.android/bin:$HOME/.local/bin:$HOME/.android/Sdk/platform-tools:$HOME/Android/Sdk/platform-tools:/usr/local/bin:/usr/bin:/bin:$PATH"

VERSIONS=(15 14 13 12 10 9 8)
NAME_PREFIX="redroid"
BASE_PORT=5500
STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/quickshell/redroid"
LOG_FILE="$STATE_DIR/redroid.log"
WAYDROID_NET_SCRIPT="/usr/lib/waydroid/data/scripts/waydroid-net.sh"
WAYDROID_LOG="/var/lib/waydroid/waydroid.log"
AVD_HOME="${ANDROID_AVD_HOME:-$HOME/.android/avd}"

mkdir -p "$STATE_DIR"

log() {
  printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$LOG_FILE" 2>/dev/null || true
}

notify() {
  if [ -n "${APP_NAME:-}" ]; then
    qs ipc call notifications dismissApp "$APP_NAME" >/dev/null 2>&1 || true
    sleep 0.1
  fi
  if [ -n "${APP_NAME:-}" ]; then
    notify-send -a "$APP_NAME" "$@" >/dev/null 2>&1 || true
  else
    notify-send "$@" >/dev/null 2>&1 || true
  fi
}

name_for() { printf '%s%s' "$NAME_PREFIX" "$1"; }
port_for() { printf '%s' "$((BASE_PORT + $1))"; }

docker_cmd() {
  if docker "$@" >/dev/null 2>&1; then
    return 0
  fi
  sudo docker "$@"
}

is_running() {
  local name="$1"
  docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$name" && return 0
  sudo docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$name" && return 0
  return 1
}

ensure_docker() {
  if systemctl is-active --quiet docker 2>/dev/null; then
    return 0
  fi
  notify -t 300000 "$APP_NAME" "Starting Docker service…"
  sudo systemctl start docker >/dev/null 2>&1 || return 1
  return 0
}

save_size() {
  local v="$1" w="$2" h="$3" d="$4"
  printf '%sx%s@%s\n' "$w" "$h" "$d" >"$STATE_DIR/last-size-$v"
}

# Returns the remembered size as WxH@DPI (older files used "WxH DPI").
load_size() {
  local s
  s="$(cat "$STATE_DIR/last-size-$1" 2>/dev/null)" || return 0
  [ -n "$s" ] || return 0
  printf '%s' "${s// /@}"
}

wait_boot() {
  local v="$1" port="$2" name="$3" tries=0
  until timeout 5 adb connect "localhost:$port" >/dev/null 2>&1 &&
    [ "$(timeout 5 adb -s "localhost:$port" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do
    if ! is_running "$name"; then
      return 1
    fi
    tries=$((tries + 1))
    if [ "$tries" -gt 60 ]; then
      return 1
    fi
    sleep 2
    if ! is_running "$name"; then
      return 1
    fi
  done
  return 0
}

apply_size() {
  local port="$1" w="$2" h="$3" d="$4"
  adb connect "localhost:$port" >/dev/null 2>&1 || true
  adb -s "localhost:$port" shell wm size "${w}x${h}" >/dev/null 2>&1 || true
  adb -s "localhost:$port" shell wm density "$d" >/dev/null 2>&1 || true
}

open_scrcpy() {
  local v="$1" port="$2"
  if pgrep -f "scrcpy.*localhost:$port" >/dev/null 2>&1; then
    notify -t 300000 "Redroid $v" "Already open on localhost:$port"
    return 0
  fi
  setsid scrcpy -s "localhost:$port" \
    --no-audio --hwdec=disabled --max-fps=60 -b 16M >/dev/null 2>&1 &
  return 0
}

# ── Waydroid ─────────────────────────────────────────────────────────
# Waydroid's session start can die while building its nftables ruleset
# (`waydroid-net.sh start` → "Could not process rule: No such file or
# directory"), which is what happens right after Docker — started for Redroid —
# rewrites the host nftables state. These helpers reset that state, make sure
# binderfs is back, and retry, so Waydroid works again after Redroid was used.

have_waydroid() { command -v waydroid >/dev/null 2>&1; }

waydroid_session_running() {
  have_waydroid || return 1
  waydroid status 2>/dev/null | grep -q 'Session:.*RUNNING'
}

waydroid_container_active() {
  systemctl is-active --quiet waydroid-container 2>/dev/null
}

ensure_binderfs() {
  mountpoint -q /dev/binderfs 2>/dev/null && return 0
  sudo mkdir -p /dev/binderfs >/dev/null 2>&1 || true
  sudo mount -t binder binder /dev/binderfs >/dev/null 2>&1 || true
}

# The container service only creates the anbox-* binder nodes when a session
# starts (prepare_drivers_once), so wait for the service itself, never for the
# nodes — waiting on them deadlocks a fresh binderfs.
ensure_waydroid_container() {
  waydroid_container_active && return 0
  sudo systemctl start waydroid-container >/dev/null 2>&1 || true
  local i
  for i in $(seq 1 20); do
    waydroid_container_active && return 0
    sleep 0.25
  done
  return 1
}

reset_waydroid_net() {
  if [ -x "$WAYDROID_NET_SCRIPT" ]; then
    sudo "$WAYDROID_NET_SCRIPT" stop force >/dev/null 2>&1 || true
  fi
  # waydroid-net.sh only drops its nftables tables while waydroid0 still exists.
  # Only purge tables that actually belong to Waydroid — real LXC uses the same
  # table names and must not be touched.
  local family
  for family in inet ip; do
    if sudo nft list table "$family" lxc 2>/dev/null | grep -q waydroid0; then
      sudo nft delete table "$family" lxc >/dev/null 2>&1 || true
    fi
  done
}

open_waydroid_ui() {
  setsid waydroid show-full-ui >/dev/null 2>&1 &
}

# Called after a container goes away: drop Waydroid's stale net state only when
# no Waydroid session owns it.
release_waydroid() {
  have_waydroid || return 0
  waydroid_session_running && return 0
  pgrep -f 'lxc-start -P /var/lib/waydroid' >/dev/null 2>&1 && return 0
  reset_waydroid_net
}

cmd_waydroid() {
  case "${1:-start}" in
    start)      waydroid_start ;;
    open)       waydroid_open ;;
    stop)       waydroid_stop ;;
    restart)    waydroid_stop quiet; sleep 1; waydroid_start ;;
    logs)       waydroid_logs ;;
    shell)      waydroid_shell ;;
    copy)       waydroid_copy ;;
    screenshot) waydroid_screenshot ;;
    doctor)     cmd_doctor ;;
    *)
      echo "usage: redroid.sh waydroid [start|open|stop|restart|logs|shell|copy|screenshot|doctor]" >&2
      return 1
      ;;
  esac
}

waydroid_start() {
  APP_NAME="Waydroid"
  if ! have_waydroid; then
    notify -u critical "Waydroid" "Waydroid is not installed"
    return 1
  fi

  ensure_binderfs
  if ! ensure_waydroid_container; then
    notify -u critical "Waydroid" "Binder container unavailable (run: redroid.sh doctor)"
    log "waydroid: container service failed"
    return 1
  fi

  if waydroid_session_running; then
    open_waydroid_ui
    notify -t 2000 "Waydroid" "Session already running"
    return 0
  fi

  notify -t 300000 "Waydroid" "Starting session…"
  local attempt i
  for attempt in 1 2 3; do
    reset_waydroid_net
    setsid waydroid session start >/dev/null 2>&1 &
    for i in $(seq 1 15); do
      sleep 1
      waydroid_session_running && break
    done
    if waydroid_session_running; then
      log "waydroid: session running (attempt $attempt)"
      open_waydroid_ui
      notify -t 3000 "Waydroid" "Session ready"
      return 0
    fi
    log "waydroid: attempt $attempt failed"
    waydroid session stop >/dev/null 2>&1 || true
  done

  notify -u critical "Waydroid" "Session failed to start (run: redroid.sh doctor)"
  log "waydroid: session failed after $attempt attempts"
  return 1
}

waydroid_open() {
  APP_NAME="Waydroid"
  if waydroid_session_running; then
    open_waydroid_ui
    notify -t 2000 "Waydroid" "Opening"
  else
    waydroid_start
  fi
}

waydroid_stop() {
  local quiet="${1:-}"
  APP_NAME="Waydroid"
  qs ipc call notifications dismissApp "$APP_NAME" >/dev/null 2>&1 || true
  have_waydroid || return 0
  [ "$quiet" = "quiet" ] || notify -t 300000 "Waydroid" "Stopping…"
  waydroid session stop >/dev/null 2>&1 || true
  reset_waydroid_net
  [ "$quiet" = "quiet" ] || notify -t 2000 "Waydroid" "Session stopped"
}

waydroid_copy() {
  APP_NAME="Waydroid"
  local ip
  ip="$(waydroid status 2>/dev/null | awk -F'\t' '/IP address/ {print $2}')"
  if [ -z "$ip" ]; then
    notify -t 3000 "Waydroid" "Session not running"
    return 1
  fi
  printf '%s:5555' "$ip" | wl-copy 2>/dev/null || true
  notify -t 2000 "Waydroid" "Copied $ip:5555"
}

waydroid_logs() {
  APP_NAME="Waydroid"
  if waydroid_session_running; then
    setsid kitty --title "waydroid logcat" sh -c \
      "sudo waydroid logcat; echo; echo '[logcat ended — press Enter]'; read -r _" >/dev/null 2>&1 &
  else
    setsid kitty --title "waydroid log" sh -c \
      "sudo tail -n 200 -f '$WAYDROID_LOG'; echo; echo '[log stream ended — press Enter]'; read -r _" >/dev/null 2>&1 &
  fi
}

waydroid_shell() {
  APP_NAME="Waydroid"
  if ! waydroid_session_running; then
    notify -t 3000 "Waydroid" "Session not running"
    return 1
  fi
  setsid kitty --title "waydroid shell" sh -c \
    "sudo waydroid shell; echo; echo '[shell ended — press Enter]'; read -r _" >/dev/null 2>&1 &
}

waydroid_screenshot() {
  APP_NAME="Waydroid"
  local ip file
  if ! waydroid_session_running; then
    notify -t 3000 "Waydroid" "Session not running"
    return 1
  fi
  ip="$(waydroid status 2>/dev/null | awk -F'\t' '/IP address/ {print $2}')"
  if [ -z "$ip" ]; then
    notify -u critical "Waydroid" "No session IP"
    return 1
  fi
  mkdir -p "$HOME/Pictures"
  file="$HOME/Pictures/waydroid-$(date +%Y%m%d-%H%M%S).png"
  adb connect "$ip:5555" >/dev/null 2>&1 || true
  if adb -s "$ip:5555" exec-out screencap -p >"$file" 2>/dev/null && [ -s "$file" ]; then
    notify -t 4000 -i "$file" "Waydroid" "Screenshot saved: $file"
  else
    rm -f "$file"
    notify -t 3000 -u critical "Waydroid" "Screenshot failed"
  fi
}

# ── Emulators (AVDs) ─────────────────────────────────────────────────
# Driven through the `android` CLI (android emulator …), which starts the
# emulator detached, waits for a full boot and reports its adb serial.

have_android_cli() { command -v android >/dev/null 2>&1; }

# adb serial of a running AVD, empty when stopped.
emu_serial() {
  have_android_cli || return 0
  android emulator list --long 2>/dev/null | awk -v id="$1" '
    $1 == id {
      for (i = 2; i <= NF; i++) if ($i ~ /^emulator-/) { print $i; exit }
    }'
}

# id<TAB>name<TAB>api<TAB>state<TAB>serial<TAB>width<TAB>height<TAB>density
cmd_emulators() {
  have_android_cli || return 0
  local id name api state serial w h d cfg
  android emulator list --long 2>/dev/null | awk '
    NR > 1 && NF {
      name = ""; api = ""; state = "stopped"; serial = ""
      for (i = 2; i <= NF; i++) {
        if ($i ~ /^android-/) { api = $i; continue }
        if ($i == "Online") { state = "running"; continue }
        if ($i == "Offline") { continue }
        if ($i ~ /^emulator-/) { serial = $i; continue }
        name = (name == "" ? $i : name " " $i)
      }
      print $1 "\t" name "\t" api "\t" state "\t" serial
    }' | while IFS=$'\t' read -r id name api state serial; do
      cfg="$AVD_HOME/$id.avd/config.ini"
      w="$(sed -n 's/^hw\.lcd\.width=//p' "$cfg" 2>/dev/null | head -n1)"
      h="$(sed -n 's/^hw\.lcd\.height=//p' "$cfg" 2>/dev/null | head -n1)"
      d="$(sed -n 's/^hw\.lcd\.density=//p' "$cfg" 2>/dev/null | head -n1)"
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$name" "$api" "$state" "$serial" "$w" "$h" "$d"
    done
}

# Best-effort focus of a running emulator window (title = AVD name + console port).
emu_focus() {
  local avd="$1" serial="$2" addr
  command -v hyprctl >/dev/null 2>&1 || return 0
  [ -n "$serial" ] || return 0
  addr="$(hyprctl clients -j 2>/dev/null |
    jq -r --arg a "$avd" '.[] | select(.class == "Emulator" and (.title | contains($a))) | .address' 2>/dev/null |
    head -n1)"
  # The QuickShell overlay restores the previous window when it unmaps; wait for
  # it to go away so focusing the emulator is not undone a moment later.
  local i
  for i in $(seq 1 20); do
    hyprctl layers -j 2>/dev/null |
      jq -e '.. | objects | select(.namespace? == "quickshell-redroid")' >/dev/null 2>&1 || break
    sleep 0.1
  done
  sleep 0.15
  if [ -n "$addr" ]; then
    hyprctl dispatch "hl.dsp.focus({ window = hl.get_window(\"address:$addr\") })" >/dev/null 2>&1 ||
      hyprctl dispatch focuswindow "address:$addr" >/dev/null 2>&1 || true
  else
    hyprctl dispatch "hl.dsp.focus({ window = hl.get_window(\"title:Android Emulator - $avd:${serial#emulator-}\") })" >/dev/null 2>&1 || true
  fi
}

emu_start() {
  local avd="$1" cold="${2:-}" serial i
  APP_NAME="Emulator $avd"
  if ! have_android_cli; then
    notify -u critical "$APP_NAME" "android CLI not found"
    return 1
  fi
  serial="$(emu_serial "$avd")"
  if [ -n "$serial" ]; then
    emu_focus "$avd" "$serial"
    notify -t 2000 "$APP_NAME" "Already running ($serial)"
    return 0
  fi

  notify -t 300000 "$APP_NAME" "Booting…"
  local args=(emulator start)
  [ "$cold" = "cold" ] && args+=(--cold)
  args+=("$avd")
  log "emu $avd: android ${args[*]}"
  QT_QPA_PLATFORM=xcb setsid android "${args[@]}" >>"$STATE_DIR/emu-$avd.log" 2>&1 &

  for i in $(seq 1 180); do
    sleep 2
    serial="$(emu_serial "$avd")"
    [ -n "$serial" ] && break
  done
  if [ -z "$serial" ]; then
    log "emu $avd: boot timed out"
    notify -u critical "$APP_NAME" "Boot timed out — see $STATE_DIR/emu-$avd.log"
    return 1
  fi

  for i in $(seq 1 60); do
    if [ "$(timeout 5 adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; then
      log "emu $avd: ready as $serial"
      notify -t 3000 "$APP_NAME" "Ready ($serial)"
      return 0
    fi
    sleep 2
  done
  log "emu $avd: serial $serial but boot did not finish"
  notify -u critical "$APP_NAME" "Started ($serial) but boot did not finish"
  return 1
}

emu_open() {
  local avd="$1" serial
  APP_NAME="Emulator $avd"
  serial="$(emu_serial "$avd")"
  if [ -n "$serial" ]; then
    emu_focus "$avd" "$serial"
    notify -t 2000 "$APP_NAME" "Focused ($serial)"
  else
    emu_start "$avd"
  fi
}

emu_stop() {
  local avd="$1" quiet="${2:-}" serial
  APP_NAME="Emulator $avd"
  qs ipc call notifications dismissApp "$APP_NAME" >/dev/null 2>&1 || true
  serial="$(emu_serial "$avd")"
  if [ -z "$serial" ]; then
    [ "$quiet" = "quiet" ] || notify -t 2000 "$APP_NAME" "Not running"
    return 0
  fi
  [ "$quiet" = "quiet" ] || notify -t 300000 "$APP_NAME" "Stopping…"
  android emulator stop "$avd" >/dev/null 2>&1 || true
  [ "$quiet" = "quiet" ] || notify -t 2000 "$APP_NAME" "Stopped"
}

emu_restart() {
  local avd="$1"
  emu_stop "$avd" quiet
  sleep 1
  emu_start "$avd"
}

emu_logs() {
  local avd="$1" serial
  APP_NAME="Emulator $avd"
  serial="$(emu_serial "$avd")"
  if [ -n "$serial" ]; then
    setsid kitty --title "emulator $avd logcat" sh -c \
      "adb -s '$serial' logcat; echo; echo '[logcat ended — press Enter]'; read -r _" >/dev/null 2>&1 &
  else
    setsid kitty --title "emulator $avd log" sh -c \
      "tail -n 200 -f '$HOME/.android/$avd/emulator.log' '$STATE_DIR/emu-$avd.log'; echo; echo '[log ended — press Enter]'; read -r _" >/dev/null 2>&1 &
  fi
}

emu_shell() {
  local avd="$1" serial
  APP_NAME="Emulator $avd"
  serial="$(emu_serial "$avd")"
  if [ -z "$serial" ]; then
    notify -t 3000 "$APP_NAME" "Not running"
    return 1
  fi
  setsid kitty --title "emulator $avd shell" sh -c \
    "adb -s '$serial' shell; echo; echo '[adb shell ended — press Enter]'; read -r _" >/dev/null 2>&1 &
}

emu_screenshot() {
  local avd="$1" serial file
  APP_NAME="Emulator $avd"
  serial="$(emu_serial "$avd")"
  if [ -z "$serial" ]; then
    notify -t 3000 "$APP_NAME" "Not running"
    return 1
  fi
  mkdir -p "$HOME/Pictures"
  file="$HOME/Pictures/emulator-${avd}-$(date +%Y%m%d-%H%M%S).png"
  if adb -s "$serial" exec-out screencap -p >"$file" 2>/dev/null && [ -s "$file" ]; then
    notify -t 4000 -i "$file" "$APP_NAME" "Screenshot saved: $file"
  else
    rm -f "$file"
    notify -t 3000 -u critical "$APP_NAME" "Screenshot failed"
  fi
}

emu_copy() {
  local avd="$1" serial
  APP_NAME="Emulator $avd"
  serial="$(emu_serial "$avd")"
  if [ -z "$serial" ]; then
    notify -t 3000 "$APP_NAME" "Not running"
    return 1
  fi
  printf '%s' "$serial" | wl-copy 2>/dev/null || true
  notify -t 2000 "$APP_NAME" "Copied $serial"
}

# Kill a hung emulator: polite `adb emu kill` first, SIGTERM as fallback.
emu_kill() {
  local avd="$1" serial
  APP_NAME="Emulator $avd"
  serial="$(emu_serial "$avd")"
  if [ -n "$serial" ]; then
    adb -s "$serial" emu kill >/dev/null 2>&1 || true
    sleep 2
  fi
  if pgrep -f "[@]$avd" >/dev/null 2>&1; then
    pkill -f "[@]$avd" >/dev/null 2>&1 || true
    sleep 1
  fi
  if [ -z "$(emu_serial "$avd")" ]; then
    notify -t 2000 "$APP_NAME" "Killed"
  else
    notify -u critical "$APP_NAME" "Still running — check $STATE_DIR/emu-$avd.log"
    return 1
  fi
}

cmd_emu() {
  local action="${1:-start}" avd="${2:-}"
  [ -n "$avd" ] || {
    echo "usage: redroid.sh emu <start|cold|open|stop|restart|kill|logs|shell|screenshot|copy|doctor> <avd>" >&2
    return 1
  }
  case "$action" in
    start)      emu_start "$avd" ;;
    cold)       emu_start "$avd" cold ;;
    open)       emu_open "$avd" ;;
    stop)       emu_stop "$avd" ;;
    restart)    emu_restart "$avd" ;;
    kill)       emu_kill "$avd" ;;
    logs)       emu_logs "$avd" ;;
    shell)      emu_shell "$avd" ;;
    screenshot) emu_screenshot "$avd" ;;
    copy)       emu_copy "$avd" ;;
    doctor)     cmd_doctor ;;
    *)
      echo "usage: redroid.sh emu <start|cold|open|stop|restart|kill|logs|shell|screenshot|copy|doctor> <avd>" >&2
      return 1
      ;;
  esac
}

cmd_doctor() {
  APP_NAME="Redroid"
  local out
  out="$STATE_DIR/doctor-$(date +%Y%m%d-%H%M%S).txt"
  {
    echo "== redroid / waydroid doctor — $(date '+%F %T') =="
    echo
    echo "-- kernel --"
    uname -a
    echo
    echo "-- nftables / iptables --"
    nft --version 2>&1
    iptables --version 2>&1
    sudo nft list tables 2>&1
    echo
    echo "-- iptables FORWARD --"
    sudo iptables -L FORWARD -n 2>&1 | head -12
    echo
    echo "-- binder --"
    lsmod 2>/dev/null | grep -E 'binder|ashmem' || echo "(no binder module — built into the kernel)"
    mount | grep -i binder || echo "(binderfs not mounted)"
    ls -l /dev/binderfs 2>&1
    ls -l /dev 2>/dev/null | grep -E 'binder|ashmem' || true
    echo
    echo "-- waydroid status --"
    waydroid status 2>&1
    echo
    echo "-- waydroid-container journal (this boot) --"
    sudo journalctl -u waydroid-container -b --no-pager 2>&1 | tail -50
    echo
    echo "-- waydroid log --"
    sudo tail -50 "$WAYDROID_LOG" 2>&1
    echo
    echo "-- docker --"
    sudo docker ps -a --format '{{.Names}}\t{{.Status}}\t{{.Image}}' 2>&1
    echo
    echo "-- android emulators --"
    android emulator list --long 2>&1
    adb devices -l 2>&1
    echo
    echo "-- redroid log --"
    tail -30 "$LOG_FILE" 2>/dev/null
  } >"$out" 2>&1
  setsid kitty --title "redroid doctor" sh -c \
    "cat '$out'; echo; echo '[report saved: $out — press Enter]'; read -r _" >/dev/null 2>&1 &
  notify -t 4000 "Redroid" "Doctor report: $out"
}

cmd_start() {
  local v="$1" w="$2" h="$3" d="$4"
  local image="${REDROID_IMAGE:-}"
  if [ -z "$image" ]; then
    if [ "$v" = "15" ] && docker_cmd images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -qx 'redroid15-patched:v1'; then
      image="redroid15-patched:v1"
    elif [ "$v" = "8" ]; then
      image="redroid/redroid:8.1.0-latest"
    else
      image="redroid/redroid:${v}.0.0-latest"
    fi
  fi
  local name port
  name="$(name_for "$v")"
  port="$(port_for "$v")"

  APP_NAME="Redroid $v"
  notify -t 300000 "$APP_NAME" "Preparing…"

  if ! ensure_docker; then
    notify -u critical "Redroid $v" "Failed to start Docker"
    log "start $v: docker failed"
    exit 1
  fi

  if is_running "$name"; then
    notify -t 300000 "Redroid $v" "Applying ${w}x${h} @ ${d} dpi…"
    apply_size "$port" "$w" "$h" "$d"
  elif docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "$name" || \
       sudo docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "$name"; then
    notify -t 300000 "Redroid $v" "Starting existing container ${w}x${h} @ ${d} dpi…"
    log "start $v: docker start $name on $port (${w}x${h}@${d})"
    docker_cmd start "$name" >/dev/null 2>&1 || {
      notify -u critical "Redroid $v" "Failed to start container (see log)"
      log "start $v: docker start failed"
      exit 1
    }

    if ! wait_boot "$v" "$port" "$name"; then
      if is_running "$name"; then
        notify -u critical "Redroid $v" "Boot timed out. Check: docker logs $name"
        log "start $v: boot timed out"
      else
        notify -t 3000 "Redroid $v" "Stopped"
        log "start $v: aborted by user"
      fi
      exit 1
    fi
  else
    notify -t 300000 "Redroid $v" "Booting ${w}x${h} @ ${d} dpi…"
    log "start $v: docker run $name on $port (${w}x${h}@${d})"
    docker_cmd run -d --rm --privileged --name "$name" \
      -v "${name}-data:/data" \
      -p "$port:5555" \
      "$image" \
      androidboot.redroid_gpu_mode=host \
      androidboot.redroid_gpu_node=/dev/dri/renderD128 \
      androidboot.redroid_fps=60 \
      androidboot.use_memfd=1 \
      androidboot.redroid_width="$w" \
      androidboot.redroid_height="$h" \
      androidboot.redroid_dpi="$d" >/dev/null 2>&1 || {
      notify -u critical "Redroid $v" "Failed to start container (see log)"
      log "start $v: docker run failed"
      exit 1
    }

    if ! wait_boot "$v" "$port" "$name"; then
      if is_running "$name"; then
        notify -u critical "Redroid $v" "Boot timed out. Check: docker logs $name"
        log "start $v: boot timed out"
      else
        notify -t 3000 "Redroid $v" "Stopped"
        log "start $v: aborted by user"
      fi
      exit 1
    fi
  fi

  # Disable the emulator Bluetooth app: on redroid 15 it crash-loops SystemUI
  # (BLUETOOTH_CONNECT SecurityException), which breaks the whole layer tree.
  if [ "$v" = "15" ]; then
    adb connect "localhost:$port" >/dev/null 2>&1 || true
    adb -s "localhost:$port" shell 'pm disable-user --user 0 com.android.bluetooth' >/dev/null 2>&1 || true
  fi

  apply_size "$port" "$w" "$h" "$d"
  save_size "$v" "$w" "$h" "$d"
  open_scrcpy "$v" "$port"
  notify -t 3000 "Redroid $v" "Ready on localhost:$port"
  log "start $v: ready"
}

cmd_open() {
  local v="$1" name port
  name="$(name_for "$v")"
  port="$(port_for "$v")"
  APP_NAME="Redroid $v"
  notify -t 300000 "$APP_NAME" "Opening…"

  if ! is_running "$name"; then
    notify -t 3000 "Redroid $v" "Not running"
    return 1
  fi
  open_scrcpy "$v" "$port"
  notify -t 2000 "Redroid $v" "Open on localhost:$port"
}

cmd_resize() {
  local v="$1" w="$2" h="$3" d="$4" name port
  APP_NAME="Redroid $v"
  name="$(name_for "$v")"
  port="$(port_for "$v")"
  APP_NAME="Redroid $v"
  notify -t 300000 "$APP_NAME" "Resizing…"

  if ! is_running "$name"; then
    cmd_start "$v" "$w" "$h" "$d"
    return $?
  fi

  apply_size "$port" "$w" "$h" "$d"
  save_size "$v" "$w" "$h" "$d"
  open_scrcpy "$v" "$port"
  notify -t 3000 "Redroid $v" "Resized to ${w}x${h} @ ${d} dpi"
}

cmd_size_reset() {
  local v="$1" name port
  APP_NAME="Redroid $v"
  name="$(name_for "$v")"
  port="$(port_for "$v")"
  if ! is_running "$name"; then
    notify -t 3000 "Redroid $v" "Not running"
    return 1
  fi
  adb connect "localhost:$port" >/dev/null 2>&1 || true
  adb -s "localhost:$port" shell wm size reset >/dev/null 2>&1 || true
  adb -s "localhost:$port" shell wm density reset >/dev/null 2>&1 || true
  rm -f "$STATE_DIR/last-size-$v"
  notify -t 2000 "Redroid $v" "Screen size reset"
}

cmd_stop() {
  local v="$1" quiet="${2:-}" name
  APP_NAME="Redroid $v"
  qs ipc call notifications dismissApp "$APP_NAME" >/dev/null 2>&1 || true
  name="$(name_for "$v")"
  if ! is_running "$name"; then
    [ "$quiet" = "quiet" ] || notify -t 2000 "Redroid $v" "Not running"
    return 0
  fi
  [ "$quiet" = "quiet" ] || notify -t 300000 "Redroid $v" "Stopping…"
  docker_cmd stop "$name" >/dev/null 2>&1 || true
  release_waydroid
  [ "$quiet" = "quiet" ] || notify -t 2000 "Redroid $v" "Stopped"
}

cmd_restart() {
  local v="$1" w="$2" h="$3" d="$4" saved
  APP_NAME="Redroid $v"
  if [ -z "${w:-}" ] || [ -z "${h:-}" ] || [ -z "${d:-}" ]; then
    saved="$(load_size "$v")"
    if [ -n "$saved" ]; then
      w="${saved%%x*}"
      saved="${saved#*x}"
      h="${saved%%@*}"
      d="${saved#*@}"
    else
      w=1080
      h=1920
      d=420
    fi
  fi
  cmd_stop "$v" quiet
  sleep 1
  cmd_start "$v" "$w" "$h" "$d"
}

cmd_logs() {
  local v="$1" name
  name="$(name_for "$v")"
  setsid kitty --title "redroid$v logs" sh -c \
    "docker logs -f '$name' 2>/dev/null || sudo docker logs -f '$name'; echo; echo '[log stream ended]'; read -r _" >/dev/null 2>&1 &
}

cmd_shell() {
  local v="$1" port
  port="$(port_for "$v")"
  setsid kitty --title "redroid$v shell" sh -c \
    "adb -s 'localhost:$port' shell; echo; echo '[adb shell ended — press Enter]'; read -r _" >/dev/null 2>&1 &
}

cmd_screenshot() {
  local v="$1" port file
  APP_NAME="Redroid $v"
  port="$(port_for "$v")"
  mkdir -p "$HOME/Pictures"
  file="$HOME/Pictures/redroid${v}-$(date +%Y%m%d-%H%M%S).png"
  if adb -s "localhost:$port" exec-out screencap -p >"$file" 2>/dev/null && [ -s "$file" ]; then
    notify -t 4000 -i "$file" "Redroid $v" "Screenshot saved: $file"
  else
    rm -f "$file"
    notify -t 3000 -u critical "Redroid $v" "Screenshot failed"
  fi
}

cmd_copy() {
  local v="$1" port
  APP_NAME="Redroid $v"
  port="$(port_for "$v")"
  printf 'localhost:%s' "$port" | wl-copy 2>/dev/null || true
  notify -t 2000 "Redroid $v" "Copied localhost:$port"
}

cmd_kill() {
  local v="$1" name
  APP_NAME="Redroid $v"
  qs ipc call notifications dismissApp "$APP_NAME" >/dev/null 2>&1 || true
  name="$(name_for "$v")"
  docker_cmd kill "$name" >/dev/null 2>&1 || true
  release_waydroid
  notify -t 2000 "Redroid $v" "Killed"
}

cmd_clear() {
  local v="$1" name
  APP_NAME="Redroid $v"
  name="$(name_for "$v")"
  cmd_stop "$v" quiet
  docker_cmd rm -f "$name" >/dev/null 2>&1 || true
  docker_cmd volume rm "${name}-data" >/dev/null 2>&1 || true
  release_waydroid
  rm -f "$STATE_DIR/last-size-$v"
  notify -t 3000 "Redroid $v" "Container and data removed"
}

cmd_status() {
  local v port ports size state list=()
  # Callers may pass their own version list; fall back to the built-in one.
  for v in "$@"; do [[ "$v" =~ ^[0-9]+$ ]] && list+=("$v"); done
  ((${#list[@]})) || list=("${VERSIONS[@]}")
  ports="$(ss -ltn 2>/dev/null | awk 'NR > 1 { n = split($4, a, ":"); print a[n] }')"
  for v in "${list[@]}"; do
    port="$(port_for "$v")"
    if printf '%s\n' "$ports" | grep -qx "$port"; then state=running; else state=stopped; fi
    size="$(load_size "$v")"
    if [ -n "$size" ]; then
      printf '%s %s %s\n' "$v" "$state" "$size"
    else
      printf '%s %s\n' "$v" "$state"
    fi
  done
  if have_waydroid; then
    if pgrep -f 'waydroid session start' >/dev/null 2>&1; then
      printf 'waydroid running\n'
    else
      printf 'waydroid stopped\n'
    fi
  fi
}

usage() {
  cat <<'EOF'
usage: redroid.sh <command> [args]

commands:
  start <v> <w> <h> <d>   boot (or reconfigure) and open
  resize <v> <w> <h> <d>  apply size and open
  size-reset <v>          reset screen size and density to native
  open <v>                open scrcpy for a running instance
  stop <v>                stop container
  restart <v> [w h d]     restart (uses last size when omitted)
  logs <v>                follow container logs
  shell <v>               open adb shell
  screenshot <v>          save a screenshot to /tmp
  copy <v>                copy localhost:<port>
  kill <v>                docker kill
  clear <v>               remove container and data volume
  status [v…]             print running/stopped per version
  waydroid [action]       Waydroid control: start|open|stop|restart|logs|shell|copy|screenshot|doctor
  emulators               list AVDs (tab-separated: id, name, api, state, serial, size)
  emu <action> <avd>      AVD control: start|cold|open|stop|restart|kill|logs|shell|screenshot|copy|doctor
  doctor                  write binder/net/docker diagnostics to a report
EOF
}

main() {
  local cmd="${1:-}"
  [ $# -gt 0 ] && shift
  case "$cmd" in
    start)
      [ $# -ge 4 ] || { usage; exit 1; }
      cmd_start "$1" "$2" "$3" "$4"
      ;;
    resize)
      [ $# -ge 4 ] || { usage; exit 1; }
      cmd_resize "$1" "$2" "$3" "$4"
      ;;
    open)       [ $# -ge 1 ] && cmd_open "$1" ;;
    size-reset) [ $# -ge 1 ] && cmd_size_reset "$1" ;;
    stop)       [ $# -ge 1 ] && cmd_stop "$1" ;;
    restart)    [ $# -ge 1 ] && cmd_restart "$1" "${2:-}" "${3:-}" "${4:-}" ;;
    logs)       [ $# -ge 1 ] && cmd_logs "$1" ;;
    shell)      [ $# -ge 1 ] && cmd_shell "$1" ;;
    screenshot) [ $# -ge 1 ] && cmd_screenshot "$1" ;;
    copy)       [ $# -ge 1 ] && cmd_copy "$1" ;;
    kill)       [ $# -ge 1 ] && cmd_kill "$1" ;;
    clear)      [ $# -ge 1 ] && cmd_clear "$1" ;;
    status)     cmd_status "$@" ;;
    waydroid)   cmd_waydroid "${1:-start}" ;;
    emulators)  cmd_emulators ;;
    emu)        cmd_emu "${1:-}" "${2:-}" ;;
    doctor)     cmd_doctor ;;
    *)          usage; exit 1 ;;
  esac
}

main "$@"
