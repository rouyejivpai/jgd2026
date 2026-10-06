#!/usr/bin/env python3
"""对 capture_screens.gd 产出的截图做**像素级断言**。

为什么需要它：本工程的沙箱让 Godot 写不了项目目录，历史上我只能"读日志"验证逻辑，
所以坐标偏格、信标没渲染、文字溢出这类问题全是被用户肉眼发现的。
capture_screens.gd 负责出图 + 出元数据（SHOTMETA），本脚本负责**不靠眼睛地判对错**。

坐标换算与 BattleRenderer 完全一致：
    瓦片 (i,j) 的逻辑中心 = (i+0.5, j+0.5)
    世界像素 = 逻辑中心 * tile_px
    屏幕像素 = (世界 - 相机) * zoom + 视口/2

用法：
    python check_shots.py --shots D:/jgd2026/_shots --meta D:/jgd2026/_logs/shots7.txt
"""
from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path

from PIL import Image

# BattleRenderer 里的颜色（改那边要同步改这里）
C_BEACON = (0.35, 0.80, 1.00)
C_GOAL_EDGE = (0.45, 0.95, 0.65)
C_WALL = (0.34, 0.36, 0.42)
C_BG = (0.10, 0.11, 0.14)
C_OUTSIDE = (0.035, 0.040, 0.055)

results: list[tuple[bool, str]] = []


def ok(cond: bool, msg: str) -> None:
    results.append((bool(cond), msg))


def near(px, want, tol=0.08) -> bool:
    return all(abs(px[k] - want[k]) <= tol for k in range(3))


def to_screen(tile, meta):
    """瓦片 → 屏幕像素（与 Godot 里 BattleRenderer + Camera2D 的换算一致）"""
    tile_px = meta.get("tile_px", 64.0)
    zoom = meta.get("zoom", 1.0)
    cam = meta.get("camera", [0.0, 0.0])
    vw, vh = meta["viewport"]
    wx = (tile[0] + 0.5) * tile_px
    wy = (tile[1] + 0.5) * tile_px
    sx = (wx - cam[0]) * zoom + vw * 0.5
    sy = (wy - cam[1]) * zoom + vh * 0.5
    return int(round(sx)), int(round(sy))


def load_metas(meta_file: Path) -> dict:
    out = {}
    if not meta_file.exists():
        return out
    for line in meta_file.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line.startswith("SHOTMETA ") or line.startswith("SHOTMETA_ALL"):
            continue
        try:
            j = json.loads(line[len("SHOTMETA "):])
        except json.JSONDecodeError:
            continue
        out[j["name"]] = j
    return out


def sample_ring(img, sx, sy, radius_px, n=8):
    """在中心周围取一圈采样点。

    为什么要取圈：信标中心画的是**序号数字**（深蓝 0.05,0.10,0.16），
    直接采中心会采到数字而不是信标底色，产生误报（实测踩到）。
    """
    pts = []
    for k in range(n):
        a = 2 * math.pi * k / n
        x = int(round(sx + radius_px * math.cos(a)))
        y = int(round(sy + radius_px * math.sin(a)))
        if 0 <= x < img.width and 0 <= y < img.height:
            pts.append(tuple(c / 255 for c in img.getpixel((x, y))[:3]))
    return pts


def check_shot(img: Image.Image, meta: dict, verbose: bool, other: dict) -> None:
    name = meta["name"]
    w, h = meta["viewport"]
    ui = meta.get("ui") or {}
    dr = ui.get("drawer_rect") or [0, 0, 0, 0]
    drawer_open = bool(ui.get("drawer_open"))

    # ---- 共享局部变量：**一律在这里定义** ----
    #
    # 【为什么要集中】这些值（tile_px / modal_up）原先散在函数中段才赋值，
    # 而后来新增的断言块插在前面，就出现"用了还没赋值的局部变量" →
    # `UnboundLocalError`。这个坑在本文件里已经踩了两次（第 79 条），
    # 所以直接把共享量提到开头，让后面任何位置都能安全使用。
    tile_px = meta.get("tile_px", 64.0)
    modal_up = (bool(ui.get("intro_showing")) or bool(ui.get("result_showing"))
                or bool(meta.get("story_showing"))
                or bool(ui.get("help_showing")) or bool(ui.get("pause_showing")))
    # 抽屉展开时它盖住的那块区域不能做颜色断言（否则会把抽屉底色当成瓦片颜色）
    occl_x = dr[0] + dr[2] if drawer_open else -1e9


    ok(img.size == (w, h), f"{name}: 尺寸 {img.size} == 元数据 {w}x{h}")
    ok(meta.get("save_err", 0) == 0, f"{name}: 落盘无错误（err={meta.get('save_err')}）")
    ok(meta.get("unique_colors", 0) > 10, f"{name}: 有画面内容（唯一色 {meta.get('unique_colors')}）")
    ok(meta.get("fg_samples", 0) > 0, f"{name}: 有前景像素（{meta.get('fg_samples')}）")

    # 界面元素不许越界（文字溢出/控件跑出屏幕的自动化检测）
    for key in ("toolbar_rect", "banner_rect"):
        r = ui.get(key)
        if not r:
            continue
        x, y, rw, rh = r
        ok(x >= -1 and y >= -1 and x + rw <= w + 1 and y + rh <= h + 1,
           f"{name}: {key} 在屏内（{x:.0f},{y:.0f} {rw:.0f}x{rh:.0f}）")
    if dr:
        x, y, rw, rh = dr
        if drawer_open:
            # 【1/3 → 0.42】指令面板改成**左条件 / 右行为**两栏后（用户补充需求），
            # 1/3 分两栏每栏仅约 295px，类型下拉会被压到显示不全。
            # 这里断言"比例**够两栏用**"，而不是钉死某个数字 ——
            # 钉死数字的代价是：以后一改布局就得改断言，而且看不出为什么是这个数。
            _per_col = (rw - 40.0 - 26.0) * 0.5
            ok(_per_col >= 340.0,
               f"{name}: **抽屉宽度够左右两栏**（宽 {rw:.0f}，每栏约 {_per_col:.0f}px）")
            ok(x >= -1 and x + rw <= w + 1, f"{name}: 展开的抽屉横向不出屏（{x:.0f}..{x + rw:.0f}）")
            ok(y + rh <= h + 1, f"{name}: 展开的抽屉底部不出屏（{y + rh:.0f} <= {h}）")
        else:
            ok(x + rw <= 1, f"{name}: 收起的抽屉整体在屏幕左侧之外（右边缘 {x + rw:.0f}）")
        tb = ui.get("toolbar_rect")
        if tb:
            ok(y >= tb[1] + tb[3] - 1,
               f"{name}: 抽屉顶端({y:.0f}) 不高于工具条底边({tb[1] + tb[3]:.0f})")

    # 敌方视野圈：用**同一关的"关掉视野"那张**做 A/B。
    #
    # 【为什么不做单张颜色断言】圈是半透明描边，压在墙/地板上会混色
    # （实测墙上写成 0.65,0.45,0.42，既不等于墙色也不等于描边色），
    # 单张图里没有可靠的颜色判据。A/B 则与底色无关：
    # **圈上的像素必须变、圈外的像素必须一模一样。**
    vision_rings: list = []
    tile_px_v = meta.get("tile_px", 64.0)
    for e in (meta.get("enemies") or []):
        if float(e["radius"]) > 0:
            vision_rings.append((e["logic"][0], e["logic"][1], float(e["radius"])))

    # 【只比**显式配对**的那张】原来写成"只要开了视野就拿 12_no_vision 比"，
    # 于是子弹在飞 / 结算 / 第二关三张全被误判（它们与前一张不是同一场景状态）。
    pair_name = meta.get("ab_pair") or ""
    partner = other.get(pair_name) if pair_name else None
    # 【守卫：不许静默跳过】如果这张图**本该**有成对对照，就必须真的有。
    # 我踩过一次：配对标注没进元数据 → 整块 A/B 断言被跳过，而断言数变少、
    # 结果全绿 —— **"少测了"伪装成"通过了"**。
    # 只对**按约定用于 A/B 的那张**（图名含 `enemy_vision`）强求配对：
    # 子弹在飞 / 结算 / 第二关那几张只是碰巧也开着视野，不属于任何对照对。
    if "enemy_vision" in name:
        ok(bool(pair_name),
           f"{name}: 这张是对照图，必须声明 ab_pair，否则 A/B 断言会被静默跳过")
        if pair_name:
            ok(pair_name in other,
               f"{name}: 声明的对照图 {pair_name} 确实存在")
    if partner is not None and vision_rings:
        cam = meta.get("camera", [0.0, 0.0])
        zoom = meta.get("zoom", 1.0)
        vw, vh = meta["viewport"]
        for ex, ey, r_tiles in vision_rings:
            wx, wy = ex * tile_px_v, ey * tile_px_v
            cx = (wx - cam[0]) * zoom + vw * 0.5
            cy = (wy - cam[1]) * zoom + vh * 0.5
            r_px = r_tiles * tile_px_v * zoom
            changed = 0
            tried = 0
            same_out = 0
            tried_out = 0
            for k in range(24):
                a = 2 * math.pi * k / 24
                # 圈上：应当因为描边而变色
                sx = int(round(cx + r_px * math.cos(a)))
                sy = int(round(cy + r_px * math.sin(a)))
                if 0 <= sx < img.width and 0 <= sy < img.height:
                    p1 = img.getpixel((sx, sy))[:3]
                    p2 = partner.getpixel((sx, sy))[:3]
                    tried += 1
                    if sum(abs(p1[i] - p2[i]) for i in range(3)) > 12:
                        changed += 1
                # 圈外（半径 0.5 倍处）：必须完全一致
                sx2 = int(round(cx + r_px * 0.5 * math.cos(a)))
                sy2 = int(round(cy + r_px * 0.5 * math.sin(a)))
                if 0 <= sx2 < img.width and 0 <= sy2 < img.height:
                    q1 = img.getpixel((sx2, sy2))[:3]
                    q2 = partner.getpixel((sx2, sy2))[:3]
                    tried_out += 1
                    if sum(abs(q1[i] - q2[i]) for i in range(3)) == 0:
                        same_out += 1
            if tried > 0:
                if verbose:
                    print(f"    [A/B] 视野圈 r={r_tiles:.1f}格 环上变色 {changed}/{tried} 圈外相同 {same_out}/{tried_out}")
                ok(changed >= tried * 0.7,
                   f"{name}: **敌人视野圈确实画在半径 {r_tiles:.1f} 格上**"
                   f"（环上 {changed}/{tried} 点相对关视野那张变了色）")
                ok(tried_out > 0 and same_out >= tried_out * 0.85,
                   f"{name}: **圈外像素与关视野那张基本一致**（{same_out}/{tried_out}）")

    def on_vision_ring(tile) -> bool:
        """该格中心是否落在某个视野圈的描边附近。

        视野圈画在最上层，会盖住它经过的地形与信标 —— 被盖住的格子不能做颜色断言。
        """
        lx, ly = tile[0] + 0.5, tile[1] + 0.5
        for ex, ey, r in vision_rings:
            d = math.hypot(lx - ex, ly - ey)
            if abs(d - r) < 0.22:
                return True
        return False

    # 指令面板图必须能看到排序控件与**拖拽插入指示线**（FR-CMD-08，P0）
    if "play_rule_panel" in name:
        ok(int(ui.get("rule_count") or 0) >= 2,
           f"{name}: 面板里有 >=2 条指令（实际 {ui.get('rule_count')}）")
        ok(bool(ui.get("drop_indicator")),
           f"{name}: **拖拽时插入了指示线**（FR-CMD-08 的拖拽反馈）")
        # 详设 10 的 1.3：右侧状态 = 已用信标 n/N + **无效指令角标**。
        # 截图里那条指令故意引用了不存在的信标，角标必须出现。
        ok(bool(ui.get("invalid_badge_visible")),
           f"{name}: **工具条出现「无效指令」角标**（{ui.get('invalid_text')}）")

    # 编辑器「新建关卡」那张：状态栏必须提示**尚未保存**，
    # 而且地图是空白 7×7（新建出来的默认形状）
    if "editor_new_level" in name:
        st = str(meta.get("editor_status") or "")
        emp = meta.get("editor_map") or {}
        ok(emp.get("w") == 7 and emp.get("h") == 7,
           f"{name}: 新建出来是 7x7 空白地图（实际 {emp.get('w')}x{emp.get('h')}）")
        ok(len(st) > 0, f"{name}: 状态栏给出了提示（{st!r}）")

    # ================= 第 14 轮：用户报的四个问题的针对性断言 =================

    # ---- 问题 1：主菜单的开始/编辑器按钮必须在**标题下方** ----
    if meta.get("menu_entries") and meta.get("menu_title_rect"):
        tx, ty, tw, th = meta["menu_title_rect"]
        for e in meta["menu_entries"]:
            ex, ey, ew, eh = e["rect"]
            ok(ey >= ty + th - 1.0,
               f"{name}: **「{e['name']}」在标题下方**（按钮顶 {ey:.0f} >= 标题底 {ty + th:.0f}）")
        # 副标题（若有）也要在按钮之上
        if meta.get("menu_subtitle_rect"):
            sx, sy, sw, sh = meta["menu_subtitle_rect"]
            for e in meta["menu_entries"]:
                ok(e["rect"][1] >= sy + sh - 1.0,
                   f"{name}: 「{e['name']}」在副标题下方（按钮顶 {e['rect'][1]:.0f} >= 副标题底 {sy + sh:.0f}）")
        # 两个入口都不能压到标题的水平范围之外（顺带验没有被挤到角落）
        ok(len(meta["menu_entries"]) >= 2,
           f"{name}: 主菜单有两个入口（{len(meta['menu_entries'])}）")

    # 「打开关卡」列表（用户要求：列表项显示关卡名称）
    if "open_level" in name:
        items = meta.get("open_menu_items") or []
        ok(bool(meta.get("open_menu_visible")),
           f"{name}: **「打开关卡」菜单处于展开状态**（截到的是列表本身）")
        ok(len(items) >= 3, f"{name}: 列表里有 {len(items)} 关")
        # 列表项必须是**名称**（含「第」这种中文序号），不能是 id
        ok(all(("第" in x) for x in items) if items else False,
           f"{name}: **列表项显示关卡名称**（{items}）")
        ok(not any(x.startswith("tutorial_") for x in items),
           f"{name}: **列表项不是 id**（{items}）")

    # ---- 问题 2：地图外框必须**四条边都在**（"偶尔看不到边界线"）----
    if meta.get("frame_samples") and not modal_up:
        cam_f = meta.get("camera", [0.0, 0.0])
        zoom_f = meta.get("zoom", 1.0)
        vwf, vhf = meta["viewport"]
        C_BORDER = (0.45, 0.50, 0.62)
        missing = []
        for k, ws in enumerate(meta["frame_samples"]):
            sxf = int(round((ws[0] - cam_f[0]) * zoom_f + vwf * 0.5))
            syf = int(round((ws[1] - cam_f[1]) * zoom_f + vhf * 0.5))
            found_f = False
            for dxf in range(-3, 4):
                for dyf in range(-3, 4):
                    x3, y3 = sxf + dxf, syf + dyf
                    if 0 <= x3 < img.width and 0 <= y3 < img.height:
                        pxf = tuple(c / 255 for c in img.getpixel((x3, y3))[:3])
                        if near(pxf, C_BORDER, 0.12):
                            found_f = True
            if not found_f:
                missing.append(k)
            if verbose:
                print(f"    [标定] 外框边{k} 世界{ws} → 屏幕({sxf},{syf}) 找到={found_f}")
        ok(not missing,
           f"{name}: **地图外框四条边都画出来了**（缺的边序号：{missing}）")

    # ---- 问题 2b：内部网格线必须可见（不能淡到看不见）----
    if meta.get("grid_sample") and not modal_up:
        cam_g = meta.get("camera", [0.0, 0.0])
        zoom_g = meta.get("zoom", 1.0)
        vwg, vhg = meta["viewport"]
        gws = meta["grid_sample"]
        gxg = int(round((gws[0] - cam_g[0]) * zoom_g + vwg * 0.5))
        gyg = int(round((gws[1] - cam_g[1]) * zoom_g + vhg * 0.5))
        # 网格线是"比地板略亮"的线，所以判据是：线上比线旁明显更亮
        best_line = 0.0
        for dxg in range(-3, 4):
            x4 = gxg + dxg
            if 0 <= x4 < img.width and 0 <= gyg < img.height:
                pg = img.getpixel((x4, gyg))
                best_line = max(best_line, sum(pg[:3]) / 3.0)
        # 参考：往线右侧 20px 处（格子内部）取样作为地板亮度
        ref_x = gxg + 20
        floor_lum = 0.0
        if 0 <= ref_x < img.width and 0 <= gyg < img.height:
            pf = img.getpixel((ref_x, gyg))
            floor_lum = sum(pf[:3]) / 3.0
        ok(best_line > floor_lum + 3.0,
           f"{name}: **网格线可见**（线亮度 {best_line:.1f} 比地板 {floor_lum:.1f} 亮）")

    # ---- 问题 3：**我方**视野圈也要画出来（不能只画敌方）----
    if meta.get("visions") and meta.get("show_vision") and not modal_up:
        cam_v = meta.get("camera", [0.0, 0.0])
        zoom_v = meta.get("zoom", 1.0)
        vwv, vhv = meta["viewport"]
        tp = meta.get("tile_px", 64.0)
        C_ALLY_V = (0.55, 1.0, 0.70)
        C_ENEMY_V = (1.0, 0.55, 0.42)
        ally_ok = ally_total = 0
        enemy_ok = enemy_total = 0
        for vi in meta["visions"]:
            cx = vi["logic"][0] * tp
            cy = vi["logic"][1] * tp
            rad = vi["radius"] * tp * zoom_v
            scx = (cx - cam_v[0]) * zoom_v + vwv * 0.5
            scy = (cy - cam_v[1]) * zoom_v + vhv * 0.5
            want_v = C_ALLY_V if int(vi["team"]) == 0 else C_ENEMY_V
            # 【弧是半透明的，不能拿原色直接比】alpha 各自不同，且弧会叠在
            # 地板 / 墙 / 目标区等不同底色上，所以固定一个期望色一定对不上
            # （我第一版就是这么写的：0/2 命中）。
            # 正确做法：以**同一张图里圈内侧一点**作为底色参考，
            # 按 `弧色×alpha + 底色×(1-alpha)` 算出该点**应有**的混色再比。
            alpha_v = 0.50 if int(vi["team"]) == 0 else 0.55
            hit_v = False
            for step in range(24):
                ang = 6.283185 * step / 24.0
                cos_a = math.cos(ang)
                sin_a = math.sin(ang)
                px5 = int(round(scx + rad * cos_a))
                py5 = int(round(scy + rad * sin_a))
                # 圈内侧 6px 处作为底色参考（避开 2px 的弧本身）
                rx5 = int(round(scx + (rad - 6.0) * cos_a))
                ry5 = int(round(scy + (rad - 6.0) * sin_a))
                if not (0 <= rx5 < img.width and 0 <= ry5 < img.height):
                    continue
                ref_v = tuple(c / 255 for c in img.getpixel((rx5, ry5))[:3])
                expect_v = tuple(
                    want_v[k] * alpha_v + ref_v[k] * (1.0 - alpha_v) for k in range(3))
                for dxv in range(-2, 3):
                    for dyv in range(-2, 3):
                        x5, y5 = px5 + dxv, py5 + dyv
                        if 0 <= x5 < img.width and 0 <= y5 < img.height:
                            pv = tuple(c / 255 for c in img.getpixel((x5, y5))[:3])
                            if near(pv, expect_v, 0.10):
                                hit_v = True
            if int(vi["team"]) == 0:
                ally_total += 1
                ally_ok += 1 if hit_v else 0
            else:
                enemy_total += 1
                enemy_ok += 1 if hit_v else 0
        if ally_total > 0:
            ok(ally_ok == ally_total,
               f"{name}: **我方视野圈画出来了**（{ally_ok}/{ally_total} 个单位命中我方视野色）")
        if enemy_total > 0:
            ok(enemy_ok == enemy_total,
               f"{name}: 敌方视野圈画出来了（{enemy_ok}/{enemy_total}）")

    # ---- 问题 4：指令面板是**左条件 / 右行为** ----
    # 【在 ui 子字典里】`_ui_meta()` 把两栏矩形放在 ui 下，不是顶层
    sr = ui.get("split_rects")
    # 【守卫：不许静默跳过】指令面板展开的那张图**必须**能拿到两栏矩形。
    # 我第一版用 find_child 拿不到 → 整块断言不执行 → 断言数变少而报告全绿。
    if drawer_open and int(ui.get("rule_count") or 0) > 0:
        ok(bool(sr and sr.get("conds") and sr.get("acts")),
           f"{name}: 指令面板展开时必须报告左右两栏矩形（否则左右布局断言会被静默跳过）")
    if sr and sr.get("conds") and sr.get("acts"):
        cxc, cyc, cwc, chc = sr["conds"]
        cxa, cya, cwa, cha = sr["acts"]
        ok(cxc + cwc <= cxa + 1.0,
           f"{name}: **条件栏在行为栏左侧**（条件右 {cxc + cwc:.0f} <= 行为左 {cxa:.0f}）")
        # 两栏要有实质性的竖直重叠（否则是上下堆叠而不是左右并排）
        top = max(cyc, cya)
        bot = min(cyc + chc, cya + cha)
        overlap = max(0.0, bot - top)
        ok(overlap > 40.0,
           f"{name}: **两栏竖直方向并排**（重叠 {overlap:.0f}px > 40px）")
        ok(cwc >= 200.0 and cwa >= 200.0,
           f"{name}: 两栏都有可用宽度（条件 {cwc:.0f} / 行为 {cwa:.0f}）")

    # 子弹在飞（FR-CBT-01「有明显飞行过程，不是瞬时命中」）
    #
    # 【为什么能这样断言】子弹是 `Polygon2D`，我方黄色 (1,0.95,0.5)、敌方橙色 (1,0.5,0.2)。
    # 元数据给了它在**逻辑坐标**下的位置，换算成屏幕像素直接采点即可 ——
    # 这比"图里有黄色像素"强得多：它验的是**画在了正确的位置上**（跟着飞行推进）。
    if meta.get("projectiles"):
        tile_px_p = meta.get("tile_px", 64.0)
        cam_p = meta.get("camera", [0.0, 0.0])
        zoom_p = meta.get("zoom", 1.0)
        vwp, vhp = meta["viewport"]
        C_ALLY_BULLET = (1.0, 0.95, 0.5)
        C_ENEMY_BULLET = (1.0, 0.5, 0.2)
        hit_shots = 0
        for pr in meta["projectiles"]:
            wx = pr["logic"][0] * tile_px_p
            wy = pr["logic"][1] * tile_px_p
            sx = int(round((wx - cam_p[0]) * zoom_p + vwp * 0.5))
            sy = int(round((wy - cam_p[1]) * zoom_p + vhp * 0.5))
            want = C_ALLY_BULLET if int(pr["team"]) == 0 else C_ENEMY_BULLET
            found = False
            # 子弹有半径，中心偏 2px 内命中即可
            for dx in range(-2, 3):
                for dy in range(-2, 3):
                    x2, y2 = sx + dx, sy + dy
                    if 0 <= x2 < img.width and 0 <= y2 < img.height:
                        px = tuple(c / 255 for c in img.getpixel((x2, y2))[:3])
                        if near(px, want, 0.10):
                            found = True
            if found:
                hit_shots += 1
            if verbose:
                print(f"    [标定] 子弹 team={pr['team']} 逻辑{pr['logic']} → 屏幕({sx},{sy}) 命中={found}")
        ok(hit_shots == len(meta["projectiles"]),
           f"{name}: **子弹画在它当前飞行的位置上**（{hit_shots}/{len(meta['projectiles'])} 颗命中）")
    if "projectile_in_flight" in name:
        ok(len(meta.get("projectiles") or []) >= 1,
           f"{name}: 这一帧确实有子弹在空中（{len(meta.get('projectiles') or [])} 颗）")

    # 跨关一致性：每张玩法图都必须"地图占满视野 + 有单位可见"
    if meta.get("map") and not modal_up:
        mw = int(meta["map"]["w"])
        mh = int(meta["map"]["h"])
        ok(mw > 0 and mh > 0, f"{name}: 地图尺寸合理（{mw}×{mh}）")
        # 用地图矩形占视口的比例验"看全而不是缩成一点"
        tile_w = tile_px * meta.get("zoom", 1.0)
        mr_w = mw * tile_w
        mr_h = mh * tile_w
        fill = max(mr_w / w, mr_h / h)
        ok(fill >= 0.6,
           f"{name}: 地图占满视野（最大边 {fill * 100:.0f}%，应 >=60%）")
        ok(mr_w <= w + 2 and mr_h <= h + 2,
           f"{name}: 地图完整落在视口内（{mr_w:.0f}x{mr_h:.0f} vs {w}x{h}）")

    # 编辑器三栏：不重叠、两侧定宽（M4-1 的硬验收）
    er = meta.get("editor_rects")
    ecw = meta.get("editor_cond_widgets")
    if ecw:
        # FR-EDIT-04/05：胜负条件必须能选类型、能改参数（不只是只读文本）
        ok(bool(ecw.get("type_picker")),
           f"{name}: **编辑器有胜负条件的类型下拉**（FR-EDIT-04/05）")
        # 秒数控件的有无**由关卡数据决定**（有 timeout/survive_until 才该有），
        # 不能写死 —— 新建关卡的失败条件是 all_allies_dead，本来就不该有秒数框
        ok(bool(ecw.get("seconds_field")) == bool(ecw.get("expect_seconds")),
           f"{name}: 秒数参数控件与关卡数据一致"
           f"（期望 {ecw.get('expect_seconds')} / 实际 {ecw.get('seconds_field')}）")
    if er:
        lf, ct, rt = er["left"], er["center"], er["right"]
        ok(abs(lf[2] - 260) < 2, f"{name}: 编辑器左栏宽 260（实际 {lf[2]:.0f}）")
        ok(abs(rt[2] - 340) < 2, f"{name}: 编辑器右栏宽 340（实际 {rt[2]:.0f}）")
        ok(lf[0] + lf[2] <= ct[0] + 0.5,
           f"{name}: **编辑器左栏与中栏不重叠**（{lf[0] + lf[2]:.0f} <= {ct[0]:.0f}）")
        ok(ct[0] + ct[2] <= rt[0] + 0.5,
           f"{name}: **编辑器中栏与右栏不重叠**（{ct[0] + ct[2]:.0f} <= {rt[0]:.0f}）")
        ok(abs((rt[0] + rt[2]) - w) < 3,
           f"{name}: 编辑器三栏合计占满宽度（{rt[0] + rt[2]:.0f} vs {w}）")

    # 模态界面（介绍 / 结算 / 机制说明 / 暂停菜单）都带**全屏遮罩**，整张地图会被压暗，
    # 所以它们显示时不做瓦片颜色断言。`modal_up` 已在函数开头算好。
    # 【教训】这个名单要跟着新增的模态界面一起加 —— 我加了两张新图后又误报了一轮。

    def occluded(sx: int, sy: int) -> bool:
        if modal_up:
            return True
        return drawer_open and sx <= occl_x and sy >= dr[1]

    # 模态弹窗必须**居中**且不越界。
    # 这条是为一个真实踩过的 bug 加的：挂 CanvasLayer 下的 Control 尺寸实测为 (0,0)，
    # `CenterContainer` 会在零尺寸里居中 → 面板贴到左上角（截图里一眼可见）。
    #
    # 另外按**图名约定**校验"该出现的东西真的出现了"：
    # 实测过一种静默失效 —— 给规则加了条件后第一关就打不通了，
    # 于是 `07_result_screen.png` 悄悄退化成了推演期画面，而所有像素断言照样通过。
    if "intro_dialog" in name:
        ok(bool(ui.get("intro_showing")), f"{name}: 该图应当正在显示关卡介绍弹窗")
    if "result_screen" in name:
        ok(bool(ui.get("result_showing")), f"{name}: 该图应当正在显示结算界面")
    if "help_panel" in name:
        ok(bool(ui.get("help_showing")), f"{name}: 该图应当正在显示机制说明面板")
        ok(int(ui.get("help_sections") or 0) >= 6,
           f"{name}: 机制说明读到了 >=6 节（实际 {ui.get('help_sections')}）")
    if "pause_menu" in name:
        ok(bool(ui.get("pause_showing")), f"{name}: 该图应当正在显示暂停菜单")
    for showing_key, rect_key, label in (
        ("intro_showing", "intro_panel_rect", "关卡介绍弹窗"),
        ("result_showing", "result_panel_rect", "结算界面"),
        ("help_showing", "help_panel_rect", "机制说明面板"),
    ):
        if not ui.get(showing_key):
            continue
        r = ui.get(rect_key)
        if not r:
            continue
        px, py, pw, ph = r
        ok(px >= -1 and py >= -1 and px + pw <= w + 1 and py + ph <= h + 1,
           f"{name}: {label} 在屏内（{px:.0f},{py:.0f} {pw:.0f}x{ph:.0f}）")
        cx, cy = px + pw / 2, py + ph / 2
        ok(abs(cx - w / 2) < w * 0.02 and abs(cy - h / 2) < h * 0.05,
           f"{name}: **{label} 居中**（中心 {cx:.0f},{cy:.0f} vs 屏幕中心 {w / 2:.0f},{h / 2:.0f}）")
        ok(pw <= w * 0.9 and ph <= h * 0.9,
           f"{name}: {label} 不超出屏幕 90%（{pw:.0f}x{ph:.0f}）")



    # 信标：在中心周围一圈里找信标底色（避开中心的序号数字）
    #
    # 【D-22 之后颜色按归属单位变化】所以期望色取**元数据里渲染器报出的颜色**，
    # 不是写死的青色；旧的纯瓦片格式仍兼容（回落到 C_BEACON）。
    for entry in (meta.get("beacons") or []):
        if isinstance(entry, dict):
            tile = entry.get("tile")
            want = tuple(entry.get("color") or C_BEACON)
            owner = int(entry.get("owner", 0) or 0)
            ordinal = int(entry.get("ordinal", 1) or 1)
        else:
            tile, want, owner, ordinal = entry, C_BEACON, 0, 1
        if tile is None:
            continue
        sx, sy = to_screen(tile, meta)
        if occluded(sx, sy) or on_vision_ring(tile):
            continue
        pts = sample_ring(img, sx, sy, tile_px * meta.get("zoom", 1.0) * 0.13)
        hit = sum(1 for p in pts if near(p, want, 0.16))
        if verbose:
            print(f"    [标定] 信标{tile}(归属{owner}) 屏幕({sx},{sy}) 环上命中 {hit}/{len(pts)} 期望色={tuple(round(c,2) for c in want)}")
        ok(hit >= 2,
           f"{name}: **信标{tile} 画在瓦片中心**（环上 {hit}/{len(pts)} 点匹配它归属单位的颜色）")
        if owner > 0:
            ok(ordinal >= 1,
               f"{name}: 信标{tile} 的序号是**该单位自己的第 {ordinal} 个**（D-22 不可公用）")

    # 剧情播放器（D-25）
    if "story" in name:
        ok(bool(meta.get("story_showing")), f"{name}: 该图应当正在显示剧情播放器")
        ok(int(meta.get("story_segments", 0)) >= 2,
           f"{name}: 剧本至少 2 段（实际 {meta.get('story_segments')}）")
        # 【两种格式都认】capture 那边用 `_rect_arr()` 输出 **[x, y, w, h]**；
        # 我第一版按字典读（sr.get("x")）直接 AttributeError 把整个检查器打断了。
        sr = meta.get("story_rect")
        if isinstance(sr, dict):
            rx, ry = float(sr.get("x", 0)), float(sr.get("y", 0))
            rw, rh = float(sr.get("w", 0)), float(sr.get("h", 0))
        elif isinstance(sr, (list, tuple)) and len(sr) >= 4:
            rx, ry, rw, rh = (float(v) for v in sr[:4])
        else:
            rx = ry = rw = rh = 0.0
        if rw > 0 and rh > 0:
            ok(0 <= rx <= 600 and 0 <= ry <= 400,
               f"{name}: 剧情面板留了边距（x={rx:.0f}, y={ry:.0f}）")
            ok(rw > 1000 and rh > 500,
               f"{name}: 剧情面板够大（{rw:.0f}x{rh:.0f}）")

    for tile in (meta.get("goals") or []):
        sx, sy = to_screen(tile, meta)
        if occluded(sx, sy) or on_vision_ring(tile):
            continue
        px = tuple(c / 255 for c in img.getpixel((sx, sy))[:3])
        if verbose:
            print(f"    [标定] 终点{tile} 屏幕({sx},{sy}) 实测{tuple(round(c, 3) for c in px)}")
        ok(px[1] > px[0] + 0.10 and px[1] > px[2] + 0.05,
           f"{name}: **终点{tile} 是绿色**（实测{tuple(round(c, 2) for c in px)}）")

    for tile in (meta.get("walls") or []):
        sx, sy = to_screen(tile, meta)
        if occluded(sx, sy) or on_vision_ring(tile):
            continue
        px = tuple(c / 255 for c in img.getpixel((sx, sy))[:3])
        if verbose:
            print(f"    [标定] 墙{tile} 屏幕({sx},{sy}) 实测{tuple(round(c, 3) for c in px)}")
        ok(max(px) - min(px) < 0.15 and 0.25 < sum(px) / 3 < 0.60,
           f"{name}: **墙{tile} 是灰色**（实测{tuple(round(c, 2) for c in px)}）")

    # 单位：采样它的**实际绘制位置**（position_logic * tile_px），而不是瓦片中心。
    # 用瓦片中心会漏掉"单位偏半格"这类 bug —— 而那正是要抓的东西。
    for u in (meta.get("units") or []):
        lg = u.get("logic") or [(u["tile"][0] + 0.5), (u["tile"][1] + 0.5)]
        wx, wy = lg[0] * tile_px, lg[1] * tile_px
        cam = meta.get("camera", [0.0, 0.0])
        zoom = meta.get("zoom", 1.0)
        sx = int(round((wx - cam[0]) * zoom + w * 0.5))
        sy = int(round((wy - cam[1]) * zoom + h * 0.5))
        if occluded(sx, sy):
            continue
        px = tuple(c / 255 for c in img.getpixel((sx, sy))[:3])
        if verbose:
            print(f"    [标定] 单位绘制点({sx},{sy}) 实测{tuple(round(c, 3) for c in px)}")
        ok(not near(px, C_BG, 0.03) and not near(px, C_OUTSIDE, 0.03),
           f"{name}: 单位在绘制位置可见（({sx},{sy}) 实测{tuple(round(c, 2) for c in px)}）")
        # 并且单位必须**落在自己那一格里**（防"偏半格"回归）
        ok(int(math.floor(lg[0])) == u["tile"][0] and int(math.floor(lg[1])) == u["tile"][1],
           f"{name}: 单位逻辑坐标 {tuple(round(v, 3) for v in lg)} 落在瓦片 {u['tile']} 内")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--shots", default="D:/jgd2026/_shots")
    ap.add_argument("--meta", default="D:/jgd2026/_logs/shots7.txt")
    ap.add_argument("-v", "--verbose", action="store_true", help="打印每个采样点的实测颜色（标定用）")
    args = ap.parse_args()

    shots = Path(args.shots)
    metas = load_metas(Path(args.meta))
    pngs = sorted(shots.glob("*.png"))
    ok(len(pngs) >= 6, f"截图数量 >= 6（实际 {len(pngs)}）")

    for p in pngs:
        meta = metas.get(p.stem)
        if meta is None:
            ok(False, f"{p.stem}: 缺少 SHOTMETA 元数据")
            continue
        with Image.open(p) as im:
            imgs = {}
    for p in pngs:
        with Image.open(p) as im:
            imgs[p.stem] = im.convert("RGB").copy()
    for p in pngs:
        meta = metas.get(p.stem)
        if meta is None:
            ok(False, f"{p.stem}: 缺少 SHOTMETA 元数据")
            continue
        check_shot(imgs[p.stem], meta, args.verbose, imgs)

    passed = sum(1 for c, _ in results if c)
    print(f"\n=== 像素断言：{passed}/{len(results)} 通过 ===")
    for cond, msg in results:
        if not cond:
            print(f"  [FAIL] {msg}")
    if passed == len(results):
        # 别用 emoji：Windows 控制台默认 GBK，打印 U+2705 会抛
        # UnicodeEncodeError（实测踩到，断言明明全过却报 exit=1）
        print("全部通过 [OK]")
        return 0
    print(f"失败 {len(results) - passed} 项")
    return 1


if __name__ == "__main__":
    sys.exit(main())
