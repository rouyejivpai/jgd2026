#!/usr/bin/env python3
"""第五阶段：把 data/teaching.json 中的关卡配置覆盖「固化」进关卡文件（可选步骤）。

配置器导入的配置包写在 teaching.json，游戏运行时即生效，不固化也可以发布。
需要把数值直接写进 data/levels/<id>.json（例如交给不用配置器的人维护）时运行本工具：

    python tools/bake_teaching.py                 # 固化全部关卡的「关卡配置」项（出场 / 部署区 / 单位 / 胜负 / 加成）
    python tools/bake_teaching.py --all           # 连同可用指令 / 通关解锁 / 提示文案一起固化
    python tools/bake_teaching.py --levels level_c05,level_c06
    python tools/bake_teaching.py --dry-run       # 只列出将改动的内容

固化后这些项从 teaching.json 移除（引导步骤与 test 标记保留）。第七关数据冻结，跳过。
关卡文件按 json indent=2 写回（30 关战役原本就是此格式；level_01–08 为手排格式，固化会整体改排版）。
运行后请执行：python tools/validate_data.py，GUT 全量，run_playtests -- --check，并在 docs/CHANGELOG.md 记一行。
"""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "data"
LEVEL_KEYS = ("roster", "deploy_zone", "initial_units", "objectives", "modifiers")
TEXT_KEYS = ("allowed", "rewards", "hints", "mechanic_hint")
MERGED = ("allowed", "rewards", "roster", "objectives")
FROZEN = "level_07"


def bake_entry(level, entry, keys):
    """与 TeachingDef.apply_overrides 同口径，把 entry 中 keys 的覆盖写进 level（就地修改），返回已固化的键"""
    done = []
    for k in keys:
        if k not in entry:
            continue
        if k in MERGED and isinstance(entry[k], dict):
            merged = dict(level.get(k) or {})
            merged.update(entry[k])
            level[k] = merged
        elif k == "mechanic_hint":
            level.setdefault("briefing", {})["mechanic_hint"] = entry[k]
        else:
            level[k] = json.loads(json.dumps(entry[k]))
        done.append(k)
    return done


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--all", action="store_true", help="连同可用指令 / 通关解锁 / 提示文案一起固化")
    ap.add_argument("--levels", default="", help="只处理这些关卡（逗号分隔）")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    keys = LEVEL_KEYS + (TEXT_KEYS if a.all else ())
    tpath = ROOT / "teaching.json"
    teaching = json.loads(tpath.read_text(encoding="utf-8"))
    only = {x.strip() for x in a.levels.split(",") if x.strip()}
    changed = []
    for lid, entry in (teaching.get("levels") or {}).items():
        if (only and lid not in only) or not any(k in entry for k in keys):
            continue
        if lid == FROZEN:
            print(f"跳过 {lid}（第七关数据冻结）")
            continue
        lpath = ROOT / "levels" / f"{lid}.json"
        if not lpath.exists():
            print(f"跳过 {lid}：关卡文件不存在", file=sys.stderr)
            continue
        level = json.loads(lpath.read_text(encoding="utf-8"))
        done = bake_entry(level, entry, keys)
        print(f"{lid}: 固化 {', '.join(done)}")
        changed.append(lid)
        if not a.dry_run:
            lpath.write_text(json.dumps(level, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            for k in done:
                entry.pop(k, None)
    if not changed:
        print("teaching.json 中没有需要固化的关卡配置。")
        return 0
    if not a.dry_run:
        teaching["levels"] = {k: v for k, v in teaching["levels"].items() if v}
        tpath.write_text(json.dumps(teaching, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print("完成。请运行 validate_data.py、GUT 全量、run_playtests -- --check，并在 docs/CHANGELOG.md 记一行。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
