#!/usr/bin/env bash
# Redroid control helper for the QuickShell module.
set -u

export PATH="$HOME/.local/bin:$HOME/.android/Sdk/platform-tools:$HOME/Android/Sdk/platform-tools:/usr/local/bin:/usr/bin:/bin:$PATH"

VERSIONS=(12 13 14 15)
NAME_PREFIX="redroid"
BASE_PORT=5500
STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/quickshell/redroid"
LOG_FILE="$STATE_DIR/redroid.log"

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

port_listening() {
  local port="$1"
  ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":$port$"
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
  printf '%sx%s %s\n' "$w" "$h" "$d" >"$STATE_DIR/last-size-$v"
}

load_size() {
  cat "$STATE_DIR/last-size-$1" 2>/dev/null || true
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

cmd_start() {
  local v="$1" w="$2" h="$3" d="$4"
  local image="${REDROID_IMAGE:-}"
  if [ -z "$image" ]; then
    if [ "$v" = "15" ] && docker_cmd images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -qx 'redroid15-patched:v1'; then
      image="redroid15-patched:v1"
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
  APP_NAME="Redroid $v"
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
  [ "$quiet" = "quiet" ] || notify -t 2000 "Redroid $v" "Stopped"
}

cmd_restart() {
  local v="$1" w="$2" h="$3" d="$4" saved
  APP_NAME="Redroid $v"
  if [ -z "${w:-}" ] || [ -z "${h:-}" ] || [ -z "${d:-}" ]; then
    saved="$(load_size "$v")"
    if [ -n "$saved" ]; then
      # shellcheck disable=SC2086
      set -- $saved
      w="${1%x*}"
      h="${1#*x}"
      d="$2"
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
  notify -t 2000 "Redroid $v" "Killed"
}

cmd_clear() {
  local v="$1" name
  APP_NAME="Redroid $v"
  name="$(name_for "$v")"
  cmd_stop "$v" quiet
  docker_cmd rm -f "$name" >/dev/null 2>&1 || true
  docker_cmd volume rm "${name}-data" >/dev/null 2>&1 || true
  rm -f "$STATE_DIR/last-size-$v"
  notify -t 3000 "Redroid $v" "Container and data removed"
}

cmd_status() {
  local v port
  for v in "${VERSIONS[@]}"; do
    port="$(port_for "$v")"
    if port_listening "$port"; then
      printf '%s running\n' "$v"
    else
      printf '%s stopped\n' "$v"
    fi
  done
}

cmd_versions() {
  local versions=""
  versions=$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep '^redroid/redroid:' | sed -E 's/.*:([0-9]+)\..*/\1/' | sort -nu | tr '\n' ' ')
  if [ -z "$versions" ]; then
    versions=$(sudo docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep '^redroid/redroid:' | sed -E 's/.*:([0-9]+)\..*/\1/' | sort -nu | tr '\n' ' ')
  fi
  if [ -z "$versions" ]; then
    versions=$(docker ps --format '{{.Names}}' 2>/dev/null | sed -n 's/^redroid\([0-9]*\)$/\1/p' | sort -nu | tr '\n' ' ')
  fi
  if [ -z "$versions" ]; then
    versions=$(sudo docker ps --format '{{.Names}}' 2>/dev/null | sed -n 's/^redroid\([0-9]*\)$/\1/p' | sort -nu | tr '\n' ' ')
  fi
  if [ -z "$versions" ]; then
    versions="12 13 14 15"
  fi
  printf '%s\n' "$versions" | tr ' ' '\n' | grep -E '^[0-9]+$' | sort -nu | tr '\n' ' '
  echo
}


usage() {
  cat <<'EOF'
usage: redroid.sh <command> [args]

commands:
  start <v> <w> <h> <d>   boot (or reconfigure) and open
  resize <v> <w> <h> <d>  apply size and open
  open <v>                open scrcpy for a running instance
  stop <v>                stop container
  restart <v> [w h d]     restart (uses last size when omitted)
  logs <v>                follow container logs
  shell <v>               open adb shell
  screenshot <v>          save a screenshot to /tmp
  copy <v>                copy localhost:<port>
  kill <v>                docker kill
  clear <v>               remove container and data volume
  status                  print running/stopped per version
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
    stop)       [ $# -ge 1 ] && cmd_stop "$1" ;;
    restart)    [ $# -ge 1 ] && cmd_restart "$1" "${2:-}" "${3:-}" "${4:-}" ;;
    logs)       [ $# -ge 1 ] && cmd_logs "$1" ;;
    shell)      [ $# -ge 1 ] && cmd_shell "$1" ;;
    screenshot) [ $# -ge 1 ] && cmd_screenshot "$1" ;;
    copy)       [ $# -ge 1 ] && cmd_copy "$1" ;;
    kill)       [ $# -ge 1 ] && cmd_kill "$1" ;;
    clear)      [ $# -ge 1 ] && cmd_clear "$1" ;;
    status)     cmd_status ;;
    versions)   cmd_versions ;;
    *)          usage; exit 1 ;;
  esac
}

main "$@"
