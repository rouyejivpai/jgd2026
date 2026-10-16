"""「趋利避害」魔幻炼金术演出（实验用）。字体：GNU Unifont（16px 点阵，整数倍放大）。

演出：
  0.0–0.8s  利（翠绿）、害（绯红）背后的炼成阵顺时针描绘成形，字由普通文字溶解“炼成”为特效字
  0.5s      避 位于红色炼成阵内被灼伤发抖 → 0.85s 害 放出冲击环，避 被弹出阵外（残影）
  0.8s      利 向 趋 牵出绿色光链 → 0.9s 起 趋 被加速吸过去 → 1.8s 贴合：绿色冲击环 + 光屑迸发
  2.4–3.2s  全部归位为正常文本间距 → 3.5s 演出结束，转入 idle 循环（4s，阵纹旋转无缝衔接）

炼成阵：外圈点环 + 外环 + 内环 + 8 枚 Unifont 炼金/行星符文（依次点亮）+ 反向旋转的内接方形与三角 + 中心小圆。

输出（默认到 assets/sprites/vfx/qu_li_bi_hai_alchemy/）：
  <name>_sheet.png / <name>_frames.tres（intro + idle）/ <name>_preview.gif / <name>_demo.tscn + .gd

用法：
  python tools/gen_alchemy_phrase.py
"""
from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from gen_burning_phrase import box_blur, progress, pulse, smoothstep, write_spriteframes
from gen_burning_text import BAYER4, GODOT_ROOT, dilate, shift

FAMILY = {  # index 0 = 描边/最暗 … 5 = 最亮
    "green": np.array([(6, 30, 28, 255), (10, 64, 54, 255), (18, 112, 82, 255),
                       (40, 172, 112, 255), (112, 232, 162, 255), (214, 255, 228, 255)], np.uint8),
    "red": np.array([(38, 6, 18, 255), (86, 12, 34, 255), (148, 22, 48, 255),
                     (214, 48, 64, 255), (255, 118, 120, 255), (255, 216, 206, 255)], np.uint8),
}
NEUTRAL_OUTLINE = (16, 10, 22, 255)
NEUTRAL_SHADES = np.array([(150, 136, 140), (214, 204, 196), (248, 242, 232)], np.float64)
TINT = {"green": np.array((112, 232, 162), np.float64), "red": np.array((255, 118, 120), np.float64)}
TINT_STEPS = (0.0, 0.35, 0.65)
RUNES = "☉☽☿♀♂♃♄△"  # 日 月 汞 铜 铁 锡 铅 火
PREVIEW_BG = (12, 8, 22, 255)

# 时间轴（秒）
T_DRAW = (0.0, 0.8)       # 炼成阵描绘 + 字溶解炼成
T_SHAKE = (0.5, 0.85)
T_FLEE = (0.85, 1.4)
T_TETHER = 0.8
T_ATTRACT = (0.9, 1.8)
T_SETTLE = (2.4, 3.2)
T_END = 3.5


def render_unifont(ch: str, font: ImageFont.FreeTypeFont, scale: int = 1, crop: bool = False) -> np.ndarray:
    img = Image.new("L", (16, 16), 0)
    d = ImageDraw.Draw(img)
    d.fontmode = "1"
    d.text((0, 0), ch, font=font, fill=255)
    m = np.array(img) > 127
    if crop:
        ys, xs = np.where(m)
        m = m[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    return np.kron(m, np.ones((scale, scale), bool)) if scale > 1 else m


def stamp(dst: np.ndarray, m: np.ndarray, x: int, y: int, value) -> None:
    """把小 mask 以 (x,y) 为左上角写入 dst（自动裁剪越界部分）。"""
    H, W = dst.shape[:2]
    h, w = m.shape
    x0, y0, x1, y1 = max(0, x), max(0, y), min(W, x + w), min(H, y + h)
    if x1 <= x0 or y1 <= y0:
        return
    sub = m[y0 - y:y1 - y, x0 - x:x1 - x]
    dst[y0:y1, x0:x1][sub] = value


def build(args):
    rng = np.random.default_rng(args.seed)
    fps, n_idle = args.fps, args.idle_frames
    text = args.text
    assert len(text) == 4, "演出按 [趋][利][避][害] 四字结构编排"
    effect_of = {1: "green", 3: "red"}

    font = ImageFont.truetype(args.font, 16)
    sc = args.glyph_scale
    cell = 16 * sc
    glyphs = [render_unifont(c, font, sc) for c in text]
    ink = [(int(np.where(g.any(0))[0][0]), int(np.where(g.any(0))[0][-1])) for g in glyphs]
    runes = [render_unifont(c, font, 1, crop=True) for c in RUNES]

    R = args.radius
    r_in = R - 13
    r_rune = R - 6.5

    def contact_x(li: int, ri: int, right_x: int, gap: int = 2) -> int:
        return right_x + ink[ri][0] - gap - ink[li][1]

    st = {"li": 0}
    st["hai"] = st["li"] + 4 * cell
    st["bi_flee"] = st["hai"] - (R + 20)
    st["bi_start"] = contact_x(2, 3, st["hai"])
    st["qu_contact"] = contact_x(0, 1, st["li"])
    st["qu_start"] = st["li"] - int(3.4 * cell)
    half = cell // 2
    left = min(st["qu_start"] + ink[0][0], st["li"] + half - R - 4)
    right = st["hai"] + half + R + 4
    pad = 6
    W = right - left + 1 + 2 * pad
    W += W % 2
    off = pad - left
    st = {k: v + off for k, v in st.items()}
    top_room = 14
    cy = pad + top_room + R + 1
    H = cy + R + 4 + pad
    H += H % 2
    gy = cy - half  # 字格顶边
    x0 = (W - 4 * cell) // 2
    normal = [x0 + i * cell for i in range(4)]

    def positions(t: float) -> list[int]:
        qa = progress(T_ATTRACT, t) ** 2.4
        qu = st["qu_start"] + (st["qu_contact"] - st["qu_start"]) * qa
        bf = 1 - (1 - progress(T_FLEE, t)) ** 3
        bi = st["bi_start"] + (st["bi_flee"] - st["bi_start"]) * bf
        if T_SHAKE[0] <= t < T_SHAKE[1]:
            bi += 1 if int(t * fps) % 2 else -1
        perf = [qu, st["li"], bi, st["hai"]]
        s = smoothstep(*T_SETTLE, t)
        return [int(round(p + (n - p) * s)) for p, n in zip(perf, normal)]

    n_intro = int(round(T_END * fps))
    ys, xs = np.mgrid[0:H, 0:W]
    bayer = BAYER4[ys % 4, xs % 4]

    motes = {}
    for idx in effect_of:
        motes[idx] = [dict(rx=rng.uniform(-0.8, 0.8) * R, phase=rng.random(), cycles=int(rng.integers(1, 3)),
                           sway=rng.uniform(0.5, 2), rise=rng.uniform(1.2, 1.9) * R, twinkle=k % 3 == 0)
                      for k in range(args.motes)]

    def burst(t0, n, fam, origin_fn):
        return [dict(t0=t0, fam=fam, origin=origin_fn, life=rng.uniform(0.4, 0.9),
                     ang=rng.uniform(0, 2 * math.pi), spd=rng.uniform(25, 60)) for _ in range(n)]

    bursts = (burst(T_FLEE[0], 18, "red", lambda p: (p[3] + half, cy))
              + burst(T_ATTRACT[1], 24, "green", lambda p: (p[1] + ink[1][0] - 1, cy)))
    shocks = [(T_FLEE[0], 3, "red"), (T_ATTRACT[1], 1, "green")]

    frames = []
    history: list[list[int]] = []
    for gi in range(n_intro + n_idle):
        t = gi / fps
        pos = positions(min(t, T_END))
        history.append(pos)
        reveal = smoothstep(*T_DRAW, t)
        phase = gi / n_idle  # 一个 idle 循环 = 1.0，阵纹按整数对称周期旋转
        pul = {1: pulse(T_ATTRACT[1], 0.6, t), 3: pulse(T_FLEE[0], 0.6, t)}
        masks = [np.zeros((H, W), bool) for _ in range(4)]
        for i, g in enumerate(glyphs):
            stamp(masks[i], g, pos[i], gy, True)

        rgba = np.zeros((H, W, 4), np.uint8)
        light = {}
        knock = dilate(dilate(np.logical_or.reduce(masks)))  # 字周围留出暗底，阵纹退到字后
        for idx, fam in effect_of.items():
            cx = pos[idx] + half
            spin = 1 if fam == "green" else -1
            lay = Image.new("L", (W, H), 0)
            d = ImageDraw.Draw(lay)
            for k in range(24):  # 点环：每循环转 2 格
                a = 2 * math.pi * (k + spin * 2 * phase) / 24
                d.point((round(cx + (R + 3) * math.cos(a)), round(cy + (R + 3) * math.sin(a))), 2)
            d.ellipse([cx - R, cy - R, cx + R, cy + R], outline=4)
            d.ellipse([cx - r_in, cy - r_in, cx + r_in, cy + r_in], outline=3)
            d.ellipse([cx - 7, cy - 7, cx + 7, cy + 7], outline=2)
            a_sq = spin * phase * math.pi / 2  # 方形每循环 90°
            d.polygon([(cx + (r_in - 1) * math.cos(a_sq + k * math.pi / 2),
                        cy + (r_in - 1) * math.sin(a_sq + k * math.pi / 2)) for k in range(4)], outline=2)
            a_tr = -spin * phase * 2 * math.pi / 3 - math.pi / 2  # 三角反向，每循环 120°
            d.polygon([(cx + (r_in - 1) * math.cos(a_tr + k * 2 * math.pi / 3),
                        cy + (r_in - 1) * math.sin(a_tr + k * 2 * math.pi / 3)) for k in range(3)], outline=2)
            arr = np.array(lay)
            for k, rm in enumerate(runes):  # 符文：先挖空背后的线，再依次点亮
                a = -math.pi / 2 + 2 * math.pi * k / len(runes)
                rx = round(cx + r_rune * math.cos(a) - rm.shape[1] / 2)
                ry = round(cy + r_rune * math.sin(a) - rm.shape[0] / 2)
                stamp(arr, np.pad(dilate(np.pad(rm, 1)), 0), rx - 1, ry - 1, 0)
                chase = (phase * 2 * len(runes) - k) % len(runes)
                stamp(arr, rm, rx, ry, 5 if chase < 1 else 4 if chase < 2 else 3)
            if reveal < 1:  # 顺时针描绘，笔头最亮
                ang = (np.arctan2(xs - cx, -(ys - cy)) / (2 * math.pi)) % 1.0
                head = (ang <= reveal) & (ang > reveal - 0.05) & (arr > 0)
                arr[ang > reveal] = 0
                arr[head] = 5
            if pul[idx] > 0.25:
                arr[arr > 0] = np.minimum(arr[arr > 0] + 1, 5)
            arr[knock] = 0
            for t0, lvl0, sfam in shocks:  # 冲击环
                age = t - t0
                if sfam != fam or not 0 <= age < 0.7:
                    continue
                k = age / 0.7
                for dr, lv in ((0, lvl0 + 2 - int(k * 3)), (-5, lvl0 + 1 - int(k * 3))):
                    rr = 6 + k * (R + 26) + dr
                    if rr <= 2 or lv <= 0:
                        continue
                    ring = Image.new("1", (W, H), 0)
                    ImageDraw.Draw(ring).ellipse([cx - rr, cy - rr, cx + rr, cy + rr], outline=1)
                    rm = np.array(ring)
                    if k > 0.5:
                        rm &= (xs + ys) % 2 == 0
                    arr[rm] = min(5, lv)
            if reveal > 0.5:  # 上升光屑
                for m in motes[idx]:
                    u = (phase * m["cycles"] + m["phase"]) % 1.0
                    y = int(round(cy + R * 0.5 - u * m["rise"]))
                    x = int(round(cx + m["rx"] + m["sway"] * math.sin(2 * math.pi * (u * 2 + m["phase"]))))
                    lv = 3 if u < 0.15 else 5 if u < 0.5 else 4 if u < 0.8 else 2
                    if 0 <= y < H and 0 <= x < W:
                        arr[y, x] = lv
                        if m["twinkle"] and 0.35 < u < 0.5:
                            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                                if 0 <= y + dy < H and 0 <= x + dx < W:
                                    arr[y + dy, x + dx] = 3
            sel = arr > 0
            rgba[sel] = FAMILY[fam][arr[sel]]
            light[fam] = box_blur(box_blur(masks[idx] * 1.0 + sel * 0.15, 4), 4) * reveal * (1 + pul[idx])

        # 光链：利 → 趋，光点向 利 流动
        if T_TETHER <= t < T_ATTRACT[1]:
            (x0_, x1_) = (pos[0] + half, pos[1] + half)
            length = max(1, x1_ - x0_)
            grow = min(1.0, (t - T_TETHER) / 0.3)
            for j in range(0, length, 4):
                s = (j + gi * 2) % length
                if s < length * (1 - grow):
                    continue
                y = cy + round(1.5 * math.sin(2 * math.pi * (s / 24 - gi / 8)))
                rgba[y, x0_ + s] = FAMILY["green"][4 if (j // 4) % 3 == 0 else 3]

        # 残影
        for idx, fam in ((0, "green"), (2, "red")):
            for back, checker in ((1, False), (2, True)):
                if gi - back < 0 or abs(pos[idx] - history[gi - back][idx]) < 3:
                    continue
                gm = np.zeros((H, W), bool)
                stamp(gm, glyphs[idx], history[gi - back][idx], gy, True)
                if checker:
                    gm &= (ys + xs) % 2 == 0
                rgba[gm] = FAMILY[fam][2]

        # 字：灵光（仅空白处）→ 描边 → 字身
        for idx, fam in effect_of.items():
            aura = dilate(dilate(masks[idx])) & ~dilate(masks[idx]) & ((xs + ys + gi) % 2 == 0) & (rgba[..., 3] == 0)
            aura &= bayer < reveal
            rgba[aura] = FAMILY[fam][2 if pul[idx] > 0.2 else 1]
        for idx, m in enumerate(masks):
            rgba[dilate(m) & ~m] = FAMILY[effect_of[idx]][0] if idx in effect_of else NEUTRAL_OUTLINE
        for idx, m in enumerate(masks):
            above_empty = m & ~shift(m, 1, 0, False)
            below_empty = m & ~shift(m, -1, 0, False)
            if idx in effect_of:
                fam = effect_of[idx]
                lvl = np.where(above_empty, 4, np.where(below_empty, 2, 3))
                band = ((xs - pos[idx]) + (ys - gy) * 0.6 - (gi * 2 * 64 / n_idle)) % 64  # 斜向扫光，每循环 2 次
                lvl = lvl + np.where(band < 3, 2, np.where(band < 5, 1, 0)) + (pul[idx] > 0.2)
                lvl = np.clip(lvl, 1, 5)
                transmuted = m & (bayer < reveal)
                rgba[transmuted] = FAMILY[fam][lvl][transmuted]
                m = m & ~transmuted  # 尚未炼成的像素按普通字画
            if not m.any():
                continue
            level = np.where(above_empty, 2, np.where(below_empty, 0, 1))
            lg, lr = light["green"] * 3.2, light["red"] * 3.2
            fam_green = lg >= lr
            step = np.digitize(np.maximum(lg, lr) + (bayer - 0.5) * 0.08, (0.22, 0.5))
            for fam, sel in (("green", fam_green), ("red", ~fam_green)):
                for k, f in enumerate(TINT_STEPS):
                    for lv in range(3):
                        pick = m & sel & (step == k) & (level == lv)
                        if pick.any():
                            c = np.rint(NEUTRAL_SHADES[lv] * (1 - f) + TINT[fam] * f).astype(np.uint8)
                            rgba[pick] = (*c, 255)

        # 迸发光屑（最上层）
        for p in bursts:
            age = t - p["t0"]
            if not 0 <= age < p["life"]:
                continue
            ox, oy = p["origin"](pos)
            drag = (1 - math.exp(-3 * age)) / 3
            x = int(round(ox + math.cos(p["ang"]) * p["spd"] * drag))
            y = int(round(oy + math.sin(p["ang"]) * p["spd"] * drag - 10 * age * age))
            if 0 <= y < H and 0 <= x < W:
                rgba[y, x] = FAMILY[p["fam"]][5 - min(3, int(age / p["life"] * 4))]
        frames.append(rgba)
    return frames, n_intro, n_idle


DEMO_GD = '''extends Node2D
## 炼金术演出预览：intro 播完自动转 idle 循环；空格 / 回车 / 鼠标点击重播。

@onready var _title: AnimatedSprite2D = $Title


func _ready() -> void:
\t_title.animation_finished.connect(_on_animation_finished)
\t_title.play(&"intro")


func _on_animation_finished() -> void:
\tif _title.animation == &"intro":
\t\t_title.play(&"idle")


func _unhandled_input(event: InputEvent) -> void:
\tvar mouse := event as InputEventMouseButton
\tif event.is_action_pressed(&"ui_accept") or (mouse != null and mouse.pressed):
\t\t_title.play(&"intro")
'''


def write_demo(out: Path, name: str, res_dir: str, scale: int) -> None:
    (out / f"{name}_demo.gd").write_text(DEMO_GD, encoding="utf-8")
    bg = ", ".join(f"{c / 255:.3f}" for c in PREVIEW_BG[:3])
    (out / f"{name}_demo.tscn").write_text(f'''[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="{res_dir}/{name}_demo.gd" id="1_script"]
[ext_resource type="SpriteFrames" path="{res_dir}/{name}_frames.tres" id="2_frames"]

[node name="AlchemyDemo" type="Node2D"]
script = ExtResource("1_script")

[node name="Background" type="ColorRect" parent="."]
offset_right = 1920.0
offset_bottom = 1080.0
mouse_filter = 2
color = Color({bg}, 1)

[node name="Title" type="AnimatedSprite2D" parent="."]
texture_filter = 1
position = Vector2(960, 540)
scale = Vector2({scale}, {scale})
sprite_frames = ExtResource("2_frames")
animation = &"intro"
''', encoding="utf-8")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--text", default="趋利避害")
    ap.add_argument("--font", default=str(GODOT_ROOT / "tools/assets/fonts/unifont-18.0.01.otf"))
    ap.add_argument("--glyph-scale", type=int, default=2, help="Unifont 16px 点阵的整数放大倍数")
    ap.add_argument("--radius", type=int, default=32, help="炼成阵外环半径（1x 像素）")
    ap.add_argument("--fps", type=float, default=15)
    ap.add_argument("--idle-frames", type=int, default=60)
    ap.add_argument("--motes", type=int, default=14)
    ap.add_argument("--seed", type=int, default=5)
    ap.add_argument("--preview-scale", type=int, default=3)
    ap.add_argument("--name", default="qu_li_bi_hai_alchemy")
    ap.add_argument("--out", default=str(GODOT_ROOT / "assets/sprites/vfx/qu_li_bi_hai_alchemy"))
    args = ap.parse_args()

    frames, n_intro, n_idle = build(args)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    fh, fw = frames[0].shape[:2]
    n = len(frames)
    cols = 12
    rows = math.ceil(n / cols)
    sheet = Image.new("RGBA", (cols * fw, rows * fh), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(Image.fromarray(fr, "RGBA"), ((i % cols) * fw, (i // cols) * fh))
    sheet_path = out / f"{args.name}_sheet.png"
    sheet.save(sheet_path)

    res_dir = "res://" + out.resolve().relative_to(GODOT_ROOT).as_posix()
    write_spriteframes(out / f"{args.name}_frames.tres", f"{res_dir}/{sheet_path.name}", cols, fw, fh, [
        dict(name="intro", frames=range(n_intro), loop=False, speed=args.fps),
        dict(name="idle", frames=range(n_intro, n), loop=True, speed=args.fps),
    ])
    write_demo(out, args.name, res_dir, max(1, 1800 // fw))

    s = args.preview_scale
    seq = list(range(n)) + list(range(n_intro, n))
    gif = []
    for i in seq:
        im = Image.new("RGBA", (fw, fh), PREVIEW_BG)
        im.alpha_composite(Image.fromarray(frames[i], "RGBA"))
        gif.append(im.convert("RGB").resize((fw * s, fh * s), Image.NEAREST)
                   .quantize(colors=200, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE))
    durs = [round(1000 / args.fps)] * len(seq)
    durs[-1] += 600
    gif[0].save(out / f"{args.name}_preview.gif", save_all=True, append_images=gif[1:],
                duration=durs, loop=0, disposal=1, optimize=False)
    print(f"frame {fw}x{fh}, intro {n_intro} + idle {n_idle} @ {args.fps}fps, sheet {cols}x{rows} -> {out}")


if __name__ == "__main__":
    main()
