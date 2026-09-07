#!/usr/bin/env python3
"""showkeys.py — stdlib-only evdev key monitor for Quickshell showkeys module.

Reads /dev/input/event* keyboard devices (parsed from /proc/bus/input/devices),
decodes EV_KEY events via struct, tracks modifiers, prints one combo per line:

    SUPER + T
    CTRL + SHIFT + ESC
    SHIFT

No third-party deps (no python-evdev needed). Requires read access to
/dev/input/event* — i.e. user must be in the `input` group:
    sudo usermod -aG input $USER   # then re-login
"""
import os
import re
import select
import struct
import sys

EV_KEY = 0x01

# struct input_event on 64-bit linux: long sec, long usec, u16 type, u16 code, s32 value
EVENT_FMT = "llHHi"
EVENT_SIZE = struct.calcsize(EVENT_FMT)

# Keycodes from linux/input-event-codes.h (subset covering keyboards)
KEY_NAMES = {
    1: "ESC", 2: "1", 3: "2", 4: "3", 5: "4", 6: "5", 7: "6", 8: "7",
    9: "8", 10: "9", 11: "0", 12: "MINUS", 13: "EQUAL", 14: "BACKSPACE",
    15: "TAB", 16: "Q", 17: "W", 18: "E", 19: "R", 20: "T", 21: "Y",
    22: "U", 23: "I", 24: "O", 25: "P", 26: "LEFTBRACE", 27: "RIGHTBRACE",
    28: "ENTER", 29: "LEFTCTRL", 30: "A", 31: "S", 32: "D", 33: "F",
    34: "G", 35: "H", 36: "J", 37: "K", 38: "L", 39: "SEMICOLON",
    40: "APOSTROPHE", 41: "GRAVE", 42: "LEFTSHIFT", 43: "BACKSLASH",
    44: "Z", 45: "X", 46: "C", 47: "V", 48: "B", 49: "N", 50: "M",
    51: "COMMA", 52: "DOT", 53: "SLASH", 54: "RIGHTSHIFT", 55: "KPASTERISK",
    56: "LEFTALT", 57: "SPACE", 58: "CAPSLOCK", 59: "F1", 60: "F2",
    61: "F3", 62: "F4", 63: "F5", 64: "F6", 65: "F7", 66: "F8",
    67: "F9", 68: "F10", 69: "NUMLOCK", 70: "SCROLLLOCK", 71: "KP7",
    72: "KP8", 73: "KP9", 74: "KPMINUS", 75: "KP4", 76: "KP5", 77: "KP6",
    78: "KPPLUS", 79: "KP1", 80: "KP2", 81: "KP3", 82: "KP0", 83: "KPDOT",
    85: "ZENKAKUHANKAKU", 86: "102ND", 87: "F11", 88: "F12", 89: "RO",
    90: "KATAKANA", 91: "HIRAGANA", 92: "HENKAN", 93: "KATAKANAHIRAGANA",
    94: "MUHENKAN", 95: "KPJPCOMMA", 96: "KPENTER", 97: "RIGHTCTRL",
    98: "KPSLASH", 99: "SYSRQ", 100: "RIGHTALT", 101: "LINEFEED",
    102: "HOME", 103: "UP", 104: "PAGEUP", 105: "LEFT", 106: "RIGHT",
    107: "END", 108: "DOWN", 109: "PAGEDOWN", 110: "INSERT", 111: "DELETE",
    112: "MACRO", 113: "MUTE", 114: "VOLUMEDOWN", 115: "VOLUMEUP",
    116: "POWER", 117: "KPEQUAL", 118: "KPPLUSMINUS", 119: "PAUSE",
    120: "SCALE", 121: "KPCOMMA", 122: "HANGEUL", 123: "HANGUEL",
    124: "HANJA", 125: "LEFTMETA", 126: "RIGHTMETA", 127: "COMPOSE",
    128: "STOP", 129: "AGAIN", 130: "PROPS", 131: "UNDO", 132: "FRONT",
    133: "COPY", 134: "OPEN", 135: "PASTE", 136: "FIND", 137: "CUT",
    138: "HELP", 139: "MENU", 140: "CALC", 141: "SETUP", 142: "SLEEP",
    143: "WAKEUP", 144: "FILE", 145: "SENDFILE", 146: "DELETEFILE",
    147: "XFER", 148: "PROG1", 149: "PROG2", 150: "WWW", 151: "MSDOS",
    152: "COFFEE", 153: "ROTATE_DISPLAY", 154: "CYCLEWINDOWS",
    155: "MAIL", 156: "BOOKMARKS", 157: "COMPUTER", 158: "BACK",
    159: "FORWARD", 160: "CLOSECD", 161: "EJECTCD", 162: "EJECTCLOSECD",
    163: "NEXTSONG", 164: "PLAYPAUSE", 165: "PREVIOUSSONG", 166: "STOPCD",
    167: "RECORD", 168: "REWIND", 169: "PHONE", 170: "ISO", 171: "CONFIG",
    172: "HOMEPAGE", 173: "REFRESH", 174: "EXIT", 175: "MOVE", 176: "EDIT",
    177: "SCROLLUP", 178: "SCROLLDOWN", 179: "KPLEFTPAREN", 180: "KPRIGHTPAREN",
    181: "NEW", 182: "REDO", 183: "F13", 184: "F14", 185: "F15", 186: "F16",
    187: "F17", 188: "F18", 189: "F19", 190: "F20", 191: "F21", 192: "F22",
    193: "F23", 194: "F24",
}

MODIFIER_CODES = {29, 42, 54, 56, 97, 100, 125, 126}

PRETTY = {
    "LEFTCTRL": "CTRL", "RIGHTCTRL": "CTRL",
    "LEFTSHIFT": "SHIFT", "RIGHTSHIFT": "SHIFT",
    "LEFTALT": "ALT", "RIGHTALT": "ALT",
    "LEFTMETA": "SUPER", "RIGHTMETA": "SUPER",
    "ESC": "ESC", "ENTER": "ENTER", "TAB": "TAB",
    "BACKSPACE": "BACKSPACE", "SPACE": "SPACE", "DELETE": "DEL",
    "INSERT": "INS", "PAGEUP": "PGUP", "PAGEDOWN": "PGDN",
    "CAPSLOCK": "CAPS", "LEFTBRACE": "[", "RIGHTBRACE": "]",
    "SEMICOLON": ";", "APOSTROPHE": "'", "GRAVE": "`",
    "COMMA": ",", "DOT": ".", "SLASH": "/", "MINUS": "-",
    "EQUAL": "=", "BACKSLASH": "\\",
}

MOD_ORDER = {"SUPER": 0, "CTRL": 1, "ALT": 2, "SHIFT": 3}


def pretty(code):
    raw = KEY_NAMES.get(code, f"KEY{code}")
    return PRETTY.get(raw, raw)


def find_keyboards():
    """Return /dev/input/event* paths whose device exports kbd handler."""
    try:
        with open("/proc/bus/input/devices") as f:
            text = f.read()
    except OSError as e:
        print(f"showkeys: cannot read /proc/bus/input/devices: {e}", file=sys.stderr, flush=True)
        return []
    paths = []
    # Blocks separated by blank lines; look for Handlers=...kbd...
    for block in text.split("\n\n"):
        if "kbd" not in block:
            continue
        m = re.search(r"Handlers=.*?(event\d+)", block)
        if m:
            paths.append(f"/dev/input/{m.group(1)}")
    return sorted(set(paths))


def main():
    devs = find_keyboards()
    if not devs:
        print("showkeys: no keyboard devices found in /proc/bus/input/devices", file=sys.stderr, flush=True)
        return 1

    fds = {}
    for path in devs:
        try:
            fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
            fds[fd] = path
        except PermissionError:
            print(f"showkeys: permission denied on {path} — add user to 'input' group: sudo usermod -aG input $USER, then re-login",
                  file=sys.stderr, flush=True)
        except OSError as e:
            print(f"showkeys: cannot open {path}: {e}", file=sys.stderr, flush=True)

    if not fds:
        print("showkeys: no readable keyboard devices (permission?).", file=sys.stderr, flush=True)
        return 1

    held_mods = set()   # pretty modifier names currently held
    mod_by_code = {}    # keycode -> pretty name, to clear on release
    held_regular = set()

    print(f"showkeys: listening on {', '.join(sorted(fds.values()))}", file=sys.stderr, flush=True)

    while True:
        try:
            r, _, _ = select.select(list(fds), [], [])
        except OSError:
            break
        for fd in r:
            try:
                data = os.read(fd, 1024)
            except OSError:
                continue
            for off in range(0, len(data) - EVENT_SIZE + 1, EVENT_SIZE):
                try:
                    _, _, typ, code, val = struct.unpack(EVENT_FMT, data[off:off + EVENT_SIZE])
                except struct.error:
                    break
                if typ != EV_KEY:
                    continue
                name = pretty(code)
                if val == 1:  # press
                    if code in MODIFIER_CODES:
                        held_mods.add(name)
                        mod_by_code[code] = name
                        print(name, flush=True)
                    else:
                        held_regular.add(code)
                        if held_mods:
                            ordered = sorted(held_mods, key=lambda m: MOD_ORDER.get(m, 9))
                            print(" + ".join(ordered + [name]), flush=True)
                        else:
                            print(name, flush=True)
                elif val == 0:  # release
                    if code in MODIFIER_CODES:
                        old = mod_by_code.pop(code, name)
                        # only discard if no other key still provides it
                        if old not in mod_by_code.values():
                            held_mods.discard(old)
                    else:
                        held_regular.discard(code)
                elif val == 2:  # repeat — refresh overlay timer
                    if code in MODIFIER_CODES:
                        print(name, flush=True)
                    else:
                        if held_mods:
                            ordered = sorted(held_mods, key=lambda m: MOD_ORDER.get(m, 9))
                            print(" + ".join(ordered + [name]), flush=True)
                        else:
                            print(name, flush=True)


if __name__ == "__main__":
    sys.exit(main())
