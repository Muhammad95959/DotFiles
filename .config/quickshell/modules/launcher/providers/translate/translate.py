#!/usr/bin/env python3
"""Offline Arabic <-> English translation for the quickshell launcher.

The models are CTranslate2 int8 checkpoints shipped inside Argos Translate
`.argosmodel` archives (a zip holding sentencepiece.model + model/model.bin).
Those archives are unpacked directly, so this script needs only `ctranslate2`
and `sentencepiece` -- installing `argostranslate` itself would drag in
stanza/torch for no benefit.

Modes:
  translate.py --check                 print ok | no-deps | no-models
  translate.py --install-deps          install the two Arch packages
  translate.py --install               download + unpack both models
  translate.py --from ar --to en TEXT  print the translation

Environment:
  QUICKSHELL_TRANSLATE_DIR  overrides the model directory
"""

import argparse
import io
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile

AR = "ar"
EN = "en"

# Argos package version that still ships the Arabic pairs.
PKG_REV = "1_0"
BASE_URL = "https://data.argosopentech.com/argospm/v1"

# lang -> (local dir name, archive name)
PAIRS = {
    AR: ("ar_en", "translate-ar_en-%s.argosmodel" % PKG_REV),
    EN: ("en_ar", "translate-en_ar-%s.argosmodel" % PKG_REV),
}

# Members worth extracting; the bundled stanza/ tokenizer is unused here.
WANTED = ("sentencepiece.model", "model/model.bin", "model/shared_vocabulary.txt")

# Sentence terminators for both scripts. Splitting is required: the models
# repeat themselves when handed several sentences as one sequence. Newlines are
# not terminators here; layout() keeps them as line boundaries.
SENT_SPLIT = re.compile(r"(?<=[.!?؟۔…])\s+")
MAX_CHARS = 400

EXIT_NOMODELS = 3

# `--check` verdicts, read by TranslateProvider.qml
OK = "ok"
NO_DEPS = "no-deps"
NO_MODELS = "no-models"

AUR_CT2 = "https://aur.archlinux.org/python-ctranslate2-bin"
PKG_CT2 = "python-ctranslate2-bin"
# sentencepiece-bin is only the C++ library; the Python bindings we import live
# in the sibling package, which pulls sentencepiece-bin in as a dependency.
PKG_SP = "python-sentencepiece-bin"


def model_root():
    return os.environ.get("QUICKSHELL_TRANSLATE_DIR") or os.path.expanduser(
        "~/.local/share/quickshell-translate"
    )


def pair_dir(lang):
    return os.path.join(model_root(), PAIRS[lang][0])


def have_pair(lang):
    d = pair_dir(lang)
    return os.path.isfile(os.path.join(d, "sentencepiece.model")) and os.path.isfile(
        os.path.join(d, "model", "model.bin")
    )


def _have(module):
    import importlib.util

    try:
        return importlib.util.find_spec(module) is not None
    except (ImportError, ValueError):
        return False


def have_deps():
    return all(_have(m) for m in ("ctranslate2", "sentencepiece"))


def verdict():
    """Distinguish a missing engine from missing models; the remedies differ."""
    if not have_deps():
        return NO_DEPS
    if not (have_pair(AR) and have_pair(EN)):
        return NO_MODELS
    return OK


def sentences(line, max_chars=MAX_CHARS):
    """Split one line into translatable pieces, hard-wrapping long tokens."""
    out = []
    for part in SENT_SPLIT.split(line):
        part = (part or "").strip()
        if not part:
            continue
        if len(part) <= max_chars:
            out.append(part)
            continue
        cur = ""
        for word in part.split():
            # A single token longer than the window has no spaces to break on,
            # so slice it directly rather than overrun the model's 512 limit.
            while len(word) > max_chars:
                out.append(word[:max_chars])
                word = word[max_chars:]
            if not word:
                continue
            if cur and len(cur) + 1 + len(word) > max_chars:
                out.append(cur)
                cur = word
            else:
                cur = word if not cur else cur + " " + word
        if cur:
            out.append(cur)
    return out


def layout(text, max_chars=MAX_CHARS):
    """Group pieces per source line so paragraph structure survives translation."""
    groups = [sentences(line, max_chars) for line in text.splitlines()]
    return [g for g in groups if g]


class Engine:
    """Lazily loads one direction; a process handles one direction per call."""

    def __init__(self, lang):
        self.lang = lang
        self.sp = None
        self.tr = None

    def load(self):
        if self.tr is not None:
            return
        import ctranslate2
        import sentencepiece as spm

        d = pair_dir(self.lang)
        sp = spm.SentencePieceProcessor()
        sp.load(os.path.join(d, "sentencepiece.model"))
        self.sp = sp
        self.tr = ctranslate2.Translator(
            os.path.join(d, "model"),
            device="cpu",
            compute_type="int8",
            inter_threads=2,
            intra_threads=max(1, (os.cpu_count() or 2) // 2),
        )

    def translate(self, text):
        self.load()
        groups = layout(text)
        if not groups:
            return ""
        results = self.tr.translate_batch(
            [self.sp.encode(p, out_type=str) for g in groups for p in g],
            beam_size=4,
            max_batch_size=8,
            max_decoding_length=512,
        )
        done = iter(self.sp.decode(r.hypotheses[0]) for r in results)
        return "\n".join(" ".join(next(done) for _ in g) for g in groups).strip()


def _run(argv, cwd=None):
    print("\n$ " + " ".join(argv), flush=True)
    return subprocess.call(argv, cwd=cwd)


def install_deps():
    """Install the Arch packages that provide ctranslate2 + sentencepiece.

    Each dependency is handled on its own, so a partial install only rebuilds
    what is actually missing.

    python-ctranslate2-bin lists python-pytorch as a dependency, but the
    library never imports torch for inference; left alone it would pull ~2.5GB
    of oneapi-MKL and qt6 for nothing, so the PKGBUILD is patched first.
    """
    if have_deps():
        print("Engine already installed.")
        return 0

    helper = shutil.which("paru") or shutil.which("yay")
    if not helper:
        print("ERROR: paru or yay is required to build the AUR packages", file=sys.stderr)
        return 1

    if not _have("sentencepiece"):
        if _run([helper, "-S", "--noconfirm", "--needed", PKG_SP]) != 0:
            return 1
    if not _have("ctranslate2"):
        # makepkg shells out to `python -m installer`, which ships in python-installer.
        if _run(["sudo", "pacman", "-S", "--needed", "--noconfirm", "python-installer"]) != 0:
            return 1
        if not _install_ctranslate2(helper):
            return 1

    if not have_deps():
        missing = [m for m in ("ctranslate2", "sentencepiece") if not _have(m)]
        print("\nERROR: still not importable: %s" % ", ".join(missing), file=sys.stderr)
        print("       expected these to be present in /usr/lib/python3.14/site-packages", file=sys.stderr)
        return 1
    print("\nEngine installed.")
    return 0


def _install_ctranslate2(helper):
    work = tempfile.mkdtemp(prefix="qs-translate-deps-")
    try:
        src = os.path.join(work, PKG_CT2)
        if _run(["git", "clone", "--depth", "1", AUR_CT2, src]) != 0:
            return False
        pk = os.path.join(src, "PKGBUILD")
        with open(pk) as fh:
            text = fh.read()
        patched = text.replace("'python-pytorch' ", "").replace(" 'python-pytorch'", "")
        if patched == text:
            print("\nPKGBUILD no longer lists python-pytorch; nothing to patch.", flush=True)
        else:
            with open(pk, "w") as fh:
                fh.write(patched)
            print("\nPatched PKGBUILD: dropped the unused python-pytorch dependency.", flush=True)
        return _run(["makepkg", "-si", "--noconfirm"], cwd=src) == 0
    finally:
        shutil.rmtree(work, ignore_errors=True)


def fetch(url, timeout=120):
    req = urllib.request.Request(url, headers={"User-Agent": "quickshell-launcher"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def install(verbose=True):
    root = model_root()
    if verbose:
        print("Translation models -> %s" % root)
    todo = [lang for lang in (AR, EN) if not have_pair(lang)]
    if not todo:
        if verbose:
            print("Both directions already installed.")
        return 0

    for lang in todo:
        dirname, archive = PAIRS[lang]
        url = "%s/%s" % (BASE_URL, archive)
        if verbose:
            print("  fetching %s" % archive)
        try:
            blob = fetch(url)
        except Exception as exc:  # network/DNS/TLS
            print("ERROR: download failed for %s: %s" % (archive, exc), file=sys.stderr)
            return 1

        # Unpack beside the target, then swap in, so a failed run never leaves
        # a half-written model directory behind.
        os.makedirs(root, exist_ok=True)
        target = os.path.join(root, dirname)
        staging = tempfile.mkdtemp(prefix=".%s-" % dirname, dir=root)
        try:
            with zipfile.ZipFile(io.BytesIO(blob)) as zf:
                names = set(zf.namelist())
                for member in WANTED:
                    # Archives nest everything under "<dirname>/".
                    match = [n for n in names if n.endswith("/" + member) or n == member]
                    if not match:
                        print("ERROR: %s missing from archive" % member, file=sys.stderr)
                        return 1
                    dest = os.path.join(staging, member)
                    os.makedirs(os.path.dirname(dest), exist_ok=True)
                    with open(dest, "wb") as fh:
                        fh.write(zf.read(match[0]))
            shutil.rmtree(target, ignore_errors=True)
            os.replace(staging, target)
            staging = None
            # mkdtemp creates 0700; the models are plain data, keep them readable.
            os.chmod(target, 0o755)
        finally:
            if staging is not None:
                shutil.rmtree(staging, ignore_errors=True)

        if verbose:
            size = os.path.getsize(os.path.join(target, "model", "model.bin")) / 1e6
            print("  installed %s (%.0f MB)" % (dirname, size))

    if verbose:
        print("Done. Reopen the launcher to use @translate.")
    return 0


def main(argv):
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--install", action="store_true")
    ap.add_argument("--install-deps", dest="install_deps", action="store_true")
    ap.add_argument("--from", dest="src", choices=[AR, EN])
    ap.add_argument("--to", dest="tgt", choices=[AR, EN])
    ap.add_argument("text", nargs="*")
    args = ap.parse_args(argv)

    if args.install_deps:
        return install_deps()

    if args.install:
        return install()

    if args.check:
        v = verdict()
        print(v)
        return 0 if v == OK else EXIT_NOMODELS

    text = " ".join(args.text).strip()
    if not text:
        return 0
    if not args.src or not args.tgt:
        print("--from and --to are required", file=sys.stderr)
        return 2
    if not have_deps():
        print("ERROR: ctranslate2 and sentencepiece are required. Run: %s --install-deps" % sys.argv[0], file=sys.stderr)
        return EXIT_NOMODELS
    if not have_pair(args.src):
        print("ERROR: %s model is not installed" % args.src, file=sys.stderr)
        return EXIT_NOMODELS

    try:
        out = Engine(args.src).translate(text)
    except Exception as exc:
        print("ERROR: %s" % exc, file=sys.stderr)
        return 1

    if not out:
        return 1
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
