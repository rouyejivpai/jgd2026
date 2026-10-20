#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""2026-10-20《文本更改》换皮用的补图（关卡 initial_units[].visuals 覆盖引用）与骨花魔女新 Q 版：
  守火魔女 keeper_witch ← 美术 2026-10-20 交付的 Q 版图（work/美术资源_20261019/守火魔女QQ人/keeper_witch_full.png，朝左 → 翻为默认朝右）
  “失败品” failed_doll ← Q 版破损发饰人偶（用户 2026-10-20 指定，原色，不去色）
  骨花魔女 bone_witch ← 用户 2026-10-20 指定的骨花魔女 Q 版原图（import_qq_art.py FIGURES["flower_witch"]）
  织骸阴影立绘 witch_shadow ← illustrations/witch.png：上半涂黑，往下渐变回原色（第 27 关织骸本人登场前，剧情里用它表现「笼罩在阴影中」）
  畸变母核 / 守火魂灯 只有物件图（props/），补一张头像
单位画布 / 头像版式与 tools/import_qq_art.py 相同。
用法（godot/ 目录）：python tools/make_reskin_art.py
"""
import numpy as np
from PIL import Image

import import_qq_art as qq

SPR = qq.SPR


def save_unit(name: str, fig: Image.Image, head: list) -> None:
    qq.unit_canvas(fig, {}).save(SPR / "units" / f"{name}.png")
    qq.portrait(fig, head).save(SPR / "portraits" / f"{name}.png")
    print("单位", name)


SHADOW_SOLID = 0.5        ## 立绘自上而下这一比例完全涂黑
SHADOW_FADE_END = 0.95    ## 到这一比例时完全恢复原色（中间平滑过渡）
SHADOW_COLOR = (6, 3, 10)


def witch_shadow() -> None:
    """织骸立绘：上半涂黑，往下渐变回原色（保留透明度）"""
    src = Image.open(SPR / "illustrations/witch.png").convert("RGBA")
    arr = np.array(src).astype(np.float32)
    h = arr.shape[0]
    y = (np.arange(h, dtype=np.float32) / (h - 1))[:, None]
    k = np.clip((y - SHADOW_SOLID) / (SHADOW_FADE_END - SHADOW_SOLID), 0.0, 1.0)
    k = k * k * (3.0 - 2.0 * k)                     # smoothstep：1 = 原色，0 = 全黑
    for c in range(3):
        arr[..., c] = arr[..., c] * k + SHADOW_COLOR[c] * (1.0 - k)
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA").save(SPR / "illustrations/witch_shadow.png")
    print("立绘 witch_shadow")


def main() -> None:
    witch_shadow()
    save_unit("keeper_witch", qq.clean(Image.open(qq.SRC / "守火魔女QQ人/keeper_witch_full.png")).transpose(Image.FLIP_LEFT_RIGHT), [0.0, 0.0, 1.0, 0.6])
    save_unit("failed_doll", qq.figure("doll_worn"), qq.FIGURES["doll_worn"][2])
    save_unit("bone_witch", qq.figure("flower_witch"), qq.FIGURES["flower_witch"][2])
    for name, src in (("warped_core", "props/warped_core_a.png"), ("soul_lamp", "props/soul_lamp_lit.png")):
        qq.portrait(qq.clean(Image.open(SPR / src)), [0.0, 0.0, 1.0, 1.0]).save(SPR / "portraits" / f"{name}.png")
        print("头像", name)


if __name__ == "__main__":
    main()
