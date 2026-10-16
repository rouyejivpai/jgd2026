#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
带参考图的 PackyAPI 生图（第四阶段：侧栏详情 UI 整图 / 透明组件、角色图替换）。

  文生图：      python tools/gen_image_ref.py --prompt-file p.txt --out a.png [--size 1536x1024]
  图生图/参考：  python tools/gen_image_ref.py --prompt-file p.txt --ref whole.png --ref glyphs.png --out b.png
                 （有 --ref 时走 /v1/images/edits，multipart image[]；--background transparent 要求透明底）

规则同 gen_image.py：失败只报告 HTTP 状态码与响应体，不重试、不编造；不打印响应 url（可能是 base64）。
"""
import argparse
import base64
import io
import json
import mimetypes
import os
import re
import sys
import time
from pathlib import Path

import requests

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

BASE = "https://ai-pixel.online"
SKILL_CONFIG = Path.home() / ".claude" / "skills" / "packy-image" / "config.json"


def config() -> dict:
    return json.loads(SKILL_CONFIG.read_text(encoding="utf-8")) if SKILL_CONFIG.exists() else {}


def api_key() -> str:
    return os.environ.get("PACKY_API_KEY") or config().get("api_key", "")


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
        r = requests.get(url, timeout=180)
        r.raise_for_status()
        path.write_bytes(r.content)
        return
    raise RuntimeError("响应中未找到图片数据")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--prompt-file", required=True)
    ap.add_argument("--ref", action="append", default=[])
    ap.add_argument("--out", required=True)
    ap.add_argument("--size", default="1536x1024")
    ap.add_argument("--quality", default="high")
    ap.add_argument("--background", default="")
    ap.add_argument("--model", default="")
    ap.add_argument("--key", default="", help="用 config.json 的 key（环境变量 401 时）")
    a = ap.parse_args()
    prompt = Path(a.prompt_file).read_text(encoding="utf-8").strip()
    model = a.model or config().get("model", "gpt-image-2.5-sunburst")
    key = config().get("api_key", "") if a.key == "config" else api_key()
    headers = {"Authorization": f"Bearer {key}"}
    out = Path(a.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    t0 = time.time()
    print(f"→ {'edits' if a.ref else 'generations'} {model} {a.size} {a.quality} refs={len(a.ref)} → {out}", flush=True)
    try:
        if a.ref:
            fields = {"model": model, "prompt": prompt, "size": a.size, "quality": a.quality, "n": "1", "response_format": "b64_json"}
            if a.background:
                fields["background"] = a.background
            files = []
            for p in a.ref:
                mt = mimetypes.guess_type(p)[0] or "image/png"
                files.append(("image[]", (Path(p).name, Path(p).read_bytes(), mt)))
            r = requests.post(BASE + "/v1/images/edits", data=fields, files=files, headers=headers, timeout=600)
        else:
            body = {"model": model, "prompt": prompt, "size": a.size, "quality": a.quality, "n": 1, "response_format": "b64_json"}
            if a.background:
                body["background"] = a.background
            r = requests.post(BASE + "/v1/images/generations", json=body, headers=headers, timeout=600)
    except requests.RequestException as e:
        print(f"  ✗ 请求失败: {e}")
        return 1
    if r.status_code != 200:
        print(f"  ✗ HTTP {r.status_code}: {r.text[:800]}")
        return 1
    try:
        js = r.json()
        save_image(js, out)
    except Exception as e:  # noqa
        print(f"  ✗ 保存失败: {e}; body head: {r.text[:300]}")
        return 1
    print(f"  ✓ {out} ({out.stat().st_size // 1024} KB, {time.time() - t0:.0f}s)")
    rp = js["data"][0].get("revised_prompt")
    if rp:
        print("  revised_prompt:", rp[:300])
    return 0


if __name__ == "__main__":
    sys.exit(main())
