extends Node2D
## 설비 위 작은 표시: 전력 등(초록·노랑·빨강), 레시피 결과물 아이콘, 진행 막대,
## 공급기·감지기·분류기가 고른 아이템, 선택 테두리, 설치 고스트. 시뮬레이션 상태는 읽기만 해요.

const TILE := 32.0
const LAMP := 6.0        # 전력 등 크기 (3도트)
const ICON := 16.0       # 8×8 아이콘 2배
const BAR := 2.0         # 진행 막대 두께 (1도트)
const GHOST_ALPHA := 0.55
const REFRESH_SEC := 0.1   # 전력 등·진행 막대는 0.1초마다 (고스트·선택이 바뀌면 바로)

var world = null
var _t := 0.0
var _last_ui := []


func _process(dt: float) -> void:
	_t += dt
	var ui := [world.ghost.duplicate(), world.selected, world.buildings.revision]
	if _t >= REFRESH_SEC or ui != _last_ui:
		_t = 0.0
		_last_ui = ui
		queue_redraw()


func _draw() -> void:
	var f: Factory = world.factory
	var vis: Rect2 = world.visible_rect()
	var items := Art.tex("items8")
	# 목록: [설비, 칸 사각형] — 레일이 아닌 설비만 (building_layer가 설치·철거 때만 다시 만들어요)
	for e in world.buildings.others:
		var r: Rect2 = e[1]
		if not vis.intersects(r):
			continue
		var b = e[0]
		if b.needs_power():
			var m: float = b.power_mult()
			_lamp(r, Palette.RED if m <= 0.0 else (Palette.YELLOW if m < 1.0 else Palette.GREEN))
		elif b is Generator:
			_lamp(r, Palette.GREEN if b.running() else Palette.RED)
		var icon := ""
		if b is Machine and b.recipe != null:
			icon = b.recipe["out"].keys()[0]
			var bp: float = b.progress
			var bt: float = b.recipe["t"]
			if bp > 0.0:
				draw_rect(Rect2(r.position + Vector2(4, r.size.y - 4), Vector2((r.size.x - 8) * clampf(bp / bt, 0.0, 1.0), BAR)), Palette.c(Palette.LIME))
		elif b is InfiniteSource:
			icon = b.item_id
		elif b is Detector or b is Sorter:
			icon = b.selected if b is Detector else b.filter_item
		if icon != "":
			var ir := Rect2(r.end - Vector2(ICON + 2, ICON + 2), Vector2(ICON, ICON))
			draw_rect(ir.grow(1), Color(Palette.c(Palette.INK), 0.7))
			draw_texture_rect_region(items, ir, Art.item_region(icon, 8))
	if world.selected != null and f.buildings.has(world.selected):
		var s = world.selected
		draw_rect(world.cell_rect(s.pos, s.size).grow(1), Palette.c(Palette.LIGHT), false, 2.0)
	_draw_ghost()


func _lamp(r: Rect2, ci: int) -> void:
	var p := r.position + Vector2(3, 3)
	draw_rect(Rect2(p - Vector2(1, 1), Vector2(LAMP + 2, LAMP + 2)), Palette.c(Palette.INK))
	draw_rect(Rect2(p, Vector2(LAMP, LAMP)), Palette.c(ci))


func _draw_ghost() -> void:
	var g: Dictionary = world.ghost
	if g.is_empty():
		return
	var def: Dictionary = g["def"]
	var rot: int = g["rot"]
	var s: Vector2i = def["size"]
	var fs := Vector2i(s.y, s.x) if rot % 2 == 1 else s
	var r: Rect2 = world.cell_rect(g["pos"], fs)
	var tint := Palette.c(Palette.LIME) if g["ok"] else Palette.c(Palette.RED)
	var key := Art.building_key(def["name"])
	if key == "" or key == "trash_heap":
		draw_rect(r, Color(tint, 0.4))
	else:
		var tex := Art.tex(key)
		var fw := float(tex.get_width()) / SpriteGen.FRAMES
		var fh := float(tex.get_height()) / Art.vframes(key)
		var row := 0
		var angle := 0.0
		if key.begins_with("rail_"):
			row = rot
		elif key in Art.DIRECTIONAL:
			angle = rot * PI * 0.5
		var size := Vector2(s) * TILE
		draw_set_transform(r.get_center(), angle, Vector2.ONE)
		draw_texture_rect_region(tex, Rect2(-size * 0.5, size), Rect2(0, row * fh, fw, fh), Color(tint, GHOST_ALPHA))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(r, tint, false, 2.0)
