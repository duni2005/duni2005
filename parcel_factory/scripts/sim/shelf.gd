class_name Shelf
extends Building
## 출하대·출하 도크: 택배를 받아 쌓아 두고, 테스트용으로 일정 속도로 자동 배달해요.
## 배달 아르바이트가 1명이라도 있으면(factory.courier_count) 자동 배달은 꺼지고 직원이 집어 가요(factory.take_parcels).
## 배달할 때 요청이 맞는지 확인해 성공/오배송을 세요 (parcel_ok).

var stack: Array = []
var auto_deliver := true
var _t := 0.0
var shipped := 0
var shipped_ok := 0


func save_state() -> Dictionary:
	return {"auto_deliver": auto_deliver}


func load_state(d: Dictionary) -> void:
	auto_deliver = bool(d.get("auto_deliver", true))


func try_insert(it: Item, _from_cell: Vector2i) -> bool:
	if it.id != "택배" and it.id != "선물용 택배":
		return false
	if stack.size() >= int(def.get("cap", 10.0)):
		return false
	stack.append(it)
	return true


static func parcel_ok(p: Item) -> bool:
	## 요청이 맞는 정상 배달인지 (선물 요청인데 선물 포장이 아니면 오배송)
	var ok := p.request_done()
	if p.has_request() and p.request.get("gift", false) and p.id != "선물용 택배":
		ok = false
	return ok


func tick(dt: float) -> void:
	if not auto_deliver or stack.is_empty() or factory.courier_count > 0:
		_t = 0.0
		return
	_t += dt
	var every := 1.0 / maxf(0.01, float(def.get("rate", 1.0)))
	if _t >= every:
		_t = 0.0
		var p: Item = stack.pop_front()
		shipped += 1
		var ok := parcel_ok(p)
		if ok:
			shipped_ok += 1
		factory.record_shipment(p, ok)


func info() -> String:
	return super.info() + "\n쌓인 택배 %d/%d · 자동 배달 %s\n배달 %d (정상 %d · 오배송 %d)" % [stack.size(), int(def.get("cap", 10.0)), "켬" if auto_deliver else "끔", shipped, shipped_ok, shipped - shipped_ok]


func contents() -> Array:
	var out := stack.duplicate()
	return out


func accepts(id: String) -> bool:
	return id == "택배" or id == "선물용 택배"


func get_slots() -> Array:
	return [Building.list_slot("store", stack, int(def.get("cap", 10.0)), "택배")]


func extract_slot(_index: int, n: int) -> Array:
	return Building.take_front(stack, n)
