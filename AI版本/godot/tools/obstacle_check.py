#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""10 §7（P7，R4）障碍块清单的换算与回贴自检。公式与 scripts/battle/ground_layer.gd 的 obstacle_rects() 一致：
  块左上（整图像素）= 所占格外接框左上 + anchor_px；块尺寸 = size_px。
  所占格外接框左上 = 玩法矩形左上 + (最小列 × cell_px, (高 − 1 − 最大行) × cell_px)（玩法矩形与 cell_px 同 tools/print_playfield_rects.py）。

用法（在 godot/ 目录）：
  python tools/obstacle_check.py check [level_03 ...]
      逐关（默认全部有 scene.obstacles 的关）把障碍块按清单回贴到 base（scene.backdrop）上，与 full 比对：
      full 取清单的 "full" 字段（相对清单目录），缺省为 backdrop 文件名里 _base → _full。
      差异像素（任一通道差 > 16）占比 < 1%，且每个障碍格内不透明像素 ≥ 5%（障碍格看上去必须是障碍）为通过；
      回贴图写到 tools/_raw/obstacle_check/<关>.png。exit 0 = 全部通过。
  python tools/obstacle_check.py anchor <level_id> <x> <y> <列,行> [<列,行> ...]
      从完整画面里按像素框切出一块（左上 x, y，整图像素）时，算出该块应填的 anchor_px（相对所占格外接框左上）。
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

GODOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))
from print_playfield_rects import playfield  # noqa: E402  （导入时已把 stdout 包成 UTF-8）

DIFF_LEVEL = 16
PASS_RATIO = 0.01
CELL_FILL_MIN = 0.05      # 每个障碍格内不透明像素（alpha > 60）至少 5%


def res(path):
    return GODOT / path[len("res://"):] if path.startswith("res://") else Path(path)


def load_level(level_id):
    return json.loads((GODOT / "data" / "levels" / f"{level_id}.json").read_text(encoding="utf-8"))


def cells_top_left(level, cells):
    px, rect = playfield(level)
    h = level["grid"]["height"]
    lo_x = min(c[0] for c in cells)
    hi_y = max(c[1] for c in cells)
    return rect[0] + lo_x * px, rect[1] + (h - 1 - hi_y) * px


def check(level_id):
    L = load_level(level_id)
    sc = L.get("scene", {})
    man_path = res(sc["obstacles"])
    man = json.loads(man_path.read_text(encoding="utf-8"))
    base_path = res(sc["backdrop"])
    full_path = man_path.parent / man["full"] if man.get("full") else base_path.with_name(base_path.name.replace("_base", "_full"))
    if not base_path.exists() or not full_path.exists():
        print(f"{level_id}: 缺少 base 或 full（{base_path.name} / {full_path.name}）")
        return False
    base = Image.open(base_path).convert("RGBA")
    full = Image.open(full_path).convert("RGBA")
    if base.size != full.size:
        print(f"{level_id}: base {base.size} 与 full {full.size} 尺寸不同")
        return False
    k = base.size[1] / 1080.0                      # 整图若不是 1920×1080，按高度换算（与运行时 backdrop 铺法一致）
    comp = base.copy()
    px, rect = playfield(L)
    gh = L["grid"]["height"]
    empty_cells = []
    for pc in man.get("pieces", []):
        x, y = cells_top_left(L, pc["cells"])
        ax, ay = pc["anchor_px"]
        w, h = pc["size_px"]
        piece = Image.open(man_path.parent / pc["file"]).convert("RGBA").resize((round(w * k), round(h * k)), Image.LANCZOS)
        comp.alpha_composite(piece, (round((x + ax) * k), round((y + ay) * k)))
        alpha = np.asarray(piece)[..., 3] > 60     # 逐格覆盖：每个障碍格内不透明像素须 ≥ CELL_FILL_MIN（障碍格看上去必须是障碍）
        for cx, cy in pc["cells"]:
            gx0 = (rect[0] + cx * px - (x + ax)) * k
            gy0 = (rect[1] + (gh - 1 - cy) * px - (y + ay)) * k
            sub = alpha[max(0, round(gy0)):max(0, round(gy0 + px * k)), max(0, round(gx0)):max(0, round(gx0 + px * k))]
            fill = float(sub.mean()) if sub.size else 0.0
            if fill < CELL_FILL_MIN:
                empty_cells.append(f"[{cx},{cy}]={fill * 100:.0f}%")
    d = np.abs(np.asarray(comp, dtype=np.int16)[..., :3] - np.asarray(full, dtype=np.int16)[..., :3]).max(axis=2)
    ratio = float((d > DIFF_LEVEL).mean())
    out = GODOT / "tools" / "_raw" / "obstacle_check"
    out.mkdir(parents=True, exist_ok=True)
    comp.convert("RGB").save(out / f"{level_id}.png")
    ok = ratio < PASS_RATIO and not empty_cells
    print(f"{level_id}: {len(man.get('pieces', []))} 块，回贴差异 {ratio * 100:.2f}%，"
          f"{'逐格覆盖通过' if not empty_cells else '格内几乎没有画面：' + '、'.join(empty_cells)}"
          f" → {'通过' if ok else '未通过'}（回贴图 tools/_raw/obstacle_check/{level_id}.png）")
    return ok


def main(argv):
    if len(argv) >= 2 and argv[1] == "anchor":
        L = load_level(argv[2])
        x, y = float(argv[3]), float(argv[4])
        cells = [[int(v) for v in s.split(",")] for s in argv[5:]]
        cx, cy = cells_top_left(L, cells)
        print(json.dumps({"cells": cells, "anchor_px": [round(x - cx, 1), round(y - cy, 1)]}, ensure_ascii=False))
        return 0
    ids = argv[2:] if len(argv) > 2 else [p.stem for p in sorted((GODOT / "data" / "levels").glob("level_*.json"))
                                           if (json.loads(p.read_text(encoding="utf-8")).get("scene") or {}).get("obstacles")]
    if not ids:
        print("没有关卡配置 scene.obstacles（R4 障碍块尚未接入）")
        return 0
    return 0 if all([check(i) for i in ids]) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
