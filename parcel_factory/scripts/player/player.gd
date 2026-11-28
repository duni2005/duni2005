extends CharacterBody2D
## 플레이어 (택배 공장 직원).
## 이동·애니메이션·상호작용 대상 고르기를 맡고, 공장을 바꿀 때는 Factory의 함수만 불러요.
##   탭(짧게)    : 더미 뒤지기 / 레일 위 물건 줍기 / 결과물 꺼내기 / 정보 창 · 아이템을 들었으면 1개 넣기
##   꾹(길게)    : 설비 철거(게이지) · 아이템을 들었으면 다 넣기 · 대상이 없으면 휘두르기(공격)

signal message(text: String)
signal request_info(building)

const TILE := 32.0
const WALK_SPEED := 2.0        # 칸/초
const RUN_SPEED := 3.0
const ACCEL_TIME := 0.08       # 0 → 최고 속도까지 걸리는 시간
const REACH := 2.5             # 상호작용 거리 (칸, 플레이어 중심 → 설비 가장 가까운 점)
const HOLD_SEC := 0.35         # 이보다 길게 누르면 '꾹'
const RUMMAGE_SEC := 3.0       # 더미 뒤지기
const DECON_SEC := 1.0         # 철거 게이지
const ATTACK_SEC := 0.3        # 휘두르기 한 번
const TAKE_MAX := 50           # 결과물을 한 번에 꺼내는 최대 수
const HP_MAX := 100
const BODY_RADIUS := 7.0       # 발밑 충돌 원 (px)
const WALK_ANIM_FPS := 8.0
const IDLE_ANIM_FPS := 2.0
const RAIL_PUSH := false       # 레일 위에 서 있으면 레일 방향으로 살짝 밀려요 (기본 끔)
const RAIL_PUSH_SPEED := 0.6   # 칸/초
const DIRS := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
const HELD_OFFSET := [Vector2(14, -12), Vector2(12, -10), Vector2(-14, -12), Vector2(-12, -14)]

var factory: Factory = null
var inventory := Inventory.new()
var hp := HP_MAX
var held := ""                 # 손에 든 아이템 이름 ("" = 맨손)
var facing := 1                # DIRS 번호 (처음엔 아래를 봐요)
var move_input := Vector2.ZERO # -1~1 (키보드 + 조이스틱)
var run := false
var target = null              # 지금 상호작용 대상 Building

var action := ""               # "", "rummage", "decon", "attack"
var action_t := 0.0
var _action_target = null
var _press := false
var _press_t := 0.0
var _hold_started := false
var _press_target = null
var _anim_t := 0.0

var sprite: Sprite2D
var held_icon: Sprite2D
var hitbox: Area2D


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = BODY_RADIUS
	shape.shape = circle
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.texture = Art.tex("player")
	sprite.hframes = SpriteGen.PLAYER_COLS
	sprite.vframes = 4
	sprite.scale = Vector2(Art.SCALE, Art.SCALE)
	sprite.offset = Vector2(0, -SpriteGen.PLAYER_H * 0.5 + 2)   # 발끝이 원점 근처
	add_child(sprite)
	held_icon = Sprite2D.new()
	held_icon.scale = Vector2(Art.SCALE, Art.SCALE)
	held_icon.visible = false
	add_child(held_icon)
	hitbox = Area2D.new()
	var hs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE, TILE)
	hs.shape = rect
	hitbox.add_child(hs)
	hitbox.monitoring = false
	hitbox.visible = false
	add_child(hitbox)


# ---------- 이동 ----------

func _physics_process(dt: float) -> void:
	var speed := (RUN_SPEED if run else WALK_SPEED) * TILE
	var want := move_input.limit_length(1.0) * speed
	if move_input.length() > 0.2 and action == "rummage":
		_cancel_action("움직여서 뒤지기를 멈췄어요")
	velocity = velocity.move_toward(want, RUN_SPEED * TILE / ACCEL_TIME * dt)
	if RAIL_PUSH:
		var under = factory.get_at(cell())
		if under != null and under.is_conveyor():
			velocity += Vector2(under.dir_vec()) * RAIL_PUSH_SPEED * TILE
	move_and_slide()
	if move_input.length() > 0.2:
		var v := move_input
		facing = (0 if v.x > 0 else 2) if absf(v.x) > absf(v.y) else (1 if v.y > 0 else 3)


func cell() -> Vector2i:
	return Vector2i(floori(position.x / TILE), floori(position.y / TILE))


# ---------- 매 프레임: 대상 고르기 · 누르기 · 진행 중인 일 ----------

func _process(dt: float) -> void:
	target = _find_target()
	if _press:
		_press_t += dt
		if _press_target != null and not is_instance_valid_building(_press_target):
			_press_target = null   # 누르는 동안 철거된 설비
		if not _hold_started and _press_t >= HOLD_SEC:
			_hold_started = true
			_hold(_press_target)
	_run_action(dt)
	_animate(dt)
	_update_held_icon()


func in_reach(b) -> bool:
	if b == null:
		return false
	var pc := position / TILE
	var r := Rect2(Vector2(b.pos), Vector2(b.size))
	var closest := Vector2(clampf(pc.x, r.position.x, r.end.x), clampf(pc.y, r.position.y, r.end.y))
	return pc.distance_to(closest) <= REACH


func _find_target():
	## 반경 REACH 안에서 바라보는 방향에 가장 가까운 설비·레일·더미
	var pc := position / TILE
	var base := cell()
	var rr := int(ceil(REACH)) + 1
	var face: Vector2 = DIRS[facing]
	var best = null
	var best_score := INF
	var seen := {}
	for dy in range(-rr, rr + 1):
		for dx in range(-rr, rr + 1):
			var b = factory.get_at(base + Vector2i(dx, dy))
			if b == null or seen.has(b):
				continue
			seen[b] = true
			var r := Rect2(Vector2(b.pos), Vector2(b.size))
			var closest := Vector2(clampf(pc.x, r.position.x, r.end.x), clampf(pc.y, r.position.y, r.end.y))
			var d := pc.distance_to(closest)
			if d > REACH:
				continue
			var dot := 0.5
			if d > 0.01:
				dot = face.dot((closest - pc) / d)
			else:
				d = 0.6   # 발밑 레일은 앞에 있는 설비보다 조금 덜 우선
			var score := d * (2.0 - dot)
			if score < best_score:
				best_score = score
				best = b
	return best


func shown_target():
	var t = _press_target if _press else target
	return t if is_instance_valid_building(t) else null


func bubble_kind(b) -> String:
	## 대상 위 말풍선 아이콘: hand(손) · gear(정보) · box(넣기)
	if b == null:
		return ""
	if held != "":
		return "box"
	if _is_rummage_pile(b) or (b is Conveyor and b.item != null) or b.has_output():
		return "hand"
	return "gear"


func progress() -> float:
	## 진행 중인 일의 게이지 0~1 (없으면 -1)
	match action:
		"rummage":
			return action_t / RUMMAGE_SEC
		"decon":
			return action_t / DECON_SEC
	return -1.0


# ---------- 누르기 ----------

func action_press(override = null) -> void:
	if action == "rummage":
		return
	_press = true
	_press_t = 0.0
	_hold_started = false
	_press_target = override if override != null else target


func action_release() -> void:
	if not _press:
		return
	_press = false
	if not _hold_started:
		_tap(_press_target)
	if action == "decon":
		_cancel_action("")
	_press_target = null


func set_held(id: String) -> void:
	held = "" if id == held or inventory.count(id) == 0 else id


func cancel() -> void:
	## Esc: 진행 중인 일 멈추고 손에 든 것 내려놓기
	if action != "":
		_cancel_action("")
	held = ""


func _tap(t) -> void:
	if held != "":
		if t == null:
			message.emit("넣을 곳이 없어요")
		elif factory.insert_from(inventory, held, t):
			message.emit("%s 1개를 %s에 넣었어요" % [held, t.name])
		else:
			message.emit("%s은(는) %s에 못 넣어요" % [held, t.name])
		_drop_if_empty()
		return
	if t == null:
		return
	if _is_rummage_pile(t):
		start_rummage(t)
	elif t is Conveyor and t.item != null:
		var id: String = t.item.id
		message.emit(("%s을(를) 주웠어요" % id) if factory.pick_item(t, inventory) else "가방이 가득 찼어요")
	elif t.has_output():
		var n: int = factory.take_outputs(t, inventory, TAKE_MAX)
		message.emit(("%s에서 %d개 꺼냈어요" % [t.name, n]) if n > 0 else "가방이 가득 찼어요")
	else:
		request_info.emit(t)


func _hold(t) -> void:
	if t == null:
		if held == "":
			_start_action("attack", null)
		return
	if held != "":
		var n := 0
		while factory.insert_from(inventory, held, t):
			n += 1
		message.emit("%s %d개를 %s에 넣었어요" % [held, n, t.name] if n > 0 else "%s은(는) %s에 못 넣어요" % [held, t.name])
		_drop_if_empty()
	elif _is_rummage_pile(t):
		start_rummage(t)
	elif factory.is_fixed(t) and not factory.creative:
		message.emit("%s은(는) 철거할 수 없어요" % t.name)
	else:
		_start_action("decon", t)


func start_rummage(pile) -> void:
	if not in_reach(pile):
		message.emit("더미에 더 가까이 가야 해요")
		return
	_start_action("rummage", pile)


func _is_rummage_pile(b) -> bool:
	return b is ItemPile and b.hand_pull_range() != Vector2i.ZERO


func _drop_if_empty() -> void:
	if held != "" and inventory.count(held) == 0:
		held = ""


# ---------- 진행 중인 일 ----------

func _start_action(kind: String, t) -> void:
	action = kind
	action_t = 0.0
	_action_target = t
	if kind == "attack":
		hitbox.position = DIRS[facing] * TILE * 0.75 + Vector2(0, -TILE * 0.4)
		hitbox.monitoring = true


func _cancel_action(text: String) -> void:
	action = ""
	action_t = 0.0
	_action_target = null
	hitbox.monitoring = false
	if text != "":
		message.emit(text)


func _run_action(dt: float) -> void:
	if action == "":
		return
	action_t += dt
	match action:
		"rummage":
			if not is_instance_valid_building(_action_target) or not in_reach(_action_target):
				_cancel_action("더미에서 멀어졌어요")
			elif action_t >= RUMMAGE_SEC:
				var got: Array = factory.hand_pull(_action_target, closest_cell(_action_target), inventory)
				var names := []
				for it in got:
					names.append(it.id)
				message.emit(("뒤져서 %d개 찾았어요: %s" % [got.size(), ", ".join(names)]) if not got.is_empty() else "가방이 가득 찼어요")
				_cancel_action("")
		"decon":
			if not is_instance_valid_building(_action_target) or not in_reach(_action_target):
				_cancel_action("")
			elif action_t >= DECON_SEC:
				var nm: String = _action_target.name
				if factory.deconstruct(_action_target, inventory):
					message.emit("%s을(를) 철거해 가방에 넣었어요" % nm)
					_press_target = null
				else:
					message.emit("가방에 자리가 모자라 철거하지 못했어요")
				_cancel_action("")
		"attack":
			if action_t >= ATTACK_SEC:
				_cancel_action("")
				if _press and _hold_started and _press_target == null and held == "":
					_start_action("attack", null)   # 누르고 있으면 계속 휘둘러요


func is_instance_valid_building(b) -> bool:
	return b != null and factory.buildings.has(b)


func closest_cell(b) -> Vector2i:
	var r := Rect2i(b.pos, b.size)
	var c := cell()
	return Vector2i(clampi(c.x, r.position.x, r.end.x - 1), clampi(c.y, r.position.y, r.end.y - 1))


# ---------- 그리기 ----------

func _animate(dt: float) -> void:
	_anim_t += dt
	var col := 0
	if action == "attack":
		col = 6 if action_t < ATTACK_SEC * 0.4 else 7
	elif velocity.length() > 4.0:
		var speed_k := velocity.length() / (WALK_SPEED * TILE)
		col = int(_anim_t * WALK_ANIM_FPS * speed_k) % 4
	else:
		col = 4 + int(_anim_t * IDLE_ANIM_FPS) % 2
	sprite.frame = facing * SpriteGen.PLAYER_COLS + col
	queue_redraw()


func _update_held_icon() -> void:
	held_icon.visible = held != ""
	if held == "":
		return
	held_icon.texture = Art.item_icon(held, 8)
	held_icon.position = HELD_OFFSET[facing]
	held_icon.z_index = -1 if facing == 3 else 1


func _draw() -> void:
	# 발밑 그림자
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 11.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
