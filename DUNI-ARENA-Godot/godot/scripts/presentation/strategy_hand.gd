class_name StrategyHand
extends Control
## The strategy card hand, fanned like a card game, played by swiping a card up.
## - A press that moves clearly upward lifts the card (sideways motion leaves it); it grows, rises
##   and the cards beside it make room. While held it follows the finger with a little lag and
##   tilts with its motion; past the use line its rim glows and the phone ticks once.
## - Released past the line (or flicked up fast) the hand asks the owner (play_requested); the
##   owner answers with play() (a flight into the target, an effect at the spot, or light at the
##   centre) or refuse() (the card springs back with a short reason). Under the line it springs back.
## - A plain tap asks for the card's details (card_tapped).
## Positions are in this control's space; the lifted card may leave its rect (drawn on top).
## With UI animation off (GameSettings.motion) everything happens at once.
signal card_tapped(card_id: int)
signal lift_started(card_id: int)
signal lift_moved(card_id: int, global_point: Vector2, past_line: bool)
signal lift_ended(card_id: int)
signal play_requested(card_id: int, global_point: Vector2)


## Rows: {id, kind, title, state ("ready" / "used" / "blocked" / "waiting"), note}.
var rows: Array[Dictionary] = []
## Per card: {pos, vel, rot, scale, alpha} drawn state.
var looks: Dictionary = {}
var held_id: int = 0
var press_id: int = 0
var press_at := Vector2.ZERO
var press_time: float = 0
var finger := Vector2.ZERO
var finger_prev := Vector2.ZERO
var finger_speed := Vector2.ZERO
var finger_usec: int = 0
var past_line: bool = false
var lifting: bool = false
## Shown at the finger while a position card is over the field: {shape, size (Vector2 px),
## angle, valid}; empty when none.
var preview: Dictionary = {}
## A card shrinks while it is over the field.
var over_field: bool = false
## Cards leaving the hand: {row, look, mode, to (local), age}.
var leaving: Array[Dictionary] = []
var refusal: String = ""
var refusal_age: float = 9
var age: float = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP;z_index = 40;clip_contents = false
	custom_minimum_size.y = StrategyCardTuning.HAND_CARD.y + 30

func animate() -> bool:return GameSettings.motion

## New contents (keeps the looks of cards still in the hand, so they slide to new places).
func set_rows(value: Array) -> void:
	rows.assign(value)
	var ids: Array = rows.map(func(r): return int(r.id))
	for id in looks.keys():
		if not id in ids:looks.erase(id)
	for r in rows:
		if not looks.has(int(r.id)):
			var slot: Dictionary = _slot(rows.find(r))
			looks[int(r.id)] = {"pos": slot.pos + Vector2(0, 40 if animate() else 0), "vel": Vector2.ZERO, "rot": slot.rot, "scale": 1.0, "alpha": 0.0 if animate() else 1.0}
	if held_id != 0 and not held_id in ids:held_id = 0;lifting = false
	queue_redraw()

func row_of(id: int) -> Dictionary:
	for r in rows:
		if int(r.id) == id:return r
	return {}

## Resting place of the i-th card: a fan along a shallow arc, centred.
func _slot(i: int) -> Dictionary:
	var n: int = rows.size();var w: float = StrategyCardTuning.HAND_CARD.x
	var room: float = maxf(0, size.x - 16 - w)
	var step: float = minf(w * .96, room / maxf(1, n - 1))
	var mid: float = (n - 1) * .5;var d: float = i - mid
	var x: float = size.x * .5 + d * step
	# Cards beside the held one make way.
	var hi: int = _index(held_id)
	if hi >= 0 and i != hi and not lifting:x += signf(i - hi) * 12
	elif hi >= 0 and i != hi:x += signf(i - hi) * 18
	var y: float = size.y - StrategyCardTuning.HAND_CARD.y * .5 - 16 + absf(d) * absf(d) * StrategyCardTuning.HAND_ARC
	return {"pos": Vector2(x, y), "rot": deg_to_rad(d * StrategyCardTuning.HAND_FAN_DEG)}
func _index(id: int) -> int:
	for i in range(rows.size()):
		if int(rows[i].id) == id:return i
	return -1
## The use line, in local y.
func use_line() -> float:return size.y - StrategyCardTuning.HAND_CARD.y - StrategyCardTuning.USE_LINE

func _hit(local: Vector2) -> int:
	# Topmost first: the held card, then from the right (drawn last).
	for i in range(rows.size() - 1, -1, -1):
		var id: int = int(rows[i].id);var l: Dictionary = looks.get(id, {})
		if l.is_empty():continue
		var p: Vector2 = (local - Vector2(l.pos)).rotated(-float(l.rot)) / maxf(.1, float(l.scale))
		if Rect2(-StrategyCardTuning.HAND_CARD * .5, StrategyCardTuning.HAND_CARD).has_point(p):return id
	return 0

func _gui_input(event: InputEvent) -> void:
	var press: bool = event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT)
	var motion: bool = event is InputEventScreenDrag or event is InputEventMouseMotion
	if press and event.pressed:
		var id: int = _hit(event.position)
		if id == 0:return
		press_id = id;press_at = event.position;press_time = age;finger = event.position;finger_prev = finger;finger_speed = Vector2.ZERO;finger_usec = Time.get_ticks_usec()
		held_id = id;lifting = false;past_line = false;accept_event();queue_redraw()
	elif motion and press_id != 0:
		# Pointer speed from real time between events (at least one 60 fps frame apart).
		var now: int = Time.get_ticks_usec();var dt: float = maxf(1.0 / 60.0, (now - finger_usec) / 1000000.0)
		finger_speed = finger_speed.lerp((event.position - finger) / dt, .6);finger_usec = now
		finger = event.position
		var moved: Vector2 = finger - press_at
		if not lifting:
			# Only a clearly upward move lifts the card.
			if -moved.y > StrategyCardTuning.LIFT_START and -moved.y > absf(moved.x) * StrategyCardTuning.LIFT_VERTICAL and row_of(press_id).get("state", "") == "ready":
				lifting = true;lift_started.emit(press_id)
			elif moved.length() > StrategyCardTuning.LIFT_START * 2:
				press_id = 0;held_id = 0
		if lifting:
			var now_past: bool = finger.y < use_line()
			if now_past and not past_line and GameSettings.vibration:Input.vibrate_handheld(StrategyCardTuning.HAPTIC_MS)
			past_line = now_past
			lift_moved.emit(held_id, get_global_transform() * finger, past_line)
		accept_event();queue_redraw()
	elif press and not event.pressed and press_id != 0:
		var id: int = press_id;press_id = 0
		finger = event.position
		if lifting:
			var flick: bool = finger_speed.y < -StrategyCardTuning.FLICK_SPEED and finger.y < press_at.y - StrategyCardTuning.LIFT_START
			lifting = false;lift_ended.emit(id)
			if past_line or flick:play_requested.emit(id, get_global_transform() * finger)
			else:held_id = 0
		else:
			held_id = 0
			if (finger - press_at).length() < StrategyCardTuning.LIFT_START:card_tapped.emit(id)
		past_line = false;over_field = false;preview = {};accept_event();queue_redraw()

## The owner accepted the play: the card leaves with its animation. mode: &"unit" (flies to
## global_to and is drawn in), &"position" (turns into the effect where it is), &"instant" (rises
## to the screen centre and breaks into light).
func play(id: int, mode: StringName, global_to: Vector2 = Vector2.INF) -> void:
	var r: Dictionary = row_of(id);var l: Dictionary = looks.get(id, {})
	held_id = 0;preview = {};over_field = false
	if r.is_empty():return
	if animate() and not l.is_empty():
		var to: Vector2 = get_global_transform().affine_inverse() * global_to if global_to.is_finite() else Vector2(l.pos)
		if mode == &"instant":to = get_global_transform().affine_inverse() * (get_viewport_rect().size * .5)
		leaving.append({"row": r, "look": l.duplicate(), "mode": mode, "from": Vector2(l.pos), "to": to, "age": 0.0})
	rows.erase(r);looks.erase(id);queue_redraw()

## The owner refused the play: the card springs back with a short reason.
func refuse(id: int, reason: String) -> void:
	held_id = 0;preview = {};over_field = false
	refusal = reason;refusal_age = 0
	if looks.has(id):looks[id].vel = Vector2(0, 260) if animate() else Vector2.ZERO
	queue_redraw()

func _process(dt: float) -> void:
	age += dt;refusal_age += dt
	var moved: Vector2 = finger - finger_prev;finger_prev = finger
	var lag: float = 1.0 - pow(1.0 - StrategyCardTuning.FOLLOW, dt * 60.0)
	for i in range(rows.size()):
		var id: int = int(rows[i].id);var l: Dictionary = looks.get(id, {})
		if l.is_empty():continue
		var slot: Dictionary = _slot(i)
		var goal: Vector2 = slot.pos;var goal_rot: float = slot.rot;var goal_scale: float = 1.0
		if id == held_id:
			goal_scale = StrategyCardTuning.HAND_GRAB_SCALE;goal_rot = 0
			if lifting:
				goal = finger + Vector2(0, -StrategyCardTuning.HAND_CARD.y * .3)
				goal_rot = clampf(moved.x * StrategyCardTuning.TILT * 8, -StrategyCardTuning.TILT_MAX, StrategyCardTuning.TILT_MAX)
				if over_field:goal_scale = StrategyCardTuning.FIELD_SCALE
			else:goal = slot.pos + Vector2(0, -StrategyCardTuning.HAND_LIFT)
		if not animate():
			l.pos = goal;l.rot = goal_rot;l.scale = goal_scale;l.alpha = 1.0;continue
		if id == held_id and lifting:
			l.pos = Vector2(l.pos).lerp(goal, lag);l.vel = Vector2.ZERO
		else:
			# A spring with a little overshoot: cards settle with some bounce.
			var v: Vector2 = Vector2(l.vel) + (goal - Vector2(l.pos)) * 220.0 * dt
			v *= pow(.0009, dt);l.vel = v;l.pos = Vector2(l.pos) + v * dt
		l.rot = lerpf(float(l.rot), goal_rot, minf(1, dt * 14));l.scale = lerpf(float(l.scale), goal_scale, minf(1, dt * 14))
		l.alpha = minf(1, float(l.alpha) + dt * 5)
	for m in leaving:m.age = float(m.age) + dt
	leaving = leaving.filter(func(m): return float(m.age) < StrategyCardTuning.PLAY_TIME)
	queue_redraw()

func _draw() -> void:
	# Cards at rest, then the held one on top.
	var order: Array = []
	for r in rows:
		if int(r.id) != held_id:order.append(r)
	for r in rows:
		if int(r.id) == held_id:order.append(r)
	for r in order:
		var l: Dictionary = looks.get(int(r.id), {})
		if l.is_empty():continue
		var state: String = str(r.get("state", "ready"))
		if int(r.id) == held_id and state == "ready":state = "lifted" if past_line or not lifting else "selected"
		_card(Vector2(l.pos), float(l.rot), float(l.scale), float(l.alpha), r, state)
		if int(r.id) == held_id and past_line:
			VfxArt.glow(self, Vector2(l.pos), StrategyCardTuning.HAND_CARD.x * 1.1 * float(l.scale), ArenaUI.GOLD, .25 + .1 * sin(age * 12))
	# The use line while a card is held.
	if lifting:
		var y: float = use_line();var a: float = .6 if past_line else .3
		for x in range(0, int(size.x), 14):draw_line(Vector2(x, y), Vector2(x + 7, y), Color(ArenaUI.GOLD, a), 2)
		draw_string(get_theme_default_font(), Vector2(0, y - 6), "놓으면 사용" if past_line else "위로 올려 사용", HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, Color(ArenaUI.GOLD, a + .2))
	# Range preview of a position card at the finger.
	if lifting and not preview.is_empty():_draw_preview()
	for m in leaving:_leave(m)
	if refusal_age < 1.4 and not refusal.is_empty():
		var a: float = clampf(1.4 - refusal_age, 0, 1);var w: float = get_theme_default_font().get_string_size(refusal, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 24
		var box := Rect2(Vector2((size.x - w) * .5, -30 - 10 * refusal_age), Vector2(w, 24))
		draw_style_box(ArenaUI.box(Color(.2, .05, .07, .9 * a), Color(1, .45, .5, a)), box)
		draw_string(get_theme_default_font(), box.position + Vector2(0, 17), refusal, HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(1, .88, .9, a))

func _card(at: Vector2, rot: float, scale_k: float, alpha: float, r: Dictionary, state: String) -> void:
	draw_set_transform(at, rot, Vector2.ONE * scale_k)
	var rect := Rect2(-StrategyCardTuning.HAND_CARD * .5, StrategyCardTuning.HAND_CARD)
	StrategyCardArt.draw(self, rect, str(r.kind), str(r.title), "", "", state, str(r.get("note", "")))
	draw_set_transform(Vector2.ZERO)

func _draw_preview() -> void:
	var at: Vector2 = finger;var ok: bool = preview.get("valid", true)
	var col: Color = Color("8fe3ff") if ok else Color("ff5a6a")
	var sz: Vector2 = preview.get("size", Vector2(60, 12))
	draw_set_transform(at, float(preview.get("angle", 0)))
	match str(preview.get("shape", "circle")):
		"wall":
			draw_rect(Rect2(-sz * .5, sz), Color(col, .35));draw_rect(Rect2(-sz * .5, sz), Color(col, .95), false, 2)
		_:
			draw_circle(Vector2.ZERO, sz.x * .5, Color(col, .22));draw_arc(Vector2.ZERO, sz.x * .5, 0, TAU, 40, Color(col, .95), 2, true)
	draw_set_transform(Vector2.ZERO)

## A card leaving after a play.
func _leave(m: Dictionary) -> void:
	var k: float = clampf(float(m.age) / StrategyCardTuning.PLAY_TIME, 0, 1);var e: float = Motion.out_quint(k)
	var r: Dictionary = m.row;var from: Vector2 = m.from;var to: Vector2 = m.to
	match StringName(m.mode):
		&"unit":
			# Flies to the target and is drawn into it.
			var p: Vector2 = from.lerp(to, Motion.in_cubic(k)) + Vector2(0, -60 * sin(k * PI))
			_card(p, k * 1.5, maxf(.05, 1 - k * .95), 1 - k * .3, r, "lifted")
			VfxArt.glow(self, p, 40 * (1 - k * .5), ArenaUI.GOLD, .4 * (1 - k))
			if k > .75:draw_arc(to, 30 * (k - .75) * 4, 0, TAU, 24, Color(ArenaUI.GOLD, 1 - k), 3, true)
		&"position":
			# Turns into the effect where it was put down.
			_card(from, 0, maxf(.05, StrategyCardTuning.FIELD_SCALE * (1 - e)), 1 - k, r, "lifted")
			draw_arc(from, 20 + 70 * e, 0, TAU, 36, Color("8fe3ff", 1 - k), 3, true)
			VfxArt.glow(self, from, 60 * e, Color("8fe3ff"), .5 * (1 - k))
		_:
			# Rises to the centre of the screen and breaks into light.
			var p: Vector2 = from.lerp(to, e)
			_card(p, 0, 1 + .6 * e, 1 - maxf(0, k - .5) * 2, r, "lifted")
			if k > .4:
				var b: float = (k - .4) / .6
				for i in range(12):
					var a: float = i * TAU / 12 + b
					draw_line(p + Vector2.from_angle(a) * 30 * b, p + Vector2.from_angle(a) * (60 + 120 * b), Color(1, .95, .7, 1 - b), 3, true)
				VfxArt.glow(self, p, 120 * b, Color("fff3c8"), .6 * (1 - b))
