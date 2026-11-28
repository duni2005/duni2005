extends Node2D
## 바닥에 떨어진 아이템 하나: 아이콘 + 개수. 떨어질 때 살짝 튀어 흩어지고, 바닥에선 천천히 둥실거려요.
## 위치는 drop["pos"](칸 단위)를 따라가요 (플레이어가 끌어당기면 그쪽으로). 읽기만 해요.

const TILE := 32.0
const ICON := 16.0         # 아이콘 크기 (8×8 도트 2배)
const HOP_SEC := 0.35      # 튀는 시간
const HOP_HEIGHT := 14.0
const BOB := 2.0           # 둥실거림 높이
const BOB_SPEED := 3.0
const FOLLOW := 18.0       # 끌려갈 때 따라가는 빠르기

var drop: Dictionary = {}
var _from := Vector2.ZERO
var _hop_t := HOP_SEC
var _t := 0.0


func start(from_cells: Vector2) -> void:
	_from = from_cells * TILE
	position = _from
	_hop_t = 0.0
	_t = randf() * TAU


func _process(dt: float) -> void:
	_t += dt
	var target: Vector2 = drop["pos"] * TILE
	if _hop_t < HOP_SEC:
		_hop_t += dt
		var k := clampf(_hop_t / HOP_SEC, 0.0, 1.0)
		position = _from.lerp(target, k)
	else:
		position = position.lerp(target, 1.0 - exp(-FOLLOW * dt))
	queue_redraw()


func _draw() -> void:
	var hop := 0.0
	if _hop_t < HOP_SEC:
		hop = sin(PI * clampf(_hop_t / HOP_SEC, 0.0, 1.0)) * HOP_HEIGHT
	var lift := hop + (sin(_t * BOB_SPEED) + 1.0) * 0.5 * BOB
	# 그림자
	draw_set_transform(Vector2(0, 3), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 6.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var tex := Art.item_icon(drop["id"], 8)
	var ts := tex.get_size()
	var k := ICON / maxf(ts.x, ts.y)
	var r := Rect2(Vector2(-ts.x * k * 0.5, -ts.y * k - lift), ts * k)
	draw_texture_rect(tex, r, false)
	var n: int = drop["n"]
	if n > 1:
		var font := ThemeDB.fallback_font
		var p := Vector2(-2, 2 - lift)
		draw_string_outline(font, p, str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Palette.c(Palette.INK))
		draw_string(font, p, str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Palette.c(Palette.PAPER))
