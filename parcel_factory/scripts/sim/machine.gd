class_name Machine
extends Building
## 레시피 설비 (분해기·가공기·제작기·용광로·생산기·현금인쇄기·설비 제작대).
## 재료는 개수로 보관하고, 레시피 시간이 차면 결과물을 출력 버퍼에 넣어요.
## 속도 = 전력 충족률 × 속도 설정(100% / 50%).

var recipe = null            # Dictionary 또는 null
var inputs := {}             # 이름 -> 개수
var outputs := {}            # 이름 -> 개수
var progress := 0.0          # 초
var speed_setting := 1.0     # 1.0 또는 0.5
var working := false
var made := 0


func _init_state() -> void:
	var list: Array = DB.recipes_by_machine.get(name, [])
	if list.size() == 1:
		set_recipe(list[0])


func available_recipes() -> Array:
	return DB.recipes_by_machine.get(name, [])


func set_recipe(r) -> void:
	recipe = r
	inputs.clear()
	progress = 0.0
	# 다른 레시피의 결과물은 그대로 두면 꺼낼 수 있어요


func save_state() -> Dictionary:
	return {"recipe": int(recipe["id"]) if recipe != null else -1, "speed": speed_setting}


func load_state(d: Dictionary) -> void:
	speed_setting = float(d.get("speed", 1.0))
	var id := int(d.get("recipe", -1))
	if id < 0:
		set_recipe(null)
		return
	for r in available_recipes():
		if int(r["id"]) == id:
			set_recipe(r)
			return


func input_cap(n: String) -> int:
	return maxi(int(recipe["in"][n]) * 2, 2)


func output_total() -> int:
	var s := 0
	for k in outputs:
		s += outputs[k]
	return s


func output_cap() -> int:
	var s := 0
	for k in recipe["out"]:
		s += int(recipe["out"][k])
	return maxi(s * 2, 4)


func try_insert(it: Item, _from_cell: Vector2i) -> bool:
	if recipe == null or not it.is_plain():
		return false
	if not recipe["in"].has(it.id):
		return false
	var have: int = inputs.get(it.id, 0)
	if have >= input_cap(it.id):
		return false
	inputs[it.id] = have + 1
	return true


func has_all_inputs() -> bool:
	for n in recipe["in"]:
		if inputs.get(n, 0) < int(recipe["in"][n]):
			return false
	return true


func extra_condition() -> bool:
	if def.get("needs_computer", false):
		if power_net == null:
			return false
		for b in power_net["buildings"]:
			if b.kind == "computer":
				return true
		return false
	return true


func power_demand() -> float:
	if recipe == null:
		return 0.0
	var p := float(def.get("power", 0.0))
	return p * (0.4 if speed_setting < 1.0 else 1.0)


func tick(dt: float) -> void:
	working = false
	if recipe != null:
		if not has_all_inputs():
			status = "재료 기다리는 중"
		elif output_total() >= output_cap():
			status = "출력 막힘"
		elif not extra_condition():
			status = "작업 컴퓨터와 같은 전력망이 아니에요"
		else:
			var mult := power_mult() * speed_setting
			if mult <= 0.0:
				status = "전력 없음"
			else:
				working = true
				status = "작업 중 %d%%" % int(progress / recipe["t"] * 100.0)
				progress += dt * mult
				if progress >= recipe["t"]:
					progress -= recipe["t"]
					for n in recipe["in"]:
						inputs[n] = inputs[n] - int(recipe["in"][n])
					for n in recipe["out"]:
						outputs[n] = outputs.get(n, 0) + int(recipe["out"][n])
					made += 1
	else:
		status = "레시피를 골라 주세요"
	pump_outputs(dt)


func try_extract() -> Item:
	for n in outputs:
		if outputs[n] > 0:
			outputs[n] -= 1
			return Item.new(n)
	return null


func peek_output() -> Item:
	for n in outputs:
		if outputs[n] > 0:
			return Item.new(n)
	return null


func pop_output() -> void:
	for n in outputs:
		if outputs[n] > 0:
			outputs[n] -= 1
			return


func per_minute() -> String:
	if recipe == null:
		return ""
	var t: float = recipe["t"]
	var a := []
	for n in recipe["in"]:
		a.append("%s %s" % [n, _fmt(int(recipe["in"][n]) * 60.0 / t)])
	var b := []
	for n in recipe["out"]:
		b.append("%s %s" % [n, _fmt(int(recipe["out"][n]) * 60.0 / t)])
	return "분당: %s → %s" % [" · ".join(a), " · ".join(b)]


func _fmt(f: float) -> String:
	if is_equal_approx(f, round(f)):
		return str(int(round(f)))
	return "%.1f" % f


func info() -> String:
	var s := super.info()
	if recipe != null:
		s += "\n레시피: " + DB.recipe_label(recipe)
		s += "\n" + per_minute()
		var a := []
		for n in recipe["in"]:
			a.append("%s %d/%d" % [n, inputs.get(n, 0), int(recipe["in"][n])])
		s += "\n재료: " + ", ".join(a)
	var o := []
	for n in outputs:
		if outputs[n] > 0:
			o.append("%s %d" % [n, outputs[n]])
	if not o.is_empty():
		s += "\n출력 대기: " + ", ".join(o)
	s += "\n만든 횟수: %d · 속도 설정 %d%%" % [made, int(speed_setting * 100.0)]
	return s
