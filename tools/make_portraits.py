"""Hand-built pixel portraits for the cast, written as code so they're ours.

Each portrait is a 40x50 pixel head-and-shoulders on a flat ID-photo wall,
lit from the top left. Run: python tools/make_portraits.py [project]
Writes portraits/<name>.png (1x) and portraits/_sheet.png (preview, 4x).
"""
import sys, pathlib
from PIL import Image

W, H = 40, 50
out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".") / "portraits"
out.mkdir(exist_ok=True)


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c[:3]) + (255,)


class P:
    def __init__(self, wall):
        self.im = Image.new("RGBA", (W, H), hexc(wall))
        self.px = self.im.load()
        # A soft vertical gradient on the wall, darker at the bottom.
        for y in range(H):
            for x in range(W):
                self.px[x, y] = shade(self.px[x, y], 1.06 - 0.16 * y / H)
        self.wall = self.im.copy()

    def put(self, x, y, c):
        if 0 <= x < W and 0 <= y < H:
            self.px[x, y] = c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def ellipse(self, cx, cy, rx, ry, c, test=None):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                if dx * dx + dy * dy <= 1.0 and (test is None or test(x, y)):
                    self.put(x, y, c)

    def get(self, x, y):
        return self.px[x, y]


# --- Body parts ------------------------------------------------------------------

def shoulders(p, c, collar=None, width=17, top=37):
    """Shoulders and chest: a wide rounded block to the bottom edge."""
    cx = W / 2
    for y in range(top, H):
        half = width - max(0, (top + 4 - y)) * 1.6
        for x in range(int(cx - half), int(cx + half)):
            lit = 1.08 if x < cx - half * 0.4 else (0.82 if x > cx + half * 0.45 else 1.0)
            p.put(x, y, shade(c, lit))
    if collar:
        for i in range(5):
            p.put(int(cx) - 5 + i, top + 1 + i, collar)
            p.put(int(cx) + 4 - i, top + 1 + i, collar)
            p.put(int(cx) - 6 + i, top + 1 + i, shade(collar, 0.85))
            p.put(int(cx) + 5 - i, top + 1 + i, shade(collar, 0.85))


def neck(p, skin, top=30, bottom=39, w=4):
    cx = W // 2
    p.rect(cx - w, top, cx + w - 1, bottom, shade(skin, 0.86))
    p.rect(cx - w, top, cx - w + 1, bottom, shade(skin, 0.95))
    p.rect(cx - w, top, cx + w - 1, top + 1, shade(skin, 0.72))  # chin shadow


def head(p, skin, cx=20, cy=22, rx=8.0, ry=10.0, jaw=1.0):
    rx, ry = rx * 1.08, ry * 1.06
    """Head with a narrower jaw, lit from the top left."""
    def inside(x, y):
        dy = (y + 0.5 - cy) / ry
        r = rx * (1.0 - max(0.0, dy) * 0.28 * jaw)
        dx = (x + 0.5 - cx) / r
        return dx * dx + dy * dy <= 1.0
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if not inside(x, y):
                continue
            c = skin
            if x >= cx + rx * 0.45:
                c = shade(skin, 0.82)
            elif x <= cx - rx * 0.55 and y < cy + 2:
                c = shade(skin, 1.07)
            if y >= cy + ry * 0.72:
                c = shade(c, 0.9)
            p.put(x, y, c)
    # Ears: one pixel past the cheek on each side, found by walking outward.
    base = p.wall.load()
    for s_ in (-1, 1):
        x = cx
        while 0 < x < W - 1 and p.get(int(x + s_), int(cy) + 1) != base[int(x + s_), int(cy) + 1]:
            x += s_
        ex = int(x + s_)
        p.rect(ex, int(cy), ex, int(cy) + 3, shade(skin, 0.92 if s_ < 0 else 0.72))


def face(p, skin, eyes="#1c1410", brow=None, mouth="smile", cx=20, cy=22, nose=True, white=True):
    e = hexc(eyes)
    brow = hexc(brow) if brow else shade(e, 1.2)
    ey = cy + 0
    for s, x in ((-1, cx - 4), (1, cx + 2)):
        if white:
            p.put(x, ey, (235, 230, 220, 255))
        p.put(x + 1, ey, e)
        p.put(x, ey + 1, shade(skin, 0.8))
        p.put(x + 1, ey + 1, shade(skin, 0.8))
        p.rect(x - (1 if s < 0 else 0), ey - 2, x + 1 + (0 if s < 0 else 1), ey - 2, brow)
    if nose:
        p.put(cx, ey + 2, shade(skin, 0.85))
        p.put(cx, ey + 3, shade(skin, 0.85))
        p.put(cx - 1, ey + 4, shade(skin, 0.75))
        p.put(cx + 1, ey + 4, shade(skin, 0.7))
    my = ey + 6
    lip = shade(skin, 0.62)
    if mouth == "smile":
        p.rect(cx - 2, my, cx + 2, my, lip)
        p.put(cx - 3, my - 1, lip)
        p.put(cx + 3, my - 1, lip)
        p.rect(cx - 1, my + 1, cx + 1, my + 1, shade(skin, 0.88))
    elif mouth == "grin":
        p.rect(cx - 3, my - 1, cx + 3, my - 1, lip)
        p.rect(cx - 2, my, cx + 2, my, (240, 236, 228, 255))
        p.rect(cx - 2, my + 1, cx + 2, my + 1, lip)
    elif mouth == "flat":
        p.rect(cx - 2, my, cx + 2, my, lip)
    elif mouth == "smirk":
        p.rect(cx - 2, my, cx + 1, my, lip)
        p.put(cx + 2, my - 1, lip)


def hair_short(p, c, cx=20, top=12, rx=8.6, fade=False):
    """Close crop over the top of the head."""
    for y in range(top, top + 7):
        for x in range(int(cx - rx), int(cx + rx) + 1):
            dx = (x + 0.5 - cx) / rx
            dy = (y + 0.5 - (top + 7)) / 7.5
            if dx * dx + dy * dy <= 1.0:
                lit = 1.25 if x < cx - 2 and y < top + 3 else 1.0
                p.put(x, y, shade(hexc(c), lit))
    if fade:
        for y in range(top + 5, top + 12):
            for s in (-1, 1):
                x = int(cx + s * (rx - 0.5)) - (1 if s < 0 else 0)
                if (x + y) % 2 == 0:
                    p.put(x, y, hexc(c))


def hair_side(p, c, cx=20, top=12, length=10, rx=9):
    """Hair falling past the ears on both sides (behind the face edges)."""
    col = hexc(c)
    for y in range(top + 4, top + 4 + length):
        for s in (-1, 1):
            for k in range(2):
                p.put(int(cx + s * (rx - k)) - (1 if s < 0 else 0), y, shade(col, 0.9 if s > 0 else 1.05))


def beard(p, c, cx=20, cy=22, full=True, stubble=False):
    col = hexc(c)
    for y in range(cy + 3, cy + 10):
        for x in range(cx - 8, cx + 9):
            if p.get(x, y)[:3] == (0, 0, 0):
                continue
            r = abs(x + 0.5 - cx) / 8.0 + max(0, y - (cy + 7)) * 0.25
            if r > 1.0:
                continue
            if y == cy + 6 and abs(x - cx) <= 2 and full:
                continue  # mouth line shows through
            if stubble and ((x + y) % 2 or y < cy + 4):
                continue
            if stubble:
                p.put(x, y, shade(p.get(x, y), 0.8))
            else:
                p.put(x, y, shade(col, 0.85 if x > cx + 3 else 1.0))


def headset(p, c="#2a2d33", cx=20, cy=22, mic=True):
    col = hexc(c)
    for x in range(cx - 9, cx + 10):
        dx = (x + 0.5 - cx) / 9.5
        y = int(cy - 9.5 * (1 - dx * dx) ** 0.5) - 1
        p.put(x, y, col)
    p.rect(cx - 10, cy - 1, cx - 9, cy + 3, col)
    p.rect(cx + 9, cy - 1, cx + 10, cy + 3, col)
    if mic:
        for i in range(6):
            p.put(cx - 9 + i, cy + 4 + i // 2, col)
        p.put(cx - 3, cy + 7, shade(col, 1.6))


def cap(p, c, cx=20, top=10, badge=None):
    col = hexc(c)
    p.rect(cx - 9, top + 2, cx + 9, top + 6, col)
    p.rect(cx - 8, top, cx + 8, top + 1, shade(col, 1.1))
    p.rect(cx - 10, top + 7, cx + 6, top + 8, shade(col, 0.6))  # peak
    if badge:
        p.rect(cx - 1, top + 3, cx + 1, top + 4, hexc(badge))


def outline(p):
    """Darken the figure's edge where it meets the wall: crisp pixel-art silhouettes."""
    wall = P.__new__(P)
    src = p.im.copy()
    px = src.load()
    base = p.wall.load()
    for y in range(H):
        for x in range(W):
            if px[x, y] == base[x, y]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < H and px[nx, ny] == base[nx, ny]:
                    p.px[x, y] = shade(px[x, y], 0.62)
                    break


def save(p, name):
    outline(p)
    p.im.save(out / f"{name}.png")
    return p.im


faces = {}

# Dez: warm, earnest, flight jacket and headset. Low fade, easy grin.
p = P("#8a979c")
skin = hexc("#6b4430")
shoulders(p, hexc("#4d5233"), collar=hexc("#6a6f45"))
p.rect(19, 41, 20, 49, hexc("#2d2f22"))  # jacket zip
neck(p, skin)
head(p, skin, rx=8.2, ry=10.2)
hair_short(p, "#16110e", top=11, fade=True)
face(p, skin, eyes="#1a110c", brow="#16110e", mouth="grin")
headset(p)
faces["Dez"] = save(p, "dez")

# Charlie: dispatcher, auburn bun, headset, Charter blue with a lanyard.
p = P("#9aa3a8")
skin = hexc("#e6c2a6")
shoulders(p, hexc("#3b6a96"), collar=hexc("#e9eef2"), width=15)
for y in range(41, 50):
    p.put(16 + (y - 41) // 3, y, hexc("#d24b3a"))  # lanyard
neck(p, skin, w=3)
p.ellipse(20, 10, 4, 3, hexc("#8c3f1f"))  # bun
hair_side(p, "#8c3f1f", length=8, rx=9)
head(p, skin, rx=7.6, ry=9.8)
hair_short(p, "#a04a24", top=11)
for x in (13, 14, 26):
    p.put(x, 19, hexc("#a04a24"))  # loose strands
face(p, skin, eyes="#3b5b40", brow="#7a3a1c", mouth="smile")
headset(p, "#1f2a36")
faces["Charlie"] = save(p, "charlie")

# Lt. Franz Kessler: young, fair, neat blond, navy blues with gold pips.
p = P("#7d8b99")
skin = hexc("#efd2bb")
shoulders(p, hexc("#1f2f4f"), collar=hexc("#2a3e66"))
p.rect(10, 40, 12, 41, hexc("#d8b04a"))
p.rect(27, 40, 29, 41, hexc("#d8b04a"))
neck(p, skin)
head(p, skin, rx=7.8, ry=10.0)
hair_short(p, "#d9b25e", top=11)
p.rect(14, 13, 18, 13, hexc("#f0cf7f"))  # side part highlight
face(p, skin, eyes="#3a6ea8", brow="#b08a40", mouth="flat")
faces["Franz"] = save(p, "franz")

# The Tallyman: weathered ex-trucker, grey stubble, hair tied back, tally marks
# scratched under his left eye. Worn brown work jacket.
p = P("#7a6f68")
skin = hexc("#b98a66")
shoulders(p, hexc("#5a3f2a"), collar=hexc("#3f2c1e"), width=18)
p.rect(12, 44, 15, 46, hexc("#7a5a3d"))  # patch
neck(p, skin, w=4)
head(p, skin, rx=8.4, ry=10.0, jaw=0.7)
hair_short(p, "#8d8a85", top=12, rx=8.8)
p.rect(12, 14, 13, 18, hexc("#8d8a85"))
beard(p, "#7f7a74", stubble=True)
face(p, skin, eyes="#2b241f", brow="#6d6a66", mouth="smirk")
for i in range(4):
    p.put(22 + i * 2, 25, hexc("#e0b394"))  # four marks scratched under the eye
    p.put(22 + i * 2, 26, hexc("#e0b394"))
for i in range(7):
    p.put(21 + i, 27 - i // 2, hexc("#8a5a40"))  # and the slash through them
p.rect(13, 20, 18, 20, hexc("#5a4a3e"))  # creased brow
faces["Tallyman"] = save(p, "tallyman")

# Fay: young, messy dark crop, freckles, goggles up, orange dock coveralls.
p = P("#8f9aa1")
skin = hexc("#d6a988")
shoulders(p, hexc("#c76a2a"), collar=hexc("#a8561f"), width=15)
p.rect(14, 43, 25, 43, hexc("#3a3a3a"))  # strap
neck(p, skin, w=3)
head(p, skin, rx=7.4, ry=9.6)
hair_short(p, "#2a1d16", top=11, rx=8.4)
for x, y in ((12, 17), (13, 19), (27, 18), (26, 20), (15, 15), (24, 14)):
    p.put(x, y, hexc("#2a1d16"))  # messy ends
p.rect(13, 14, 27, 15, hexc("#444b52"))  # goggle strap
p.rect(14, 13, 18, 16, hexc("#7fb7c9"))
p.rect(22, 13, 26, 16, hexc("#7fb7c9"))
p.put(15, 14, (230, 245, 250, 255))
p.put(23, 14, (230, 245, 250, 255))
face(p, skin, eyes="#4a3324", brow="#2a1d16", mouth="grin")
for x, y in ((15, 25), (17, 26), (23, 25), (25, 26), (16, 24)):
    p.put(x, y, shade(skin, 0.78))  # freckles
p.rect(24, 28, 25, 28, hexc("#3a3330"))  # grease smudge
faces["Fay"] = save(p, "fay")

# Mersham Ali of Clan Karabey: steady dad energy, trimmed black beard going
# grey, maroon flight jacket with the clan's gold-trimmed collar.
p = P("#857a74")
skin = hexc("#a7744f")
shoulders(p, hexc("#6a1f22"), collar=hexc("#c9a24a"), width=18)
p.rect(11, 42, 13, 44, hexc("#c9a24a"))  # clan crest
neck(p, skin, w=4)
head(p, skin, rx=8.4, ry=10.2, jaw=0.8)
hair_short(p, "#191512", top=11, rx=8.8)
beard(p, "#1d1915")
for x, y in ((13, 27), (26, 27)):
    p.put(x, y, hexc("#6e6a66"))  # grey at the edges of the beard
face(p, skin, eyes="#21170f", brow="#191512", mouth="flat")
p.rect(15, 23, 16, 23, shade(skin, 0.75))  # crow's feet
p.rect(24, 23, 25, 23, shade(skin, 0.7))
faces["Mersham"] = save(p, "mersham")

# Gate customs: peaked cap, grey uniform, nothing personal.
p = P("#a2a6a9")
skin = hexc("#d8b293")
shoulders(p, hexc("#4c545c"), collar=hexc("#646e78"))
neck(p, skin)
head(p, skin, rx=7.8, ry=9.8)
cap(p, "#3d4650", top=9, badge="#d8b04a")
face(p, skin, eyes="#2d2a26", mouth="flat")
faces["Gate customs"] = save(p, "customs")

# Dock crew: hard hat and hi-vis, a day's stubble.
p = P("#8e9396")
skin = hexc("#c4916d")
shoulders(p, hexc("#d9c63a"), collar=hexc("#9a9a9a"))
p.rect(8, 44, 31, 45, hexc("#e8e8e0"))  # reflective band
neck(p, skin)
head(p, skin, rx=8.2, ry=9.8)
p.ellipse(20, 13, 9.5, 5, hexc("#e0a12a"))
p.rect(10, 15, 30, 16, hexc("#b57f1c"))
beard(p, "#4a3a2e", stubble=True)
face(p, skin, eyes="#2a221c", mouth="smile")
faces["Dock crew"] = save(p, "dock_crew")

# Contact sheet for review.
sheet = Image.new("RGBA", (W * 4 * len(faces) + 8 * (len(faces) + 1), H * 4 + 16), (30, 34, 40, 255))
for i, (n, im) in enumerate(faces.items()):
    sheet.paste(im.resize((W * 4, H * 4), Image.NEAREST), (8 + i * (W * 4 + 8), 8))
sheet.save(out / "_sheet.png")
print("wrote", len(faces), "portraits")
