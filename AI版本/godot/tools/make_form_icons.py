#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""2026-10-19：己方六形态的纯色图标（区分共用人偶图的形态）。
源：tools/_raw/form_icons/sheet.png（gpt-image 生成的 3 列 × 2 行纯黑剪影、白底，不入库）。
输出 assets/sprites/form_icons/（已烘焙颜色，游戏里只做亮度调制）：
  <form>_solid.png  实心剪影，金色 → 形态标志色 的斜向渐变（图标外框内：左上角金、主体标志色；混色保持亮度，金蓝之间不发灰），256×256；战场环绕用
  <form>.png        同一剪影 + 烘焙的柔和外发光（发光色 = 标志色）；头像 / 卡面用
形态标志色（用户 2026-10-19：各不相同，与金色渐变，玩家凭颜色区分形态；2026-10-21 改为与人偶差分的描边色一致）见 FORM_COLORS。
顺序（左→右、上→下）：基础攻击 striker、承伤 bulwark、快速 swift、远射 lancer、咒术 hexer、缚锁 binder。
用法（godot/ 目录）：python tools/make_form_icons.py
"""
import io
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
GODOT = Path(__file__).resolve().parent.parent
SHEET = GODOT / "tools/_raw/form_icons/sheet.png"
OUT = GODOT / "assets/sprites/form_icons"
FORMS = ["striker", "bulwark", "swift", "lancer", "hexer", "binder"]
GOLD = np.array([255, 200, 80], dtype=np.float32)
FORM_COLORS = {                    # 标志色 = 人偶差分描边色（2026-10-21 用户：图标颜色与描边一致；取自描边像素中位数）
    "striker": (255, 188, 109),    # 基础攻击：橙
    "bulwark": (121, 178, 255),    # 承伤：蓝
    "swift": (142, 255, 236),      # 快速：青
    "lancer": (103, 186, 69),      # 远射：绿
    "hexer": (151, 53, 255),       # 咒术：紫
    "binder": (255, 41, 54),       # 缚锁：红
}
GRAD_START, GRAD_END = 0.15, 0.8   # 渐变区间（在图标自身外框内，沿左上 → 右下对角线的比例）：左上角金色，主体为标志色
SIZE = 256
PAD = 0.2          # 外发光留边（占画布比例）
GLOW_RADIUS = 9    # 外发光模糊半径（输出像素）
GLOW_ALPHA = 0.55


def main() -> int:
    sheet = Image.open(SHEET).convert("L")
    w, h = sheet.size
    OUT.mkdir(parents=True, exist_ok=True)
    for i, form in enumerate(FORMS):
        cx, cy = i % 3, i // 3
        cell = sheet.crop((cx * w // 3, cy * h // 2, (cx + 1) * w // 3, (cy + 1) * h // 2))
        ink = Image.fromarray((255 - np.array(cell)).astype(np.uint8))     # 黑 → 不透明
        ink = ink.point(lambda v: 0 if v < 40 else min(255, int((v - 40) * 255 / 160)))
        bb = ink.point(lambda v: 255 if v > 64 else 0).getbbox()
        ink = ink.crop(bb)
        inner = int(SIZE * (1 - PAD * 2))
        k = inner / max(ink.size)
        ink = ink.resize((max(1, round(ink.width * k)), max(1, round(ink.height * k))), Image.LANCZOS)
        alpha = Image.new("L", (SIZE, SIZE), 0)
        alpha.paste(ink, ((SIZE - ink.width) // 2, (SIZE - ink.height) // 2))
        sig = np.array(FORM_COLORS[form], dtype=np.float32)
        x0, y0, x1, y1 = alpha.getbbox()
        yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
        diag = ((xx - x0) / max(x1 - x0, 1) + (yy - y0) / max(y1 - y0, 1)) * 0.5
        t = np.clip((diag - GRAD_START) / (GRAD_END - GRAD_START), 0.0, 1.0)[..., None]
        t = t * t * (3.0 - 2.0 * t)
        rgb = GOLD * (1.0 - t) + sig * t
        peak = np.max(GOLD) * (1.0 - t) + np.max(sig) * t          # 混色后按两端的最亮通道恢复亮度
        rgb = rgb * (peak / np.maximum(rgb.max(axis=2, keepdims=True), 1.0))
        a_shape = np.array(alpha, dtype=np.float32)
        Image.fromarray(np.dstack([rgb, a_shape]).clip(0, 255).astype(np.uint8), "RGBA").save(OUT / f"{form}_solid.png")
        glow = np.array(alpha.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(GLOW_RADIUS)), dtype=np.float32) * GLOW_ALPHA
        halo = sig
        w_shape = (a_shape / 255.0)[..., None]
        rgb_glow = rgb * w_shape + halo * (1.0 - w_shape)        # 形状内为渐变色，形状外发光为中间色
        a = np.maximum(a_shape, glow)
        Image.fromarray(np.dstack([rgb_glow, a]).clip(0, 255).astype(np.uint8), "RGBA").save(OUT / f"{form}.png")
        print("→", (OUT / f"{form}.png").relative_to(GODOT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
