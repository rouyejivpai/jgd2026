class_name SimSnapshot
extends RefCounted
## 本步开始时所有单位的只读副本（01 §6.2 第 5 步）。决策与移动目标位置只读这里。


class Entry:
	extends RefCounted
	var id: int = -1
	var pos: Vector2 = Vector2.ZERO
	var hp: float = 0.0
	var max_hp: float = 1.0
	var alive: bool = false
	var faction: int = SimTypes.Faction.NEUTRAL
	var kind: int = SimTypes.UnitKind.UNIT
	var damage_dealt: float = 0.0   ## 第五阶段 most_damage 选敌


var ids: Array[int] = []        ## 升序
var _entries: Dictionary = {}   ## id -> Entry


static func capture(units: Array[SimUnit]) -> SimSnapshot:
	var s := SimSnapshot.new()
	for u: SimUnit in units:
		var e := Entry.new()
		e.id = u.id
		e.pos = u.pos
		e.hp = u.hp
		e.max_hp = u.max_hp
		e.alive = u.alive
		e.faction = u.faction
		e.kind = u.kind
		e.damage_dealt = u.damage_dealt
		s.ids.append(u.id)
		s._entries[u.id] = e
	return s


func get_entry(id: int) -> Entry:
	return _entries.get(id, null) as Entry
