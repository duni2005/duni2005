extends Node2D
## 바닥 아이템 층: factory.floor_items의 한 줄마다 ItemDrop 노드 하나.
## 생기고 없어질 때(revision)만 노드를 맞추고, 위치는 각 노드가 따라가요. 읽기만 해요.

const ItemDrop := preload("res://scripts/view/item_drop.gd")

var world = null
var _nodes := {}      # uid -> ItemDrop
var _rev := -1
var _spawn_from := {} # uid -> 떨어지기 시작한 위치 (튀는 연출)


func _ready() -> void:
	world.factory.floor_items.spawned.connect(func(d, from) -> void: _spawn_from[d["uid"]] = from)


func _process(_dt: float) -> void:
	var fl: FloorItems = world.factory.floor_items
	if fl.revision == _rev:
		return
	_rev = fl.revision
	var alive := {}
	for d in fl.drops:
		var uid: int = d["uid"]
		alive[uid] = true
		if _nodes.has(uid):
			_nodes[uid].drop = d
			continue
		var n = ItemDrop.new()
		n.drop = d
		n.start(_spawn_from.get(uid, d["pos"]))
		add_child(n)
		_nodes[uid] = n
	_spawn_from.clear()
	for uid in _nodes.keys():
		if not alive.has(uid):
			_nodes[uid].queue_free()
			_nodes.erase(uid)
