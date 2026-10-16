#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""07 §1.2 玩法矩形：读取全部关卡 JSON，打印每关网格、cell_px 与玩法矩形（设计分辨率 1920×1080）。
公式与 scripts/battle/playfield.gd 一致：战场可视区 y∈[上带, 1080 − 下带]（上下带 = data/ui_layout/battle_hud.json 的 reserved，
第三阶段 P6 起；无该文件时为 64 / 120），玩法区最大 1600 × min(800, 可视区高)，居中于可视区；
cell_px = floor(min(1600 / W, 区高 / H))；关卡 scene.playfield_rect 非 null 时按该矩形计算并居中。

用法（在 godot/ 目录）：
  python tools/print_playfield_rects.py                 打印表格
  python tools/print_playfield_rects.py --png           另输出 1920×1080 标线图到 tools/_raw/playfield_guides/level_XX.png
  python tools/print_playfield_rects.py --png --out DIR 输出到指定目录
标线图（给资源方垫底作图）：金色实线 = 玩法矩形（矩形内只画平坦地面）；金色虚线 = 向外 0.5 格（不要放遮挡物）；
细线 = 网格；红色斜纹 = 障碍格（游戏内画地面标识）；绿色 = 部署区；顶部 / 底部灰带 = 局内 HUD 让出的上下带。
"""
import io
import json
import sys
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
ROOT = Path(__file__).resolve().parent.parent
DESIGN = (1920, 1080)
_hud = ROOT / "data" / "ui_layout" / "battle_hud.json"
_res = json.loads(_hud.read_text(encoding="utf-8")).get("reserved", {}) if _hud.exists() else {}
TOP_BAR, BOTTOM_BAR = int(_res.get("top", 64)), int(_res.get("bottom", 120))
AREA_MAX = (1600, min(800, DESIGN[1] - TOP_BAR - BOTTOM_BAR))


def playfield(level):
    w, h = level["grid"]["width"], level["grid"]["height"]
    cx, cy = DESIGN[0] / 2, TOP_BAR + (DESIGN[1] - TOP_BAR - BOTTOM_BAR) / 2
    pr = (level.get("scene") or {}).get("playfield_rect")
    if pr:
        px = int(min((pr[2] - pr[0]) / w, (pr[3] - pr[1]) / h))
        x0 = round(pr[0] + ((pr[2] - pr[0]) - w * px) / 2)
        y0 = round(pr[1] + ((pr[3] - pr[1]) - h * px) / 2)
    else:
        px = int(min(AREA_MAX[0] / w, AREA_MAX[1] / h))
        x0, y0 = round(cx - w * px / 2), round(cy - h * px / 2)
    return px, (x0, y0, x0 + w * px, y0 + h * px)


def deploy_cells(level):
    dz = level.get("deploy_zone", {})
    if "rect" in dz:
        x0, y0, x1, y1 = dz["rect"]
        cells = {(x, y) for x in range(x0, x1 + 1) for y in range(y0, y1 + 1)}
    else:
        cells = set(tuple(c) for c in dz.get("cells", []))
    return cells - set(tuple(c) for c in dz.get("exclude", []))


def draw_guide(level, px, rect, out_path):
    from PIL import Image, ImageDraw
    w, h = level["grid"]["width"], level["grid"]["height"]
    img = Image.new("RGB", DESIGN, (18, 10, 16))
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle((0, 0, DESIGN[0], TOP_BAR), fill=(90, 90, 90, 140))
    d.rectangle((0, DESIGN[1] - BOTTOM_BAR, DESIGN[0], DESIGN[1]), fill=(90, 90, 90, 140))
    x0, y0, x1, y1 = rect

    def cell_box(c):  # 策划坐标 y 向上
        cx, cy = c
        top = y0 + (h - 1 - cy) * px
        left = x0 + cx * px
        return left, top, left + px, top + px

    for c in deploy_cells(level):
        d.rectangle(cell_box(c), fill=(60, 160, 90, 90))
    for c in level["grid"].get("blocked", []):
        bx0, by0, bx1, by1 = cell_box(tuple(c))
        d.rectangle((bx0, by0, bx1, by1), fill=(255, 75, 62, 50))
        for k in range(1, 6):
            f = k / 6 * px
            d.line((bx0 + f, by0, bx0, by0 + f), fill=(255, 75, 62, 170), width=2)
            d.line((bx1, by0 + f, bx0 + f, by1), fill=(255, 75, 62, 170), width=2)
    for i in range(w + 1):
        d.line((x0 + i * px, y0, x0 + i * px, y1), fill=(232, 220, 196, 70), width=1)
    for j in range(h + 1):
        d.line((x0, y0 + j * px, x1, y0 + j * px), fill=(232, 220, 196, 70), width=1)
    d.rectangle(rect, outline=(201, 162, 74, 255), width=4)
    m = px // 2
    dash = 16
    for (ax, ay, bx, by) in ((x0 - m, y0 - m, x1 + m, y0 - m), (x0 - m, y1 + m, x1 + m, y1 + m),
                             (x0 - m, y0 - m, x0 - m, y1 + m), (x1 + m, y0 - m, x1 + m, y1 + m)):
        length = max(abs(bx - ax), abs(by - ay))
        for s in range(0, length, dash * 2):
            e = min(s + dash, length)
            if ax == bx:
                d.line((ax, ay + s, ax, ay + e), fill=(201, 162, 74, 200), width=2)
            else:
                d.line((ax + s, ay, ax + e, ay), fill=(201, 162, 74, 200), width=2)
    label = "%s  %dx%d  cell_px=%d  rect=(%d,%d)-(%d,%d)" % (level["id"], w, h, px, x0, y0, x1, y1)
    try:
        from PIL import ImageFont
        font = ImageFont.truetype(str(ROOT / "assets" / "fonts" / "NotoSansSC-Regular.otf"), 28)
    except OSError:
        font = None
    d.text((16, 14), label, fill=(232, 220, 196, 255), font=font)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(out_path)


def main():
    args = sys.argv[1:]
    want_png = "--png" in args
    out_dir = ROOT / "tools" / "_raw" / "playfield_guides"
    if "--out" in args:
        out_dir = Path(args[args.index("--out") + 1])
    print("| 关 | 网格 | cell_px | 玩法矩形 (x0,y0)-(x1,y1) |")
    print("|---|---|---|---|")
    for p in sorted((ROOT / "data" / "levels").glob("level_*.json")):
        level = json.loads(p.read_text(encoding="utf-8"))
        px, rect = playfield(level)
        print("| %d | %d×%d | %d | (%d,%d)-(%d,%d) |" % (level["index"], level["grid"]["width"], level["grid"]["height"], px, *rect))
        if want_png:
            draw_guide(level, px, rect, out_dir / ("%s.png" % level["id"]))
    if want_png:
        print("标线图 -> %s" % out_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
