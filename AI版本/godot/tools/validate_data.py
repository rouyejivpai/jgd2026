#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
离线数据校验：对 data/units.json、traits.json、commands.json（第三阶段取代 presets.json）、levels/*.json 执行 02_数据规格.md §7 的 D01–D08 检查。
用法（在 godot/ 目录下）：  python tools/validate_data.py
退出码 0 = 全部通过；1 = 有错误。错误逐条打印，格式 [文件] 说明。
执行方在每次修改 data/ 后必须运行；DataRegistry 的 GDScript 校验与此脚本语义一致。
"""
import json
import re
import sys
import io
from collections import deque
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent / "data"

CONDITIONS = {"always", "self_hp_below", "enemy_visible", "enemy_in_range", "target_distance", "retreat_possible", "at_beacon", "signal_is"}
SELECTORS = {"nearest", "farthest", "lowest_hp", "first_seen", "highest_max_hp", "highest_hp", "most_damage", "first_in_range"}
FILTERS = {"any", "unit", "structure"}
ACTIONS = {"idle", "attack", "chase_attack", "chase", "retreat", "follow_route", "follow_beacons", "wait", "hold_fire"}
ATTACK_GROUP_ACTIONS = {"attack", "hold_fire"}   # 第五阶段：攻击组；其余为移动组（chase_attack 为旧数据，两组都算）
UNGATED_ACTIONS = {"follow_beacons", "wait", "idle", "hold_fire"}   # 07 §3 通用工具：不受形态 allowed_actions 限制（Q-047）；第五阶段追加 停止 / 停火
BEACON_LETTERS = "ABCDEFGH"   # 10 §6.3：只用于识别旧字母并报 DEPRECATED_FIELD
BEACON_SOFT_CAP = 64


def beacon_id_ok(ctx, b, what):
    """10 §6.3：信标编号必须是正整数字符串（"1"、"2"…，无前导零）；旧字母 A–H 报 DEPRECATED_FIELD。"""
    if isinstance(b, str) and b.isdigit() and int(b) >= 1 and str(int(b)) == b:
        return True
    if isinstance(b, str) and len(b) == 1 and b in BEACON_LETTERS:
        err(ctx, f"DEPRECATED_FIELD {what} 使用旧字母信标 '{b}'，请改为数字编号 {BEACON_LETTERS.index(b) + 1}")
    else:
        err(ctx, f"{what} 必须是正整数信标编号（\"1\"、\"2\"…），实际为 {b!r}")
    return False
BEACON_MODES = {"once", "loop", "pingpong"}
ACTIONS_NEED_TARGET = {"attack", "chase_attack", "chase"}
TRAIT_TYPES = {"delayed_blast", "status", "on_hit_status", "aura_status", "tile_effect", "phased_boss"}
SIGNALS = {"red", "yellow", "blue"}   # signal_is.signal（30 关战役 Boss）
OBJ_WIN = {"annihilate", "destroy", "survive", "reach_zone", "escort"}   # 07 §9：reach_zone 可作胜利；escort 护送
MOD_STATS = {"max_hp", "attack", "attack_speed", "move_speed", "vision", "range"}
OBJ_LOSE = {"unit_dead", "all_allies_dead", "reach_zone"}
FACTIONS = {"ally", "enemy", "neutral"}
KINDS = {"unit", "structure"}
SPEAKERS = {"doll", "witch", "narrator", "system"}

errors = []
warnings = []


def err(ctx, msg):
    errors.append(f"[{ctx}] {msg}")


def warn(ctx, msg):
    warnings.append(f"[{ctx}] {msg}")


def load(name):
    p = ROOT / name
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception as e:  # noqa
        err(name, f"JSON 解析失败: {e}")
        return None


TEACH_TARGET_KINDS = {"none", "ui", "cell", "cells", "deploy_zone", "unit", "ally"}
TEACH_ADVANCES = {"next", "click", "event"}
TEACH_EVENTS = {"deployed", "ally_selected", "enemy_selected", "beacon_placed", "beacon_mode", "rules_changed", "battle_started"}
TEACH_ARROWS = {"auto", "up", "down", "left", "right", "none"}
TEACH_PANELS = {"auto", "left", "right", "top", "bottom", "center"}
TEACH_OVERRIDES = ("allowed", "rewards", "hints", "mechanic_hint", "roster", "deploy_zone", "initial_units", "objectives", "modifiers")
TEACH_STYLE = {"dim_color", "highlight_color", "highlight_width", "hole_pad", "arrow_size", "arrow_gap", "arrow_bob", "arrow_bob_hz", "panel_width", "panel_margin"}


def apply_teaching_overrides(L, entry):
    """第五阶段：teaching.json 覆盖关卡字段（与 TeachingDef.apply_overrides 同口径）"""
    if not entry:
        return L
    L = json.loads(json.dumps(L))
    for key in ("allowed", "rewards", "roster", "objectives"):
        if isinstance(entry.get(key), dict):
            merged = dict(L.get(key) or {})
            merged.update(entry[key])
            L[key] = merged
    for key in ("deploy_zone", "initial_units", "modifiers"):
        if key in entry:
            L[key] = json.loads(json.dumps(entry[key]))
    if isinstance(entry.get("hints"), list):
        L["hints"] = list(entry["hints"])
    if isinstance(entry.get("mechanic_hint"), str):
        L.setdefault("briefing", {})["mechanic_hint"] = entry["mechanic_hint"]
    return L


def check_teaching(doc, level_docs):
    """第五阶段 data/teaching.json：字段与枚举、第七关冻结、目标地块 / 预置单位存在"""
    ctx = "teaching.json"
    for k in (doc.get("style") or {}):
        if k not in TEACH_STYLE:
            err(ctx, f"style 未知字段 {k}")
    for lid, e in (doc.get("levels") or {}).items():
        lctx = f"{ctx}:levels.{lid}"
        L = level_docs.get(lid)
        if L is None:
            err(lctx, "关卡不存在"); continue
        for k in e:
            if k not in ("test", "tutorial", "_comment") + TEACH_OVERRIDES:
                err(lctx, f"未知字段 {k}")
        if lid == "level_07" and any(k in e for k in TEACH_OVERRIDES):
            err(lctx, "第七关数据冻结，只允许配置引导")
        if "hints" in e and (not isinstance(e["hints"], list) or len(e["hints"]) != 4):
            err(lctx, "hints 覆盖必须恰好 4 条 (D05)")
        for k, typ in (("roster", dict), ("objectives", dict), ("deploy_zone", dict), ("initial_units", list), ("modifiers", list)):
            if k in e and not isinstance(e[k], typ):
                err(lctx, f"{k} 覆盖类型错误（应为 {'对象' if typ is dict else '数组'}）")
        if "mechanic_hint" in e and not (isinstance(e["mechanic_hint"], str) and e["mechanic_hint"]):
            err(lctx, "mechanic_hint 覆盖必须是非空字符串")
        w, h = L.get("grid", {}).get("width", 0), L.get("grid", {}).get("height", 0)
        spawns = {u.get("id") for u in L.get("initial_units", [])}
        for i, st in enumerate((e.get("tutorial") or {}).get("steps", [])):
            sctx = f"{lctx}.tutorial.steps[{i}]"
            if not isinstance(st.get("text"), str) or not st["text"]:
                err(sctx, "text 必填")
            adv = st.get("advance", "next")
            if adv not in TEACH_ADVANCES:
                err(sctx, f"advance 非法: {adv}")
            if adv == "event" and st.get("event") not in TEACH_EVENTS:
                err(sctx, f"event 非法: {st.get('event')}")
            if st.get("arrow", "auto") not in TEACH_ARROWS:
                err(sctx, "arrow 非法")
            if st.get("panel", "auto") not in TEACH_PANELS:
                err(sctx, "panel 非法")
            if st.get("phase", "deploy") not in ("deploy", "running"):
                err(sctx, "phase 必须是 deploy / running")
            targets = st.get("targets", [])
            if adv == "click" and not any(t.get("kind") != "none" for t in targets):
                err(sctx, "advance = click 需要高亮目标")
            for t in targets:
                k = t.get("kind")
                if k not in TEACH_TARGET_KINDS:
                    err(sctx, f"target.kind 非法: {k}")
                if k == "ui" and not t.get("node"):
                    err(sctx, "ui 目标需要 node")
                cells = [t.get("cell")] if k == "cell" else (t.get("cells") or []) if k == "cells" else []
                if k == "cells" and not cells:
                    err(sctx, "cells 不能为空")
                for c in cells:
                    if not (isinstance(c, list) and len(c) == 2 and 0 <= c[0] < w and 0 <= c[1] < h):
                        err(sctx, f"地块 {c} 越界或格式错误")
                if k == "unit" and t.get("spawn") not in spawns:
                    err(sctx, f"预置单位 '{t.get('spawn')}' 不存在")


def expand_allowed(actions):
    """第五阶段：允许 chase_attack（旧数据）即视为允许 追击 + 攻击"""
    out = set(actions)
    if "chase_attack" in out:
        out.update({"chase", "attack"})
    return out


def check_rule(rule, ctx, routes=None, unit_allowed_actions=None, beacon_ids=None):
    if not isinstance(rule, dict):
        err(ctx, "规则不是对象"); return
    mode = rule.get("condition_mode", "all")
    if mode not in ("all", "any"):
        err(ctx, f"condition_mode 非法: {mode}")
    if not isinstance(rule.get("override", False), bool):
        err(ctx, "override 必须是 true / false（第四阶段「覆盖」）")
    conds = rule.get("conditions")
    if not isinstance(conds, list):
        err(ctx, "缺少 conditions 数组"); conds = []
    for i, c in enumerate(conds):
        t = c.get("type")
        if t not in CONDITIONS:
            err(ctx, f"条件[{i}] type 非法: {t}")
        if t == "self_hp_below" and not (0 < float(c.get("ratio", -1)) <= 1):
            err(ctx, f"条件[{i}] self_hp_below.ratio 必须在 (0,1]")
        if t == "target_distance":
            if c.get("op") not in ("<", ">"):
                err(ctx, f"条件[{i}] target_distance.op 必须是 '<' 或 '>'")
            if "value" not in c:
                err(ctx, f"条件[{i}] target_distance 缺少 value")
        if t == "signal_is" and c.get("signal") not in SIGNALS:
            err(ctx, f"条件[{i}] signal_is.signal 必须是 {sorted(SIGNALS)} 之一")
        if t == "at_beacon":
            b = c.get("beacon", "")
            if not beacon_id_ok(ctx, b, f"条件[{i}] at_beacon.beacon"):
                pass
            elif beacon_ids is not None and rule.get("enabled", True) and b not in beacon_ids:
                err(ctx, f"条件[{i}] at_beacon 引用的信标 {b} 不存在 (BEACON_MISSING)")
    action = rule.get("action")
    if not isinstance(action, dict) or action.get("type") not in ACTIONS:
        err(ctx, f"action 非法: {action}"); return
    at = action["type"]
    if unit_allowed_actions is not None and at not in unit_allowed_actions and at not in UNGATED_ACTIONS:
        err(ctx, f"行为 {at} 不在该形态 allowed_actions 中")
    target = rule.get("target")
    needs_target = at in ACTIONS_NEED_TARGET or any(c.get("type") == "target_distance" for c in conds)
    if needs_target and not isinstance(target, dict):
        err(ctx, f"行为 {at}/条件需要 target 但缺失")
    if isinstance(target, dict):
        if target.get("selector") not in SELECTORS:
            err(ctx, f"target.selector 非法: {target.get('selector')}")
        if target.get("filter", "any") not in FILTERS:
            err(ctx, f"target.filter 非法: {target.get('filter')}")
    if at == "follow_route":
        rid = action.get("route_id", "")
        if routes is not None and rid not in routes:
            err(ctx, f"follow_route.route_id '{rid}' 不存在于本关 routes")
    if at == "follow_beacons":
        if action.get("mode", "once") not in BEACON_MODES:
            err(ctx, f"follow_beacons.mode 非法: {action.get('mode')}")
        fr = action.get("from", "1")
        if not beacon_id_ok(ctx, fr, "follow_beacons.from"):
            pass
        elif beacon_ids is not None and rule.get("enabled", True) and fr not in beacon_ids:
            err(ctx, f"follow_beacons 引用的信标 {fr} 不存在或没有信标 (BEACON_MISSING/BEACONS_EMPTY)")
    if at == "wait":
        sec = action.get("seconds")
        if not isinstance(sec, (int, float)) or not (0.5 <= sec <= 30):
            err(ctx, "wait.seconds 必须在 0.5–30 之间")


def check_motion_profile(mctx, btn, trans_names, ease_names):
    for key in ("hover_in", "hover_out", "press", "release", "sweep"):
        spec = btn.get(key)
        if not isinstance(spec, dict):
            err(mctx, f"{key} 缺失")
            continue
        d = spec.get("duration")
        if not isinstance(d, (int, float)) or d <= 0:
            err(mctx, f"{key}.duration 必须是正数")
        elif key != "sweep" and d > 0.25:
            warn(mctx, f"{key}.duration {d}s 超过 10 §1.5 建议的 0.25 s")
        if spec.get("trans") not in trans_names:
            err(mctx, f"{key}.trans 非法: {spec.get('trans')}")
        if spec.get("ease") not in ease_names:
            err(mctx, f"{key}.ease 非法: {spec.get('ease')}")
    if not (isinstance(btn.get("press_scale"), (int, float)) and 0.9 <= btn["press_scale"] <= 1.0):
        err(mctx, "press_scale 必须在 [0.9, 1.0]")
    br = btn.get("breathe", {})
    if not (isinstance(br.get("period"), (int, float)) and br["period"] > 0):
        err(mctx, "breathe.period 必须是正数")
    gm = btn.get("gold_mask")
    if not (isinstance(gm, list) and len(gm) == 2 and gm[0] < gm[1]):
        err(mctx, "gold_mask 必须是 [低, 高]")
    for key in ("hover_boost", "hover_lift", "hover_nudge_px", "text_hover_lighten", "text_press_darken"):
        if not (isinstance(btn.get(key), (int, float)) and btn[key] >= 0):
            err(mctx, f"{key} 必须是非负数")
    if not isinstance(btn.get("focus_follows_mouse"), bool):
        err(mctx, "focus_follows_mouse 必须是 true / false")


def check_obstacles(ctx, sc, g, blocked):
    """10 §7（P7，R4）：scene.obstacles 障碍块清单——文件存在、每块 file / cells / anchor_px / size_px 合法、cells 在网格内且 ⊆ blocked"""
    path = sc.get("obstacles", "")
    if not path:
        return
    if not isinstance(path, str) or not path.startswith("res://"):
        err(ctx, "scene.obstacles 必须是 res:// 路径")
        return
    if sc.get("ground"):
        warn(ctx, "DEPRECATED_FIELD 有障碍块清单时 scene.ground 不再平铺（仅作无资源占位）")
    f = ROOT.parent / path[len("res://"):]
    if not f.exists():
        err(ctx, f"障碍块清单不存在：{path}")
        return
    try:
        man = json.loads(f.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        err(ctx, f"障碍块清单 JSON 解析失败：{e}")
        return
    w, h = g.get("width", 0), g.get("height", 0)
    for i, pc in enumerate(man.get("pieces", []) if isinstance(man, dict) else []):
        pctx = f"{ctx} obstacles.pieces[{i}]"
        if not isinstance(pc, dict):
            err(pctx, "必须是对象")
            continue
        if not (f.parent / str(pc.get("file", ""))).exists():
            err(pctx, f"障碍块贴图不存在：{pc.get('file')}")
        cells = pc.get("cells", [])
        if not cells:
            err(pctx, "cells 不能为空")
        for c in cells:
            c = tuple(c) if isinstance(c, list) else c
            if not (isinstance(c, tuple) and len(c) == 2 and 0 <= c[0] < w and 0 <= c[1] < h):
                err(pctx, f"格 {c} 超出网格")
            elif c not in blocked:
                err(pctx, f"格 {list(c)} 不在 grid.blocked 内（障碍块只能放在障碍格上）")
        a, sz = pc.get("anchor_px"), pc.get("size_px")
        if not (isinstance(a, list) and len(a) == 2 and isinstance(sz, list) and len(sz) == 2 and sz[0] > 0 and sz[1] > 0):
            err(pctx, "anchor_px 必须是 [x, y]，size_px 必须是正的 [w, h]")


def bfs_reachable(w, h, blocked, a, b):
    if a == b:
        return True
    q = deque([a]); seen = {a}
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if 0 <= n[0] < w and 0 <= n[1] < h and n not in blocked and n not in seen:
                if n == b:
                    return True
                seen.add(n); q.append(n)
    return False


def main():
    units_doc = load("units.json"); traits_doc = load("traits.json"); commands_doc = load("commands.json"); strings_doc = load("strings.json")
    if None in (units_doc, traits_doc, commands_doc, strings_doc):
        return finish()
    units = units_doc.get("units", {}); traits = traits_doc.get("traits", {})

    # traits
    for tid, t in traits.items():
        ctx = f"traits.json:{tid}"
        if t.get("type") not in TRAIT_TYPES:
            err(ctx, f"type 非法: {t.get('type')}")
        p = t.get("params", {})
        for k in (("damage", "radius", "delay", "cooldown") if t.get("type") == "delayed_blast" else ()):
            if not (isinstance(p.get(k), (int, float)) and p[k] > 0):
                err(ctx, f"params.{k} 必须为正数 (D08)")
        if t.get("type") in ("on_hit_status", "aura_status") and p.get("status") not in traits:
            err(ctx, f"params.status '{p.get('status')}' 不是已定义的状态特性")
        if p.get("selector", "farthest") not in SELECTORS:
            err(ctx, "params.selector 非法")
        if not t.get("public_text"):
            err(ctx, "缺少 public_text")

    # units
    for uid, u in units.items():
        ctx = f"units.json:{uid}"
        for k in ("display_name", "kind", "faction_default", "max_hp", "attack", "attack_speed", "move_speed", "vision", "range", "allowed_actions", "default_rules", "visuals"):
            if k not in u:
                err(ctx, f"缺少必填字段 {k}")
        if u.get("kind") not in KINDS:
            err(ctx, "kind 非法")
        if u.get("faction_default") not in FACTIONS:
            err(ctx, "faction_default 非法")
        if u.get("kind") == "structure" and (u.get("attack_speed", 1) != 0 or u.get("move_speed", 1) != 0):
            err(ctx, "建筑的 attack_speed 与 move_speed 必须为 0 (D07)")
        for tr in u.get("traits", []):
            if tr not in traits:
                err(ctx, f"trait '{tr}' 不存在 (D02)")
        for a in u.get("allowed_actions", []):
            if a not in ACTIONS:
                err(ctx, f"allowed_actions 含非法行为 {a}")
        for i, r in enumerate(u.get("default_rules", [])):
            check_rule(r, f"{ctx}.default_rules[{i}]", routes=None, unit_allowed_actions=expand_allowed(u.get("allowed_actions", [])))
        v = u.get("visuals", {})
        for k in ("sprite", "portrait", "projectile", "light_color"):
            if k not in v:
                err(ctx, f"visuals 缺少 {k}")

    for uid, u in units.items():
        if u.get("faction_default") == "ally" and u.get("kind") == "unit":
            c = u.get("cost")
            if not (isinstance(c, int) and c > 0):
                err(f"units.json:{uid}", "己方形态必须有正整数 cost（07 §4.1）")
    if (ROOT / "presets.json").exists():
        err("presets.json", "第三阶段已删除（10 §5.1），菜单改由 commands.json 提供")

    # commands（10 §5.1）：id 可解析、不重复；cost 非负整数；player 只用于行为；unlock_key 的可追溯性在读完关卡后检查
    command_valid = {"actions": ACTIONS, "conditions": CONDITIONS, "selectors": SELECTORS, "filters": FILTERS}
    command_keys = set()
    for kind, valid in command_valid.items():
        entries = commands_doc.get(kind)
        if not isinstance(entries, list) or not entries:
            err("commands.json", f"缺少非空数组 {kind}"); continue
        seen = set()
        for e in entries:
            cid = e.get("id")
            ctx = f"commands.json:{kind}.{cid}"
            if cid not in valid:
                err(ctx, "id 不是可解析的类型值")
            if cid in seen:
                err(ctx, "id 重复")
            seen.add(cid)
            cost = e.get("cost", 0)
            if not (isinstance(cost, int) and not isinstance(cost, bool) and cost >= 0):
                err(ctx, "cost 必须是非负整数")
            if "player" in e and (kind not in ("actions", "selectors") or not isinstance(e["player"], bool)):
                err(ctx, "player 只用于 actions / selectors，且必须是布尔值")
            if kind == "actions" and e.get("group") not in ("attack", "move"):
                err(ctx, "group 必须是 attack / move（第五阶段）")
            elif kind == "actions" and cid != "chase_attack" and (e.get("group") == "attack") != (cid in ATTACK_GROUP_ACTIONS):
                err(ctx, f"group 与行为类型不符：{cid} 属于 {'attack' if cid in ATTACK_GROUP_ACTIONS else 'move'}")
            key = e.get("unlock_key", "")
            if not isinstance(key, str):
                err(ctx, "unlock_key 必须是字符串（空 = 始终可用）")
            elif key:
                command_keys.add((ctx, key))
            if kind == "actions" and key == "" and cid not in UNGATED_ACTIONS and e.get("player", True):
                err(ctx, "unlock_key 为空的玩家行为只能是信标 / 等待类（Q-047）")
            if kind == "conditions" and key == "" and cid not in ("always", "at_beacon"):
                err(ctx, "unlock_key 为空的条件只能是 always / at_beacon（Q-047）")
            if "defaults" in e and not isinstance(e["defaults"], dict):
                err(ctx, "defaults 必须是对象")
            if kind == "conditions" and isinstance(e.get("defaults"), dict):
                check_rule({"conditions": [dict(e["defaults"], type=cid)], "action": {"type": "idle"},
                            "target": {"selector": "nearest", "filter": "any"}}, ctx + ".defaults", routes=None)
    gl = commands_doc.get("group_limits")
    if not isinstance(gl, dict) or set(gl.keys()) != {"attack", "move"} or not all(isinstance(v, int) and v >= 1 for v in gl.values()):
        err("commands.json", "group_limits 必须是 { attack: 正整数, move: 正整数 }（第五阶段）")
    for i, r in enumerate(commands_doc.get("new_unit_rules", [])):
        check_rule(r, f"commands.json:new_unit_rules[{i}]", routes=None)
    known_unlock_keys = set()

    # biomes（04 §2.5 道具映射）
    biomes = load("biomes.json")
    if biomes is not None:
        props = biomes.get("props", {})
        if "default" not in props:
            err("biomes.json", "props 缺少 default")
        for k, v in props.items():
            if not isinstance(v, str) or not v:
                err("biomes.json", f"props.{k} 必须是非空字符串")
        for key in ("ground_textures", "ground_marks"):
            for k, v in biomes.get(key, {}).items():
                if not isinstance(v, list) or not all(isinstance(x, str) and x for x in v):
                    err("biomes.json", f"{key}.{k} 必须是非空字符串数组")
        if "default" not in biomes.get("ground_marks", {}):
            err("biomes.json", "ground_marks 缺少 default")
        for k, v in biomes.get("level_props", {}).items():
            if not isinstance(v, str) or not v:
                err("biomes.json", f"level_props.{k} 必须是非空字符串")

    # levels
    indices = {}
    level_ids = set(p.stem for p in (ROOT / "levels").glob("level_*.json"))

    # progression（初始解锁，03 §1.3）
    prog = load("progression.json")
    if prog is not None:
        ini = prog.get("initial_unlocks", {})
        ctx = "progression.json"
        for f in ini.get("forms", []):
            if f not in units:
                err(ctx, f"initial_unlocks.forms '{f}' 不存在")
        known_unlock_keys.update(ini.get("presets", []))
        for k, valid in (("conditions", CONDITIONS), ("selectors", SELECTORS), ("actions", ACTIONS)):
            if k not in ini:
                err(ctx, f"initial_unlocks 缺少 {k}")
            for v in ini.get(k, []):
                if v not in valid:
                    err(ctx, f"initial_unlocks.{k} 含非法值 {v}")
        for lid in prog.get("initial_levels", []):
            if lid not in level_ids:
                err(ctx, f"initial_levels '{lid}' 不存在")
    teaching = load("teaching.json") if (ROOT / "teaching.json").exists() else {}
    teaching = teaching or {}
    level_docs = {}
    for path in sorted((ROOT / "levels").glob("level_*.json")):
        L = load(f"levels/{path.name}")
        if L is None:
            continue
        L = apply_teaching_overrides(L, (teaching.get("levels") or {}).get(path.stem, {}))
        level_docs[path.stem] = L
        ctx = path.name
        for k in ("id", "index", "title", "biome", "scene", "grid", "deploy_zone", "roster", "initial_units", "allowed", "objectives", "briefing", "hints", "fail_feedback", "recommended", "rewards", "verification"):
            if k not in L:
                err(ctx, f"缺少必填字段 {k}")
        bgm = L.get("bgm", "")
        if bgm and not (ROOT.parent / "assets" / "audio" / "bgm" / f"{bgm}.mp3").exists():
            err(ctx, f"bgm '{bgm}' 对应的 assets/audio/bgm/{bgm}.mp3 不存在")
        if L.get("rules_format", "legacy") not in ("legacy", "dual"):
            err(ctx, "rules_format 必须是 legacy / dual（第五阶段）")
        if "recommended_deploy" in L:
            err(ctx, "DEPRECATED_FIELD recommended_deploy 已废弃，改用 recommended.units")
        if "background" in L:
            err(ctx, "DEPRECATED_FIELD background 已废弃，改用 scene.backdrop")
        sc = L.get("scene", {})
        if not isinstance(sc.get("backdrop"), str) or not sc.get("backdrop"):
            err(ctx, "scene.backdrop 必须是非空字符串")
        if not isinstance(sc.get("ground", ""), str):
            err(ctx, "scene.ground 必须是字符串")
        if not re.fullmatch(r"#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?", str(sc.get("ground_tint", "#ffffff"))):
            err(ctx, f"scene.ground_tint 不是合法颜色: {sc.get('ground_tint')}")
        pr = sc.get("playfield_rect")
        if pr is not None and not (isinstance(pr, list) and len(pr) == 4 and pr[2] > pr[0] and pr[3] > pr[1]):
            err(ctx, "scene.playfield_rect 必须是 null 或 [x0, y0, x1, y1]")
        for key in ("backdrop", "ground"):
            fpath = sc.get(key, "")
            if isinstance(fpath, str) and fpath.startswith("res://") and not (ROOT.parent / fpath[len("res://"):]).exists():
                warn(ctx, f"scene.{key} 文件不存在（运行时回退占位）：{fpath}")
        if L.get("biome") not in (biomes or {}).get("ground_marks", {}) and "default" not in (biomes or {}).get("ground_marks", {}):
            err(ctx, f"biome '{L.get('biome')}' 在 biomes.json ground_marks 中没有条目且无 default")
        if L.get("id") != path.stem:
            err(ctx, f"id '{L.get('id')}' 与文件名不一致")
        idx = L.get("index")
        if idx in indices:
            err(ctx, f"index {idx} 与 {indices[idx]} 重复 (D06)")
        indices[idx] = path.name
        g = L.get("grid", {}); w, h = g.get("width", 0), g.get("height", 0)
        inb = lambda c: 0 <= c[0] < w and 0 <= c[1] < h  # noqa
        blocked = set(tuple(c) for c in g.get("blocked", []))
        check_obstacles(ctx, sc, g, blocked)
        for c in blocked:
            if not inb(c):
                err(ctx, f"blocked {c} 越界 (D03)")
        # deploy zone
        dz = L.get("deploy_zone", {})
        if "rect" in dz:
            x0, y0, x1, y1 = dz["rect"]
            cells = {(x, y) for x in range(x0, x1 + 1) for y in range(y0, y1 + 1)}
        else:
            cells = set(tuple(c) for c in dz.get("cells", []))
        cells -= set(tuple(c) for c in dz.get("exclude", []))
        if not cells:
            err(ctx, "部署区为空")
        for c in cells:
            if not inb(c):
                err(ctx, f"部署格 {c} 越界 (D03)")
            if c in blocked:
                err(ctx, f"部署格 {c} 与障碍重叠 (D03)")
        # routes
        routes = L.get("routes", {})
        for rid, r in routes.items():
            pts = [tuple(p) for p in r.get("points", [])]
            if not r.get("name"):
                err(ctx, f"路线 {rid} 缺少 name")
            for p in pts:
                if not inb(p) or p in blocked:
                    err(ctx, f"路线 {rid} 路点 {p} 越界或在障碍上 (D03)")
            for a, b in zip(pts, pts[1:]):
                if inb(a) and inb(b) and not bfs_reachable(w, h, blocked, a, b):
                    err(ctx, f"路线 {rid} 路点 {a}->{b} 不可达 (D04)")
        # roster（07 §4.1）
        if "slots" in L:
            err(ctx, "DEPRECATED_FIELD slots 已废弃，改用 roster")
        ro = L.get("roster", {})
        mode = ro.get("mode")
        if mode not in ("fixed", "free"):
            err(ctx, f"roster.mode 非法: {mode}")
        ally_forms = {k for k, v in units.items() if v.get("faction_default") == "ally" and v.get("kind") == "unit"}
        af = ro.get("available_forms")
        if af is not None:
            for f in af:
                if f not in ally_forms:
                    err(ctx, f"roster.available_forms '{f}' 不是己方形态")
        if mode == "free":
            if not (isinstance(ro.get("budget"), int) and ro["budget"] > 0):
                err(ctx, "free 模式 roster.budget 必须为正整数")
            if ro.get("fixed_slots"):
                err(ctx, "free 模式不使用 fixed_slots")
        elif mode == "fixed" and not ro.get("fixed_slots"):
            err(ctx, "fixed 模式需要 fixed_slots")
        mn, mx = ro.get("min_units", 1), ro.get("max_units", len(ro.get("fixed_slots", [])))
        if not (1 <= mn <= mx):
            err(ctx, "roster 需要 1 ≤ min_units ≤ max_units")
        slot_ids = set()
        for s in ro.get("fixed_slots", []):
            sid = s.get("id"); slot_ids.add(sid)
            if s.get("unit") not in units:
                err(ctx, f"槽位 {sid} 的 unit '{s.get('unit')}' 不存在 (D02)")
                continue
            if "rules" in s:
                warn(f"{ctx}:slots.{sid}", "DEPRECATED_FIELD slots[].rules 已废弃并被忽略，推荐指令请写入 recommended.units")
        # initial units
        spawn_ids = set(); spawn_pos = {}
        for su in L.get("initial_units", []):
            sid = su.get("id")
            if sid in spawn_ids:
                err(ctx, f"initial_units id '{sid}' 重复")
            spawn_ids.add(sid)
            if su.get("unit") not in units:
                err(ctx, f"initial_units {sid} 的 unit '{su.get('unit')}' 不存在 (D02)"); continue
            if su.get("faction") not in FACTIONS:
                err(ctx, f"initial_units {sid} faction 非法")
            pos = tuple(su.get("pos", (-1, -1)))
            spawn_pos[sid] = pos
            if not inb(pos) or pos in blocked:
                err(ctx, f"initial_units {sid} 位置 {pos} 越界或在障碍上 (D03)")
            if pos in cells and su.get("faction") == "enemy":
                err(ctx, f"敌方初始单位 {sid} 位于部署区内")
            udef = units[su["unit"]]
            for i, r in enumerate(su.get("rules", [])):
                check_rule(r, f"{ctx}:initial_units.{sid}.rules[{i}]", routes=routes, unit_allowed_actions=expand_allowed(udef.get("allowed_actions", [])))
        # 07 §7 modifiers / 07 §9 overrides
        for m in L.get("modifiers", []):
            tgt = str(m.get("target", ""))
            kind, _, val = tgt.partition(":")
            if kind not in ("spawn", "form", "faction") or not val:
                err(ctx, f"modifiers.target 非法: {tgt}")
            elif kind == "spawn" and val not in spawn_ids:
                err(ctx, f"modifiers 引用了不存在的单位 '{val}'")
            elif kind == "form" and val not in units:
                err(ctx, f"modifiers 引用了不存在的形态 '{val}'")
            elif kind == "faction" and val not in FACTIONS:
                err(ctx, f"modifiers 阵营非法: {val}")
            if m.get("stat") not in MOD_STATS:
                err(ctx, f"modifiers.stat 非法: {m.get('stat')}")
            if float(m.get("mul", 1)) < 0:
                err(ctx, "modifiers.mul 必须 ≥ 0")
        for su in L.get("initial_units", []):
            for k, v in su.get("overrides", {}).items():
                if k not in MOD_STATS or not isinstance(v, (int, float)) or v < 0:
                    err(ctx, f"initial_units {su.get('id')} overrides.{k} 非法")
        # allowed
        al = L.get("allowed", {})
        for k, valid in (("conditions", CONDITIONS), ("selectors", SELECTORS), ("actions", ACTIONS)):
            for v in al.get(k, []):
                if v not in valid:
                    err(ctx, f"allowed.{k} 含非法值 {v}")
        # objectives
        obj = L.get("objectives", {})
        if not obj.get("objective_text"):
            err(ctx, "objectives.objective_text 缺失")
        lose_ids = []
        if not obj.get("win"):
            err(ctx, "至少需要一条 win 条件")
        for o in obj.get("win", []):
            if o.get("type") not in OBJ_WIN:
                err(ctx, f"win 条件类型非法 {o.get('type')}")
            for t in o.get("targets", []) + ([o["target"]] if "target" in o and o["target"] != "any_ally" else []):
                if t not in spawn_ids:
                    err(ctx, f"win 条件引用了不存在的单位 '{t}' (D02)")
            if o.get("type") in ("reach_zone", "escort"):
                if not o.get("cells"):
                    err(ctx, f"{o.get('type')}.cells 不能为空")
                for c in o.get("cells", []):
                    if not inb(tuple(c)):
                        err(ctx, f"{o.get('type')} 格 {c} 越界 (D03)")
                if int(o.get("count", 1)) < 1:
                    err(ctx, "reach_zone.count 必须 ≥ 1")
            if o.get("type") == "escort":
                es = next((su for su in L.get("initial_units", []) if su.get("id") == o.get("target")), None)
                if es is not None and (es.get("faction") != "ally" or units.get(es.get("unit"), {}).get("kind") != "unit"):
                    err(ctx, f"escort 目标 {o.get('target')} 必须是己方可移动单位")
                if not any(lo.get("type") == "unit_dead" and lo.get("target") == o.get("target") for lo in obj.get("lose", [])):
                    err(ctx, f"escort 关卡需要失败条件 unit_dead 指向 {o.get('target')}")
            if o.get("type") == "survive" and not (o.get("seconds", 0) > 0):
                err(ctx, "survive.seconds 必须为正")
        if not obj.get("lose"):
            err(ctx, "至少需要一条 lose 条件")
        for o in obj.get("lose", []):
            lose_ids.append(o.get("id"))
            if o.get("type") not in OBJ_LOSE:
                err(ctx, f"lose 条件类型非法 {o.get('type')}")
            if "target" in o and o["target"] not in spawn_ids:
                err(ctx, f"lose 条件引用了不存在的单位 '{o['target']}' (D02)")
            if o.get("target") == "any_ally":
                err(ctx, "any_ally 只能用于胜利条件")
            for c in o.get("cells", []):
                if not inb(tuple(c)):
                    err(ctx, f"reach_zone 格 {c} 越界")
        # briefing / hints / feedback
        if "dialogue" in L.get("briefing", {}):
            err(ctx, "DEPRECATED_FIELD briefing.dialogue 已废弃：写入 data/stories/<level_id>_intro.json")
        if "story_id" in L.get("rewards", {}):
            err(ctx, "DEPRECATED_FIELD rewards.story_id 已废弃：剧情按 <level_id>_intro/_win/_lose 约定查找")
        if not L.get("briefing", {}).get("mechanic_hint"):
            err(ctx, "briefing.mechanic_hint 缺失")
        if len(L.get("hints", [])) != 4:
            err(ctx, "hints 必须恰好 4 条 (D05)")
        fb = L.get("fail_feedback", {})
        if "default" not in fb:
            err(ctx, "fail_feedback.default 缺失 (D05)")
        for lid in lose_ids:
            if lid not in fb:
                err(ctx, f"fail_feedback 缺少 lose 条目 '{lid}' 的文本 (D05)")
        # recommended（07 §2 推荐阵型：部署 + 推荐指令 + 信标）
        slot_unit = {s.get("id"): s.get("unit") for s in ro.get("fixed_slots", [])}
        rec_units = L.get("recommended", {}).get("units")
        if not isinstance(rec_units, list):
            err(ctx, "recommended.units 必须是数组"); rec_units = []
        rec_cells = []; rec_slots = []
        for ru in rec_units:
            sid, form = ru.get("slot", ""), ru.get("form", "")
            key = sid or form
            if not key:
                err(ctx, "recommended.units 条目需要 slot 或 form"); continue
            if mode == "free":
                if not form:
                    err(ctx, "free 模式的 recommended.units 条目需要 form"); continue
                if af is not None and form not in af:
                    err(ctx, f"recommended.units {key} 的形态 '{form}' 不在 available_forms 中")
            elif sid:
                if sid not in slot_ids:
                    err(ctx, f"recommended.units 槽位 '{sid}' 不存在"); continue
                if sid in rec_slots:
                    err(ctx, f"recommended.units 槽位 '{sid}' 重复")
                rec_slots.append(sid)
                if form and form != slot_unit[sid]:
                    err(ctx, f"recommended.units {sid} 的 form '{form}' 与槽位形态 '{slot_unit[sid]}' 不一致")
                form = slot_unit[sid]
            pos = tuple(ru.get("pos", (-1, -1)))
            if pos not in cells:
                err(ctx, f"recommended.units {key} {list(pos)} 不在部署区 (D04)")
            rec_cells.append(pos)
            if form not in units:
                err(ctx, f"recommended.units {key} 的形态 '{form}' 不存在 (D02)"); continue
            rec_beacons = [b.get("id") for b in ru.get("beacons", [])]
            for i, r in enumerate(ru.get("rules", [])):
                check_rule(r, f"{ctx}:recommended.{key}.rules[{i}]", routes=routes, unit_allowed_actions=expand_allowed(units[form].get("allowed_actions", [])), beacon_ids=rec_beacons)
            if len(ru.get("beacons", [])) > BEACON_SOFT_CAP:
                err(ctx, f"recommended.units {key} 信标超过 {BEACON_SOFT_CAP} 个")
            if len(rec_beacons) != len(set(rec_beacons)):
                err(ctx, f"recommended.units {key} 信标编号重复")
            for b in ru.get("beacons", []):
                beacon_id_ok(ctx, b.get("id"), f"recommended.units {key} 信标 id")
                bc = tuple(b.get("cell", (-1, -1)))
                if not b.get("id") or not inb(bc) or bc in blocked:
                    err(ctx, f"recommended.units {key} 信标 {b.get('id')} {list(bc)} 缺少 id、越界或在障碍上 (D03)")
        if len(rec_cells) != len(set(rec_cells)):
            err(ctx, "recommended.units 存在重叠格")
        if mode == "free":
            total = sum(units.get(ru.get("form"), {}).get("cost", 0) for ru in rec_units)
            if total > ro.get("budget", 0):
                err(ctx, f"推荐阵型 Cost {total} 超出预算 {ro.get('budget')}")
            if not (mn <= len(rec_units) <= mx):
                err(ctx, f"推荐阵型人数 {len(rec_units)} 不在 [{mn}, {mx}] 内")
        # rewards
        rw = L.get("rewards", {})
        if "summary" in L and not isinstance(L["summary"], str):
            err(ctx, "summary 必须是字符串（10 §3.1，可选；空则回退 subtitle）")
        nl = rw.get("unlock_level", "")
        if nl and nl not in level_ids:
            err(ctx, f"rewards.unlock_level '{nl}' 不存在 (D06)")
        for f in rw.get("unlock_forms", []):
            if f not in units:
                err(ctx, f"rewards.unlock_forms '{f}' 不存在")
        known_unlock_keys.update(rw.get("unlock_presets", []))
    # 10 §5.1：commands.json 的 unlock_key 必须在 progression 初始解锁或某关 rewards.unlock_presets 中出现
    for ctx, key in sorted(command_keys):
        if key not in known_unlock_keys:
            err(ctx, f"unlock_key '{key}' 不在 progression 初始解锁或任何关卡 rewards.unlock_presets 中")
    # 07 §10.1 章节
    for cp in sorted((ROOT / "chapters").glob("*.json")) if (ROOT / "chapters").exists() else []:
        ch = load(f"chapters/{cp.name}")
        if ch is None:
            continue
        cctx = f"chapters/{cp.name}"
        for k in ("id", "title", "regions", "nodes"):
            if k not in ch:
                err(cctx, f"缺少必填字段 {k}")
        region_ids = {r.get("id") for r in ch.get("regions", [])}
        # 2026-10-18 分区域：区域地图 / 一级地图坐标；章节一级地图
        def _pair(v, allow_zero=False):
            return isinstance(v, list) and len(v) == 2 and all(isinstance(x, (int, float)) and (x >= 0 if allow_zero else x > 0) for x in v)
        for r in ch.get("regions", []):
            rctx = f"{cctx}:regions.{r.get('id')}"
            if "map" in r and not (isinstance(r["map"], str) and r["map"].startswith("res://") and (ROOT.parent / r["map"][6:]).exists()):
                err(rctx, f"区域地图 {r.get('map')} 不存在")
            if "map_size" in r and not _pair(r["map_size"]):
                err(rctx, "map_size 必须是 [宽, 高]（正数）")
            if "world_pos" in r and not _pair(r["world_pos"], True):
                err(rctx, "world_pos 必须是 [x, y]")
        if "world" in ch:
            w = ch["world"]
            if not (isinstance(w, dict) and isinstance(w.get("map"), str) and w["map"].startswith("res://") and (ROOT.parent / w["map"][6:]).exists()):
                err(cctx, "world.map 必须是存在的 res:// 图片")
            if not _pair((w or {}).get("map_size", [1, 1])):
                err(cctx, "world.map_size 必须是 [宽, 高]（正数）")
            for r in ch.get("regions", []):
                if "world_pos" not in r:
                    err(f"{cctx}:regions.{r.get('id')}", "有一级地图时每个区域都需要 world_pos")
        ms = ch.get("map_size", [1920, 1080])
        if not (isinstance(ms, list) and len(ms) == 2 and all(isinstance(v, (int, float)) and v > 0 for v in ms)):
            err(cctx, "map_size 必须是 [宽, 高]（正数）")
        # 10 §3.1：节点以 id 索引（缺省 = level）；placeholder 节点不得有 level / boss / story_on_unlock
        node_ids = [n.get("id", n.get("level")) for n in ch.get("nodes", [])]
        if len(node_ids) != len(set(node_ids)):
            err(cctx, "节点 id 重复")
        node_levels = [n.get("level") for n in ch.get("nodes", []) if n.get("level")]
        if len(node_levels) != len(set(node_levels)):
            err(cctx, "节点关卡重复")
        for n in ch.get("nodes", []):
            nid = n.get("id", n.get("level"))
            if not nid:
                err(cctx, "节点需要 level 或 id")
            if n.get("placeholder", False):
                for k in ("level", "boss", "story_on_unlock"):
                    if k in n:
                        err(cctx, f"占位节点 {nid} 不得有 {k}")
                if "title_key" in n and not isinstance(n["title_key"], str):
                    err(cctx, f"占位节点 {nid} title_key 必须是字符串")
            elif n.get("level") not in level_ids:
                err(cctx, f"节点关卡 '{n.get('level')}' 不存在")
            if "node_art" in n and not isinstance(n["node_art"], str):
                err(cctx, f"节点 {nid} node_art 必须是字符串")
            if n.get("region") and n["region"] not in region_ids:
                err(cctx, f"节点 {nid} 的区域 '{n.get('region')}' 不存在")
            if not (isinstance(n.get("pos"), list) and len(n["pos"]) == 2):
                err(cctx, f"节点 {nid} pos 必须是 [x, y]")
            for to in n.get("links", []):
                if to not in node_ids:
                    err(cctx, f"节点 {nid} 的连线指向不在本章的 '{to}'")
            if not isinstance(n.get("legacy_ids", []), list):
                err(cctx, f"节点 {nid} legacy_ids 必须是数组")
    # 10 §1.5 UI 动效参数（P8；文件可缺省 = 不挂动效参数）
    if (ROOT / "ui_motion.json").exists():
        um = load("ui_motion.json")
        mctx = "ui_motion.json"
        trans_names = {"linear", "sine", "quad", "cubic", "quart", "quint", "expo", "circ", "back", "elastic", "bounce", "spring"}
        ease_names = {"in", "out", "in_out", "out_in"}
        um = um or {}
        if "button" not in um:
            err(mctx, "缺少通用档 button")

        def merged(name, seen=()):
            prof = um.get(name, {})
            if "extends" not in prof:
                return dict(prof)
            base_name = prof["extends"]
            if base_name not in um or base_name in seen:
                err(mctx, f"{name}.extends 指向不存在或循环的档 '{base_name}'")
                return dict(prof)
            out = merged(base_name, seen + (name,))
            out.update(prof)
            return out

        for pname in [k for k in um if isinstance(um[k], dict) and k.startswith("button")]:
            check_motion_profile(mctx + " " + pname, merged(pname), trans_names, ease_names)
        st = um.get("scroll_text")                 # P6 文字溢出滚动
        if not isinstance(st, dict):
            err(mctx, "缺少 scroll_text")
        else:
            for key in ("auto_speed_px", "auto_pause_s", "wheel_step_px", "drag_threshold_px", "edge_fade_px"):
                if not (isinstance(st.get(key), (int, float)) and st[key] >= 0):
                    err(mctx, f"scroll_text.{key} 必须是非负数")

        ab = um.get("art_banner")                  # P8 战斗开始提示
        if ab is not None:
            for key in ("ink_height_px", "fade_in_s", "hold_s", "fade_out_s", "rise_px", "start_scale"):
                if not (isinstance(ab.get(key), (int, float)) and ab[key] >= 0):
                    err(mctx, f"art_banner.{key} 必须是非负数")

    # P8 艺术字（10 §1.5、决策 ⑭）：data/art_text.json 指向的素材包须有 manifest.json 与 base 图层文件
    if (ROOT / "art_text.json").exists():
        at = load("art_text.json") or {}
        for table in ("texts", "nodes"):
            for key, d in (at.get(table) or {}).items():
                actx = f"art_text.json {table}.{key}"
                pdir = ROOT.parent / str(d)[len("res://"):] if str(d).startswith("res://") else None
                if pdir is None or not (pdir / "manifest.json").exists():
                    err(actx, f"素材包不存在或缺 manifest.json：{d}")
                    continue
                man = json.loads((pdir / "manifest.json").read_text(encoding="utf-8"))
                els = man.get("elements") or [{}]
                layers = {l.get("id"): l.get("file") for l in els[0].get("layers", [])}
                if not layers.get("base") or not (pdir / layers["base"]).exists():
                    err(actx, "缺 base 图层")
                for f in (els[0].get("frames") or {}).get("files", []):
                    if not (pdir / f).exists():
                        err(actx, f"帧文件不存在：{f}")
                        break

    # 07 §10.2 剧情（文件可缺省 = 不触发；存在则须格式正确）
    for sp in sorted((ROOT / "stories").glob("*.json")) if (ROOT / "stories").exists() else []:
        st = load(f"stories/{sp.name}")
        if st is None:
            continue
        sctx = f"stories/{sp.name}"
        if st.get("id") != sp.stem:
            err(sctx, f"id '{st.get('id')}' 与文件名不一致")
        if not isinstance(st.get("scenes"), list):
            err(sctx, "scenes 必须是数组（空数组 = 不触发）")
        for i, sc in enumerate(st.get("scenes", [])):
            if sc.get("speaker") not in SPEAKERS:
                err(sctx, f"scenes[{i}] speaker 非法: {sc.get('speaker')}")
            if not isinstance(sc.get("text"), str) or not sc.get("text"):
                err(sctx, f"scenes[{i}] text 缺失")
            for key in ("illustration", "backdrop"):
                if key in sc and not isinstance(sc[key], str):
                    err(sctx, f"scenes[{i}] {key} 必须是字符串")
    check_teaching(teaching, level_docs)
    # 第五阶段：异常状态粒子参数
    if (ROOT / "status_fx.json").exists():
        fx = load("status_fx.json") or {}
        for sid, spec in (fx.get("statuses") or {}).items():
            fctx = f"status_fx.json:statuses.{sid}"
            if sid not in ("vulnerable", "paralysis", "slow"):
                err(fctx, "未知异常状态")
            if spec.get("emission", "sphere") not in ("point", "sphere", "ring", "box"):
                err(fctx, "emission 非法")
            for k in ("amount", "lifetime"):
                if not (isinstance(spec.get(k), (int, float)) and spec[k] > 0):
                    err(fctx, f"{k} 必须 > 0")
            if not (isinstance(spec.get("energy", 1.0), (int, float)) and spec.get("energy", 1.0) >= 0):
                err(fctx, "energy 必须 ≥ 0")
            for k in ("velocity", "scale", "offset", "direction", "gravity"):
                if k in spec and not (isinstance(spec[k], list) and len(spec[k]) == 2):
                    err(fctx, f"{k} 必须是 [a, b]")
    return finish()


def finish():
    if warnings:
        print(f"提醒 {len(warnings)} 条（不影响通过）：")
        for w in warnings:
            print("  " + w)
    if errors:
        print(f"校验失败，共 {len(errors)} 条错误：")
        for e in errors:
            print("  " + e)
        return 1
    print("数据校验通过（units / traits / commands / strings / progression / biomes / levels / chapters / stories / ui_motion / art_text / teaching / status_fx）。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
