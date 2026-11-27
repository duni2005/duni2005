class_name ItemPile
extends Building
## 물건 더미: 정해진 비율대로 원재료를 만들어 출구로 내보내요.
## 비율은 10% 단위라 분당 양이 딱 떨어져요 (Lv1 30 · Lv2 60 · Lv3 120개/분).

var pile_type: String = "기본"
var level: int = 1
var buffer: Array = []
var _seq: Array = []
var _seq_i := 0
var _acc := 0.0


func _init_state() -> void:
	set_type(pile_type)


func set_type(t: String) -> void:
	pile_type = t
	_seq.clear()
	var mix: Dictionary = DB.piles[t]
	# 비율을 번갈아 섞어서 한 품목이 몰리지 않게 순서를 만들어요
	var left := {}
	for k in mix:
		left[k] = int(mix[k])
	var total := 0
	for k in left:
		total += left[k]
	while _seq.size() < total:
		for k in left:
			if left[k] > 0:
				_seq.append(k)
				left[k] -= 1
	_seq_i = 0
	buffer.clear()


func save_state() -> Dictionary:
	return {"type": pile_type, "level": level}


func load_state(d: Dictionary) -> void:
	var t := str(d.get("type", pile_type))
	if DB.piles.has(t):
		set_type(t)
	level = clampi(int(d.get("level", 1)), 1, 3)


func rate_per_min() -> float:
	return float(DB.pile_rates[clampi(level, 1, 3) - 1])


func tick(dt: float) -> void:
	if buffer.size() < 10:
		_acc += dt * rate_per_min() / 60.0
		while _acc >= 1.0 and buffer.size() < 10:
			_acc -= 1.0
			buffer.append(Item.new(_seq[_seq_i]))
			_seq_i = (_seq_i + 1) % _seq.size()
	else:
		_acc = 0.0
	pump_outputs(dt)


func try_extract() -> Item:
	if buffer.is_empty():
		return null
	return buffer.pop_front()


func peek_output() -> Item:
	return null if buffer.is_empty() else buffer[0]


func pop_output() -> void:
	buffer.pop_front()


func info() -> String:
	return super.info() + "\n종류: %s · Lv%d (%d개/분)\n대기: %d" % [pile_type, level, int(rate_per_min()), buffer.size()]
