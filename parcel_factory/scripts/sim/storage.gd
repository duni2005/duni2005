class_name StorageBlock
extends Building
## 창고 블록: 20개씩 보관. 붙어 있는 창고 블록은 하나로 합쳐져요(용량 합산).
## 섞어 보관하고, 들어온 순서대로 나와요.

class Group:
	var items: Array = []
	var cap: int = 20
	var members: Array = []


var group: Group = null


func _init_state() -> void:
	group = Group.new()
	group.members = [self]


func try_insert(it: Item, _from_cell: Vector2i) -> bool:
	if group.items.size() >= group.cap:
		return false
	group.items.append(it)
	return true


func try_extract() -> Item:
	if group.items.is_empty():
		return null
	return group.items.pop_front()


func info() -> String:
	var counts := {}
	for it in group.items:
		counts[it.id] = counts.get(it.id, 0) + 1
	var parts := []
	for k in counts:
		parts.append("%s %d" % [k, counts[k]])
	return super.info() + "\n블록 %d개, %d / %d\n%s" % [group.members.size(), group.items.size(), group.cap, ", ".join(parts)]


func has_output() -> bool:
	return not group.items.is_empty()


func accepts(_id: String) -> bool:
	return true


func get_slots() -> Array:
	return _grouped(group.items, "store", group.cap)


func extract_slot(index: int, n: int) -> Array:
	return _take_grouped(group.items, "store", index, n)


func _grouped(list: Array, kind: String, cap: int) -> Array:
	## 같은 물건끼리 한 칸으로 (내용물이 있는 물건은 하나씩)
	var out := []
	var at := {}
	for it in list:
		if not it.is_plain():
			out.append(Building.slot(kind, it.id, 1, cap, it))
		elif at.has(it.id):
			out[at[it.id]]["count"] += 1
		else:
			at[it.id] = out.size()
			out.append(Building.slot(kind, it.id, 1, cap))
	return out


func _take_grouped(list: Array, kind: String, index: int, n: int) -> Array:
	var s := _grouped(list, kind, 0)
	if index < 0 or index >= s.size():
		return []
	var out := []
	if s[index]["item"] != null:
		list.erase(s[index]["item"])
		return [s[index]["item"]]
	var id: String = s[index]["item_id"]
	for it in list.duplicate():
		if out.size() >= n:
			break
		if it.id == id and it.is_plain():
			list.erase(it)
			out.append(it)
	return out
