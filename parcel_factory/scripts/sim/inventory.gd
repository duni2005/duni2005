class_name Inventory
extends RefCounted
## 플레이어 인벤토리: 핫바 HOTBAR칸(0~) + 가방 BAG칸. 칸 수는 상수라 나중에 가방을 늘리기 쉬워요.
##
## 다른 기능(설비 정보창·바닥 아이템·설치 등)은 아래 네 함수로만 인벤토리를 바꿔요.
##   add(item, n) -> 못 넣은 수     item: 아이템 이름(String) 또는 Item (내용물이 있는 박스·택배는 1칸 1개)
##   remove(id, n, prefer) -> 꺼낸 Item 목록
##   count(id) -> 개수
##   can_accept(item) -> 하나라도 들어가는지
## 칸끼리 옮기기·나누기·빠른 이동(move_slot·split_slot·quick_move·take_slot)은 인벤토리 화면 전용이에요.

signal changed

const HOTBAR := 9
const BAG := 27
const SLOTS := HOTBAR + BAG
const STACK_ITEM := 50          # 일반 아이템
const STACK_BUILDING := 20      # 설비 아이템
const STACK_LINE := 100         # 레일·전선·파이프
const LINE_ITEMS := ["[설비] 레일 Mk1", "[설비] 레일 Mk2", "[설비] 레일 Mk3", "[설비] 전선", "[설비] 파이프"]

var slots: Array = []   # SLOTS칸, 빈 칸은 null, 아니면 {id, n, item} (item: 쌓지 않는 물건일 때만 Item)


func _init() -> void:
	slots.resize(SLOTS)


static func stack_limit(id: String) -> int:
	if id in LINE_ITEMS:
		return STACK_LINE
	if id.begins_with("[설비]"):
		return STACK_BUILDING
	return STACK_ITEM


static func _unique(item) -> bool:
	## 내용물·요청서가 있는 물건은 쌓지 않아요
	return item is Item and not item.is_plain()


static func _id_of(item) -> String:
	return item.id if item is Item else str(item)


# ---------- 공개 함수 ----------

func add(item, n: int = 1) -> int:
	## n개를 넣고 못 넣은 수를 돌려줘요. 이미 있는 묶음부터 채우고, 빈 칸은 핫바 → 가방 순서
	var id := _id_of(item)
	var left := n
	if _unique(item):
		while left > 0:
			var e := _first_empty()
			if e < 0:
				break
			slots[e] = {"id": id, "n": 1, "item": item}
			left -= 1
	else:
		var lim := stack_limit(id)
		for i in SLOTS:
			if left <= 0:
				break
			var s = slots[i]
			if s != null and s["id"] == id and s["item"] == null and s["n"] < lim:
				var k := mini(left, lim - int(s["n"]))
				s["n"] += k
				left -= k
		while left > 0:
			var e := _first_empty()
			if e < 0:
				break
			var k := mini(left, lim)
			slots[e] = {"id": id, "n": k, "item": null}
			left -= k
	if left != n:
		changed.emit()
	return left


func remove(id: String, n: int = 1, prefer: int = -1) -> Array:
	## 최대 n개를 꺼내 Item 목록으로 돌려줘요. prefer 칸(손에 든 칸)부터, 그다음 뒤 칸부터
	var out := []
	var order := []
	if prefer >= 0 and prefer < SLOTS:
		order.append(prefer)
	for i in range(SLOTS - 1, -1, -1):
		if i != prefer:
			order.append(i)
	for i in order:
		if out.size() >= n:
			break
		var s = slots[i]
		if s == null or s["id"] != id:
			continue
		while out.size() < n and int(s["n"]) > 0:
			out.append(s["item"] if s["item"] != null else Item.new(id))
			s["n"] -= 1
		if int(s["n"]) <= 0:
			slots[i] = null
	if not out.is_empty():
		changed.emit()
	return out


func count(id: String) -> int:
	var n := 0
	for s in slots:
		if s != null and s["id"] == id:
			n += int(s["n"])
	return n


func can_accept(item) -> bool:
	if _first_empty() >= 0:
		return true
	if _unique(item):
		return false
	var id := _id_of(item)
	var lim := stack_limit(id)
	for s in slots:
		if s != null and s["id"] == id and s["item"] == null and s["n"] < lim:
			return true
	return false


# ---------- 읽기 도우미 ----------

func id_at(i: int) -> String:
	return "" if i < 0 or i >= SLOTS or slots[i] == null else slots[i]["id"]


func item_at(i: int) -> Item:
	## 그 칸의 물건 하나 (쌓는 물건이면 새 Item, 아니면 보관된 그 Item)
	if id_at(i) == "":
		return null
	var s: Dictionary = slots[i]
	return s["item"] if s["item"] != null else Item.new(s["id"])


func total() -> int:
	var n := 0
	for s in slots:
		if s != null:
			n += int(s["n"])
	return n


func used_slots() -> int:
	var n := 0
	for s in slots:
		if s != null:
			n += 1
	return n


func clear() -> void:
	slots.clear()
	slots.resize(SLOTS)
	changed.emit()


func _first_empty(from: int = 0, to: int = SLOTS) -> int:
	for i in range(from, to):
		if slots[i] == null:
			return i
	return -1


# ---------- 인벤토리 화면 전용 ----------

func move_slot(a: int, b: int) -> void:
	## a칸을 b칸으로: 같은 물건이면 합치고(넘치면 a에 남겨요), 아니면 자리를 바꿔요
	if a == b or slots[a] == null:
		return
	var sa: Dictionary = slots[a]
	var sb = slots[b]
	if sb != null and sb["id"] == sa["id"] and sa["item"] == null and sb["item"] == null:
		var k := mini(int(sa["n"]), stack_limit(sa["id"]) - int(sb["n"]))
		sb["n"] += k
		sa["n"] -= k
		if int(sa["n"]) <= 0:
			slots[a] = null
	else:
		slots[a] = sb
		slots[b] = sa
	changed.emit()


func split_slot(i: int) -> int:
	## 묶음을 반으로 나눠 빈 칸(가방 먼저)에 놓아요. 놓은 칸 번호 (못 나누면 -1)
	var s = slots[i]
	if s == null or int(s["n"]) < 2:
		return -1
	var e := _first_empty(HOTBAR, SLOTS)
	if e < 0:
		e = _first_empty(0, HOTBAR)
	if e < 0:
		return -1
	var half := int(int(s["n"]) / 2.0)
	s["n"] -= half
	slots[e] = {"id": s["id"], "n": half, "item": null}
	changed.emit()
	return e


func quick_move(i: int) -> void:
	## 핫바 ↔ 가방 빠른 이동 (Shift+클릭): 반대쪽의 같은 묶음부터 채우고 빈 칸으로
	var s = slots[i]
	if s == null:
		return
	var from := HOTBAR if i < HOTBAR else 0
	var to := SLOTS if i < HOTBAR else HOTBAR
	if s["item"] == null:
		var lim := stack_limit(s["id"])
		for j in range(from, to):
			var t = slots[j]
			if t != null and t["id"] == s["id"] and t["item"] == null and t["n"] < lim:
				var k := mini(int(s["n"]), lim - int(t["n"]))
				t["n"] += k
				s["n"] -= k
				if int(s["n"]) <= 0:
					slots[i] = null
					changed.emit()
					return
	var e := _first_empty(from, to)
	if e >= 0:
		slots[e] = s
		slots[i] = null
	changed.emit()


func take_slot(i: int) -> Array:
	## 한 칸을 통째로 꺼내요 (창 밖으로 끌어 버리기): Item 목록
	var s = slots[i]
	if s == null:
		return []
	return remove(s["id"], int(s["n"]), i)


# ---------- 저장 ----------

func to_save() -> Array:
	var out := []
	for s in slots:
		if s == null:
			out.append(null)
		else:
			out.append({"id": s["id"], "n": s["n"], "item": ItemIO.to_dict(s["item"]) if s["item"] != null else null})
	return out


func load_save(arr) -> void:
	clear()
	if not (arr is Array):
		return
	for i in mini(arr.size(), SLOTS):
		var e = arr[i]
		if e is Dictionary:
			var it = e.get("item")
			slots[i] = {"id": str(e["id"]), "n": int(e["n"]), "item": ItemIO.from_dict(it) if it is Dictionary else null}
	changed.emit()
