class_name Judge
extends Conveyor
## 완료 판정기: 다 찬 박스는 오른쪽으로, 덜 찬 박스는 앞으로(다시 루프로) 보내요.

var passed_ok := 0


func _init_state() -> void:
	speed = 2.0


func accepts_from(from_cell: Vector2i) -> bool:
	return from_cell == back_cell()


func power_demand() -> float:
	return float(def.get("power", 0.0))


func is_done(it: Item) -> bool:
	if it.has_request():
		return it.request_done()
	return it.sale_ready()


func move_speed() -> float:
	return speed * power_mult()


func deliver() -> bool:
	if is_done(item):
		if push_to(right_cell(), item):
			passed_ok += 1
			return true
		return false
	return push_to(front_cell(), item)


func info() -> String:
	return super.info() + "\n완료로 보낸 박스: %d" % passed_ok
