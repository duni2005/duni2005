extends Node2D
## 바닥 아이템 층: factory.floor_items를 한 노드의 _draw로 한꺼번에 그려요 (화면 밖은 건너뛰어요).
## 떨어질 때 살짝 튀어 흩어지고, 바닥에선 천천히 둥실거려요. 위치는 drop["pos"](칸 단위)를 따라가요
## (플레이어가 끌어당기면 그쪽으로). 읽기만 해요.

const TILE := 32.0
const ICON := 16.0         # 아이콘 크기 (8×8 도트 2배)
const HOP_SEC := 0.35      # 튀는 시간
const HOP_HEIGHT := 14.0
const BOB := 2.0           # 둥실거림 높이
const BOB_SPEED := 3.0
const FOLLOW := 18.0       # 끌려갈 때 따라가는 빠르기

var world = null
var _anim := {}            # uid -> {p: 그리는 위치(px), from, hop, t}
var _spawn_from := {}      # uid -> 떨어지기 시작한 위치 (튀는 연출)
var _t := 0.0


func _ready() -> void:
	world.factory.floor_items.spawned.connect(func(d, from) -> void: _spawn_from[d["uid"]] = from)


func _process(dt: float) -> void:
	_t += dt
	var fl: FloorItems = world.factory.floor_items
	var alive := {}
	for d in fl.drops:
		var uid: int = d["uid"]
		alive[uid] = true
		var target: Vector2 = d["pos"] * TILE
		if not _anim.has(uid):
			var from: Vector2 = _spawn_from.get(uid, d["pos"]) * TILE
			_anim[uid] = {"p": from, "from": from, "hop": 0.0 if _spawn_from.has(uid) else HOP_SEC, "t": randf() * TAU}
		var a: Dictionary = _anim[uid]
		if a["hop"] < HOP_SEC:
			a["hop"] += dt
			a["p"] = a["from"].lerp(target, clampf(a["hop"] / HOP_SEC, 0.0, 1.0))
		else:
			a["p"] = a["p"].lerp(target, 1.0 - exp(-FOLLOW * dt))
	_spawn_from.clear()
	var gone := _anim.size() != alive.size()
	if gone:
		for uid in _anim.keys():
			if not alive.has(uid):
				_anim.erase(uid)
	if not fl.drops.is_empty() or gone:
		queue_redraw()   # 바닥 아이템이 없으면 다시 그리지 않아요


func _draw() -> void:
	## 그림자 → 아이콘 → 개수 순서로 한꺼번에 (섞어 그리면 그리기 묶음이 끊겨 폰에서 느려져요)
	var fl: FloorItems = world.factory.floor_items
	var vis: Rect2 = world.visible_rect()
	var shown := []   # [위치, 들림, drop]
	for d in fl.drops:
		var a: Dictionary = _anim.get(d["uid"], {})
		if a.is_empty() or not vis.has_point(a["p"]):
			continue
		var hop := 0.0
		if a["hop"] < HOP_SEC:
			hop = sin(PI * clampf(a["hop"] / HOP_SEC, 0.0, 1.0)) * HOP_HEIGHT
		shown.append([a["p"], hop + (sin((_t + a["t"]) * BOB_SPEED) + 1.0) * 0.5 * BOB, d])
	var shadow := Color(0, 0, 0, 0.35)
	for e in shown:
		# 납작한 도트 그림자: 사각형 두 개 (원·다각형은 하나하나 따로 그려져 폰에서 느려요)
		var c: Vector2 = e[0] + Vector2(0, 3)
		draw_rect(Rect2(c - Vector2(6, 1), Vector2(12, 2)), shadow)
		draw_rect(Rect2(c - Vector2(4, 2), Vector2(8, 1)), shadow)
		draw_rect(Rect2(c + Vector2(-4, 1), Vector2(8, 1)), shadow)
	for e in shown:
		var tex := Art.item_icon(e[2]["id"], 8)
		var ts := tex.get_size()
		var k := ICON / maxf(ts.x, ts.y)
		draw_texture_rect(tex, Rect2(e[0] + Vector2(-ts.x * k * 0.5, -ts.y * k - e[1]), ts * k), false)
	var font := ThemeDB.fallback_font
	for e in shown:
		var n: int = e[2]["n"]
		if n > 1:
			var q: Vector2 = e[0] + Vector2(-2, 2 - e[1])
			draw_string_outline(font, q, str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Palette.c(Palette.INK))
			draw_string(font, q, str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Palette.c(Palette.PAPER))
