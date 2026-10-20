#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""2026-10-20：把策划交付的《剧本.docx》导入为 30 关剧情（data/stories/level_cNN_intro.json / level_cNN_win.json）。
剧本格式：幕标题行（「序幕 · 工坊」「第一幕 · 农田」…）→ 关卡标题行「<序号> <关名>」→「开头：」段 →「结尾：」段；
最后的「尾声」段（「放在30关结尾：」）接在第 30 关 _win 末尾。
行格式「说话人：台词」按 SPEAKERS 映射说话人与立绘，其余行为旁白（narrator，无立绘）。
「【…】」导演备注（如【放cg！】）不入剧情，导入时打印出来。
织骸在第 27 关之前只是「体内的声音」，用笼罩在阴影里的 witch_shadow 立绘；第 27 关起本人登场，显示 witch 立绘。
注意：重新导入会覆盖手工加进剧情的句子（如第 18 关开头的 CG 句 {"cg": "doll_tears"}），导入后需补回。
已有剧情文件会被覆盖（仅 level_cNN_intro / _win；_phase2 等其它文件不动）。
用法（godot/ 目录）：python tools/import_script_stories.py <剧本.docx> [--dry-run]
"""
import html
import io
import json
import re
import sys
import zipfile
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
GODOT = Path(__file__).resolve().parent.parent
STORIES = GODOT / "data/stories"
WITCH_SHOWN_FROM = 27            # 织骸本人登场的关卡（之前只是声音）

# 剧本里的说话人 → (strings.json speakers 键, 立绘)
SPEAKERS = {
    "织骸": ("witch", "witch"),
    "人偶": ("doll", "doll"),
    "守火派魔女 A": ("keeper_a", "keeper"),
    "守火派魔女 B": ("keeper_b", "keeper"),
    "守火派魔女 C": ("keeper_c", "keeper"),
    "回响": ("echo", ""),
    "骨者": ("bone_elder", "bone_elder"),
    "敲钟魔女": ("bell_witch", "bell_witch"),
    "缄默者信徒": ("silent_believer", ""),
    "灵魂": ("soul", ""),
    "低语": ("whisper", ""),
    "骨刃": ("bone_blade", ""),
    "一": ("yi", "doll_worn"),
    "骨花魔女": ("bone_witch", "bone_witch"),
}
ACT_RE = re.compile(r"^(序幕|第.幕|终幕)\s*·")
LEVEL_RE = re.compile(r"^(\d{1,2})\s+(\S.*)$")


def docx_lines(path: Path) -> list:
    xml = zipfile.ZipFile(path).read("word/document.xml").decode("utf-8")
    out = []
    for p in re.findall(r"<w:p[ >].*?</w:p>", xml, re.S):
        t = "".join(re.findall(r"<w:t[^>]*>([^<]*)</w:t>", p))
        out.append(html.unescape(t).strip())
    return out


def curly(text: str) -> str:
    """成对的直引号换成中文引号"""
    parts = text.split('"')
    if len(parts) % 2 == 0:
        return text
    return "".join(p + ("“" if i % 2 == 0 else "”") for i, p in enumerate(parts[:-1])) + parts[-1]


def scene(line: str, level: int) -> dict:
    head, sep, body = line.partition("：")
    if sep and head in SPEAKERS:
        key, illu = SPEAKERS[head]
        if key == "witch" and level < WITCH_SHOWN_FROM:
            illu = "witch_shadow"          # 2026-10-20 用户：本人登场前立绘上半涂黑、往下渐变回原色（tools/make_reskin_art.py）
        return {"speaker": key, "illustration": illu, "text": curly(body.strip())}
    return {"speaker": "narrator", "illustration": "", "text": curly(line)}


def parse(lines: list) -> tuple:
    stories, titles, notes = {}, {}, []
    level, part = 0, ""
    for line in lines:
        if not line or ACT_RE.match(line):
            continue
        m = LEVEL_RE.match(line)
        if m and line not in ("开头：", "结尾："):
            level, part = int(m.group(1)), ""
            titles[level] = m.group(2).strip()
            continue
        if line == "尾声":
            level, part = 30, "win"
            continue
        if line in ("开头：", "结尾：", "放在30关结尾："):
            part = {"开头：": "intro", "结尾：": "win"}.get(line, "win")
            continue
        if line.startswith("【") and line.endswith("】"):
            notes.append(f"第 {level} 关 {part}：{line}（未导入）")
            continue
        if level == 0 or part == "":
            notes.append(f"无法归属的行：{line}")
            continue
        stories.setdefault(f"level_c{level:02d}_{part}", []).append(scene(line, level))
    return stories, titles, notes


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        sys.exit(__doc__)
    stories, titles, notes = parse(docx_lines(Path(args[0])))
    for sid, scenes in sorted(stories.items()):
        print(f"{sid}: {len(scenes)} 句")
        if "--dry-run" not in sys.argv:
            doc = {"id": sid, "scenes": scenes}
            (STORIES / f"{sid}.json").write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("关名：", json.dumps(titles, ensure_ascii=False))
    used = sorted({s["speaker"] for v in stories.values() for s in v})
    print("说话人：", used)
    for n in notes:
        print("注意：", n)


if __name__ == "__main__":
    main()
