class_name ExitPort
extends Conveyor
## 출구: 뒤쪽 더미·창고·설비에서 물건을 꺼내 앞 칸으로 보내요 (최대 4개/초).

var _cd := 0.0


func _init_state() -> void:
	speed = 4.0


func accepts_from(_from_cell: Vector2i) -> bool:
	return false


func accepts_auto_output() -> bool:
	return false


func tick(dt: float) -> void:
	_cd -= dt
	if item == null and _cd <= 0.0:
		var src = factory.get_at(back_cell())
		# 엄청난 쓰레기 더미는 정해진 출구 자리에서만 꺼낼 수 있어요
		if src != null and not src.is_conveyor() and not (src is ItemPile and not src.accepts_exit_at(pos)):
			var it: Item = src.try_extract()
			if it != null:
				item = it
				progress = 0.5
				_cd = 0.25
	super.tick(dt)
