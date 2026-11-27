class_name Conveyor
extends Building
## 레일 계열(1칸, 방향 있음)의 바탕.
## 한 칸에 물건 1개. progress가 0→1로 차면 앞 칸에 넘기려고 시도해요.
## 앞이 막히면 그 자리에서 기다려요 (역압).

var item: Item = null
var progress := 0.0
var speed := 1.0     # 칸/초


func _init_state() -> void:
	speed = float(def.get("speed", 1.0))


func is_conveyor() -> bool:
	return true


func accepts_auto_output() -> bool:
	return true


func accepts_from(from_cell: Vector2i) -> bool:
	## 기본: 앞쪽만 빼고 어느 쪽에서든 받아요
	return from_cell != front_cell()


func try_insert(it: Item, from_cell: Vector2i) -> bool:
	if item != null or not accepts_from(from_cell):
		return false
	item = it
	progress = 0.0
	return true


func move_speed() -> float:
	return speed


func tick(dt: float) -> void:
	if item == null:
		return
	if progress < 1.0:
		progress = minf(1.0, progress + move_speed() * dt)
	if progress >= 1.0:
		if deliver():
			item = null
			progress = 0.0


func deliver() -> bool:
	## 앞 칸으로 넘기기. 다른 출력 규칙이 있으면 덮어써요
	return push_to(front_cell(), item)


func info() -> String:
	var s := super.info()
	s += "\n물건: " + (item.describe() if item != null else "없음")
	return s
