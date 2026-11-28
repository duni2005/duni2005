extends StaticBody2D
## 플레이어가 부딪히는 것: 큰방 벽(정문·복도 포함)과 설비.
## 레일 계열(레일·분류기·분배기 등 벨트 장치)과 전선·파이프·물 샘은 걸어 다닐 수 있어요 (Factorio처럼).
## 설치·철거(factory.revision)가 바뀔 때만 달라진 설비의 충돌 모양을 더하고 빼요. 시뮬레이션은 읽기만 해요.

const TILE := 32.0

var factory: Factory = null
var _rev := -1
var _shapes := {}   # Building -> CollisionShape2D


func _ready() -> void:
	collision_layer = 3   # 1 = 플레이어, 2 = 직원 (직원끼리·플레이어와는 안 부딪혀요)
	if factory.room != null:
		var r: Rect2i = factory.room.interior()
		# 둘레 벽 네 줄 (정문·복도 칸도 벽 줄 위라 함께 막혀요)
		_add_rect(Rect2i(r.position.x - 1, r.position.y - 1, r.size.x + 2, 1))
		_add_rect(Rect2i(r.position.x - 1, r.end.y, r.size.x + 2, 1))
		_add_rect(Rect2i(r.position.x - 1, r.position.y, 1, r.size.y))
		_add_rect(Rect2i(r.end.x, r.position.y, 1, r.size.y))


func _add_rect(cells: Rect2i) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(cells.size) * TILE
	cs.shape = shape
	cs.position = (Vector2(cells.position) + Vector2(cells.size) * 0.5) * TILE
	add_child(cs)
	return cs


func is_solid(b) -> bool:
	return not b.is_conveyor()


func _physics_process(_dt: float) -> void:
	if factory.revision == _rev:
		return
	_rev = factory.revision
	var alive := {}
	for b in factory.buildings:
		if not is_solid(b):
			continue
		alive[b] = true
		if not _shapes.has(b):
			_shapes[b] = _add_rect(Rect2i(b.pos, b.size))
		else:
			var cs: CollisionShape2D = _shapes[b]
			cs.position = (Vector2(b.pos) + Vector2(b.size) * 0.5) * TILE
	for b in _shapes.keys():
		if not alive.has(b):
			_shapes[b].queue_free()
			_shapes.erase(b)
