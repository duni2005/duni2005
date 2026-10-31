class_name DungeonMap
extends Control
## The current floor seen from above as a great round tower: a crenellated stone wall ring with
## four slate-roofed turrets around a grass meadow in the battlefield's greens, and blue sky with
## flat drifting clouds beyond the wall. Rooms are round daises joined by paved roads; once the floor's clear
## requirement is met, a stairway room opens in its reserved spot.
## A floor shown for the first time builds itself: the camera shows the whole tower, the rooms rise
## one by one (boss rooms last, under a pillar of light with a rune circle and a shake), the
## paths draw between them, then the camera closes in. It cannot be skipped. Drag to move the
## camera, pinch or wheel to zoom.
signal stairs_pressed
signal reward_pressed(depth: int)
const GOLD := Color("c9a560")
const HEADER: float = 58
const PAD: float = 18
const MAX_ZOOM: float = 1.6
## Build timing (seconds).
const TOWER_IN: float = .5
const ROOM_GAP: float = .2
const BOSS_GAP: float = .42
const POP: float = .4
const PATH_GAP: float = .12
const PATH_DRAW: float = .4
const ZOOM_IN: float = .8
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
## Stairs opening (on the map, when the next floor or chapter unlocks): seconds into it, -1 idle.
const UNLOCK: float = 3.2
var unlock_t: float = -1
var unlock_title: String = ""
var unlock_kicker: String = ""
var unlock_detail: String = ""
var unlock_from := Vector2.ZERO
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
			# Round daises: square cards, boss rooms larger.
			var size := Vector2.ONE * side * scale * (.34 if big else .27 if key == "stairs" else rng.randf_range(.25, .29))
			size = size.max(Vector2(70, 70))
			var best := Rect2();var best_gap: float = -1
			for k in range(40):
				var at := Vector2(rng.randf_range(-.5, .5) * v.size.x, rng.randf_range(-.5, .5) * v.size.y)
				var rect := Rect2(at - size * .5, size)
				if not _fits(rect):continue
				var gap: float = INF
				for other in layout_rects.values():gap = minf(gap, other.get_center().distance_to(at) - (other.size.x + size.x) * .5)
				if gap < 22 and attempt < 9:continue
				if gap > best_gap:best_gap = gap;best = rect
			if best_gap < 0 and attempt < 9:ok = false;break
			if best_gap < 0:best = Rect2(-size * .5, size)
			layout_rects[key] = best
		if ok:break
		scale *= .92
	# Paths: a spanning tree over the rooms plus one extra loop, each bowed a little. The stairs
	# hang off their nearest room, so the rooms stay connected while the stairs are closed.
	var rooms: Array = keys.filter(func(k):return k != "stairs")
	var inside: Array = [rooms[0]];var rest: Array = rooms.slice(1)
	while not rest.is_empty():
		var pair: Array = [];var gap: float = INF
		for a in inside:
			for b in rest:
				var d: float = layout_rects[a].get_center().distance_to(layout_rects[b].get_center())
				if d < gap:gap = d;pair = [a, b]
		edges.append([pair[0], pair[1], rng.randf_range(-.18, .18)]);inside.append(pair[1]);rest.erase(pair[1])
	var near: String = rooms[0]
	for id in rooms:
		if layout_rects[id].get_center().distance_to(layout_rects["stairs"].get_center()) < layout_rects[near].get_center().distance_to(layout_rects["stairs"].get_center()):near = id
	edges.append([near, "stairs", rng.randf_range(-.18, .18)])
	var a: String = ids[rng.randi_range(0, ids.size() - 1)];var b: String = ids[rng.randi_range(0, ids.size() - 1)]
	# The loop is left out when it would run under another room.
	var clear: bool = a != b and not edges.any(func(e):return a in e and b in e)
	for id in layout_rects:
		if clear and id != a and id != b:
			var p: Vector2 = layout_rects[a].get_center();var q: Vector2 = layout_rects[b].get_center();var c: Vector2 = layout_rects[id].get_center()
			clear = c.distance_to(Geometry2D.get_closest_point_to_segment(c, p, q)) > layout_rects[id].size.x * .5 + 14
	if clear:edges.append([a, b, rng.randf_range(-.18, .18)])
	for id in room_cards:room_cards[id].visible = layout_rects.has(id)
	_place();world.queue_redraw()
func _big(key: String) -> bool:return room_cards.has(key) and room_cards[key].kind in ["boss", "miniboss"]
## Inside the resting view (less a margin) and inside the meadow.
func _fits(rect: Rect2) -> bool:
	var v: Rect2 = view();var half: Vector2 = v.size * .5 - Vector2(10, 10)
	if rect.position.x < -half.x or rect.position.y < -half.y or rect.end.x > half.x or rect.end.y > half.y:return false
	# Rooms are round: their circle stays clear of the wall.
	return rect.get_center().length() + rect.size.x * .5 <= meadow_radius() - 10

## The stairs open as a cutscene: the tower rumbles and the camera drifts to the stairs, the stair
## room bursts open under a gold pillar, its road draws in, and "N층 개방" (or "챕터 N 개방") is
## stamped over the map. It cannot be skipped.
func play_unlock(heading: String, kicker: String, detail: String = "") -> void:
	if not layout_rects.has("stairs"):set_stairs(true);return
	unlock_title = heading;unlock_kicker = kicker;unlock_detail = detail;unlock_t = 0;unlock_from = cam
	stairs_open = true;stairs_age = 0;stairs.visible = true;stairs.modulate.a = 0
	for card in _cards():card.mouse_filter = Control.MOUSE_FILTER_IGNORE
func unlocking() -> bool:return unlock_t >= 0
func _finish_unlock() -> void:
	unlock_t = -1;stairs.modulate.a = 1;stairs.scale = Vector2.ONE
	for card in _cards():card.mouse_filter = Control.MOUSE_FILTER_PASS
func _animate_unlock() -> void:
	var t: float = unlock_t
	# Rumble builds until the stairs burst open at .9 s, then settles.
	shake = maxf(shake, Motion.phase(t, 0, .9) * .9 if t < .9 else 1.2 * (1 - Motion.phase(t, .9, .5)))
	var target: Vector2 = layout_rects["stairs"].get_center() * .5
	cam = unlock_from.lerp(target, Motion.out_quint(Motion.phase(t, 0, 1.1)))
	var k: float = Motion.phase(t, .9, POP)
	stairs.pivot_offset = stairs.size * .5;stairs.scale = Vector2.ONE * lerpf(.3, 1, Motion.emphasis(k));stairs.modulate.a = Motion.out_quint(k * 1.6)

func set_stairs(open: bool) -> void:
	if open and not stairs_open:stairs_age = 0
	stairs_open = open;stairs.visible = open and layout_rects.has("stairs");world.queue_redraw()

## Called whenever the map is shown: a floor seen for the first time builds itself.
func play_unfold() -> void:
	var key: String = "%s:%d" % [run_id, floor_index]
	if built.has(key) or floor_index < 0:return
	built[key] = true
	# Hidden at once: the map may be drawn this frame before _process runs.
	if TowerCinematic.auto_play():pending = true;world.modulate.a = 0
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
	if unlock_t >= 0:
		unlock_t += dt
		if unlock_t >= UNLOCK:_finish_unlock()
		else:_animate_unlock()
	# A floor waiting for its build (behind a chapter cutscene or the loading cover) shows only sky,
	# so the finished map never flashes up before the build plays.
	world.modulate.a = 0.0 if pending else 1.0 if build_t < 0 else Motion.out_expo(Motion.phase(build_t, 0, TOWER_IN))
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
	# The floor build and the stair opening play out in full: taps are held, not skipped.
	if unlock_t >= 0 or build_t >= 0 or pending:
		if (event is InputEventMouseButton and event.pressed) or event is InputEventScreenTouch:accept_event()
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

# Sky (screen space): a clean blue gradient, a soft sun and a few flat clouds that drift and
# follow the camera a little.
func _draw() -> void:
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]), PackedColorArray([Color("3d8fdc"), Color("3d8fdc"), Color("b9e3fa"), Color("b9e3fa")]))
	VfxArt.glow(self, Vector2(size.x * .82, size.y * .1), size.x * .7, Color("fff4d6"), .45)
	var drift: Vector2 = -cam * zoom * .3
	for cloud in clouds:
		var span := size + Vector2(260, 200)
		var at := Vector2(fposmod(cloud[0].x * span.x + age * cloud[2] + drift.x, span.x) - 130, fposmod(cloud[0].y * span.y + drift.y, span.y) - 100)
		_cloud(self, at, 40 * cloud[1], .9)

## A flat cartoon cloud: rounded puffs on a flat base, with a pale blue underside.
static func _cloud(c: CanvasItem, at: Vector2, s: float, alpha: float) -> void:
	var puffs: Array = [[Vector2(-1.1, .1), .5], [Vector2(-.45, -.25), .72], [Vector2(.35, -.38), .85], [Vector2(1.05, .05), .55]]
	for puff in puffs:c.draw_circle(at + puff[0] * s + Vector2(0, s * .14), puff[1] * s, Color("cfe3f5", alpha))
	c.draw_rect(Rect2(at + Vector2(-1.1, .1) * s + Vector2(0, s * .14), Vector2(2.15 * s, .5 * s)), Color("cfe3f5", alpha))
	for puff in puffs:c.draw_circle(at + puff[0] * s, puff[1] * s, Color(1, 1, 1, alpha))
	c.draw_rect(Rect2(at + Vector2(-1.1, .1) * s, Vector2(2.15 * s, .45 * s)), Color(1, 1, 1, alpha))

# The tower, in world units around its centre, lit from the upper left.
func _draw_world() -> void:
	var r: float = radius;var w: float = wall_width();var inner: float = r - w
	# Soft shadow on the sky.
	VfxArt.glow(world, Vector2(r * .06, r * .1), r * 1.25, Color(.04, .16, .38), .55)
	# Meadow: battlefield grass, lighter towards the sun, with a few tufts and flowers.
	world.draw_circle(Vector2.ZERO, inner, Color("5c9a3a"))
	VfxArt.glow(world, Vector2(-inner * .25, -inner * .3), inner * 1.1, Color("8fcf5a"), .55)
	var rng := RandomNumberGenerator.new();rng.seed = 4242
	for i in range(int(inner * inner / 3400)):
		var at: Vector2 = Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * (inner - 18);var kind: float = rng.randf()
		if kind < .7:
			world.draw_line(at, at + Vector2(-2.5, -5), Color("3f7a2c"), 1.4, true);world.draw_line(at, at + Vector2(2.5, -5.5), Color("3f7a2c"), 1.4, true)
		else:world.draw_circle(at, 2.2, Color("fff7d6") if kind < .85 else Color("ffd45c"))
	# Cloud shadows sliding over the grass.
	for i in range(2):
		var at := Vector2(fposmod(age * 9 + i * 420, inner * 3) - inner * 1.5, (i - .5) * inner * .7)
		if at.length() < inner * .8:VfxArt.glow(world, at, inner * .4, Color(0, .08, .1), .1)
	# Shade along the foot of the wall.
	var steps: int = 96
	for i in range(steps):
		var p0: Vector2 = Vector2.from_angle(i * TAU / steps);var p1: Vector2 = Vector2.from_angle((i + 1) * TAU / steps)
		world.draw_polygon(PackedVector2Array([p0 * inner, p1 * inner, p1 * (inner - 22), p0 * (inner - 22)]), PackedColorArray([Color(0, .1, 0, .32), Color(0, .1, 0, .32), Color(0, .1, 0, 0), Color(0, .1, 0, 0)]))
	# Wall: a smooth stone walk with neat joints, an outer parapet of merlons, crisp edges.
	world.draw_arc(Vector2.ZERO, inner + w * .5, 0, TAU, 128, Color("b9b2a3"), w, true)
	world.draw_arc(Vector2.ZERO, inner + w * .2, 0, TAU, 128, Color("cfc8b8"), w * .35, true)
	var joints: int = int(TAU * inner / 26)
	for i in range(joints):
		var d: Vector2 = Vector2.from_angle(i * TAU / joints);world.draw_line(d * (inner + 2), d * (inner + w * .62), Color("9d9686"), 1)
	var merlons: int = int(TAU * r / 22)
	for i in range(merlons):
		var a0: float = i * TAU / merlons;var a1: float = a0 + TAU / merlons * .58
		var p0: Vector2 = Vector2.from_angle(a0);var p1: Vector2 = Vector2.from_angle(a1)
		world.draw_colored_polygon(PackedVector2Array([p0 * (r - w * .3), p1 * (r - w * .3), p1 * r, p0 * r]), Color("ddd6c6"))
	world.draw_arc(Vector2.ZERO, r - w * .3, 0, TAU, 128, Color("8f8878"), 1.5, true)
	world.draw_arc(Vector2.ZERO, inner, 0, TAU, 128, Color("6f6858"), 2, true)
	world.draw_arc(Vector2.ZERO, r, 0, TAU, 128, Color("6f6858"), 2, true)
	# Four round turrets with slate cone roofs.
	for i in range(4):
		var at: Vector2 = Vector2.from_angle(PI * .25 + i * PI * .5) * (r - w * .5);var tr: float = w * 1.1
		world.draw_circle(at + Vector2(4, 7), tr, Color(.02, .1, .25, .25))
		world.draw_circle(at, tr, Color("cfc8b8"));world.draw_arc(at, tr, 0, TAU, 40, Color("6f6858"), 2, true)
		var roof: float = tr * .82
		for k in range(8):
			var a0: float = k * TAU / 8;world.draw_colored_polygon(PackedVector2Array([at, at + Vector2.from_angle(a0) * roof, at + Vector2.from_angle(a0 + TAU / 8) * roof]), Color("4f6b9a") if k % 2 else Color("5f7cad"))
		VfxArt.glow(world, at + Vector2(-roof * .3, -roof * .3), roof * .6, Color.WHITE, .25)
		world.draw_circle(at, roof * .14, Color("e3c27a"))
	# Paved roads between the rooms (under the cards), drawn in as the floor builds.
	for i in range(edges.size()):
		var e: Array = edges[i]
		if not layout_rects.has(e[0]) or not layout_rects.has(e[1]) or "stairs" in e and not stairs_open:continue
		var amount: float = 1.0 if build_t < 0 else Motion.out_quint(Motion.phase(build_t, path_start[i], PATH_DRAW)) if i < path_start.size() and path_start[i] >= 0 else 0.0
		if unlock_t >= 0 and "stairs" in e:amount = Motion.out_quint(Motion.phase(unlock_t, 1.0, PATH_DRAW))
		if amount > 0:_path(_curve(e), amount)
	if stairs_open and layout_rects.has("stairs") and (build_t < 0 or build_t >= appear.get("stairs", INF)) and (unlock_t < 0 or unlock_t >= .9):
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
	world.draw_polyline(part, Color(0, .12, 0, .22), 22, true)
	world.draw_polyline(part, Color("b9b2a3"), 18, true)
	world.draw_polyline(part, Color("e9e3d3"), 13, true)
	# Small dashes down the middle, like a laid stone line.
	for k in range(1, part.size() - 1, 2):world.draw_line(part[k], part[k].lerp(part[k + 1], .55), Color("cfc8b8"), 2, true)
	if amount < 1:
		VfxArt.glow(world, part[part.size() - 1], 26, Color("fff1c4"), .9);world.draw_circle(part[part.size() - 1], 4, Color("fffbe8"))

# Build bursts over the rooms: a ring and dust as each room lands; boss rooms add a light pillar,
# a turning rune circle and a jolt.
func _draw_fx() -> void:
	if unlock_t >= 0 and layout_rects.has("stairs"):
		# The stair room: a gold pillar gathers, then a burst of rings and dust as it opens.
		var rect: Rect2 = layout_rects["stairs"];var at: Vector2 = rect.get_center();var t: float = unlock_t;var col := Color("ffd27a")
		var gather: float = Motion.phase(t, .3, .6);var fade: float = 1 - Motion.phase(t, 1.4, .7)
		if t < 2.1:
			fx.draw_rect(Rect2(at.x - rect.size.x * .32 * gather, at.y - 900, rect.size.x * .64 * gather, 900), Color(col, .3 * fade))
			fx.draw_rect(Rect2(at.x - rect.size.x * .09 * gather, at.y - 900, rect.size.x * .18 * gather, 900), Color(1, .98, .9, .6 * fade))
			VfxArt.glow(fx, at, rect.size.x * (.4 + gather), col, .5 * gather * fade)
		var k: float = Motion.phase(t, .9, .9)
		if k > 0 and k < 1:
			for ring in [.55, .9, 1.3]:fx.draw_arc(at, rect.size.x * (.3 + ring * Motion.out_expo(k)), 0, TAU, 48, Color(col, .8 * (1 - k)), 3 * (1 - k) + 1, true)
			for n in range(10):
				var d: Vector2 = Vector2.from_angle(n * TAU / 10 + .4);fx.draw_circle(at + d * rect.size.x * (.4 + .6 * Motion.out_expo(k)), 5 * (1 - k) + 1, Color(Color("e9dcc0"), .8 * (1 - k)))
		return
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
	if unlock_t >= 1.0:_draw_unlock_banner(unlock_t - 1.0)
## "N층 개방" stamped across the map: a dark band slides in, the English kicker, the title rising
## letter by letter over a gold rule, then the band slides away.
func _draw_unlock_banner(t: float) -> void:
	var a: float = Motion.out_quint(Motion.phase(t, 0, .3)) * (1 - Motion.phase(t, UNLOCK - 1.0 - .45, .45))
	# The band sits on the half of the screen away from the stairs, so the opening stays in view.
	var stairs_y: float = world.position.y + layout_rects.get("stairs", Rect2()).get_center().y * zoom
	var mid: Vector2 = view().get_center() + Vector2(0, view().size.y * (.24 if stairs_y < view().get_center().y else -.2));var band := Rect2(0, mid.y - 62, size.x, 124)
	TypeArt.panels(hud, band, Motion.phase(t, 0, UNLOCK - 1.0), false, [TypeArt.NAVY, TypeArt.INDIGO, Color(.03, .035, .08, .9)], .7)
	var gold := Color("f0d490");var font: Font = ArenaUI.heading_font();var title_size: int = 34 if size.x < 600 else 44
	hud.draw_string(ArenaUI.numbers_font(), Vector2(0, mid.y - 28), unlock_kicker, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(gold, .9 * a * Motion.out_expo(Motion.phase(t, .1, Motion.ENTER))))
	var width: float = font.get_string_size(unlock_title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	TypeArt.letters(hud, font, unlock_title, Vector2(mid.x - width * .5, mid.y + 16), title_size, Color("fff2cf", a), t - .15, 20, Color(.02, .03, .08, .6 * a))
	TypeArt.rule(hud, Vector2(mid.x, mid.y + 30), width * .5 + 30, Motion.phase(t, .35, Motion.ENTER), Color(gold, .7 * a), 2)
	if not unlock_detail.is_empty():hud.draw_string(get_theme_default_font(), Vector2(0, mid.y + 52), unlock_detail, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color("c4cdbb", a * Motion.phase(t, .5, .4)))
