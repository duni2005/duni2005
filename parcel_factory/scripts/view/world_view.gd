extends Node2D
## 공장 화면 (탑뷰 도트). 시뮬레이션 상태는 읽기만 해요.
## 층 순서 (아래 → 위)
##   바닥 타일(TileMapLayer) → 전선·파이프·물 샘(얇게) → 벽 타일(TileMapLayer) → 방 표시(점선·이름판)
##   → 설비 스프라이트(설비 하나당 Sprite2D) → 레일 위 물건(한 노드 _draw로 일괄) → 표시(전력 등·고스트·선택)
##   → '층 보기'를 켜면 전선·파이프를 진하게 맨 위에 한 번 더

const TILE := 32.0
const TILE_FLOOR_FROM_X := 40     # 이 x부터 정문 쪽은 사무실 타일 바닥
const LIGHT_SPACING := 6          # 형광등 아래 밝은 카펫 간격
const POSTER_EVERY := 13          # 벽 포스터 빈도 (칸)

const RoomOverlay := preload("res://scripts/view/room_overlay.gd")
const LineLayer := preload("res://scripts/view/line_layer.gd")
const BuildingLayer := preload("res://scripts/view/building_layer.gd")
const ItemLayer := preload("res://scripts/view/item_layer.gd")
const MarkerLayer := preload("res://scripts/view/marker_layer.gd")

var factory: Factory = null
var ghost := {}             # {def, pos, rot, ok}
var selected = null         # Building
var show_layers := false    # 켜면 전선·파이프를 진하게

var floor_layer: TileMapLayer
var wall_layer: TileMapLayer
var buildings: Node2D       # BuildingLayer
var items: Node2D           # ItemLayer


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	RenderingServer.set_default_clear_color(Palette.c(Palette.INK).darkened(0.45))
	var ts := _tile_set()
	floor_layer = _tile_layer(ts)
	_add(LineLayer, {"bold": false})
	wall_layer = _tile_layer(ts)
	_add(RoomOverlay, {})
	buildings = _add(BuildingLayer, {})
	items = _add(ItemLayer, {})
	_add(MarkerLayer, {})
	_add(LineLayer, {"bold": true})
	if factory.room != null:
		_fill_room(factory.room)


func _add(script: Script, props: Dictionary) -> Node2D:
	var n: Node2D = script.new()
	n.set("world", self)
	for k in props:
		n.set(k, props[k])
	add_child(n)
	return n


func visible_rect() -> Rect2:
	## 지금 화면에 보이는 월드 영역 (조금 넉넉하게)
	var inv := get_viewport().get_canvas_transform().affine_inverse()
	var a: Vector2 = inv * Vector2.ZERO
	var b: Vector2 = inv * get_viewport_rect().size
	return Rect2(a, b - a).abs().grow(TILE)


func cell_rect(c: Vector2i, s: Vector2i = Vector2i.ONE) -> Rect2:
	return Rect2(Vector2(c) * TILE, Vector2(s) * TILE)


func cell_center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * TILE


# ---------- 바닥·벽 타일 ----------

func _tile_set() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(Art.DOT, Art.DOT)
	var src := TileSetAtlasSource.new()
	src.texture = Art.tex("tiles")
	src.texture_region_size = Vector2i(Art.DOT, Art.DOT)
	for i in SpriteGen.TILES.size():
		src.create_tile(Vector2i(i, 0))
	ts.add_source(src, 0)
	return ts


func _tile_layer(ts: TileSet) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.tile_set = ts
	l.scale = Vector2(Art.SCALE, Art.SCALE)
	add_child(l)
	return l


func _set_tile(l: TileMapLayer, c: Vector2i, tile_name: String) -> void:
	l.set_cell(c, 0, Vector2i(Art.tile_index(tile_name), 0))


func _fill_room(room: Room) -> void:
	var inner := room.interior()
	for y in range(inner.position.y, inner.end.y):
		for x in range(inner.position.x, inner.end.x):
			var c := Vector2i(x, y)
			var t := "carpet_a"
			if room.terrain_at(c) == Room.T.NO_BUILD:
				t = "hazard"
			elif x >= TILE_FLOOR_FROM_X:
				t = "office"
			elif x % LIGHT_SPACING == 3 and y % LIGHT_SPACING == 3:
				t = "carpet_lit"
			else:
				var h := absi(hash(c)) % 13
				t = "carpet_stain" if h == 0 else ("carpet_b" if h < 4 else "carpet_a")
			_set_tile(floor_layer, c, t)
	var ring := inner.grow(1)
	for y in range(ring.position.y, ring.end.y):
		for x in range(ring.position.x, ring.end.x):
			var c := Vector2i(x, y)
			match room.terrain_at(c):
				Room.T.WALL:
					var poster := y == -1 and absi(hash(c)) % POSTER_EVERY == 0
					_set_tile(wall_layer, c, "wall_poster" if poster else "wall")
				Room.T.DOOR:
					_set_tile(wall_layer, c, "door")
				Room.T.CORRIDOR:
					_set_tile(wall_layer, c, "barrier")
	# 복도: 벽 바깥으로 이어지는 어두운 통로와 양옆 벽
	for r in room.corridor_rects():
		var dir := -1 if r.position.y < 0 else 1
		for k in range(1, Room.CORRIDOR_LEN + 1):
			var y: int = r.position.y + dir * k
			for x in range(r.position.x, r.end.x):
				_set_tile(floor_layer, Vector2i(x, y), "corridor")
			_set_tile(wall_layer, Vector2i(r.position.x - 1, y), "corridor_wall")
			_set_tile(wall_layer, Vector2i(r.end.x, y), "corridor_wall")
