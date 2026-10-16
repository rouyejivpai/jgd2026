"""生成「像素风燃烧文字」动画素材（实验用）。

输出（默认到 assets/sprites/vfx/burning_title/）：
  <name>_sheet.png     1x 透明底精灵表（Godot 用，最近邻过滤）
  <name>_frames.tres   Godot 4 SpriteFrames 资源（AnimatedSprite2D 直接挂）
  <name>_preview.gif   放大后的深色底预览 GIF（双击即可播放）

动画首尾无缝循环：所有噪声在时间维度上周期为 frames，火星按整数圈数运动。

用法：
  python tools/gen_burning_text.py
  python tools/gen_burning_text.py --text 人工神灵 --size 40 --frames 24 --fps 12
"""
from __future__ import annotations

import argparse
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

GODOT_ROOT = Path(__file__).resolve().parent.parent

# 火焰色板：index 1 最暗（焰尖/烟）→ 8 最热（焰根）。以红为主，只有焰根带一点橙黄。
FLAME_PAL = np.array([
    (0, 0, 0, 0),
    (52, 6, 10, 255),
    (98, 10, 14, 255),
    (148, 16, 18, 255),
    (196, 26, 22, 255),
    (232, 46, 28, 255),
    (255, 82, 40, 255),
    (255, 132, 64, 255),
    (255, 196, 120, 255),
], dtype=np.uint8)
FLAME_THRESH = [0.10, 0.20, 0.32, 0.46, 0.60, 0.76, 0.90, 1.0]

# 字身色板：炭化暗红核心 + 发光边缘
TEXT_OUTLINE = (22, 3, 6, 255)
TEXT_PAL = np.array([
    (64, 8, 10, 255),
    (118, 14, 14, 255),
    (182, 28, 20, 255),
    (240, 64, 32, 255),
    (255, 146, 80, 255),
], dtype=np.uint8)
TEXT_THRESH = [0.38, 0.55, 0.72, 0.88]

SPARK_PAL = [(255, 200, 120, 255), (255, 120, 56, 255), (220, 40, 26, 255), (120, 12, 14, 255)]

BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def periodic_noise(h: int, w: int, sx: float, sy: float, rng: np.random.Generator) -> np.ndarray:
    """两个方向都周期平铺的平滑噪声（FFT 低通白噪声），值域 0..1。"""
    white = rng.standard_normal((h, w))
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    filt = np.exp(-2 * math.pi ** 2 * ((sx * fx) ** 2 + (sy * fy) ** 2))
    n = np.real(np.fft.ifft2(np.fft.fft2(white) * filt))
    lo, hi = np.percentile(n, 1), np.percentile(n, 99)
    return np.clip((n - lo) / (hi - lo), 0, 1)


def shift(a: np.ndarray, dy: int, dx: int, fill) -> np.ndarray:
    out = np.full_like(a, fill)
    h, w = a.shape
    ys, yd = (slice(0, h - dy), slice(dy, h)) if dy >= 0 else (slice(-dy, h), slice(0, h + dy))
    xs, xd = (slice(0, w - dx), slice(dx, w)) if dx >= 0 else (slice(-dx, w), slice(0, w + dx))
    out[yd, xd] = a[ys, xs]
    return out


def dilate(m: np.ndarray) -> np.ndarray:
    out = m.copy()
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            out |= shift(m, dy, dx, False)
    return out


def erode4(m: np.ndarray) -> np.ndarray:
    out = m.copy()
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        out &= shift(m, dy, dx, False)
    return out


def render_mask(text: str, font_path: str, size: int, pad_top: int, pad_x: int, pad_bottom: int):
    font = ImageFont.truetype(font_path, size)
    probe = ImageDraw.Draw(Image.new("L", (1, 1)))
    probe.fontmode = "1"  # 单色渲染，避免抗锯齿灰边，保证像素硬边
    l, t, r, b = probe.textbbox((0, 0), text, font=font)
    w = (r - l) + pad_x * 2
    h = (b - t) + pad_top + pad_bottom
    w += w % 2
    h += h % 2
    img = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(img)
    d.fontmode = "1"
    d.text((pad_x - l, pad_top - t), text, font=font, fill=255)
    return np.array(img) > 127


def build(args) -> list[np.ndarray]:
    rng = np.random.default_rng(args.seed)
    size = args.size
    mask = render_mask(args.text, args.font, size, pad_top=int(size * 0.9), pad_x=int(size * 0.25),
                       pad_bottom=max(4, size // 8))
    H, W = mask.shape
    F = args.frames
    ys, xs = np.mgrid[0:H, 0:W]

    # 每个像素到其正下方最近文字像素的距离（火焰从笔画向上蹿），再做横向扩散
    big = 10 ** 4
    d_up = np.full((H, W), big, dtype=np.int32)
    run = np.full(W, big, dtype=np.int32)
    for y in range(H - 1, -1, -1):
        run = np.where(mask[y], 0, np.minimum(run + 1, big))
        d_up[y] = run
    for _ in range(2):
        d_up = np.minimum.reduce([d_up, shift(d_up, 0, 1, big) + 1, shift(d_up, 0, -1, big) + 1])

    # 周期噪声：高度 = 速度 × 帧数，保证滚动一整圈刚好回到起点
    sp1, sp2, sp3, spc = 3, 5, 2, 2
    n_coarse = periodic_noise(sp1 * F, W, sx=2.2, sy=4.5, rng=rng)
    n_fine = periodic_noise(sp2 * F, W, sx=1.0, sy=1.6, rng=rng)
    n_text = periodic_noise(sp3 * F, W, sx=2.0, sy=2.0, rng=rng)
    n_len = periodic_noise(spc * F, W, sx=3.0, sy=3.0, rng=rng)

    flame_len = size * args.flame_height
    text_top = np.argmax(mask.any(axis=1))
    text_bot = H - np.argmax(mask[::-1].any(axis=1))
    outline = dilate(mask) & ~mask
    ring0 = mask & ~erode4(mask)
    ring1 = erode4(mask) & ~erode4(erode4(mask))
    edge_heat = np.where(ring0, 0.66, np.where(ring1, 0.52, 0.30))
    vert_heat = 0.22 * (ys - text_top) / max(1, text_bot - text_top)

    # 火星：在有笔画的列上随机出生，每圈整数次循环
    cols = np.where(mask.any(axis=0))[0]
    sparks = []
    for _ in range(args.sparks):
        x0 = int(rng.choice(cols))
        top = int(np.argmax(mask[:, x0]))
        sparks.append(dict(x0=x0, y0=top - 1, phase=rng.random(), cycles=int(rng.integers(1, 3)),
                           rise=rng.uniform(0.6, 1.1) * flame_len * 1.2, sway=rng.uniform(1, 3)))

    dither = (BAYER4[ys % 4, xs % 4] - 0.5) * args.dither
    frames = []
    for f in range(F):
        t = f / F
        nc = n_coarse[(ys + f * sp1) % n_coarse.shape[0], xs]
        nf = n_fine[(ys + f * sp2) % n_fine.shape[0], xs]
        nl = n_len[(f * spc) % n_len.shape[0], xs]

        # 焰体横向摆动：根部稳、尖部飘
        amp = np.clip(d_up / 6.0, 0, 1) * 1.6
        xo = np.rint(amp * np.sin(2 * math.pi * (ys / 13.0 - t)) + (nc - 0.5) * 2 * amp).astype(int)
        d = d_up[ys, np.clip(xs + xo, 0, W - 1)]

        L = flame_len * (0.55 + 0.9 * nl)
        heat = np.clip(1 - d / L, 0, 1)
        heat = np.where(d >= L, -1, heat * (0.55 + 0.85 * nc) - 0.28 * (nf - 0.5) + dither)
        idx = np.digitize(heat, FLAME_THRESH)
        rgba = FLAME_PAL[idx].copy()

        # 火星
        for s in sparks:
            u = (t * s["cycles"] + s["phase"]) % 1.0
            if u > 0.85:
                continue
            y = int(round(s["y0"] - u * s["rise"]))
            x = int(round(s["x0"] + s["sway"] * math.sin(2 * math.pi * (u * 1.5 + s["phase"]))))
            if 0 <= y < H and 0 <= x < W:
                rgba[y, x] = SPARK_PAL[min(3, int(u / 0.85 * 4))]

        # 字身：描边 + 发光边缘 + 底部更热 + 闪烁
        nt = n_text[(ys + f * sp3) % n_text.shape[0], xs]
        th = edge_heat + vert_heat + 0.42 * (nt - 0.5) + dither * 0.5
        tidx = np.digitize(th, TEXT_THRESH)
        rgba[outline] = TEXT_OUTLINE
        rgba[mask] = TEXT_PAL[tidx][mask]
        frames.append(rgba)
    return frames


def write_spriteframes(path: Path, sheet_res: str, n: int, cols: int, fw: int, fh: int, fps: float):
    lines = [f'[gd_resource type="SpriteFrames" load_steps={n + 2} format=3]', "",
             f'[ext_resource type="Texture2D" path="{sheet_res}" id="1_sheet"]', ""]
    for i in range(n):
        x, y = (i % cols) * fw, (i // cols) * fh
        lines += [f'[sub_resource type="AtlasTexture" id="AtlasTexture_{i}"]',
                  'atlas = ExtResource("1_sheet")', f"region = Rect2({x}, {y}, {fw}, {fh})", ""]
    frames = ", ".join(f'{{\n"duration": 1.0,\n"texture": SubResource("AtlasTexture_{i}")\n}}' for i in range(n))
    lines += ["[resource]", "animations = [{", f'"frames": [{frames}],', '"loop": true,',
              '"name": &"default",', f'"speed": {fps:.1f}', "}]", ""]
    path.write_text("\n".join(lines), encoding="utf-8")


def main():
    import sys
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--text", default="人工神灵")
    ap.add_argument("--font", default=r"C:\Windows\Fonts\msyhbd.ttc", help="默认微软雅黑 Bold")
    ap.add_argument("--size", type=int, default=40, help="1x 像素字号")
    ap.add_argument("--frames", type=int, default=24)
    ap.add_argument("--fps", type=float, default=12)
    ap.add_argument("--flame-height", type=float, default=0.75, help="火焰平均高度（相对字号）")
    ap.add_argument("--sparks", type=int, default=18)
    ap.add_argument("--dither", type=float, default=0.06)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--preview-scale", type=int, default=4)
    ap.add_argument("--name", default="burning_title")
    ap.add_argument("--out", default=str(GODOT_ROOT / "assets/sprites/vfx/burning_title"))
    args = ap.parse_args()

    frames = build(args)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    fh, fw = frames[0].shape[:2]
    n = len(frames)
    cols = min(n, 6)
    rows = math.ceil(n / cols)

    sheet = Image.new("RGBA", (cols * fw, rows * fh), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(Image.fromarray(fr, "RGBA"), ((i % cols) * fw, (i // cols) * fh))
    sheet_path = out / f"{args.name}_sheet.png"
    sheet.save(sheet_path)

    res_path = "res://" + sheet_path.resolve().relative_to(GODOT_ROOT).as_posix()
    write_spriteframes(out / f"{args.name}_frames.tres", res_path, n, cols, fw, fh, args.fps)

    s = args.preview_scale
    bg = (14, 6, 8, 255)
    gif_frames = []
    for fr in frames:
        im = Image.new("RGBA", (fw, fh), bg)
        im.alpha_composite(Image.fromarray(fr, "RGBA"))
        gif_frames.append(im.convert("RGB").resize((fw * s, fh * s), Image.NEAREST)
                          .quantize(colors=64, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE))
    gif_frames[0].save(out / f"{args.name}_preview.gif", save_all=True, append_images=gif_frames[1:],
                       duration=round(1000 / args.fps), loop=0, disposal=1, optimize=False)

    print(f"frame {fw}x{fh} x{n} @ {args.fps}fps, sheet {cols}x{rows} -> {out}")


if __name__ == "__main__":
    main()
