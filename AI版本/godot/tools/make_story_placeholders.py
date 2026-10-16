#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""07 §10.2 剧情占位：为每个关卡生成 data/stories/<level_id>_{intro,win,lose}.json。
固定约定：每关开始（_intro）、胜利（_win）、失败（_lose）各一段，StoryPlayer 按 id 查找；文件缺失或 scenes 为空 = 不触发。

用法（在 godot/ 目录）：
  python tools/make_story_placeholders.py            只创建缺失的文件（已存在的不动）
  python tools/make_story_placeholders.py --force    覆盖重建全部占位
  python tools/make_story_placeholders.py --migrate  一次性迁移（第二阶段 P5）：关卡 briefing.dialogue → <level>_intro，
                                                      strings.json stories.ch1_boss_outro → level_08_win，
                                                      然后从关卡 JSON 删除 briefing.dialogue 与 rewards.story_id、从 strings.json 删除 stories 占位
占位内容：一句 system 文本"剧情待配置：<story_id>"。文案不改，等剧情配置器。
"""
import io
import json
import re
import sys
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
STORIES = DATA / "stories"
KINDS = ("intro", "win", "lose")
ILLUSTRATED = {"doll", "witch"}          # 有立绘的说话人（01 §9：默认人偶，魔女说话时切换）
LEGACY_TO_STORY = {"ch1_boss_outro": "level_08_win"}


def scene(speaker, text):
    return {"speaker": speaker, "illustration": speaker if speaker in ILLUSTRATED else "", "text": text}


def placeholder(story_id):
    return {"id": story_id, "scenes": [scene("system", "剧情待配置：%s" % story_id)]}


def fmt_story(d):
    lines = ['{', '  "id": %s,' % json.dumps(d["id"], ensure_ascii=False), '  "scenes": [']
    for i, s in enumerate(d["scenes"]):
        body = ", ".join("%s: %s" % (json.dumps(k, ensure_ascii=False), json.dumps(v, ensure_ascii=False)) for k, v in s.items())
        lines.append("    { %s }%s" % (body, "," if i < len(d["scenes"]) - 1 else ""))
    lines += ['  ]', '}']
    return "\n".join(lines) + "\n"


def strip_level(path):
    text = path.read_text(encoding="utf-8")
    before = json.loads(text)
    text2 = re.sub(r'\n    "dialogue": \[\n.*?\n    \],', '', text, count=1, flags=re.S)
    text2 = re.sub(r',\s*"story_id": "[^"]*"', '', text2, count=1)
    after = json.loads(text2)
    b = dict(before)
    b["briefing"] = {k: v for k, v in before["briefing"].items() if k != "dialogue"}
    b["rewards"] = {k: v for k, v in before["rewards"].items() if k != "story_id"}
    assert b == after, path
    path.write_text(text2, encoding="utf-8", newline="\n")


def main():
    force = "--force" in sys.argv
    migrate = "--migrate" in sys.argv
    STORIES.mkdir(parents=True, exist_ok=True)
    strings = json.loads((DATA / "strings.json").read_text(encoding="utf-8"))
    legacy = strings.get("stories", {})
    written = 0
    level_paths = sorted((DATA / "levels").glob("level_*.json"))
    for lp in level_paths:
        L = json.loads(lp.read_text(encoding="utf-8"))
        lid = L["id"]
        for kind in KINDS:
            sid = "%s_%s" % (lid, kind)
            out = STORIES / ("%s.json" % sid)
            if out.exists() and not force and not migrate:
                continue
            story = placeholder(sid)
            if migrate or force:
                if kind == "intro" and L.get("briefing", {}).get("dialogue"):
                    story = {"id": sid, "scenes": [scene(x["speaker"], x["text"]) for x in L["briefing"]["dialogue"]]}
                for old, new in LEGACY_TO_STORY.items():
                    if new == sid and legacy.get(old):
                        story = {"id": sid, "scenes": [scene(x["speaker"], x["text"]) for x in legacy[old]]}
                if out.exists() and not force and not migrate:
                    continue
                if out.exists() and migrate and not force:
                    existing = json.loads(out.read_text(encoding="utf-8"))
                    if existing.get("scenes") and existing != placeholder(sid):
                        continue          # 已配置过的剧情不覆盖
            out.write_text(fmt_story(story), encoding="utf-8", newline="\n")
            written += 1
    if migrate:
        for lp in level_paths:
            L = json.loads(lp.read_text(encoding="utf-8"))
            if "dialogue" in L.get("briefing", {}) or "story_id" in L.get("rewards", {}):
                strip_level(lp)
        text = (DATA / "strings.json").read_text(encoding="utf-8")
        text2 = re.sub(r'\n  "_stories_comment": "[^"]*",', '', text, count=1)
        text2 = re.sub(r'\n  "stories": [^\n]*', '', text2, count=1)        # stories 占位在 strings.json 中是单独一行
        s2 = json.loads(text2)
        assert "stories" not in s2 and {k: v for k, v in strings.items() if k not in ("stories", "_stories_comment")} == s2
        (DATA / "strings.json").write_text(text2, encoding="utf-8", newline="\n")
    print("剧情文件写入 %d 个 -> %s" % (written, STORIES))
    return 0


if __name__ == "__main__":
    sys.exit(main())
