class_name Building
extends RefCounted
## 모든 설비의 바탕 클래스.
## 물건을 주고받는 규칙은 두 함수로 통일했어요.
##   try_insert(item, from_cell) : 옆 칸(from_cell)에서 물건을 밀어 넣을 때. 받으면 true
##   try_extract()               : 출구가 물건을 꺼내 갈 때. 없으면 null

const DIRV := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]

var factory = null           # Factory
var def: Dictionary = {}
var name: String = ""
var kind: String = ""
var pos := Vector2i.ZERO     # 왼쪽 위 칸
var rot: int = 0             # 0 오른쪽, 1 아래, 2 왼쪽, 3 위
var size := Vector2i.ONE     # 회전이 반영된 크기
var power_net = null         # 전력망 (Dictionary) 또는 null
var water_net = null
var out_links: Array = []    # 자동으로 밀어낼 수 있는 [레일, 내 칸]
var status: String = ""      # 정보 패널에 보여줄 상태
var _push_cd := 0.0
var _push_index := 0


func setup(p_factory, p_def: Dictionary, p_pos: Vector2i, p_rot: int) -> void:
	factory = p_factory
	def = p_def
	name = def["name"]
	kind = def["kind"]
	pos = p_pos
	rot = p_rot
	var s: Vector2i = def["size"]
	size = Vector2i(s.y, s.x) if rot % 2 == 1 else s
	_init_state()


func _init_state() -> void:
	pass


# ---------- 위치 ----------

func cells() -> Array:
	var out := []
	for y in size.y:
		for x in size.x:
			out.append(pos + Vector2i(x, y))
	return out


func has_cell(c: Vector2i) -> bool:
	return c.x >= pos.x and c.y >= pos.y and c.x < pos.x + size.x and c.y < pos.y + size.y


func dir_vec() -> Vector2i:
	return DIRV[rot]


func front_cell() -> Vector2i:
	return pos + DIRV[rot]


func back_cell() -> Vector2i:
	return pos - DIRV[rot]


func right_cell() -> Vector2i:
	return pos + DIRV[(rot + 1) % 4]


func left_cell() -> Vector2i:
	return pos + DIRV[(rot + 3) % 4]


func is_conveyor() -> bool:
	## 레일처럼 방향을 가지고 물건을 앞으로 보내는 1칸 설비
	return false


# ---------- 물건 주고받기 ----------

func try_insert(_item: Item, _from_cell: Vector2i) -> bool:
	return false


func try_extract() -> Item:
	return null


func push_to(cell: Vector2i, item: Item) -> bool:
	## 내 칸(pos)에서 옆 칸 cell로 물건을 넘겨요
	var t = factory.get_at(cell)
	if t == null or t == self:
		return false
	return t.try_insert(item, pos if size == Vector2i.ONE else _nearest_own_cell(cell))


func _nearest_own_cell(cell: Vector2i) -> Vector2i:
	for c in cells():
		var d: Vector2i = cell - c
		if absi(d.x) + absi(d.y) == 1:
			return c
	return pos


func refresh_links() -> void:
	## 내 둘레에서 '나에게서 멀어지는 방향'인 레일을 찾아 둬요 (자동 출력용)
	out_links.clear()
	if size == Vector2i.ONE and is_conveyor():
		return
	for c in cells():
		for d in DIRV:
			var n: Vector2i = c + d
			if has_cell(n):
				continue
			var b = factory.get_at(n)
			if b != null and b.is_conveyor() and b.size == Vector2i.ONE and b.dir_vec() == d and b.accepts_auto_output():
				out_links.append([b, c])


func accepts_auto_output() -> bool:
	return false


func auto_push(item: Item) -> bool:
	## 둘레의 바깥쪽 레일로 차례로 밀어내기
	if out_links.is_empty():
		return false
	for i in out_links.size():
		var k := (_push_index + i) % out_links.size()
		var link = out_links[k]
		if link[0].try_insert(item, link[1]):
			_push_index = k + 1
			return true
	return false


func pump_outputs(dt: float) -> void:
	## 출력 버퍼에 있는 물건을 0.1초마다 하나씩 자동 출력
	_push_cd -= dt
	if _push_cd > 0.0 or out_links.is_empty():
		return
	_push_cd = 0.1
	var it := peek_output()
	if it != null and auto_push(it):
		pop_output()


func peek_output() -> Item:
	return null


func pop_output() -> void:
	pass


# ---------- 전력 ----------

func power_demand() -> float:
	return 0.0


func power_supply() -> float:
	return 0.0


func needs_power() -> bool:
	return float(def.get("power", 0.0)) > 0.0


func power_mult() -> float:
	if not needs_power():
		return 1.0
	if power_net == null:
		return 0.0
	return power_net["sat"]


# ---------- 저장 ----------

func save_state() -> Dictionary:
	## 설비별 설정만 저장해요 (안에 든 물건은 아직 저장하지 않아요)
	return {}


func load_state(_d: Dictionary) -> void:
	pass


# ---------- 진행 ----------

func tick(_dt: float) -> void:
	pass


func info() -> String:
	var s := name
	if needs_power():
		if power_net == null:
			s += "\n전력: 연결 안 됨"
		else:
			s += "\n전력: %d%%" % int(round(power_mult() * 100.0))
	if status != "":
		s += "\n" + status
	return s
