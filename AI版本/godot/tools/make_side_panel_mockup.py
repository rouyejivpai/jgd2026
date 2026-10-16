#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""第四阶段：侧栏详情（指令弹窗靠屏幕一侧）布局线框 + 字形参考图，作为生图 API 整图的参考输入。

用法（在 godot/ 目录）：python tools/make_side_panel_mockup.py <输出目录>
产物：
  side_mockup.png   1920×1080：真实游戏截图为底，右侧停靠的详情侧栏线框（位置即设计坐标，文字用游戏实际字体渲染），
                    底部为「信标模式」边栏（放置信标时替换出场卡）
  glyphs.png        游戏实际使用的字形：NotoSerifSC-Bold（标题 / 优先级 / 按钮）、NotoSerifSC-Regular（正文 / 下拉值）、Cinzel（COST）
  side_layout.json  线框里每个元素的矩形（设计坐标），供 fit_spec 作为 rect_ref 起点
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

GODOT = Path(__file__).resolve().parent.parent
BASE = GODOT.parent / "docs/screenshots/ui_geom/battle_hud/ui_21_actual.png"
F_BOLD = str(GODOT / "assets/fonts/NotoSerifSC-Bold.otf")
F_REG = str(GODOT / "assets/fonts/NotoSerifSC-Regular.otf")
F_CINZEL = str(GODOT / "assets/fonts/Cinzel-Regular.ttf")

GOLD = (232, 196, 106)
GOLD_LINE = (201, 162, 74)
BONE = (218, 201, 179)
DIM = (150, 136, 128)
PANEL = (28, 14, 38)
CARD = (38, 20, 50)
DROP = (44, 22, 58)
RED = (128, 22, 26)
TEAL = (24, 84, 88)
PURPLE = (64, 34, 96)

# 设计坐标（1920×1080），右侧停靠；左侧停靠时 x 镜像（x' = 1920 − x − w），内部元素同样镜像排布
L = {
    "side_panel": [1272, 8, 640, 1064],
    "side_close": [1790, 26, 102, 46],
    "side_remove": [1678, 26, 102, 46],
    "side_portrait": [1292, 40, 126, 126],
    "side_title": [1434, 76, 236, 46],
    "side_desc": [1434, 128, 456, 52],
    "side_cost": [1434, 182, 300, 22],
    "side_stats": [1290, 214, 604, 92],
    "side_note": [1294, 314, 400, 22],
    "side_scroll": [1290, 344, 584, 568],
    "side_track": [1882, 352, 8, 552],
    "side_thumb": [1882, 354, 8, 150],
    "side_row1": [1290, 344, 584, 246],
    "side_row2": [1290, 600, 584, 246],
    "side_handle": [1306, 360, 24, 40],
    "side_prio": [1340, 360, 120, 40],
    "side_override_box": [1476, 365, 30, 30],
    "side_override_label": [1512, 360, 70, 40],
    "side_delete": [1770, 358, 88, 42],
    "side_act_label": [1306, 414, 52, 40],
    "side_action": [1362, 414, 214, 40],
    "side_p1": [1586, 414, 140, 40],
    "side_p2": [1736, 414, 122, 40],
    "side_c1_label": [1306, 470, 70, 38],
    "side_c1": [1380, 470, 300, 38],
    "side_cparam": [1690, 470, 112, 38],
    "side_cunit": [1808, 470, 40, 38],
    "side_logic": [1560, 516, 40, 24],
    "side_c2_label": [1306, 540, 70, 38],
    "side_c2": [1380, 540, 300, 38],
    "side_add": [1298, 928, 290, 54],
    "side_beacon_btn": [1602, 928, 290, 54],
    "side_footer": [1440, 1000, 312, 40],
    "beacon_bar": [436, 858, 812, 196],
    "beacon_bar_title": [466, 874, 560, 36],
    "beacon_bar_hint": [466, 912, 752, 28],
    "beacon_mode_once": [466, 956, 166, 50],
    "beacon_mode_loop": [644, 956, 166, 50],
    "beacon_mode_pingpong": [822, 956, 166, 50],
    "beacon_mode_auto": [1000, 956, 166, 50],
    "beacon_done": [1080, 870, 150, 46],
}
STATS = [("生命", "80/80"), ("攻击", "12"), ("攻速", "1"), ("移速", "3"), ("视野", "8"), ("射程", "4")]


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size)


def rect(d: ImageDraw.ImageDraw, r, fill, outline, width=2, radius=8):
    x, y, w, h = r
    d.rounded_rectangle([x, y, x + w - 1, y + h - 1], radius=radius, fill=fill, outline=outline, width=width)


def text(d, xy, s, f, color, anchor="la"):
    d.text(xy, s, font=f, fill=color, anchor=anchor)


def dropdown(d, r, value, size=20):
    rect(d, r, DROP, GOLD_LINE, 2, 6)
    x, y, w, h = r
    text(d, (x + 12, y + h / 2), value, font(F_REG, size), BONE, "lm")
    cx, cy = x + w - 18, y + h / 2
    d.line([(cx - 7, cy - 3), (cx, cy + 4), (cx + 7, cy - 3)], fill=BONE, width=2)


def button(d, r, label, fill, size=22, bold=True):
    rect(d, r, fill, GOLD_LINE, 2, 10)
    x, y, w, h = r
    text(d, (x + w / 2, y + h / 2), label, font(F_BOLD if bold else F_REG, size), GOLD if fill != RED else (255, 232, 210), "mm")


def draw_row(d, dy: int, prio: int, action: str, p1: str, p2: str, c1: str, cparam: str, c2: str, override: bool):
    def R(k):
        x, y, w, h = L[k]
        return [x, y + dy, w, h]
    rect(d, R("side_row1"), CARD, (140, 106, 52), 2, 12)
    hx, hy, hw, hh = R("side_handle")
    for i in range(3):
        for j in range(2):
            d.ellipse([hx + 6 + j * 9, hy + 8 + i * 10, hx + 11 + j * 9, hy + 13 + i * 10], fill=BONE)
    x, y, w, h = R("side_prio")
    text(d, (x, y + h / 2), f"优先级 {prio}", font(F_BOLD, 24), GOLD, "lm")
    bx, by, bw, bh = R("side_override_box")
    rect(d, R("side_override_box"), DROP, GOLD_LINE, 2, 4)
    if override:
        d.line([(bx + 6, by + 15), (bx + 13, by + 22), (bx + 25, by + 8)], fill=GOLD, width=3)
    x, y, w, h = R("side_override_label")
    text(d, (x, y + h / 2), "覆盖", font(F_REG, 20), BONE, "lm")
    button(d, R("side_delete"), "删除", RED, 20, False)
    x, y, w, h = R("side_act_label")
    text(d, (x, y + h / 2), "行为", font(F_REG, 20), BONE, "lm")
    dropdown(d, R("side_action"), action)
    dropdown(d, R("side_p1"), p1)
    if p2:
        dropdown(d, R("side_p2"), p2)
    x, y, w, h = R("side_c1_label")
    text(d, (x, y + h / 2), "条件一", font(F_REG, 20), BONE, "lm")
    if cparam:
        dropdown(d, R("side_c1"), c1)
        dropdown(d, R("side_cparam"), cparam)
        x, y, w, h = R("side_cunit")
        text(d, (x, y + h / 2), "格", font(F_REG, 20), BONE, "lm")
    else:
        x, y, w, h = R("side_c1")
        dropdown(d, [x, y, w + 122, h], c1)
    x, y, w, h = R("side_logic")
    lx0, lx1 = L["side_c1"][0], L["side_c1"][0] + 422
    d.line([(lx0, y + h / 2), (x - 6, y + h / 2)], fill=(110, 102, 112), width=1)
    d.line([(x + w + 6, y + h / 2), (lx1, y + h / 2)], fill=(110, 102, 112), width=1)
    text(d, (x + w / 2, y + h / 2), "∧", font(F_REG, 20), BONE, "mm")
    x, y, w, h = R("side_c2_label")
    text(d, (x, y + h / 2), "条件二", font(F_REG, 20), BONE, "lm")
    x, y, w, h = R("side_c2")
    dropdown(d, [x, y, w + 122, h], c2)


def mockup(out: Path) -> None:
    im = Image.open(BASE).convert("RGB").resize((1920, 1080))
    d = ImageDraw.Draw(im, "RGBA")
    # 信标模式边栏（替换出场卡）
    d.rectangle([420, 840, 1265, 1072], fill=(16, 8, 22, 255))
    rect(d, L["beacon_bar"], PANEL, GOLD_LINE, 3, 14)
    x, y, w, h = L["beacon_bar_title"]
    text(d, (x, y + h / 2), "信标模式 · 1 号  基础攻击形态", font(F_BOLD, 26), GOLD, "lm")
    x, y, w, h = L["beacon_bar_hint"]
    text(d, (x, y + h / 2), "左键点击地块放置信标，右键撤销最后一个；按 1–5 切换单位", font(F_REG, 18), BONE, "lm")
    button(d, L["beacon_mode_once"], "沿路径", TEAL, 22)
    button(d, L["beacon_mode_loop"], "循环", (40, 26, 50), 22)
    button(d, L["beacon_mode_pingpong"], "往返", (40, 26, 50), 22)
    button(d, L["beacon_mode_auto"], "自动寻路", (30, 22, 34), 20)
    button(d, L["beacon_done"], "完成", PURPLE, 22)
    # 侧栏
    rect(d, L["side_panel"], PANEL + (250,), GOLD_LINE, 3, 16)
    button(d, L["side_close"], "关闭", RED, 22, False)
    rect(d, L["side_remove"], (40, 18, 30), (120, 60, 60), 2, 8)
    x, y, w, h = L["side_remove"]
    text(d, (x + w / 2, y + h / 2), "移除", font(F_REG, 22), BONE, "mm")
    x, y, w, h = L["side_portrait"]
    d.ellipse([x, y, x + w, y + h], fill=(70, 40, 60), outline=GOLD_LINE, width=3)
    port = Image.open(GODOT / "assets/sprites/portraits/striker.png").convert("RGBA").resize((w - 8, h - 8))
    mask = Image.new("L", port.size, 0)
    ImageDraw.Draw(mask).ellipse([0, 0, port.size[0] - 1, port.size[1] - 1], fill=255)
    im.paste(port, (x + 4, y + 4), mask)
    x, y, w, h = L["side_title"]
    text(d, (x, y + h / 2), "基础攻击形态", font(F_BOLD, 36), GOLD, "lm")
    x, y, w, h = L["side_desc"]
    text(d, (x, y), "人偶最先学会的分裂形态。骨刺从前臂增生弹出，", font(F_REG, 18), BONE)
    text(d, (x, y + 26), "中距离、均衡。", font(F_REG, 18), BONE)
    x, y, w, h = L["side_cost"]
    text(d, (x, y + h / 2), "形态 3 ＋ 指令 0", font(F_REG, 16), DIM, "lm")
    rect(d, L["side_stats"], (34, 18, 46), GOLD_LINE, 2, 10)
    sx, sy, sw, sh = L["side_stats"]
    for i, (n, v) in enumerate(STATS):
        cx = sx + 18 + (i % 3) * 196
        cy = sy + 24 + (i // 3) * 44
        d.ellipse([cx, cy - 11, cx + 22, cy + 11], outline=BONE, width=2)
        text(d, (cx + 32, cy), n, font(F_REG, 20), BONE, "lm")
        text(d, (cx + 84, cy), v, font(F_REG, 20), GOLD, "lm")
    x, y, w, h = L["side_note"]
    text(d, (x, y + h / 2), "越靠上，优先级越高；勾选「覆盖」的指令条件成立时优先接管", font(F_REG, 16), DIM, "lm")
    # 滚动区（裁剪）
    layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    draw_row(ld, 0, 1, "沿我的信标", "沿路径", "1", "始终", "", "无", False)
    draw_row(ld, 256, 2, "撤离", "最近", "敌人", "目标距离", "< 3", "无", True)
    draw_row(ld, 512, 3, "追击并攻击", "最近", "敌人", "射程内敌人", "", "无", False)
    sx, sy, sw, sh = L["side_scroll"]
    clip = Image.new("L", im.size, 0)
    ImageDraw.Draw(clip).rectangle([sx, sy, sx + sw, sy + sh], fill=255)
    im.paste(layer, (0, 0), Image.composite(layer.getchannel("A"), Image.new("L", im.size, 0), clip))
    d = ImageDraw.Draw(im, "RGBA")
    rect(d, L["side_track"], (60, 40, 60), (90, 70, 80), 1, 4)
    rect(d, L["side_thumb"], GOLD_LINE, GOLD, 1, 4)
    d.line([(1290, 918), (1894, 918)], fill=GOLD_LINE + (180,), width=2)
    button(d, L["side_add"], "＋ 添加指令", TEAL, 24)
    button(d, L["side_beacon_btn"], "信标", PURPLE, 24)
    x, y, w, h = L["side_footer"]
    text(d, (x + w / 2, y + h / 2), "信标：2 个 · 沿路径", font(F_REG, 20), BONE, "mm")
    im.save(out / "side_mockup.png")


def glyphs(out: Path) -> None:
    im = Image.new("RGB", (1536, 1024), (24, 12, 32))
    d = ImageDraw.Draw(im)
    y = 30
    samples = [
        (F_BOLD, "NotoSerifSC-Bold（思源宋体 粗）", ["基础攻击形态 快速形态 承伤形态", "优先级 1 2 3  添加指令  信标  完成", "信标模式 · 1 号  沿路径 循环 往返"], [48, 34, 28]),
        (F_REG, "NotoSerifSC-Regular（思源宋体 常规）", ["射程内敌人 最近 追击并攻击 始终 沿我的信标 撤离", "条件一 条件二 行为 覆盖 删除 关闭 移除 自动寻路", "生命 80/80 攻击 12 攻速 1 移速 3 视野 8 射程 4", "人偶最先学会的分裂形态。骨刺从前臂增生弹出，中距离、均衡。"], [30, 30, 26, 22]),
        (F_CINZEL, "Cinzel（拉丁数字 / COST）", ["COST 3  1x 2x  0123456789"], [40]),
    ]
    for path, title, lines, sizes in samples:
        d.text((40, y), title, font=font(F_REG, 22), fill=DIM)
        y += 40
        for s, sz in zip(lines, sizes):
            d.text((40, y), s, font=font(path, sz), fill=GOLD if path == F_BOLD else BONE)
            y += int(sz * 1.6)
        y += 30
    im.save(out / "glyphs.png")


def main() -> int:
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else GODOT / "assets/ui/side_detail/ref"
    out.mkdir(parents=True, exist_ok=True)
    mockup(out)
    glyphs(out)
    (out / "side_layout.json").write_text(json.dumps(L, ensure_ascii=False, indent=1), encoding="utf-8")
    print("written", out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
