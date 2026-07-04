# 表情差分シートから頭パーツだけを背景抜きで切り出す
# （シートのレイアウトは extract_parts.py と同じ「左上=頭」前提。
#   汗マークなど頭の周りの小さい付随パーツも一緒に拾う）
# 使い方: python3 tools/extract_head.py <元画像> <出力PNG>
import os
import sys
from collections import deque

from PIL import Image

src_path, out_path = sys.argv[1], sys.argv[2]
img = Image.open(src_path).convert("RGB")
W, H = img.size
px = img.load()

# 背景判定は extract_parts.py と同じ縁からのfloodfill
TOL = 10

bg = bytearray(W * H)
q = deque()
for x in range(W):
    q.append((x, 0)); q.append((x, H - 1))
for y in range(H):
    q.append((0, y)); q.append((W - 1, y))
for x, y in q:
    bg[y * W + x] = 1

while q:
    x, y = q.popleft()
    c = px[x, y]
    for nx, ny in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
        if 0 <= nx < W and 0 <= ny < H and not bg[ny * W + nx]:
            n = px[nx, ny]
            if (abs(n[0]-c[0]) <= TOL and abs(n[1]-c[1]) <= TOL
                    and abs(n[2]-c[2]) <= TOL):
                bg[ny * W + nx] = 1
                q.append((nx, ny))

for _ in range(2):
    grow = []
    for y in range(H):
        for x in range(W):
            if not bg[y * W + x]:
                for nx, ny in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
                    if 0 <= nx < W and 0 <= ny < H and bg[ny * W + nx]:
                        grow.append((x, y)); break
    for x, y in grow:
        bg[y * W + x] = 1

# 前景の連結成分
label = [0] * (W * H)
comps = []
for sy in range(H):
    for sx in range(W):
        i = sy * W + sx
        if bg[i] or label[i]:
            continue
        cid = len(comps) + 1
        cells = []
        dq = deque([(sx, sy)])
        label[i] = cid
        while dq:
            x, y = dq.popleft()
            cells.append((x, y))
            for nx, ny in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
                if 0 <= nx < W and 0 <= ny < H:
                    j = ny * W + nx
                    if not bg[j] and not label[j]:
                        label[j] = cid
                        dq.append((nx, ny))
        comps.append(cells)

# 左上領域(頭)にある成分を全部まとめる。汗マーク等は小さいので閾値は低め
picked = []
for cells in comps:
    if len(cells) < 300:
        continue
    xs = [p[0] for p in cells]; ys = [p[1] for p in cells]
    cx, cy = sum(xs) / len(xs), sum(ys) / len(ys)
    if cx < W * 0.62 and cy < H * 0.5:
        picked.append(cells)
        print(f"pick size={len(cells)} center=({cx:.0f},{cy:.0f})")

if not picked:
    sys.exit("頭領域にパーツが見つからない")

cells = [p for c in picked for p in c]
xs = [p[0] for p in cells]; ys = [p[1] for p in cells]
x0, y0, x1, y1 = min(xs), min(ys), max(xs), max(ys)
pad = 2
x0, y0 = max(0, x0 - pad), max(0, y0 - pad)
x1, y1 = min(W - 1, x1 + pad), min(H - 1, y1 + pad)
w, h = x1 - x0 + 1, y1 - y0 + 1

rgba = img.convert("RGBA")
out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
op = out.load()
for (x, y) in cells:
    op[x - x0, y - y0] = rgba.getpixel((x, y))
os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
out.save(out_path)
print(f"{out_path} {w}x{h}")
