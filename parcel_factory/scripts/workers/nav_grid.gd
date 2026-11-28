extends RefCounted
## 직원 길 찾기 격자 (AStarGrid2D, 방 안쪽 칸). 막힘 = 벽 + 레일이 아닌 설비, 레일 계열 위는 지나가요
## (플레이어 충돌 world_collision.gd와 같은 규칙). 대각선 이동은 하지 않아요(모서리에 걸리지 않게).
## factory.cells_changed(칸 목록)를 받아 그 칸만 다시 정해요 (빈 목록 = 전부). 시뮬레이션은 읽기만 해요.

var factory: Factory = null
var astar := AStarGrid2D.new()
var region := Rect2i()
var updates := 0          # 칸을 다시 정한 횟수 (테스트용)


func setup(f: Factory) -> void:
	factory = f
	region = f.room.interior() if f.room != null else Rect2i(-64, -64, 128, 128)
	astar.region = region
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()
	refresh_all()
	f.cells_changed.connect(_on_cells_changed)


func _on_cells_changed(cells: Array) -> void:
	if cells.is_empty():
		refresh_all()
		return
	for c in cells:
		refresh(c)


func refresh_all() -> void:
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			refresh(Vector2i(x, y))


func refresh(c: Vector2i) -> void:
	if not region.has_point(c):
		return
	astar.set_point_solid(c, not _walkable(c))
	updates += 1


func _walkable(c: Vector2i) -> bool:
	if factory.room != null and factory.room.terrain_at(c) == Room.T.WALL:
		return false
	var b = factory.get_at(c)
	return b == null or b.is_conveyor()


func walkable(c: Vector2i) -> bool:
	return region.has_point(c) and not astar.is_point_solid(c)


func path(from: Vector2i, to: Vector2i) -> Array:
	## 칸 목록 (from 다음 칸부터 to까지). 길이 없으면 빈 목록, 이미 도착이면 [to]
	if not walkable(to):
		return []
	if from == to:
		return [to]
	var start := from
	if not walkable(start):
		start = nearest_walkable(from)
		if start == Vector2i(-99999, -99999):
			return []
	var pts: Array[Vector2i] = astar.get_id_path(start, to)
	if pts.is_empty():
		return []
	var out := []
	for p in pts:
		out.append(p)
	if out.size() > 1 and out[0] == from:
		out.pop_front()
	return out


func nearest_walkable(c: Vector2i) -> Vector2i:
	## 설비가 발밑에 생겼을 때 등: 가장 가까운 걸을 수 있는 칸
	for r in range(1, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if walkable(n):
					return n
	return Vector2i(-99999, -99999)


func spots_next_to(b) -> Array:
	## 설비 둘레에서 서 있을 수 있는 칸들 (설비 바로 옆)
	var out := []
	for y in range(b.pos.y - 1, b.pos.y + b.size.y + 1):
		for x in range(b.pos.x - 1, b.pos.x + b.size.x + 1):
			var c := Vector2i(x, y)
			if b.has_cell(c):
				continue
			var inside_x: bool = x >= b.pos.x and x < b.pos.x + b.size.x
			var inside_y: bool = y >= b.pos.y and y < b.pos.y + b.size.y
			if (inside_x or inside_y) and walkable(c):
				out.append(c)
	return out
