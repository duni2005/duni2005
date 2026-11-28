class_name GiftPacker
extends Building
## 선물 포장기: '물건이 담긴 택배' + 리본 → '물건이 담긴 선물용 택배' (6초).

var ribbon := 0
var parcels: Array = []
var out_buf: Array = []
var t := 0.0
var made := 0


func try_insert(it: Item, _from_cell: Vector2i) -> bool:
	if it.id == "리본" and it.is_plain():
		if ribbon >= 10:
			return false
		ribbon += 1
		return true
	if it.id == "택배" and parcels.size() < 4:
		parcels.append(it)
		return true
	return false


func power_demand() -> float:
	return float(def.get("power", 0.0))


func tick(dt: float) -> void:
	if parcels.is_empty() or ribbon < 1:
		status = "택배와 리본을 기다려요"
	elif out_buf.size() >= 4:
		status = "출력 막힘"
	else:
		status = "선물 포장 중"
		t += dt * power_mult()
		if t >= float(def.get("time", 6.0)):
			t = 0.0
			ribbon -= 1
			var p: Item = parcels.pop_front()
			var g := Item.new("선물용 택배")
			g.copy_payload_from(p)
			out_buf.append(g)
			made += 1
	if not out_buf.is_empty() and auto_push(out_buf[0]):
		out_buf.pop_front()


func try_extract() -> Item:
	return null if out_buf.is_empty() else out_buf.pop_front()


func info() -> String:
	return super.info() + "\n리본 %d · 대기 택배 %d · 출력 %d · 포장 %d" % [ribbon, parcels.size(), out_buf.size(), made]


func is_active() -> bool:
	return not parcels.is_empty() and ribbon >= 1 and out_buf.size() < 4 and power_mult() > 0.0


func has_output() -> bool:
	return not out_buf.is_empty()


func contents() -> Array:
	var out := Building.items_of("리본", ribbon)
	out.append_array(parcels)
	out.append_array(out_buf)
	return out
