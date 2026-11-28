class_name ItemPile
extends Building
## 물건 더미: 정해진 비율대로 원재료를 만들어 출구로 내보내요.
## 비율은 10% 단위라 분당 양이 딱 떨어져요 (Lv1 30 · Lv2 60 · Lv3 120개/분).
## 정의에 exit_slots(N)가 있으면 오른쪽 면의 N곳에서만 물건이 나가요 (엄청난 쓰레기 더미).
## 정의에 hand_pull([최소, 최대])이 있으면 손으로 뒤져서 그만큼 꺼낼 수 있어요.

var pile_type: String = "기본"
var level: int = 1
var buffer: Array = []
var _seq: Array = []
var _seq_i := 0
var _acc := 0.0


func _init_state() -> void:
	set_type(pile_type)


func is_giant() -> bool:
	return def.has("exit_slots")


func exit_slots() -> Array:
	## 출구를 붙일 수 있는 바깥 칸들. 오른쪽 면을 N등분한 가운데 (회전 0 기준)
	var out := []
	var n := int(def.get("exit_slots", 0))
	for i in n:
		out.append(pos + Vector2i(size.x, int((i + 0.5) * size.y / float(n))))
	return out


func accepts_exit_at(c: Vector2i) -> bool:
	return not is_giant() or exit_slots().has(c)


func refresh_links() -> void:
	super.refresh_links()
	if not is_giant():
		return
	var slots := exit_slots()
	var kept := []
	for link in out_links:
		var rail: Building = link[0]
		if slots.has(rail.pos):
			kept.append(link)
	out_links = kept


func hand_pull_range() -> Vector2i:
	var r: Array = def.get("hand_pull", [])
	if r.size() < 2:
		return Vector2i.ZERO
	return Vector2i(int(r[0]), int(r[1]))


func hand_pull(count: int) -> Array:
	## 손으로 뒤져서 물건 count개를 꺼내요 (자동 출력 버퍼와는 따로)
	var out := []
	for i in count:
		out.append(_next_item())
	return out


func _next_item() -> Item:
	var it := Item.new(_seq[_seq_i])
	_seq_i = (_seq_i + 1) % _seq.size()
	return it


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
			buffer.append(_next_item())
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
	var s: String = super.info() + "\n종류: %s · Lv%d (%d개/분)\n대기: %d" % [pile_type, level, int(rate_per_min()), buffer.size()]
	if is_giant():
		s += "\n출구 자리 %d곳 (오른쪽 면 표시)" % exit_slots().size()
	return s


func is_active() -> bool:
	return true


func has_output() -> bool:
	return not buffer.is_empty()


func contents() -> Array:
	var out := buffer.duplicate()
	return out
