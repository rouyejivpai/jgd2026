#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""10 §1.1 换皮验收：实机截图与设计图逐像素比对，输出差异图与差异比例。
用法（在 godot/ 目录）：
  python tools/ui_diff.py --design assets/ui/main_menu/design.png --actual ../docs/screenshots/ui_diff/main_menu_actual.png \
      --manifest assets/ui/main_menu/manifest.json --out ../docs/screenshots/ui_diff/main_menu_diff.png [--ignore log_hint 0,0,10,10 ...] [--no-motion]
指标（像素 = 任一通道差 > 阈值即"不同"）：
  strict      严格：任一通道差 > 0 的像素比例（全图）
  tolerant    排除 --ignore 区域（动态内容），通道差 > --tol（默认 2/255，编码取整）
  final       在 tolerant 基础上，文字区（manifest 中 text_style 的 rect 与按钮的 text_rect）内允许 --text-shift 像素（默认 1）
              以内的位移匹配——只吸收字形反走样 / 栅格化差异，面板、控件、贴图不享受该豁免
  通过条件：final ≤ --threshold（默认 2.0%）
--context-manifest：浮窗类界面的设计图含下层界面（如设置浮窗后面的主菜单），下层 manifest 的文字区同样按文字豁免（可多个）。
差异图：设计图压暗为底；红 = 不同，黄 = 文字反走样豁免，蓝 = 忽略区域。--ignore 可写元素 id（取 manifest rect）或 x,y,w,h。
--no-motion（P8，10 §1.5 约束 1）：要求实机截图是动效冻结的静止态——读截图旁的 <png>.meta.json（take_screenshots 写出），
  motion 为 true 或缺少该文件时报参数错误；报告记 "no_motion": true。
--report 输出 JSON。exit 0 = 通过，1 = 未通过，2 = 参数错误。"""
import argparse
import io
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")


def load_rgb(path):
    return np.asarray(Image.open(path).convert("RGB")).astype(np.int16)


def rects_from_manifest(manifest):
    """返回 (id → 全局 rect, 文字区列表)"""
    by_id, text = {}, []
    for e in manifest.get("elements", []):
        r = e.get("rect")
        if not r:
            continue
        by_id[e["id"]] = r
        if e.get("kind") == "text_style":
            text.append(r)
        elif e.get("kind") == "button" and e.get("text_rect"):
            t = e["text_rect"]
            text.append([r[0] + t[0], r[1] + t[1], t[2], t[3]])
    return by_id, text


def mask_of(shape, rects, grow=0):
    m = np.zeros(shape[:2], bool)
    h, w = shape[:2]
    for x, y, rw, rh in rects:
        x0, y0 = max(0, int(x) - grow), max(0, int(y) - grow)
        x1, y1 = min(w, int(x + rw) + grow), min(h, int(y + rh) + grow)
        if x1 > x0 and y1 > y0:
            m[y0:y1, x0:x1] = True
    return m


def shifted_min_diff(design, actual, shift):
    """每个像素：actual 与 design 在 ±shift 邻域内最接近的一个像素的最大通道差"""
    best = np.abs(design - actual).max(axis=2)
    h, w = best.shape
    pad = np.pad(design, ((shift, shift), (shift, shift), (0, 0)), mode="edge")
    for dy in range(-shift, shift + 1):
        for dx in range(-shift, shift + 1):
            if dx == 0 and dy == 0:
                continue
            d = pad[shift + dy:shift + dy + h, shift + dx:shift + dx + w]
            best = np.minimum(best, np.abs(d - actual).max(axis=2))
    return best


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--design", required=True)
    ap.add_argument("--actual", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--manifest")
    ap.add_argument("--context-manifest", nargs="*", default=[])
    ap.add_argument("--ignore", nargs="*", default=[])
    ap.add_argument("--tol", type=int, default=2)
    ap.add_argument("--text-shift", type=int, default=1)
    ap.add_argument("--threshold", type=float, default=2.0)
    ap.add_argument("--report")
    ap.add_argument("--no-motion", action="store_true")
    a = ap.parse_args()
    if a.no_motion:
        meta = Path(a.actual + ".meta.json")
        if not meta.exists():
            print(f"--no-motion：缺少 {meta.name}（请用 take_screenshots ... --no-motion 重新截图）")
            return 2
        if json.loads(meta.read_text(encoding="utf-8")).get("motion", True):
            print("--no-motion：该截图是在动效开启时拍的（meta motion=true），请加 --no-motion 重新截图")
            return 2
    design, actual = load_rgb(a.design), load_rgb(a.actual)
    if design.shape != actual.shape:
        print(f"尺寸不一致：设计 {design.shape[1]}×{design.shape[0]}，实机 {actual.shape[1]}×{actual.shape[0]}")
        return 2
    by_id, text_rects = ({}, [])
    if a.manifest:
        by_id, text_rects = rects_from_manifest(json.loads(Path(a.manifest).read_text(encoding="utf-8")))
    for cm in a.context_manifest:
        text_rects = text_rects + rects_from_manifest(json.loads(Path(cm).read_text(encoding="utf-8")))[1]
    ignore_rects = []
    for item in a.ignore:
        if item in by_id:
            ignore_rects.append(by_id[item])
        else:
            try:
                ignore_rects.append([float(v) for v in item.split(",")])
            except ValueError:
                print(f"--ignore 无法识别：{item}")
                return 2
    total = design.shape[0] * design.shape[1]
    raw = np.abs(design - actual).max(axis=2)
    ignored = mask_of(design.shape, ignore_rects)
    counted = ~ignored
    n_counted = int(counted.sum())
    strict = float((raw > 0).sum()) / total * 100.0
    diff_tol = (raw > a.tol) & counted
    tolerant = float(diff_tol.sum()) / max(n_counted, 1) * 100.0
    text_mask = mask_of(design.shape, text_rects, grow=a.text_shift) & counted
    shifted = shifted_min_diff(design, actual, a.text_shift) if a.text_shift > 0 else raw
    text_ok = diff_tol & text_mask & (shifted <= a.tol)
    final_diff = diff_tol & ~text_ok
    final = float(final_diff.sum()) / max(n_counted, 1) * 100.0
    max_non_text = int(raw[final_diff].max()) if final_diff.any() else 0
    # 差异图
    base = (design.mean(axis=2) * 0.35).astype(np.uint8)
    img = np.stack([base, base, base], axis=2)
    img[ignored] = (img[ignored] * 0.5 + np.array([0, 40, 120])).astype(np.uint8)
    img[text_ok] = (255, 220, 0)
    img[final_diff] = (255, 32, 32)
    Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(img).save(a.out)
    passed = final <= a.threshold
    report = {
        "design": a.design, "actual": a.actual, "diff_image": a.out, "size": [design.shape[1], design.shape[0]],
        "ignore": ignore_rects, "tol": a.tol, "text_shift": a.text_shift, "threshold_pct": a.threshold,
        "strict_pct": round(strict, 4), "tolerant_pct": round(tolerant, 4), "final_pct": round(final, 4),
        "max_channel_diff_failing": max_non_text, "no_motion": a.no_motion, "passed": passed,
    }
    if a.report:
        Path(a.report).write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"严格 {strict:.4f}%  ｜ 容差 {a.tol}/255 且排除忽略区 {tolerant:.4f}%  ｜ 再豁免文字反走样 {final:.4f}%"
          f"（阈值 {a.threshold}%，未豁免像素最大通道差 {max_non_text}）→ {'通过' if passed else '未通过'}")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
