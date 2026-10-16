class_name SimBlast
extends RefCounted
## 已放置的延迟爆炸（01 §6.8）：落点固定，不追踪、不因目标死亡取消。

var id: int = 0
var pos: Vector2 = Vector2.ZERO
var radius: float = 0.0
var damage: float = 0.0
var remaining: float = 0.0
var delay: float = 0.0
var source: int = -1
var source_faction: int = SimTypes.Faction.ENEMY
var target: int = -1                    ## 放置时锁定的单位（仅供表现/记录）
