class_name Inventory
extends RefCounted
## 플레이어 가방. 칸(slot)마다 같은 물건을 STACK개까지 쌓아요.
## 내용물·요청서가 붙은 물건(박스·택배·요청서)은 쌓지 않고 칸 하나에 그 물건 그대로 넣어 둬요.

signal changed

const SLOTS := 30
const STACK := 50

var slots: Array = []   # [{id, n, item}] item: 쌓지 않는 물건일 때만 Item, 아니면 null


func add(it: Item) -> bool:
	if not it.is_plain():
		if slots.size() >= SLOTS:
			return false
		slots.append({"id": it.id, "n": 1, "item": it})
		changed.emit()
		return true
	return add_id(it.id, 1) == 1


func add_id(id: String, n: int) -> int:
	## 최대 n개를 넣고, 실제로 넣은 개수를 돌려줘요
	var left := n
	for s in slots:
		if left <= 0:
			break
		if s["id"] == id and s["item"] == null and s["n"] < STACK:
			var k := mini(left, STACK - int(s["n"]))
			s["n"] += k
			left -= k
	while left > 0 and slots.size() < SLOTS:
		var k := mini(left, STACK)
		slots.append({"id": id, "n": k, "item": null})
		left -= k
	if left != n:
		changed.emit()
	return n - left


func can_add(it: Item) -> bool:
	if slots.size() < SLOTS:
		return true
	if not it.is_plain():
		return false
	for s in slots:
		if s["id"] == it.id and s["item"] == null and s["n"] < STACK:
			return true
	return false


func has_room() -> bool:
	## 빈 칸이 하나라도 있는지 (무엇이든 하나는 들어가요)
	return slots.size() < SLOTS


func copy():
	## 미리 넣어 보기용 사본 (물건 자체는 같이 써요).
	## 자기 class_name을 안에서 부르면 Godot 4.3에서 끌 때 누수로 보고돼서 get_script()로 만들어요
	var c = get_script().new()
	for s in slots:
		c.slots.append(s.duplicate())
	return c


func count(id: String) -> int:
	var n := 0
	for s in slots:
		if s["id"] == id:
			n += int(s["n"])
	return n


func total() -> int:
	var n := 0
	for s in slots:
		n += int(s["n"])
	return n


func take(id: String) -> Item:
	## 하나 꺼내요. 없으면 null (뒤쪽 칸부터 꺼내 앞 칸이 남아요)
	for i in range(slots.size() - 1, -1, -1):
		var s: Dictionary = slots[i]
		if s["id"] != id:
			continue
		var it: Item = s["item"] if s["item"] != null else Item.new(id)
		s["n"] -= 1
		if int(s["n"]) <= 0:
			slots.remove_at(i)
		changed.emit()
		return it
	return null


func clear() -> void:
	slots.clear()
	changed.emit()
