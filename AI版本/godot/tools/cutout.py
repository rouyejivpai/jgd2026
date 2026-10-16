#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
把 tools/_raw/<kind>/<id>.png 规格化为游戏资源，输出到 art_manifest.json 的 output 目录。
  units / props : --native-alpha 保留原生透明 → 裁边 → 等比缩放到 target-24 → 居中到 target×target，脚底对齐底部 24px
  illustrations : --native-alpha 保留原生透明 → 裁边 → 等比缩放到 768×1152 画布，脚底贴底（正常头身立绘，对话与剧情用）
  portraits     : 中心正方形裁切 → 缩放到 target；带 source 的条目改为从已处理的立绘裁头部（先跑 --group illustrations）
  backgrounds   : 缩放/裁切到 1536×1024
  ui            : 透明控件保留原生 alpha 裁边；不透明大图缩放到 1920×1080（key_art/chapter_map）

用法（在 godot/ 目录）：
  python tools/cutout.py --id striker --kind units --native-alpha
  python tools/cutout.py --group units
  python tools/cutout.py --all
  python tools/cutout.py --id striker --kind units --variant 2     # 选用第 2 个候选
"""
import argparse
import io
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

TOOLS = Path(__file__).resolve().parent
PROJECT = TOOLS.parent
RAW = TOOLS / "_raw"
MANIFEST = TOOLS / "art_manifest.json"
MAGENTA = np.array([255, 0, 255], dtype=np.int16)
FOOT_PAD = 24


def chroma_key(img: Image.Image, tol: int = 60) -> Image.Image:
    rgba = np.array(img.convert("RGBA")).astype(np.int16)
    dist = np.abs(rgba[..., :3] - MAGENTA).sum(axis=-1)
    alpha = np.clip((dist - tol) * (255.0 / tol), 0, 255).astype(np.uint8)
    rgba[..., 3] = np.minimum(rgba[..., 3], alpha)
    # 去色晕：把半透明像素中的品红成分向邻近色拉回
    out = rgba.astype(np.uint8)
    semi = (out[..., 3] > 0) & (out[..., 3] < 255)
    out[semi, 0] = np.minimum(out[semi, 0], out[semi, 1] + 40)
    out[semi, 2] = np.minimum(out[semi, 2], out[semi, 1] + 40)
    return Image.fromarray(out, "RGBA")


def rembg_refine(img: Image.Image) -> Image.Image:
    try:
        from rembg import remove  # type: ignore
    except Exception:  # noqa
        print("  (rembg 不可用，跳过精修)")
        return img
    refined = remove(img.convert("RGBA"))
    a1 = np.array(img.convert("RGBA"))[..., 3].astype(np.int16)
    a2 = np.array(refined)[..., 3].astype(np.int16)
    merged = np.array(img.convert("RGBA"))
    merged[..., 3] = np.minimum(a1, a2).astype(np.uint8)
    return Image.fromarray(merged, "RGBA")


def trim(img: Image.Image) -> Image.Image:
    bbox = img.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    if bbox is None:
        raise RuntimeError("抠图后为空图")
    return img.crop(bbox)


def opaque_ratio(img: Image.Image) -> float:
    a = np.array(img.getchannel("A"))
    return float((a > 8).mean())


def transparent_source(src: Image.Image, native_alpha: bool) -> Image.Image:
    if not native_alpha:
        return rembg_refine(chroma_key(src))
    if "A" not in src.getbands() and "transparency" not in src.info:
        raise RuntimeError("原生透明输入缺少 alpha，请使用原生透明图")
    rgba = src.convert("RGBA")
    if rgba.getchannel("A").getextrema()[0] == 255:
        raise RuntimeError("原生透明输入完全不透明，请重生成透明背景")
    return rgba


def process_sprite(src: Image.Image, target: int, native_alpha: bool = False) -> Image.Image:
    if target <= FOOT_PAD:
        raise ValueError("target 必须大于底边留白")
    keyed = transparent_source(src, native_alpha)
    if not native_alpha:
        ratio = opaque_ratio(keyed)
        if ratio < 0.08 or ratio > 0.85:
            raise RuntimeError(f"抠图结果可疑（不透明像素占比 {ratio:.2f}），请重生成")
    cut = trim(keyed)
    inner = target - FOOT_PAD
    scale = min(inner / cut.width, inner / cut.height)
    cut = cut.resize((max(1, int(cut.width * scale)), max(1, int(cut.height * scale))), Image.LANCZOS)
    canvas = Image.new("RGBA", (target, target), (0, 0, 0, 0))
    x = (target - cut.width) // 2
    y = target - FOOT_PAD - cut.height
    canvas.alpha_composite(cut, (x, max(0, y)))
    return canvas


def process_portrait(src: Image.Image, target: int) -> Image.Image:
    w, h = src.size
    s = min(w, h)
    box = ((w - s) // 2, (h - s) // 2, (w - s) // 2 + s, (h - s) // 2 + s)
    return src.convert("RGBA").crop(box).resize((target, target), Image.LANCZOS)


def process_illustration(src: Image.Image, tw: int, th: int, native_alpha: bool = False) -> Image.Image:
    """立绘：抠图 → 裁边 → 等比缩放到高度 th → 居中到 tw×th，脚底贴底。"""
    cut = trim(transparent_source(src, native_alpha))
    scale = min(th / cut.height, tw / cut.width)
    cut = cut.resize((max(1, int(cut.width * scale)), max(1, int(cut.height * scale))), Image.LANCZOS)
    canvas = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    canvas.alpha_composite(cut, ((tw - cut.width) // 2, th - cut.height))
    return canvas


def portrait_from_illustration(illu: Image.Image, target: int) -> Image.Image:
    """从已抠图的立绘裁出头部方形，铺在深紫黑渐变底上。"""
    cut = trim(illu)
    a = np.array(cut.getchannel("A"))
    top_rows = a[: max(1, int(cut.height * 0.2))]
    cols = np.where(top_rows.max(axis=0) > 8)[0]
    cx = int(cols.mean()) if len(cols) else cut.width // 2
    s = int(cut.height * 0.32)
    x0 = max(0, min(cut.width - s, cx - s // 2))
    head = cut.crop((x0, 0, x0 + s, s)).resize((target, target), Image.LANCZOS)
    bg = Image.new("RGBA", (target, target), (0x2A, 0x14, 0x30, 255))
    grad = np.linspace(0, 1, target, dtype=np.float32)[:, None]
    arr = np.array(bg).astype(np.float32)
    arr[..., :3] = arr[..., :3] * (1.0 - 0.35 * grad)
    bg = Image.fromarray(arr.astype(np.uint8), "RGBA")
    bg.alpha_composite(head)
    return bg


def process_cover(src: Image.Image, tw: int, th: int) -> Image.Image:
    w, h = src.size
    scale = max(tw / w, th / h)
    img = src.convert("RGBA").resize((int(w * scale + 0.5), int(h * scale + 0.5)), Image.LANCZOS)
    x = (img.width - tw) // 2
    y = (img.height - th) // 2
    return img.crop((x, y, x + tw, y + th))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--id"); ap.add_argument("--kind"); ap.add_argument("--group")
    ap.add_argument("--all", action="store_true"); ap.add_argument("--variant", type=int, default=1)
    ap.add_argument("--native-alpha", action="store_true", help="保留原生 alpha，跳过品红色键与 rembg；只做裁边、缩放和对齐")
    a = ap.parse_args()
    m = json.loads(MANIFEST.read_text(encoding="utf-8"))
    items = m["items"]
    if a.id:
        sel = [it for it in items if it["id"] == a.id and (not a.kind or it["kind"] == a.kind)]
    elif a.group:
        sel = [it for it in items if it["kind"] == a.group]
    elif a.all:
        sel = items
    else:
        ap.print_help(); return 1

    ok = fail = 0
    for it in sel:
        kind = it["kind"]
        suffix = "" if a.variant <= 1 else f"_v{a.variant}"
        out_cfg = m["output"][kind]
        out_dir = PROJECT / out_cfg["dir"]; out_dir.mkdir(parents=True, exist_ok=True)
        out_path = out_dir / f"{it['id']}.png"
        if "source" in it:
            # 从已处理的立绘派生（先处理 illustrations 组）
            src_path = PROJECT / m["output"]["illustrations"]["dir"] / (it["source"].split("/", 1)[1] + ".png")
        else:
            src_path = RAW / kind / f"{it['id']}{suffix}.png"
        if not src_path.exists():
            print(f"  - 跳过 {kind}/{it['id']}：原图不存在 {src_path.relative_to(PROJECT)}"); continue
        try:
            src = Image.open(src_path)
            if "source" in it:
                res = portrait_from_illustration(src.convert("RGBA"), int(out_cfg["target"]))
            elif kind in ("units", "props"):
                res = process_sprite(src, int(out_cfg["target"]), a.native_alpha)
            elif kind == "illustrations":
                res = process_illustration(src, *out_cfg["target"], native_alpha=a.native_alpha)
            elif kind == "portraits":
                res = process_portrait(src, int(out_cfg["target"]))
            elif kind == "backgrounds":
                res = process_cover(src, *out_cfg["target"])
            else:  # ui
                if a.native_alpha and "transparent" in it["prompt"].lower():
                    res = trim(transparent_source(src, True))
                elif "magenta" in it["prompt"].lower():
                    res = trim(rembg_refine(chroma_key(src)))
                else:
                    res = process_cover(src, 1920, 1080)
            res.save(out_path, optimize=True)
            print(f"  ✓ {out_path.relative_to(PROJECT)} {res.size}")
            ok += 1
        except Exception as e:  # noqa
            print(f"  ✗ {kind}/{it['id']}: {e}")
            fail += 1
    print(f"完成：成功 {ok}，失败 {fail}")
    return 0 if fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
