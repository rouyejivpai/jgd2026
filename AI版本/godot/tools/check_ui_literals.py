#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""铁律 8 检查：界面/表现层脚本中不得出现中文（含全角标点）字符串字面量；注释与 push_error/push_warning/DataReader 错误日志（开发者调试文字）除外。
用法（在 godot/ 目录）：python tools/check_ui_literals.py   退出码 0 = 通过。"""
import io
import re
import sys
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
ROOT = Path(__file__).resolve().parent.parent / "scripts"
CJK = re.compile(r"[　-〿一-鿿＀-￯]")
STRING = re.compile(r'"(?:[^"\\]|\\.)*"')

bad = 0
for sub in ("ui", "battle", "screens", "autoloads"):
    for f in sorted((ROOT / sub).glob("*.gd")):
        for i, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
            code = line.split("#")[0]
            if "push_error" in code or "push_warning" in code or "DataReader." in code:
                continue
            for m in STRING.finditer(code):
                if CJK.search(m.group()):
                    print(f"{f.relative_to(ROOT.parent)}:{i}: {m.group()}")
                    bad += 1
print("界面脚本无中文字面量。" if bad == 0 else f"发现 {bad} 处中文字面量。")
sys.exit(1 if bad else 0)
