# マッチョぽんぽこ仕様書シート（ChatGPT生成、チェッカー疑似透過背景）から
# パーツ・表情・エフェクト・持ち物を切り出して assets/images/ponta_macho/ に保存する。
#   python3 tools/extract_macho.py <sheet.png>
# 背景 = 画像の縁から連結した「明るい無彩色（チェッカー柄・区切り線）」。
# ラベル文字・見出し帯は暗色成分として各ボックス内で除外する。
import os
import sys
from collections import deque

from PIL import Image

SRC = sys.argv[1]
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "images", "ponta_macho")

# シート上の切り出しボックス (x1, y1, x2, y2)。1536x1024前提
PARTS = {
    # 本体パーツ
    "head_smug":  (350, 130, 520, 325),   # パーツ一覧の頭（ドヤ顔・葉っぱ込み）
    "body":       (528, 130, 692, 335),
    "arm_r_down": (712, 160, 802, 345),
    "arm_r_flex": (818, 160, 972, 300),
    "head_arm_l": (985, 145, 1145, 325),  # 頭＋左腕（腕組み用）
    "leg_l":      (1148, 165, 1245, 335),
    "leg_r":      (1252, 165, 1348, 335),
    "tail":       (1358, 165, 1505, 335),
    # 表情（頭のみ）
    "face_normal": (28, 455, 222, 618),
    "face_smug":   (228, 455, 422, 618),
    "face_panic":  (424, 455, 622, 618),
    "face_angry":  (626, 455, 832, 618),
    "face_plead":  (28, 640, 222, 800),
    # 眠いはZzz装飾（青系）を成分フィルタで除外して頭だけにする
    "face_sleepy": (224, 640, 422, 800),
    "face_cry":    (424, 640, 622, 800),
    "face_shock":  (624, 640, 832, 800),
    # エフェクト
    "fx_sweat": (925, 465, 1035, 595),
    "fx_fire":  (1095, 460, 1235, 600),
    "fx_heart": (1285, 465, 1445, 585),
    "fx_meat":  (915, 635, 1045, 765),
    "fx_beer":  (1105, 630, 1235, 775),
    "fx_rice":  (1285, 640, 1425, 765),
    # 持ち物（腕込み）
    "item_dumbbell": (15, 875, 162, 1005),
    "item_protein":  (168, 875, 282, 1005),
    "item_salad":    (285, 875, 398, 1005),
    "item_water":    (415, 875, 525, 1005),
    "item_banana":   (535, 875, 652, 1005),
    "item_onigiri":  (655, 875, 785, 1005),
    # ポーズ例の完成絵（右から3番目=左から2番目、両腕フレックス）。
    # パーツ合成が化け物になりがちなのでMachoPontaはこの1枚をそのまま使う
    "pose_flex": (1020, 830, 1180, 1015),
    # 参照用（アプリでは未使用、位置合わせの見本）
    "ref_complete": (18, 55, 332, 392),
}

img = Image.open(SRC).convert("RGB")
W, H = img.size
px = img.load()


def is_checker(c):
    mx, mn = max(c), min(c)
    return mx - mn < 25 and mx > 175


# 画像の縁からチェッカー柄を辿ってグローバル背景マスクを作る
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


# 青系の装飾（Zzz・隣ポーズの✨）を捨てるパーツ。汗やフラッシュは表情の一部なので対象外
DROP_BLUE = {"face_sleepy", "pose_flex"}


os.makedirs(OUT_DIR, exist_ok=True)

for name, (x1, y1, x2, y2) in PARTS.items():
    bw, bh = x2 - x1, y2 - y1
    # ボックス内の前景を連結成分に分け、ラベル文字（ほぼ暗色 or 極小）を捨てる
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
            # 文字・ノイズ除去: 極小成分、または暗色率7割超（ラベル文字）
            if len(comp) < 40 or dark / len(comp) > 0.7:
                continue
            # 青系装飾（Zzz等）の除去対象パーツ
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
