# 既存PontaPuppet（ponta_parts）のボディに、マッチョシート由来の新表情頭
# （ponta_macho/face_*）を載せる混合プレビュー。
# 配置座標は lib/widgets/ponta_puppet.dart のデザイン座標(560x660)と同じ。
# ここで決めたスケール・オフセットをDart側に写す。
#   python3 tools/compose_mix.py <out.png>
import os
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "images")

# ponta_puppet.dartと同じ配置 (name, left, top)。パーツは原寸=デザイン寸
BODY_STACK = [
    ("ponta_parts/tail", 330, 300),
    ("ponta_parts/body", 91, 350),
    ("ponta_parts/foot_l", 150, 528),
    ("ponta_parts/foot_r", 272, 528),
    ("ponta_parts/arm_l", 96, 420),
    ("ponta_parts/arm_r", 302, 420),
]

# 新表情頭の配置 (name, left, top, width)。既存head(77,30,w407)に顔位置を合わせる
# 焦る/怒り/驚きは汗・怒りマーク・フラッシュ込みでクロップが広い分を微調整
NEW_HEADS = {
    "angry":   ("ponta_macho/face_angry", 77, 35, 410),  # 淡色版シートで顔幅クロップに
    "panic":   ("ponta_macho/face_panic", 70, 35, 415),
    "plead":   ("ponta_macho/face_plead", 77, 30, 407),
    "sleepy":  ("ponta_macho/face_sleepy", 110, 40, 340),  # クロップが縦長なので小さめ
    "cry":     ("ponta_macho/face_cry", 77, 35, 410),
    "surprised": ("ponta_macho/face_shock", 65, 30, 445),
}

CANVAS = (560, 660)


def load(name):
    return Image.open(os.path.join(ROOT, f"{name}.png"))


def compose(head_spec):
    name, x, y, w = head_spec
    # お願いは顔に両手が含まれるので、ボディ側の腕を外す（手4本の化け物防止）
    hide_arms = "plead" in name
    canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    for pname, px_, py_ in BODY_STACK:
        if hide_arms and pname.endswith(("arm_l", "arm_r")):
            continue
        canvas.alpha_composite(load(pname), (px_, py_))
    head = load(name)
    head = head.resize((w, int(head.height * w / head.width)), Image.NEAREST)
    canvas.alpha_composite(head, (x, y))
    return canvas


if __name__ == "__main__":
    out_path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/mix_compose.png"
    # 比較用: 既存のnormal頭 → 新6表情
    specs = [("ponta_parts/head", 77, 30, 407)] + list(NEW_HEADS.values())
    h = 360
    scaled = []
    for s in specs:
        im = compose(s)
        scaled.append(im.resize((int(im.width * h / im.height), h), Image.NEAREST))
    total_w = sum(im.width for im in scaled) + 15 * (len(scaled) + 1)
    sheet = Image.new("RGB", (total_w, h + 20), (90, 140, 90))
    x = 15
    for im in scaled:
        sheet.paste(im, (x, 10), im)
        x += im.width + 15
    sheet.save(out_path)
    print(f"saved {out_path}")
