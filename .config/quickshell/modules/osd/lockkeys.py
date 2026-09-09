#!/usr/bin/env python3
"""lockkeys.py — stdlib-only instant Caps/Num Lock monitor for Quickshell OSD.

Why this exists: polling /sys/class/leds/...brightness on a timer (e.g. every
350ms) adds up to a full poll interval of visible lag before the OSD appears.
This daemon instead blocks on the keyboard evdev devices and reports lock-key
presses the moment they happen (~ms latency).

Protocol (one line per stdout write, unbuffered):
    init caps <0|1> num <0|1>   — initial LED state at startup (no OSD for this)
    caps <0|1>                  — caps lock toggled, new state
    num <0|1>                   — num lock toggled, new state

State tracking: on each KEY_CAPSLOCK / KEY_NUMLOCK *press* (value==1) the
tracked state is toggled. Toggling (rather than re-reading sysfs) avoids a
race where the kernel LED update hasn't landed yet when we read. Sysfs is
still re-read every RESYNC_SEC seconds to heal any drift (external changes,
missed events); a drift correction is emitted like a normal event.

No third-party deps (no python-evdev needed). Requires read access to
/dev/input/event* — i.e. user must be in the `input` group:
    sudo usermod -aG input $USER   # then re-login
"""
import fnmatch
import glob
import os
import re
import select
import struct
import sys
import time

EV_KEY = 0x01
KEY_CAPSLOCK = 58
KEY_NUMLOCK = 69

# struct input_event on 64-bit linux: long sec, long usec, u16 type, u16 code, s32 value
EVENT_FMT = "llHHi"
EVENT_SIZE = struct.calcsize(EVENT_FMT)

RESYNC_SEC = 30.0  # re-read sysfs + rescan devices (hotplug) this often


def read_led_state(pattern):
    """Return True if ANY matching LED brightness file reports on.

    Multiple keyboards each export their own inputN::capslock file, so
    `head -n1` can read the wrong (inactive) device. Any-on is correct.
    """
    try:
        paths = glob.glob(f"/sys/class/leds/{pattern}")
    except OSError:
        return False
    for p in paths:
        if not fnmatch.fnmatch(os.path.basename(p), pattern):
            continue
        try:
            with open(os.path.join(p, "brightness")) as f:
                if f.read().strip() == "1":
                    return True
        except OSError:
            continue
    return False


def read_states():
    return {
        "caps": read_led_state("input*::capslock"),
        "num": read_led_state("input*::numlock"),
    }


def find_keyboards():
    """Return /dev/input/event* paths whose device exports kbd handler."""
    try:
        with open("/proc/bus/input/devices") as f:
            text = f.read()
    except OSError as e:
        print(f"lockkeys: cannot read /proc/bus/input/devices: {e}", file=sys.stderr, flush=True)
        return []
    paths = []
    for block in text.split("\n\n"):
        if "kbd" not in block:
            continue
        m = re.search(r"Handlers=.*?(event\d+)", block)
        if m:
            paths.append(f"/dev/input/{m.group(1)}")
    return sorted(set(paths))


def open_devices(paths, fds):
    """Open any paths not already open; fds maps fd -> path."""
    known = set(fds.values())
    for path in paths:
        if path in known:
            continue
        try:
            fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
            fds[fd] = path
        except PermissionError:
            print(f"lockkeys: permission denied on {path} — add user to 'input' group: sudo usermod -aG input $USER, then re-login",
                  file=sys.stderr, flush=True)
        except OSError as e:
            print(f"lockkeys: cannot open {path}: {e}", file=sys.stderr, flush=True)


def emit(kind, on):
    print(f"{kind} {1 if on else 0}", flush=True)


def handle_events(data, state):
    """Decode raw input_event bytes; toggle lock state on key presses.

    Returns list of (kind, new_state) changes.
    """
    changes = []
    for off in range(0, len(data) - EVENT_SIZE + 1, EVENT_SIZE):
        try:
            _, _, typ, code, val = struct.unpack(EVENT_FMT, data[off:off + EVENT_SIZE])
        except struct.error:
            break
        if typ != EV_KEY or val != 1:  # press only; ignore release (0) & repeat (2)
            continue
        if code == KEY_CAPSLOCK:
            state["caps"] = not state["caps"]
            changes.append(("caps", state["caps"]))
        elif code == KEY_NUMLOCK:
            state["num"] = not state["num"]
            changes.append(("num", state["num"]))
    return changes


def main():
    state = read_states()
    print(f"init caps {1 if state['caps'] else 0} num {1 if state['num'] else 0}", flush=True)

    fds = {}
    open_devices(find_keyboards(), fds)
    if not fds:
        print("lockkeys: no readable keyboard devices (permission?).", file=sys.stderr, flush=True)
        return 1

    print(f"lockkeys: listening on {', '.join(sorted(fds.values()))}", file=sys.stderr, flush=True)
    last_resync = time.monotonic()

    while True:
        try:
            r, _, _ = select.select(list(fds), [], [], RESYNC_SEC)
        except OSError:
            break
        for fd in r:
            try:
                data = os.read(fd, 1024)
            except OSError:
                # Device vanished (unplugged) — drop it; rescan picks up replacements.
                try:
                    os.close(fd)
                except OSError:
                    pass
                fds.pop(fd, None)
                continue
            for kind, on in handle_events(data, state):
                last_resync = time.monotonic()  # event confirms liveness; don't clobber fresh toggles
                emit(kind, on)
        now = time.monotonic()
        if now - last_resync >= RESYNC_SEC:
            last_resync = now
            open_devices(find_keyboards(), fds)  # hotplug: pick up new keyboards
            if not fds:
                print("lockkeys: all devices gone, waiting for keyboards...", file=sys.stderr, flush=True)
                continue
            actual = read_states()  # drift heal: adopt real LED state if we desynced
            for kind in ("caps", "num"):
                if actual[kind] != state[kind]:
                    state[kind] = actual[kind]
                    emit(kind, actual[kind])


if __name__ == "__main__":
    sys.exit(main())
