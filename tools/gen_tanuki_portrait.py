# ぽんぽこ正面ポートレート（4表情）のドット絵ジェネレータ（標準ライブラリのみ）
# mini_tanuki.dart と同じ文字グリッド＋パレット方式。
# 実行するとプレビューPNG（4表情横並び）と Dart 用文字列を出力する。
import struct
import sys
import zlib

W, H = 28, 30

PALETTE = {
    "K": (0x4E, 0x34, 0x2E, 255),  # 輪郭
    "B": (0xC4, 0x9A, 0x6C, 255),  # 体
    "D": (0x6D, 0x4C, 0x41, 255),  # 濃い茶（マスク・しま）
    "C": (0xF6, 0xE7, 0xC1, 255),  # クリーム（マズル・腹）
    "G": (0x66, 0xBB, 0x6A, 255),  # 葉っぱ明
    "g": (0x43, 0xA0, 0x47, 255),  # 葉っぱ暗
    "E": (0x21, 0x18, 0x16, 255),  # 目
    "W": (0xFF, 0xFF, 0xFF, 255),  # ハイライト・白目
    "N": (0x3E, 0x27, 0x23, 255),  # 鼻
    "P": (0x56, 0x3A, 0x30, 255),  # 足先
    "R": (0xE5, 0x73, 0x73, 255),  # 舌・ほっぺ
    ".": (0, 0, 0, 0),
}


def new_grid():
    return [["." for _ in range(W)] for _ in range(H)]


def px(g, x, y, ch):
    if 0 <= x < W and 0 <= y < H:
        g[y][x] = ch


def ellipse(g, cx, cy, rx, ry, ch):
    for y in range(H):
        for x in range(W):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                g[y][x] = ch


def hline(g, x0, x1, y, ch):
    for x in range(x0, x1 + 1):
        px(g, x, y, ch)


def outline(g):
    # 本体に隣接する透明ピクセルを輪郭Kにする
    body = {(x, y) for y in range(H) for x in range(W) if g[y][x] != "."}
    for (x, y) in list(body):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < W and 0 <= ny < H and g[ny][nx] == ".":
                g[ny][nx] = "K"


def base():
    """表情なしの正面立ち絵（頭・耳・葉っぱ・マスク・マズル・体・腹・足・しっぽ）"""
    g = new_grid()
    cx = 13.5

    # しっぽ(体の後ろ、右側からのぞく縞々の房)
    ellipse(g, 23.5, 20.5, 3.2, 3.6, "B")
    for y in (18, 20, 22):
        for x in range(20, 27):
            if g[y][x] == "B":
                g[y][x] = "D"

    # 体(頭より小さいチビ比率)
    ellipse(g, cx, 22.0, 7.0, 5.4, "B")
    # 腹
    ellipse(g, cx, 22.8, 4.4, 4.0, "C")

    # 足(体の下から左右に)
    for x0 in (8, 16):
        hline(g, x0, x0 + 3, 27, "B")
        hline(g, x0, x0 + 3, 28, "P")

    # 頭(大きめ)
    ellipse(g, cx, 10.5, 9.4, 7.6, "B")
    # 耳(頭の上に飛び出す三角、内側D)
    for r in range(4):
        hline(g, 7 - r // 2, 7 + r, 0 + r, "B")
        hline(g, 20 - r, 20 + r // 2, 0 + r, "B")
    px(g, 7, 1, "D")
    hline(g, 6, 8, 2, "D")
    px(g, 20, 1, "D")
    hline(g, 19, 21, 2, "D")

    # たぬきマスク(目の周りの濃い部分、左右)
    ellipse(g, 8.5, 10.5, 3.6, 2.7, "D")
    ellipse(g, 18.5, 10.5, 3.6, 2.7, "D")
    # マズル(クリーム)
    ellipse(g, cx, 13.6, 4.2, 3.2, "C")

    # 葉っぱ(頭のてっぺん)
    hline(g, 12, 15, 0, "G")
    hline(g, 11, 16, 1, "G")
    px(g, 13, 0, "g")
    px(g, 14, 1, "g")

    outline(g)

    # 鼻(全表情共通)
    hline(g, 13, 14, 12, "N")
    return g


def _round_eye(g, ex, ey):
    """白目(角丸4x4)+中央2x2の黒目"""
    for dy in range(4):
        for dx in range(4):
            if (dx, dy) in ((0, 0), (3, 0), (0, 3), (3, 3)):
                continue
            px(g, ex + dx, ey + dy, "W")
    for dy in (1, 2):
        for dx in (1, 2):
            px(g, ex + dx, ey + dy, "E")


def eyes_normal(g):
    _round_eye(g, 7, 9)
    _round_eye(g, 17, 9)
    # ちいさなにっこり口
    px(g, 12, 15, "K")
    hline(g, 13, 14, 16, "K")
    px(g, 15, 15, "K")


def eyes_happy(g):
    # キラキラおめめ + 大きなにっこり口 + ほっぺ
    _round_eye(g, 7, 9)
    _round_eye(g, 17, 9)
    px(g, 5, 13, "R")
    px(g, 6, 13, "R")
    px(g, 21, 13, "R")
    px(g, 22, 13, "R")
    # 口角の上がった開き口(中に舌)
    px(g, 11, 14, "K")
    px(g, 16, 14, "K")
    px(g, 12, 15, "K")
    px(g, 15, 15, "K")
    hline(g, 13, 14, 15, "E")
    px(g, 12, 16, "K")
    px(g, 15, 16, "K")
    hline(g, 13, 14, 16, "R")  # 舌


def eyes_shocked(g):
    # 見開いた目(白目大きめ+黒目は中央) + 小さなまん丸口
    for ex in (7, 17):
        for dy in range(4):
            for dx in range(4):
                if (dx, dy) in ((0, 0), (3, 0), (0, 3), (3, 3)):
                    continue
                px(g, ex + dx, 8 + dy, "W")
        for dy in (9, 10):
            px(g, ex + 1, dy, "E")
            px(g, ex + 2, dy, "E")
    hline(g, 13, 14, 14, "K")
    px(g, 12, 15, "K")
    px(g, 15, 15, "K")
    hline(g, 13, 14, 15, "E")
    hline(g, 13, 14, 16, "K")


def eyes_angry(g):
    # つり眉 + じと目 + への字口
    for ex, inner in ((7, True), (17, False)):
        if inner:
            px(g, ex, 8, "E")
            px(g, ex + 1, 8, "E")
            px(g, ex + 2, 9, "E")
            px(g, ex + 3, 9, "E")
        else:
            px(g, ex, 9, "E")
            px(g, ex + 1, 9, "E")
            px(g, ex + 2, 8, "E")
            px(g, ex + 3, 8, "E")
    for ex in (8, 18):
        px(g, ex, 10, "W")
        px(g, ex + 1, 10, "W")
        px(g, ex, 11, "E")
        px(g, ex + 1, 11, "E")
    # への字
    px(g, 11, 16, "K")
    px(g, 12, 15, "K")
    hline(g, 13, 14, 15, "K")
    px(g, 15, 15, "K")
    px(g, 16, 16, "K")


MOODS = {
    "normal": eyes_normal,
    "happy": eyes_happy,
    "shocked": eyes_shocked,
    "angry": eyes_angry,
}


def build(mood):
    g = base()
    MOODS[mood](g)
    return g


# ---- PNG出力(RGBA、フィルタなし) ----
def write_png(path, pixels, w, h):
    raw = b"".join(
        b"\x00" + b"".join(struct.pack("4B", *p) for p in row) for row in pixels
    )

    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c))

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw)))
        f.write(chunk(b"IEND", b""))


def preview(path, scale=12, bg=(0x30, 0x30, 0x38, 255)):
    """4表情を横並びにした確認用PNG"""
    grids = [build(m) for m in MOODS]
    pad = 2
    pw = (W + pad) * len(grids) * scale
    ph = (H + pad * 2) * scale
    img = [[bg] * pw for _ in range(ph)]
    for gi, g in enumerate(grids):
        ox = (gi * (W + pad) + pad // 2) * scale
        oy = pad * scale
        for y in range(H):
            for x in range(W):
                c = PALETTE[g[y][x]]
                if c[3] == 0:
                    continue
                for sy in range(scale):
                    for sx in range(scale):
                        img[oy + y * scale + sy][ox + x * scale + sx] = c
    write_png(path, img, pw, ph)
    print(f"preview: {path}")


def emit_dart():
    for m in MOODS:
        g = build(m)
        print(f"  static const List<String> _{m} = [")
        for row in g:
            print(f'    "{"".join(row)}",')
        print("  ];\n")


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "tanuki_portrait_preview.png"
    preview(out)
    if "--dart" in sys.argv:
        emit_dart()
