class_name InfiniteSource
extends Building
## 무한 공급기 (크리에이티브): 고른 아이템을 앞 칸으로 최대 4개/초 내보내요.

var item_id: String = "장난감"
var per_sec := 2.0
var _t := 0.0
var sent := 0


func save_state() -> Dictionary:
	return {"item": item_id, "per_sec": per_sec}


func load_state(d: Dictionary) -> void:
	item_id = str(d.get("item", item_id))
	per_sec = float(d.get("per_sec", per_sec))


func tick(dt: float) -> void:
	_t += dt
	if _t >= 1.0 / per_sec:
		if push_to(front_cell(), Item.new(item_id)):
			_t = 0.0
			sent += 1
		else:
			_t = 1.0 / per_sec


func try_extract() -> Item:
	return Item.new(item_id)


func info() -> String:
	return super.info() + "\n아이템: %s · %d개/초 · 보낸 수 %d" % [item_id, int(per_sec), sent]


func is_active() -> bool:
	return true
