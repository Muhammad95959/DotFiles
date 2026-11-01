#!/usr/bin/env python3
"""Tooling for the /design skill.

Subcommands:
  check <tokens.json>...                 Validate tokens and WCAG 2.2 AA contrast. Exit 1 on failure.
  build <src/index.html> <out.html>      Assemble a self-contained HTML file from partials, inject tokens,
                                         lint for hard-coded colors and undefined CSS vars.
                                         Also writes <out_dir>/.artifact/<out name> (fragment for publishing).
  shot <file.html> <route> <out.png>     Headless Chrome screenshot of a route, e.g. "#ds?theme=dark&viewport=phone".
       [--width 1440] [--height 1000]

Build directives (HTML comments inside source files):
  <!-- include: relative/path.html -->              inline another file (recursive, relative to the including file)
  <!-- tokens: path/to/tokens.json [scope=.opt-a] [id=opt-a] -->
                                                    inject CSS variables, font links, icon loader and a JSON
                                                    <script id=...> with resolved tokens + contrast report
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

REQUIRED_ROLES = [
    "background", "on-background",
    "surface", "on-surface", "on-surface-variant",
    "surface-container", "surface-container-high",
    "outline", "outline-variant",
    "primary", "on-primary", "primary-container", "on-primary-container",
    "error", "on-error", "error-container", "on-error-container",
    "warning-container", "on-warning-container",
    "success-container", "on-success-container",
    "info-container", "on-info-container",
    "inverse-surface", "on-inverse-surface", "inverse-primary",
    "focus-ring", "scrim",
]

TEXT_FG = ["on-surface", "on-surface-variant"]
TEXT_BG = ["background", "surface", "surface-container", "surface-container-high"]
BUILTIN_PAIRS = (
    [(fg, bg, "text") for fg in TEXT_FG for bg in TEXT_BG]
    + [(fg, bg, "text") for fg in ["primary", "error"] for bg in ["background", "surface", "surface-container"]]
    + [(fg, bg, "ui") for fg in ["outline", "focus-ring"] for bg in ["background", "surface", "surface-container", "surface-container-high"]]
    + [("inverse-primary", "inverse-surface", "text")]
)
THRESHOLDS = {"text": 4.5, "large-text": 3.0, "ui": 3.0}

HEX_RE = re.compile(r"^#([0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$")
REF_RE = re.compile(r"^\{([^}]+)\}$")


def fail(msg):
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(1)


def parse_hex(value):
    m = HEX_RE.match(value.strip())
    if not m:
        return None
    h = m.group(1)
    if len(h) in (3, 4):
        h = "".join(c * 2 for c in h)
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    a = int(h[6:8], 16) / 255 if len(h) == 8 else 1.0
    return r, g, b, a


def luminance(rgb):
    def ch(c):
        c = c / 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = rgb[:3]
    return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)


def blend(fg, bg):
    a = fg[3]
    return tuple(round(fg[i] * a + bg[i] * (1 - a)) for i in range(3)) + (1.0,)


def ratio(fg, bg):
    if fg[3] < 1:
        fg = blend(fg, bg)
    l1, l2 = luminance(fg), luminance(bg)
    hi, lo = max(l1, l2), min(l1, l2)
    return (hi + 0.05) / (lo + 0.05)


def resolve_ref(value, primitives, path):
    m = REF_RE.match(value.strip()) if isinstance(value, str) else None
    if not m:
        return value
    node = primitives
    for part in m.group(1).split("."):
        if not isinstance(node, dict) or part not in node:
            fail(f"{path}: unknown primitive reference {value}")
        node = node[part]
    if isinstance(node, str) and REF_RE.match(node):
        return resolve_ref(node, primitives, path)
    return node


def load_tokens(path):
    try:
        data = json.loads(Path(path).read_text())
    except json.JSONDecodeError as e:
        fail(f"{path}: invalid JSON: {e}")
    themes = data.get("meta", {}).get("themes") or list(data.get("color", {}).keys())
    if not themes:
        fail(f"{path}: no themes in meta.themes or color")
    primitives = data.get("primitives", {}).get("color", {})
    resolved = {}
    for theme in themes:
        roles = data.get("color", {}).get(theme)
        if roles is None:
            fail(f"{path}: color.{theme} missing")
        out = {}
        for role, value in roles.items():
            v = resolve_ref(value, primitives, f"{path} color.{theme}.{role}")
            if not isinstance(v, str) or not parse_hex(v):
                fail(f"{path}: color.{theme}.{role} = {value!r} is not a hex color")
            out[role] = v.lower()
        missing = [r for r in REQUIRED_ROLES if r not in out]
        if missing:
            fail(f"{path}: color.{theme} missing required roles: {', '.join(missing)}")
        resolved[theme] = out
    data["_resolved"] = resolved
    data["_themes"] = themes
    return data


def contrast_report(data):
    pairs = {}
    for fg, bg, use in BUILTIN_PAIRS:
        pairs[(fg, bg)] = use
    any_theme = data["_resolved"][data["_themes"][0]]
    for role in any_theme:
        if role.startswith("on-") and role[3:] in any_theme:
            pairs.setdefault((role, role[3:]), "text")
    for p in data.get("contrast", []):
        bgs = p["bg"] if isinstance(p["bg"], list) else [p["bg"]]
        for bg in bgs:
            pairs[(p["fg"], bg)] = p.get("use", "text")
    report = []
    for theme in data["_themes"]:
        colors = data["_resolved"][theme]
        for (fg, bg), use in pairs.items():
            if fg not in colors or bg not in colors:
                continue
            fgc, bgc = parse_hex(colors[fg]), parse_hex(colors[bg])
            if bgc[3] < 1:
                continue
            r = ratio(fgc, bgc)
            need = THRESHOLDS.get(use, 0)
            report.append({
                "theme": theme, "fg": fg, "bg": bg, "use": use,
                "fgHex": colors[fg], "bgHex": colors[bg],
                "ratio": round(r, 2), "required": need, "pass": r >= need,
            })
    return report


def cmd_check(args):
    ok = True
    for path in args.tokens:
        data = load_tokens(path)
        report = contrast_report(data)
        failed = [r for r in report if not r["pass"]]
        print(f"{path}: {len(report)} pairs checked, {len(failed)} failing")
        for r in failed:
            print(f"  FAIL [{r['theme']}] {r['fg']} on {r['bg']} ({r['use']}): "
                  f"{r['ratio']}:1, needs {r['required']}:1  ({r['fgHex']} on {r['bgHex']})")
        ok = ok and not failed
    sys.exit(0 if ok else 1)


def px(v):
    return f"{v}px" if isinstance(v, (int, float)) else str(v)


def font_stack(f):
    fam = f["family"]
    fam = fam if fam.startswith(("'", '"')) or "," in fam else f"'{fam}'"
    return f"{fam}, {f.get('fallback', 'system-ui, sans-serif')}"


def theme_vars(data, theme):
    lines = [f"--color-{k}: {v};" for k, v in data["_resolved"][theme].items()]
    for k, v in data.get("elevation", {}).get(theme, {}).items():
        lines.append(f"--elevation-{k}: {v};")
    return " ".join(lines)


def static_vars(data):
    lines = []
    for name, f in data.get("font", {}).items():
        lines.append(f"--font-{name}: {font_stack(f)};")
    for name, t in data.get("type", {}).items():
        lines.append(f"--type-{name}: {t.get('weight', 400)} {px(t['size'])}/{px(t['line'])} var(--font-{t.get('font', 'body')});")
        lines.append(f"--type-{name}-tracking: {px(t.get('tracking', 0))};")
    for group, prefix in (("space", "space"), ("radius", "radius"), ("size", "size")):
        for k, v in data.get(group, {}).items():
            lines.append(f"--{prefix}-{k}: {px(v)};")
    icons = data.get("icons", {})
    if "stroke" in icons:
        lines.append(f"--icon-stroke: {icons['stroke']};")
    return " ".join(lines)


def tokens_css(data, scope):
    themes = data["_themes"]
    light = themes[0] if "light" not in themes else "light"
    dark = "dark" if "dark" in themes else None
    static = static_vars(data)
    css = []
    s = scope or ":root"
    css.append(f"{s} {{ {static} {theme_vars(data, light)} }}")
    if dark:
        dv = theme_vars(data, dark)
        if scope:
            css.append(f"@media (prefers-color-scheme: dark) {{ :root:not([data-theme=\"light\"]) {scope} {{ {dv} }} }}")
            css.append(f":root[data-theme=\"dark\"] {scope} {{ {dv} }}")
        else:
            css.append(f"@media (prefers-color-scheme: dark) {{ :root:not([data-theme=\"light\"]) {{ color-scheme: dark; {dv} }} }}")
            css.append(f":root[data-theme=\"dark\"] {{ color-scheme: dark; {dv} }}")
        prefix = f"{scope} " if scope else ""
        css.append(f"{prefix}[data-theme-panel=\"dark\"]:not(#_) {{ color-scheme: dark; {dv} }}")
        css.append(f"{prefix}[data-theme-panel=\"light\"]:not(#_) {{ color-scheme: light; {theme_vars(data, light)} }}")
    prefix = f"{scope} " if scope else ""
    for name, t in data.get("type", {}).items():
        css.append(f"{prefix}.t-{name} {{ font: var(--type-{name}); letter-spacing: var(--type-{name}-tracking); }}")
    return "\n".join(css)


def head_assets(data):
    out = []
    families = [f["google"] for f in data.get("font", {}).values() if f.get("google")]
    icons = data.get("icons", {})
    iset = icons.get("set", "")
    if iset.startswith("material-symbols-"):
        fam = "Material+Symbols+" + iset.split("-")[-1].capitalize()
        families.append(f"{fam}:opsz,wght,FILL,GRAD@20..48,100..700,0..1,-50..200")
    if families:
        q = "&".join("family=" + f.replace(" ", "+") for f in families)
        out.append(f'<link rel="stylesheet" href="https://fonts.googleapis.com/css2?{q}&display=swap">')
    if iset == "lucide":
        out.append(f'<script src="https://cdn.jsdelivr.net/npm/lucide@{icons.get("version", "0.460.0")}/dist/umd/lucide.min.js"></script>')
    return out


INCLUDE_RE = re.compile(r"<!--\s*include:\s*(\S+)\s*-->")
TOKENS_RE = re.compile(r"<!--\s*tokens:\s*(\S+)((?:\s+\w+=\S+)*)\s*-->")
GEN_START, GEN_END = "/*__generated__*/", "/*__end_generated__*/"


class Builder:
    def __init__(self):
        self.lint_errors = []
        self.contrast_failed = []
        self.seen_assets = set()

    def lint_source(self, path, text):
        if Path(path).name.startswith("viewer."):
            return
        regions = []
        if path.suffix == ".css":
            regions.append(text)
        else:
            regions += re.findall(r"<style[^>]*>(.*?)</style>", text, re.S)
            regions += re.findall(r'style="([^"]*)"', text)
            regions += re.findall(r"style='([^']*)'", text)
        color_fn = re.compile(r"(#[0-9a-fA-F]{3,8}\b|\b(?:rgb|rgba|hsl|hsla|oklch|oklab|lab|lch)\()")
        for region in regions:
            for line in region.splitlines():
                if "lint-ok" in line:
                    continue
                for m in color_fn.finditer(line):
                    self.lint_errors.append(f"{path}: hard-coded color '{m.group(0)}' in: {line.strip()[:100]}")
        for m in re.finditer(r'\b(fill|stroke|stop-color|color)="([^"]+)"', text):
            val = m.group(2).strip()
            if val.startswith("var("):
                self.lint_errors.append(f"{path}: {m.group(1)}=\"{val}\" does not work as an SVG attribute; use style=\"{m.group(1)}:{val}\" or a CSS class")
            elif val not in ("none", "currentColor", "transparent", "inherit") and not val.startswith("url("):
                self.lint_errors.append(f"{path}: hard-coded {m.group(1)}=\"{val}\"; use currentColor or a token via style/class")

    def expand(self, path, stack=()):
        path = Path(path).resolve()
        if path in stack:
            fail(f"include cycle: {' -> '.join(str(p) for p in stack + (path,))}")
        if not path.exists():
            fail(f"include not found: {path}")
        text = path.read_text()
        self.lint_source(path, text)

        def inc(m):
            return self.expand(path.parent / m.group(1), stack + (path,))

        def tok(m):
            opts = dict(o.split("=", 1) for o in m.group(2).split())
            tpath = (path.parent / m.group(1)).resolve()
            data = load_tokens(tpath)
            report = contrast_report(data)
            self.contrast_failed += [(tpath, r) for r in report if not r["pass"]]
            tid = opts.get("id", "tokens")
            scope = opts.get("scope")
            payload = {
                "meta": data.get("meta", {}), "themes": data["_themes"], "scope": scope,
                "primitives": data.get("primitives", {}).get("color", {}),
                "roles": {t: {r: data.get("color", {})[t][r] for r in data["_resolved"][t]} for t in data["_themes"]},
                "resolved": data["_resolved"], "font": data.get("font", {}), "type": data.get("type", {}),
                "space": data.get("space", {}), "radius": data.get("radius", {}), "size": data.get("size", {}),
                "elevation": data.get("elevation", {}), "icons": data.get("icons", {}), "contrast": report,
            }
            assets = [a for a in head_assets(data) if a not in self.seen_assets]
            self.seen_assets.update(assets)
            js = json.dumps(payload).replace("</", "<\\/")
            return ("\n".join(assets) + f"\n<style>{GEN_START}\n{tokens_css(data, scope)}\n{GEN_END}</style>\n"
                    f'<script type="application/json" id="{tid}">{js}</script>')

        text = TOKENS_RE.sub(tok, text)
        return INCLUDE_RE.sub(inc, text)

    def lint_vars(self, html):
        css_blobs = re.findall(r"<style[^>]*>(.*?)</style>", html, re.S) + re.findall(r'style="([^"]*)"', html)
        css = "\n".join(css_blobs)
        defined = set(re.findall(r"(--[\w-]+)\s*:", css))
        defined |= set(re.findall(r"setProperty\(\s*['\"](--[\w-]+)", html))
        used = set(re.findall(r"var\(\s*(--[\w-]+)\s*\)", css))
        for name in sorted(used - defined):
            self.lint_errors.append(f"undefined CSS variable {name}")


def cmd_build(args):
    b = Builder()
    fragment = b.expand(args.src).strip()
    b.lint_vars(fragment)
    if not fragment.lower().startswith("<title"):
        b.lint_errors.append("first element of the page must be <title> (artifact publishing scans for it)")
    if b.contrast_failed:
        print("Contrast failures (WCAG 2.2 AA):")
        for tpath, r in b.contrast_failed:
            print(f"  [{tpath.name} {r['theme']}] {r['fg']} on {r['bg']} ({r['use']}): {r['ratio']}:1 < {r['required']}:1")
    if b.lint_errors:
        print("Lint errors:")
        for e in sorted(set(b.lint_errors)):
            print(f"  {e}")
    if b.contrast_failed or b.lint_errors:
        print("Build failed, nothing written.")
        sys.exit(1)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    standalone = ('<!doctype html>\n<html lang="en">\n<meta charset="utf-8">\n'
                  '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n'
                  + fragment + "\n</html>\n")
    out.write_text(standalone)
    art = out.parent / ".artifact" / out.name
    art.parent.mkdir(exist_ok=True)
    art.write_text(fragment + "\n")
    print(f"Built {out} ({len(standalone) // 1024} KB) and {art} for publishing")


def find_chrome():
    for c in ["/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
              "/Applications/Chromium.app/Contents/MacOS/Chromium",
              shutil.which("google-chrome") or "", shutil.which("chromium") or "", shutil.which("chrome") or ""]:
        if c and os.path.exists(c):
            return c
    fail("Chrome not found")


def cmd_shot(args):
    url = Path(args.file).resolve().as_uri() + args.route
    out = Path(args.out).resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    # --headless=new is required: the old headless mode renders text baselines and fonts incorrectly.
    cmd = [find_chrome(), "--headless=new", "--disable-gpu", "--hide-scrollbars",
           f"--window-size={args.width},{args.height}", "--virtual-time-budget=4000",
           f"--screenshot={out}", url]
    subprocess.run(cmd, check=True, capture_output=True)
    print(out)


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("check")
    c.add_argument("tokens", nargs="+")
    c.set_defaults(fn=cmd_check)
    b = sub.add_parser("build")
    b.add_argument("src")
    b.add_argument("out")
    b.set_defaults(fn=cmd_build)
    s = sub.add_parser("shot")
    s.add_argument("file")
    s.add_argument("route")
    s.add_argument("out")
    s.add_argument("--width", type=int, default=1440)
    s.add_argument("--height", type=int, default=1000)
    s.set_defaults(fn=cmd_shot)
    args = p.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
