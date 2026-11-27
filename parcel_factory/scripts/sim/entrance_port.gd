class_name EntrancePort
extends Conveyor
## 입구: 뒤쪽 레일에서 받은 물건을 앞쪽 창고·설비에 넣어요.


func _init_state() -> void:
	speed = 4.0


func accepts_from(from_cell: Vector2i) -> bool:
	return from_cell == back_cell()
