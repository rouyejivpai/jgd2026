"""「趋利避害」演出动画（实验用），沿用 gen_burning_text.py 的像素火焰逻辑。

演出：
  0.0s  利（绿火）、害（红火）点燃；趋 在远处，避 紧贴 害
  0.2s  避 被灼烧发抖 → 0.55s 弹开远离 害（害 火焰爆燃）
  0.6s  趋 被吸引加速贴向 利 → 1.5s 贴合（利 火焰爆燃 + 绿色火星）
  2.1s  全部归位为正常文本间距 → 3.2s 演出结束，转入 idle 循环

输出（默认到 assets/sprites/vfx/qu_li_bi_hai/）：
  <name>_sheet.png     1x 透明底精灵表
  <name>_frames.tres   SpriteFrames：intro（播放一次）+ idle（循环，与 intro 末帧无缝衔接）
  <name>_preview.gif   放大预览：intro + 两轮 idle，整体循环

用法：
  python tools/gen_burning_phrase.py
"""
from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from gen_burning_text import (BAYER4, FLAME_PAL, FLAME_THRESH, GODOT_ROOT, SPARK_PAL, TEXT_OUTLINE,
                              TEXT_PAL, TEXT_THRESH, dilate, erode4, periodic_noise, shift)

GREEN_FLAME_PAL = np.array([
    (0, 0, 0, 0),
    (6, 40, 22, 255),
    (10, 72, 34, 255),
    (16, 110, 46, 255),
    (26, 152, 56, 255),
    (44, 194, 68, 255),
    (92, 228, 96, 255),
    (152, 248, 140, 255),
    (216, 255, 196, 255),
], dtype=np.uint8)
GREEN_TEXT_OUTLINE = (4, 20, 10, 255)
GREEN_TEXT_PAL = np.array([
    (10, 56, 28, 255),
    (18, 98, 42, 255),
    (34, 156, 62, 255),
    (80, 218, 98, 255),
    (176, 255, 168, 255),
], dtype=np.uint8)
GREEN_SPARK_PAL = [(216, 255, 196, 255), (120, 240, 120, 255), (34, 168, 62, 255), (12, 80, 36, 255)]

# 普通字（趋/避）：骨白色，顶边高光、底边阴影；会被邻近火焰的光染色
NEUTRAL_OUTLINE = (20, 12, 14, 255)
NEUTRAL_SHADES = np.array([(142, 126, 118), (208, 196, 182), (246, 238, 226)], dtype=np.float64)
TINT = {"green": np.array((92, 228, 96), np.float64), "red": np.array((255, 82, 40), np.float64)}
TINT_STEPS = (0.0, 0.35, 0.65)

EFFECTS = {
    "green": dict(flame=GREEN_FLAME_PAL, outline=GREEN_TEXT_OUTLINE, text=GREEN_TEXT_PAL, spark=GREEN_SPARK_PAL),
    "red": dict(flame=FLAME_PAL, outline=TEXT_OUTLINE, text=TEXT_PAL, spark=SPARK_PAL),
}

# 时间轴（秒）
T_IGNITE = 0.6
T_SHAKE = (0.2, 0.55)
T_FLEE = (0.55, 1.15)
T_ATTRACT = (0.6, 1.5)
T_SETTLE = (2.1, 2.9)
T_END = 3.2


def smoothstep(e0: float, e1: float, t: float) -> float:
    u = min(1.0, max(0.0, (t - e0) / (e1 - e0)))
    return u * u * (3 - 2 * u)


def progress(span: tuple[float, float], t: float) -> float:
    return min(1.0, max(0.0, (t - span[0]) / (span[1] - span[0])))


def pulse(t0: float, dur: float, t: float) -> float:
    """t0 时刻冲到 1，dur 内衰减到恰好 0（保证 idle 段完全静止，可无缝循环）。"""
    if t < t0:
        return 0.0
    return max(0.0, 1 - (t - t0) / dur) ** 2


def box_blur(a: np.ndarray, r: int) -> np.ndarray:
    for axis in (0, 1):
        p = np.pad(a, [(r + 1, r) if i == axis else (0, 0) for i in range(2)], mode="constant")
        c = np.cumsum(p, axis=axis)
        n = a.shape[axis]
        hi = np.take(c, range(2 * r + 1, 2 * r + 1 + n), axis=axis)
        lo = np.take(c, range(0, n), axis=axis)
        a = (hi - lo) / (2 * r + 1)
    return a


class Glyph:
    def __init__(self, ch: str, font: ImageFont.FreeTypeFont, top: int, cell_h: int, margin: int):
        adv = int(round(font.getlength(ch)))
        img = Image.new("L", (adv + 2 * margin, cell_h), 0)
        d = ImageDraw.Draw(img)
        d.fontmode = "1"
        d.text((margin, -top), ch, font=font, fill=255)
        self.ch = ch
        self.adv = adv
        self.mask = np.array(img) > 127
        cols = np.where(self.mask.any(axis=0))[0]
        self.ink_l, self.ink_r = int(cols[0]), int(cols[-1])
        self.margin = margin


def place(glyph: Glyph, x: int, y: int, H: int, W: int) -> np.ndarray:
    m = np.zeros((H, W), bool)
    gh, gw = glyph.mask.shape
    x0, x1 = max(0, x), min(W, x + gw)
    if x1 > x0:
        m[y:y + gh, x0:x1] = glyph.mask[:, x0 - x:x1 - x]
    return m


def column_distance_up(mask: np.ndarray) -> np.ndarray:
    H, W = mask.shape
    big = 10 ** 4
    d_up = np.full((H, W), big, dtype=np.int32)
    run = np.full(W, big, dtype=np.int32)
    for y in range(H - 1, -1, -1):
        run = np.where(mask[y], 0, np.minimum(run + 1, big))
        d_up[y] = run
    for _ in range(2):
        d_up = np.minimum.reduce([d_up, shift(d_up, 0, 1, big) + 1, shift(d_up, 0, -1, big) + 1])
    return d_up


def build(args):
    rng = np.random.default_rng(args.seed)
    size, fps = args.size, args.fps
    text = args.text
    assert len(text) == 4, "演出按 [趋][利][避][害] 四字结构编排"
    effect_of = {1: "green", 3: "red"}  # 第 2 字绿火，第 4 字红火

    font = ImageFont.truetype(args.font, size)
    probe = ImageDraw.Draw(Image.new("L", (1, 1)))
    probe.fontmode = "1"
    _, top, _, bot = probe.textbbox((0, 0), text, font=font)
    margin = 2
    glyphs = [Glyph(c, font, top, bot - top, margin) for c in text]
    a = glyphs[0].adv
    pad_top, pad_bottom, pad_x = int(size * 1.35), max(4, size // 8), int(size * 0.3)

    # 舞台站位（以字格左上角计），gap=2 时两字描边重合，即“贴紧”
    def contact_x(left: Glyph, right: Glyph, right_x: int, gap: int = 2) -> int:
        return right_x + right.ink_l - gap - left.ink_r

    stage = {}
    stage["li"] = 0
    stage["hai"] = stage["li"] + int(3.4 * a)
    stage["bi_flee"] = stage["li"] + int(1.7 * a)
    stage["bi_start"] = contact_x(glyphs[2], glyphs[3], stage["hai"])
    stage["qu_contact"] = contact_x(glyphs[0], glyphs[1], stage["li"])
    stage["qu_start"] = stage["li"] - int(2.3 * a)
    left = stage["qu_start"] + glyphs[0].ink_l
    right = stage["hai"] + glyphs[3].ink_r
    W = (right - left + 1) + 2 * pad_x
    W += W % 2
    H = pad_top + glyphs[0].mask.shape[0] + pad_bottom
    H += H % 2
    off = pad_x - left
    stage = {k: v + off for k, v in stage.items()}
    # 正常排版：按字体步进连续排列，整体居中
    total = sum(g.adv for g in glyphs)
    x0 = (W - total) // 2 - margin
    normal = [x0 + sum(g.adv for g in glyphs[:i]) for i in range(4)]

    def positions(t: float) -> list[int]:
        qa = progress(T_ATTRACT, t) ** 2.4  # ease-in：越近吸得越快
        qu = stage["qu_start"] + (stage["qu_contact"] - stage["qu_start"]) * qa
        bf = 1 - (1 - progress(T_FLEE, t)) ** 3  # ease-out：猛地弹开再减速
        bi = stage["bi_start"] + (stage["bi_flee"] - stage["bi_start"]) * bf
        if T_SHAKE[0] <= t < T_SHAKE[1]:
            bi += (1 if int(t * fps) % 2 else -1)
        perf = [qu, stage["li"], bi, stage["hai"]]
        s = smoothstep(*T_SETTLE, t)
        return [int(round(p + (n - p) * s)) for p, n in zip(perf, normal)]

    n_intro = int(round(T_END * fps))
    n_idle = args.idle_frames
    ys, xs = np.mgrid[0:H, 0:W]
    dither = (BAYER4[ys % 4, xs % 4] - 0.5) * args.dither

    # 每个特效字各自一套周期噪声（周期 = 速度 × idle 帧数）
    sp1, sp2, sp3, spc = 3, 5, 2, 2
    noise = {}
    for idx in effect_of:
        noise[idx] = dict(
            coarse=periodic_noise(sp1 * n_idle, W, sx=2.2, sy=4.5, rng=rng),
            fine=periodic_noise(sp2 * n_idle, W, sx=1.0, sy=1.6, rng=rng),
            text=periodic_noise(sp3 * n_idle, W, sx=2.0, sy=2.0, rng=rng),
            length=periodic_noise(spc * n_idle, W, sx=3.0, sy=3.0, rng=rng),
        )

    flame_len0 = size * args.flame_height
    gy = pad_top
    gmask_h = glyphs[0].mask.shape[0]
    rows = np.where(glyphs[0].mask.any(axis=1) | glyphs[1].mask.any(axis=1))[0]
    text_top, text_bot = gy + rows.min(), gy + rows.max()

    # 常驻火星（相对字格，周期 = idle 帧数）
    sparks = {}
    for idx in effect_of:
        g = glyphs[idx]
        cols = np.where(g.mask.any(axis=0))[0]
        lst = []
        for _ in range(args.sparks):
            cx = int(rng.choice(cols))
            lst.append(dict(cx=cx, cy=int(np.argmax(g.mask[:, cx])) - 1, phase=rng.random(),
                            cycles=int(rng.integers(1, 3)), sway=rng.uniform(1, 3),
                            rise=rng.uniform(0.6, 1.1) * flame_len0 * 1.2))
        sparks[idx] = lst

    # 事件迸发粒子：避 弹开时 害 喷红火星；趋 贴合时 利 喷绿火星
    def burst(t0, n, eff, origin_fn, dir_sign):
        out = []
        for _ in range(n):
            ang = rng.uniform(-math.pi * 0.95, -math.pi * 0.05)
            spd = rng.uniform(30, 75)
            out.append(dict(t0=t0, eff=eff, origin=origin_fn, life=rng.uniform(0.35, 0.8),
                            vx=math.cos(ang) * spd + dir_sign * rng.uniform(5, 30),
                            vy=math.sin(ang) * spd, oy=rng.uniform(0.2, 0.8)))
        return out

    bursts = (burst(T_FLEE[0], 16, "red", lambda p: p[3] + glyphs[3].ink_l, -1)
              + burst(T_ATTRACT[1], 22, "green", lambda p: p[1] + glyphs[1].ink_l - 1, 0))

    frames, labels = [], []
    history: list[list[int]] = []
    for gi in range(n_intro + n_idle):
        t = gi / fps
        pos = positions(min(t, T_END))
        history.append(pos)
        ign = smoothstep(0, T_IGNITE, t)
        boost = {1: 0.45 * pulse(T_ATTRACT[1], 0.6, t), 3: 0.45 * pulse(T_FLEE[0], 0.55, t)}
        masks = [place(g, x, gy, H, W) for g, x in zip(glyphs, pos)]

        rgba = np.zeros((H, W, 4), np.uint8)
        best = np.full((H, W), -1.0)
        light = {}
        for idx, eff in effect_of.items():
            nz = noise[idx]
            lx = (xs - pos[idx]) % W  # 噪声跟着字走
            nc = nz["coarse"][(ys + gi * sp1) % nz["coarse"].shape[0], lx]
            nf = nz["fine"][(ys + gi * sp2) % nz["fine"].shape[0], lx]
            nl = nz["length"][(gi * spc) % nz["length"].shape[0], lx]
            d_up = column_distance_up(masks[idx])
            amp = np.clip(d_up / 6.0, 0, 1) * 1.6
            xo = np.rint(amp * np.sin(2 * math.pi * (ys / 13.0 - gi / n_idle)) + (nc - 0.5) * 2 * amp).astype(int)
            d = d_up[ys, np.clip(xs + xo, 0, W - 1)]
            L = np.maximum(0.5, flame_len0 * ign * (1 + boost[idx]) * (0.55 + 0.9 * nl))
            base = 1 - d / L
            heat = np.where(base <= 0, -1, base * (0.55 + 0.85 * nc) - 0.28 * (nf - 0.5) + dither)
            heat = np.where(d_up > 10 ** 3, -1, heat)
            idxs = np.digitize(heat, FLAME_THRESH)
            take = (idxs > 0) & (heat > best)
            rgba[take] = EFFECTS[eff]["flame"][idxs][take]
            best = np.where(take, heat, best)
            light[eff] = box_blur(box_blur(masks[idx] * 1.0 + np.clip(heat, 0, 1) * 0.6, 4), 4) \
                * (0.4 + 0.6 * ign) * (1 + boost[idx])

            for s in sparks[idx]:
                if ign < 0.6:
                    continue
                u = (gi / n_idle * s["cycles"] + s["phase"]) % 1.0
                if u > 0.85:
                    continue
                y = int(round(gy + s["cy"] - u * s["rise"]))
                x = int(round(pos[idx] + s["cx"] + s["sway"] * math.sin(2 * math.pi * (u * 1.5 + s["phase"]))))
                if 0 <= y < H and 0 <= x < W:
                    rgba[y, x] = EFFECTS[eff]["spark"][min(3, int(u / 0.85 * 4))]

        # 残影：快速移动的普通字留下两帧拖影
        for idx, col in ((0, (34, 156, 62, 255)), (2, (118, 14, 14, 255))):
            for back, checker in ((1, False), (2, True)):
                if gi - back < 0:
                    continue
                px = history[gi - back][idx]
                if abs(pos[idx] - px) < 3:
                    continue
                gm = place(glyphs[idx], px, gy, H, W)
                if checker:
                    gm &= (ys + xs) % 2 == 0
                rgba[gm] = col

        # 字：先画全部描边，再画字身
        for idx, m in enumerate(masks):
            rgba[dilate(m) & ~m] = EFFECTS[effect_of[idx]]["outline"] if idx in effect_of else NEUTRAL_OUTLINE
        for idx, m in enumerate(masks):
            if idx in effect_of:
                eff = effect_of[idx]
                nz = noise[idx]
                nt = nz["text"][(ys + gi * sp3) % nz["text"].shape[0], (xs - pos[idx]) % W]
                ring0 = m & ~erode4(m)
                ring1 = erode4(m) & ~erode4(erode4(m))
                th = (np.where(ring0, 0.66, np.where(ring1, 0.52, 0.30))
                      + 0.22 * (ys - text_top) / max(1, text_bot - text_top)
                      + 0.42 * (nt - 0.5) + dither * 0.5 - 0.35 * (1 - ign) + 0.15 * boost[idx])
                rgba[m] = EFFECTS[eff]["text"][np.digitize(th, TEXT_THRESH)][m]
            else:
                above_empty = m & ~shift(m, 1, 0, False)
                below_empty = m & ~shift(m, -1, 0, False)
                level = np.where(above_empty, 2, np.where(below_empty, 0, 1))
                lg, lr = light["green"] * 3.6, light["red"] * 3.6
                fam_green = lg >= lr
                s = np.maximum(lg, lr) + dither
                step = np.digitize(s, (0.22, 0.5))
                for fam, sel in (("green", fam_green), ("red", ~fam_green)):
                    for k, f in enumerate(TINT_STEPS):
                        for lv in range(3):
                            pick = m & sel & (step == k) & (level == lv)
                            if pick.any():
                                c = np.rint(NEUTRAL_SHADES[lv] * (1 - f) + TINT[fam] * f).astype(np.uint8)
                                rgba[pick] = (*c, 255)

        # 迸发粒子画在最上层
        for p in bursts:
            age = t - p["t0"]
            if not 0 <= age < p["life"]:
                continue
            ox = p["origin"](pos)
            oy = text_top + p["oy"] * (text_bot - text_top)
            drag = 1 - math.exp(-3 * age)
            x = int(round(ox + p["vx"] * drag / 3))
            y = int(round(oy + p["vy"] * drag / 3 - 12 * age * age))
            if 0 <= y < H and 0 <= x < W:
                rgba[y, x] = EFFECTS[p["eff"]]["spark"][min(3, int(age / p["life"] * 4))]

        frames.append(rgba)
        labels.append("intro" if gi < n_intro else "idle")
    return frames, n_intro, n_idle


def write_spriteframes(path: Path, sheet_res: str, cols: int, fw: int, fh: int, anims: list[dict]):
    n = sum(len(a["frames"]) for a in anims)
    lines = [f'[gd_resource type="SpriteFrames" load_steps={n + 2} format=3]', "",
             f'[ext_resource type="Texture2D" path="{sheet_res}" id="1_sheet"]', ""]
    for i in range(n):
        x, y = (i % cols) * fw, (i // cols) * fh
        lines += [f'[sub_resource type="AtlasTexture" id="AtlasTexture_{i}"]',
                  'atlas = ExtResource("1_sheet")', f"region = Rect2({x}, {y}, {fw}, {fh})", ""]
    blocks = []
    for a in anims:
        frames = ", ".join(f'{{\n"duration": 1.0,\n"texture": SubResource("AtlasTexture_{i}")\n}}' for i in a["frames"])
        blocks.append("{\n" + f'"frames": [{frames}],\n"loop": {str(a["loop"]).lower()},\n'
                      f'"name": &"{a["name"]}",\n"speed": {a["speed"]:.1f}\n' + "}")
    lines += ["[resource]", "animations = [" + ", ".join(blocks) + "]", ""]
    path.write_text("\n".join(lines), encoding="utf-8")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--text", default="趋利避害")
    ap.add_argument("--font", default=r"C:\Windows\Fonts\msyhbd.ttc", help="默认微软雅黑 Bold")
    ap.add_argument("--size", type=int, default=40)
    ap.add_argument("--fps", type=float, default=15)
    ap.add_argument("--idle-frames", type=int, default=30)
    ap.add_argument("--flame-height", type=float, default=0.75)
    ap.add_argument("--sparks", type=int, default=8)
    ap.add_argument("--dither", type=float, default=0.06)
    ap.add_argument("--seed", type=int, default=11)
    ap.add_argument("--preview-scale", type=int, default=3)
    ap.add_argument("--name", default="qu_li_bi_hai")
    ap.add_argument("--out", default=str(GODOT_ROOT / "assets/sprites/vfx/qu_li_bi_hai"))
    args = ap.parse_args()

    frames, n_intro, n_idle = build(args)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    fh, fw = frames[0].shape[:2]
    n = len(frames)
    cols = 10
    rows = math.ceil(n / cols)
    sheet = Image.new("RGBA", (cols * fw, rows * fh), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(Image.fromarray(fr, "RGBA"), ((i % cols) * fw, (i // cols) * fh))
    sheet_path = out / f"{args.name}_sheet.png"
    sheet.save(sheet_path)

    res_path = "res://" + sheet_path.resolve().relative_to(GODOT_ROOT).as_posix()
    write_spriteframes(out / f"{args.name}_frames.tres", res_path, cols, fw, fh, [
        dict(name="intro", frames=range(n_intro), loop=False, speed=args.fps),
        dict(name="idle", frames=range(n_intro, n), loop=True, speed=args.fps),
    ])

    s = args.preview_scale
    seq = list(range(n_intro)) + list(range(n_intro, n)) * 2
    gif = []
    for i in seq:
        im = Image.new("RGBA", (fw, fh), (14, 6, 8, 255))
        im.alpha_composite(Image.fromarray(frames[i], "RGBA"))
        gif.append(im.convert("RGB").resize((fw * s, fh * s), Image.NEAREST)
                   .quantize(colors=200, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE))
    durs = [round(1000 / args.fps)] * len(seq)
    durs[-1] += 600  # 整体重播前稍作停顿
    gif[0].save(out / f"{args.name}_preview.gif", save_all=True, append_images=gif[1:],
                duration=durs, loop=0, disposal=1, optimize=False)
    print(f"frame {fw}x{fh}, intro {n_intro} + idle {n_idle} @ {args.fps}fps, sheet {cols}x{rows} -> {out}")


if __name__ == "__main__":
    main()
