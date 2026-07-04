# チェッカー柄(疑似透過)背景のシートから頭＋汗マークを切り出す
# 背景 = 縁から連結した「明るい無彩色」ピクセル。ラベル文字は無彩色成分として除外
import sys
from collections import deque

from PIL import Image

src, out_path = sys.argv[1], sys.argv[2]
img = Image.open(src).convert("RGB")
W, H = img.size
px = img.load()


def is_checker(c):
    mx, mn = max(c), min(c)
    return mx - mn < 25 and mx > 175


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
    for nx, ny in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
        if 0 <= nx < W and 0 <= ny < H and not bg[ny * W + nx]:
            if is_checker(px[nx, ny]):
                bg[ny * W + nx] = 1
                q.append((nx, ny))

# フリンジを2px膨張で食う
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

# 前景成分
label = [0] * (W * H)
comps = []
for sy in range(H):
    for sx in range(W):
        i = sy * W + sx
        if bg[i] or label[i]:
            continue
        cells = []
        dq = deque([(sx, sy)])
        label[i] = 1
        while dq:
            x, y = dq.popleft()
            cells.append((x, y))
            for nx, ny in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
                if 0 <= nx < W and 0 <= ny < H:
                    j = ny * W + nx
                    if not bg[j] and not label[j]:
                        label[j] = 1
                        dq.append((nx, ny))
        comps.append(cells)

# 左上領域の、無彩色(ラベル文字)でない成分を採用
picked = []
for cells in comps:
    if len(cells) < 200:
        continue
    xs = [p[0] for p in cells]; ys = [p[1] for p in cells]
    cx, cy = sum(xs) / len(xs), sum(ys) / len(ys)
    if not (cx < W * 0.4 and cy < H * 0.5):
        continue
    rs = gs = bs = 0
    for (x, y) in cells:
        c = px[x, y]
        rs += c[0]; gs += c[1]; bs += c[2]
    n = len(cells)
    mean = (rs / n, gs / n, bs / n)
    if max(mean) - min(mean) < 12:  # グレー成分＝ラベル文字
        print(f"skip text size={n} center=({cx:.0f},{cy:.0f}) mean={mean}")
        continue
    picked.append(cells)
    print(f"pick size={n} center=({cx:.0f},{cy:.0f})")

cells = [p for c in picked for p in c]
xs = [p[0] for p in cells]; ys = [p[1] for p in cells]
x0, y0 = max(0, min(xs) - 2), max(0, min(ys) - 2)
x1, y1 = min(W - 1, max(xs) + 2), min(H - 1, max(ys) + 2)
w, h = x1 - x0 + 1, y1 - y0 + 1
out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
op = out.load()
rgba = img.convert("RGBA")
for (x, y) in cells:
    op[x - x0, y - y0] = rgba.getpixel((x, y))
out.save(out_path)
print(f"{out_path} {w}x{h}")
