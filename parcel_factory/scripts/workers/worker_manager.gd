extends Node2D
## 직원(아르바이트) 묶음: 고용, 길 찾기 격자(nav), 출하대·고장 설비 찾기, 정비 맡기(같은 설비를 둘이 고치지 않게).
## 직원은 정문 안쪽(사물함은 아직 없어요)에서 생겨요. 배달 직원 수를 factory.courier_count에 알려
## 출하대 자동 배달을 꺼요. 설비가 설치·철거·이동되면(factory.cells_changed) 길 위가 바뀐 직원만 다시 길을 찾아요.

const Worker := preload("res://scripts/workers/worker.gd")
const NavGrid := preload("res://scripts/workers/nav_grid.gd")
const TILE := 32.0
const PICK_RADIUS := 18.0     # 직원 탭 판정 (px, 몸 중심 기준)

var factory: Factory = null
var nav = null                # nav_grid.gd
var workers: Array = []
var _claims := {}             # 고장 설비 -> 고치러 가는 직원


func _ready() -> void:
	nav = NavGrid.new()
	nav.setup(factory)
	factory.cells_changed.connect(_on_cells_changed)


func hire(def_name: String):
	var w = Worker.new()
	w.factory = factory
	w.manager = self
	w.setup(DB.workers[def_name])
	var n := 1
	for o in workers:
		if o.def["name"] == def_name:
			n += 1
	w.title = "%s %d" % [def_name, n]
	w.position = (Vector2(spawn_cell()) + Vector2(0.5, 0.5)) * TILE
	workers.append(w)
	add_child(w)
	_count_couriers()
	return w


func to_save() -> Array:
	var out := []
	for w in workers:
		out.append(w.to_save())
	return out


func load_save(list) -> void:
	## 지금 직원을 모두 내보내고 저장된 직원으로 바꿔요
	for w in workers:
		w.queue_free()
	workers.clear()
	_claims.clear()
	if list is Array:
		for d in list:
			if d is Dictionary and DB.workers.has(str(d.get("def", ""))):
				var w = hire(str(d["def"]))
				w.load_save(d)
	_count_couriers()


func _count_couriers() -> void:
	var n := 0
	for w in workers:
		if w.job == "delivery":
			n += 1
	factory.courier_count = n


func spawn_cell() -> Vector2i:
	## 정문 안쪽 가운데 (통로 칸)
	var d: Rect2i = factory.room.door_rect()
	return Vector2i(d.position.x - 1, d.position.y + int(d.size.y / 2.0))


func exit_cell(from: Vector2i) -> Vector2i:
	## 정문으로 나가는 칸: 정문 바로 안쪽, 지금 줄과 가장 가까운 칸
	var d: Rect2i = factory.room.door_rect()
	return Vector2i(d.position.x - 1, clampi(from.y, d.position.y, d.end.y - 1))


func find_shelf(w, with_parcels: bool):
	## 가장 가까운 출하대(·출하 도크). with_parcels면 택배가 있는 것만
	var best = null
	var bd := INF
	var me: Vector2 = w.position / TILE
	for b in factory.buildings:
		if not (b is Shelf) or (with_parcels and b.stack.is_empty()):
			continue
		var d := me.distance_to(Vector2(b.pos) + Vector2(b.size) * 0.5)
		if d < bd:
			bd = d
			best = b
	return best


func claim_broken(w):
	## 담당 구역 안 가장 가까운 고장 설비 (다른 정비 직원이 맡지 않은 것)를 맡아요
	var best = null
	var bd := INF
	var me: Vector2 = w.position / TILE
	for b in factory.buildings:
		if not b.broken or (_claims.has(b) and _claims[b] != w):
			continue
		if not w.zone.intersects(Rect2i(b.pos, b.size)):
			continue
		var d := me.distance_to(Vector2(b.pos) + Vector2(b.size) * 0.5)
		if d < bd:
			bd = d
			best = b
	if best != null:
		_claims[best] = w
	return best


func release(w) -> void:
	for b in _claims.keys():
		if _claims[b] == w:
			_claims.erase(b)


func worker_at(world_pos: Vector2):
	for w in workers:
		if w.visible and Rect2(w.position + Vector2(-PICK_RADIUS, -44), Vector2(PICK_RADIUS * 2.0, 50)).has_point(world_pos):
			return w
	return null


func _on_cells_changed(cells: Array) -> void:
	for w in workers:
		if cells.is_empty() or w.path_has(cells):
			w.repath()
