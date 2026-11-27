class_name WorkComputer
extends Building
## 작업 컴퓨터 (샌드박스용): 주문 품목 목록에서 요청서를 1초에 1장 만들어 출력해요.
## 출구를 붙이거나, 둘레에 바깥쪽으로 향한 레일을 두면 나가요.

var order_items: Array = ["장난감", "나뭇가지", "바위"]
var max_kinds := 2
var max_total := 3
var gift := false
var printing := true
var buffer: Array = []
var _t := 0.0
var printed := 0
var _rng := RandomNumberGenerator.new()


func _init_state() -> void:
	_rng.seed = 12345


func save_state() -> Dictionary:
	return {"orders": order_items.duplicate(), "max_kinds": max_kinds, "max_total": max_total, "gift": gift, "printing": printing}


func load_state(d: Dictionary) -> void:
	order_items.clear()
	for n in d.get("orders", []):
		order_items.append(str(n))
	max_kinds = int(d.get("max_kinds", max_kinds))
	max_total = int(d.get("max_total", max_total))
	gift = bool(d.get("gift", false))
	printing = bool(d.get("printing", true))


func make_request() -> Item:
	var p := Item.new("요청서")
	var items := {}
	if order_items.is_empty():
		return null
	var kinds := _rng.randi_range(1, mini(max_kinds, order_items.size()))
	var pool := order_items.duplicate()
	var total_left := max_total
	for i in kinds:
		if pool.is_empty() or total_left <= 0:
			break
		var idx := _rng.randi_range(0, pool.size() - 1)
		var n: String = pool[idx]
		pool.remove_at(idx)
		var c := _rng.randi_range(1, maxi(1, total_left - (kinds - i - 1)))
		items[n] = c
		total_left -= c
	var fr := false
	for n in items:
		if DB.is_fragile(n):
			fr = true
	p.request = {"items": items, "fragile": fr, "gift": gift}
	return p


func tick(dt: float) -> void:
	if printing and buffer.size() < 10:
		_t += dt
		if _t >= 1.0:
			_t = 0.0
			var p := make_request()
			if p != null:
				buffer.append(p)
				printed += 1
	pump_outputs(dt)
	status = "요청서 출력 %s" % ("중" if printing else "멈춤")


func try_extract() -> Item:
	return null if buffer.is_empty() else buffer.pop_front()


func peek_output() -> Item:
	return null if buffer.is_empty() else buffer[0]


func pop_output() -> void:
	buffer.pop_front()


func info() -> String:
	return super.info() + "\n주문 품목: %s\n한 요청 최대 %d종 · %d개 · 선물용 %s\n대기 %d · 출력 %d" % [", ".join(order_items), max_kinds, max_total, "예" if gift else "아니오", buffer.size(), printed]
