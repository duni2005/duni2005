class_name Packer
extends Building
## 포장기: 입력 2(테이프, 박스), 출력 1. 3초, 테이프 2개.
##  - 요청서가 붙은 박스 → '택배' (내용물·요청 유지)
##  - 요청서 없이 같은 온전한 물건 4개가 든 박스 → '판매용 ○○'
##  - 그 밖의 박스 → '택배' (요청 없음, 출하하면 오배송으로 세요)

var tape := 0
var boxes: Array = []
var out_buf: Array = []
var t := 0.0
var made := 0


func try_insert(it: Item, _from_cell: Vector2i) -> bool:
	if it.id == "박스 테이프" and it.is_plain():
		if tape >= 20:
			return false
		tape += 1
		return true
	if DB.is_box(it.id) and boxes.size() < 4:
		boxes.append(it)
		return true
	return false


func power_demand() -> float:
	return float(def.get("power", 0.0))


func tick(dt: float) -> void:
	if boxes.is_empty():
		status = "박스를 기다려요"
	elif tape < 2:
		status = "테이프가 모자라요"
	elif out_buf.size() >= 4:
		status = "출력 막힘"
	else:
		var m := power_mult()
		if m <= 0.0:
			status = "전력 없음"
		else:
			status = "포장 중"
			t += dt * m
			if t >= float(def.get("time", 3.0)):
				t = 0.0
				tape -= 2
				out_buf.append(_pack(boxes.pop_front()))
				made += 1
	if not out_buf.is_empty() and auto_push(out_buf[0]):
		out_buf.pop_front()


func _pack(b: Item) -> Item:
	if not b.has_request() and b.sale_ready():
		return Item.new(DB.sale_map[b.contents[0]])
	var p := Item.new("택배")
	p.copy_payload_from(b)
	return p


func try_extract() -> Item:
	return null if out_buf.is_empty() else out_buf.pop_front()


func info() -> String:
	return super.info() + "\n테이프 %d · 대기 박스 %d · 출력 %d · 포장 %d" % [tape, boxes.size(), out_buf.size(), made]


func is_active() -> bool:
	return not boxes.is_empty() and tape >= 2 and out_buf.size() < 4 and power_mult() > 0.0


func has_output() -> bool:
	return not out_buf.is_empty()


func contents() -> Array:
	var out := Building.items_of("박스 테이프", tape)
	out.append_array(boxes)
	out.append_array(out_buf)
	return out
