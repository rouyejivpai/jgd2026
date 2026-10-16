#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""第四阶段：侧栏详情（side_detail）切片 + manifest 生成。
输入：
  assets/ui/side_detail/design.png              批准整图（生图 API 按线框 + 风格 + 字形参考出图，1672×941）
  assets/ui/side_detail/ref/side_layout.json    线框矩形（设计坐标 1920×1080，整图与之逐元素对齐）
  assets/ui/side_detail/ref/sheets.json         组件表位置；ref/sheet_<frames|widgets>_v1.png = 图生图得到的透明组件表
  assets/ui/side_detail/calibration.json        （可选）实机几何比对后的修正：{id: {"nudge": [dx, dy], "size_adjust": n}}
输出：
  assets/ui/side_detail/slices/*.png            透明组件（缩回设计尺寸 1:1，裁到不透明外框）
  assets/ui/side_detail/manifest.json           apply_ui_manifest.py 的输入（元素 id 沿用 det_*，供 DetailKit / RuleRow / RuleEditor 读取）
文字：ref_ink 在批准整图（缩放到设计尺寸）上、线框文字外框附近按亮度量出；label 矩形按字体度量反推，使 ink 落在参考位置（与 ui_fit_reference.py 同法）；
      字色取 ink 亮部中位色。之后用 ui_geom_check.py 比对实机，偏差写进 calibration.json 再生成。
用法（godot/ 目录）：python tools/make_side_manifest.py
"""
import io
import json
import sys
from pathlib import Path

import cv2
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ui_border_check import borders, gold  # noqa: E402  边线扫描（与核对工具同一算法）
from PIL import Image, ImageFont

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
GODOT = Path(__file__).resolve().parent.parent
D = GODOT / "assets/ui/side_detail"
L = json.loads((D / "ref/side_layout.json").read_text(encoding="utf-8"))
SHEETS = json.loads((D / "ref/sheets.json").read_text(encoding="utf-8"))
CAL = json.loads((D / "calibration.json").read_text(encoding="utf-8")) if (D / "calibration.json").exists() else {}
FONTS = {"NotoSerifSC": GODOT / "assets/fonts/NotoSerifSC-Regular.otf", "NotoSerifSC-Bold": GODOT / "assets/fonts/NotoSerifSC-Bold.otf"}
FRAME_IDS = ("side_panel", "side_stats", "beacon_bar")    # 大框体：边线可能离线框较远（整图里画大了），放宽扫描范围
FRAME_OVERHANG = 4         # 框体角纹饰伸出边线的量（设计像素，批准整图量取）
ROW2_DY = 0                # 第 2 张指令卡相对线框的偏移：整图横向金线逐行扫描，第 2 张卡各行比第 1 张卡恰好低 256 px（= 线框卡距）
ROW2_TEXTS = ("det_c1_narrow", "det_cparam", "det_cunit")   # 第 2 张卡上的件：纵向按第 1 张卡同一行（条件一）+ 卡距推出。
# （第 2 张卡的字贴着下拉边框，直接量 ink 容易混入边框；按卡距推出更稳）
TINT = {"hover": "#FFFFFF", "pressed": "#C9C2C9", "disabled": "#8C8490"}

# 切片：组件表 id → (切片文件名, 九宫格 [左, 上, 右, 下])
SLICES = {
    "side_panel": ("panel", [48, 48, 48, 48]), "side_row": ("card", [36, 36, 36, 36]), "side_stats": ("stats", [32, 32, 32, 32]),
    "beacon_bar": ("bar", [36, 36, 36, 36]),
    "dropdown_wide": ("dropdown_wide", [14, 14, 40, 14]), "dropdown": ("dropdown", [14, 14, 40, 14]),
    "btn_delete": ("btn_red", [14, 14, 14, 14]), "btn_close": ("btn_red_large", [14, 14, 14, 14]), "btn_remove": ("btn_dark", [14, 14, 14, 14]),
    "check_off": ("check_off", None), "check_on": ("check_on", None), "handle": ("handle", None), "portrait_ring": ("portrait_ring", None),
    "btn_add": ("btn_teal", [18, 14, 18, 14]), "btn_beacon": ("btn_purple", [18, 14, 18, 14]),
    "mode_on": ("mode_on", [16, 14, 16, 14]), "mode_off": ("mode_off", [16, 14, 16, 14]), "mode_auto": ("mode_auto", [16, 14, 16, 14]),
    "btn_done": ("btn_done", [16, 14, 16, 14]),
    "scroll_thumb": ("thumb", [0, 6, 0, 6]), "scroll_track": ("track", [0, 6, 0, 6]),
}


def nine_resize(piece: Image.Image, W: int, H: int, margins, k: float) -> Image.Image:
    """九宫格式缩放：四角按组件表比例 1/k 缩放（纹饰不变形），四边与中间拉伸到目标尺寸（图生图把框画宽 / 画窄时用）"""
    l, t, r, b = [max(1, int(v)) for v in margins]
    sl, st, sr, sb = [max(1, round(v * k)) for v in (l, t, r, b)]
    pw, ph = piece.size
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    xs_src = [0, sl, pw - sr, pw]
    ys_src = [0, st, ph - sb, ph]
    xs_dst = [0, l, W - r, W]
    ys_dst = [0, t, H - b, H]
    for i in range(3):
        for j in range(3):
            box = (xs_src[i], ys_src[j], xs_src[i + 1], ys_src[j + 1])
            dw, dh = xs_dst[i + 1] - xs_dst[i], ys_dst[j + 1] - ys_dst[j]
            if dw <= 0 or dh <= 0 or box[2] <= box[0] or box[3] <= box[1]:
                continue
            out.paste(piece.crop(box).resize((dw, dh), Image.LANCZOS), (xs_dst[i], ys_dst[j]))
    return out


def cut_slices() -> dict:
    """组件表 → slices/<名>.png；返回 组件 id → {file, rect（批准整图上的设计坐标外框）, size}"""
    out = {}
    (D / "slices").mkdir(exist_ok=True)
    for sheet, items in SHEETS.items():
        img = Image.open(D / f"ref/sheet_{sheet}_v1.png").convert("RGBA")
        alpha = np.array(img.getchannel("A"))
        # 连通域：图生图可能把组件画得比表内格子宽 / 窄（实测属性框、底栏被画宽），按"与预期格子重叠最多的连通域"取整件
        n, labels, stats, _ = cv2.connectedComponentsWithStats((alpha >= 24).astype(np.uint8), connectivity=8)
        for cid, m in items.items():
            x, y = m["at"]
            w, h = m["size"]
            k, pad = m["scale"], m["pad"]
            win = labels[y:y + h, x:x + w]
            ids, counts = np.unique(win[win > 0], return_counts=True)
            if len(ids) == 0:
                raise SystemExit(f"{sheet}/{cid}：表内格子里没有组件")
            best = int(ids[np.argmax(counts)])
            # 同一组件可能断成几块（细线、勾号）：并入外框与预期格子相交的其他连通域
            keep = [best] + [int(i) for i in ids if int(i) != best and stats[int(i), cv2.CC_STAT_AREA] >= 4]
            mask = np.isin(labels, keep)
            ys, xs = np.nonzero(mask)
            bx0, by0, bx1, by1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
            arr0 = np.array(img)[by0:by1, bx0:bx1].copy()
            arr0[..., 3] = np.where(mask[by0:by1, bx0:bx1], arr0[..., 3], 0)
            piece = Image.fromarray(arr0)
            bx0, by0, bx1, by1 = bx0 - x, by0 - y, bx1 - x, by1 - y
            # 设计坐标外框：表内 at 处对应整图 (src − pad)、比例 k（组件表就是这样从整图裁出来的；图生图保持位置不变）
            sx, sy = m["src"][0], m["src"][1]
            rx, ry = sx - pad + bx0 / k, sy - pad + by0 / k
            W, H = max(1, round((bx1 - bx0) / k)), max(1, round((by1 - by0) / k))
            name, np_ = SLICES[cid]
            if sheet == "frames":
                # 大框体：图生图时位置与尺寸都有漂移（实测属性框上移 22、画宽 260），一律以批准整图（= 线框矩形）为准，
                # 外框 = 线框矩形四周外扩 FRAME_OVERHANG（角纹饰伸出边线的量，整图量取）
                ov = FRAME_OVERHANG
                rx, ry = m["src"][0] - ov, m["src"][1] - ov
                W, H = round(m["src"][2] + 2 * ov), round(m["src"][3] + 2 * ov)
            elif np_ is not None:
                # 九宫格小件（按钮 / 下拉）：图生图会把件画大几像素（实测下拉 45 vs 整图 40），整图里的外框与线框矩形一致（边框扫描核对），
                # 直接取线框矩形
                rx, ry = m["src"][0], m["src"][1]
                W, H = round(m["src"][2]), round(m["src"][3])
            piece = nine_resize(piece, W, H, np_, k) if np_ is not None else piece.resize((W, H), Image.LANCZOS)
            arr = np.array(piece)
            al = arr[..., 3]
            al[al < 10] = 0
            al[al >= 235] = 255                      # 实心底板完全不透明（HDR 下 99% 的不透明也会透出背后高亮的按钮）
            if cid == "scroll_track":                 # 轨道切片里带着整图上的金色滑块：滑块行换成下方的暗色轨道行
                lum_r = arr[..., 0].astype(int)
                rows = [i for i in range(arr.shape[0]) if (lum_r[i][arr[i, :, 3] > 0] > 150).any()]
                dark = next(i for i in range(arr.shape[0] - 1, -1, -1) if i not in rows and arr.shape[0] - i > 10)
                for i in rows:
                    if 6 <= i < arr.shape[0] - 6:
                        arr[i] = arr[dark]
            piece = Image.fromarray(arr)
            piece.save(D / f"slices/{name}.png")
            # 金边内缩：切片外框到最外侧金色边线的距离（切片四周有淡淡的辉光 / 阴影，金边不在切片边上）
            pm = gold(np.array(piece.convert("RGB"))) & (np.array(piece)[..., 3] > 128)
            bb = borders(pm, [0, 0, W, H], 0)
            inset = None
            if all(bb[k] is not None for k in ("left", "right", "top", "bottom")):
                inset = [bb["left"], bb["top"], W - 1 - bb["right"], H - 1 - bb["bottom"]]
            out[cid] = {"file": f"slices/{name}.png", "rect": [round(rx), round(ry), W, H], "ninepatch": np_, "inset": inset, "src": list(m["src"])}
    return out


def ref_image() -> np.ndarray:
    return np.array(Image.open(D / "design.png").convert("RGB").resize((1920, 1080), Image.LANCZOS)).astype(np.int16)


def font(fam: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONTS[fam]), size)


def _bbox(text, fam, size, xy, anchor):
    x0, y0, x1, y1 = font(fam, size).getbbox(text, anchor=anchor)
    return [xy[0] + x0, xy[1] + y0, xy[0] + x1, xy[1] + y1]


def measure_ink(ref: np.ndarray, box, thr: int, g: int = 6):
    """线框文字外框 ±g px 内、比局部背景亮 thr 以上的像素外框，与字色（亮部中位色）；按钮 / 下拉里的文字 g 取小，免得把边框算进来"""
    x0, y0, x1, y1 = [int(round(v)) for v in box]
    reg = ref[y0 - g:y1 + g, x0 - g:x1 + g]
    lum = reg.mean(axis=2)
    bg = np.median(np.concatenate([lum[:3].ravel(), lum[-3:].ravel()]))
    ys, xs = np.nonzero(lum > bg + thr)
    if len(xs) < 6:
        return None, None
    ink = [float(xs.min() + x0 - g), float(ys.min() + y0 - g), float(xs.max() - xs.min() + 1), float(ys.max() - ys.min() + 1)]
    px = reg[ys, xs]
    l2 = px.mean(axis=1)
    bright = px[l2 >= np.percentile(l2, 60)]
    c = np.median(bright, axis=0).astype(int)
    return ink, "#%02X%02X%02X" % tuple(int(v) for v in c)


def label_rect(text, fam, size, ink, align, max_w):
    """ink（设计坐标）→ Label 矩形：高 = 行高（ascent + descent），使字形落在 ink；左对齐按左缘、居中按中心"""
    f = font(fam, size)
    asc, desc = f.getmetrics()
    bx0, by0, bx1, by1 = f.getbbox(text, anchor="ls")
    y = ink[1] - (asc + by0)
    if align == "left":
        x = ink[0] - bx0
    else:
        x = ink[0] + ink[2] / 2 - max_w / 2
    return [x, y, max_w, asc + desc]


# 文字：id → (文本, 字体, 字号, 线框锚点 (x, y), PIL anchor, 对齐, 可用宽, 溢出, 亮度阈值, 所属按钮 / None)
def texts() -> dict:
    T = {}
    T["det_title"] = ("基础攻击形态", "NotoSerifSC-Bold", 36, (1434, 99), "lm", "left", 236, "auto", 60, None)
    T["det_cost"] = ("形态 3 ＋ 指令 0", "NotoSerifSC", 16, (1434, 193), "lm", "left", 300, "auto", 40, None)
    T["det_note"] = ("越靠上，优先级越高；勾选「覆盖」的指令条件成立时优先接管", "NotoSerifSC", 16, (1294, 325), "lm", "left", 580, "auto", 40, None)
    names = ["生命", "攻击", "攻速", "移速", "视野", "射程"]
    vals = ["80/80", "12", "1", "3", "8", "4"]
    sx, sy = L["side_stats"][0], L["side_stats"][1]
    for i in range(6):
        cx, cy = sx + 18 + (i % 3) * 196, sy + 24 + (i // 3) * 44
        T[f"det_stat_name_{i}"] = (names[i], "NotoSerifSC", 20, (cx + 32, cy), "lm", "left", 50, "", 60, None)
        T[f"det_stat_value_{i}"] = (vals[i], "NotoSerifSC", 20, (cx + 84, cy), "lm", "left", 100, "auto", 60, None)
    T["det_prio"] = ("优先级 1", "NotoSerifSC-Bold", 24, (1340, 380), "lm", "left", 124, "", 60, None)
    T["det_override_label"] = ("覆盖", "NotoSerifSC", 20, (1512, 380), "lm", "left", 70, "", 60, None)
    T["det_act_label"] = ("行为", "NotoSerifSC", 20, (1306, 434), "lm", "left", 52, "", 60, None)
    T["det_c1_label"] = ("条件一", "NotoSerifSC", 20, (1306, 489), "lm", "left", 70, "", 60, None)
    T["det_c2_label"] = ("条件二", "NotoSerifSC", 20, (1306, 559), "lm", "left", 70, "", 60, None)
    T["det_logic"] = ("∧", "NotoSerifSC", 20, (1580, 528), "mm", "center", 30, "", 50, "det_logic")
    T["det_beacons"] = ("信标：2 个 · 沿路径", "NotoSerifSC", 20, (1596, 1020), "mm", "center", 440, "auto", 60, None)
    T["beacon_bar_title"] = ("信标模式 · 1 号  基础攻击形态", "NotoSerifSC-Bold", 26, (466, 892), "lm", "left", 600, "auto", 60, None)
    T["beacon_bar_hint"] = ("左键点击地块放置信标，右键撤销最后一个；按 1–5 切换单位", "NotoSerifSC", 18, (466, 926), "lm", "left", 752, "auto", 50, None)
    # 按钮 / 下拉文字
    T["det_action"] = ("沿我的信标", "NotoSerifSC", 20, (1374, 434), "lm", "left", 166, "", 60, "det_action")
    T["det_p1"] = ("沿路径", "NotoSerifSC", 20, (1598, 434), "lm", "left", 94, "", 60, "det_p1")
    T["det_p2"] = ("1", "NotoSerifSC", 20, (1748, 434), "lm", "left", 76, "", 60, "det_p2")
    T["det_c1"] = ("始终", "NotoSerifSC", 20, (1392, 489), "lm", "left", 370, "", 60, "det_c1")
    T["det_cunit"] = ("格", "NotoSerifSC", 20, (1808, 745 + ROW2_DY), "lm", "left", 40, "", 60, None)
    T["det_c1_narrow"] = ("目标距离", "NotoSerifSC", 20, (1392, 745 + ROW2_DY), "lm", "left", 250, "", 60, "det_c1_narrow")
    T["det_cparam"] = ("< 3", "NotoSerifSC", 20, (1702, 745 + ROW2_DY), "lm", "left", 66, "", 60, "det_cparam")
    T["det_c2"] = ("无", "NotoSerifSC", 20, (1392, 559), "lm", "left", 370, "", 60, "det_c2")
    T["det_delete"] = ("删除", "NotoSerifSC", 20, (1814, 379), "mm", "center", 70, "", 70, "det_delete")
    T["det_close"] = ("关闭", "NotoSerifSC", 22, (1841, 49), "mm", "center", 84, "", 70, "det_close")
    T["det_remove"] = ("移除", "NotoSerifSC", 22, (1729, 49), "mm", "center", 84, "", 60, "det_remove")
    T["det_add"] = ("＋ 添加指令", "NotoSerifSC-Bold", 24, (1443, 955), "mm", "center", 250, "", 60, "det_add")
    T["det_beacon_btn"] = ("信标", "NotoSerifSC-Bold", 24, (1747, 955), "mm", "center", 250, "", 60, "det_beacon_btn")
    T["beacon_mode_once"] = ("沿路径", "NotoSerifSC-Bold", 22, (549, 981), "mm", "center", 140, "", 60, "beacon_mode_once")
    T["beacon_mode_loop"] = ("循环", "NotoSerifSC-Bold", 22, (727, 981), "mm", "center", 140, "", 60, "beacon_mode_loop")
    T["beacon_mode_pingpong"] = ("往返", "NotoSerifSC-Bold", 22, (905, 981), "mm", "center", 140, "", 60, "beacon_mode_pingpong")
    T["beacon_mode_auto"] = ("自动寻路", "NotoSerifSC-Bold", 20, (1083, 981), "mm", "center", 140, "", 50, "beacon_mode_auto")
    T["beacon_done"] = ("完成", "NotoSerifSC-Bold", 22, (1155, 893), "mm", "center", 120, "", 60, "beacon_done")
    return T


def main() -> int:
    sl = cut_slices()
    ref = ref_image()
    els = []

    def ninepatch(eid, cid, rect=None, extra=None):
        s = sl[cid]
        r = list(rect or s["rect"])
        x0, y0, x1, y1 = max(0, r[0]), max(0, r[1]), min(1920, r[0] + r[2]), min(1080, r[1] + r[3])   # 贴屏幕边的外框收进设计画布（九宫格保角）
        e = {"id": eid, "kind": "ninepatch", "rect": [x0, y0, x1 - x0, y1 - y0], "file": s["file"], "ninepatch": s["ninepatch"]}
        if extra:
            e.update(extra)
        els.append(e)

    def image(eid, cid, rect=None):
        s = sl[cid]
        els.append({"id": eid, "kind": "image", "rect": rect or s["rect"], "file": s["file"]})

    def button(eid, cid, rect=None, states=None):
        s = sl[cid]
        st = states or {"normal": s["file"], "hover": {"file": s["file"], "modulate": TINT["hover"]},
                        "pressed": {"file": s["file"], "modulate": TINT["pressed"]}, "disabled": {"file": s["file"], "modulate": TINT["disabled"]}}
        els.append({"id": eid, "kind": "button", "rect": rect or s["rect"], "states": st, "ninepatch": s["ninepatch"]})

    ref_gold = gold(ref.astype(np.uint8))

    def fit(cid, dst=None, scan=True):
        """切片放到线框矩形 dst（默认切片自己的来源矩形）：在批准整图里扫出 dst 处金色边线的位置，外框 = 边线外扩该切片的金边内缩，
        使实机金边与整图逐像素重合；扫不到（或与线框差 > 16 px，多半扫到了内部控件）的边退回"线框矩形 + 切片原外扩量" """
        s_ = sl[cid]
        d = list(dst or s_["src"])
        src = s_["src"]
        ov = [src[0] - s_["rect"][0], src[1] - s_["rect"][1], s_["rect"][0] + s_["rect"][2] - src[0] - src[2], s_["rect"][1] + s_["rect"][3] - src[1] - src[3]]
        x0, y0, x1, y1 = d[0] - ov[0], d[1] - ov[1], d[0] + d[2] + ov[2], d[1] + d[3] + ov[3]
        ins = s_.get("inset")
        if scan and ins is not None:
            rb = borders(ref_gold, d, 16 if cid in FRAME_IDS else 4)   # 小件只在线框附近找，免得扫到相邻控件的边
            if rb["left"] is not None and abs(rb["left"] - d[0]) <= 16:
                x0 = rb["left"] - ins[0]
            if rb["top"] is not None and abs(rb["top"] - d[1]) <= 16:
                y0 = rb["top"] - ins[1]
            if rb["right"] is not None and abs(rb["right"] - (d[0] + d[2] - 1)) <= 16:
                x1 = rb["right"] + 1 + ins[2]
            if rb["bottom"] is not None and abs(rb["bottom"] - (d[1] + d[3] - 1)) <= 16:
                y1 = rb["bottom"] + 1 + ins[3]
        return [int(x0), int(y0), int(x1 - x0), int(y1 - y0)]

    # 底层到上层
    ninepatch("det_panel", "side_panel", fit("side_panel"))
    image("det_portrait_ring", "portrait_ring")
    els.append({"id": "det_portrait", "kind": "flatbox", "rect": [L["side_portrait"][0] + 6, L["side_portrait"][1] + 6, L["side_portrait"][2] - 12, L["side_portrait"][3] - 12], "style": {"bg": "#00000000"}})
    button("det_remove", "btn_remove", fit("btn_remove"))
    button("det_close", "btn_close", fit("btn_close"))
    ninepatch("det_stats", "side_stats", fit("side_stats"))
    sx, sy = L["side_stats"][0], L["side_stats"][1]
    for i in range(6):
        cx, cy = sx + 18 + (i % 3) * 196, sy + 24 + (i // 3) * 44
        els.append({"id": f"det_stat_icon_{i}", "kind": "flatbox", "rect": [cx, cy - 11, 22, 22], "style": {"bg": "#00000000"}})
    els.append({"id": "det_scroll", "kind": "flatbox", "rect": L["side_scroll"], "style": {"bg": "#00000000"}})
    ninepatch("det_track", "scroll_track", fit("scroll_track"))
    ninepatch("det_thumb", "scroll_thumb", fit("scroll_thumb"))
    ninepatch("det_row1", "side_row", fit("side_row", None, False))
    ninepatch("det_row2", "side_row", fit("side_row", L["side_row2"], False))
    image("det_handle", "handle")
    els.append({"id": "det_override", "kind": "toggle", "rect": sl["check_off"]["rect"], "states": {"off": sl["check_off"]["file"], "on": sl["check_on"]["file"]}})
    button("det_delete", "btn_delete", fit("btn_delete"))
    button("det_action", "dropdown", fit("dropdown"))
    button("det_p1", "dropdown", fit("dropdown", L["side_p1"]))
    button("det_p2", "dropdown", fit("dropdown", L["side_p2"]))
    button("det_c1", "dropdown_wide", fit("dropdown_wide"))
    row2 = L["side_row2"][1] - L["side_row1"][1]          # 带参数的条件版式取自第二张卡（整图里第 2 条指令），与 RuleRow.rel(id, "det_row2") 对应
    # 第 2 张卡的带参数条件行：游戏里每张卡同一版式（RuleRow 把它们放在条件一的行高上），纵向 = 第 1 张卡条件一 + 卡距
    pitch = row2 + ROW2_DY
    c1r = next(e for e in els if e["id"] == "det_c1")["rect"]
    r_c1n = fit("dropdown_wide", [L["side_c1"][0], L["side_c1"][1], L["side_c1"][2], L["side_c1"][3]], False)
    button("det_c1_narrow", "dropdown_wide", [c1r[0], c1r[1] + pitch, r_c1n[2], c1r[3]])
    r_cp = fit("dropdown", [L["side_cparam"][0], L["side_cparam"][1], L["side_cparam"][2], L["side_cparam"][3]], False)
    button("det_cparam", "dropdown", [r_cp[0], c1r[1] + pitch, r_cp[2], c1r[3]])
    button("det_c2", "dropdown_wide", fit("dropdown_wide", [L["side_c2"][0], L["side_c2"][1], 422, L["side_c2"][3]]))
    lx0, lx1, lg = L["side_c1"][0], L["side_c1"][0] + 422, L["side_logic"]
    ly = lg[1] + lg[3] // 2
    els.append({"id": "det_logic_line_l", "kind": "flatbox", "rect": [lx0, ly, lg[0] - 6 - lx0, 1], "style": {"bg": "#6E6670"}})
    els.append({"id": "det_logic_line_r", "kind": "flatbox", "rect": [lg[0] + lg[2] + 6, ly, lx1 - lg[0] - lg[2] - 6, 1], "style": {"bg": "#6E6670"}})
    els.append({"id": "det_logic", "kind": "button", "rect": lg, "flat_states": {s: {"bg": "#00000000", "border": "", "border_width": 0, "radius": 0} for s in ("normal", "hover", "pressed", "disabled")}})
    # 指令区与底部按钮之间的金色细分隔线（整图有，线框里画在 y = 918）
    sep = [L["side_scroll"][0], 917, L["side_stats"][0] + L["side_stats"][2] - L["side_scroll"][0], 2]
    ys = [y for y in range(905, 925) if ref_gold[y, sep[0] + 20:sep[0] + sep[2] - 20].mean() > 0.6]
    if ys:
        sep = [sep[0], ys[0], sep[2], len(ys)]
    sep_col = ref[sep[1]:sep[1] + sep[3], sep[0] + 40:sep[0] + sep[2] - 40].reshape(-1, 3).mean(axis=0).astype(int)
    els.append({"id": "det_footer_line", "kind": "flatbox", "rect": sep, "style": {"bg": "#%02X%02X%02X" % tuple(int(v) for v in sep_col)}})
    button("det_add", "btn_add", fit("btn_add"))
    button("det_beacon_btn", "btn_beacon", fit("btn_beacon"))
    # 等待参数（沿用行为行：p1 位置写「持续时间」，p2 位置为秒数框，右侧「秒」）
    els.append({"id": "det_wait_box", "kind": "button", "rect": fit("dropdown", L["side_p2"]), "states": els[[e["id"] for e in els].index("det_p2")]["states"], "ninepatch": sl["dropdown"]["ninepatch"]})
    # 信标模式边栏
    ninepatch("beacon_bar", "beacon_bar", fit("beacon_bar"))
    button("beacon_mode_once", "mode_on", fit("mode_on"), {"normal": sl["mode_off"]["file"], "hover": {"file": sl["mode_off"]["file"], "modulate": "#FFFFFF"},
                                                  "pressed": sl["mode_on"]["file"], "disabled": sl["mode_auto"]["file"]})
    for mid, lid in (("beacon_mode_loop", "beacon_mode_loop"), ("beacon_mode_pingpong", "beacon_mode_pingpong"), ("beacon_mode_auto", "beacon_mode_auto")):
        button(mid, "mode_off", fit("mode_off", L[lid]), {"normal": sl["mode_off"]["file"], "hover": {"file": sl["mode_off"]["file"], "modulate": "#FFFFFF"},
                                                                    "pressed": sl["mode_on"]["file"], "disabled": sl["mode_auto"]["file"]})
    button("beacon_done", "btn_done", fit("btn_done"))

    # 框体校准（calibration.json 的 "rect": [dx, dy]，来自 ui_geom_check 的框体偏移）：在算文字区之前平移，文字区随之相对按钮重算
    for e in els:
        rn = CAL.get(e["id"], {}).get("rect")
        if rn:
            rn = list(rn) + [0] * (4 - len(rn))
            e["rect"] = [e["rect"][0] + rn[0], e["rect"][1] + rn[1], e["rect"][2] + rn[2], e["rect"][3] + rn[3]]
    by_id = {e["id"]: e for e in els}
    inks = {}
    report = ["# side_detail 文字拟合", "", "| id | 文本 | 字号 | ref_ink | 字色 |", "|---|---|---|---|---|"]
    for tid, (text, fam, size, xy, anchor, align, max_w, overflow, thr, owner) in texts().items():
        cal = CAL.get(tid, {})
        size2 = size + int(cal.get("size_adjust", 0))
        box = _bbox(text, fam, size, xy, anchor)
        ink, color = measure_ink(ref, box, thr, 6 if owner is None else 3)
        if tid in ROW2_TEXTS and ink is not None and "det_c1" in inks:
            # 第 2 张卡的字贴着下拉边框，直接量容易把边框算进来或截掉一半：横向取实测左缘，纵向按第 1 张卡条件一的 ink 中心 + 卡距，高宽取字体外框
            c1 = inks["det_c1"]
            cy = c1[1] + c1[3] / 2 + (L["side_row2"][1] - L["side_row1"][1]) + ROW2_DY
            fb = font(fam, size).getbbox(text, anchor="ls")
            ink = [ink[0], cy - (fb[3] - fb[1]) / 2, fb[2] - fb[0], fb[3] - fb[1]]
        if ink is not None:
            inks[tid] = ink
        if ink is None:
            print(f"  ! {tid} 未在整图中检出文字，用线框外框")
            ink, color = [box[0], box[1], box[2] - box[0], box[3] - box[1]], "#DAC9B3"
        lr = label_rect(text, fam, size2, ink, align, max_w)
        nx, ny = cal.get("nudge", [0, 0])
        lr[0] += nx
        lr[1] += ny
        fnt = {"family": fam, "size": size2, "color": color}
        data = {"ref_ink": [round(v, 1) for v in ink], "ref_text": text}
        report.append(f"| {tid} | {text} | {size2} | {data['ref_ink']} | {color} |")
        if owner is None:
            e = {"id": tid, "kind": "text_style", "rect": [round(lr[0]), round(lr[1]), round(lr[2]), round(lr[3])], "text_rect": [0, 0, round(lr[2]), round(lr[3])],
                 "font": fnt, "align": align, "data": data}
            if overflow:
                e["overflow"] = overflow
            els.append(e)
        else:
            b = by_id[owner]
            r = b["rect"]
            tr = [round(lr[0] - r[0]), round(lr[1] - r[1]), round(lr[2]), round(lr[3])]
            tr[0] = max(0, tr[0])
            tr[2] = min(tr[2], r[2] - tr[0])
            b["text_rect"] = tr
            b["font"] = fnt
            b["align"] = align
            b["data"] = data
            if owner == "det_p2":
                by_id["det_wait_box"]["text_rect"] = tr
                by_id["det_wait_box"]["font"] = fnt
                by_id["det_wait_box"]["align"] = align
    # 等待「持续时间」「秒」与等待框同一行（字样同条件标题）
    by_id = {e["id"]: e for e in els}
    c1l = by_id["det_c1_label"]
    act = by_id["det_action"]
    p1 = L["side_p1"]
    dy = act["rect"][1] + act["text_rect"][1] - c1l["rect"][1]
    els.append({"id": "det_wait_label", "kind": "text_style", "rect": [p1[0] + 8, c1l["rect"][1] + dy, p1[2] - 8, c1l["rect"][3]], "text_rect": [0, 0, p1[2] - 8, c1l["rect"][3]],
                "font": c1l["font"], "align": "left"})
    els.append({"id": "det_wait_unit", "kind": "text_style", "rect": [L["side_p2"][0] + L["side_p2"][2] + 6, c1l["rect"][1] + dy, 40, c1l["rect"][3]], "text_rect": [0, 0, 40, c1l["rect"][3]],
                "font": c1l["font"], "align": "left"})
    els.append({"id": "det_desc", "kind": "text_style", "rect": L["side_desc"], "text_rect": [0, 0, L["side_desc"][2], L["side_desc"][3]],
                "font": {"family": "NotoSerifSC", "size": 18 + int(CAL.get("det_desc", {}).get("size_adjust", 0)), "color": by_id.get("det_cost", {}).get("font", {}).get("color", "#DAC9B3")},
                "align": "left", "overflow": "manual"})
    desc_ink, desc_col = measure_ink(ref, _bbox("人偶最先学会的分裂形态。骨刺从前臂增生弹出，", "NotoSerifSC", 18, (1434, 128), "la"), 60)
    if desc_col:
        els[-1]["font"]["color"] = desc_col
        nx, ny = CAL.get("det_desc", {}).get("nudge", [0, 0])
        f = font("NotoSerifSC", 18)
        asc, _ = f.getmetrics()
        bx0, by0, _, _ = f.getbbox("人偶最先学会的分裂形态。骨刺从前臂增生弹出，", anchor="ls")
        # 宽 = 整图第一行字形宽 + 一个字宽：与批准整图同样在「弹出，」后换行（样例说明）；更长的说明在此宽度内换行、超出两行时滚动
        w = round(desc_ink[2] + 18 * 1.2)
        els[-1]["rect"] = [round(desc_ink[0] - bx0 + nx), round(desc_ink[1] - asc - by0 + ny), w, L["side_desc"][3]]
        els[-1]["text_rect"] = [0, 0, w, L["side_desc"][3]]
        els[-1]["data"] = {"ref_ink_line1": [round(v, 1) for v in desc_ink]}
    # 「添加指令」行为列表样式（沿用局内 HUD 的 det_pick 颜色与图标，供 RuleEditor 读取）
    hud = json.loads((GODOT / "data/ui_layout/battle_hud.json").read_text(encoding="utf-8"))
    pick = next(e for e in hud["elements"] if e["id"] == "det_pick")
    els.append({"id": "det_pick", "kind": "flatbox", "rect": [L["side_scroll"][0], L["side_scroll"][1], L["side_scroll"][2], 38], "style": {"bg": "#00000000"}, "data": pick.get("data", {})})
    man = {"schema_version": 1, "screen": "side_detail", "design_size": [1920, 1080],
           "_comment": "由 tools/make_side_manifest.py 生成（批准整图 design.png + 图生图透明组件 + calibration.json），勿手改。",
           "elements": els}
    (D / "manifest.json").write_text(json.dumps(man, ensure_ascii=False, indent=1) + "\n", encoding="utf-8", newline="\n")
    (D / "FIT_REPORT.md").write_text("\n".join(report) + "\n", encoding="utf-8", newline="\n")
    print(f"side_detail：{len(els)} 个元素、{len(sl)} 张切片")
    return 0


if __name__ == "__main__":
    sys.exit(main())
