#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""2026-10-19 哥特换皮切图入库：把美术交付的切图整理到 assets/ui/gothic/（文件名见 NAMES），并做三处修补。
用法（在 godot/ 目录）：
  python -I tools/import_gothic_ui.py <01 解压目录（含 C01资产 / C02参考）> <E11-8.png> <E12-8.png> <D06-8.png> <主界面整图.png>
修补：
  1. E01（HUD 框体）与 F02（对话框）导出为 1921 宽：裁成 1920（最右一列只有极淡的光晕）；E01 同时裁到 1080 高。
  2. F02 最底 4 行导出成了全透明：用最后一行不透明像素补齐（对话框贴底，不露缝）。
  3. F02 里烘进了「示例文本」：按列在文字带上下两行之间线性插值抹掉（底色是平滑渐变）。
出场卡（按参考整图 HUD.png 量取）：E12 条纹图 = 后片、立绘夹中间、E11 徽记图 = 前片；屏幕只露出后片上 256 / 前片上 126 像素，按此裁切。
主界面整图缩到 2560×1440（铺满视口）。参考整图另存为 design_*.png（导出时按 export_presets 的 design* 规则排除）。
其后：Godot --import → python tools/apply_ui_manifest.py chapter battle_hud dialogue main_menu。"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets" / "ui" / "gothic"
NAMES = {"D01": "level_panel", "D02": "scroll_rail", "D03": "scroll_knob", "D04": "btn_replay", "D05": "btn_enter",
         "E01": "hud_frame", "E02": "objective_header", "E03": "objective_row", "E04": "btn_start", "E05": "btn_pause",
         "E06": "btn_retry", "E07": "btn_exit", "E08": "hex_dark", "E09": "speed_labels", "E10": "hex_gray",
         "F01": "dialogue_next", "F02": "dialogue_box"}
REFS = {"选关": "design_level_select", "HUD": "design_hud", "对话": "design_dialogue"}


def rgba(p) -> Image.Image:
    return Image.open(p).convert("RGBA")


def fix_dialogue_box(im: Image.Image) -> Image.Image:
    a = np.array(im.crop((0, 0, 1920, im.height)))
    last = max(y for y in range(a.shape[0]) if a[y, :, 3].mean() > 200)
    a[last + 1:] = a[last]
    y0, y1, x0, x1 = 336, 428, 370, 1370                # 示例文字带（切图坐标）
    t = np.linspace(0.0, 1.0, y1 - y0 + 1)[:, None, None]
    band = a[y0].astype(np.float32)[None] * (1.0 - t) + a[y1].astype(np.float32)[None] * t
    a[y0:y1 + 1, x0:x1] = band[:, x0:x1].round().astype(np.uint8)
    return Image.fromarray(a)


def main(argv) -> int:
    if len(argv) != 6:
        print(__doc__)
        return 1
    src, e11, e12, d06, menu = (Path(a) for a in argv[1:])
    OUT.mkdir(parents=True, exist_ok=True)
    for k, n in NAMES.items():
        im = rgba(src / "C01资产" / f"{k}-8.png")
        if k == "E01":
            im = im.crop((0, 0, 1920, 1080))
        if k == "F02":
            im = fix_dialogue_box(im)
        im.save(OUT / f"{n}.png")
    rgba(e12).crop((0, 0, 141, 256)).save(OUT / "card_back.png")      # 按参考整图：E12 条纹片在后
    rgba(e11).crop((0, 0, 150, 126)).save(OUT / "card_front.png")     # E11 徽记片在前（遮住立绘下半身）
    rgba(d06).save(OUT / "node_icon.png")
    Image.new("RGBA", (4, 4), (0, 0, 0, 0)).save(OUT / "blank.png")
    Image.open(menu).convert("RGB").resize((2560, 1440), Image.LANCZOS).save(OUT / "menu_bg.png", optimize=True)
    for ref, n in REFS.items():
        rgba(src / "C02参考" / f"{ref}.png").crop((0, 0, 1920, 1080)).convert("RGB").save(OUT / f"{n}.png")
    print(f"已写入 {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
