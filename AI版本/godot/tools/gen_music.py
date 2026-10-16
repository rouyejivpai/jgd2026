#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
通过 Suno.cn REST API 生成 music_manifest.json 中的 BGM，并下载 mp3 到 assets/audio/bgm/<id>.mp3。

用法（在 godot/ 目录）：
  python tools/gen_music.py --list
  python tools/gen_music.py --id menu_theme
  python tools/gen_music.py --all --skip-existing
  python tools/gen_music.py --status 123,456          # 查询已提交任务并下载（任务号打印在 tools/_raw/music_tasks.json）

API Key：环境变量 SUNO_CN_API_KEY，或 ~/.claude/skills/suno-cn-music/config.json 的 api_key。
规则：失败只报告状态码与响应体，不编造；同一任务最多查询 12 次（每次服务端等待 45 秒），仍未完成则记录任务号退出。
每次提交通常返回 2 个任务号（两个候选版本），脚本下载全部候选为 <id>.mp3 与 <id>_alt.mp3，由人工挑选后删除多余的。
"""
import argparse
import io
import json
import os
import sys
import time
from pathlib import Path

import requests

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

TOOLS = Path(__file__).resolve().parent
PROJECT = TOOLS.parent
MANIFEST = TOOLS / "music_manifest.json"
TASKS_FILE = TOOLS / "_raw" / "music_tasks.json"
OUT_DIR = PROJECT / "assets" / "audio" / "bgm"
BASE = "https://mcp.suno.cn"
SKILL_CONFIG = Path.home() / ".claude" / "skills" / "suno-cn-music" / "config.json"
MAX_POLLS = 12


def api_key() -> str:
    k = os.environ.get("SUNO_CN_API_KEY")
    if k:
        return k
    if SKILL_CONFIG.exists():
        return json.loads(SKILL_CONFIG.read_text(encoding="utf-8")).get("api_key", "")
    raise SystemExit("未找到 SUNO_CN_API_KEY（环境变量或 ~/.claude/skills/suno-cn-music/config.json）")


def headers() -> dict:
    return {"Authorization": f"Bearer {api_key()}", "Content-Type": "application/json; charset=utf-8"}


def load_tasks() -> dict:
    if TASKS_FILE.exists():
        return json.loads(TASKS_FILE.read_text(encoding="utf-8"))
    return {}


def save_tasks(t: dict) -> None:
    TASKS_FILE.parent.mkdir(parents=True, exist_ok=True)
    TASKS_FILE.write_text(json.dumps(t, ensure_ascii=False, indent=2), encoding="utf-8")


def submit(m: dict, item: dict) -> list:
    body = {"prompt": item["prompt"], "mv": m.get("mv", "v6"), "title": item.get("title", item["id"]),
            "tags": item.get("tags", ""), "custom_mode": False, "instrumental": True}
    r = requests.post(f"{BASE}/mcp/api/generate", data=json.dumps(body, ensure_ascii=False).encode("utf-8"), headers=headers(), timeout=60)
    if r.status_code != 200:
        print(f"  ✗ 提交失败 HTTP {r.status_code}: {r.text[:500]}")
        return []
    data = r.json()
    serials = [str(s) for s in data.get("serial_nos", [])]
    print(f"  ✓ 已提交，任务号 {serials}  ({data.get('message', '')})")
    return serials


def query(serials: list, wait: bool) -> list:
    url = f"{BASE}/mcp/api/task/{','.join(serials)}" + ("?wait=45" if wait else "")
    r = requests.get(url, headers=headers(), timeout=90)
    if r.status_code != 200:
        print(f"  ✗ 查询失败 HTTP {r.status_code}: {r.text[:500]}")
        return []
    return r.json().get("tasks", [])


def download(url: str, path: Path) -> None:
    r = requests.get(url, timeout=180)
    r.raise_for_status()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(r.content)
    print(f"  ✓ 已下载 {path.relative_to(PROJECT)} ({path.stat().st_size // 1024} KB)")


def wait_and_download(item_id: str, serials: list) -> bool:
    done = {}
    for i in range(MAX_POLLS):
        tasks = query(serials, wait=True)
        if not tasks:
            return False
        for t in tasks:
            sn = str(t.get("serial_no"))
            st = t.get("status")
            if st == "success" and sn not in done:
                done[sn] = t
            elif st == "failed":
                print(f"  ✗ 任务 {sn} 失败: {t.get('fail_reason')}")
                done[sn] = None
        if len(done) >= len(serials):
            break
        print(f"  … 第 {i + 1} 次查询，仍在生成中")
    ok = [t for t in done.values() if t]
    if not ok:
        print(f"  ✗ {item_id} 无成功结果（任务号 {serials} 已记录，可稍后用 --status 重试）")
        return False
    for idx, t in enumerate(ok):
        name = f"{item_id}.mp3" if idx == 0 else f"{item_id}_alt{idx}.mp3"
        print(f"  标题 {t.get('title')}，时长 {t.get('duration')} 秒")
        download(t["play_url"], OUT_DIR / name)
    return True


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--list", action="store_true"); ap.add_argument("--id"); ap.add_argument("--all", action="store_true")
    ap.add_argument("--skip-existing", action="store_true"); ap.add_argument("--status")
    a = ap.parse_args()
    m = json.loads(MANIFEST.read_text(encoding="utf-8"))
    items = m["items"]
    tasks = load_tasks()

    if a.list:
        for it in items:
            print(f"{'✓' if (OUT_DIR / (it['id'] + '.mp3')).exists() else ' '} {it['id']:16s} {it['title']}")
        return 0
    if a.status:
        serials = a.status.split(",")
        item_id = next((k for k, v in tasks.items() if set(v) & set(serials)), "manual")
        return 0 if wait_and_download(item_id, serials) else 1

    sel = [it for it in items if it["id"] == a.id] if a.id else (items if a.all else [])
    if not sel:
        ap.print_help(); return 1
    ok = fail = 0
    for it in sel:
        if a.skip_existing and (OUT_DIR / f"{it['id']}.mp3").exists():
            continue
        print(f"→ {it['id']}")
        serials = submit(m, it)
        if not serials:
            fail += 1; continue
        tasks[it["id"]] = serials; save_tasks(tasks)
        time.sleep(5)
        if wait_and_download(it["id"], serials):
            ok += 1
        else:
            fail += 1
    print(f"完成：成功 {ok}，失败 {fail}")
    return 0 if fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
