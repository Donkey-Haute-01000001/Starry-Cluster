"""Render a MagicaVoxel .vox model to a top-down pixel sprite (nose to the right).

Each column shows its topmost voxel, shaded by height with a light from the
upper left and a dark outline, so voxel ships sit with the 2D sprite packs.
Usage: python3 vox_to_sprite.py in.vox out.png [--scale N] [--rot K]
"""
import struct, sys
from PIL import Image


def read_vox(path):
    data = open(path, "rb").read()
    assert data[:4] == b"VOX ", "not a vox file"
    pos = 8
    size = None
    voxels = []
    pal = None

    def chunks(pos, end):
        while pos < end:
            cid, n, m = struct.unpack_from("<4sii", data, pos)
            yield cid, pos + 12, n, m
            pos += 12 + n + m
    # MAIN chunk holds the rest as children.
    cid, n, m = struct.unpack_from("<4sii", data, pos)
    for cid, p, n, m in chunks(pos + 12 + n, pos + 12 + n + m):
        if cid == b"SIZE" and size is None:
            size = struct.unpack_from("<3i", data, p)
        elif cid == b"XYZI" and not voxels:
            k = struct.unpack_from("<i", data, p)[0]
            for i in range(k):
                voxels.append(struct.unpack_from("<4B", data, p + 4 + i * 4))
        elif cid == b"RGBA":
            pal = [struct.unpack_from("<4B", data, p + i * 4) for i in range(256)]
    if pal is None:
        pal = [(255, 255, 255, 255)] * 256
    return size, voxels, pal


def render(path, out, scale=4, rot=0):
    (sx, sy, sz), voxels, pal = read_vox(path)
    top = {}
    for x, y, z, c in voxels:
        if (x, y) not in top or z > top[(x, y)][0]:
            top[(x, y)] = (z, c)
    W, H = sx, sy
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    for (x, y), (z, c) in top.items():
        r, g, b, a = pal[(c - 1) % 256]
        h = z / max(sz - 1, 1)
        # Height light, plus a bevel: brighter if the neighbour to the upper
        # left is lower, darker if the lower right one is.
        k = 0.62 + 0.45 * h
        ul = top.get((x - 1, y + 1))
        lr = top.get((x + 1, y - 1))
        if ul is None or ul[0] < z:
            k += 0.12
        if lr is None or lr[0] < z:
            k -= 0.14
        px[x, H - 1 - y] = (min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k)), 255)
    # Dark outline.
    o = img.copy()
    op = o.load()
    for y in range(H):
        for x in range(W):
            if px[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < W and 0 <= ny < H and px[nx, ny][3]:
                        op[x, y] = (12, 12, 18, 255)
                        break
    img = o
    if rot:
        img = img.rotate(90 * rot, expand=True)
    bb = img.getbbox()
    img = img.crop(bb)
    w, h = img.size
    img = img.resize((w * scale, h * scale), Image.NEAREST)
    side = max(img.size) + 8
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(img, ((side - img.size[0]) // 2, (side - img.size[1]) // 2))
    canvas.save(out)
    return (sx, sy, sz), len(voxels)


if __name__ == "__main__":
    a = sys.argv
    scale = int(a[a.index("--scale") + 1]) if "--scale" in a else 4
    rot = int(a[a.index("--rot") + 1]) if "--rot" in a else 0
    print(render(a[1], a[2], scale, rot))
