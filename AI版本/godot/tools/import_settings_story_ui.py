#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""2026-10-21 04.zip 切图入库：设置面板 I01 + 剧情选择 J01 卡 / J02 返回 / J03 叠层 → assets/ui/gothic/。
用法（在 godot/ 目录）：python -I tools/import_settings_story_ui.py <04 解压目录（含 C01资产 / C02参考）>
修补 / 裁切：
  1. J01 剧情卡（331×1096）上下各有一大段全透明：裁到不透明行 145–952（331×807），参考图里卡顶落在 y=130。
  2. J03 叠层导出为 1921×1081：裁成 1920×1080（最右列 / 最下行是导出多出的一像素）。
  3. 参考图里设置面板上方的徽记、面板底座后面各有一团很淡的暗红光晕，切图里没有：按参考图的范围程序生成
     settings_glow_top.png / settings_glow_bottom.png（椭圆高斯衰减，暗红，中心不透明度 0.32）。
参考整图另存到 docs/reference/ui_04/（不放 assets，免得打进导出包）。
其后：Godot --import → python tools/apply_ui_manifest.py settings_overlay story_select main_menu chapter。"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets" / "ui" / "gothic"
REF = Path(__file__).resolve().parent.parent.parent / "docs" / "reference" / "ui_04"
GLOW_RGB = (176, 44, 56)
GLOW_ALPHA = 0.32


def rgba(p: Path) -> Image.Image:
    return Image.open(p).convert("RGBA")


def glow(w: int, h: int, cx: float, cy: float, rx: float, ry: float) -> Image.Image:
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d2 = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
    a = np.exp(-d2 * 2.2) * GLOW_ALPHA
    out = np.zeros((h, w, 4), np.uint8)
    out[..., 0], out[..., 1], out[..., 2] = GLOW_RGB
    out[..., 3] = np.clip(a * 255.0 + 0.5, 0, 255).astype(np.uint8)
    return Image.fromarray(out)


def main(argv) -> int:
    if len(argv) != 2:
        print(__doc__)
        return 1
    src = Path(argv[1])
    a = src / "C01资产"
    OUT.mkdir(parents=True, exist_ok=True)
    rgba(a / "I01-8.png").save(OUT / "settings_frame.png")
    rgba(a / "J01-8.png").crop((0, 145, 331, 952)).save(OUT / "story_card.png")
    rgba(a / "J02-8.png").save(OUT / "story_back.png")
    rgba(a / "J03-8.png").crop((0, 0, 1920, 1080)).save(OUT / "story_overlay.png")
    glow(1000, 330, 500, 120, 470, 200).save(OUT / "settings_glow_top.png")
    glow(1000, 230, 500, 150, 470, 150).save(OUT / "settings_glow_bottom.png")
    REF.mkdir(parents=True, exist_ok=True)
    for ref, n in {"设置": "design_settings", "剧情选择": "design_story_select"}.items():
        Image.open(src / "C02参考" / f"{ref}.png").convert("RGB").crop((0, 0, 1920, 1080)).save(REF / f"{n}.png")
    print("ok", len(list(OUT.glob("story_*.png"))) + len(list(OUT.glob("settings_*.png"))), "files")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
