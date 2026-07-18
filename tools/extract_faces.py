# 表情シート（2026-07-18、ChatGPT生成、4x4・黒背景ピクセルアート）から
# 頭パーツだけを切り出して assets/images/ponta_faces/ に保存する。
# 体はponta_partsのまま、頭だけをこのシートに差し替える用途。
#   python3 tools/extract_faces.py <sheet.png> [out_dir]
#
# 単純な4等分だと耳の先などが隣の顔とわずかに接していて混入した
# （実データで確認済み、ユーザー指摘）。行の境界は完全な黒帯で綺麗に
# 割れるが、列の境界は行ごとに独立して「非黒画素が最も少ない列」を
# 境界として選び直すことで混入を最小化している
import os
import sys
from collections import deque

from PIL import Image

SRC = sys.argv[1]
OUT_DIR = sys.argv[2] if len(sys.argv) > 2 else os.path.join(
    os.path.dirname(__file__), "..", "assets", "images", "ponta_faces")

GRID_NAMES = [
    ["sad", "disappointed", "calm_closed", "wink_grin"],
    ["content_smile", "normal", "meh_tongue", "worried"],
    ["cry", "angry", "smug_tongue", "surprised_q"],
    ["heart", "relieved", "shock", "laugh_squint"],
]

BG_THRESHOLD = 30


def is_bg(c):
    return sum(c) < BG_THRESHOLD


img = Image.open(SRC).convert("RGB")
W, H = img.size
px = img.load()


def colsum_range(x, y1, y2):
    return sum(1 for y in range(y1, y2) if sum(px[x, y]) >= BG_THRESHOLD)


def rowsum(y):
    return sum(1 for x in range(W) if sum(px[x, y]) >= BG_THRESHOLD)


# 行境界: 画像全体で非黒画素が最少の行を4分割の理論値付近で探す
row_bounds = [0]
for k in (1, 2, 3):
    center = round(H * k / 4)
    window = range(max(0, center - 50), min(H, center + 50))
    row_bounds.append(min(window, key=rowsum))
row_bounds.append(H)

os.makedirs(OUT_DIR, exist_ok=True)

for row in range(4):
    y1, y2 = row_bounds[row], row_bounds[row + 1]

    # 列境界はこの行帯だけで独立に探す
    col_bounds = [0]
    for k in (1, 2, 3):
        center = round(W * k / 4)
        window = range(max(0, center - 50), min(W, center + 50))
        col_bounds.append(min(window, key=lambda x: colsum_range(x, y1, y2)))
    col_bounds.append(W)

    for col in range(4):
        name = GRID_NAMES[row][col]
        x1, x2 = col_bounds[col], col_bounds[col + 1]
        bw, bh = x2 - x1, y2 - y1

        bg = bytearray(bw * bh)
        q = deque()
        for x in range(bw):
            for y in (0, bh - 1):
                if is_bg(px[x1 + x, y1 + y]) and not bg[y * bw + x]:
                    bg[y * bw + x] = 1
                    q.append((x, y))
        for y in range(bh):
            for x in (0, bw - 1):
                if is_bg(px[x1 + x, y1 + y]) and not bg[y * bw + x]:
                    bg[y * bw + x] = 1
                    q.append((x, y))
        while q:
            x, y = q.popleft()
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < bw and 0 <= ny < bh and not bg[ny * bw + nx]:
                    if is_bg(px[x1 + nx, y1 + ny]):
                        bg[ny * bw + nx] = 1
                        q.append((nx, ny))

        out = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
        opx = out.load()
        minx, miny, maxx, maxy = bw, bh, -1, -1
        for y in range(bh):
            for x in range(bw):
                if not bg[y * bw + x]:
                    r, g, b = px[x1 + x, y1 + y]
                    opx[x, y] = (r, g, b, 255)
                    minx, miny = min(minx, x), min(miny, y)
                    maxx, maxy = max(maxx, x), max(maxy, y)
        if maxx < 0:
            print(f"!! {name}: 前景なし")
            continue
        out = out.crop((minx, miny, maxx + 1, maxy + 1))
        out.save(os.path.join(OUT_DIR, f"{name}.png"))
        print(f"{name}: {out.size[0]}x{out.size[1]}")
