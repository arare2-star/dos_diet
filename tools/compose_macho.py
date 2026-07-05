# マッチョぽんぽこのパーツを組み立てて完成イメージと見比べるプレビューを作る。
# ここでの配置座標が確定したら、そのままDart側（Stack合成）の座標の元にする。
#   python3 tools/compose_macho.py <out.png>
import os
import sys

from PIL import Image

DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "images", "ponta_macho")

# キャンバス上の配置 (パーツ名, left, top, 左右反転, スケール)。後ろ→前の順に描く
# 完成イメージは頭身低め（頭≒体の1.4倍幅）なので頭だけ1.5倍
CANVAS = (280, 370)
# 腕の本数ルール（化け物防止）:
# - head_arm_l は「頭＋左腕」一体なので、他の腕パーツと併用しない
# - face_plead は顔に両手が含まれるので、サイド腕・持ち物と併用しない
# - 持ち物は腕込み素材なので、右サイド腕と差し替える（合計2本を維持）
POSES = {
    # 腕組み（完成イメージ準拠）。腕はhead_arm_lの1パーツのみ
    "crossed": [
        ("tail",       175, 195, False, 1.0),
        ("leg_l",      60, 215, False, 1.0),
        ("leg_r",      150, 215, False, 1.0),
        ("body",       68, 130, False, 1.0),
        ("head_arm_l", 32, 25, False, 1.5),  # 頭＋左腕。腕が胸の上に重なる
    ],
}
PLACEMENT = POSES["crossed"]


def stand_pose(face, item=None, fx=None, fx_pos=(200, 20)):
    """直立ポーズ。頭パーツ差し替えで表情8種、持ち物は右腕と差し替え、
    エフェクトは頭の横に重ねる。この構成がDart側のデフォルトになる想定"""
    hands_in_face = face == "face_plead"  # お願いは顔に両手が含まれる
    p = [
        ("tail",       175, 195, False, 1.0),
        ("leg_l",      60, 215, False, 1.0),
        ("leg_r",      150, 215, False, 1.0),
    ]
    if not hands_in_face:
        p.append(("arm_r_down", 28, 135, True, 1.0))  # 左腕（反転）
        if item is None:
            p.append(("arm_r_down", 188, 135, False, 1.0))  # 右腕
    p.append(("body", 68, 130, False, 1.0))
    p.append((face, 35, 30, False, 1.5))
    if item is not None and not hands_in_face:
        p.append((item, 175, 195, False, 1.0))  # 右手の持ち物（腕込み素材）
    if fx is not None:
        p.append((fx, fx_pos[0], fx_pos[1], False, 1.0))
    return p


def load(name):
    return Image.open(os.path.join(DIR, f"{name}.png"))


def compose(placement=None):
    canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    for name, x, y, flip, scale in (placement or PLACEMENT):
        part = load(name)
        if flip:
            part = part.transpose(Image.FLIP_LEFT_RIGHT)
        if scale != 1.0:
            part = part.resize(
                (int(part.width * scale), int(part.height * scale)), Image.NEAREST)
        canvas.alpha_composite(part, (x, y))
    return canvas


if __name__ == "__main__":
    out_path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/macho_compose.png"
    ref = load("ref_complete")
    h = 400
    showcase = [
        POSES["crossed"],
        stand_pose("face_normal"),
        stand_pose("face_angry", fx="fx_fire", fx_pos=(195, 5)),
        stand_pose("face_panic", fx="fx_sweat", fx_pos=(210, 25)),
        stand_pose("face_smug", item="item_dumbbell"),
        stand_pose("face_normal", item="item_onigiri"),
        stand_pose("face_plead"),  # 顔の手のみ（サイド腕なし）
    ]
    images = [ref] + [compose(p) for p in showcase]
    scaled = [im.resize((int(im.width * h / im.height), h), Image.NEAREST)
              for im in images]
    total_w = sum(im.width for im in scaled) + 20 * (len(scaled) + 1)
    sheet = Image.new("RGB", (total_w, h + 20), (90, 140, 90))
    x = 20
    for im in scaled:
        sheet.paste(im, (x, 10), im)
        x += im.width + 20
    sheet.save(out_path)
    print(f"saved {out_path}")
