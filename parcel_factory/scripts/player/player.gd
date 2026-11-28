extends CharacterBody2D
## 플레이어 (택배 공장 직원).
## 이동·애니메이션·상호작용 대상 고르기를 맡고, 공장을 바꿀 때는 Factory의 함수만 불러요.
##   탭(짧게)    : 설비 정보창 열기 (레일은 위 물건 줍기, 쓰레기 더미는 뒤지기)
##   꾹(길게)    : 들고 있는 아이템 빠른 넣기(넣을 수 있는 만큼) · 맨손이면 휘두르기(공격)
##   철거는 정보창의 [철거(꾹)] 버튼 · 철거 모드(9단계)에서만 해요.
## 손에 든 것 = 고른 핫바 칸. 바닥 아이템은 1칸 안에 들어오면 끌려와 자동으로 주워요.

signal message(text: String)
signal request_info(building)
signal hotbar_changed
signal build_hold   # 설비 아이템을 들고 꾹 → 설치 모드 (build_controller가 받아요)

const TILE := 32.0
const WALK_SPEED := 2.0        # 칸/초
const RUN_SPEED := 3.0
const ACCEL_TIME := 0.08       # 0 → 최고 속도까지 걸리는 시간
const REACH := 3.0             # 상호작용·정보창 거리 INFO_RANGE (칸, 플레이어 중심 → 설비 가장 가까운 점)
const BLINK_SEC := 1.0          # 멀리 있는 설비를 탭하면 그 테두리가 깜빡이는 시간
const HOLD_SEC := 0.35         # 이보다 길게 누르면 '꾹'
const RUMMAGE_SEC := 3.0       # 더미 뒤지기
const ATTACK_SEC := 0.3        # 휘두르기 한 번
const HP_MAX := 100
const BODY_RADIUS := 7.0       # 발밑 충돌 원 (px)
const WALK_ANIM_FPS := 8.0
const IDLE_ANIM_FPS := 2.0
const RAIL_PUSH := false       # 레일 위에 서 있으면 레일 방향으로 살짝 밀려요 (기본 끔)
const RAIL_PUSH_SPEED := 0.6   # 칸/초
const DIRS := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
const PICKUP_RADIUS := 1.0     # 이 거리(칸) 안의 바닥 아이템을 끌어와요
const PICKUP_SNAP := 0.25      # 이만큼 가까워지면 가방에 넣어요
const PULL_SPEED := 4.0        # 끌려오는 빠르기 (칸/초)
const DROP_DIST := 1.4         # 버리면 플레이어 앞 이 거리에 떨어져요 (줍는 거리 밖)
const DROP_DELAY := 1.5        # 버린 물건은 이 시간 동안 다시 줍지 않아요
const HELD_OFFSET := [Vector2(14, -12), Vector2(12, -10), Vector2(-14, -12), Vector2(-12, -14)]

var factory: Factory = null
var inventory := Inventory.new()
var hp := HP_MAX
var hotbar := -1               # 고른 핫바 칸 (-1 = 맨손)
var facing := 1                # DIRS 번호 (처음엔 아래를 봐요)
var move_input := Vector2.ZERO # -1~1 (키보드 + 조이스틱)
var run := false
var target = null              # 지금 상호작용 대상 Building
var use_aim := false           # PC: 마우스를 올린 칸(aim)이 대상
var aim = null

var action := ""               # "", "rummage", "attack"
var blink_target = null        # 멀어서 못 연 설비 (테두리 깜빡임)
var blink_t := 0.0
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
	_pull_drops(dt)
	if move_input.length() > 0.2:
		var v := move_input
		facing = (0 if v.x > 0 else 2) if absf(v.x) > absf(v.y) else (1 if v.y > 0 else 3)


func _pull_drops(dt: float) -> void:
	## 바닥 아이템: 1칸 안이면 끌려와서 주워져요 (가방이 가득이면 그대로 둬요)
	var fl: FloorItems = factory.floor_items
	var me := position / TILE
	for d in fl.drops.duplicate():
		if d["delay"] > 0.0:
			d["delay"] -= dt
			continue
		var dist: float = me.distance_to(d["pos"])
		if dist > PICKUP_RADIUS or not inventory.can_accept(fl.item_of(d)):
			continue
		if dist <= PICKUP_SNAP:
			factory.pickup_drop(d, inventory)
		else:
			d["pos"] = d["pos"].move_toward(me, PULL_SPEED * dt)


func facing_vec() -> Vector2:
	return DIRS[facing]


func cell() -> Vector2i:
	return Vector2i(floori(position.x / TILE), floori(position.y / TILE))


# ---------- 매 프레임: 대상 고르기 · 누르기 · 진행 중인 일 ----------

func _process(dt: float) -> void:
	target = _find_target()
	if blink_t > 0.0:
		blink_t -= dt
		if blink_t <= 0.0:
			blink_target = null
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
	## PC면 마우스를 올린 설비(손 닿을 때만), 아니면 반경 REACH 안에서 바라보는 방향에 가장 가까운 설비·레일·더미
	if use_aim:
		return aim if aim != null and in_reach(aim) else null
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


func blink(b) -> void:
	## 멀리 있는 설비: 테두리만 잠깐 깜빡여요
	blink_target = b
	blink_t = BLINK_SEC


static func has_window(b) -> bool:
	## 정보창이 열리는 설비인지. 레일·출구·분배기 같은 단순 벨트 장치와 쓰레기 더미는 기존 동작
	if b is ItemPile and b.is_giant():
		return false
	if b is Conveyor:
		return b is Sorter or b is RailBridge or b is Detector or b is Injector
	return true


func bubble_kind(b) -> String:
	## 대상 위 말풍선 아이콘: hand(줍기·뒤지기) · gear(정보창) · box(들고 꾹 = 넣기)
	if b == null:
		return ""
	if _is_rummage_pile(b) or (not has_window(b) and b is Conveyor and b.item != null):
		return "hand"
	if held_id() != "" and has_window(b):
		return "box"
	return "gear" if has_window(b) else ""


func progress() -> float:
	## 진행 중인 일의 게이지 0~1 (없으면 -1)
	if action == "rummage":
		return action_t / RUMMAGE_SEC
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
	_press_target = null


func held_id() -> String:
	## 손에 든 아이템 이름 ("" = 맨손)
	return inventory.id_at(hotbar)


func select_hotbar(i: int) -> void:
	## 핫바 칸 고르기. 같은 칸을 다시 고르면 맨손
	hotbar = -1 if i == hotbar else clampi(i, 0, Inventory.HOTBAR - 1)
	hotbar_changed.emit()


func drop_slot(i: int) -> void:
	## 가방 칸 하나를 통째로 플레이어 앞 바닥에 버려요
	var items := inventory.take_slot(i)
	if items.is_empty():
		return
	factory.drop_items(items, position / TILE + DIRS[facing] * DROP_DIST, DROP_DELAY)
	message.emit("%s %d개를 버렸어요" % [items[0].id, items.size()])


func cancel() -> void:
	## Esc: 진행 중인 일 멈추고 손에 든 것 내려놓기(맨손)
	if action != "":
		_cancel_action("")
	if hotbar >= 0:
		hotbar = -1
		hotbar_changed.emit()


func _tap(t) -> void:
	## 탭: 정보창 열기 (레일은 물건 줍기, 쓰레기 더미는 뒤지기)
	if t == null:
		return
	if _is_rummage_pile(t):
		start_rummage(t)
	elif has_window(t):
		request_info.emit(t)
	elif t is Conveyor and t.item != null:
		var id: String = t.item.id
		message.emit(("%s을(를) 주웠어요" % id) if factory.pick_item(t, inventory) else "인벤토리가 가득 찼어요")


func _hold(t) -> void:
	## 꾹: 들고 있으면 빠른 넣기(넣을 수 있는 만큼), 맨손이면 휘두르기. 쓰레기 더미는 뒤지기
	var held := held_id()
	if held.begins_with("[설비]"):
		build_hold.emit()
	elif t != null and _is_rummage_pile(t):
		start_rummage(t)
	elif held != "" and t != null:
		quick_insert(t)
	elif held == "":
		_start_action("attack", null)


func quick_insert(t) -> int:
	## 손에 든 칸의 아이템을 설비에 넣을 수 있는 만큼 넣어요
	var held := held_id()
	if held == "" or t == null:
		return 0
	if not t.accepts(held):
		message.emit("%s은(는) %s에 못 넣어요" % [held, t.name])
		return 0
	var unique: Item = inventory.slots[hotbar]["item"]
	var n: int = factory.player_insert(t, unique if unique != null else held, inventory.count(held))
	if n > 0:
		inventory.remove(held, n, hotbar)
		message.emit("%s %d개를 %s에 넣었어요" % [held, n, t.name])
	else:
		message.emit("%s이(가) 가득 찼어요" % t.name)
	return n


func start_rummage(pile) -> void:
	if not in_reach(pile):
		message.emit("더미에 더 가까이 가야 해요")
		return
	_start_action("rummage", pile)


func _is_rummage_pile(b) -> bool:
	return b is ItemPile and b.hand_pull_range() != Vector2i.ZERO


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
		"attack":
			if action_t >= ATTACK_SEC:
				_cancel_action("")
				if _press and _hold_started and _press_target == null and held_id() == "":
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
	var held := held_id()
	held_icon.visible = held != ""
	if held == "":
		return
	held_icon.texture = Art.item_icon(held, 8)
	var tw: float = held_icon.texture.get_width()
	held_icon.scale = Vector2.ONE * (16.0 / maxf(1.0, tw))   # 설비 아이템(큰 그림)도 16px로
	held_icon.position = HELD_OFFSET[facing]
	held_icon.z_index = -1 if facing == 3 else 1


func _draw() -> void:
	# 발밑 그림자
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 11.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------- 저장 ----------

func to_save() -> Dictionary:
	return {"pos": [position.x / TILE, position.y / TILE], "hp": hp, "hotbar": hotbar, "facing": facing, "inventory": inventory.to_save()}


func load_save(d) -> void:
	if not (d is Dictionary):
		return
	var p: Array = d.get("pos", [position.x / TILE, position.y / TILE])
	position = Vector2(float(p[0]), float(p[1])) * TILE
	velocity = Vector2.ZERO
	hp = int(d.get("hp", HP_MAX))
	hotbar = int(d.get("hotbar", -1))
	facing = int(d.get("facing", 1))
	inventory.load_save(d.get("inventory", []))
	hotbar_changed.emit()

