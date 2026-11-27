class_name RailBridge
extends Conveyor
## 레일 다리: 앞쪽 2~5칸 안에 같은 방향 다리가 있으면 그곳으로 건너뛰어요.
## 없으면 보통 레일처럼 바로 앞 칸으로 보내요.

var _from_bridge := false


func _init_state() -> void:
	speed = 2.0


func partner():
	for k in range(2, 6):
		var b = factory.get_at(pos + dir_vec() * k)
		if b != null and b is RailBridge and b.rot == rot:
			return b
	return null


func receive_from_bridge(it: Item) -> bool:
	if item != null:
		return false
	item = it
	progress = 0.5
	_from_bridge = true
	return true


func try_insert(it: Item, from_cell: Vector2i) -> bool:
	if from_cell != back_cell():
		return false
	if super.try_insert(it, from_cell):
		_from_bridge = false
		return true
	return false


func deliver() -> bool:
	# 다리로 들어온 물건은 바로 앞으로, 레일에서 들어온 물건은 짝 다리로
	if not _from_bridge:
		var p = partner()
		if p != null:
			return p.receive_from_bridge(item)
	return push_to(front_cell(), item)
