"""Copy Foozle's Void fleet packs (CC0) into art/ships/<faction>/<hull>/.

Each hull gets base.png plus animation strips: engine.png, weapons.png,
shield.png, destruction.png (frames are square, one strip each).
Usage: python3 import_void_fleets.py <extracted packs dir> <art/ships dir>
"""
import glob, os, re, shutil, sys

LAYERS = {"Base": "base", "Designs - Base": "base", "Engine": "engine", "Engine Effects": "engine",
          "Shield": "shield", "Shields": "shield", "Weapons": "weapons", "Destruction": "destruction"}
FACTIONS = {"Kla'ed": "klaed", "Nairan": "nairan", "Nautolan": "nautolan"}

src, dst = sys.argv[1], sys.argv[2]
n = 0
for f in glob.glob(os.path.join(src, "**", "PNGs", "*.png"), recursive=True):
    if "_Previews" in f:
        continue
    layer_dir = os.path.basename(os.path.dirname(os.path.dirname(f)))
    layer = LAYERS.get(layer_dir)
    fac = next((v for k, v in FACTIONS.items() if os.sep + k + os.sep in f), None)
    if not layer or not fac:
        continue
    name = os.path.basename(f)[:-4]
    parts = [p.strip() for p in re.split(r"\s+-\s+", name) if p.strip()]
    if len(parts) < 2:
        continue
    hull = parts[1].lower().replace(" ", "_")
    out = os.path.join(dst, fac, hull)
    os.makedirs(out, exist_ok=True)
    shutil.copy(f, os.path.join(out, layer + ".png"))
    n += 1
print("copied", n)
