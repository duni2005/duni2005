class_name FloorItems
extends RefCounted
## 바닥에 떨어진 아이템 목록. 시뮬레이션(레일·설비)에는 영향이 없고 이동도 막지 않아요.
## 같은 칸·같은 아이템은 하나로 합쳐 노드 수를 줄여요 (내용물이 있는 박스·택배는 합치지 않아요).
## 한 줄: {id, n, item, pos(칸 단위 Vector2), delay(주울 수 없는 남은 초), uid}

signal spawned(drop, from_pos)   # 화면이 '튀어 흩어지는' 연출을 할 때 써요

const SCATTER_MIN := 0.25        # 떨어질 때 흩어지는 거리 (칸)
const SCATTER_MAX := 0.55

var drops: Array = []
var revision := 0                # 생기거나 없어질 때마다 늘어요
var _uid := 0
var _rng := RandomNumberGenerator.new()


func spawn(item, n: int, origin: Vector2, delay: float = 0.0, scatter: bool = true) -> Dictionary:
	## origin(칸 단위) 근처에 떨어뜨려요. 같은 칸에 같은 아이템이 있으면 합쳐요
	var id: String = item.id if item is Item else str(item)
	var unique: bool = item is Item and not item.is_plain()
	var pos := origin
	if scatter:
		pos += Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(SCATTER_MIN, SCATTER_MAX)
	var cell := Vector2i(pos.floor())
	if not unique:
		for d in drops:
			if d["id"] == id and d["item"] == null and Vector2i(d["pos"].floor()) == cell:
				d["n"] += n
				d["delay"] = maxf(d["delay"], delay)
				revision += 1
				return d
	_uid += 1
	var drop := {"id": id, "n": n, "item": item if unique else null, "pos": pos, "delay": delay, "uid": _uid}
	drops.append(drop)
	revision += 1
	spawned.emit(drop, origin)
	return drop


func item_of(d: Dictionary):
	## 인벤토리에 넣을 때 쓰는 값: 쌓는 물건이면 이름, 아니면 그 Item
	return d["item"] if d["item"] != null else d["id"]


func remove(d: Dictionary) -> void:
	drops.erase(d)
	revision += 1


func set_count(d: Dictionary, n: int) -> void:
	if n <= 0:
		remove(d)
	else:
		d["n"] = n
		revision += 1


func clear() -> void:
	drops.clear()
	revision += 1


func to_save() -> Array:
	var out := []
	for d in drops:
		out.append({"id": d["id"], "n": d["n"], "pos": [d["pos"].x, d["pos"].y], "item": ItemIO.to_dict(d["item"]) if d["item"] != null else null})
	return out


func load_save(arr) -> void:
	clear()
	if not (arr is Array):
		return
	for e in arr:
		if not (e is Dictionary):
			continue
		var it = e.get("item")
		var p: Array = e.get("pos", [0, 0])
		_uid += 1
		drops.append({"id": str(e["id"]), "n": int(e["n"]), "item": ItemIO.from_dict(it) if it is Dictionary else null,
			"pos": Vector2(float(p[0]), float(p[1])), "delay": 0.0, "uid": _uid})
	revision += 1
