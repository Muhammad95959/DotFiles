#!/usr/bin/env python3
import json, os, sys, sqlite3, shutil, tempfile, glob

def walk_chromium(node, out):
    if isinstance(node, dict):
        t = node.get("type")
        if t == "url" and node.get("url"):
            out.append((node.get("name", node["url"]), node["url"]))
        for v in node.values():
            walk_chromium(v, out)
    elif isinstance(node, list):
        for v in node:
            walk_chromium(v, out)

def chromium_bookmarks():
    out = []
    home = os.path.expanduser("~")
    # (base dir, normalized source) - sources must match Launcher.qml bookmarkBrowsers:
    # brave, brave-origin, helium, chrome, chromium, vivaldi, firefox
    bases = [
        (".config/BraveSoftware/Brave-Browser", "brave"),
        (".config/BraveSoftware/Brave-Browser-Beta", "brave"),
        (".config/BraveSoftware/Brave-Origin", "brave-origin"),
        (".config/google-chrome", "chrome"),
        (".config/google-chrome-beta", "chrome"),
        (".config/chromium", "chromium"),
        (".config/vivaldi", "vivaldi"),
        (".config/vivaldi-snapshot", "vivaldi"),
        (".config/helium", "helium"),
        (".config/Helium", "helium"),
        (".config/helium-browser", "helium"),
    ]
    profiles = ["Default/Bookmarks", "Profile 1/Bookmarks", "Profile 2/Bookmarks"]
    for base, src in bases:
        for prof in profiles:
            rel = base + "/" + prof
            p = os.path.join(home, rel)
            if not os.path.isfile(p):
                continue
            try:
                with open(p, "r", encoding="utf-8", errors="ignore") as f:
                    data = json.load(f)
                items = []
                walk_chromium(data.get("roots", data), items)
                for title, url in items:
                    if url and not url.startswith(("place:", "chrome://", "about:")):
                        out.append((title or url, url, src))
            except Exception:
                continue
    return out

def firefox_bookmarks(limit=2000):
    out = []
    home = os.path.expanduser("~")
    for pat in [".mozilla/firefox/*.default*/places.sqlite",
                ".mozilla/firefox/*.default-release/places.sqlite",
                ".config/mozilla/firefox/*.default*/places.sqlite",
                ".config/mozilla/firefox/*.default-release/places.sqlite",
                "snap/firefox/common/.mozilla/firefox/*.default*/places.sqlite",
                ".var/app/org.mozilla.firefox/.mozilla/firefox/*.default*/places.sqlite"]:
        for db in glob.glob(os.path.join(home, pat)):
            if not os.path.isfile(db):
                continue
            tmp = ""
            try:
                fd, tmp = tempfile.mkstemp(suffix=".sqlite")
                os.close(fd)
                shutil.copy2(db, tmp)
                con = sqlite3.connect("file:%s?mode=ro" % tmp, uri=True, timeout=2)
                cur = con.cursor()
                cur.execute("""SELECT COALESCE(b.title, p.title, p.url), p.url
                               FROM moz_places p JOIN moz_bookmarks b ON b.fk = p.id
                               WHERE p.url NOT LIKE 'place:%' AND p.url LIKE 'http%'
                               GROUP BY p.url ORDER BY MAX(p.visit_count) DESC LIMIT ?""", (limit,))
                for title, url in cur.fetchall():
                    if url:
                        out.append((title or url, url, "firefox"))
                con.close()
            except Exception:
                pass
            finally:
                if tmp and os.path.exists(tmp):
                    try:
                        os.unlink(tmp)
                    except Exception:
                        pass
    return out

def main():
    seen = set()
    items = chromium_bookmarks() + firefox_bookmarks()
    for title, url, src in items:
        src = (src or "unknown").strip().lower()
        if not url or (url, src) in seen:
            continue
        if url.startswith(("place:", "chrome://", "about:", "file://")):
            continue
        seen.add((url, src))
        title = (title or url).replace("\t", " ").replace("\n", " ").strip()[:200]
        url = url.strip()[:500]
        sys.stdout.write("%s\t%s\t%s\n" % (title, url, src))
        if len(seen) >= 3000:
            break

if __name__ == "__main__":
    main()
