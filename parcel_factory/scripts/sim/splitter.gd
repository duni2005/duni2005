class_name Splitter
extends Conveyor
## 분배기: 입력 1(뒤), 출력 3(앞·왼쪽·오른쪽)으로 차례로 나눠요.

var _next := 0


func _init_state() -> void:
	speed = 4.0


func accepts_from(from_cell: Vector2i) -> bool:
	return from_cell == back_cell()


func deliver() -> bool:
	var outs := [front_cell(), left_cell(), right_cell()]
	for i in 3:
		var k := (_next + i) % 3
		if push_to(outs[k], item):
			_next = k + 1
			return true
	return false
