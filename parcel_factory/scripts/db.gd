extends Node
## 데이터베이스 (자동 로드 'DB').
## data/*.json을 읽어 아이템·레시피·설비 정의를 보관해요.
## 수치는 기획서 표를 그대로 옮긴 것이라, 밸런스는 JSON만 고치면 돼요.

var items := {}              # 이름 -> {cat, fragile}
var item_order: Array = []   # 표시 순서
var item_categories: Array = []  # [{name, items}]
var fragile: Array = []
var box_capacity := {}
var sale_map := {}
var short_names := {}

var recipes: Array = []          # [{m, in, out, t, alt, id}]
var recipes_by_machine := {}     # 설비 이름 -> [recipe]

var buildings := {}              # 이름 -> 정의
var building_order: Array = []
var building_categories: Array = []
var piles := {}
var pile_rates: Array = [30, 60, 120]

var _colors := {}


func _ready() -> void:
	_load_items()
	_load_recipes()
	_load_buildings()


func _load_json(path: String):
	var txt := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(txt)
	if data == null:
		push_error("JSON을 읽지 못했어요: " + path)
	return data


func _load_items() -> void:
	var d = _load_json("res://data/items.json")
	fragile = d["fragile"]
	box_capacity = d["box_capacity"]
	sale_map = d["sale_map"]
	short_names = d["short"]
	for cat in d["categories"]:
		item_categories.append(cat)
		for n in cat["items"]:
			_add_item(n, cat["name"])


func _add_item(n: String, cat: String) -> void:
	if items.has(n):
		return
	items[n] = {"cat": cat, "fragile": n in fragile}
	item_order.append(n)


func _load_recipes() -> void:
	var d = _load_json("res://data/recipes.json")
	var idx := 0
	for r in d:
		r["id"] = idx
		r["t"] = float(r["t"])
		if not r.has("alt"):
			r["alt"] = false
		# JSON 숫자는 float라서 개수는 int로 바꿔 둬요
		var ins := {}
		for k in r["in"]:
			ins[k] = int(r["in"][k])
		var outs := {}
		for k in r["out"]:
			# '[설비] 레일 Mk1 ×4' 같은 묶음 이름은 '[설비] 레일 Mk1' 4개로 바꿔요 (가방에서 한 종류로 쌓이게)
			var nm: String = k
			var mult := 1
			var cut := nm.rfind(" ×")
			if cut > 0 and nm.substr(cut + 2).is_valid_int():
				mult = int(nm.substr(cut + 2))
				nm = nm.substr(0, cut)
			outs[nm] = int(outs.get(nm, 0)) + int(r["out"][k]) * mult
			if not items.has(nm):
				_add_item(nm, "설비 아이템" if nm.begins_with("[설비]") else "기타")
		r["in"] = ins
		r["out"] = outs
		recipes.append(r)
		if not recipes_by_machine.has(r["m"]):
			recipes_by_machine[r["m"]] = []
		recipes_by_machine[r["m"]].append(r)
		idx += 1


func _load_buildings() -> void:
	var d = _load_json("res://data/buildings.json")
	building_categories = d["categories"]
	piles = d["piles"]
	pile_rates = d["pile_rates"]
	for b in d["buildings"]:
		b["size"] = Vector2i(int(b["size"][0]), int(b["size"][1]))
		for key in ["power", "gen", "fuel_rate", "speed", "time", "cap", "rate", "water"]:
			if b.has(key):
				b[key] = float(b[key])
		buildings[b["name"]] = b
		building_order.append(b["name"])


func recipe_label(r: Dictionary) -> String:
	var a := []
	for k in r["in"]:
		a.append("%s %d" % [k, r["in"][k]])
	var b := []
	for k in r["out"]:
		b.append("%s %d" % [k, r["out"][k]])
	var s := "%s → %s (%s초)" % [" + ".join(a), " + ".join(b), _num(r["t"])]
	if r["alt"]:
		s += " [대체]"
	return s


func _num(f: float) -> String:
	if is_equal_approx(f, round(f)):
		return str(int(round(f)))
	return "%.1f" % f


func building_item(def_name: String) -> String:
	## 설비 이름 → 가방에 들어가는 설비 아이템 이름
	return "[설비] " + def_name


func all_item_names() -> Array:
	## 크리에이티브 보관함용: 모든 아이템 + 지형이 아닌 모든 설비 아이템
	var out := []
	for n in item_order:
		if not n.begins_with("[설비]"):
			out.append(n)
	for b in building_order:
		if buildings[b]["cat"] in building_categories:
			out.append(building_item(b))
	return out


func short(n: String) -> String:
	if short_names.has(n):
		return short_names[n]
	if n.begins_with("[설비]"):
		return "설비"
	return n.substr(0, 2)


func color_of(n: String) -> Color:
	if _colors.has(n):
		return _colors[n]
	var h := float(absi(hash(n)) % 1000) / 1000.0
	var c := Color.from_hsv(h, 0.55, 0.95)
	_colors[n] = c
	return c


func is_fragile(n: String) -> bool:
	return n in fragile


func is_box(n: String) -> bool:
	return box_capacity.has(n)


func buildings_in(cat: String) -> Array:
	var out := []
	for n in building_order:
		if buildings[n]["cat"] == cat:
			out.append(n)
	return out
