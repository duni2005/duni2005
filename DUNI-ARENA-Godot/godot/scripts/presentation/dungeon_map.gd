class_name DungeonMap
extends Control
## The current floor drawn as an old dungeon map: a parchment sheet with rooms as scattered
## rectangles of different sizes, joined by inked corridors. Once the floor's clear requirement
## is met, a stairway room appears in a free spot. The sheet unrolls sideways when shown.
signal stairs_pressed
signal reward_pressed(depth: int)
## Dark dungeon chart in the game's own navy and gold.
const SHEET := Color("121a2b")
const SHEET_LIGHT := Color("1f2c48")
const LINE := Color("2c3b5e")
const GOLD := Color("c9a560")
const HEADER: float = 58
const PAD: float = 18
var floor_index: int = -1
var shown_depth: int = -1
var chapter: int = 1
var run_id: String = ""
var title: String = ""
var progress: String = ""
var room_cards: Dictionary = {} # room id -> ArenaCard, every floor; only this floor's are shown
var layout_rects: Dictionary = {} # room id or "stairs" -> Rect2(centre in 0..1 sheet space, size in shorter-side units)
var edges: Array = [] # [id, id] corridor pairs
var stairs: ArenaCard
var reward_button: ConquestRewardButton
var stairs_open: bool = false
var stairs_age: float = 0
var unfold: float = 1
var age: float = 0
var stains: Array = []
var layout_cols: int = 0

func _ready() -> void:
	clip_contents = false;mouse_filter = Control.MOUSE_FILTER_PASS
	stairs = ArenaCard.new();stairs.name = "Stairs";stairs.card_type = "stairs";stairs.title = "다음 층";stairs.visible = false
	ArenaUI.bind(stairs, func():stairs_pressed.emit());add_child(stairs)
	reward_button = ConquestRewardButton.new();reward_button.custom_minimum_size = Vector2(0, 30);reward_button.text = "층 정복 보상"
	ArenaUI.bind(reward_button, func():reward_pressed.emit(floor_index));add_child(reward_button)
	resized.connect(_place)

func add_room(id: String, card: ArenaCard) -> void:
	room_cards[id] = card;add_child(card);card.visible = false

## Show one floor. Layout is seeded by run and floor so it never shuffles between visits.
func show_floor(depth: int, ids: Array, run: String) -> void:
	if depth == floor_index and run == run_id:return
	shown_depth = depth;run_id = run;show_floor_ids(ids)
func show_floor_ids(ids: Array) -> void:
	floor_index = shown_depth;var depth: int = shown_depth;var run: String = run_id;layout_rects.clear();edges.clear();stains.clear()
	var rng := RandomNumberGenerator.new();rng.seed = hash("%s:%d" % [run, depth])
	# A grid matched to the sheet's shape, one spare cell, then a shuffle: rooms and the stairway
	# land in different spots every floor but always spread over the whole sheet.
	var keys: Array = ids.duplicate();keys.append("stairs")
	var aspect: float = area().size.x / maxf(1, area().size.y) if area().size.y > 1 else .6
	layout_cols = 2 if aspect < .8 else 4 if aspect > 1.6 else 3
	var rows: int = ceili(float(keys.size() + 1) / layout_cols)
	var cells: Array = range(layout_cols * rows)
	for i in range(cells.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i);var t = cells[i];cells[i] = cells[j];cells[j] = t
	for i in range(keys.size()):
		var cell: int = cells[i];var cx: float = (cell % layout_cols + .5) / layout_cols;var cy: float = (cell / layout_cols + .5) / rows
		var big: bool = keys[i] != "stairs" and room_cards.has(keys[i]) and room_cards[keys[i]].kind in ["boss", "miniboss"]
		# Size in units of the sheet's shorter side, so rooms stay roughly square on any screen.
		var w: float = (rng.randf_range(.24, .32) if not big else .38);var h: float = (rng.randf_range(.2, .28) if not big else .32)
		if keys[i] == "stairs":w = .27;h = .24
		var at := Vector2(cx + rng.randf_range(-.18, .18) / layout_cols, cy + rng.randf_range(-.18, .18) / rows)
		layout_rects[keys[i]] = Rect2(at, Vector2(w, h))
	# Corridors: a spanning tree over room centres plus one extra loop, like a dungeon plan.
	var inside: Array = [keys[0]];var rest: Array = keys.slice(1)
	while not rest.is_empty():
		var best: Array = [];var gap: float = INF
		for a in inside:
			for b in rest:
				var d: float = layout_rects[a].position.distance_to(layout_rects[b].position)
				if d < gap:gap = d;best = [a, b]
		edges.append(best);inside.append(best[1]);rest.erase(best[1])
	var a: String = ids[rng.randi_range(0, ids.size() - 1)];var b: String = ids[rng.randi_range(0, ids.size() - 1)]
	if a != b and not edges.has([a, b]) and not edges.has([b, a]):edges.append([a, b])
	for i in range(14):stains.append([Vector2(rng.randf(), rng.randf()), rng.randf_range(.04, .14), rng.randf_range(.03, .08)])
	for id in room_cards:room_cards[id].visible = layout_rects.has(id)
	_place();queue_redraw()

func set_stairs(open: bool) -> void:
	if open and not stairs_open:stairs_age = 0
	stairs_open = open;stairs.visible = open;_place()

func play_unfold() -> void:
	unfold = 0 if UiMotion.enabled else 1

func _process(dt: float) -> void:
	if not is_visible_in_tree():return
	age += dt;stairs_age += dt
	if unfold < 1:unfold = minf(1, unfold + dt / .75)
	var show: float = clampf((unfold - .7) / .3, 0, 1)
	for id in layout_rects:
		var card: Control = stairs if id == "stairs" else room_cards.get(id)
		if card != null:card.modulate.a = show * (clampf(stairs_age / .4, 0, 1) if id == "stairs" else 1.0)
	reward_button.modulate.a = show
	queue_redraw()

func area() -> Rect2:
	return Rect2(Vector2(PAD, HEADER), size - Vector2(PAD * 2, HEADER + PAD))

func _place() -> void:
	var a: Rect2 = area()
	# A very different sheet shape (rotation, first real size) gets a fresh grid.
	var cols: int = 2 if a.size.x / maxf(1, a.size.y) < .8 else 4 if a.size.x / maxf(1, a.size.y) > 1.6 else 3
	if a.size.y > 1 and layout_cols != 0 and cols != layout_cols and floor_index >= 0:
		var ids: Array = layout_rects.keys().filter(func(k):return k != "stairs");floor_index = -1;show_floor_ids(ids);return
	for id in layout_rects:
		var card: Control = stairs if id == "stairs" else room_cards.get(id)
		if card == null:continue
		var r: Rect2 = layout_rects[id];var side: float = minf(a.size.x, a.size.y);var px: Vector2 = r.size * side
		var rect := Rect2(a.position + r.position * a.size - px * .5, px)
		# Touch targets never shrink below 54 px.
		rect = rect.grow_individual(maxf(0, (54 - rect.size.x) * .5), maxf(0, (54 - rect.size.y) * .5), maxf(0, (54 - rect.size.x) * .5), maxf(0, (54 - rect.size.y) * .5))
		card.position = rect.position;card.size = rect.size;card.custom_minimum_size = Vector2.ZERO
	var w: float = minf(132, size.x * .36)
	reward_button.position = Vector2(size.x - PAD - w, 8);reward_button.size = Vector2(w, 30)

func _draw() -> void:
	var e: float = 1 - pow(1 - unfold, 3)
	var sheet := Rect2(Vector2(size.x * .5 * (1 - e), 0), Vector2(size.x * e, size.y))
	# Dark chart: lit centre, mottled edges, a double gold frame with corner brackets.
	var body: StyleBoxFlat = ArenaUI.box(SHEET, Color(GOLD, .55));body.set_corner_radius_all(10);body.set_border_width_all(2);draw_style_box(body, sheet)
	if sheet.size.x > 40:
		VfxArt.glow(self, sheet.get_center(), minf(sheet.size.x, sheet.size.y) * .75, SHEET_LIGHT, .9)
		for st in stains:draw_circle(sheet.position + Vector2(st[0].x * sheet.size.x, st[0].y * sheet.size.y), float(st[1]) * minf(sheet.size.x, sheet.size.y), Color(0, 0, .02, float(st[2]) * 2.5))
		draw_rect(sheet.grow(-6), Color(GOLD, .22), false, 1)
		for c in [sheet.position + Vector2(6, 6), Vector2(sheet.end.x - 6, sheet.position.y + 6), sheet.end - Vector2(6, 6), Vector2(sheet.position.x + 6, sheet.end.y - 6)]:
			var dx: float = 14 if c.x < sheet.get_center().x else -14;var dy: float = 14 if c.y < sheet.get_center().y else -14
			draw_polyline(PackedVector2Array([c + Vector2(dx, 0), c, c + Vector2(0, dy)]), Color(GOLD, .7), 2)
			draw_circle(c, 2.5, GOLD)
	if unfold < 1:
		# Rolled ends travelling outwards while the chart opens.
		for x in [sheet.position.x, sheet.end.x]:
			var roll := Rect2(Vector2(x - 9, -6), Vector2(18, size.y + 12))
			var style := StyleBoxFlat.new();style.bg_color = Color("2e2420");style.set_corner_radius_all(9);style.border_color = GOLD;style.set_border_width_all(2)
			draw_style_box(style, roll);draw_line(Vector2(x - 3, 0), Vector2(x - 3, size.y), Color(GOLD, .3), 2)
	if e < .7:return
	var alpha: float = clampf((unfold - .7) / .3, 0, 1);var a: Rect2 = area()
	# Floor-plan grid and a compass rose.
	var step: float = maxf(22, minf(a.size.x, a.size.y) / 12)
	for x in range(1, int(a.size.x / step) + 1):draw_line(Vector2(a.position.x + x * step, a.position.y), Vector2(a.position.x + x * step, a.end.y), Color(LINE, .45 * alpha), 1)
	for y in range(1, int(a.size.y / step) + 1):draw_line(Vector2(a.position.x, a.position.y + y * step), Vector2(a.end.x, a.position.y + y * step), Color(LINE, .45 * alpha), 1)
	_compass(Vector2(a.position.x + 28, a.end.y - 28), 20, alpha)
	# Corridors under the rooms: dark passages with stone walls, L-shaped like a floor plan.
	for pair in edges:
		if (pair[0] == "stairs" or pair[1] == "stairs") and not stairs_open:continue
		var p: Vector2 = a.position + layout_rects[pair[0]].position * a.size;var q: Vector2 = a.position + layout_rects[pair[1]].position * a.size
		var bend := Vector2(q.x, p.y)
		for seg in [[p, bend], [bend, q]]:
			draw_line(seg[0], seg[1], Color("3a4a70", alpha), 12, true);draw_line(seg[0], seg[1], Color("0b111e", alpha), 7, true)
			var length: float = seg[0].distance_to(seg[1]);var dir: Vector2 = (seg[1] - seg[0]) / maxf(1, length)
			for d in range(0, int(length), 12):draw_line(seg[0] + dir * d, seg[0] + dir * minf(length, d + 5), Color(GOLD, .35 * alpha), 1.5)
	if stairs_open:
		var at: Vector2 = a.position + layout_rects.get("stairs", Rect2()).position * a.size
		VfxArt.glow(self, at, 70 + 8 * sin(age * 3), Color("ffd27a"), (.22 + .1 * sin(age * 3)) * alpha)
	# Header: floor and chapter, plus the unlock progress.
	var font: Font = ArenaUI.heading_font()
	draw_string(font, Vector2(PAD + 4, 30), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - PAD * 2 - minf(132, size.x * .36) - 8, 20, Color(ArenaUI.GOLD, alpha))
	draw_string(get_theme_default_font(), Vector2(PAD + 4, 50), progress, HORIZONTAL_ALIGNMENT_LEFT, size.x - PAD * 2 - 8, 11, Color(ArenaUI.MUTED, alpha))
	draw_line(Vector2(PAD, HEADER - 4), Vector2(size.x - PAD, HEADER - 4), Color(GOLD, .3 * alpha), 1)

func _compass(at: Vector2, r: float, alpha: float) -> void:
	draw_arc(at, r, 0, TAU, 32, Color(GOLD, .4 * alpha), 1.5, true)
	for i in range(4):
		var d: Vector2 = Vector2.from_angle(i * PI / 2 - PI / 2);var n: Vector2 = d.orthogonal()
		draw_colored_polygon(PackedVector2Array([at + d * r * 1.15, at + n * r * .22, at - n * r * .22]), Color(GOLD, (.7 if i == 0 else .35) * alpha))
	draw_string(ArenaUI.heading_font(), at + Vector2(-4, -r - 6), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(GOLD, .7 * alpha))
