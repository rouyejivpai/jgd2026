#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""P6 拼接：以「批准整图」为准，把资源方的无字切片与文字锚点拟合成 manifest（12 §3；用户 2026-10-05：与参考整图一致）。
用法（在 godot/ 目录）：python tools/ui_fit_reference.py assets/ui/<screen>/fit_spec.json
输入 fit_spec.json（路径相对 spec 所在目录）：
  reference       批准整图（原生尺寸，如 1672×941）；design_size 为运行设计坐标（1920×1080），两轴分别按比例换算
  slices          资源方 layout.json（切片文件、交付 placement 仅作搜索起点）与切片目录
  text_anchors    资源方 text_anchors.json（参考整图上量出的文字可见边界 ink）与其中的 ref 名
  elements[]      逐元素：
    {"id", "kind": "image"|"button", "slice": <切片 id>}                       切片 → 在参考图里做边缘多尺度匹配，得到等比缩放后的矩形
    button 另可带 "text_anchor"、"font"、"align"、"tint"（hover / pressed / disabled 的调色，切片只有一态时用）
    "slice_crop": [x,y,w,h]         只用切片的这一块（贴图像素），另存 derived/<切片>_crop.png（切片可见部分偏在大张透明图一角时用）
    "fit_visible": true             image + rect_ref：rect_ref 为整图里装饰的可见外框，切片不透明区等比缩放后居中放入（切片留白大时用）
    "scale_like": <前面某切片 id>   同形框体（如「任务」「机制说明」）取同一缩放，只搜位置
    "text_inset_like": <前面某按钮 id>  同类控件（如多个下拉）文字区左右边距、字体与该元素相同（不另设 text_anchor）
    "size_like": <前面某文字元素 id>  同类文字（如两个条件标题）取同一字号，只按本元素 ink 定位
    "center_on_slice": true          文字水平居中于框体不透明区（整图文字本身偏了时用；ref_ink 随之改为居中后的位置）
    "ink_from": {"reference": <整图>, "roi": [x,y,w,h], "text": "...", "relative_to": <切片 id>}
                                     没有资源方锚点的文字（其他状态整图里才出现的）：在该整图的 roi（整图像素）内按亮度自动取 ink 外框作锚点；
                                     relative_to：先在该整图里也拟合这张切片，按"文字相对框体"的位置搬到主整图的框体上
    "disabled_from": <整图>          切片只有一态、而另一张批准整图画出了禁用样子时：在那张整图的同一矩形里量出相对正常整图的
                                     亮度比与饱和度比、禁用文字色，生成派生贴图 derived/<切片>_disabled.png 作为 disabled 态
    {"id", "kind": "ninepatch", "slice", "rect_ref": [x,y,w,h]}       九宫格切片拉伸到整图里量出的矩形（如问题面板）
    {"id", "kind": "flatbox", "rect_ref", "style": {bg, border, border_width, radius}}   资源没有切片的简单底板 / 分隔线（StyleBoxFlat，取色于整图）
    {"id", "kind": "button", "rect_ref", "flat": {bg, border, border_width, radius}}      资源没有切片的平面按钮（整图里的描边按钮），四态由颜色派生
    {"id", "kind": "text_style", "text_anchor", "font", "align", "max_w"}     text_anchor 可写 "<ref>:<id>" 引用其他整图上的锚点（如 detail:detail-title）       文字 → 字号按 ink 高宽拟合（整数字号），
         label 矩形按字体度量反推，使 ink 落在参考位置；max_w（参考像素）为可用宽度，超出时由 UiKit 遮罩 + 滚动
    "color" 缺省时从参考 ink 区取亮部中位色
  reserved        原样写入（例如战场让出的上下带）
输出：同目录 manifest.json（apply_ui_manifest.py 的输入）与 FIT_REPORT.md（每个元素的拟合结果与分数）。
校准（PIL 与 Godot 的字体度量 / 栅格化略有差别）：python tools/ui_fit_reference.py <fit_spec.json> --calibrate <ui_geom_check 输出的 *_geom.json>
  按实机文字 ink 与参考 ink 的差，把每个文字元素的修正累加写回 fit_spec：
  "size_adjust"（ink 高差 ≥ 2 px 时字号 ∓1）、"nudge"（ink 中心差的反向，设计像素）；然后重新生成 manifest。反复"截图 → 比对 → 校准"直到通过。
匹配：切片与参考都取 Sobel 梯度幅值，带 alpha 掩码的归一化互相关（TM_CCORR_NORMED），缩放 0.75–1.25 步长 0.005，
      位置在交付 placement 周围 ±60 px 搜索。切片是重绘的无字稿（颜色与参考不同），所以按轮廓而不是按颜色对齐。"""
import io
import json
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageFont

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
GODOT = Path(__file__).resolve().parent.parent
FONT_FILES = {
    "NotoSerifSC": GODOT / "assets/fonts/NotoSerifSC-Regular.otf",
    "NotoSerifSC-Bold": GODOT / "assets/fonts/NotoSerifSC-Bold.otf",
    "Cinzel": GODOT / "assets/fonts/Cinzel-Regular.ttf",
}


def imread(path, flags):
    """cv2.imread 在 Windows 上不认非 ASCII 路径，改用 fromfile + imdecode"""
    return cv2.imdecode(np.fromfile(str(path), dtype=np.uint8), flags)


def edges(bgr):
    g = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY).astype(np.float32)
    return cv2.magnitude(cv2.Sobel(g, cv2.CV_32F, 1, 0, ksize=3), cv2.Sobel(g, cv2.CV_32F, 0, 1, ksize=3))


def fit_slice(ref_edges, slice_path, start_rect, scales=None):
    sl = imread(slice_path, cv2.IMREAD_UNCHANGED)
    a = sl[..., 3]
    ys, xs = np.nonzero(a > 8)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    crop = sl[y0:y1, x0:x1]
    al = crop[..., 3:4].astype(np.float32) / 255.0
    comp = (crop[..., :3].astype(np.float32) * al + 60.0 * (1.0 - al)).astype(np.uint8)
    te = edges(comp)
    mask = cv2.dilate((crop[..., 3] > 8).astype(np.uint8), np.ones((5, 5), np.uint8)).astype(np.float32)
    px, py, pw, ph = start_rect
    cx, cy = px + pw / 2.0, py + ph / 2.0
    best = None
    for s in (scales if scales is not None else np.arange(0.75, 1.25, 0.005)):
        w, h = int(round(te.shape[1] * s)), int(round(te.shape[0] * s))
        t = cv2.resize(te, (w, h))
        m = cv2.resize(mask, (w, h))
        rx0, ry0 = int(max(0, cx - w / 2 - 60)), int(max(0, cy - h / 2 - 60))
        rx1, ry1 = int(min(ref_edges.shape[1], cx + w / 2 + 60)), int(min(ref_edges.shape[0], cy + h / 2 + 60))
        roi = ref_edges[ry0:ry1, rx0:rx1]
        if roi.shape[0] < h or roi.shape[1] < w:
            continue
        r = np.nan_to_num(cv2.matchTemplate(roi, t, cv2.TM_CCORR_NORMED, mask=m), nan=-1.0, posinf=-1.0, neginf=-1.0)
        _, mx, _, loc = cv2.minMaxLoc(r)
        if best is None or mx > best[0]:
            best = (mx, float(s), rx0 + loc[0], ry0 + loc[1])
    score, s, X, Y = best
    # 切片整张（含透明留白）在参考图中的矩形；不透明区中心（文字居中于框体时用）
    return {"rect": [X - x0 * s, Y - y0 * s, sl.shape[1] * s, sl.shape[0] * s], "scale": s, "score": score,
            "opaque_center": [X + (x1 - x0) * s / 2.0, Y + (y1 - y0) * s / 2.0]}


def _lum(a):
    return a[..., 0] * 0.299 + a[..., 1] * 0.587 + a[..., 2] * 0.114


def derive_disabled(slice_path, rect_d, text_rect_d, ref_normal_d, ref_disabled_d, out_path):
    """在两张整图（已缩放到设计尺寸）的同一矩形里比较：亮度比、饱和度比（切片不透明区、扣掉文字区），禁用文字色（文字区亮部）。
    生成派生贴图：保亮度去饱和到该比例，再乘亮度比。返回 (亮度比, 饱和度比, 文字色)"""
    x, y, w, h = [int(round(v)) for v in rect_d]
    sl = np.asarray(Image.open(slice_path).convert("RGBA")).astype(np.float32)
    m = np.asarray(Image.open(slice_path).convert("RGBA").resize((w, h)))[..., 3] > 250
    if text_rect_d:
        tx, ty, tw, th = [int(round(v)) for v in text_rect_d]
        m[max(0, ty):ty + th, max(0, tx):tx + tw] = False
    a1, a2 = ref_normal_d[y:y + h, x:x + w].astype(np.float32), ref_disabled_d[y:y + h, x:x + w].astype(np.float32)
    sat = lambda a: a.max(axis=-1) - a.min(axis=-1)      # noqa: E731
    lum_k = float(_lum(a2)[m].mean() / max(_lum(a1)[m].mean(), 1e-3))
    sat_k = float(sat(a2)[m].mean() / max(sat(a1)[m].mean(), 1e-3))
    color = "#FFFFFF"
    if text_rect_d:
        t = ref_disabled_d[y + ty:y + ty + th, x + tx:x + tx + tw].reshape(-1, 3).astype(np.float32)
        L = _lum(t)
        color = "#%02X%02X%02X" % tuple(int(round(v)) for v in np.median(t[L >= np.percentile(L, 90)], axis=0))
    rgb = sl[..., :3]
    lum = _lum(rgb)[..., None]
    out = np.clip((lum + (rgb - lum) * sat_k) * lum_k, 0, 255)
    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.concatenate([out, sl[..., 3:4]], axis=-1).astype(np.uint8), "RGBA").save(out_path)
    return lum_k, sat_k, color


def detect_ink(rgb, roi):
    """roi 内亮字的外框（整图像素）：按最亮通道（彩色字如红字亮度低、但最亮通道高）取阈值，
    阈值在 70 分位与 99.5 分位之间偏上处；去掉面积过小的孤立点"""
    x, y, w, h = [int(v) for v in roi]
    L = rgb[y:y + h, x:x + w].astype(np.float32).max(axis=-1)
    lo, hi = np.percentile(L, 70), np.percentile(L, 99.5)
    m = (L >= max(110.0, lo + 0.55 * (hi - lo))).astype(np.uint8)
    n, lab, stats, _ = cv2.connectedComponentsWithStats(m, 8)
    keep = np.zeros_like(m)
    for i in range(1, n):
        if stats[i, cv2.CC_STAT_AREA] >= 3:
            keep[lab == i] = 1
    ys, xs = np.nonzero(keep)
    return [x + int(xs.min()), y + int(ys.min()), int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1)]


def ink_color(ref_rgb, ink):
    x, y, w, h = ink
    reg = ref_rgb[y:y + h, x:x + w].reshape(-1, 3).astype(np.float32)
    lum = reg @ np.array([0.299, 0.587, 0.114], np.float32)
    sel = reg[lum >= np.percentile(lum, 85)]
    c = np.median(sel, axis=0)
    return "#%02X%02X%02X" % tuple(int(round(v)) for v in c)


def fit_text(text, ink_d, family, align, max_w_d, size_adjust=0, nudge=(0, 0), size_fixed=0):
    """ink_d：设计坐标下的参考 ink [x, y, w, h]。返回 (字号, label 矩形, 实测 ink 宽高)；size_adjust / nudge 为实机校准量"""
    best = None
    for size in range(6, 96):
        f = ImageFont.truetype(str(FONT_FILES[family]), size)
        l, t, r, b = f.getbbox(text, anchor="ls")
        err_ = abs((r - l) - ink_d[2]) + 1.5 * abs((b - t) - ink_d[3])
        if best is None or err_ < best[0]:
            best = (err_, size, f, (l, t, r, b))
    _, size, f, (l, t, r, b) = best
    if size_fixed:
        size = size_fixed
        f = ImageFont.truetype(str(FONT_FILES[family]), size)
        l, t, r, b = f.getbbox(text, anchor="ls")
    if size_adjust:
        size += size_adjust
        f = ImageFont.truetype(str(FONT_FILES[family]), size)
        l, t, r, b = f.getbbox(text, anchor="ls")
    asc, desc = f.getmetrics()
    line_h = asc + desc
    baseline = ink_d[1] - t                    # ink 顶 = 基线 + t（t 为负）
    y = baseline - asc
    adv = f.getlength(text)
    w = max(max_w_d, adv)
    if align == "left":
        x = ink_d[0] - l
    elif align == "right":
        x = ink_d[0] + ink_d[2] - r - (w - adv)
    else:
        cx = ink_d[0] - l + adv / 2.0
        x = cx - w / 2.0
    return size, [x + nudge[0], y + nudge[1], w, line_h], [r - l, b - t]


FRAME_CALIBRATE_MAX = 3   # 校准只修正小偏移（PIL / Godot 栅格差）；更大的偏移不自动搬


def calibrate(spec_path, geom_path):
    """按实机 ink 校准：字号在 当前 ±1 中选「max(|Δw|/3, |Δh|/1.5)」最小者（实机 ink 按字号线性外推）；位置按 ink 中心（左对齐按左缘）反向修正"""
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    man = {e["id"]: e for e in json.loads((spec_path.parent / "manifest.json").read_text(encoding="utf-8"))["elements"]}
    rows = {r["id"]: r for r in json.loads(Path(geom_path).read_text(encoding="utf-8")) if r.get("what") == "文字" and "d" in r}
    n = 0
    frames = {r["id"]: r for r in json.loads(Path(geom_path).read_text(encoding="utf-8")) if r.get("what") == "框体"}
    ref_size = imread((spec_path.parent / spec["reference"]).resolve(), cv2.IMREAD_COLOR).shape[:2]
    fsx, fsy = spec.get("design_size", [1920, 1080])[0] / ref_size[1], spec.get("design_size", [1920, 1080])[1] / ref_size[0]
    for e in spec["elements"]:          # 量取矩形的框体（rect_ref）按实机偏移修正（框体用模板匹配的不需要）
        f = frames.get(e["id"])
        if f is None or "rect_ref" not in e or (f["dx"] == 0 and f["dy"] == 0):
            continue
        if max(abs(f["dx"]), abs(f["dy"])) > FRAME_CALIBRATE_MAX:   # 偏移大 = 代用切片与整图画法不同（边缘匹配不可信），不搬框体
            print(f"  跳过框体 {e['id']}：偏移 {f['dx']}, {f['dy']} 超过 ±{FRAME_CALIBRATE_MAX}（多为代用切片），请目视确认")
            continue
        rr = e["rect_ref"]
        e["rect_ref"] = [round(rr[0] + f["dx"] / fsx, 1), round(rr[1] + f["dy"] / fsy, 1), rr[2], rr[3]]
        n += 1
    for e in spec["elements"]:
        r = rows.get(e["id"])
        if r is None or e["id"] not in man:
            continue
        ra, rr = r["act_ink"], r["ref_ink"]
        size = int(man[e["id"]]["font"]["size"])
        best = None
        for cand in (size - 1, size, size + 1):
            k = cand / size
            cost = max(abs(ra[2] * k - rr[2]) / 3.0, abs(ra[3] * k - rr[3]) / 1.5)
            if best is None or cost < best[0] - 1e-6:
                best = (cost, cand)
        changed = False
        if best[1] != size:
            e["size_adjust"] = int(e.get("size_adjust", 0)) + (best[1] - size)
            changed = True
        nx, ny = e.get("nudge", [0, 0])
        if e.get("align") == "left":
            ddx = ra[0] - rr[0]
        else:
            ddx = round((ra[0] + ra[2] / 2) - (rr[0] + rr[2] / 2))
        ddy = round((ra[1] + ra[3] / 2) - (rr[1] + rr[3] / 2))
        if best[1] == size:                          # 字号变了就先不动位置，下一轮再量
            if ddx:
                nx -= ddx
                changed = True
            if ddy:
                ny -= ddy
                changed = True
        e["nudge"] = [nx, ny]
        n += changed
    spec_path.write_text(json.dumps(spec, ensure_ascii=False, indent=1) + "\n", encoding="utf-8", newline="\n")
    print(f"校准：{n} 个文字元素有修正，已写回 {spec_path.name}")


def main(argv):
    spec_path = Path(argv[1]).resolve()
    if len(argv) >= 4 and argv[2] == "--calibrate":
        calibrate(spec_path, argv[3])
    base = spec_path.parent
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    ref_path = (base / spec["reference"]).resolve()
    ref_bgr = imread(ref_path, cv2.IMREAD_COLOR)
    ref_rgb = cv2.cvtColor(ref_bgr, cv2.COLOR_BGR2RGB)
    ref_e = edges(ref_bgr)
    rh, rw = ref_bgr.shape[:2]
    dw, dh = spec.get("design_size", [1920, 1080])
    sx, sy = dw / rw, dh / rh
    to_d = lambda r: [r[0] * sx, r[1] * sy, r[2] * sx, r[3] * sy]     # noqa: E731
    lay = json.loads((base / spec["slices"]["layout"]).read_text(encoding="utf-8"))["assets"]
    sdir = base / spec["slices"]["dir"]
    ta = json.loads((base / spec["text_anchors"]["file"]).read_text(encoding="utf-8"))
    anchors = {a["id"]: a for a in ta["anchors"] if a["ref"] == spec["text_anchors"]["ref"]}
    other_rgb = {}
    for a in ta["anchors"]:          # 其他整图上的锚点：键为 "<ref>:<id>"（如 detail:detail-title），取色用该整图
        if a["ref"] != spec["text_anchors"]["ref"]:
            if a["ref"] not in other_rgb:
                other_rgb[a["ref"]] = cv2.cvtColor(imread(Path(ta["reference"][a["ref"]]), cv2.IMREAD_COLOR), cv2.COLOR_BGR2RGB)
            anchors[a["ref"] + ":" + a["id"]] = dict(a, _rgb=other_rgb[a["ref"]])
    out = {"schema_version": 1, "screen": spec["screen"], "design_size": [dw, dh],
           "_comment": f"由 tools/ui_fit_reference.py 从 {spec_path.name} 生成：以批准整图 {spec['reference']} 为准拟合（切片按轮廓、文字按 ink），勿手改。",
           "elements": []}
    if "reserved" in spec:
        out["reserved"] = spec["reserved"]
    report = [f"# {spec['screen']} 拟合报告", "", f"参考：`{spec['reference']}`（{rw}×{rh}）→ 设计 {dw}×{dh}（x × {sx:.5f}，y × {sy:.5f}）", "",
              "| 元素 | 类型 | 来源 | 结果（设计坐标） | 分数 / 字号 |", "|---|---|---|---|---|"]
    fitted = {}
    rint = lambda r: [int(round(v)) for v in r]     # noqa: E731
    ref_d = cv2.resize(ref_rgb, (dw, dh), interpolation=cv2.INTER_LANCZOS4)
    text_sizes = {}
    alt_refs = {}
    for e in spec["elements"]:
        eid, kind = e["id"], e["kind"]
        item = {"id": eid, "kind": kind}
        if "slice" in e:
            a = lay[e["slice"]]
            src = sdir / Path(a["file"]).name
            fpath = "../" + src.relative_to(base.parent).as_posix()
            if e.get("slice_crop"):      # 切片画在大张透明图的一角（留白不对称、九宫格拉不开）：裁出可见部分另存 derived/<切片>_crop.png 使用
                cx, cy, cw, ch = e["slice_crop"]
                (base / "derived").mkdir(exist_ok=True)
                src_crop = base / "derived" / f"{e['slice']}_crop.png"
                Image.open(src).crop((cx, cy, cx + cw, cy + ch)).save(src_crop)
                src, fpath = src_crop, "derived/" + src_crop.name
            start = a.get("placement") or a["source_rect"]
            scales = [fitted[e["scale_like"]]["scale"]] if e.get("scale_like") in fitted else None     # 同形框体取同一缩放
            if "rect_ref" in e:          # 九宫格等被拉伸使用的切片：矩形取自整图（可见边框），不做模板匹配；
                # 切片四周的透明留白（贴图像素，九宫格不缩放）向外补上，使可见边框落在 rect_ref 上
                rgba = np.asarray(Image.open(src).convert("RGBA")).astype(np.float32)
                al = rgba[..., 3]
                gold = ((rgba[..., 0] - rgba[..., 2]) > 45) & (rgba[..., 0] > 120) & (al > 128)    # 可见边框 = 金色线
                gx = np.nonzero(gold.sum(axis=0) > al.shape[0] * 0.3)[0]
                gy = np.nonzero(gold.sum(axis=1) > al.shape[1] * 0.3)[0]
                if e.get("no_pad"):
                    pl = pt = pr = pb = 0
                elif len(gx) >= 2 and len(gy) >= 2 and gold.mean() < 0.3:       # 金色是细边框（不是整块金色，如滚动条滑块）
                    pl, pr, pt, pb = gx.min(), al.shape[1] - 1 - gx.max(), gy.min(), al.shape[0] - 1 - gy.max()
                else:
                    ys_, xs_ = np.nonzero(al > 128)
                    pl, pt, pr, pb = xs_.min(), ys_.min(), al.shape[1] - 1 - xs_.max(), al.shape[0] - 1 - ys_.max()
                rr = e["rect_ref"]
                # 设计坐标下留白仍是贴图像素，换回整图像素：除以缩放
                rect_ref = [rr[0] - pl / sx, rr[1] - pt / sy, rr[2] + (pl + pr) / sx, rr[3] + (pt + pb) / sy]
                if e.get("fit_visible"):     # 整张缩放的装饰图：不透明区等比缩放、居中放进 rect_ref（切片四周留白随之缩放）
                    ys_, xs_ = np.nonzero(al > 40)
                    x0, y0, bw, bh = xs_.min(), ys_.min(), xs_.max() - xs_.min() + 1, ys_.max() - ys_.min() + 1
                    k = min(rr[2] / bw, rr[3] / bh)
                    vx, vy = rr[0] + (rr[2] - bw * k) / 2, rr[1] + (rr[3] - bh * k) / 2
                    rect_ref = [vx - x0 * k, vy - y0 * k, al.shape[1] * k, al.shape[0] * k]
                f = {"rect": rect_ref, "scale": 1.0, "score": 0.0, "opaque_center": [rr[0] + rr[2] / 2, rr[1] + rr[3] / 2]}
            else:
                f = fitted.get(e["slice"]) or fit_slice(ref_e, src, start, scales)
            fitted[e["slice"]] = f
            rect = rint(to_d(f["rect"]))
            item["rect"] = rect
            if kind == "image":
                item["file"] = fpath
            elif kind == "ninepatch":
                item["file"] = fpath
                item["ninepatch"] = e.get("ninepatch", lay[e["slice"]].get("nine_patch_margins", [0, 0, 0, 0]))
            elif kind == "button":
                tint = e.get("tint", {})
                item["states"] = {st: ({"file": fpath, "modulate": tint[st]} if st in tint else fpath) for st in ("normal", "hover", "pressed", "disabled")}
                if "ninepatch" in e:         # 拉伸到 rect_ref 的按钮：九宫格边距（贴图像素），端头装饰不随宽度变形
                    item["ninepatch"] = e["ninepatch"]
            report.append(f"| {eid} | {kind} | 切片 {e['slice']} | {rect} | 轮廓 NCC {f['score']:.3f}，缩放 {f['scale']:.3f} |")
        if "ink_from" in e:
            src = e["ink_from"]["reference"]
            if src not in alt_refs:
                alt_refs[src] = cv2.resize(cv2.cvtColor(imread(base / src, cv2.IMREAD_COLOR), cv2.COLOR_BGR2RGB), (dw, dh), interpolation=cv2.INTER_LANCZOS4)
            src_bgr = imread(base / src, cv2.IMREAD_COLOR)
            src_rgb = cv2.cvtColor(src_bgr, cv2.COLOR_BGR2RGB)
            ink = detect_ink(src_rgb, e["ink_from"]["roi"])
            ink_src = list(ink)                     # 取色用原位置
            rel = e["ink_from"].get("relative_to")
            if rel:      # 其他状态整图里同一框体位置略有不同：量出文字相对框体的位置，再搬到主整图的框体上
                ra = lay[rel]
                f_alt = fit_slice(edges(src_bgr), sdir / Path(ra["file"]).name, fitted[rel]["rect"])
                dx = fitted[rel]["rect"][0] - f_alt["rect"][0]
                dy = fitted[rel]["rect"][1] - f_alt["rect"][1]
                ink = [ink[0] + dx, ink[1] + dy, ink[2], ink[3]]
            anchors[e["id"] + "@ink"] = {"ink": ink, "text": e["ink_from"]["text"], "_rgb": src_rgb, "_ink_src": ink_src}
            e = dict(e, text_anchor=e["id"] + "@ink")
        if kind == "button" and "flat" in e:     # 无切片的平面按钮：整图量取矩形与颜色；hover 提亮、pressed 压暗、disabled 去饱和
            item["rect"] = rint(to_d(e["rect_ref"]))
            fl = dict(e["flat"])
            for k in ("border_width", "radius"):
                if k in fl:
                    fl[k] = round(fl[k] * sx, 1)
            def shade(hexc, k, sat=1.0):
                if not hexc:
                    return hexc
                c = np.array([int(hexc[i:i + 2], 16) for i in (1, 3, 5)], np.float32)
                lum = c @ np.array([0.299, 0.587, 0.114], np.float32)
                c = np.clip((lum + (c - lum) * sat) * k, 0, 255)
                return "#%02X%02X%02X" % tuple(int(round(v)) for v in c) + hexc[7:9]     # 保留透明度
            item["flat_states"] = {
                "normal": fl,
                "hover": dict(fl, bg=shade(fl["bg"], 1.18), border=shade(fl.get("border") or fl["bg"], 1.15)),
                "pressed": dict(fl, bg=shade(fl["bg"], 0.8)),
                "disabled": dict(fl, bg=shade(fl["bg"], 0.85, 0.15), border=shade(fl.get("border") or fl["bg"], 0.85, 0.15)),
            }
            report.append(f"| {eid} | 平面按钮 | 整图量取 | {item['rect']} | {fl} |")
        if kind == "flatbox":       # 无切片的简单底板 / 分隔线：矩形与样式（颜色、边框、圆角，整图像素）取自整图
            item["rect"] = rint(to_d(e["rect_ref"]))
            st = dict(e.get("style", {}))
            for k in ("border_width", "radius"):
                if k in st:
                    st[k] = round(st[k] * sx, 1)
            item["style"] = st
            report.append(f"| {eid} | flatbox | 整图量取 | {item['rect']} | {st} |")
        if "text_anchor" in e:
            an = anchors[e["text_anchor"]]
            ink_d = to_d(an["ink"])
            if e.get("center_on_slice") and "slice" in e:          # 整图文字略偏时，水平居中于框体（用户 2026-10-06：右上角圆按钮）
                ink_d[0] = fitted[e["slice"]]["opaque_center"][0] * sx - ink_d[2] / 2.0
            max_w_d = float(e.get("max_w", an["ink"][2])) * sx
            fixed = int(text_sizes.get(e["size_like"], 0)) if e.get("size_like") else 0       # 同类文字取同一字号
            size, trect, ink_wh = fit_text(an["text"], ink_d, e["font"], e.get("align", "center"), max_w_d,
                                           int(e.get("size_adjust", 0)), tuple(e.get("nudge", (0, 0))), fixed)
            text_sizes[eid] = size
            color = e.get("color") or ink_color(an.get("_rgb", ref_rgb), an.get("_ink_src", an["ink"]))
            font = {"family": e["font"], "size": size, "color": color}
            if kind == "text_style":
                item["rect"] = rint(trect)
                item["text_rect"] = [0, 0, item["rect"][2], item["rect"][3]]
            else:
                r = item["rect"]
                item["text_rect"] = rint([trect[0] - r[0], trect[1] - r[1], trect[2], trect[3]])
            item["font"] = font
            item["align"] = e.get("align", "center")
            item.setdefault("data", {})["ref_ink"] = [round(v, 1) for v in ink_d]       # 参考 ink（设计坐标），几何验收用
            item["data"]["ref_text"] = an["text"]
            if e.get("overflow"):
                item["overflow"] = e["overflow"]
            report.append(f"| {eid} 文字 | {kind} | 锚点 {e['text_anchor'] if '@ink' not in e['text_anchor'] else '整图 ' + e['ink_from']['reference'] + ' 自动取 ink'}「{an['text']}」 | ink {rint(ink_d)} → label {rint(trect)} | {e['font']} {size}px，实测 ink {ink_wh[0]}×{ink_wh[1]}，色 {color} |")
        if e.get("text_inset_like"):          # 同类控件（如多个下拉）：文字区与参照元素的左右边距、上边距、行高相同
            src = next(x for x in out["elements"] if x["id"] == e["text_inset_like"])
            sr, st = src["rect"], src["text_rect"]
            right = sr[2] - st[0] - st[2]
            item["text_rect"] = [st[0], st[1] + (item["rect"][3] - sr[3]) // 2, max(item["rect"][2] - st[0] - right, 1), st[3]]
            item["font"] = dict(src["font"])
            item["align"] = src.get("align", "left")
        if e.get("disabled_file") and kind == "button":       # 直接用已派生的禁用贴图（如其他界面同一切片的禁用态）
            item["states"]["disabled"] = e["disabled_file"]
        if e.get("disabled_from") and kind == "button":
            src = e["disabled_from"]
            if src not in alt_refs:
                alt_refs[src] = cv2.resize(cv2.cvtColor(imread(base / src, cv2.IMREAD_COLOR), cv2.COLOR_BGR2RGB), (dw, dh), interpolation=cv2.INTER_LANCZOS4)
            a = lay[e["slice"]]
            tr = item.get("text_rect")
            derived = base / "derived" / f"{e['slice']}_disabled.png"
            lum_k, sat_k, dcol = derive_disabled(sdir / Path(a["file"]).name, item["rect"], tr, ref_d, alt_refs[src], derived)
            item["states"]["disabled"] = "derived/" + derived.name
            if "font" in item:
                item["font"]["disabled_color"] = dcol
            report.append(f"| {eid} 禁用态 | button | 整图 {src} | 派生 derived/{derived.name} | 亮度 × {lum_k:.3f}，饱和度 × {sat_k:.3f}，禁用文字色 {dcol} |")
        if "key" in e:
            item["key"] = e["key"]
        if "data" in e:
            item.setdefault("data", {}).update(e["data"])
        out["elements"].append(item)
    (base / "manifest.json").write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    (base / "FIT_REPORT.md").write_text("\n".join(report) + "\n", encoding="utf-8", newline="\n")
    print(f"{spec['screen']}：{len(out['elements'])} 个元素 → manifest.json、FIT_REPORT.md")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
