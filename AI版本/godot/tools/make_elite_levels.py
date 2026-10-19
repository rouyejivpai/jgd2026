#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""生成四个精英关 data/levels/level_e01..e04.json（2026-10-19）。改数值改这里再重跑；推荐解 / 反例用 tools/elite_probe.gd 验证。
精英关 = 章节地图上的支线节点（chapter_02），在某区域最后一关通关后开放，难度高于同区域，通关奖励一枚遗物（data/relics.json）：
  e01 剔骨坊（织骸工坊之后）→ 骨刃     e02 灰棘祭坛（灰棘林之后）→ 徽章
  e03 冷焰沼（肉巢沼泽之后）→ 提灯     e04 断臂回廊（畸变回廊之后）→ 骨臂
用法（在 godot/ 目录）：python tools/make_elite_levels.py
"""
import io
import json
import sys
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
ROOT = Path(__file__).resolve().parent.parent / "data" / "levels"


# ---- 指令简写 ----
def c_in_range():
    return {"type": "enemy_in_range"}


def c_visible():
    return {"type": "enemy_visible"}


def c_at(b):
    return {"type": "at_beacon", "beacon": str(b)}


def c_hp_below(r):
    return {"type": "self_hp_below", "ratio": r}


def attack(sel="nearest", flt="unit", conds=None):
    return {"conditions": conds if conds is not None else [c_in_range()], "target": {"selector": sel, "filter": flt}, "action": {"type": "attack"}}


def chase(sel="nearest", flt="unit", conds=None):
    return {"conditions": conds if conds is not None else [c_visible()], "target": {"selector": sel, "filter": flt}, "action": {"type": "chase_attack"}}


def follow(mode="once", conds=None, frm=None):
    a = {"type": "follow_beacons", "mode": mode}
    if frm:
        a["from"] = str(frm)
    return {"conditions": conds or [], "action": a}


def wait(beacon, seconds):
    return {"conditions": [c_at(beacon)], "action": {"type": "wait", "seconds": seconds}}


def idle():
    return {"conditions": [], "action": {"type": "idle"}}


def beacons(*cells):
    return [{"id": str(i + 1), "cell": list(c)} for i, c in enumerate(cells)]


def wall(cells):
    return [list(c) for c in cells]


def col(x, ys):
    return [(x, y) for y in ys]


def row(y, xs):
    return [(x, y) for x in xs]


VISION = {"striker": 9, "bulwark": 9, "swift": 10, "lancer": 10, "hexer": 10, "binder": 9}


def vision_mods(forms, enemy_forms=()):
    out = []
    for f in list(enemy_forms) + list(forms):
        if f in VISION:
            out.append({"target": f"form:{f}", "stat": "vision", "mul": 0, "add": VISION[f], "_design_vision": True})
    return out


def enemy(id_, unit, pos, name, overrides=None, rules=None, text=None):
    e = {"id": id_, "unit": unit, "faction": "enemy", "pos": list(pos), "display_name": name}
    if overrides:
        e["overrides"] = overrides
    if rules is not None:
        e["rules"] = rules
    if text:
        e["public_rule_text"] = text
    return e


def level(**k):
    lid = k["id"]
    rec_units = k["recommended"]
    hints = [k["mechanic_hint"], k["objective_text"], k["expected_win"], "实在过不去时，可以先摆放推荐阵型看看思路。"]
    d = {
        "schema_version": 1,
        "id": lid,
        "index": k["index"],
        "display_index": k["display_index"],
        "elite": True,
        "title": k["title"],
        "subtitle": k["subtitle"],
        "summary": k["subtitle"],
        "region": k["region"],
        "region_cn": k["region_cn"],
        "chapter": "chapter_02",
        "biome": k["biome"],
        "bgm": k["bgm"],
        "seed": k["seed"],
        "grid": {"width": k["w"], "height": k["h"], "blocked": wall(k["blocked"]), "tiles": {kk: wall(v) for kk, v in k.get("tiles", {}).items()}},
        "deploy_zone": {"rect": k["deploy"]},
        "roster": {"mode": "free", "budget": k["budget"], "available_forms": k["forms"], "max_units": k["max_units"], "min_units": 1, "fixed_slots": [],
                   "beacon_cost": 1, "beacon_bundle": 5, "_beacon_note": "1 Cost 买 5 个信标，全场共用这一个池"},
        "initial_units": k["enemies"],
        "routes": k.get("routes", {}),
        "allowed": k["allowed"],
        "modifiers": vision_mods(k["forms"], k.get("enemy_vision_forms", ())),
        "recommended": {"units": rec_units},
        "objectives": {"objective_text": k["objective_text"], "win": k["win"], "lose": k.get("lose", [{"id": "lose_all_dead", "type": "all_allies_dead"}])},
        "briefing": {"mechanic_hint": k["mechanic_hint"]},
        "hints": hints,
        "fail_feedback": {"lose_all_dead": "全员倒下了。" + k["mechanic_hint"], "default": k["mechanic_hint"]},
        "verification": {"expected_win": k["expected_win"], "expected_fail": k["expected_fail"], "alternatives": k.get("alternatives", []),
                         "risks": [], "_engine_check": "tools/elite_probe.gd（tools/elite_scenarios.json）无头实跑"},
        "scene": {"backdrop": k["backdrop"], "ground": k["ground"], "ground_tint": k["tint"], "playfield_rect": None},
        "rewards": {"unlock_forms": [], "unlock_presets": [], "unlock_conditions": [], "unlock_selectors": [], "unlock_actions": [], "unlock_level": "",
                    "unlock_relics": [k["relic"]]},
        "_design_comment": k["design"],
    }
    return d


LEVELS = []

# ---------------------------------------------------------------- e01 剔骨坊 → 骨刃
# 织骸工坊之后（c06 通关开放）。考的是第一区的两课合起来：「谁当最远的那个」（骨喉）+「远射隔着守卫点后排」（远射形态 / 最远选敌）。
# 中墙只在中段留缺口；两名剔骨匠守缺口、视野短；骨喉在最后方朝最远的分裂体吐骨浆。
LEVELS.append(level(
    id="level_e01", index=201, display_index=1, title="剔骨坊", subtitle="守卫在前，骨喉在后", region="bone_workshop", region_cn="织骸工坊",
    biome="bone_farm", bgm="region_bone_workshop", seed=20101, relic="bone_blade",
    w=16, h=9,
    blocked=col(8, [0, 1, 2]) + col(8, [6, 7, 8]),
    deploy=[0, 2, 2, 6],
    budget=13, max_units=3, forms=["striker", "swift", "bulwark", "lancer"],
    enemies=[
        enemy("G1", "bone_guard", (10, 5), "剔骨匠·上", {"max_hp": 125, "attack": 11, "vision": 5}),
        enemy("G2", "bone_guard", (10, 3), "剔骨匠·下", {"max_hp": 125, "attack": 11, "vision": 5}),
        enemy("S1", "spitter", (14, 4), "骨喉", {"max_hp": 170, "vision": 16}),
    ],
    allowed={"conditions": ["always", "enemy_in_range", "enemy_visible", "at_beacon"], "selectors": ["nearest", "farthest", "lowest_hp", "highest_max_hp"],
             "actions": ["attack", "chase_attack", "follow_beacons", "wait", "idle"]},
    win=[{"id": "win_annihilate", "type": "annihilate"}],
    objective_text="清掉剔骨坊里的全部敌人。两名剔骨匠守着中墙缺口，骨喉在最后方朝视野内最远的分裂体吐骨浆（落点射程 12 格）。",
    mechanic_hint="承伤形态顶在缺口前拖住剔骨匠；远射形态站在快速形态前面打；快速形态在后场 12 格以内来回绕圈，当那个「最远的人」替大家挨骨浆。",
    expected_win="",
    expected_fail=["三人一起冲缺口：没人当最远的那个，骨浆砸在人堆里，打不完骨喉。"],
    alternatives=["冲锋阵容 + 遗物骨刃：骨刃两刀补掉骨喉，可以翻盘（遗物对照）。"],
    recommended=[],
    backdrop="res://assets/backdrops/level_01.png", ground="res://assets/grounds/bone_farm_a.png", tint="#c8b8b0",
    design="精英关 1：把第一区的「诱导骨浆」和「远射点后排」放进同一张图，预算只够三人各司其职。",
))

# ---------------------------------------------------------------- e02 灰棘祭坛 → 徽章
# 灰棘林之后（c14 通关开放）。易伤反制：髓块命中施加易伤，祭坛两侧是腐地；净化台在我方半场。咒术师给髓块上易伤，承伤站台。
LEVELS.append(level(
    id="level_e02", index=202, display_index=2, title="灰棘祭坛", subtitle="先清侍从，再磨髓块", region="grey_thorn", region_cn="灰棘林",
    biome="bone_greenhouse", bgm="region_grey_thorn", seed=20202, relic="badge",
    w=17, h=11,
    blocked=col(9, [0, 1, 2, 8, 9, 10]),
    tiles={"hazard": col(7, range(0, 11)), "shrine": [(4, 5)]},
    deploy=[0, 3, 2, 7],
    budget=13, max_units=3, forms=["bulwark", "striker", "lancer", "hexer", "swift"],
    enemies=[
        enemy("M1", "marrow_hulk", (12, 5), "祭坛髓块", {"max_hp": 300, "attack": 18, "vision": 9, "move_speed": 0.9},
              rules=[attack("lowest_hp"), chase("lowest_hp")], text="近战命中施加易伤。追击并攻击视野内血量最低的分裂体。"),
        enemy("H1", "husk", (13, 7), "残骸侍从·上", {"max_hp": 70, "attack": 8, "vision": 9}, rules=[attack("first_seen"), chase("first_seen"), idle()],
              text="锁定首个进入视野的分裂体并追击攻击。"),
        enemy("H2", "husk", (13, 3), "残骸侍从·下", {"max_hp": 70, "attack": 8, "vision": 9}, rules=[attack("first_seen"), chase("first_seen"), idle()],
              text="锁定首个进入视野的分裂体并追击攻击。"),
    ],
    enemy_vision_forms=(),
    allowed={"conditions": ["always", "enemy_in_range", "at_beacon"], "selectors": ["nearest", "farthest", "lowest_hp", "highest_max_hp"],
             "actions": ["attack", "follow_beacons", "wait", "idle"]},
    win=[{"id": "win_annihilate", "type": "annihilate"}],
    objective_text="清掉灰棘祭坛的守卫。髓块打中谁谁就易伤，两个侍从跟着咬人；绿色三角是净化台，我方站上去立刻清掉异常。",
    mechanic_hint="先清侍从：所有人打最近的目标，咒术师的易伤让侍从和髓块都更脆；承伤形态诱敌后退回净化台站住，髓块标上的易伤会被立刻清掉。",
    expected_win="",
    expected_fail=["不带咒术师（换基础攻击形态）：没有易伤，输出不够，髓块磨死全队。", "所有人集火血最厚的髓块：侍从一直在咬人，后排先倒。"],
    alternatives=["不站净化台、退回部署区也能险胜（约 22 秒），远射形态会掉血。", "不带咒术师 + 遗物徽章（给承伤形态回两次血）可以赢。"],
    recommended=[],
    backdrop="res://assets/backdrops/level_03.png", ground="res://assets/grounds/bone_farm_a.png", tint="#b090b8",
    design="精英关 2：c12「回流」的升级版，多了侍从与咒术师，考易伤的「互相施加」。",
))

# ---------------------------------------------------------------- e03 冷焰沼 → 提灯
# 肉巢沼泽之后（c22 通关开放）。骸猎犬会逃，泥沼（缓滞带）里谁都慢；把猎犬逼进泥沼再追。
LEVELS.append(level(
    id="level_e03", index=203, display_index=3, title="冷焰沼", subtitle="把猎犬赶进泥里", region="flesh_swamp", region_cn="肉巢沼泽",
    biome="hound_den", bgm="region_flesh_swamp", seed=20303, relic="lantern",
    w=17, h=11,
    blocked=[],
    tiles={"mire": [(x, y) for x in range(12, 17) for y in range(0, 11)]},
    deploy=[0, 3, 2, 7],
    budget=13, max_units=4, forms=["striker", "swift", "bulwark", "lancer"],
    routes={"rush_top": {"name": "上路", "points": [[8, 8], [3, 6]]}, "rush_bot": {"name": "下路", "points": [[8, 2], [3, 4]]},
            "rush_mid": {"name": "中路", "points": [[3, 5]]}},
    enemies=[
        enemy("D1", "hound", (9, 8), "冷焰猎犬·一", {"max_hp": 150, "attack": 12}, rules=[{"conditions": [c_hp_below(0.4)], "action": {"type": "retreat", "search_depth": 3}}, attack("nearest"), {"conditions": [], "action": {"type": "follow_route", "route_id": "rush_top"}}], text="沿路线直扑部署区，咬住射程内最近的分裂体；血量低于 40% 时朝远离威胁的方向逃跑（多半逃进泥沼）。"),
        enemy("D2", "hound", (9, 2), "冷焰猎犬·二", {"max_hp": 150, "attack": 12}, rules=[{"conditions": [c_hp_below(0.4)], "action": {"type": "retreat", "search_depth": 3}}, attack("nearest"), {"conditions": [], "action": {"type": "follow_route", "route_id": "rush_bot"}}], text="沿路线直扑部署区，咬住射程内最近的分裂体；血量低于 40% 时朝远离威胁的方向逃跑（多半逃进泥沼）。"),
        enemy("D3", "hound", (11, 5), "冷焰猎犬·三", {"max_hp": 150, "attack": 12}, rules=[{"conditions": [c_hp_below(0.4)], "action": {"type": "retreat", "search_depth": 3}}, attack("nearest"), {"conditions": [], "action": {"type": "follow_route", "route_id": "rush_mid"}}], text="沿路线直扑部署区，咬住射程内最近的分裂体；血量低于 40% 时朝远离威胁的方向逃跑（多半逃进泥沼）。"),
        enemy("W1", "bone_weaver", (15, 5), "织骨者", {"max_hp": 120}),
    ],
    allowed={"conditions": ["always", "enemy_in_range", "enemy_visible", "at_beacon"], "selectors": ["nearest", "farthest", "lowest_hp"],
             "actions": ["attack", "chase_attack", "follow_beacons", "idle"]},
    win=[{"id": "win_annihilate", "type": "annihilate"}],
    objective_text="清掉冷焰沼里的三只猎犬和织骨者。猎犬沿路线直扑部署区，咬到血量低于四成就逃进右边泥沼（泥沼里移速减半）。",
    mechanic_hint="承伤形态顶在前面挨咬，基础攻击形态在旁边补刀；远射形态打血最少的猎犬，等它们逃进泥沼后追过去逐个点掉，别贴进织骨者的减速光环。",
    expected_win="",
    expected_fail=["没有承伤形态（两个基础攻击 + 快速形态）：三只猎犬同时扑上来，7 秒内团灭。"],
    alternatives=["承伤 + 两个基础攻击形态都用追击指令也能惨胜（约 44 秒），最后只剩一人。", "遗物提灯：在部署区前方放冷焰地块，猎犬冲锋被减速，可以多打几轮。"],
    recommended=[],
    backdrop="res://assets/backdrops/level_04.png", ground="res://assets/grounds/hound_den_a.png", tint="#a0b0c8",
    design="精英关 3：猎犬撤离 + 缓滞带 + 织骨者光环，三个「慢」叠在一起。",
))

# ---------------------------------------------------------------- e04 断臂回廊 → 骨臂
# 畸变回廊之后（c26 通关开放）。血极厚的断臂巨像（髓块）+ 两具骨花核心的延迟爆炸；不给巨像上易伤就磨不死。
LEVELS.append(level(
    id="level_e04", index=204, display_index=4, title="断臂回廊", subtitle="别挤在一起", region="warped_corridor", region_cn="畸变回廊",
    biome="transit_node", bgm="region_warped_corridor", seed=20404, relic="bone_arm",
    w=19, h=11,
    blocked=row(3, range(6, 13)) + row(7, range(6, 13)),
    deploy=[0, 3, 2, 7],
    budget=17, max_units=4, forms=["striker", "swift", "bulwark", "lancer", "hexer"],
    enemies=[
        enemy("B1", "marrow_hulk", (14, 5), "断臂巨像", {"max_hp": 540, "attack": 14, "vision": 10, "move_speed": 0.6},
              rules=[attack("lowest_hp"), chase("lowest_hp")], text="近战命中施加易伤。追击并攻击视野内血量最低的分裂体。血极厚。"),
        enemy("C1", "bone_core", (17, 9), "骨花核心·上", {"max_hp": 90, "vision": 10}),
        enemy("C2", "bone_core", (17, 1), "骨花核心·下", {"max_hp": 90, "vision": 10}),
    ],
    allowed={"conditions": ["always", "enemy_in_range", "at_beacon", "self_hp_below"], "selectors": ["nearest", "farthest", "highest_max_hp", "lowest_hp"],
             "actions": ["attack", "follow_beacons", "wait", "idle"]},
    win=[{"id": "win_boss", "type": "destroy", "targets": ["B1"]}],
    objective_text="击倒断臂巨像。它血极厚、打谁谁易伤；两角的骨花核心会朝视野内（10 格）最远的人投下花粉爆裂（半径 2 格）。",
    mechanic_hint="别扎堆：只让承伤形态进入骨花核心的视野去顶巨像，远射形态和咒术师在后面拉开距离输出，花粉爆裂就只会砸在一个人身上。",
    expected_win="",
    expected_fail=["四人一起挤到 (9, 4..6)：两颗花粉爆裂同时落在人堆里，9 秒内倒下三人。"],
    alternatives=["咒术师换成基础攻击形态也能险胜（约 26 秒）。", "遗物骨臂：在巨像脚下放诅咒地块，巨像持续易伤，十几秒就能击倒。"],
    recommended=[],
    backdrop="res://assets/backdrops/level_07.png", ground="res://assets/grounds/transit_node_a.png", tint="#b8a8c0",
    design="精英关 4：高血量巨像 + 两颗朝「最远者」投弹的骨花核心，考站位分散；骨臂（易伤地块）在这里效果最明显。",
))


def main():
    rec = json.loads((Path(__file__).resolve().parent / "elite_recommended.json").read_text(encoding="utf-8"))
    for d in LEVELS:
        r = rec.get(d["id"], {})
        d["recommended"]["units"] = r.get("units", [])
        d["verification"]["expected_win"] = r.get("expected_win", "")
        d["hints"][2] = d["verification"]["expected_win"] or d["hints"][2]
        (ROOT / f"{d['id']}.json").write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
        print("wrote", d["id"], d["title"])


if __name__ == "__main__":
    main()
