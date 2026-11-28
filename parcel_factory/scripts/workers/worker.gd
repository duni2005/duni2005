extends CharacterBody2D
## 아르바이트 직원 (상태 기계). 정의는 data/workers.json (DB.workers).
##   배달(job = delivery): 대기 → 가장 가까운 출하대에 택배가 있으면 걸어가 carry개까지 집기 → 정문으로 걸어가 밖으로(사라짐)
##     → 밖에서 '배달 시간' = round_trip − 실제 걷는 시간(나간 길 × 2) → 배달 순간 정상/오배송을 세고(factory.deliver) → 정문으로 들어옴 → 반복.
##     출하대가 비면 출하대 옆에서 대기. 가던 출하대가 철거·이동되면 다시 찾아요.
##   정비(job = repair): 담당 구역(zone) 안의 고장 설비를 찾아 옆으로 걸어가 repair_sec초 수리(factory.repair).
## 길: WorkerManager.nav(AStarGrid2D). 길이 없거나 1초 넘게 못 움직이면 1초 뒤 다시 계산, 3번 실패하면 '길이 막혔어요' 말풍선.
## 공장은 factory.take_parcels / deliver / repair로만 바꿔요. 게임 속도(×1~8)·일시정지·하루 끝을 따라요.

enum S { IDLE, WAIT, GO_PICK, GO_EXIT, OUTSIDE, GO_REPAIR, REPAIR }

const TILE := 32.0
const DRAW_SCALE := 1.75        # 플레이어(2배)보다 조금 작게
const BODY_RADIUS := 6.0
const ARRIVE_PX := 3.0
const RETRY_SEC := 1.0
const FAILS_FOR_BUBBLE := 3
const STUCK_SEC := 1.0
const THINK_SEC := 0.25         # 대기 중 일을 다시 찾는 간격
const WALK_FPS := 8.0
const IDLE_FPS := 2.0
const COLS := 8                 # SpriteGen.PLAYER_COLS
const FW := 16
const FH := 24
const STATE_TEXT := {
	S.IDLE: "대기", S.WAIT: "출하대 옆에서 대기", S.GO_PICK: "택배 가지러 가는 중", S.GO_EXIT: "정문으로 가는 중",
	S.OUTSIDE: "배달 중 (밖)", S.GO_REPAIR: "고장 설비로 가는 중", S.REPAIR: "수리 중",
}
const STATE_ICON := {S.GO_PICK: "hand", S.GO_EXIT: "box", S.OUTSIDE: "", S.GO_REPAIR: "gear", S.REPAIR: "hammer"}

var factory: Factory = null
var manager = null
var def: Dictionary = {}
var job := "delivery"
var title := ""
var state := S.IDLE
var today := 0                  # 오늘 처리 수 (배달한 택배 · 고친 설비)
var carried: Array = []         # 들고 있는 택배 (Item)
var target = null               # 출하대 또는 고장 설비
var zone := Rect2i()            # 정비 담당 구역 (기본 = 방 전체)
var round_trip := 45.0
var carry := 1
var repair_sec := 8.0
var speed := 2.0                # 칸/초 (게임 속도 ×1 기준)
var path: Array = []
var blocked := false            # 3번 실패: 말풍선
var fails := 0
var outside_t := 0.0
var work_t := 0.0
var walk_t := 0.0               # 출하대 → 정문까지 걸은 시간
var facing := 1
var _target_pos := Vector2i.ZERO
var _goal := Vector2i.ZERO
var _retry := 0.0
var _think := 0.0
var _stuck := 0.0
var _last_pos := Vector2.ZERO
var _anim := 0.0
var _day := 1


func setup(p_def: Dictionary) -> void:
	def = p_def
	job = def["job"]
	round_trip = float(def.get("round_trip", 45.0))
	carry = int(def.get("carry", 1))
	repair_sec = float(def.get("repair_sec", 8.0))
	speed = float(def.get("speed", 2.0))


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 0   # 플레이어·다른 직원과는 부딪히지 않아요
	collision_mask = 2    # 벽·설비만 (world_collision이 2번 층에도 있어요)
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = BODY_RADIUS
	cs.shape = circle
	add_child(cs)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_day = factory.day
	if zone.size == Vector2i.ZERO and factory.room != null:
		zone = factory.room.interior()


func cell() -> Vector2i:
	return Vector2i(floori(position.x / TILE), floori(position.y / TILE))


func state_text() -> String:
	if blocked:
		return "길이 막혔어요"
	return STATE_TEXT[state]


# ---------- 매 물리 프레임 ----------

func _physics_process(dt: float) -> void:
	if factory.paused or factory.day_over:
		velocity = Vector2.ZERO
		return
	if factory.day != _day:
		_day = factory.day
		today = 0
	var gdt := dt * factory.speed   # 게임 시간
	_anim += gdt
	match state:
		S.IDLE:
			_think -= gdt
			if _think <= 0.0:
				_think = THINK_SEC
				_find_work()
		S.WAIT:
			_think -= gdt
			if _think <= 0.0:
				_think = THINK_SEC
				if manager.find_shelf(self, true) != null:
					state = S.IDLE   # 택배가 생겼어요
			if not path.is_empty():
				_walk(gdt)
		S.GO_PICK, S.GO_REPAIR:
			if not _target_ok():
				_release()
				state = S.IDLE
				return
			if _walk(gdt):
				_arrive()
		S.GO_EXIT:
			walk_t += gdt
			if _walk(gdt):
				_arrive()
		S.OUTSIDE:
			outside_t -= gdt
			if outside_t <= 0.0:
				_come_back()
		S.REPAIR:
			velocity = Vector2.ZERO
			if not _target_ok():
				_release()
				state = S.IDLE
				return
			work_t += gdt
			if work_t >= repair_sec:
				factory.repair(target)
				today += 1
				_release()
				state = S.IDLE
	queue_redraw()


func _find_work() -> void:
	if job == "delivery" and not carried.is_empty():
		_go_exit()   # 불러왔을 때 들고 있던 택배는 그대로 배달하러
		return
	if job == "delivery":
		var s = manager.find_shelf(self, true)
		if s != null:
			_go_to(s, S.GO_PICK)
			return
		var near = manager.find_shelf(self, false)
		if near != null:
			if _go_to(near, S.WAIT):
				state = S.WAIT
		return
	var b = manager.claim_broken(self)
	if b != null:
		_go_to(b, S.GO_REPAIR)


func _target_ok() -> bool:
	## 가던 설비가 철거·이동되면 다시 찾아요 (고장 설비는 이미 고쳐졌어도)
	if target == null or not factory.buildings.has(target) or target.pos != _target_pos:
		return false
	return not (job == "repair" and not target.broken)


func _release() -> void:
	manager.release(self)
	target = null
	path = []


# ---------- 이동 ----------

func _go_to(b, next: int) -> bool:
	## 설비 옆 칸으로 길을 찾아요. 찾으면 true
	target = b
	_target_pos = b.pos
	var spots: Array = manager.nav.spots_next_to(b)
	var me := cell()
	spots.sort_custom(func(a, c) -> bool: return (a - me).length_squared() < (c - me).length_squared())
	for i in mini(spots.size(), 4):
		var p: Array = manager.nav.path(me, spots[i])
		if not p.is_empty():
			_set_path(p, spots[i])
			state = next
			return true
	_fail(next)
	return false


func _go_exit() -> void:
	var to: Vector2i = manager.exit_cell(cell())
	var p: Array = manager.nav.path(cell(), to)
	if p.is_empty():
		_fail(S.GO_EXIT)
		return
	_set_path(p, to)
	state = S.GO_EXIT


func _set_path(p: Array, goal: Vector2i) -> void:
	path = p
	_goal = goal
	fails = 0
	blocked = false
	_stuck = 0.0
	_last_pos = position


func _fail(next: int) -> void:
	## 길이 없어요: RETRY_SEC 뒤 다시 (3번 실패하면 말풍선)
	fails += 1
	blocked = fails >= FAILS_FOR_BUBBLE
	path = []
	state = next
	_retry = RETRY_SEC


func repath() -> void:
	## 길 위 칸이 바뀌었어요 (설치·철거·이동)
	if path.is_empty():
		return
	var p: Array = manager.nav.path(cell(), _goal)
	if p.is_empty():
		_fail(state)
	else:
		path = p


func path_has(cells: Array) -> bool:
	for c in cells:
		if path.has(c):
			return true
	return false


func _walk(gdt: float) -> bool:
	## 길을 따라 한 걸음. 도착했으면 true
	if path.is_empty():
		velocity = Vector2.ZERO
		if _retry > 0.0:
			_retry -= gdt
			if _retry <= 0.0:
				_retry_path()
			return false
		return true
	var to: Vector2 = (Vector2(path[0]) + Vector2(0.5, 0.5)) * TILE
	var d := to - position
	if d.length() <= ARRIVE_PX:
		position = to
		path.pop_front()
		return path.is_empty()
	var v := d.normalized() * speed * TILE * factory.speed
	velocity = v
	move_and_slide()
	facing = (0 if v.x > 0 else 2) if absf(v.x) > absf(v.y) else (1 if v.y > 0 else 3)
	# 1초 넘게 거의 못 움직이면 막힌 것으로 보고 다시 계산
	if position.distance_to(_last_pos) > 2.0:
		_last_pos = position
		_stuck = 0.0
	else:
		_stuck += gdt
		if _stuck >= STUCK_SEC:
			_stuck = 0.0
			fails += 1
			blocked = fails >= FAILS_FOR_BUBBLE
			_retry_path()
	return false


func _retry_path() -> void:
	match state:
		S.GO_EXIT:
			_go_exit()
		S.GO_PICK, S.GO_REPAIR, S.WAIT:
			if target != null and _target_ok():
				_go_to(target, state)   # 찾으면 실패 횟수·말풍선이 풀려요
			else:
				_release()
				state = S.IDLE


func _arrive() -> void:
	velocity = Vector2.ZERO
	match state:
		S.GO_PICK:
			var got: Array = factory.take_parcels(target, carry) if target is Shelf else []
			target = null
			if got.is_empty():
				state = S.IDLE   # 그 사이 비었어요
				return
			carried = got
			walk_t = 0.0
			_go_exit()
		S.GO_EXIT:
			# 밖으로 나가요: 왕복 시간에서 실제로 걸은 시간(나간 길 × 2)을 뺀 만큼 밖에 있어요
			visible = false
			outside_t = maxf(0.0, round_trip - walk_t * 2.0)
			state = S.OUTSIDE
		S.GO_REPAIR:
			state = S.REPAIR
			work_t = 0.0


func _come_back() -> void:
	factory.deliver(carried)
	today += carried.size()
	carried = []
	position = (Vector2(manager.spawn_cell()) + Vector2(0.5, 0.5)) * TILE
	visible = true
	state = S.IDLE
	_think = 0.0


# ---------- 저장 ----------

func to_save() -> Dictionary:
	var items := []
	for it in carried:
		items.append(ItemIO.to_dict(it))
	return {"def": def["name"], "title": title, "pos": [position.x / TILE, position.y / TILE], "facing": facing,
		"zone": [zone.position.x, zone.position.y, zone.size.x, zone.size.y], "today": today, "day": _day,
		"carried": items, "outside": state == S.OUTSIDE, "outside_t": outside_t}


func load_save(d: Dictionary) -> void:
	## 걷던 길·맡은 일은 다시 찾아요. 밖에서 배달 중이었으면 남은 시간만큼 더 밖에
	title = str(d.get("title", title))
	var p: Array = d.get("pos", [position.x / TILE, position.y / TILE])
	position = Vector2(float(p[0]), float(p[1])) * TILE
	facing = int(d.get("facing", 1))
	var z: Array = d.get("zone", [])
	if z.size() == 4:
		zone = Rect2i(int(z[0]), int(z[1]), int(z[2]), int(z[3]))
	today = int(d.get("today", 0))
	_day = int(d.get("day", factory.day))
	carried = []
	for e in d.get("carried", []):
		if e is Dictionary:
			carried.append(ItemIO.from_dict(e))
	if bool(d.get("outside", false)):
		state = S.OUTSIDE
		outside_t = float(d.get("outside_t", 0.0))
		visible = false


# ---------- 그리기 ----------

func _draw() -> void:
	# 발밑 그림자
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 몸 (걷기 4칸 + 대기 2칸)
	var moving := velocity.length() > 1.0
	var col := int(_anim * WALK_FPS) % 4 if moving else 4 + int(_anim * IDLE_FPS) % 2
	var tex := Art.tex("worker_" + job)
	var size := Vector2(FW, FH) * DRAW_SCALE
	var r := Rect2(Vector2(-size.x * 0.5, -size.y + 4.0), size)
	draw_texture_rect_region(tex, r, Rect2(col * FW, facing * FH, FW, FH))
	# 들고 있는 택배
	if not carried.is_empty():
		draw_texture_rect_region(Art.tex("items8"), Rect2(Vector2(-8, -24), Vector2(16, 16)), Art.item_region(carried[0].id, 8))
		if carried.size() > 1:
			draw_string(ThemeDB.fallback_font, Vector2(8, -10), "×%d" % carried.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.c(Palette.PAPER))
	# 머리 위 상태 아이콘 (막히면 말풍선)
	var top := Vector2(0, r.position.y - 6)
	if blocked:
		_plate(top, "길이 막혔어요")
		return
	var icon: String = STATE_ICON.get(state, "")
	if state == S.REPAIR:
		var k := clampf(work_t / repair_sec, 0.0, 1.0)
		draw_rect(Rect2(top + Vector2(-14, -4), Vector2(28, 5)), Palette.c(Palette.INK))
		draw_rect(Rect2(top + Vector2(-13, -3), Vector2(26 * k, 3)), Palette.c(Palette.LIME))
		top.y -= 8
	var i := SpriteGen.UI_ICONS.find(icon)
	if i >= 0:
		var box := Rect2(top - Vector2(9, 18), Vector2(18, 18))
		draw_rect(box.grow(1), Palette.c(Palette.INK))
		draw_rect(box, Palette.c(Palette.PAPER))
		draw_texture_rect_region(Art.tex("ui_icons"), box.grow(-1), Rect2(i * 8, 0, 8, 8))


func _plate(bottom: Vector2, text: String) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 12.0
	var r := Rect2(bottom - Vector2(w * 0.5, 20), Vector2(w, 18))
	draw_rect(r.grow(1), Palette.c(Palette.INK))
	draw_rect(r, Palette.c(Palette.PAPER))
	draw_string(font, r.position + Vector2(6, 14), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.c(Palette.INK))
