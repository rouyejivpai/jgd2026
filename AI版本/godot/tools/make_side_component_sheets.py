#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""第四阶段：从批准整图（assets/ui/side_detail/design.png，1672×941）裁出侧栏各组件，按固定位置排成两张 1536×1024 透明底的
"组件表"，作为图生图的输入（生图 API 把它们重绘为无字、透明底的干净组件，位置不变）；位置写入 sheets.json，供 cut_side_components.py 切回。
用法（godot/ 目录）：python tools/make_side_component_sheets.py
"""
import json
from pathlib import Path

from PIL import Image

GODOT = Path(__file__).resolve().parent.parent
D = GODOT / "assets/ui/side_detail"
L = json.loads((D / "ref/side_layout.json").read_text(encoding="utf-8"))

# id: (源矩形（设计坐标 1920×1080）, 放大倍数, 表内左上)
SHEETS = {
    "frames": {
        "side_panel": (L["side_panel"], 0.92, (12, 22)),
        "side_row": (L["side_row1"], 1.0, (640, 20)),
        "side_stats": (L["side_stats"], 1.0, (640, 300)),
        "beacon_bar": (L["beacon_bar"], 1.0, (640, 440)),
    },
    "widgets": {
        "dropdown_wide": ([1380, 470, 422, 38], 1.5, (20, 20)),
        "dropdown": (L["side_action"], 1.5, (700, 20)),
        "btn_delete": (L["side_delete"], 2.0, (20, 130)),
        "btn_close": (L["side_close"], 2.0, (230, 130)),
        "btn_remove": (L["side_remove"], 2.0, (470, 130)),
        "check_off": (L["side_override_box"], 3.0, (720, 130)),
        "check_on": ([1476, 621, 30, 30], 3.0, (840, 130)),
        "handle": (L["side_handle"], 3.0, (960, 120)),
        "portrait_ring": (L["side_portrait"], 2.0, (1100, 110)),
        "btn_add": (L["side_add"], 1.5, (20, 300)),
        "btn_beacon": (L["side_beacon_btn"], 1.5, (500, 300)),
        "mode_on": (L["beacon_mode_once"], 1.5, (20, 430)),
        "mode_off": (L["beacon_mode_loop"], 1.5, (300, 430)),
        "mode_auto": (L["beacon_mode_auto"], 1.5, (580, 430)),
        "btn_done": (L["beacon_done"], 1.5, (860, 430)),
        "scroll_thumb": (L["side_thumb"], 1.5, (1420, 20)),
        "scroll_track": (L["side_track"], 1.5, (1470, 20)),
    },
}


def main() -> None:
    whole = Image.open(D / "design.png").convert("RGBA").resize((1920, 1080), Image.LANCZOS)
    meta = {}
    for name, items in SHEETS.items():
        sheet = Image.new("RGBA", (1536, 1024), (0, 0, 0, 0))
        meta[name] = {}
        for cid, (r, k, at) in items.items():
            x, y, w, h = r
            pad = 4
            crop = whole.crop((x - pad, y - pad, x + w + pad, y + h + pad))
            crop = crop.resize((round((w + 2 * pad) * k), round((h + 2 * pad) * k)), Image.LANCZOS)
            sheet.alpha_composite(crop, at)
            meta[name][cid] = {"src": r, "scale": k, "pad": pad, "at": list(at), "size": list(crop.size)}
        sheet.save(D / f"ref/sheet_{name}_in.png")
    (D / "ref/sheets.json").write_text(json.dumps(meta, ensure_ascii=False, indent=1), encoding="utf-8")
    print("ok")


if __name__ == "__main__":
    main()
