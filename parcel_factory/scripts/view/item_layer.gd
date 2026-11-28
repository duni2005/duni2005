extends Node2D
## 레일 위 물건을 한 노드의 _draw로 한꺼번에 그려요 (8×8 아이콘 아틀라스 한 장이라 묶어서 그려져요).
## 손으로 꺼낸 물건이 튀어나오는 연출도 여기서 그려요. 시뮬레이션 상태는 읽기만 해요.

const TILE := 32.0
const ICON := 16.0            # 8×8 도트를 2배로
const PATH := 0.8             # 칸 안에서 물건이 움직이는 거리 비율
const POP_SEC := 0.9
const POP_GRAVITY := 900.0
const POP_SPEED := 260.0

var world = null
var _pops: Array = []        # [{p, v, t, id}]


func _ready() -> void:
	world.factory.items_popped.connect(_on_items_popped)


func _process(dt: float) -> void:
	for pop in _pops:
		var v: Vector2 = pop["v"]
		v.y += POP_GRAVITY * dt
		pop["v"] = v
		pop["p"] += v * dt
		pop["t"] += dt
	_pops = _pops.filter(func(pp) -> bool: return pp["t"] < POP_SEC)
	queue_redraw()


func _on_items_popped(_pile, cell: Vector2i, popped: Array) -> void:
	var i := 0
	for it in popped:
		var ang := -PI * 0.5 + (float(i) - float(popped.size() - 1) * 0.5) * 0.45
		_pops.append({"p": world.cell_center(cell), "v": Vector2(cos(ang), sin(ang)) * POP_SPEED, "t": 0.0, "id": it.id})
		i += 1


func _draw() -> void:
	var tex := Art.tex("items8")
	var vis: Rect2 = world.visible_rect()
	var paper := Palette.c(Palette.PAPER)
	var done := Palette.c(Palette.LIME)
	var half := Vector2(ICON, ICON) * 0.5
	var size := Vector2(ICON, ICON)
	var step := TILE * PATH
	# 목록: [설비, 칸 가운데, 들어오는 방향, 나가는 방향] (building_layer가 설치·철거 때만 다시 만들어요)
	for e in world.buildings.conveyors:
		var it: Item = e[0].item
		if it == null:
			continue
		var c: Vector2 = e[1]
		if not vis.has_point(c):
			continue
		var prog: float = e[0].progress
		var p: Vector2
		if prog < 0.5:
			p = c - e[2] * ((0.5 - prog) * step)
		else:
			p = c + e[3] * ((prog - 0.5) * step)
		p = p.round()
		draw_texture_rect_region(tex, Rect2(p - half, size), Art.item_region(it.id, 8))
		if it.has_request():
			# 요청서가 붙은 박스: 위에 흰 쪽지 (다 차면 연두)
			draw_rect(Rect2(p + Vector2(-5, -10), Vector2(10, 4)), done if it.request_done() else paper)
	for pop in _pops:
		var t: float = pop["t"]
		var a := 1.0 - clampf((t - POP_SEC * 0.6) / (POP_SEC * 0.4), 0.0, 1.0)
		var pp: Vector2 = pop["p"]
		draw_texture_rect_region(tex, Rect2(pp.round() - Vector2(ICON, ICON) * 0.5, Vector2(ICON, ICON)), Art.item_region(pop["id"], 8), Color(1, 1, 1, a))
