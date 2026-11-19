"""Build the game's art/ folder from the unpacked asset packs.

The packs are bought art, so art/ is git-ignored. Run:
    python tools/prepare_art.py <folder with the unpacked packs> [<project folder>]
Needs Pillow (pip install pillow).
"""
import glob, os, re, sys
from PIL import Image

SRC = sys.argv[1]
OUT = os.path.join(sys.argv[2] if len(sys.argv) > 2 else os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "art")

# Every ship pack with top-down sprites. In these packs dir7 is nose-right,
# which is Godot's forward (+X). Saved as art/ships/<pack name, lowercase>.png.
SHIPS = sorted(d for d in os.listdir(SRC) if glob.glob(os.path.join(SRC, d, "1024", "*", "*dir7.png")))

# Animated stations: art/stations/<key>/NN.png
STATIONS = {"rim": "Arcadian Rim/512/Isometric", "hub": "Space hub/512/Top", "depot": "Space Station/512/Front view",
            "loop": "Space loop city/512", "dyson": "Dyson Sphere/512/Top"}


def frame_no(p):
    m = re.findall(r"(\d+)", os.path.basename(p))
    return int(m[-1]) if m else 0


def ok(p):
    try:
        Image.open(p).load()
        return True
    except Exception:
        print("  skipping unreadable", p)
        return False


def save(im, path, size):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im = im.convert("RGBA")
    if size and im.width != size:
        im = im.resize((size, size), Image.LANCZOS)
    im.save(path, optimize=True)


for pack in SHIPS:
    key = pack.lower().replace(" ", "_").replace("-", "_")
    f = [p for p in glob.glob(os.path.join(SRC, pack, "1024", "*", "*_dir7.png")) if "op" in os.path.basename(os.path.dirname(p))]
    if f and ok(f[0]):
        save(Image.open(f[0]), os.path.join(OUT, "ships", key + ".png"), 256)
        print("ship", key)

for p in sorted(glob.glob(os.path.join(SRC, "Planets", "*"))):
    if not os.path.isdir(p):
        continue
    name = os.path.basename(p).lower()
    frames = glob.glob(os.path.join(p, "512", "**", "*.png"), recursive=True)
    front = [f for f in frames if "Front" in f]
    frames = sorted(front or frames, key=frame_no)
    frames = [f for f in frames if ok(f)]
    for i, f in enumerate(frames):
        save(Image.open(f), os.path.join(OUT, "planets", name, "%02d.png" % i), 512)
    print("planet", name, len(frames))

for key, sub in STATIONS.items():
    frames = sorted(glob.glob(os.path.join(SRC, sub, "*.png")), key=frame_no)
    frames = [f for f in frames if ok(f)]
    for i, f in enumerate(frames):
        save(Image.open(f), os.path.join(OUT, "stations", key, "%02d.png" % i), 320)
    print("station", key, len(frames))

gate = os.path.join(SRC, "Stargate", "512", "stargate_Front.png")
if not os.path.exists(gate):
    gate = os.path.join(SRC, "Stargate", "1024", "stargate_Front.png")
save(Image.open(gate), os.path.join(OUT, "gate.png"), 384)

for i, f in enumerate(sorted(glob.glob(os.path.join(SRC, "Asteroids", "512", "*.png")), key=frame_no)):
    if ok(f):
        save(Image.open(f), os.path.join(OUT, "asteroids", "%02d.png" % i), 96)
print("done ->", OUT)
