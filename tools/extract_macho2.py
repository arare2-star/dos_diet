# 新マッチョ仕様書シート（2026-07-06、ドット絵版）から
# パーツ・表情・エフェクト・持ち物を切り出して assets/images/ponta_macho/ に保存する。
#   python3 tools/extract_macho2.py <sheet.png> [out_dir]
# ロジックはtools/extract_macho.pyと同じ（チェッカー/白背景を縁から連結して除去し、
# 各ボックス内でラベル文字・装飾だけ捨てる）。座標だけ新シート用に採り直した。
import os
import sys
from collections import deque

from PIL import Image

SRC = sys.argv[1]
OUT_DIR = sys.argv[2] if len(sys.argv) > 2 else os.path.join(
    os.path.dirname(__file__), "..", "assets", "images", "ponta_macho")

# シート上の切り出しボックス (x1, y1, x2, y2)。1535x1024前提
PARTS = {
    # 本体パーツ（パーツ一覧）
    "head_smug":  (315, 100, 500, 325),
    "body":       (505, 100, 670, 330),
    "arm_r_down": (705, 160, 790, 345),
    "arm_r_flex": (820, 155, 975, 310),
    "head_arm_l": (980, 160, 1150, 345),
    "leg_l":      (1160, 170, 1245, 335),
    "leg_r":      (1265, 170, 1355, 335),
    "tail":       (1390, 185, 1510, 335),
    # 表情（頭のみ）
    "face_normal": (35, 470, 210, 615),
    "face_smug":   (240, 470, 415, 615),
    "face_panic":  (440, 470, 615, 615),
    "face_angry":  (644, 470, 835, 615),
    "face_plead":  (35, 645, 210, 800),
    # 眠いはZzz装飾（青系）を成分フィルタで除外して頭だけにする
    "face_sleepy": (215, 645, 415, 795),
    "face_cry":    (443, 645, 610, 795),
    # 驚きはフラッシュ込みで少し右に広め
    "face_shock":  (645, 645, 838, 795),
    # エフェクト
    "fx_sweat": (898, 470, 1052, 605),
    "fx_fire":  (1093, 465, 1247, 605),
    "fx_heart": (1278, 465, 1432, 605),
    "fx_meat":  (913, 645, 1052, 770),
    "fx_beer":  (1108, 645, 1227, 770),
    "fx_rice":  (1293, 645, 1420, 762),
    # 持ち物（腕込み）
    "item_dumbbell": (8, 893, 148, 1002),
    "item_protein":  (172, 883, 272, 1002),
    "item_salad":    (284, 895, 407, 1002),
    "item_water":    (426, 888, 527, 1002),
    "item_banana":   (558, 883, 657, 1000),
    "item_onigiri":  (686, 895, 792, 1000),
    # ポーズ例（左から2番目、片腕フレックス＋キラキラ）
    "pose_flex": (1005, 835, 1185, 1015),
    # 参照用（アプリでは未使用、位置合わせの見本）
    "ref_complete": (18, 48, 310, 385),
}

img = Image.open(SRC).convert("RGB")
W, H = img.size
px = img.load()


def is_checker(c):
    mx, mn = max(c), min(c)
    return mx - mn < 25 and mx > 175


# 画像の縁からチェッカー/白背景を辿ってグローバル背景マスクを作る
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

# フリンジを2px膨張で食う
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


def is_darkish(c):
    return max(c) < 120


# 青系の装飾（Zzz）を捨てるパーツ。汗・涙・フラッシュは表情の一部なので対象外
DROP_BLUE = {"face_sleepy"}


os.makedirs(OUT_DIR, exist_ok=True)

for name, (x1, y1, x2, y2) in PARTS.items():
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
            blue = 0
            stack = [(sx, sy)]
            seen[i] = 1
            while stack:
                cx, cy = stack.pop()
                comp.append((cx, cy))
                c = px[x1 + cx, y1 + cy]
                if is_darkish(c):
                    dark += 1
                if c[2] > c[0] + 20:
                    blue += 1
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    j = ny * bw + nx
                    if 0 <= nx < bw and 0 <= ny < bh and not seen[j] \
                            and not bg[(y1 + ny) * W + (x1 + nx)]:
                        seen[j] = 1
                        stack.append((nx, ny))
            if len(comp) < 40 or dark / len(comp) > 0.7:
                continue
            if name in DROP_BLUE and blue / len(comp) > 0.4:
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
        print(f"!! {name}: 前景なし（ボックス要調整）")
        continue
    out = out.crop((minx, miny, maxx + 1, maxy + 1))
    out.save(os.path.join(OUT_DIR, f"{name}.png"))
    print(f"{name}: {out.size[0]}x{out.size[1]}")
