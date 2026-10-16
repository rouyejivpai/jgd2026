#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
批量调用 PackyAPI gpt-image-2 生成 art_manifest.json 中的资源原图。
原图保存到 tools/_raw/<kind>/<id>[_vN].png（不入库），再由 cutout.py 规格化。

用法（在 godot/ 目录）：
  python tools/gen_image.py --list
  python tools/gen_image.py --id striker --kind units
  python tools/gen_image.py --group units            # kind 分组：units/portraits/backgrounds/props/ui
  python tools/gen_image.py --all --skip-existing
  python tools/gen_image.py --id striker --kind units --variant 2   # 生成第 2 个候选

规则：失败只报告 HTTP 状态码与响应体，不重试、不编造；不要把响应 url 打印到终端（可能是几百 KB 的 base64）。
"""
import argparse
import base64
import io
import json
import os
import re
import sys
import time
from pathlib import Path

import requests

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

TOOLS = Path(__file__).resolve().parent
RAW = TOOLS / "_raw"
MANIFEST = TOOLS / "art_manifest.json"
ENDPOINT = "https://ai-pixel.online/v1/images/generations"
SKILL_CONFIG = Path.home() / ".claude" / "skills" / "packy-image" / "config.json"


def api_key() -> str:
    k = os.environ.get("PACKY_API_KEY")
    if k:
        return k
    if SKILL_CONFIG.exists():
        return json.loads(SKILL_CONFIG.read_text(encoding="utf-8")).get("api_key", "")
    raise SystemExit("未找到 PACKY_API_KEY（环境变量或 ~/.claude/skills/packy-image/config.json）")


def load_manifest() -> dict:
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def build_prompt(m: dict, item: dict) -> str:
    parts = [item["prompt"].strip()]
    kind_suffix = m["style_suffix"].get(item["kind"], "")
    if kind_suffix:
        parts.append(kind_suffix)
    parts.append(m["style_suffix"].get("common_" + item["kind"], m["style_suffix"]["common"]))
    return ", ".join(parts)


def out_path(item: dict, variant: int) -> Path:
    d = RAW / item["kind"]
    d.mkdir(parents=True, exist_ok=True)
    suffix = "" if variant <= 1 else f"_v{variant}"
    return d / f"{item['id']}{suffix}.png"


def save_image(data: dict, path: Path) -> None:
    d = data["data"][0]
    if d.get("b64_json"):
        path.write_bytes(base64.b64decode(d["b64_json"]))
        return
    url = d.get("url", "")
    m = re.match(r"^data:image/(\w+);base64,(.+)$", url, re.S)
    if m:
        path.write_bytes(base64.b64decode(m.group(2)))
        return
    if url.startswith("http"):
        r = requests.get(url, timeout=120)
        r.raise_for_status()
        path.write_bytes(r.content)
        return
    raise RuntimeError("响应中未找到图片数据")


def generate(m: dict, item: dict, variant: int, quality: str) -> bool:
    path = out_path(item, variant)
    size = item.get("size") or m["defaults"][item["kind"]]["size"]
    body = {"model": "gpt-image-2", "prompt": build_prompt(m, item), "size": size, "quality": quality, "response_format": "b64_json", "n": 1}
    print(f"→ 生成 {item['kind']}/{item['id']} ({size}, {quality}) ...", flush=True)
    t0 = time.time()
    try:
        r = requests.post(ENDPOINT, json=body, headers={"Authorization": f"Bearer {api_key()}", "Content-Type": "application/json"}, timeout=240)
    except requests.RequestException as e:
        print(f"  ✗ 请求失败: {e}")
        return False
    if r.status_code != 200:
        print(f"  ✗ HTTP {r.status_code}: {r.text[:500]}")
        return False
    try:
        save_image(r.json(), path)
    except Exception as e:  # noqa
        print(f"  ✗ 保存失败: {e}")
        return False
    print(f"  ✓ {path.relative_to(TOOLS.parent)} ({path.stat().st_size // 1024} KB, {time.time() - t0:.0f}s)")
    return True


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--id")
    ap.add_argument("--kind")
    ap.add_argument("--group")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--skip-existing", action="store_true")
    ap.add_argument("--variant", type=int, default=1)
    ap.add_argument("--quality", default="high", choices=["low", "medium", "high", "auto"])
    a = ap.parse_args()
    m = load_manifest()
    items = m["items"]

    if a.list:
        for it in items:
            if "source" in it:
                print(f"- {it['kind']:14s} {it['id']}  (由 {it['source']} 裁切，不调用 API)")
                continue
            exists = out_path(it, 1).exists()
            print(f"{'✓' if exists else ' '} {it['kind']:14s} {it['id']}")
        return 0
    items = [it for it in items if "source" not in it]

    if a.id:
        sel = [it for it in items if it["id"] == a.id and (not a.kind or it["kind"] == a.kind)]
        if len(sel) > 1:
            raise SystemExit(f"id '{a.id}' 在多个 kind 中出现，请加 --kind")
    elif a.group:
        sel = [it for it in items if it["kind"] == a.group]
    elif a.all:
        sel = items
    else:
        ap.print_help(); return 1
    if not sel:
        raise SystemExit("没有匹配的条目")

    ok = fail = skipped = 0
    for it in sel:
        if a.skip_existing and out_path(it, a.variant).exists():
            skipped += 1; continue
        if generate(m, it, a.variant, a.quality):
            ok += 1
        else:
            fail += 1
    print(f"完成：成功 {ok}，失败 {fail}，跳过 {skipped}")
    return 0 if fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
