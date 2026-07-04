# ChatGPT生成のパーツ画像から背景を抜いて、パーツごとの透過PNGに切り出す
# 使い方: python3 tools/extract_parts.py <元画像> <出力ディレクトリ>
import sys
from collections import deque

from PIL import Image

src_path, out_dir = sys.argv[1], sys.argv[2]
img = Image.open(src_path).convert("RGB")
W, H = img.size
px = img.load()

# 背景は滑らかなグラデーションなので、縁からの
# 「隣接ピクセルとの色差が小さい範囲」をfloodfillで背景と判定する。
# パーツは濃い輪郭線で囲まれているため、そこで伝播が止まる。
TOL = 10  # 隣接色差の許容量(チャンネルごと)

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

# 背景マスクを2px膨張させて、ぼかしのフリンジ(にじみ)を食う
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

# 前景の連結成分を拾う
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

# ノイズ除去: 小さすぎる成分は捨てる
comps = [c for c in comps if len(c) > 2000]
print(f"components: {len(comps)}")

# 位置とサイズでパーツ名を決める
infos = []
for cells in comps:
    xs = [p[0] for p in cells]; ys = [p[1] for p in cells]
    infos.append({
        "cells": cells,
        "cx": sum(xs) / len(xs), "cy": sum(ys) / len(ys),
        "box": (min(xs), min(ys), max(xs), max(ys)),
        "n": len(cells),
    })

for inf in infos:
    print(f"  size={inf['n']:7d} center=({inf['cx']:.0f},{inf['cy']:.0f}) box={inf['box']}")

# 命名: 上段左=head 上段右=body、中段左2つ=arm、下段左2つ=foot、右下=tail
named = {}
by_size = sorted(infos, key=lambda i: -i["n"])
top = sorted([i for i in infos if i["cy"] < H * 0.45], key=lambda i: i["cx"])
named["head"], named["body"] = top[0], top[1]
rest = [i for i in infos if i not in top]
tail = max(rest, key=lambda i: i["n"])
named["tail"] = tail
rest = [i for i in rest if i is not tail]
rest_sorted = sorted(rest, key=lambda i: i["cy"])
arms = sorted(rest_sorted[:2], key=lambda i: i["cx"])
feet = sorted(rest_sorted[2:], key=lambda i: i["cx"])
named["arm_l"], named["arm_r"] = arms[0], arms[1]
named["foot_l"], named["foot_r"] = feet[0], feet[1]

import os
os.makedirs(out_dir, exist_ok=True)
rgba = img.convert("RGBA")
for name, inf in named.items():
    x0, y0, x1, y1 = inf["box"]
    pad = 2
    x0, y0 = max(0, x0 - pad), max(0, y0 - pad)
    x1, y1 = min(W - 1, x1 + pad), min(H - 1, y1 + pad)
    w, h = x1 - x0 + 1, y1 - y0 + 1
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    op = out.load()
    for (x, y) in inf["cells"]:
        op[x - x0, y - y0] = rgba.getpixel((x, y))
    out.save(os.path.join(out_dir, f"{name}.png"))
    print(f"{name}.png {w}x{h}")
