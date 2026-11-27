class_name Merger
extends Conveyor
## 병합기: 뒤·왼쪽·오른쪽에서 받아 앞으로 보내요.


func accepts_from(from_cell: Vector2i) -> bool:
	return from_cell != front_cell()
