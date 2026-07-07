# 寝転びぽんぽこ仕様書シート（2026-07-08、ドット絵版）から
# 「完成イメージ」の1枚絵だけを切り出して assets/images/ponta_macho/pose_lie.png に保存する。
# パーツ合成は過去に3回失敗しているため（MEMORY参照）、完成絵をそのまま使う方針。
#   python3 tools/extract_lie.py <sheet.png> [out_dir]
import os
import sys
from collections import deque

from PIL import Image

SRC = sys.argv[1]
OUT_DIR = sys.argv[2] if len(sys.argv) > 2 else os.path.join(
    os.path.dirname(__file__), "..", "assets", "images", "ponta_macho")

# 完成イメージのボックス（1536x1024前提、周囲に少し余白を持たせた値）
BOX = (50, 60, 460, 435)


def is_checker(c):
    mx, mn = max(c), min(c)
    return mx - mn < 25 and mx > 175


def is_darkish(c):
    return max(c) < 120


img = Image.open(SRC).convert("RGB")
W, H = img.size
px = img.load()

bg = bytearray(W * H)
q = deque()
for x in range(W):
    for y in (0, H - 1):
        if is_checker(px[x, y]) and not bg[y * W + x]:
            bg[y * W + x] = 1
            q.append((x, y))
for y in range(H):
    for x in (0, W - 1):
        if is_checker(px[x, y]) and not bg[y * W + x]:
            bg[y * W + x] = 1
            q.append((x, y))
while q:
    x, y = q.popleft()
    for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
        if 0 <= nx < W and 0 <= ny < H and not bg[ny * W + nx]:
            if is_checker(px[nx, ny]):
                bg[ny * W + nx] = 1
                q.append((nx, ny))
for _ in range(2):
    grow = []
    for y in range(H):
        base = y * W
        for x in range(W):
            if not bg[base + x]:
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < W and 0 <= ny < H and bg[ny * W + nx]:
                        grow.append((x, y))
                        break
    for x, y in grow:
        bg[y * W + x] = 1

x1, y1, x2, y2 = BOX
bw, bh = x2 - x1, y2 - y1
seen = bytearray(bw * bh)
keep = bytearray(bw * bh)
for sy in range(bh):
    for sx in range(bw):
        i = sy * bw + sx
        gx, gy = x1 + sx, y1 + sy
        if seen[i] or bg[gy * W + gx]:
            continue
        comp = []
        dark = 0
        stack = [(sx, sy)]
        seen[i] = 1
        while stack:
            cx, cy = stack.pop()
            comp.append((cx, cy))
            c = px[x1 + cx, y1 + cy]
            if is_darkish(c):
                dark += 1
            for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                j = ny * bw + nx
                if 0 <= nx < bw and 0 <= ny < bh and not seen[j] \
                        and not bg[(y1 + ny) * W + (x1 + nx)]:
                    seen[j] = 1
                    stack.append((nx, ny))
        if len(comp) < 40 or dark / len(comp) > 0.7:
            continue
        for cx, cy in comp:
            keep[cy * bw + cx] = 1

out = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
opx = out.load()
minx, miny, maxx, maxy = bw, bh, -1, -1
for sy in range(bh):
    for sx in range(bw):
        if keep[sy * bw + sx]:
            r, g, b = px[x1 + sx, y1 + sy]
            opx[sx, sy] = (r, g, b, 255)
            minx, miny = min(minx, sx), min(miny, sy)
            maxx, maxy = max(maxx, sx), max(maxy, sy)

if maxx < 0:
    print("!! pose_lie: 前景なし（ボックス要調整）")
    sys.exit(1)

out = out.crop((minx, miny, maxx + 1, maxy + 1))
os.makedirs(OUT_DIR, exist_ok=True)
out_path = os.path.join(OUT_DIR, "pose_lie.png")
out.save(out_path)
print(f"pose_lie: {out.size[0]}x{out.size[1]} -> {out_path}")
