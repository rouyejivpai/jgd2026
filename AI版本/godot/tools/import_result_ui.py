#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""结算界面切图入库（03.zip，2026-10-20）。
用法（在 godot/ 目录）：python -I tools/import_result_ui.py <03 解压目录（含 C01资产）>
  H01 结算框体 → assets/ui/gothic/result_frame.png（框里烘进的「战斗胜利」抹掉：胜利 / 保护成功 / 失败共用一张框，标题由程序写）
  H02 返回选关 / H03 重新开始 / H04 下一关 → result_btn_back / result_btn_retry / result_btn_next.png（按钮字在图上）
  H05 得分圆环（「综合得分」「最高得分」在图上，数字由程序写）→ result_score_ring.png
坐标由 C02参考/结算.png 模板匹配量出：框体 (435,108)、圆环 (1210,519)、按钮 y=977（x 537 / 828 / 1118）。"""
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

sys.stdout.reconfigure(encoding="utf-8")
GODOT = Path(__file__).resolve().parent.parent
OUT = GODOT / "assets" / "ui" / "gothic"
TITLE_BOX = (470, 68, 590, 170)      # H01 内标题字所在区域（贴图像素）
TITLE_GREY = 153                      # 烘进的标题字是纯灰 #999999


def erase_title(im: np.ndarray) -> np.ndarray:
    x0, y0, x1, y1 = TITLE_BOX
    sub = im[y0:y1, x0:x1].astype(int)
    core = ((np.abs(sub[..., :3] - TITLE_GREY).max(axis=2) <= 6) & (sub[..., 3] > 250)).astype(np.uint8)
    mask = np.zeros(im.shape[:2], np.uint8)
    mask[y0:y1, x0:x1] = (cv2.dilate(core, np.ones((3, 3), np.uint8), iterations=2) > 0).astype(np.uint8) * 255
    rgb = cv2.inpaint(cv2.cvtColor(im[..., :3], cv2.COLOR_RGB2BGR), mask, 3, cv2.INPAINT_NS)
    alpha = cv2.inpaint(im[..., 3], mask, 3, cv2.INPAINT_NS)
    return np.dstack([cv2.cvtColor(rgb, cv2.COLOR_BGR2RGB), alpha])


def main(argv) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    src = Path(argv[1])
    assets = next(src.rglob("C01资产"), None)
    if assets is None:
        print("找不到 C01资产 目录")
        return 1
    rgba = lambda n: np.array(Image.open(assets / f"{n}-8.png").convert("RGBA"))
    Image.fromarray(erase_title(rgba("H01")), "RGBA").save(OUT / "result_frame.png")
    for n, name in (("H02", "result_btn_back"), ("H03", "result_btn_retry"), ("H04", "result_btn_next"), ("H05", "result_score_ring")):
        Image.fromarray(rgba(n), "RGBA").save(OUT / f"{name}.png")
    print("写入", OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
