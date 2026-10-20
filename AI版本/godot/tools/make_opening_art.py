"""开场动画画面（2026-10-20，《开场.docx》）：用游戏里正在使用的素材拼贴 / 调色，生成 assets/cg/opening/*.png。

只用正式素材（剧情立绘、CG、区域背景、主菜单背景、在用的敌人 Q 版图、在用的道具）；不用 review_* / design* / 未接入的图。
统一调色：压暗、去饱和、暗部偏紫黑、亮部偏骨白，保留血红；人物多做成剪影 + 轮廓光，避免 Q 版图放大后的稚气。
画面尺寸 1680×820（屏上显示 1440×703 的取景框，留出镜头缓推的余量）。

用法：python tools/make_opening_art.py            # 全部重画
     python tools/make_opening_art.py p03 p09    # 只画指定画面
     python tools/make_opening_art.py --sheet    # 另外输出一张总览图到 tools/_work/opening_sheet.jpg
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parent.parent
A = ROOT / "assets"
OUT = A / "cg" / "opening"
W, H = 1680, 820

VOID = (8, 7, 10)
BONE = (236, 229, 216)
BLOOD = (179, 26, 44)
EMBER = (255, 90, 102)
COLD = (150, 170, 205)


# ---------------------------------------------------------------- 基础工具

def load(rel: str) -> Image.Image:
    return Image.open(A / rel).convert("RGBA")


def trim(im: Image.Image) -> Image.Image:
    """裁到不透明像素的包围盒；顺手清掉几乎透明的底噪（否则辉光会描出一个矩形）"""
    alpha = im.getchannel("A").point(lambda v: 0 if v < 24 else v)
    im = im.copy()
    im.putalpha(alpha)
    box = alpha.getbbox()
    return im.crop(box) if box else im


def cover(im: Image.Image, w: int = W, h: int = H, fx: float = 0.5, fy: float = 0.5, crop: tuple | None = None) -> Image.Image:
    """裁切 + 缩放铺满 w×h；crop 为原图上的 (x0, y0, x1, y1)，不给则按焦点 (fx, fy) 居中裁"""
    if crop:
        im = im.crop(crop)
    s = max(w / im.width, h / im.height)
    im = im.resize((max(w, round(im.width * s)), max(h, round(im.height * s))), Image.LANCZOS)
    x = round((im.width - w) * fx)
    y = round((im.height - h) * fy)
    return im.crop((x, y, x + w, y + h))


def fit_h(im: Image.Image, h: int) -> Image.Image:
    return im.resize((max(1, round(im.width * h / im.height)), h), Image.LANCZOS)


def arr(im: Image.Image) -> np.ndarray:
    return np.asarray(im.convert("RGBA")).astype(np.float32) / 255.0


def img(a: np.ndarray) -> Image.Image:
    return Image.fromarray((np.clip(a, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8), "RGBA")


def grade(im: Image.Image, exposure: float = 1.0, sat: float = 0.45, shadow=(26, 14, 24), high=BONE,
          tone: float = 0.55, contrast: float = 1.1, keep_red: float = 0.6) -> Image.Image:
    """统一调色：曝光 → 去饱和（红色保留更多）→ 暗紫 / 骨白分离色调 → 对比"""
    a = arr(im)
    rgb = a[..., :3] * exposure
    lum = (rgb @ np.array([0.299, 0.587, 0.114], np.float32))[..., None]
    redness = np.clip((rgb[..., 0:1] - np.maximum(rgb[..., 1:2], rgb[..., 2:3])) * 3.0, 0.0, 1.0)
    s = sat + (1.0 - sat) * keep_red * redness
    rgb = lum + (rgb - lum) * s
    sh = np.array(shadow, np.float32) / 255.0
    hi = np.array(high, np.float32) / 255.0
    l = np.clip(lum, 0.0, 1.0)
    split = sh * (1.0 - l) + hi * l
    rgb = rgb * (1.0 - tone) + split * l * 1.05 * tone + rgb * 0.0
    rgb = rgb + (sh * (1.0 - l) ** 3) * tone * 0.6
    rgb = np.clip((rgb - 0.5) * contrast + 0.5, 0.0, 1.0)
    a[..., :3] = rgb
    return img(a)


def silhouette(im: Image.Image, color=VOID, detail: float = 0.12) -> Image.Image:
    a = arr(im)
    c = np.array(color, np.float32) / 255.0
    a[..., :3] = a[..., :3] * detail + c * (1.0 - detail)
    return img(a)


def rim(im: Image.Image, color, dx: float, dy: float, width: float = 3.0, strength: float = 1.0) -> Image.Image:
    """轮廓光：光从 (dx, dy) 反方向照来时被照亮的边"""
    alpha = im.getchannel("A")
    shifted = ImageChops.offset(alpha, round(dx), round(dy))
    edge = ImageChops.subtract(alpha, shifted).filter(ImageFilter.GaussianBlur(width))
    edge = ImageChops.multiply(edge, alpha)
    edge = edge.point(lambda v: min(255, int(v * strength)))
    layer = Image.new("RGBA", im.size, color + (0,))
    layer.putalpha(edge)
    return layer


def lit_figure(im: Image.Image, h: int, rim_color, light=(-1.0, -1.0), detail: float = 0.12,
               body=VOID, rim_w: float = 3.0, rim_strength: float = 1.6) -> Image.Image:
    """立绘 → 指定高度的剪影 + 轮廓光"""
    f = fit_h(trim(im), h)
    s = silhouette(f, body, detail)
    k = max(4.0, h / 90.0)
    s.alpha_composite(rim(f, rim_color, -light[0] * k, -light[1] * k, rim_w, rim_strength))
    return s


def glow_of(im: Image.Image, color, radius: float, strength: float = 1.0) -> Image.Image:
    alpha = im.getchannel("A").filter(ImageFilter.GaussianBlur(radius)).point(lambda v: min(255, int(v * strength)))
    g = Image.new("RGBA", im.size, color + (0,))
    g.putalpha(alpha)
    return g


def paste(base: Image.Image, layer: Image.Image, cx: float, bottom: float, glow=None) -> None:
    """以底边中点 (cx, bottom) 贴上（可先贴一层辉光）"""
    x = round(cx - layer.width / 2)
    y = round(bottom - layer.height)
    if glow:
        pad = int(glow[1] * 3)
        g = Image.new("RGBA", (layer.width + pad * 2, layer.height + pad * 2), (0, 0, 0, 0))
        g.paste(layer, (pad, pad))
        _composite_clip(base, glow_of(g, glow[0], glow[1], glow[2] if len(glow) > 2 else 1.0), x - pad, y - pad)
    _composite_clip(base, layer, x, y)


def _composite_clip(base: Image.Image, layer: Image.Image, x: int, y: int) -> None:
    """alpha_composite 不接受负坐标：先裁掉画外部分"""
    x0, y0 = max(0, -x), max(0, -y)
    x1, y1 = min(layer.width, base.width - x), min(layer.height, base.height - y)
    if x1 <= x0 or y1 <= y0:
        return
    base.alpha_composite(layer.crop((x0, y0, x1, y1)), (x + x0, y + y0))


def add(base: Image.Image, layer: Image.Image) -> Image.Image:
    """加色混合（光）"""
    b = arr(base)
    l = arr(layer)
    b[..., :3] = b[..., :3] + l[..., :3] * l[..., 3:4]
    return img(b)


def radial(color, cx: float, cy: float, r: float, strength: float = 1.0, size=(W, H), squash: float = 1.0) -> Image.Image:
    yy, xx = np.mgrid[0:size[1], 0:size[0]].astype(np.float32)
    d = np.sqrt(((xx - cx) / r) ** 2 + ((yy - cy) / (r * squash)) ** 2)
    a = np.clip(1.0 - d, 0.0, 1.0) ** 2 * strength
    out = np.zeros((size[1], size[0], 4), np.float32)
    out[..., :3] = np.array(color, np.float32) / 255.0
    out[..., 3] = np.clip(a, 0.0, 1.0)
    return img(out)


def beam(cx: float, top_w: float, bottom_w: float, color, strength: float = 0.8, blur: float = 40.0, y0: float = -40, y1: float = H) -> Image.Image:
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    d.polygon([(cx - top_w / 2, y0), (cx + top_w / 2, y0), (cx + bottom_w / 2, y1), (cx - bottom_w / 2, y1)], fill=int(255 * strength))
    # 自上而下渐弱
    fade = Image.linear_gradient("L").resize((W, H)).point(lambda v: 255 - int(v * 0.55))
    m = ImageChops.multiply(m, fade).filter(ImageFilter.GaussianBlur(blur))
    layer = Image.new("RGBA", (W, H), color + (0,))
    layer.putalpha(m)
    return layer


def vignette(im: Image.Image, strength: float = 0.75, inner: float = 0.35) -> Image.Image:
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    d = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2) / math.sqrt(2)
    v = 1.0 - strength * np.clip((d - inner) / (1.0 - inner), 0.0, 1.0) ** 1.6
    a = arr(im)
    a[..., :3] *= v[..., None]
    return img(a)


def tint(im: Image.Image, color, amount: float) -> Image.Image:
    a = arr(im)
    c = np.array(color, np.float32) / 255.0
    lum = (a[..., :3] @ np.array([0.299, 0.587, 0.114], np.float32))[..., None]
    a[..., :3] = a[..., :3] * (1.0 - amount) + c * lum * 1.6 * amount
    return img(a)


def solid(color=VOID) -> Image.Image:
    return Image.new("RGBA", (W, H), color + (255,))


def dust(base: Image.Image, n: int, color, seed: int, rmax: float = 2.4, alpha: float = 0.6, region=(0, 0, W, H)) -> None:
    rnd = random.Random(seed)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(n):
        x = rnd.uniform(region[0], region[2])
        y = rnd.uniform(region[1], region[3])
        r = rnd.uniform(0.6, rmax)
        d.ellipse((x - r, y - r, x + r, y + r), fill=color + (int(255 * alpha * rnd.uniform(0.3, 1.0)),))
    base.alpha_composite(layer.filter(ImageFilter.GaussianBlur(0.8)))


def diamond(d: ImageDraw.ImageDraw, cx: float, cy: float, w: float, h: float, fill) -> None:
    d.polygon([(cx, cy - h), (cx + w, cy), (cx, cy + h), (cx - w, cy)], fill=fill)


def ripple(im: Image.Image, amp: float, freq: float, seed: int) -> Image.Image:
    """把剪影扭成畸形：正弦位移 + 随机块状挤压"""
    a = arr(im)
    h, w = a.shape[:2]
    rnd = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    ph = rnd.uniform(0, 6.28, 4)
    dx = amp * (np.sin(yy * freq + ph[0]) + 0.6 * np.sin(yy * freq * 2.7 + xx * freq * 0.8 + ph[1]))
    dy = amp * 0.7 * (np.sin(xx * freq * 1.3 + ph[2]) + 0.5 * np.sin(xx * freq * 3.1 + yy * freq + ph[3]))
    sx = np.clip(xx + dx, 0, w - 1).astype(np.int32)
    sy = np.clip(yy + dy, 0, h - 1).astype(np.int32)
    return img(a[sy, sx])


def glitch(im: Image.Image, seed: int, bands: int = 18, shift: int = 26) -> Image.Image:
    """横向错位条 + 红青分离"""
    a = arr(im)
    rnd = random.Random(seed)
    for _ in range(bands):
        y = rnd.randrange(0, H - 8)
        hgt = rnd.randrange(3, 26)
        s = rnd.randint(-shift, shift)
        a[y:y + hgt] = np.roll(a[y:y + hgt], s, axis=1)
    r = np.roll(a[..., 0], 5, axis=1)
    b = np.roll(a[..., 2], -5, axis=1)
    a[..., 0] = r
    a[..., 2] = b
    return img(a)


def clouds(seed: int, dark, light, cover_frac: float = 1.0) -> Image.Image:
    """程序生成的翻涌云层（分形值噪声）；cover_frac < 1 时只铺上方、向下渐隐"""
    rng = np.random.default_rng(seed)
    acc = np.zeros((H, W), np.float32)
    amp, total = 1.0, 0.0
    for octave in range(6):
        gw, gh = 4 * 2 ** octave, 2 * 2 ** octave
        g = Image.fromarray((rng.random((gh + 1, gw + 1)) * 255).astype(np.uint8), "L")
        acc += np.asarray(g.resize((W, H), Image.BICUBIC), np.float32) / 255.0 * amp
        total += amp
        amp *= 0.55
    n = acc / total
    n = np.clip((n - 0.3) / 0.45, 0.0, 1.0) ** 1.4
    d = np.array(dark, np.float32) / 255.0
    l = np.array(light, np.float32) / 255.0
    out = np.ones((H, W, 4), np.float32)
    out[..., :3] = d + (l - d) * n[..., None]
    if cover_frac < 1.0:
        yy = np.linspace(0.0, 1.0, H, dtype=np.float32)[:, None]
        out[..., 3] = np.clip((cover_frac - yy) / 0.25 + 0.0, 0.0, 1.0) * np.ones((1, W), np.float32)
    return img(out)


def finish(im: Image.Image, v: float = 0.7) -> Image.Image:
    return vignette(im, v).convert("RGB")


# ---------------------------------------------------------------- 各画面

def p01() -> Image.Image:
    """一位神，踏进了这方世界。——云层裂开，一道光柱落地"""
    base = grade(cover(load("backdrops/regions/grey_thorn.png"), fy=0.8).filter(ImageFilter.GaussianBlur(4)),
                 exposure=0.3, sat=0.2, tone=0.6)
    base.alpha_composite(clouds(1, (12, 9, 16), (92, 76, 96), 0.7))
    base = add(base, beam(W * 0.55, 120, 420, (255, 236, 200), 0.85, 46))
    base = add(base, beam(W * 0.55, 30, 120, (255, 250, 236), 0.9, 14))
    base = add(base, radial((255, 225, 180), W * 0.55, H * 0.98, 520, 0.85, squash=0.22))
    base = add(base, radial((255, 236, 210), W * 0.55, -40, 360, 0.6, squash=0.45))
    dust(base, 260, (255, 236, 205), 11, 2.2, 0.55, (W * 0.35, 0, W * 0.75, H))
    return finish(base)


def p02() -> Image.Image:
    """以血肉为泥，捏出精灵、巨兽与神话的种族——血肉沼泽上站起一排造物"""
    base = grade(cover(load("backdrops/regions/flesh_swamp.png")).filter(ImageFilter.GaussianBlur(4)),
                 exposure=0.5, sat=0.55, tone=0.45, keep_red=0.9)
    base = add(base, beam(W * 0.5, 300, 900, (255, 222, 190), 0.35, 70))
    row = [("marrow_hulk", 560, 0.10), ("brute", 470, 0.25), ("bone_guard", 520, 0.40), ("hound", 380, 0.56),
           ("spitter", 460, 0.72), ("husk", 380, 0.88)]
    for i, (name, h, x) in enumerate(row):
        f = lit_figure(load(f"sprites/units/{name}.png"), h, (255, 214, 180), (0.3 * (x - 0.5) * 4, -1.0), detail=0.04,
                       body=(18, 6, 10), rim_w=2.5, rim_strength=1.3)
        paste(base, f, W * x, H * 0.98 + (i % 2) * 14, glow=((120, 20, 30), 16, 0.6))
    base.alpha_composite(radial((40, 6, 12), W * 0.5, H * 1.05, 900, 0.75, squash=0.25))
    dust(base, 120, (255, 140, 120), 22, 2.0, 0.5)
    return finish(base, 0.75)


def _bell_witch_scene(red: bool) -> Image.Image:
    base = solid((14, 10, 14))
    base = add(base, radial((90, 60, 70), W * 0.5, H * 0.55, 700, 0.6, squash=0.6))
    bw = trim(load("sprites/illustrations/bell_witch.png"))
    fig = fit_h(bw, 700)
    if red:
        fig = tint(grade(fig, exposure=0.85, sat=0.6, tone=0.3, keep_red=1.0), BLOOD, 0.45)
        base = add(base, radial((200, 20, 40), W * 0.5, H * 0.62, 560, 0.75, squash=0.7))
        paste(base, fig, W * 0.5, H * 0.95, glow=((255, 60, 70), 26, 1.4))
        base = add(base, radial((255, 90, 90), W * 0.5, H * 0.55, 260, 0.35))
        dust(base, 320, (255, 80, 80), 33, 2.6, 0.75)
    else:
        fig = grade(fig, exposure=0.95, sat=0.5, tone=0.45)
        base = add(base, beam(W * 0.5, 160, 700, (255, 240, 220), 0.55, 50))
        paste(base, fig, W * 0.5, H * 0.95, glow=((255, 236, 210), 22, 0.6))
        dust(base, 180, (255, 240, 220), 31, 2.0, 0.55, (W * 0.3, 0, W * 0.7, H))
    return base


def p03() -> Image.Image:
    """祂赐“祝福”给一些对情绪格外敏感的人。"""
    return finish(_bell_witch_scene(False), 0.8)


def p03b() -> Image.Image:
    """极端的情绪爆发 → 觉醒为魔女"""
    return finish(_bell_witch_scene(True), 0.8)


def p04() -> Image.Image:
    """魔女领悟术法：用情绪驱动血肉与骨骼——守火的魔女，胸口燃起红色的魂火"""
    base = grade(cover(load("backdrops/regions/grey_thorn.png")).filter(ImageFilter.GaussianBlur(5)),
                 exposure=0.4, sat=0.25, tone=0.6)
    fig = lit_figure(load("sprites/illustrations/keeper.png"), 790, EMBER, (0.0, 0.6), detail=0.42, body=(22, 12, 16),
                     rim_w=4, rim_strength=2.2)
    paste(base, fig, W * 0.5, H + 20, glow=((220, 30, 50), 30, 0.9))
    base = add(base, radial((255, 60, 70), W * 0.5, H * 0.42, 150, 1.0))
    base = add(base, radial((255, 200, 190), W * 0.5, H * 0.42, 40, 1.0))
    dust(base, 260, (255, 90, 90), 44, 2.4, 0.7, (W * 0.25, 0, W * 0.75, H))
    return finish(base, 0.8)


def p05() -> Image.Image:
    """堕落为畸变的怪物——骨花魔女"""
    base = grade(cover(load("backdrops/regions/flesh_swamp.png"), fy=0.2).filter(ImageFilter.GaussianBlur(8)),
                 exposure=0.32, sat=0.6, tone=0.4, keep_red=1.0)
    fig = fit_h(trim(load("sprites/illustrations/bone_witch.png")), 800)
    fig = grade(fig, exposure=0.85, sat=0.6, tone=0.35, keep_red=1.0)
    paste(base, rim(fig, EMBER, 6, 6, 3, 1.2), W * 0.5, H + 30)
    paste(base, fig, W * 0.5, H + 30, glow=((200, 20, 40), 34, 1.1))
    base = glitch(base, 55, bands=10, shift=14)
    dust(base, 200, (255, 120, 120), 55, 2.2, 0.55)
    return finish(base, 0.85)


def p06() -> Image.Image:
    """另一道神启悄然降临：缄默者——冷光中的高大剪影"""
    base = grade(cover(load("backdrops/regions/grey_thorn.png"), fy=0.3).filter(ImageFilter.GaussianBlur(3)),
                 exposure=0.42, sat=0.15, shadow=(10, 14, 22), high=(200, 214, 236), tone=0.7)
    base = add(base, beam(W * 0.5, 80, 520, (190, 210, 240), 0.45, 50))
    fig = lit_figure(load("sprites/illustrations/bone_elder.png"), 780, COLD, (0.0, -1.0), detail=0.06,
                     body=(8, 10, 16), rim_w=3, rim_strength=2.4)
    paste(base, fig, W * 0.5, H + 10, glow=((170, 195, 235), 20, 0.7))
    dust(base, 240, (210, 225, 250), 66, 1.8, 0.6)
    return finish(base, 0.8)


def _maw(exposure: float, sat: float) -> Image.Image:
    return grade(cover(load("backdrops/regions/warped_corridor.png")), exposure=exposure, sat=sat,
                 shadow=(30, 6, 12), high=(240, 190, 180), tone=0.45, keep_red=1.0, contrast=1.2)


def p07() -> Image.Image:
    """血肉神以负面情绪为食——巨口与坠落的魔女们"""
    base = _maw(0.62, 0.7)
    base = add(base, radial((255, 40, 60), W * 0.5, H * 0.5, 420, 0.5, squash=0.6))
    rnd = random.Random(77)
    names = ["bell_witch", "bone_witch", "keeper", "witch_shadow", "bell_witch", "keeper", "bone_witch"]
    for i, n in enumerate(names):
        f = trim(load(f"sprites/illustrations/{n}.png"))
        h = rnd.randint(110, 260)
        f = silhouette(fit_h(f, h), (16, 4, 8), 0.08).rotate(rnd.uniform(-160, 160), expand=True, resample=Image.BICUBIC)
        ang = i / len(names) * math.tau + rnd.uniform(-0.3, 0.3)
        r = rnd.uniform(220, 520)
        cx = W * 0.5 + math.cos(ang) * r * 1.3
        cy = H * 0.5 + math.sin(ang) * r * 0.55
        paste(base, f, cx, cy + f.height / 2, glow=((255, 80, 90), 10, 0.8))
    return finish(base, 0.85)


def p08() -> Image.Image:
    """魔女们的祭祀——圣钟废墟，魂灯围成一圈"""
    base = grade(cover(load("backdrops/regions/holy_bell.png"), fy=0.4), exposure=0.42, sat=0.4,
                 shadow=(12, 10, 24), high=(220, 200, 230), tone=0.6)
    cx, cy = W * 0.5, H * 0.66
    ring = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(ring)
    for k, (rx, ry, wd) in enumerate([(520, 150, 4), (440, 125, 2), (330, 92, 3)]):
        d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), outline=(255, 70, 80, 230), width=wd)
    for i in range(12):
        a = i / 12 * math.tau
        diamond(d, cx + math.cos(a) * 480, cy + math.sin(a) * 138, 9, 14, (255, 110, 110, 255))
    base = add(base, ring.filter(ImageFilter.GaussianBlur(10)))
    base.alpha_composite(ring)
    base = add(base, radial((255, 50, 70), cx, cy, 560, 0.55, squash=0.3))
    base = add(base, beam(cx, 30, 200, (255, 120, 120), 0.5, 26, y1=cy))
    lamp = grade(fit_h(trim(load("sprites/props/soul_lamp_lit.png")), 120), exposure=0.9, sat=0.7, tone=0.2)
    # 魔女站在法阵后半圈（正后方留给光柱），魂灯围一整圈；全部按脚底 y 由远到近绘制，近的挡住远的
    props = []
    for name, deg in [("keeper_witch", 196), ("bell_witch", 232), ("bone_witch", 308), ("hexer", 344)]:
        a = math.radians(deg)
        x, y = cx + math.cos(a) * 470, cy + math.sin(a) * 128
        src = load(f"sprites/units/{name}.png")
        if x > cx:                           # 这几张 Q 版图原本都朝右：站在右半圈的镜像，全部面向法阵中心
            src = ImageOps.mirror(src)
        w = lit_figure(src, 220, (255, 130, 120), (math.cos(a), 0.2), detail=0.1, body=(14, 8, 14))
        props.append((y, w, x, None))
    for i in range(6):
        a = i / 6 * math.tau + 0.26
        x, y = cx + math.cos(a) * 560, cy + math.sin(a) * 160
        props.append((y, lamp, x, ((140, 200, 255), 16, 1.2)))
    for y, im, x, glow in sorted(props, key=lambda t: t[0]):
        paste(base, im, x, y + 8, glow=glow)
    dust(base, 200, (255, 140, 140), 88, 2.0, 0.6)
    return finish(base, 0.8)


def _storm_sky() -> Image.Image:
    sky = grade(cover(load("backdrops/regions/flesh_swamp.png"), fy=0.9).filter(ImageFilter.GaussianBlur(5)),
                exposure=0.3, sat=0.5, tone=0.5, keep_red=1.0)
    sky.alpha_composite(clouds(9, (16, 4, 8), (150, 40, 50), 0.8))
    return add(sky, radial((255, 60, 60), W * 0.5, H * 0.35, 700, 0.45, squash=0.5))


def p09() -> Image.Image:
    """神战：血色天空下的缄默者（随后被撕碎）"""
    base = _storm_sky()
    fig = lit_figure(load("sprites/illustrations/bone_elder.png"), 820, BONE, (0.0, -0.4), detail=0.05,
                     body=(10, 6, 10), rim_w=3, rim_strength=2.6)
    paste(base, fig, W * 0.5, H + 30, glow=((255, 200, 190), 26, 0.8))
    return finish(base, 0.75)


def p09b() -> Image.Image:
    """碎片落满世界"""
    base = _storm_sky()
    shards = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(shards)
    rnd = random.Random(99)
    for _ in range(170):
        x, y = rnd.uniform(0, W), rnd.uniform(0, H)
        s = rnd.uniform(3, 15)
        diamond(d, x, y, s * 0.6, s, (236, 229, 216, rnd.randint(110, 255)))
    base = add(base, shards.filter(ImageFilter.GaussianBlur(6)))
    base.alpha_composite(shards)
    return finish(base, 0.75)


def p10() -> Image.Image:
    """血肉神被重创，沉睡，没有死。"""
    base = _maw(0.38, 0.35).filter(ImageFilter.GaussianBlur(3))
    base = add(base, radial((120, 10, 24), W * 0.5, H * 0.5, 380, 0.4, squash=0.5))
    return finish(base, 0.9)


def p12() -> Image.Image:
    """三百年后，种族回来了——不是造物，是畸形的血肉"""
    base = grade(cover(load("backdrops/regions/flesh_swamp.png"), fy=0.7).filter(ImageFilter.GaussianBlur(3)),
                 exposure=0.38, sat=0.45, tone=0.5, keep_red=0.9)
    row = [("marrow_hulk", 600, 0.12), ("brute", 520, 0.30), ("bone_guard", 560, 0.47), ("hound", 420, 0.62),
           ("spitter", 500, 0.77), ("husk", 420, 0.92)]
    for i, (name, h, x) in enumerate(row):
        f = fit_h(trim(load(f"sprites/units/{name}.png")), h)
        f = ripple(tint(grade(f, exposure=0.7, sat=0.5, tone=0.3), (150, 40, 50), 0.6), h * 0.03, 0.045, i)
        paste(base, f, W * x, H * 1.0 + (i % 2) * 18, glow=((150, 10, 30), 22, 1.0))
    base.alpha_composite(radial((10, 2, 4), W * 0.5, H * 1.1, 900, 0.7, squash=0.25))
    return finish(glitch(base, 120, bands=8, shift=12), 0.85)


def p13() -> Image.Image:
    """诅咒与怪物一同回归，且更加诡异"""
    return finish(glitch(_bell_witch_scene(True), 130, bands=26, shift=34), 0.85)


def p14() -> Image.Image:
    """世界正在烂掉。——枯骨农田，压上阴云"""
    farm = cover(load("backdrops/regions/withered_farm.png"), fy=0.6).filter(ImageFilter.GaussianBlur(2))
    base = grade(farm, exposure=0.55, sat=0.3, shadow=(20, 14, 12), high=(214, 200, 170), tone=0.6, keep_red=0.8)
    base.alpha_composite(clouds(14, (14, 10, 12), (80, 68, 60), 0.32))
    for name, h, x, y in [("husk", 150, 0.3, 0.74), ("hound", 120, 0.62, 0.7), ("husk", 110, 0.78, 0.66), ("spitter", 90, 0.46, 0.62)]:
        f = lit_figure(load(f"sprites/units/{name}.png"), h, (190, 170, 150), (0.0, -1.0), detail=0.05, body=(16, 12, 12),
                       rim_w=2, rim_strength=1.0)
        paste(base, f, W * x, H * y)
    base.alpha_composite(radial((12, 9, 10), W * 0.5, H * 0.75, 1100, 0.35, squash=0.3))
    dust(base, 300, (200, 190, 180), 140, 1.8, 0.45)
    return finish(base, 0.7)


def p15() -> Image.Image:
    """织骸魔女——剪影，红线自她手中散开"""
    base = solid((12, 8, 11))
    base = add(base, radial((110, 20, 34), W * 0.5, H * 0.6, 640, 0.6, squash=0.7))
    threads = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(threads)
    rnd = random.Random(150)
    for i in range(26):
        sx, sy = W * 0.5 + rnd.uniform(-90, 90), H * 0.55 + rnd.uniform(-60, 60)
        ex = rnd.choice([-80, W + 80]) if i % 3 else rnd.uniform(0, W)
        ey = rnd.uniform(-60, H + 60) if i % 3 else rnd.choice([-60, H + 60])
        mx, my = (sx + ex) / 2 + rnd.uniform(-160, 160), (sy + ey) / 2 + rnd.uniform(-120, 120)
        pts = [((1 - t) ** 2 * sx + 2 * (1 - t) * t * mx + t * t * ex, (1 - t) ** 2 * sy + 2 * (1 - t) * t * my + t * t * ey)
               for t in [k / 40 for k in range(41)]]
        d.line(pts, fill=(200, 30, 50, rnd.randint(120, 230)), width=rnd.choice([1, 2, 2, 3]))
    base = add(base, threads.filter(ImageFilter.GaussianBlur(5)))
    base.alpha_composite(threads)
    fig = fit_h(trim(load("sprites/illustrations/witch_shadow.png")), 800)
    paste(base, fig, W * 0.5, H + 30, glow=((200, 30, 50), 22, 0.9))
    dust(base, 160, (255, 110, 110), 151, 2.0, 0.5)
    return finish(base, 0.8)


def p16() -> Image.Image:
    """容器——吊在提线上的人偶，胸口一枚红菱"""
    base = solid((12, 10, 12))
    base = add(base, beam(W * 0.5, 260, 760, (236, 229, 216), 0.3, 60))
    doll = grade(fit_h(trim(load("sprites/illustrations/doll.png")), 700), exposure=0.95, sat=0.6, tone=0.3, keep_red=1.0)
    top = H - 30 - doll.height
    d = ImageDraw.Draw(base)
    bar_y = 34
    d.rectangle((W * 0.5 - 240, bar_y, W * 0.5 + 240, bar_y + 10), fill=BONE + (255,))
    d.rectangle((W * 0.5 - 5, 0, W * 0.5 + 5, bar_y + 10), fill=BONE + (255,))
    for sx, ex, ey in [(-230, -150, top + doll.height * 0.42), (0, 0, top + 40), (230, 150, top + doll.height * 0.42),
                       (-120, -70, top + doll.height * 0.9), (120, 70, top + doll.height * 0.9)]:
        d.line([(W * 0.5 + sx, bar_y + 10), (W * 0.5 + ex, ey)], fill=BONE + (170,), width=2)
    paste(base, doll, W * 0.5, H - 30, glow=((236, 229, 216), 18, 0.45))
    cy = top + doll.height * 0.36
    base = add(base, radial((255, 40, 60), W * 0.5, cy, 110, 0.9))
    gem = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    diamond(ImageDraw.Draw(gem), W * 0.5, cy, 14, 22, BLOOD + (255,))
    base.alpha_composite(gem)
    dust(base, 140, (236, 229, 216), 160, 1.8, 0.45)
    return finish(base, 0.8)


PANELS = {
    "p01": p01, "p02": p02, "p03": p03, "p03b": p03b, "p04": p04, "p05": p05, "p06": p06, "p07": p07,
    "p08": p08, "p09": p09, "p09b": p09b, "p10": p10, "p12": p12, "p13": p13, "p14": p14, "p15": p15,
    "p16": p16,
}


def main(argv: list[str]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    want = [a for a in argv if not a.startswith("--")] or list(PANELS)
    for key in want:
        im = PANELS[key]()
        im.save(OUT / f"{key}.png", optimize=True)
        print("wrote", (OUT / f"{key}.png").relative_to(ROOT))
    if "--sheet" in argv:
        files = sorted(OUT.glob("*.png"))
        cols, cw = 4, 420
        ch = round(cw * H / W)
        sheet = Image.new("RGB", (cols * cw, ((len(files) + cols - 1) // cols) * (ch + 18)), (30, 30, 30))
        dr = ImageDraw.Draw(sheet)
        for i, f in enumerate(files):
            t = Image.open(f).convert("RGB").resize((cw, ch))
            x, y = (i % cols) * cw, (i // cols) * (ch + 18)
            sheet.paste(t, (x, y))
            dr.text((x + 4, y + ch + 3), f.stem, fill=(255, 255, 0))
        work = ROOT / "tools" / "_work"
        work.mkdir(exist_ok=True)
        sheet.save(work / "opening_sheet.jpg", quality=88)
        print("sheet: tools/_work/opening_sheet.jpg")


if __name__ == "__main__":
    main(sys.argv[1:])
