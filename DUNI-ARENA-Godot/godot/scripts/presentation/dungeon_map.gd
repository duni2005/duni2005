class_name DungeonMap
extends Control
## The current floor seen from above as a great round tower: a crenellated stone wall ring with
## four turrets around a meadow painted like the battlefield, and blue sky with drifting clouds
## beyond the wall. Rooms stand in the meadow joined by paved roads; once the floor's clear
## requirement is met, a stairway room opens in its reserved spot.
## A floor shown for the first time builds itself: the camera shows the whole tower, the rooms rise
## one by one (boss rooms last, under a pillar of light with a rune circle and a shake), the
## paths draw between them, then the camera closes in. Tapping skips it. Drag to move the
## camera, pinch or wheel to zoom.
signal stairs_pressed
signal reward_pressed(depth: int)
const GOLD := Color("c9a560")
const HEADER: float = 58
const PAD: float = 18
const MAX_ZOOM: float = 1.6
## Build timing (seconds).
const TOWER_IN: float = .6
const ROOM_GAP: float = .26
const BOSS_GAP: float = .5
const POP: float = .45
const PATH_GAP: float = .16
const PATH_DRAW: float = .45
const ZOOM_IN: float = .95
var floor_index: int = -1
var shown_depth: int = -1
var chapter: int = 1
var run_id: String = ""
var title: String = ""
var progress: String = ""
var room_cards: Dictionary = {} # room id -> ArenaCard, every floor; only this floor's are shown
var layout_rects: Dictionary = {} # room id or "stairs" -> card rect in world units (1 unit = 1 px at rest)
var edges: Array = [] # [id, id, bend] paths; bend bows the path sideways (share of its length)
var stairs: ArenaCard
var reward_button: ConquestRewardButton
var stairs_open: bool = false
var stairs_age: float = 0
var age: float = 0
## Camera: the world point at the view's centre, and the zoom (1 = rest).
var cam := Vector2.ZERO
var zoom: float = 1
var radius: float = 300
var layout_size := Vector2.ZERO
var floor_ids: Array = []
var world: Control # camera space: the tower, its paths and the room cards
var fx: Control # above the rooms: build bursts
var hud: Control # the header over the sky
## True while something covers the map (a chapter cinematic); the build waits for it.
var hold: Callable
var built: Dictionary = {} # "run:depth" floors whose build has played
var pending: bool = false
var build_t: float = -1 # seconds into the build, -1 when idle
var build_end: float = 0
var appear: Dictionary = {} # id -> build time it rises
var path_start: Array = [] # per edge: build time its path starts drawing
var zoom_from: float = 1
var shake: float = 0
var clouds: Array = [] # [position 0..1, scale, speed]
var drag_sum: float = 0
var drag_time: int = 0
var touches: Dictionary = {} # touch index -> position, kept for every touch (cards swallow some releases)
var touch_prev: Dictionary = {} # touch index -> position before its latest drag

func _ready() -> void:
	clip_contents = true;mouse_filter = Control.MOUSE_FILTER_PASS
	world = Control.new();world.name = "World";world.mouse_filter = Control.MOUSE_FILTER_IGNORE;world.draw.connect(_draw_world);add_child(world)
	stairs = ArenaCard.new();stairs.name = "Stairs";stairs.card_type = "stairs";stairs.title = "다음 층";stairs.visible = false
	ArenaUI.bind(stairs, func():if build_t < 0:stairs_pressed.emit());world.add_child(stairs)
	fx = Control.new();fx.name = "Fx";fx.mouse_filter = Control.MOUSE_FILTER_IGNORE;fx.draw.connect(_draw_fx);world.add_child(fx)
	hud = Control.new();hud.name = "Hud";hud.mouse_filter = Control.MOUSE_FILTER_IGNORE;hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.draw.connect(_draw_hud);add_child(hud)
	reward_button = ConquestRewardButton.new();reward_button.custom_minimum_size = Vector2(0, 30);reward_button.text = "층 정복 보상"
	ArenaUI.bind(reward_button, func():reward_pressed.emit(floor_index));add_child(reward_button)
	var rng := RandomNumberGenerator.new();rng.seed = 7
	for i in range(9):clouds.append([Vector2(rng.randf(), rng.randf()), rng.randf_range(.6, 1.3), rng.randf_range(4, 11)])
	resized.connect(_place)

func add_room(id: String, card: ArenaCard) -> void:
	room_cards[id] = card;world.add_child(card);card.visible = false;world.move_child(fx, -1)

## Show one floor. Layout is seeded by run and floor so it never shuffles between visits.
func show_floor(depth: int, ids: Array, run: String) -> void:
	if depth == floor_index and run == run_id:return
	shown_depth = depth;run_id = run;cam = Vector2.ZERO;zoom = 1;show_floor_ids(ids)
func show_floor_ids(ids: Array) -> void:
	floor_index = shown_depth;floor_ids = ids;layout_rects.clear();edges.clear();layout_size = view().size
	var v: Rect2 = view()
	if v.size.x < 60 or v.size.y < 60:
		# Not laid out yet: the first real size lays the floor out.
		layout_size = Vector2.ZERO
		for id in room_cards:room_cards[id].visible = false
		return
	var rng := RandomNumberGenerator.new();rng.seed = hash("%s:%d" % [run_id, shown_depth])
	# Upright views see the wall above and below; wide ones at the sides.
	radius = v.size.y * .49 if v.size.y >= v.size.x else maxf(v.size.x * .43, v.size.y * .6)
	# Rooms fill the part of the meadow the resting camera sees, so every room is on screen and
	# the wall shows above and below. Bigger rooms go first; each takes the best of a few random
	# spots (furthest from the others), and the set shrinks a little until everything fits.
	var keys: Array = ids.duplicate();keys.append("stairs")
	keys.sort_custom(func(a, b):return _big(a) and not _big(b))
	var side: float = minf(v.size.x, v.size.y);var scale: float = 1.0
	for attempt in range(10):
		layout_rects.clear();var ok: bool = true
		for key in keys:
			var big: bool = _big(key)
			var size := Vector2(rng.randf_range(.26, .32), rng.randf_range(.21, .26)) * side * scale
			if big:size = Vector2(.36, .3) * side * scale
			elif key == "stairs":size = Vector2(.27, .24) * side * scale
			size = size.max(Vector2(64, 56))
			var best := Rect2();var best_gap: float = -1
			for k in range(40):
				var at := Vector2(rng.randf_range(-.5, .5) * v.size.x, rng.randf_range(-.5, .5) * v.size.y)
				var rect := Rect2(at - size * .5, size)
				if not _fits(rect):continue
				var gap: float = INF
				for other in layout_rects.values():gap = minf(gap, other.get_center().distance_to(at) - (other.size + size).length() * .5)
				if gap < 14 and attempt < 9:continue
				if gap > best_gap:best_gap = gap;best = rect
			if best_gap < 0 and attempt < 9:ok = false;break
			if best_gap < 0:best = Rect2(-size * .5, size)
			layout_rects[key] = best
		if ok:break
		scale *= .92
	# Paths: a spanning tree over the rooms plus one extra loop, each bowed a little.
	var inside: Array = [keys[0]];var rest: Array = keys.slice(1)
	while not rest.is_empty():
		var pair: Array = [];var gap: float = INF
		for a in inside:
			for b in rest:
				var d: float = layout_rects[a].get_center().distance_to(layout_rects[b].get_center())
				if d < gap:gap = d;pair = [a, b]
		edges.append([pair[0], pair[1], rng.randf_range(-.18, .18)]);inside.append(pair[1]);rest.erase(pair[1])
	var a: String = ids[rng.randi_range(0, ids.size() - 1)];var b: String = ids[rng.randi_range(0, ids.size() - 1)]
	if a != b and not edges.any(func(e):return a in e and b in e):edges.append([a, b, rng.randf_range(-.18, .18)])
	for id in room_cards:room_cards[id].visible = layout_rects.has(id)
	_place();world.queue_redraw()
func _big(key: String) -> bool:return room_cards.has(key) and room_cards[key].kind in ["boss", "miniboss"]
## Inside the resting view (less a margin) and inside the meadow.
func _fits(rect: Rect2) -> bool:
	var v: Rect2 = view();var half: Vector2 = v.size * .5 - Vector2(10, 10)
	if rect.position.x < -half.x or rect.position.y < -half.y or rect.end.x > half.x or rect.end.y > half.y:return false
	var inner: float = meadow_radius() - 12
	for corner in [rect.position, rect.end, Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y)]:
		if corner.length() > inner:return false
	return true

func set_stairs(open: bool) -> void:
	if open and not stairs_open:stairs_age = 0
	stairs_open = open;stairs.visible = open and layout_rects.has("stairs");world.queue_redraw()

## Called whenever the map is shown: a floor seen for the first time builds itself.
func play_unfold() -> void:
	var key: String = "%s:%d" % [run_id, floor_index]
	if built.has(key) or floor_index < 0:return
	built[key] = true
	if TowerCinematic.auto_play():pending = true
func building() -> bool:return build_t >= 0 or pending

func _start_build() -> void:
	pending = false;appear.clear();path_start.clear()
	var order: Array = layout_rects.keys().filter(func(k):return k != "stairs" and not _big(k))
	order.sort_custom(func(a, b):return room_cards[a].subtitle.to_int() < room_cards[b].subtitle.to_int())
	var t: float = TOWER_IN
	for id in order:appear[id] = t;t += ROOM_GAP
	for id in layout_rects:
		if _big(id):t += BOSS_GAP - ROOM_GAP;appear[id] = t;t += BOSS_GAP
	t += .15
	for i in range(edges.size()):
		if not "stairs" in edges[i]:path_start.append(t);t += PATH_GAP
		else:path_start.append(-1.0)
	t += PATH_DRAW
	if stairs_open:
		appear["stairs"] = t;t += .5
		for i in range(edges.size()):
			if "stairs" in edges[i]:path_start[i] = appear["stairs"] - .1
	build_end = t + ZOOM_IN;zoom_from = fit_zoom();build_t = 0;cam = Vector2.ZERO;zoom = zoom_from
	for card in _cards():card.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _finish_build() -> void:
	build_t = -1;zoom = 1;cam = Vector2.ZERO
	for card in _cards():card.mouse_filter = Control.MOUSE_FILTER_PASS;card.modulate.a = 1;card.scale = Vector2.ONE
	_place()
func _cards() -> Array:
	var out: Array = []
	for id in layout_rects:
		var card: Control = stairs if id == "stairs" else room_cards.get(id)
		if card != null:out.append(card)
	return out

func _process(dt: float) -> void:
	if not is_visible_in_tree():return
	age += dt;stairs_age += dt;shake = maxf(0, shake - dt * 3)
	if pending and not layout_rects.is_empty() and not (hold.is_valid() and hold.call()) and not get_tree().root.get_children().any(func(n):return n is LoadingScreen):_start_build()
	if build_t >= 0:
		build_t += dt
		if build_t >= build_end:_finish_build()
		else:_animate_build()
	world.modulate.a = 1.0 if build_t < 0 else Motion.out_expo(Motion.phase(build_t, 0, TOWER_IN))
	_place();queue_redraw();world.queue_redraw();fx.queue_redraw();hud.queue_redraw()

func _animate_build() -> void:
	var t: float = build_t
	for id in layout_rects:
		var card: Control = stairs if id == "stairs" else room_cards.get(id)
		if card == null:continue
		var k: float = Motion.phase(t, appear.get(id, INF), POP)
		card.pivot_offset = card.size * .5;card.scale = Vector2.ONE * lerpf(.35, 1, Motion.emphasis(k));card.modulate.a = Motion.out_quint(k * 1.6)
	# Close in once everything stands.
	var z: float = Motion.phase(t, build_end - ZOOM_IN, ZOOM_IN);z = z * z * (3 - 2 * z)
	var tower_in: float = Motion.out_expo(Motion.phase(t, 0, TOWER_IN))
	zoom = lerpf(zoom_from * (.86 + .14 * tower_in), 1, z)

## The resting view in screen space: everything under the header.
func view() -> Rect2:
	return Rect2(Vector2(0, HEADER), size - Vector2(0, HEADER))
func meadow_radius() -> float:return radius - wall_width()
func wall_width() -> float:return clampf(radius * .085, 18, 40)
## Zoom that shows the whole tower.
func fit_zoom() -> float:
	var v: Rect2 = view();return clampf(minf(v.size.x, v.size.y) / (radius * 2.25), .2, 1)

func _place() -> void:
	if size.x < 2 or size.y < 2:return
	# A very different view size (rotation, first real size) gets a fresh layout.
	if floor_index >= 0 and (absf(size.x - layout_size.x) > layout_size.x * .1 + 2 or absf(view().size.y - layout_size.y) > layout_size.y * .1 + 2):
		show_floor_ids(floor_ids)
		if layout_rects.is_empty():return
	if build_t < 0:_clamp_camera()
	var jolt := Vector2(sin(age * 61), cos(age * 47)) * 5 * shake
	world.position = view().get_center() - cam * zoom + jolt;world.scale = Vector2.ONE * zoom
	for id in layout_rects:
		var card: Control = stairs if id == "stairs" else room_cards.get(id)
		if card == null:continue
		var rect: Rect2 = layout_rects[id]
		card.position = rect.position;card.size = rect.size;card.custom_minimum_size = Vector2.ZERO
	stairs.visible = stairs_open and layout_rects.has("stairs")
	var w: float = minf(132, size.x * .36)
	reward_button.position = Vector2(size.x - PAD - w, 8);reward_button.size = Vector2(w, 30)
	reward_button.modulate.a = _hud_alpha()
func _clamp_camera() -> void:
	zoom = clampf(zoom, fit_zoom(), MAX_ZOOM)
	var half: Vector2 = view().size * .5 / zoom;var reach: float = radius + 30
	cam = Vector2(clampf(cam.x, -maxf(0, reach - half.x), maxf(0, reach - half.x)), clampf(cam.y, -maxf(0, reach - half.y), maxf(0, reach - half.y)))
func _hud_alpha() -> float:
	if build_t < 0:return 0.0 if pending else 1.0
	return Motion.phase(build_t, build_end - ZOOM_IN * .6, ZOOM_IN * .6)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:touches[event.index] = event.position
		else:touches.erase(event.index);touch_prev.erase(event.index)
	elif event is InputEventScreenDrag:
		touch_prev[event.index] = touches.get(event.index, event.position);touches[event.index] = event.position

# Camera input. Room cards pass their drags up here (ArenaUI.bind cancels the tap once a drag
# goes past 18 px), so the map pans from anywhere.
func _gui_input(event: InputEvent) -> void:
	if build_t >= 0 or pending:
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
			if build_t >= 0:build_end = minf(build_end, build_t + .01)
			accept_event()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_zoom_at(event.position, 1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1 / 1.12);accept_event()
	elif event is InputEventMouseMotion and event.device != -1 and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_drag(event.relative)
	elif event is InputEventScreenDrag:
		# Touch positions are screen-space (from _input); gestures work in map space.
		var offset: Vector2 = get_global_transform_with_canvas().origin
		if touches.size() >= 2:
			var other: Vector2 = touches[touches.keys().filter(func(i):return i != event.index)[0]] - offset
			var was: Vector2 = touch_prev.get(event.index, touches[event.index]) - offset;var now: Vector2 = touches[event.index] - offset
			var before: float = was.distance_to(other);var after: float = now.distance_to(other)
			if before > 1:_zoom_at((now + other) * .5, after / before)
			cam -= ((now + other) * .5 - (was + other) * .5) / zoom;_clamp_camera();_place()
		else:_drag(event.relative)
func _drag(relative: Vector2) -> void:
	# A new gesture starts after a pause; it pans once it has moved 10 px.
	if Time.get_ticks_msec() - drag_time > 250:drag_sum = 0
	drag_time = Time.get_ticks_msec();drag_sum += relative.length()
	if drag_sum > 10:cam -= relative / zoom;_clamp_camera();_place()
func _zoom_at(point: Vector2, factor: float) -> void:
	var anchor: Vector2 = cam + (point - view().get_center()) / zoom
	zoom = clampf(zoom * factor, fit_zoom(), MAX_ZOOM)
	cam = anchor - (point - view().get_center()) / zoom;_clamp_camera();_place()

# Sky (screen space): a blue gradient with soft clouds that drift and follow the camera a little.
func _draw() -> void:
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]), PackedColorArray([Color("4f9de0"), Color("4f9de0"), Color("a8dbf7"), Color("a8dbf7")]))
	VfxArt.glow(self, Vector2(size.x * .8, size.y * .12), size.x * .6, Color("fff6d8"), .35)
	var drift: Vector2 = -cam * zoom * .3
	for cloud in clouds:
		var span := size + Vector2(260, 200)
		var at := Vector2(fposmod(cloud[0].x * span.x + age * cloud[2] + drift.x, span.x) - 130, fposmod(cloud[0].y * span.y + drift.y, span.y) - 100)
		_cloud(self, at, 44 * cloud[1], .75)

static func _cloud(c: CanvasItem, at: Vector2, s: float, alpha: float) -> void:
	for puff in [[Vector2(-.9, .15), .55], [Vector2(-.35, -.2), .75], [Vector2(.3, -.3), .85], [Vector2(.95, .1), .6], [Vector2(.2, .25), .7]]:
		c.draw_circle(at + puff[0] * s + Vector2(0, s * .12), puff[1] * s, Color(.55, .7, .86, alpha * .35))
	for puff in [[Vector2(-.9, .15), .55], [Vector2(-.35, -.2), .75], [Vector2(.3, -.3), .85], [Vector2(.95, .1), .6], [Vector2(.2, .25), .7]]:
		c.draw_circle(at + puff[0] * s, puff[1] * s, Color(1, 1, 1, alpha))

# The tower, in world units around its centre.
func _draw_world() -> void:
	var r: float = radius;var w: float = wall_width();var inner: float = r - w
	# Shadow on the sky, then the stone ring.
	for i in range(4):world.draw_circle(Vector2(r * .04, r * .07), r * (1.02 + i * .03), Color(.05, .12, .3, .1))
	world.draw_circle(Vector2.ZERO, r, Color("6f6b64"))
	# Meadow: the battlefield's own floor painted into the circle.
	var points := PackedVector2Array();var uvs := PackedVector2Array();var steps: int = 72
	for i in range(steps):
		var d: Vector2 = Vector2.from_angle(i * TAU / steps);points.append(d * inner);uvs.append(Vector2(.5, .5) + d * .165)
	world.draw_colored_polygon(points, ArenaFloor.BASE)
	world.draw_colored_polygon(points, Color.WHITE, uvs, ArenaFloor.texture(0))
	# Cloud shadows sliding over the floor.
	for i in range(3):
		var at := Vector2(fposmod(age * 9 + i * 340, inner * 3) - inner * 1.5, (i - 1) * inner * .55)
		if at.length() < inner * .85:VfxArt.glow(world, at, inner * .35, Color(0, .05, .1), .14)
	# Shade inside the wall.
	for i in range(steps):
		var a0: float = i * TAU / steps;var a1: float = (i + 1) * TAU / steps
		var p0: Vector2 = Vector2.from_angle(a0);var p1: Vector2 = Vector2.from_angle(a1)
		world.draw_polygon(PackedVector2Array([p0 * inner, p1 * inner, p1 * (inner - 26), p0 * (inner - 26)]), PackedColorArray([Color(0, 0, 0, .38), Color(0, 0, 0, .38), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
	# Wall top: two courses of stone with joints, then battlements on the outer edge.
	world.draw_arc(Vector2.ZERO, inner + w * .32, 0, TAU, 96, Color("8b867d"), w * .64, true)
	world.draw_arc(Vector2.ZERO, inner + 1, 0, TAU, 96, Color("4a463f"), 3, true)
	world.draw_arc(Vector2.ZERO, inner + w * .64, 0, TAU, 96, Color("5f5a52"), 1.5, true)
	var joints: int = int(TAU * inner / 22)
	for i in range(joints):
		var d: Vector2 = Vector2.from_angle(i * TAU / joints + (.5 * TAU / joints if i % 2 else 0.0))
		world.draw_line(d * (inner + 2), d * (inner + w * .3), Color("625d55"), 1.2);world.draw_line(Vector2.from_angle(i * TAU / joints) * (inner + w * .34), Vector2.from_angle(i * TAU / joints) * (inner + w * .62), Color("625d55"), 1.2)
	var merlons: int = int(TAU * r / 24)
	for i in range(merlons):
		var a0: float = i * TAU / merlons;var a1: float = a0 + TAU / merlons * .55
		var p0: Vector2 = Vector2.from_angle(a0);var p1: Vector2 = Vector2.from_angle(a1)
		world.draw_colored_polygon(PackedVector2Array([p0 * (r - w * .34), p1 * (r - w * .34), p1 * r, p0 * r]), Color("a29d93"))
		world.draw_line(p0 * r, p1 * r, Color("c4bfb4"), 1.5)
	world.draw_arc(Vector2.ZERO, r, 0, TAU, 128, Color("3f3b35"), 2, true)
	# Four round turrets on the ring.
	for i in range(4):
		var at: Vector2 = Vector2.from_angle(PI * .25 + i * PI * .5) * (r - w * .5);var tr: float = w * 1.05
		world.draw_circle(at + Vector2(3, 5), tr, Color(0, 0, 0, .25));world.draw_circle(at, tr, Color("9a958b"))
		world.draw_circle(at, tr * .62, Color("6e695f"));world.draw_arc(at, tr, 0, TAU, 32, Color("3f3b35"), 2, true)
		for k in range(8):
			var d: Vector2 = Vector2.from_angle(k * TAU / 8);world.draw_line(at + d * tr * .62, at + d * tr, Color("5a554c"), 2)
	# Paved roads between the rooms (under the cards), drawn in as the floor builds.
	for i in range(edges.size()):
		var e: Array = edges[i]
		if not layout_rects.has(e[0]) or not layout_rects.has(e[1]) or "stairs" in e and not stairs_open:continue
		var amount: float = 1.0 if build_t < 0 else Motion.out_quint(Motion.phase(build_t, path_start[i], PATH_DRAW)) if i < path_start.size() and path_start[i] >= 0 else 0.0
		if amount > 0:_path(_curve(e), amount)
	if stairs_open and layout_rects.has("stairs") and (build_t < 0 or build_t >= appear.get("stairs", INF)):
		var at: Vector2 = layout_rects["stairs"].get_center()
		VfxArt.glow(world, at, 90 + 8 * sin(age * 3), Color("ffd27a"), .3 + .1 * sin(age * 3))
func _curve(e: Array) -> PackedVector2Array:
	var p: Vector2 = layout_rects[e[0]].get_center();var q: Vector2 = layout_rects[e[1]].get_center()
	var bend: Vector2 = (p + q) * .5 + (q - p).orthogonal() * float(e[2]);var out := PackedVector2Array()
	for k in range(25):
		var s: float = k / 24.0;out.append(p.lerp(bend, s).lerp(bend.lerp(q, s), s))
	return out
func _path(curve: PackedVector2Array, amount: float) -> void:
	var count: int = maxi(2, int(ceil(amount * (curve.size() - 1))) + 1);var part: PackedVector2Array = curve.slice(0, count)
	part[part.size() - 1] = curve[count - 2].lerp(curve[count - 1], fmod(amount * (curve.size() - 1), 1.0) if amount < 1 else 1.0)
	world.draw_polyline(part, Color(0, .05, 0, .3), 24, true)
	world.draw_polyline(part, Color("7d776c"), 20, true)
	world.draw_polyline(part, Color("cfc7b4"), 15, true)
	# Flagstones across the road.
	for k in range(1, part.size() - 1):
		var n: Vector2 = (part[k + 1] - part[k]).orthogonal().normalized() * 7.5
		world.draw_line(part[k] - n, part[k] + n, Color("a39b88"), 1.2)
	if amount < 1:
		VfxArt.glow(world, part[part.size() - 1], 26, Color("fff1c4"), .9);world.draw_circle(part[part.size() - 1], 4, Color("fffbe8"))

# Build bursts over the rooms: a ring and dust as each room lands; boss rooms add a light pillar,
# a turning rune circle and a jolt.
func _draw_fx() -> void:
	if build_t < 0:return
	for id in appear:
		if not layout_rects.has(id):continue
		var rect: Rect2 = layout_rects[id];var at: Vector2 = rect.get_center();var k: float = build_t - appear[id]
		var boss: bool = _big(id);var col: Color = Color("ff6a4d") if boss and room_cards[id].kind == "boss" else Color("ffae4a") if boss else Color("ffd27a") if id == "stairs" else Color("bfeaff")
		if boss:
			if k > -.35 and k < 1.1:
				var p: float = clampf((k + .35) / .35, 0, 1);var fade: float = 1 - Motion.phase(k, .5, .6)
				fx.draw_rect(Rect2(at.x - rect.size.x * .3 * p, at.y - 900, rect.size.x * .6 * p, 900), Color(col, .28 * fade))
				fx.draw_rect(Rect2(at.x - rect.size.x * .08 * p, at.y - 900, rect.size.x * .16 * p, 900), Color(1, .97, .9, .55 * fade))
				var ring: float = rect.size.length() * .62;var spin: float = k * 2.4
				fx.draw_arc(at, ring, spin, spin + TAU, 48, Color(col, .7 * fade), 2.5, true)
				fx.draw_arc(at, ring * .82, -spin, -spin + TAU, 48, Color(col, .45 * fade), 1.5, true)
				for n in range(8):
					var d: Vector2 = Vector2.from_angle(spin + n * TAU / 8);fx.draw_line(at + d * ring * .82, at + d * ring, Color(col, .6 * fade), 2)
			if k >= 0 and k < .05:shake = 1
		if k < 0 or k > .9:continue
		var grow: float = Motion.out_expo(k / .9);var fade: float = 1 - k / .9
		fx.draw_arc(at, rect.size.length() * (.3 + .55 * grow), 0, TAU, 48, Color(col, .8 * fade), 3 * fade + 1, true)
		if boss:fx.draw_arc(at, rect.size.length() * (.25 + .9 * grow), 0, TAU, 48, Color(col, .5 * fade), 2, true)
		VfxArt.glow(fx, at, rect.size.length() * .55, col, .5 * fade)
		for n in range(8):
			var d: Vector2 = Vector2.from_angle(n * TAU / 8 + appear[id]);fx.draw_circle(at + d * rect.size.length() * (.35 + .4 * grow), 4 * fade + 1, Color(Color("e9dcc0"), .7 * fade))

# Header over the sky: a dark band with the floor, its chapter and the unlock progress.
func _draw_hud() -> void:
	var alpha: float = _hud_alpha()
	hud.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, HEADER + 24), Vector2(0, HEADER + 24)]), PackedColorArray([Color(.03, .06, .14, .88 * alpha), Color(.03, .06, .14, .88 * alpha), Color(.03, .06, .14, 0), Color(.03, .06, .14, 0)]))
	var font: Font = ArenaUI.heading_font()
	hud.draw_string(font, Vector2(PAD + 4, 30), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - PAD * 2 - minf(132, size.x * .36) - 8, 20, Color(ArenaUI.GOLD, alpha))
	hud.draw_string(get_theme_default_font(), Vector2(PAD + 4, 50), progress, HORIZONTAL_ALIGNMENT_LEFT, size.x - PAD * 2 - 8, 11, Color(Color("dfe7f7"), alpha))
	# While the camera is pulled back a thin cloud layer drifts over the tower.
	var high: float = clampf((1 - zoom) / .45, 0, 1) * (1.0 if build_t >= 0 else .6)
	if high > .02:
		for i in range(3):_cloud(hud, Vector2(fposmod(age * 14 + i * 260, size.x + 300) - 150, size.y * (.3 + i * .22)), 60, .14 * high)
