#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""04 §4.4 导入设置：按目录改写 .import 的压缩与 mipmap 参数（需先由 Godot --import 生成 .import 文件）。
用法（在 godot/ 目录）：python tools/apply_import_presets.py   之后再运行一次 Godot --import 让改动生效。
  backgrounds/、backdrops/、grounds/    VRAM Compressed (2)，mipmaps 开（07 §1：backdrops、grounds 为第二阶段新增）
  sprites/units、props、portraits、illustrations、ground_marks、tile_marks   Lossless (0)，mipmaps 开
  sprites/ui、vfx、projectiles          Lossless (0)，mipmaps 关
  sprites/ui/icons/*.svg               svg/scale = 2.0
只改上述键，其他参数保持不变；输出改动文件数。"""
import io
import re
import sys
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
ROOT = Path(__file__).resolve().parent.parent / "assets"

RULES = [
    ("backgrounds", {"compress/mode": "2", "mipmaps/generate": "true"}),
    ("backdrops", {"compress/mode": "2", "mipmaps/generate": "true"}),
    ("grounds", {"compress/mode": "2", "mipmaps/generate": "true"}),
    ("sprites/units", {"compress/mode": "0", "mipmaps/generate": "true"}),
    ("sprites/ground_marks", {"compress/mode": "0", "mipmaps/generate": "true"}),
    ("sprites/tile_marks", {"compress/mode": "0", "mipmaps/generate": "true"}),
    ("sprites/props", {"compress/mode": "0", "mipmaps/generate": "true"}),
    ("sprites/portraits", {"compress/mode": "0", "mipmaps/generate": "true"}),
    ("sprites/illustrations", {"compress/mode": "0", "mipmaps/generate": "true"}),
    ("sprites/ui/icons", {"svg/scale": "2.0"}),
    ("sprites/ui", {"compress/mode": "0", "mipmaps/generate": "false"}),
    ("sprites/vfx", {"compress/mode": "0", "mipmaps/generate": "false"}),
    ("sprites/projectiles", {"compress/mode": "0", "mipmaps/generate": "false"}),
]


def rule_for(path: Path) -> dict:
    rel = path.relative_to(ROOT).as_posix()
    for prefix, params in RULES:          # 先匹配更具体的目录（icons 在 ui 之前）
        if rel.startswith(prefix + "/"):
            return params
    return {}


def main() -> int:
    changed = 0
    for imp in sorted(ROOT.rglob("*.import")):
        params = rule_for(imp)
        if not params:
            continue
        text = imp.read_text(encoding="utf-8")
        new = text
        for key, value in params.items():
            pattern = re.compile(r"^" + re.escape(key) + r"=.*$", re.MULTILINE)
            if pattern.search(new):
                new = pattern.sub(f"{key}={value}", new)
        if new != text:
            imp.write_text(new, encoding="utf-8", newline="\n")
            changed += 1
    print(f"导入预设已应用：改动 {changed} 个 .import 文件。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
