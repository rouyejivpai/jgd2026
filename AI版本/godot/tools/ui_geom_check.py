#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""P6 拼接验收（几何）：实机截图与批准整图逐元素比对位置与大小。
批准整图是 AI 原生绘制，切片是重绘的无字稿、文字字形也不是游戏字体，逐像素 diff 不能衡量"拼得对不对"；
本工具改为几何比对（与资源方 P3_PIXEL_ALIGNMENT_VALIDATION 的口径一致）：
  框体（image / button / 卡片）：取 Sobel 边缘图，以切片自身的不透明区为掩码（背景不参与），实机与参考（缩放到设计尺寸）做 ±8 px 平移搜索，
        报告最佳偏移 dx, dy 与边缘相关系数；|dx|, |dy| ≤ --tol（默认 1 px）为通过
  文字（text_style 与按钮文字）：参考 ink = 布局 data.ref_ink（资源方在批准整图上量出的字形可见边界，ui_fit_reference.py 写入）；
        实机 ink = 实机截图与 --notext 截图（take_screenshots --text-layer，隐藏全部文字）之差在文字区内的外框。
        位置（左对齐比左缘，其余比 ink 中心；上下比中心）差 ≤ --tol 为通过；宽差 > 3 px 或高差 > 1.5 px 另标 ⚠（批准整图的字形是 AI 绘制，
        与游戏字体比例不同，Godot 字号又只能取整数，外框宽高无法同时逐像素一致，只报告不判失败）；文字内容与参考不同的元素用 --skip-text 跳过
用法（在 godot/ 目录）：
  python tools/ui_geom_check.py --reference assets/ui/hud/design_low_noise.png --actual <截图> --screen battle_hud
      --notext <隐藏文字的截图> [--skip id ...] [--skip-text id ...]
      [--out <目录>]   输出 <screen>_geom.md / .json 与逐元素并排图 <screen>_geom_sheet.png（上 = 参考，下 = 实机，青线 = 布局矩形）
exit 0 = 全部通过，1 = 有未通过项。"""
import argparse
import io
import json
import sys
from pathlib import Path

import cv2
import numpy as np

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
GODOT = Path(__file__).resolve().parent.parent


def imread(path):
    return cv2.imdecode(np.fromfile(str(path), dtype=np.uint8), cv2.IMREAD_COLOR)


def edges(bgr):
    g = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY).astype(np.float32)
    return cv2.magnitude(cv2.Sobel(g, cv2.CV_32F, 1, 0, ksize=3), cv2.Sobel(g, cv2.CV_32F, 0, 1, ksize=3))


def slice_mask(e, w, h):
    """元素切片的不透明区（缩放到元素矩形）；只在框体自身像素上比边缘，背景不参与"""
    f = e.get("file") or (e.get("states") or {}).get("normal")
    if not f:
        return None
    img = cv2.imdecode(np.fromfile(str(GODOT / f.replace("res://", "")), dtype=np.uint8), cv2.IMREAD_UNCHANGED)
    if img is None or img.shape[2] < 4:
        return None
    m = cv2.resize((img[..., 3] > 128).astype(np.uint8), (w, h), interpolation=cv2.INTER_NEAREST)
    return cv2.dilate(m, np.ones((3, 3), np.uint8)).astype(np.float32)


def best_shift(ea, er, rect, search=8, mask=None):
    x, y, w, h = [int(round(v)) for v in rect]
    H, W = er.shape
    x0, y0, x1, y1 = max(0, x), max(0, y), min(W, x + w), min(H, y + h)
    tmpl = ea[y0:y1, x0:x1]
    if mask is not None:
        mask = mask[y0 - y:y1 - y, x0 - x:x1 - x]
    sx0, sy0 = max(0, x0 - search), max(0, y0 - search)
    roi = er[sy0:min(H, y1 + search), sx0:min(W, x1 + search)]
    if tmpl.size == 0 or roi.shape[0] < tmpl.shape[0] or roi.shape[1] < tmpl.shape[1]:
        return None
    r = cv2.matchTemplate(roi, tmpl, cv2.TM_CCORR_NORMED, mask=mask) if mask is not None else cv2.matchTemplate(roi, tmpl, cv2.TM_CCORR_NORMED)
    r = np.nan_to_num(r, nan=-1.0, posinf=-1.0, neginf=-1.0)
    _, mx, _, loc = cv2.minMaxLoc(r)
    # 实机元素在参考里的位置 - 实机位置 = 参考相对实机的偏移；报告"实机应移动多少才对齐参考"
    return {"dx": sx0 + loc[0] - x0, "dy": sy0 + loc[1] - y0, "ncc": round(float(mx), 3)}


def ink_box(bgr, rect, thr):
    x, y, w, h = [int(round(v)) for v in rect]
    reg = cv2.cvtColor(bgr[max(0, y):y + h, max(0, x):x + w], cv2.COLOR_BGR2GRAY)
    ys, xs = np.nonzero(reg >= thr)
    if len(xs) < 4:
        return None
    return [int(xs.min() + x), int(ys.min() + y), int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1)]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--reference", required=True)
    ap.add_argument("--actual", required=True)
    ap.add_argument("--screen", required=True)
    ap.add_argument("--skip", nargs="*", default=[])
    ap.add_argument("--skip-text", nargs="*", default=[])
    ap.add_argument("--skip-prefix", nargs="*", default=[], help="跳过整组元素（本状态下不显示的弹窗 / 面板，如 obj_ problems_）")
    ap.add_argument("--tol", type=float, default=1.0)
    ap.add_argument("--notext")
    ap.add_argument("--out", default="../docs/screenshots/ui_geom")
    a = ap.parse_args()
    lay = json.loads((GODOT / "data" / "ui_layout" / f"{a.screen}.json").read_text(encoding="utf-8"))
    dw, dh = lay["design_size"]
    act = imread(a.actual)
    ref = cv2.resize(imread(a.reference), (dw, dh), interpolation=cv2.INTER_LANCZOS4)
    if act.shape[:2] != (dh, dw):
        print(f"实机截图尺寸 {act.shape[1]}×{act.shape[0]} 与设计尺寸 {dw}×{dh} 不同")
        return 2
    notext = imread(a.notext) if a.notext else None
    ea, er = edges(notext if notext is not None else act), edges(ref)     # 框体用无文字截图比，不受文字改动影响
    rows, ok_all, sheet = [], True, []
    for e in lay["elements"]:
        eid = e["id"]
        if eid in a.skip or any(eid.startswith(pf) for pf in a.skip_prefix):
            continue
        r = e["rect"]
        if e["kind"] in ("image", "button", "ninepatch", "icon"):
            s = best_shift(ea, er, r, mask=slice_mask(e, int(round(r[2])), int(round(r[3]))))
            if s is not None:
                ok = abs(s["dx"]) <= a.tol and abs(s["dy"]) <= a.tol
                ok_all &= ok
                rows.append({"id": eid, "what": "框体", "rect": r, **s, "pass": ok})
        ref_ink = (e.get("data", {}) or {}).get("ref_ink")
        if ref_ink and notext is not None and eid not in a.skip_text:
            t = e.get("text_rect", [0, 0, r[2], r[3]])
            tr = [r[0] + t[0], r[1] + t[1], t[2], t[3]] if e["kind"] != "text_style" else r
            x, y, w, h = [int(round(v)) for v in [tr[0] - 2, tr[1] - 2, tr[2] + 4, tr[3] + 4]]
            diff = np.abs(act[max(0, y):y + h, max(0, x):x + w].astype(np.int16) - notext[max(0, y):y + h, max(0, x):x + w].astype(np.int16)).max(axis=2)
            ys, xs = np.nonzero(diff > 64)
            if len(xs) >= 4:
                ib_a = [int(xs.min() + max(0, x)), int(ys.min() + max(0, y)), int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1)]
                ib_r = [round(v) for v in ref_ink]
                d = [ib_a[i] - ib_r[i] for i in range(4)]
                # 位置：左对齐比左缘，其余比中心；上下比中心（字形不同，外框宽高不可能逐像素一致）
                px = d[0] if e.get("align") == "left" else (ib_a[0] + ib_a[2] / 2) - (ib_r[0] + ib_r[2] / 2)
                py = (ib_a[1] + ib_a[3] / 2) - (ib_r[1] + ib_r[3] / 2)
                ok = abs(px) <= a.tol and abs(py) <= a.tol
                shape_warn = abs(d[2]) > 3 or abs(d[3]) > 1.5
                ok_all &= ok
                rows.append({"id": eid, "what": "文字", "rect": [int(v) for v in tr], "ref_ink": ib_r, "act_ink": ib_a, "d": d,
                             "pos": [round(px, 1), round(py, 1)], "shape_warn": shape_warn, "pass": ok})
            else:
                ok_all = False
                rows.append({"id": eid, "what": "文字", "rect": [int(v) for v in tr], "note": "实机未检出文字", "pass": False})
        # 并排图
        x, y, w, h = [int(round(v)) for v in r]
        x0, y0 = max(0, x - 10), max(0, y - 10)
        x1, y1 = min(dw, x + w + 10), min(dh, y + h + 10)
        top, bot = ref[y0:y1, x0:x1].copy(), act[y0:y1, x0:x1].copy()
        for img in (top, bot):
            cv2.rectangle(img, (x - x0, y - y0), (x - x0 + w - 1, y - y0 + h - 1), (255, 255, 0), 1)
        sheet.append((eid, np.vstack([top, np.full((4, top.shape[1], 3), (255, 0, 255), np.uint8), bot])))
    out = (GODOT / a.out).resolve() if not Path(a.out).is_absolute() else Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    # 并排图拼成一张（按行排）
    maxw = 1900
    lines, line, lw = [], [], 0
    for eid, im in sheet:
        im = im[:, :maxw]                 # 超宽元素（全屏遮罩等）裁到图宽
        if lw + im.shape[1] > maxw and line:
            lines.append(line); line, lw = [], 0
        line.append(im); lw += im.shape[1] + 6
    if line:
        lines.append(line)
    rows_img = []
    for ln in lines:
        hmax = max(im.shape[0] for im in ln)
        row = np.full((hmax, maxw, 3), 40, np.uint8)
        cx = 0
        for im in ln:
            row[:im.shape[0], cx:cx + im.shape[1]] = im
            cx += im.shape[1] + 6
        rows_img.append(row)
        rows_img.append(np.full((6, maxw, 3), 40, np.uint8))
    cv2.imencode(".png", np.vstack(rows_img))[1].tofile(str(out / f"{a.screen}_geom_sheet.png"))
    md = [f"# {a.screen} 几何比对", "", f"参考 `{a.reference}`（缩放到 {dw}×{dh}）· 实机 `{Path(a.actual).name}`", "",
          "| 元素 | 项 | 布局矩形 | 结果 | 通过 |", "|---|---|---|---|---|"]
    for r in rows:
        if r["what"] == "框体":
            res = f"偏移 dx {r['dx']:+d}，dy {r['dy']:+d}（边缘相关 {r['ncc']}）"
        elif "d" in r:
            res = (f"ink 参考 {r['ref_ink']} / 实机 {r['act_ink']}：位置差 {r['pos'][0]:+.1f}, {r['pos'][1]:+.1f}；"
                   f"宽差 {r['d'][2]:+d} 高差 {r['d'][3]:+d}" + ("（⚠ 字形比例差，超出 ±3 / ±1.5）" if r["shape_warn"] else ""))
        else:
            res = r["note"]
        md.append(f"| {r['id']} | {r['what']} | {r['rect']} | {res} | {'✓' if r['pass'] else '✗'} |")
    n_fail = sum(1 for r in rows if not r["pass"])
    md += ["", f"共 {len(rows)} 项，未通过 {n_fail} 项。"]
    (out / f"{a.screen}_geom.md").write_text("\n".join(md) + "\n", encoding="utf-8", newline="\n")
    (out / f"{a.screen}_geom.json").write_text(json.dumps(rows, ensure_ascii=False, indent=1) + "\n", encoding="utf-8", newline="\n")
    print("\n".join(md[-(len(rows) + 3):]))
    return 0 if ok_all else 1


if __name__ == "__main__":
    sys.exit(main())
