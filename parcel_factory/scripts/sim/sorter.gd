class_name Sorter
extends Conveyor
## 분류기: 입력 1, 출력 2 (앞, 옆).
## 모드  filter  : 고른 품목만 옆으로
##       overflow: 앞으로 보내다가 막히면 옆으로
##       inverse : 고른 품목만 앞으로, 나머지는 옆으로
## 요청서는 '요청에 그 품목이 들었는지'로 골라요.

var filter_item: String = ""
var mode: String = "filter"
var side_right := true


func _init_state() -> void:
	speed = 4.0


func save_state() -> Dictionary:
	return {"filter": filter_item, "mode": mode, "side_right": side_right}


func load_state(d: Dictionary) -> void:
	filter_item = str(d.get("filter", ""))
	mode = str(d.get("mode", "filter"))
	side_right = bool(d.get("side_right", true))


func side_cell() -> Vector2i:
	return right_cell() if side_right else left_cell()


func accepts_from(from_cell: Vector2i) -> bool:
	return from_cell != front_cell() and from_cell != side_cell()


func matches(it: Item) -> bool:
	if filter_item == "":
		return false
	if it.id == filter_item:
		return true
	if it.id == "요청서" and it.has_request():
		return it.request["items"].has(filter_item)
	return false


func deliver() -> bool:
	match mode:
		"overflow":
			return push_to(front_cell(), item) or push_to(side_cell(), item)
		"inverse":
			return push_to(front_cell() if matches(item) else side_cell(), item)
		_:
			return push_to(side_cell() if matches(item) else front_cell(), item)


func info() -> String:
	var m := {"filter": "고른 품목 → 옆", "overflow": "넘치면 옆", "inverse": "고른 품목 → 앞"}
	return super.info() + "\n품목: %s\n모드: %s\n옆 출력: %s" % [filter_item if filter_item != "" else "없음", m.get(mode, mode), "오른쪽" if side_right else "왼쪽"]
