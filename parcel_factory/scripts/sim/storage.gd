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
