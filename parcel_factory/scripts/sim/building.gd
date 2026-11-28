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
var given := false           # 처음부터 깔린 지급 설비 (철거할 수 없어요)
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


func is_active() -> bool:
	## 지금 일하는 중인지 (화면이 가동 애니메이션을 켤지 정할 때 읽어요)
	return false


func has_output() -> bool:
	## 손으로 꺼낼 결과물이 있는지 (try_extract로 꺼내요)
	return false


func contents() -> Array:
	## 철거할 때 돌려줄 안에 든 물건 목록 (읽기만, 상태는 그대로)
	return []


# ---------- 정보창 칸 (플레이어 손으로 넣고 빼기) ----------
## get_slots() 한 줄: {kind: "in"/"out"/"fuel"/"store", item_id, count, cap, item(내용물 있는 물건이면 그 Item, 아니면 null)}
## 넣기는 try_insert(설비가 어느 칸에 넣을지 정해요), 빼기는 extract_slot(칸 번호, 개수).

func accepts(_id: String) -> bool:
	## 이 아이템을 넣을 수 있는 설비인지 (가득 찬지는 따지지 않아요. 인벤토리를 흐리게 할 때 써요)
	return false


func get_slots() -> Array:
	return []


func extract_slot(_index: int, _n: int) -> Array:
	return []


static func slot(kind: String, id: String, count: int, cap: int, item = null) -> Dictionary:
	return {"kind": kind, "item_id": id, "count": count, "cap": cap, "item": item}


static func list_slot(kind: String, list: Array, cap: int, default_id: String) -> Dictionary:
	## Item 목록으로 된 칸 (박스·택배처럼 하나하나 다를 수 있는 것)
	var first: Item = list[0] if not list.is_empty() else null
	return slot(kind, first.id if first != null else default_id, list.size(), cap, first if first != null and not first.is_plain() else null)


static func take_front(list: Array, n: int) -> Array:
	var out := []
	while out.size() < n and not list.is_empty():
		out.append(list.pop_front())
	return out


static func items_of(id: String, n: int) -> Array:
	var out := []
	for i in n:
		out.append(Item.new(id))
	return out


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
