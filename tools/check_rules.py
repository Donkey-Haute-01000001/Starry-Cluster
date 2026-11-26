"""Checks the locked rules in CLAUDE.md that code can break. Exits 1 on any break.
Run: python3 tools/check_rules.py   (also run by tools/run_tests.sh)
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCRIPTS = sorted((ROOT / "scripts").glob("*.gd"))
problems = []


def src(p):
    return p.read_text(encoding="utf-8")


# Sounds are real recordings: no generators, no radio static, no synth folder.
for p in (ROOT / "tools").glob("*.py"):
    t = src(p)
    if p.name != "check_rules.py" and "wave.open" in t and re.search(r"np\.sin|noise\(", t):
        problems.append(f"sound: {p.name} synthesizes audio (sounds must be recordings)")
for p in (ROOT / "sounds").rglob("*.wav"):
    if re.search(r"radio|static|synth|hiss", p.stem):
        problems.append(f"sound: {p.relative_to(ROOT)} looks like synth or radio static")
if re.search(r"synthesi[sz]ed", src(ROOT / "CREDITS.md"), re.I):
    problems.append("sound: CREDITS.md lists synthesized foley")

# Every sound a script plays must exist (missing ones fail silently in game).
names = {p.stem for p in (ROOT / "sounds").glob("*.wav")}
for p in SCRIPTS:
    for m in re.finditer(r'Sfx\.(?:play|stream)\("([a-z0-9_]+)"', src(p)):
        if m.group(1) not in names:
            problems.append(f"sound: {p.name} plays '{m.group(1)}' but sounds/{m.group(1)}.wav is missing")

# Fonts: only the locked families.
allowed = ("BigShoulders", "BigShouldersStencil", "CourierPrime", "NanumPenScript", "VT323")
for p in (ROOT / "fonts").glob("*.[ot]tf"):
    if not p.stem.startswith(allowed):
        problems.append(f"font: {p.name} is not a locked font")

# Say "opening" / "start", never "demo", in anything the player reads.
for p in SCRIPTS:
    for i, line in enumerate(src(p).splitlines(), 1):
        code = line.split("#", 1)[0]
        for s in re.findall(r'"([^"\\]*(?:\\.[^"\\]*)*)"', code):
            if re.search(r"\bdemo\b", s, re.I):
                problems.append(f"words: {p.name}:{i} says 'demo' on screen")

# Story flags: every flag read must be written somewhere (typos fail silently).
DYNAMIC = {"saved_names"}  # written through Career.remember(key, ...)
written, read = set(), {}
for p in SCRIPTS:
    t = src(p)
    written |= set(re.findall(r'flags\["([a-z0-9_]+)"\]\s*=(?!=)', t))
    for m in re.finditer(r'(?:flags\.get\(|_flag\(|flags\.has\()"([a-z0-9_]+)"', t):
        read.setdefault(m.group(1), p.name)
for k, where in sorted(read.items()):
    if k not in written and k not in DYNAMIC:
        problems.append(f"flag: '{k}' is read in {where} but never set (typo?)")

# Portraits (Vishnu 2026-11-26): every named speaker in a script gets a face.
# A literal say("Name", ...) / call_in(kind, "Name", ...) must be in PORTRAIT_FILES.
ui = src(ROOT / "scripts" / "ui_style.gd")
faces = set(re.findall(r'"([^"]+)":\s*"[a-z_]+"', ui[ui.find("PORTRAIT_FILES"):ui.find("}", ui.find("PORTRAIT_FILES"))]))
faces |= {"You"}
for p in SCRIPTS:
    for m in re.finditer(r'(?:\bsay\(|call_in\("[A-Z]+",\s*)"([A-Z][^"]*)"', src(p)):
        if m.group(1) not in faces:
            problems.append(f"portrait: {p.name} has '{m.group(1)}' speak with no portrait (add it to PORTRAIT_FILES)")

if problems:
    print("RULES: %d broken" % len(problems))
    for x in problems:
        print("  " + x)
    sys.exit(1)
print("RULES: ok (sounds, fonts, words, flags, portraits)")
