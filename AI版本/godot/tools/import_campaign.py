#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
把 30 关战役（关卡编辑器格式，见 output/关卡完善_20261014/01-关卡数据_编辑器格式）导入原型：

  data/levels/level_c01.json … level_c30.json   （与第一章 level_01…08 并存，互不覆盖）
  data/chapters/chapter_02.json                  （第二个章节地图：8 个地区 / 30 个节点）
  data/progression.json                          （initial_levels 追加 level_c01，战役可直接开始）

转换要点（编辑器格式 → 原型格式，详见 output/…/05-工具/tools/campaign_to_game.py）：
  - 信标 [x, y] → {id, cell}；at_beacon 编号转字符串；max_hp_override → overrides.max_hp；
    overrides 里的非数值键移到单位本身；survive 补守护对象；lose 至少一条；hints / fail_feedback 补齐。
  - id 改成 level_cNN；index = 100 + N（D06 要求全局唯一），display_index = N（界面显示「第 N 关」）。
  - rewards.unlock_level 串成 c01 → c02 → … → c30；按每关 roster / allowed 反推解锁链，
    保证从第一章初始解锁出发，每一关需要的形态 / 条件 / 选敌 / 行为都已在前一关解锁。
  - 场景：编辑器里引用的 review_r4 障碍块清单与新地形不对应，一律去掉；背景按地区借用第一阶段的 8 张背景（占位）。
  - 视野：30 关按设计视野验证过（与第一章 units.json 有 9 处不同）。为了不改第一章，
    在每关用 modifiers（form:<单位>）把相关单位的视野设成设计值；骸猎犬未显式写指令的，补上「向量之和」逃跑。

用法（在 godot/ 目录下）：
  python tools/import_campaign.py <编辑器格式关卡目录>
"""

from __future__ import annotations

import copy
import glob
import io
import json
import os
import sys
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

GODOT = Path(__file__).resolve().parent.parent
DATA = GODOT / "data"
STATS = {"max_hp", "attack", "attack_speed", "move_speed", "vision", "range"}
CARD_SLOTS = 5      # scripts/ui/hud.gd CARD_SLOTS（data/ui_layout 的 card_1…card_5）

# 30 关验证时使用的设计视野（交付物 pck 数据）；与 units.json 不同的会写成关卡 modifiers
DESIGN_VISION = {"bone_core": 13, "bone_guard": 9, "brute": 10, "bulwark": 9, "echo_pillar": 7, "hound": 9,
                 "husk": 9, "lancer": 11, "raider": 9, "striker": 9, "swift": 10, "warden": 9}

HOUND_RULES = [
    {"conditions": [{"type": "retreat_possible", "threat_radius": 4, "search_depth": 3, "flee": "vector_sum"}],
     "action": {"type": "retreat", "threat_radius": 4, "search_depth": 3, "flee": "vector_sum"}},
    {"conditions": [{"type": "enemy_in_range"}], "target": {"selector": "nearest", "filter": "unit"}, "action": {"type": "attack"}},
    {"conditions": [], "action": {"type": "idle"}},
]

# 地区 → 章节区域、节点图标、局内地图底图（2026-10-18 区域底图，tools/region_map_post.py 产出）
REGIONS = [
    ("bone_workshop", "人偶工坊", "rake", "res://assets/backdrops/regions/bone_workshop.png"),
    ("withered_farm", "枯骨农田", "rake", "res://assets/backdrops/regions/withered_farm.png"),
    ("grey_thorn", "灰棘林", "shield", "res://assets/backdrops/regions/grey_thorn.png"),
    ("holy_bell", "圣钟城废墟", "grid", "res://assets/backdrops/regions/holy_bell.png"),
    ("flesh_swamp", "肉巢沼泽", "wolf_head", "res://assets/backdrops/regions/flesh_swamp.png"),
    ("warped_corridor", "畸变回廊", "crosshair", "res://assets/backdrops/regions/warped_corridor.png"),
    ("bone_greenhouse", "骨花温室", "flower", "res://assets/backdrops/regions/bone_greenhouse.png"),
    ("final_battle", "最终战", "flower", "res://assets/backdrops/regions/bone_greenhouse.png"),
]
REGION = {r[0]: r for r in REGIONS}
# 地区 → BGM（assets/audio/bgm/<id>.mp3）；地区场景曲来自「游戏场景bgm.zip」，没有专曲的地区沿用原型已有曲目（Boss 战用 boss_01）
REGION_BGM = {"bone_workshop": "battle_01", "withered_farm": "region_withered_farm", "grey_thorn": "region_grey_thorn",
              "holy_bell": "region_holy_bell", "flesh_swamp": "region_flesh_swamp", "warped_corridor": "region_warped_corridor",
              "bone_greenhouse": "region_bone_greenhouse", "final_battle": "boss_01"}
GAME_BIOME = {"doll_workshop": "bone_farm", "godfall_core": "bone_greenhouse"}

INITIAL = json.load(open(DATA / "progression.json", encoding="utf-8"))["initial_unlocks"]
UNITS = json.load(open(DATA / "units.json", encoding="utf-8"))["units"]
COMMANDS = json.load(open(DATA / "commands.json", encoding="utf-8"))


def lid(n: int) -> str:
    return "level_c%02d" % n


def conv_beacons(bs):
    return [b if isinstance(b, dict) else {"id": str(i + 1), "cell": [int(b[0]), int(b[1])]} for i, b in enumerate(bs or [])]


def conv_rules(rules):
    for r in rules or []:
        for c in r.get("conditions") or []:
            if c.get("type") == "at_beacon" and not isinstance(c.get("beacon"), str):
                c["beacon"] = str(int(c.get("beacon", 1)))
    return rules


def unlock_key(kind: str, cid: str) -> str:
    for x in COMMANDS.get(kind, []):
        if x["id"] == cid:
            return x.get("unlock_key", "")
    return ""


def strip_md(v):
    """编辑器文本里的 **加粗** 是 Markdown 写法，游戏内不渲染：去掉星号。"""
    if isinstance(v, str):
        return v.replace("**", "")
    if isinstance(v, list):
        return [strip_md(x) for x in v]
    if isinstance(v, dict):
        return {k: (strip_md(x) if not k.startswith("_") else x) for k, x in v.items()}
    return v


TEXT_KEYS = ("title", "subtitle", "summary", "objectives", "briefing", "hints", "hint_tiers", "fail_feedback", "initial_units")


def convert(d: dict, n: int) -> dict:
    d = copy.deepcopy(d)
    d["id"] = lid(n)
    d["index"] = 100 + n
    d["display_index"] = n
    d["summary"] = d.get("subtitle", "")
    d["chapter"] = "chapter_02"
    for u in (d.get("recommended") or {}).get("units") or []:
        u["beacons"] = conv_beacons(u.get("beacons"))
        conv_rules(u.get("rules"))
    p2 = (d.get("recommended") or {}).get("phase2") or {}
    for u in p2.get("reinforcements") or []:
        u["beacons"] = conv_beacons(u.get("beacons"))
        conv_rules(u.get("rules"))
    for rs in (p2.get("rules") or {}).values():
        conv_rules(rs)
    # 原型 HUD 只有 5 个出场卡位（批准的 UI 版式）；超过时去掉推荐解（含第二阶段增援）用不到的形态，优先去快速形态
    forms = list(d["roster"].get("available_forms") or [])
    if len(forms) > CARD_SLOTS:
        used = {u["form"] for u in (d.get("recommended") or {}).get("units") or []} |             {u["form"] for u in ((d.get("recommended") or {}).get("phase2") or {}).get("reinforcements") or []}
        for f in sorted([f for f in forms if f not in used], key=lambda f: (f != "swift", forms.index(f))):
            if len(forms) <= CARD_SLOTS:
                break
            forms.remove(f)
            d["roster"].setdefault("_ui_note", []).append(f"去掉形态 {f}：原型 HUD 只有 {CARD_SLOTS} 个出场卡位")
        d["roster"]["available_forms"] = forms
    present = set(d["roster"].get("available_forms") or [])
    for e in d.get("initial_units") or []:
        present.add(e["unit"])
        ov = e.get("overrides") or {}
        for k in [k for k in ov if k not in STATS]:
            e.setdefault(k, ov.pop(k))
        if "max_hp_override" in e:
            ov["max_hp"] = e.pop("max_hp_override")
        if ov:
            e["overrides"] = ov
        else:
            e.pop("overrides", None)
        if e["unit"] == "hound" and not e.get("rules"):
            e["rules"] = copy.deepcopy(HOUND_RULES)
        if not e.get("rules"):
            # 默认指令引用了本关没有的路线（如 husk_lane）：原型校验会报错；验证时其效果是原地不动，这里显式写成待机
            dr = copy.deepcopy(UNITS.get(e["unit"], {}).get("default_rules") or [])
            if any((r.get("action") or {}).get("type") == "follow_route"
                   and r["action"].get("route_id") not in (d.get("routes") or {}) for r in dr):
                e["rules"] = [r if (r.get("action") or {}).get("type") != "follow_route"
                              else {"conditions": r.get("conditions") or [], "action": {"type": "idle"}} for r in dr]
        conv_rules(e.get("rules"))
    for u in (p2.get("reinforcements") or []):
        present.add(u["form"])
    mods = [m for m in d.get("modifiers") or [] if not m.get("_design_vision")]
    for uid in sorted(present):
        v = DESIGN_VISION.get(uid)
        if v is not None and uid in UNITS and UNITS[uid]["vision"] != v:
            mods.append({"target": "form:" + uid, "stat": "vision", "mul": 0, "add": v, "_design_vision": True})
    if mods:
        d["modifiers"] = mods
    obj = d.setdefault("objectives", {})
    allies = [e["id"] for e in d.get("initial_units") or [] if e.get("faction") == "ally"]
    slots = {u["slot"] for u in (d.get("recommended") or {}).get("units") or []}
    for w in obj.get("win") or []:
        if w.get("type") == "survive" and not w.get("target") and allies:
            w["target"] = allies[0]
        if w.get("type") == "reach_zone" and w.get("target") in slots:
            w["target"] = "any_ally"      # 自由编队没有固定槽位：「任一我方单位到达」
            w.pop("_target_note", None)
    if not obj.get("lose"):
        obj["lose"] = [{"id": "lose_all_dead", "type": "all_allies_dead"}]
    # 原型要求恰好 4 条提示（D05）：分层提示优先，不足用机制说明 / 目标 / 推荐思路补齐
    hint = (d.get("briefing") or {}).get("mechanic_hint", "")
    hints = [t["text"] for t in d.get("hint_tiers") or [] if t.get("text")]
    for x in (hint, obj.get("objective_text", ""), str((d.get("verification") or {}).get("expected_win", "")),
              "实在过不去时，可以先摆放推荐阵型看看思路。"):
        if len(hints) < 4 and x and x not in hints:
            hints.append(x)
    d["hints"] = hints[:4]
    # 失败反馈：每条 lose 条件一段文字（D05）
    fb = dict(d.get("fail_feedback") or {})
    for lo in obj.get("lose") or []:
        if lo["id"] in fb:
            continue
        if lo["type"] == "all_allies_dead":
            fb[lo["id"]] = "全员倒下了。" + hint
        elif lo["type"] == "reach_zone":
            fb[lo["id"]] = "目标跑到出口了。时间要花在赶路上——先到能盯住它的位置。"
        elif lo["type"] == "unit_dead":
            fb[lo["id"]] = "要保护的单位倒下了。别让敌人先找上它。"
        else:
            fb[lo["id"]] = hint
    fb.setdefault("default", hint)
    d["fail_feedback"] = fb
    d["scene"] = {"backdrop": REGION[d["region"]][3], "playfield_rect": None,
                  "_note": "区域局内地图（2026-10-18）：整张底图 + 程序发光格线，不铺地面贴图"}
    d["biome"] = GAME_BIOME.get(d.get("biome"), d.get("biome"))
    d["bgm"] = REGION_BGM[d["region"]]
    (d.get("grid") or {}).pop("empty", None)
    for k in [k for k in d if k in ("_campaign_from", "_layout_shift", "_zone_locked", "_beacon_route_note", "_reach_note")]:
        d.pop(k)
    for k in TEXT_KEYS:
        if k in d:
            d[k] = strip_md(d[k])
    return d


def needs(d: dict) -> dict:
    al = d.get("allowed") or {}
    forms = set(d["roster"].get("available_forms") or [])
    return {"forms": forms, "conditions": set(al.get("conditions") or []),
            "selectors": set(al.get("selectors") or []), "actions": set(al.get("actions") or [])}


def build_rewards(levels: list[dict]) -> None:
    have = {k: set(INITIAL[k]) for k in ("forms", "conditions", "selectors", "actions")}
    have_presets = set(INITIAL["presets"])
    for i, d in enumerate(levels):
        rw = d.setdefault("rewards", {})
        for k in ("unlock_forms", "unlock_presets", "unlock_conditions", "unlock_selectors", "unlock_actions"):
            rw[k] = []
        rw.pop("unlock_level", None)
        if i + 1 < len(levels):
            rw["unlock_level"] = levels[i + 1]["id"]
    for i, d in enumerate(levels):
        need = needs(d)
        giver = levels[i - 1]["rewards"] if i > 0 else None
        for k in ("forms", "conditions", "selectors", "actions"):
            miss = sorted(need[k] - have[k])
            if not miss:
                continue
            if giver is None:
                raise SystemExit(f"{d['id']} 需要 {k} {miss}，但它是第一关，初始解锁里没有")
            giver["unlock_" + k] += miss
            have[k] |= set(miss)
            if k != "forms":
                for cid in miss:
                    key = unlock_key(k, cid)
                    if key and key not in have_presets:
                        giver["unlock_presets"].append(key)
                        have_presets.add(key)
    # commands.json 里每个 unlock_key 都要能在某处解锁（D 校验）；新键在第一次用到它的前一关给出
    used = set()
    for d in levels:
        used |= set(d["rewards"]["unlock_presets"])
    for kind in ("conditions", "selectors", "actions", "filters"):
        for x in COMMANDS.get(kind, []):
            key = x.get("unlock_key", "")
            if key and key not in have_presets and key not in used:
                levels[0]["rewards"]["unlock_presets"].append(key)
                used.add(key)


def build_chapter(levels: list[dict]) -> dict:
    nodes = []
    n = len(levels)
    for i, d in enumerate(levels):
        x = 170 + int(i * (3240 - 340) / (n - 1))
        y = [760, 600, 700, 470, 620, 360][i % 6]
        r = REGION[d["region"]]
        node = {"level": d["id"], "region": d["region"], "pos": [x, y],
                "links": [levels[i + 1]["id"]] if i + 1 < n else [], "node_art": r[2]}
        if i == n - 1:
            node["boss"] = True
        nodes.append(node)
    return {
        "schema_version": 1,
        "_comment": "30 关战役（2026-10-12 评审后版本，由 tools/import_campaign.py 生成）。地图暂借第一章宽图；节点坐标为临时值，等章节美术。",
        "id": "chapter_02",
        "title": "人工神灵 · 战役",
        "map": "res://assets/ui/chapter/map_chapter_01_low_noise.png",
        "map_size": [3240, 1080],
        "regions": [{"id": r[0], "title": r[1]} for r in REGIONS],
        "nodes": nodes,
    }


def main() -> int:
    src = Path(sys.argv[1])
    files = sorted(glob.glob(str(src / "level_*.json")))
    assert len(files) == 30, f"应为 30 关，实际 {len(files)}"
    levels = [convert(json.load(open(p, encoding="utf-8")), i + 1) for i, p in enumerate(files)]
    build_rewards(levels)
    out = DATA / "levels"
    for d in levels:
        json.dump(d, open(out / f"{d['id']}.json", "w", encoding="utf-8", newline="\n"), ensure_ascii=False, indent=2)
    json.dump(build_chapter(levels), open(DATA / "chapters" / "chapter_02.json", "w", encoding="utf-8", newline="\n"),
              ensure_ascii=False, indent=2)
    prog_p = DATA / "progression.json"
    raw = open(prog_p, encoding="utf-8").read()
    if '"level_c01"' not in raw:
        raw = raw.replace('"initial_levels": ["level_01"]', '"initial_levels": ["level_01", "level_c01"]')
        assert '"level_c01"' in raw, "progression.json initial_levels 格式变了，请手工追加 level_c01"
        open(prog_p, "w", encoding="utf-8", newline="\n").write(raw)
    for d in levels:
        rw = d["rewards"]
        got = {k: v for k, v in rw.items() if k.startswith("unlock_") and v and k != "unlock_level"}
        if got:
            print(f"  {d['id']} 通关解锁：{got}")
    print(f"导入 {len(levels)} 关 → data/levels/level_c01..c30.json；章节 → data/chapters/chapter_02.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
