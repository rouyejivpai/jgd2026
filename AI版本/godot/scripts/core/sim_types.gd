class_name SimTypes
## 模拟核心公共枚举与常量（契约文件，执行方不得改动既有成员的名称与含义；可追加）。
## JSON 中的小写 snake_case 字符串通过本文件的 parse_* 函数转换为枚举。

const SIM_DT: float = 1.0 / 30.0          ## 固定模拟步长（30 步/秒）
const PATH_REFRESH_STEPS: int = 6          ## 追击路径重算间隔（步）
const RANGE_MARGIN: float = 0.15           ## 追击停下时与射程的安全余量（格）
const ARRIVE_EPS: float = 0.05             ## 到达路点判定距离（格）
const RETREAT_MIN_GAIN: float = 0.5        ## retreat_possible 条件要求的最小距离改善（格）
const TILE_SIZE: int = 96                  ## 表现层每格像素

const TIME_EPS: float = 1e-6               ## 计时/冷却比较容差（秒）
const DIST_EPS: float = 1e-6               ## 射程/半径比较容差（格）
const DEFAULT_SEARCH_DEPTH: int = 3        ## retreat / retreat_possible 的默认 BFS 深度（02 §3）
const AT_BEACON_RADIUS: float = 0.35       ## 07 §3.3：at_beacon 成立距离（格）；follow_beacons 抵达仍用 ARRIVE_EPS
const MAX_BEACONS: int = 8                 ## 07 §3.1 的旧上限；第三阶段（10 §6.3）起不再用于限制，常量名保留（契约只增不改）
const BEACON_LETTERS: String = "ABCDEFGH"  ## 10 §6.3：仅用于兼容旧数据——字母 A–H 映射为 "1"–"8"
const BEACON_SOFT_CAP: int = 64            ## 10 §6.3：每单位信标数防呆上限（超出 toast，不在 UI 体现）
const WAIT_MIN_SECONDS: float = 0.5        ## 07 §3.4：wait.seconds 范围
const WAIT_MAX_SECONDS: float = 30.0

const ALLY_ID_BASE: int = 1
const ENEMY_ID_BASE: int = 101
const STRUCTURE_ID_BASE: int = 201

enum Faction { ALLY, ENEMY, NEUTRAL }
enum UnitKind { UNIT, STRUCTURE }
enum Phase { DEPLOY, RUNNING, PAUSED, ENDED }
enum BattleResult { NONE, WIN, LOSE }

enum ConditionType { ALWAYS, SELF_HP_BELOW, ENEMY_VISIBLE, ENEMY_IN_RANGE, TARGET_DISTANCE, RETREAT_POSSIBLE, AT_BEACON, SIGNAL_IS }
enum ConditionMode { ALL, ANY }
enum Selector { NEAREST, FARTHEST, LOWEST_HP, FIRST_SEEN, LAST_ATTACKER, HIGHEST_MAX_HP }   ## LAST_ATTACKER：07 §9 预留，未实现、不可解析
enum TargetFilter { ANY, UNIT, STRUCTURE }
enum ActionType { IDLE, ATTACK, CHASE_ATTACK, CHASE, RETREAT, FOLLOW_ROUTE, FOLLOW_BEACONS, WAIT }
enum TraitType { DELAYED_BLAST, ALERT_BROADCAST, STATUS, ON_HIT_STATUS, AURA_STATUS, TILE_EFFECT, PHASED_BOSS }   ## ALERT_BROADCAST：07 §9 预留，未实现、不可解析
enum BeaconMode { ONCE, LOOP, PINGPONG }            ## follow_beacons.mode（07 §3.2）
enum ObjectiveType { ANNIHILATE, DESTROY, SURVIVE, UNIT_DEAD, ALL_ALLIES_DEAD, REACH_ZONE, ESCORT }   ## ESCORT：07 §9

## 决策/阻塞原因码。UI 通过 strings.json["reason"][键名] 取短句。
enum ReasonCode {
	OK,
	NO_RULE_MATCHED,
	COND_HP_NOT_BELOW,
	COND_NO_VISIBLE_ENEMY,
	COND_NO_ENEMY_IN_RANGE,
	COND_DISTANCE_FAIL,
	NO_TARGET_CANDIDATE,
	COND_NO_ESCAPE,
	TARGET_OUT_OF_RANGE,
	PATH_BLOCKED,
	FLEE_NO_DIRECTION,
	ROUTE_FINISHED,
	COOLDOWN,
	WAITING,            ## 07 §3.6：wait 计时中
	BEACON_MISSING,     ## 07 §3.6：引用的信标不存在 / 没有信标
	COND_NOT_AT_BEACON, ## at_beacon 未成立（不在该信标上）
	WAIT_DONE,          ## wait 已执行过（armed = false），离开条件后才会再次等待
	PARALYZED,          ## 麻痹中：本步攻击不出手（不造成伤害、不进入冷却），仍可移动
	COND_SIGNAL_OFF,    ## signal_is 未成立（Boss 当前信号不是这个颜色）
}

enum EventType {
	ATTACK_FIRED,
	DAMAGE_APPLIED,
	UNIT_DIED,
	BLAST_PLACED,
	BLAST_DETONATED,
	RULE_CHANGED,
	TARGET_CHANGED,
	OBJECTIVE_PROGRESS,
	BATTLE_ENDED,
}

const _FACTION := { "ally": Faction.ALLY, "enemy": Faction.ENEMY, "neutral": Faction.NEUTRAL }
const _KIND := { "unit": UnitKind.UNIT, "structure": UnitKind.STRUCTURE }
const _COND := {
	"always": ConditionType.ALWAYS, "self_hp_below": ConditionType.SELF_HP_BELOW,
	"enemy_visible": ConditionType.ENEMY_VISIBLE, "enemy_in_range": ConditionType.ENEMY_IN_RANGE,
	"target_distance": ConditionType.TARGET_DISTANCE, "retreat_possible": ConditionType.RETREAT_POSSIBLE,
	"at_beacon": ConditionType.AT_BEACON, "signal_is": ConditionType.SIGNAL_IS,
}
const _MODE := { "all": ConditionMode.ALL, "any": ConditionMode.ANY }
const _SEL := { "nearest": Selector.NEAREST, "farthest": Selector.FARTHEST, "lowest_hp": Selector.LOWEST_HP, "first_seen": Selector.FIRST_SEEN, "highest_max_hp": Selector.HIGHEST_MAX_HP }
const _FILTER := { "any": TargetFilter.ANY, "unit": TargetFilter.UNIT, "structure": TargetFilter.STRUCTURE }
const _ACTION := {
	"idle": ActionType.IDLE, "attack": ActionType.ATTACK, "chase_attack": ActionType.CHASE_ATTACK,
	"chase": ActionType.CHASE, "retreat": ActionType.RETREAT, "follow_route": ActionType.FOLLOW_ROUTE,
	"follow_beacons": ActionType.FOLLOW_BEACONS, "wait": ActionType.WAIT,
}
const _BEACON_MODE := { "once": BeaconMode.ONCE, "loop": BeaconMode.LOOP, "pingpong": BeaconMode.PINGPONG }
const _TRAIT := { "delayed_blast": TraitType.DELAYED_BLAST, "status": TraitType.STATUS, "on_hit_status": TraitType.ON_HIT_STATUS,
	"aura_status": TraitType.AURA_STATUS, "tile_effect": TraitType.TILE_EFFECT, "phased_boss": TraitType.PHASED_BOSS }
const _OBJ := {
	"annihilate": ObjectiveType.ANNIHILATE, "destroy": ObjectiveType.DESTROY, "survive": ObjectiveType.SURVIVE,
	"unit_dead": ObjectiveType.UNIT_DEAD, "all_allies_dead": ObjectiveType.ALL_ALLIES_DEAD, "reach_zone": ObjectiveType.REACH_ZONE,
	"escort": ObjectiveType.ESCORT,
}


## 通用解析：未知字符串返回 -1，调用方必须视为数据错误。
static func _parse(table: Dictionary, s: String) -> int:
	return int(table.get(s, -1))

static func parse_faction(s: String) -> int: return _parse(_FACTION, s)
static func parse_kind(s: String) -> int: return _parse(_KIND, s)
static func parse_condition(s: String) -> int: return _parse(_COND, s)
static func parse_mode(s: String) -> int: return _parse(_MODE, s)
static func parse_selector(s: String) -> int: return _parse(_SEL, s)
static func parse_filter(s: String) -> int: return _parse(_FILTER, s)
static func parse_action(s: String) -> int: return _parse(_ACTION, s)
static func parse_trait(s: String) -> int: return _parse(_TRAIT, s)
static func parse_objective(s: String) -> int: return _parse(_OBJ, s)
static func parse_beacon_mode(s: String) -> int: return _parse(_BEACON_MODE, s)

## 反向：枚举 → JSON 字符串（存档与调试用）
static func _key_of(table: Dictionary, v: int) -> String:
	for k: String in table.keys():
		if int(table[k]) == v:
			return String(k)
	return ""

static func condition_to_string(v: int) -> String: return _key_of(_COND, v)
static func selector_to_string(v: int) -> String: return _key_of(_SEL, v)
static func filter_to_string(v: int) -> String: return _key_of(_FILTER, v)
static func action_to_string(v: int) -> String: return _key_of(_ACTION, v)
static func beacon_mode_to_string(v: int) -> String: return _key_of(_BEACON_MODE, v)
static func reason_to_key(v: int) -> String: return ReasonCode.keys()[v]

## 10 §6.3 信标 id：正整数字符串 "1"、"2"…（不含前导零）
static func is_beacon_id(s: String) -> bool:
	return s.is_valid_int() and int(s) >= 1 and str(int(s)) == s

## 旧字母 id（A–H）→ 数字 id（"1"–"8"）；不是旧字母时返回 ""
static func legacy_beacon_id(s: String) -> String:
	var i: int = BEACON_LETTERS.find(s) if s.length() == 1 else -1
	return str(i + 1) if i >= 0 else ""

## 坐标换算：策划坐标（左下原点，y 向上）→ 屏幕像素（左上原点）
static func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x + 0.5, c.y + 0.5)

static func pos_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x)), int(floor(p.y)))

static func sim_to_screen(p: Vector2, grid_height: int) -> Vector2:
	return Vector2(p.x * TILE_SIZE, (float(grid_height) - p.y) * TILE_SIZE)

static func screen_to_sim(px: Vector2, grid_height: int) -> Vector2:
	return Vector2(px.x / TILE_SIZE, float(grid_height) - px.y / TILE_SIZE)
