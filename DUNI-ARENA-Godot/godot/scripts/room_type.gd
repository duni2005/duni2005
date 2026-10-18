class_name RoomType
extends RefCounted
## String names match the executable web kind keys.
const BATTLE = &"battle"
const MINIBOSS = &"miniboss"
const BOSS = &"boss"
const SHOP = &"shop"
const RECRUIT = &"recruit"
const REST = &"rest"
const EVENT = &"event"
const LABELS = {BATTLE:"전투", MINIBOSS:"미니보스", BOSS:"보스", SHOP:"상점", RECRUIT:"길드원 모집", REST:"길드 휴식소", EVENT:"이벤트"}
static func is_combat(kind: StringName) -> bool:
	return kind in [BATTLE, MINIBOSS, BOSS]
