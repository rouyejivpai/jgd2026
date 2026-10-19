#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""2026-10-19：建筑 / 目标物 Q 版图（按 QQ人 / 物件画风用 gpt-image 生成，参考图为白袍女、守火魂灯、静息祭坛）。
源：tools/_raw/structures/sheet.png（2 × 2，洋红 #FF00FF 底，不入库）。
抠图：按「洋红程度」min(R, B) − G 生成 alpha（紫色玻璃约 80，不会被抠掉），半透明边去洋红溢色；每格只留最大连通块及其附属。
输出到 work/美术资源_20261019/生成_建筑/<名>.png（透明底），再由 tools/import_qq_art.py 放入单位画布与头像。
顺序：左上 transit_node 转运点、右上 echo_pillar 回响骸柱、左下 dummy 试作人偶、右下 supply_crate 物资箱。
用法（godot/ 目录）：python tools/make_structures.py
"""
import io
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
GODOT = Path(__file__).resolve().parent.parent
SHEET = GODOT / "tools/_raw/structures/sheet.png"
OUT = GODOT.parent / "work/美术资源_20261019/生成_建筑"
NAMES = ["transit_node", "echo_pillar", "dummy", "supply_crate"]
KEY_LO, KEY_HI = 110.0, 190.0     # 洋红程度：低于 LO 完全保留，高于 HI 完全抠掉


def key_out(rgb: np.ndarray) -> np.ndarray:
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    m = np.minimum(r, b) - g
    alpha = 1.0 - np.clip((m - KEY_LO) / (KEY_HI - KEY_LO), 0.0, 1.0)
    out = rgb.copy()
    a = np.maximum(alpha, 1e-3)[..., None]
    magenta = np.array([255.0, 0.0, 255.0])
    out = (rgb - (1.0 - a) * magenta) / a              # 去掉与洋红底的混色
    return np.dstack([np.clip(out, 0, 255), alpha * 255.0]).astype(np.uint8)


def main() -> int:
    import cv2
    sheet = np.array(Image.open(SHEET).convert("RGB")).astype(np.float32)
    h, w = sheet.shape[:2]
    OUT.mkdir(parents=True, exist_ok=True)
    for i, name in enumerate(NAMES):
        cx, cy = i % 2, i // 2
        cell = key_out(sheet[cy * h // 2:(cy + 1) * h // 2, cx * w // 2:(cx + 1) * w // 2])
        n, lab, st, _ = cv2.connectedComponentsWithStats((cell[..., 3] > 40).astype(np.uint8), 8)
        areas = st[1:, cv2.CC_STAT_AREA]
        keep = [k + 1 for k, a in enumerate(areas) if a >= areas.max() * 0.01]
        cell[..., 3] = np.where(np.isin(lab, keep), cell[..., 3], 0)
        im = Image.fromarray(cell, "RGBA")
        im = im.crop(im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())
        im.save(OUT / f"{name}.png")
        print("→", OUT / f"{name}.png", im.size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
