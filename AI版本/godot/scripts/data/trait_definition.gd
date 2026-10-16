class_name TraitDefinition
extends RefCounted
## 特性定义（02 §2）。Demo 只有 delayed_blast 一种类型。

var id: String = ""
var type: int = SimTypes.TraitType.DELAYED_BLAST
var params: Dictionary = {}
var public_text: String = ""
# delayed_blast 参数
var damage: float = 0.0
var radius: float = 0.0
var delay: float = 0.0
var cooldown: float = 0.0
var selector: int = SimTypes.Selector.FARTHEST
var filter: int = SimTypes.TargetFilter.UNIT
var place_range: float = -1.0           ## JSON 键 "range"；< 0 表示等于施放者视野
var first_delay: float = 0.0
# 状态类（status / on_hit_status / aura_status / tile_effect）参数：原样存于 params，以下为常用快捷字段
var status: String = ""                 ## on_hit_status / aura_status 施加的状态；tile_effect 的 applies
var duration: float = 0.0               ## 状态持续秒数
var damage_taken_mult: float = 1.0      ## status：受伤倍率（易伤 1.5）
var move_speed_mult: float = 1.0        ## status / tile_effect：移速倍率
var blocks_attack: bool = false         ## status：是否封攻击（麻痹）
var aura_radius: float = 0.0
var clears: Array[String] = []          ## tile_effect：清除的状态
var affects: String = "any"             ## any / ally_only / enemy_of_owner


static func from_dict(trait_id: String, d: Dictionary, ctx: String) -> TraitDefinition:
	var t := TraitDefinition.new()
	t.id = trait_id
	var raw_type: String = DataReader.req_str(d, "type", ctx)
	t.type = DataReader.enum_value(SimTypes.parse_trait(raw_type), raw_type, "特性类型", ctx)
	t.public_text = DataReader.req_str(d, "public_text", ctx)
	t.params = DataReader.req_dict(d, "params", ctx)
	var pctx: String = ctx + ".params"
	if t.type == SimTypes.TraitType.DELAYED_BLAST:
		t.damage = DataReader.req_num(t.params, "damage", pctx)
		t.radius = DataReader.req_num(t.params, "radius", pctx)
		t.delay = DataReader.req_num(t.params, "delay", pctx)
		t.cooldown = DataReader.req_num(t.params, "cooldown", pctx)
		# D08：参数全为正数
		for key: String in ["damage", "radius", "delay", "cooldown"]:
			if t.params.has(key) and DataReader.opt_num(t.params, key, 0.0, pctx) <= 0.0:
				DataReader.report(pctx, "%s 必须为正数 (D08)" % key)
		var raw_sel: String = DataReader.opt_str(t.params, "selector", "farthest", pctx)
		t.selector = DataReader.enum_value(SimTypes.parse_selector(raw_sel), raw_sel, "选敌", pctx)
		var raw_filter: String = DataReader.opt_str(t.params, "filter", "unit", pctx)
		t.filter = DataReader.enum_value(SimTypes.parse_filter(raw_filter), raw_filter, "过滤", pctx)
		t.place_range = DataReader.opt_num(t.params, "range", -1.0, pctx)
		t.first_delay = DataReader.opt_num(t.params, "first_delay", 0.0, pctx)
		if t.params.has("range") and t.place_range <= 0.0:
			DataReader.report(pctx, "range 必须为正数 (D08)")
		if t.first_delay < 0.0:
			DataReader.report(pctx, "first_delay 不能为负")
	elif t.type == SimTypes.TraitType.STATUS:
		t.duration = DataReader.opt_num(t.params, "duration", 0.0, pctx)
		t.damage_taken_mult = DataReader.opt_num(t.params, "damage_taken_mult", 1.0, pctx)
		t.move_speed_mult = DataReader.opt_num(t.params, "move_speed_mult", 1.0, pctx)
		t.blocks_attack = (DataReader.opt_array(t.params, "blocks", pctx) as Array).has("attack")
	elif t.type == SimTypes.TraitType.ON_HIT_STATUS or t.type == SimTypes.TraitType.AURA_STATUS:
		t.status = DataReader.req_str(t.params, "status", pctx)
		t.duration = DataReader.opt_num(t.params, "duration", 0.0, pctx)
		t.aura_radius = DataReader.opt_num(t.params, "radius", 0.0, pctx)
		t.affects = DataReader.opt_str(t.params, "affects", "enemy_of_owner", pctx)
	elif t.type == SimTypes.TraitType.TILE_EFFECT:
		t.status = DataReader.opt_str(t.params, "applies", "", pctx)
		t.duration = DataReader.opt_num(t.params, "duration", 0.0, pctx)
		t.move_speed_mult = DataReader.opt_num(t.params, "move_speed_mult", 1.0, pctx)
		t.clears = DataReader.string_array(DataReader.opt_array(t.params, "clears", pctx), pctx + ".clears")
		t.affects = DataReader.opt_str(t.params, "affects", "any", pctx)
	return t
