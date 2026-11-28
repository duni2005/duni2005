class_name Combiner
extends Building
## 요청 결합기: 빈 박스 + 요청서 → 요청서가 붙은 박스 (1초).
## 결과는 앞쪽(방향) 레일로 자동 출력해요.

var boxes: Array = []     # 빈 박스 Item
var papers: Array = []    # 요청서 Item
var out_buf: Array = []
var t := 0.0
var made := 0


func try_insert(it: Item, _from_cell: Vector2i) -> bool:
	if it.id == "요청서" and it.has_request() and papers.size() < 4:
		papers.append(it)
		return true
	if DB.is_box(it.id) and it.is_plain() and boxes.size() < 4:
		boxes.append(it)
		return true
	return false


func power_demand() -> float:
	return float(def.get("power", 0.0))


func tick(dt: float) -> void:
	if boxes.is_empty() or papers.is_empty():
		status = "빈 박스와 요청서를 기다려요"
	elif out_buf.size() >= 4:
		status = "출력 막힘"
	else:
		t += dt * power_mult()
		status = "결합 중"
		if t >= float(def.get("time", 1.0)):
			t = 0.0
			var b: Item = boxes.pop_front()
			var p: Item = papers.pop_front()
			b.request = p.request.duplicate(true)
			out_buf.append(b)
			made += 1
	if not out_buf.is_empty() and push_to(front_cell(), out_buf[0]):
		out_buf.pop_front()


func try_extract() -> Item:
	return null if out_buf.is_empty() else out_buf.pop_front()


func info() -> String:
	return super.info() + "\n빈 박스 %d · 요청서 %d · 출력 %d · 만든 수 %d" % [boxes.size(), papers.size(), out_buf.size(), made]


func is_active() -> bool:
	return not boxes.is_empty() and not papers.is_empty() and out_buf.size() < 4 and power_mult() > 0.0
