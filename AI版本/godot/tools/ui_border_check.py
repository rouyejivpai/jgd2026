#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""第四阶段：框体逐像素边线核对（补充 ui_geom_check.py）。
金色细边框在边缘相关（NCC）里容易误配到相邻的重复花纹（实测指令卡、下拉会被配错 ±8 px），这里直接比边线像素：
对每个框体元素，沿其水平中线向左右、沿竖直中线向上下，在布局矩形 ±search 范围内找最外侧的"金色"像素（R>150, G>105, B<130），
得到 左 / 右 / 上 / 下 四条边线坐标；参考（批准整图缩放到设计尺寸）与实机逐条比较，|差| ≤ tol 通过。
文字遮挡中线时会多取几条平行扫描线，取众数。
用法（godot/ 目录）：python tools/ui_border_check.py --reference <整图> --actual <截图（建议 _notext）> --screen side_detail [--skip id ...] [--tol 1] [--out 目录]
"""
import argparse
import io
import json
import sys
from collections import Counter
from pathlib import Path

import numpy as np
from PIL import Image

GODOT = Path(__file__).resolve().parent.parent


def gold(img: np.ndarray) -> np.ndarray:
    r, g, b = img[..., 0].astype(int), img[..., 1].astype(int), img[..., 2].astype(int)
    return (r > 150) & (g > 105) & (b < 130) & (r - b > 60)


def edge(mask_line: np.ndarray, from_start: bool):
    idx = np.nonzero(mask_line)[0]
    if len(idx) == 0:
        return None
    return int(idx[0]) if from_start else int(idx[-1])


def borders(mask: np.ndarray, rect, search: int, lines: int = 5):
    x, y, w, h = [int(round(v)) for v in rect]
    H, W = mask.shape
    x0, x1 = max(0, x - search), min(W, x + w + search)
    y0, y1 = max(0, y - search), min(H, y + h + search)
    res = {}
    # 左右：多条水平扫描线（中线附近 ±h/4），各自只看左 / 右三分之一，免得取到内部控件
    lefts, rights, tops, bottoms = [], [], [], []
    for k in range(lines):
        yy = int(y + h * (0.35 + 0.3 * k / max(1, lines - 1)))
        if not (0 <= yy < H):
            continue
        row = mask[yy, x0:x1]
        third = max(1, (x1 - x0) // 3)
        l = edge(row[:third], True)
        r = edge(row[-third:], False)
        if l is not None:
            lefts.append(x0 + l)
        if r is not None:
            rights.append(x1 - third + r)
    for k in range(lines):
        xx = int(x + w * (0.35 + 0.3 * k / max(1, lines - 1)))
        if not (0 <= xx < W):
            continue
        col = mask[y0:y1, xx]
        third = max(1, (y1 - y0) // 3)
        t = edge(col[:third], True)
        b = edge(col[-third:], False)
        if t is not None:
            tops.append(y0 + t)
        if b is not None:
            bottoms.append(y1 - third + b)
    for name, vals in (("left", lefts), ("right", rights), ("top", tops), ("bottom", bottoms)):
        res[name] = Counter(vals).most_common(1)[0][0] if vals else None
    return res


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--reference", required=True)
    ap.add_argument("--actual", required=True)
    ap.add_argument("--screen", required=True)
    ap.add_argument("--skip", nargs="*", default=[])
    ap.add_argument("--tol", type=float, default=1.0)
    ap.add_argument("--search", type=int, default=8)
    ap.add_argument("--out", default="")
    a = ap.parse_args()
    lay = json.loads((GODOT / "data/ui_layout" / f"{a.screen}.json").read_text(encoding="utf-8"))
    dw, dh = lay["design_size"]
    ref = np.array(Image.open(a.reference).convert("RGB").resize((dw, dh), Image.LANCZOS))
    act = np.array(Image.open(a.actual).convert("RGB"))
    mr, ma = gold(ref), gold(act)
    rows, fails = [], 0
    md = [f"# {a.screen} 边线核对", "", "| 元素 | 边 | 参考 | 实机 | 差 | 通过 |", "|---|---|---|---|---|---|"]
    for e in lay["elements"]:
        if e["id"] in a.skip or e["kind"] not in ("ninepatch", "button", "toggle", "image"):
            continue
        if e["kind"] == "button" and "flat_states" in e:
            continue
        big = e["rect"][2] * e["rect"][3] > 60000           # 大框体放宽扫描；小件只看矩形附近，免得扫到相邻控件
        srch = a.search if big else 3
        br, ba = borders(mr, e["rect"], srch), borders(ma, e["rect"], srch)
        for side in ("left", "right", "top", "bottom"):
            if br[side] is None or ba[side] is None:
                continue
            d = ba[side] - br[side]
            ok = abs(d) <= a.tol
            fails += 0 if ok else 1
            rows.append({"id": e["id"], "side": side, "ref": br[side], "act": ba[side], "d": d, "pass": ok})
            md.append(f"| {e['id']} | {side} | {br[side]} | {ba[side]} | {d:+d} | {'✓' if ok else '✗'} |")
    md += ["", f"共 {len(rows)} 条边，未通过 {fails} 条。"]
    if a.out:
        out = Path(a.out)
        out.mkdir(parents=True, exist_ok=True)
        (out / f"{a.screen}_borders.md").write_text("\n".join(md) + "\n", encoding="utf-8", newline="\n")
        (out / f"{a.screen}_borders.json").write_text(json.dumps(rows, ensure_ascii=False, indent=1) + "\n", encoding="utf-8", newline="\n")
    print("\n".join(md))
    return 0 if fails == 0 else 1


if __name__ == "__main__":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    sys.exit(main())
