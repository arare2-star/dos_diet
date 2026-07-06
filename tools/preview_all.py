# lib/widgets/ponta_puppet.dartのStack合成をそのまま再現して、
# 全表情×全エフェクトを見比べるプレビューを作る（デザイン座標560x660はDart側と同一）。
#   python3 tools/preview_all.py <out.png>
import os
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "images")
CANVAS = (560, 660)

# (folder, name, left, top, width) 表情ごとの頭配置。ponta_puppet.dart _head() と同一
HEADS = {
    "normal":    ("ponta_parts", "head", 77, 30, 407),
    "wink":      ("ponta_parts", "head_wink", 77, 30, 407),
    "smug":      ("ponta_macho", "head_smug", 77, 40, 406),
    "shock":     ("ponta_parts", "head_shock", 72, 14, 420),
    "angry":     ("ponta_macho", "face_angry", 77, 35, 410),
    "panic":     ("ponta_macho", "face_panic", 70, 35, 415),
    "plead":     ("ponta_macho", "face_plead", 77, 30, 407),
    "sleepy":    ("ponta_macho", "face_sleepy", 77, 35, 410),
    "cry":       ("ponta_macho", "face_cry", 77, 35, 410),
    "surprised": ("ponta_macho", "face_shock", 65, 52, 445),
}

# (folder, name, width) ponta_puppet.dart _effect() と同一。leftは445固定
EFFECTS = {
    "sweat": ("ponta_macho", "fx_sweat", 100.0),
    "fire":  ("ponta_macho", "fx_fire", 130.0),
    "heart": ("ponta_macho", "fx_heart", 140.0),
    "meat":  ("ponta_macho", "fx_meat", 130.0),
    "beer":  ("ponta_macho", "fx_beer", 115.0),
    "rice":  ("ponta_macho", "fx_rice", 130.0),
}

BODY_STACK = [
    ("ponta_parts", "tail", 330, 300),
    ("ponta_parts", "body", 91, 350),
    ("ponta_parts", "foot_l", 150, 528),
    ("ponta_parts", "foot_r", 272, 528),
    ("ponta_parts", "arm_l", 96, 420),
    ("ponta_parts", "arm_r", 302, 420),
]


def load(folder, name):
    return Image.open(os.path.join(ROOT, folder, f"{name}.png")).convert("RGBA")


def compose(expr, effect=None):
    hide_arms = expr == "plead"
    canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    for folder, name, x, y in BODY_STACK:
        if hide_arms and name in ("arm_l", "arm_r"):
            continue
        canvas.alpha_composite(load(folder, name), (x, y))
    hfolder, hname, hx, hy, hw = HEADS[expr]
    head = load(hfolder, hname)
    head = head.resize((hw, int(head.height * hw / head.width)), Image.NEAREST)
    canvas.alpha_composite(head, (hx, hy))
    if effect is not None:
        efolder, ename, ew = EFFECTS[effect]
        fx = load(efolder, ename)
        fx = fx.resize((int(ew), int(fx.height * ew / fx.width)), Image.NEAREST)
        canvas.alpha_composite(fx, (445, -5))
    return canvas


def grid(images_labels, cols, cell_h=280, bg=(70, 120, 80)):
    scaled = []
    for label, im in images_labels:
        w = int(im.width * cell_h / im.height)
        scaled.append((label, im.resize((w, cell_h), Image.NEAREST)))
    cell_w = max(w for _, im in scaled for w in [im.width]) + 20
    rows = (len(scaled) + cols - 1) // cols
    sheet = Image.new("RGB", (cell_w * cols, (cell_h + 30) * rows), bg)
    from PIL import ImageDraw
    d = ImageDraw.Draw(sheet)
    for i, (label, im) in enumerate(scaled):
        cx = (i % cols) * cell_w
        cy = (i // cols) * (cell_h + 30)
        ox = cx + (cell_w - im.width) // 2
        sheet.paste(im, (ox, cy + 25), im)
        d.text((cx + 5, cy + 5), label, fill=(255, 255, 255))
    return sheet


if __name__ == "__main__":
    out_path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/preview_all.png"

    expr_imgs = [(name, compose(name)) for name in HEADS]
    sheet1 = grid(expr_imgs, cols=5)

    fx_imgs = [(name, compose("normal", name)) for name in EFFECTS]
    sheet2 = grid(fx_imgs, cols=3)

    total_h = sheet1.height + sheet2.height + 10
    total_w = max(sheet1.width, sheet2.width)
    combined = Image.new("RGB", (total_w, total_h), (40, 60, 50))
    combined.paste(sheet1, (0, 0))
    combined.paste(sheet2, (0, sheet1.height + 10))
    combined.save(out_path)
    print(f"saved {out_path} {combined.size}")
