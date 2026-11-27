class_name Detector
extends Conveyor
## 요청 감지기: 레일 위에 놓고 아이템 1종을 골라요.
##  - 옆에서 그 아이템을 받아 10개까지 보관해요.
##  - 뒤에서 들어온 박스에 그 아이템이 더 필요하면 레일을 세우고 1초에 1개씩 넣어요.
##  - '판매용' 모드: 요청서 없는 박스에 같은 물건 4개를 채워요.
##  - 완충재를 고르면 '깨지기 쉬움' 요청 박스에 1개를 넣어요.

var selected: String = ""
var sale_mode := false
var stock := 0
var fill_t := 0.0


func _init_state() -> void:
	speed = 2.0


func save_state() -> Dictionary:
	return {"selected": selected, "sale_mode": sale_mode}


func load_state(d: Dictionary) -> void:
	selected = str(d.get("selected", ""))
	sale_mode = bool(d.get("sale_mode", false))


func try_insert(it: Item, from_cell: Vector2i) -> bool:
	if from_cell == back_cell():
		return super.try_insert(it, from_cell)
	if from_cell == front_cell():
		return false
	# 옆 입력: 고른 아이템만 보관
	if selected != "" and it.id == selected and it.is_plain() and stock < 10:
		stock += 1
		return true
	return false


func needs(box: Item) -> bool:
	if selected == "" or not DB.is_box(box.id):
		return false
	if box.contents.size() >= box.capacity() and selected != "완충재":
		return false
	if selected == "완충재":
		return box.has_request() and box.request.get("fragile", false) and not box.cushion
	if sale_mode:
		if box.has_request() or box.contents.size() >= 4:
			return false
		for x in box.contents:
			if x != selected:
				return false
		return true
	return box.need_of(selected) > 0


func power_demand() -> float:
	return float(def.get("power", 0.0))


func tick(dt: float) -> void:
	if item != null and stock > 0 and needs(item):
		var m := power_mult()
		if m <= 0.0:
			status = "전력 없음"
			return
		status = "넣는 중"
		fill_t += dt * m
		if fill_t >= 1.0:
			fill_t = 0.0
			stock -= 1
			if selected == "완충재":
				item.cushion = true
			else:
				item.contents.append(selected)
		return
	fill_t = 0.0
	status = ""
	super.tick(dt)


func info() -> String:
	return super.info() + "\n고른 아이템: %s · 보관 %d/10\n모드: %s" % [selected if selected != "" else "없음", stock, "판매용(같은 물건 4개)" if sale_mode else "요청 채우기"]
