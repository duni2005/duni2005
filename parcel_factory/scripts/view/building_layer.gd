extends Node2D
## 설비 스프라이트 묶음. 설비 하나당 Sprite2D 하나(+ 1도트 그림자)를 두고 시뮬레이션 객체와 짝지어요.
## 레일(레일 Mk1~3)은 수가 많아서 Sprite2D 없이 이 노드의 _draw 하나로 모아 그려요 (화면 밖은 건너뛰어요).
## 설치·철거·회전(factory.revision)이 바뀔 때만 노드와 목록을 다시 맞추고,
## 매 프레임은 미리 만든 목록을 돌며 애니메이션 프레임만 바꿔요. 시뮬레이션 상태는 읽기만 해요.
## 다른 층이 함께 쓰는 목록: conveyors(레일 위 물건 그리기), others(전력 등·아이콘 그리기)
## 성능: 화면 밖 설비는 애니메이션 프레임을 바꾸지 않고, 철거된 설비의 Sprite2D는 그림 종류별로 모아 두었다가 다시 써요(풀링).

const TILE := 32.0
const ANIM_FPS := 6.0            # 설비 가동 애니메이션 속도
const BELT_FPS_PER_SPEED := 4.0  # 레일: 속도 1칸/초 = 초당 4프레임 (벨트 무늬가 물건과 같이 움직여요)
const SHADOW := Color(0, 0, 0, 0.35)

enum K { STORAGE, SHELF, SORTER, MACHINE, STATIC }

## 애니메이션 목록 한 줄: [설비, 스프라이트, 그림자(또는 null), 종류 K, 줄]
var _anim: Array = []
## 모아 그리는 레일 한 줄: [설비, 칸 사각형(px), 그림 키, 줄(레일 모양), 지금 프레임]
var _rails: Array = []
## 레일 계열 목록 한 줄: [설비, 칸 가운데, 들어오는 방향, 나가는 방향]
var conveyors: Array = []
## 레일이 아닌 설비 목록 한 줄: [설비, 칸 사각형]
var others: Array = []

var world = null
var revision := -1        # 목록을 마지막으로 맞춘 factory.revision
var _sprites := {}        # Building -> Sprite2D
var _pool := {}           # 그림 키 -> [쉬고 있는 Sprite2D]
var _groups := {}         # 그림 키 -> Node2D (같은 그림 설비를 이어서 그려 그리기 묶음이 끊기지 않게)
var _clock := 0.0
var _last_beat := -1      # 프레임 번호가 바뀌는 순간에만 목록을 돌아요


func _process(dt: float) -> void:
	var f: Factory = world.factory
	if not f.paused:
		_clock += dt * f.speed
	var changed := f.revision != revision
	if changed:
		revision = f.revision
		_sync(f)
	# 레일 벨트(Mk3 초당 16프레임)와 설비(초당 6프레임) 중 하나라도 다음 프레임으로 넘어갈 때만 갱신
	var beat := int(_clock * ANIM_FPS)
	var belt := int(_clock * BELT_FPS_PER_SPEED * 4.0)
	var stamp := beat * 1000003 + belt
	if stamp == _last_beat and not changed:
		return
	_last_beat = stamp
	var vis: Rect2 = world.visible_rect()
	var dirty := changed
	for e in _rails:
		if not vis.intersects(e[1]):
			continue
		var rb = e[0]
		if rb.item != null and rb.progress >= 1.0:
			continue   # 막힌 레일은 벨트를 멈춰요
		var rf: int = int(_clock * BELT_FPS_PER_SPEED * rb.speed) % SpriteGen.FRAMES
		if rf != e[4]:
			e[4] = rf
			dirty = true
	if dirty:
		queue_redraw()
	for e in _anim:
		var s: Sprite2D = e[1]
		if not vis.has_point(s.position):
			continue   # 화면 밖은 프레임을 바꾸지 않아요 (들어오면 다음 박자에 맞춰져요)
		var b = e[0]
		var fr := 0
		match e[3]:
			K.STORAGE:
				fr = _fill_frame(b.group.items.size(), b.group.cap)
			K.SHELF:
				fr = _fill_frame(b.stack.size(), int(b.def["cap"]))
			K.SORTER:
				fr = (1 + beat % 3 if b.is_active() else 0) + (0 if b.side_right else SpriteGen.FRAMES)
			K.MACHINE:
				fr = 1 + beat % 3 if b.is_active() else 0
			_:
				continue
		if s.frame != fr:
			s.frame = fr
			if e[2] != null:
				e[2].frame = fr


# ---------- 목록 맞추기 ----------

func _sync(f: Factory) -> void:
	var alive := {}
	for b in f.buildings:
		if Art.building_key(b.name).begins_with("rail_"):
			continue   # 레일은 _draw로
		alive[b] = true
		if not _sprites.has(b):
			_sprites[b] = _make(b)
	for b in _sprites.keys():
		if not alive.has(b):
			var old: Sprite2D = _sprites[b]
			old.visible = false
			old.get_meta("shadow").visible = false
			var key: String = old.get_meta("key")
			if not _pool.has(key):
				_pool[key] = []
			_pool[key].append(old)   # 버리지 않고 같은 그림 설비가 다시 생기면 써요
			_sprites.erase(b)
	_anim.clear()
	_rails.clear()
	conveyors.clear()
	others.clear()
	for b in f.buildings:
		if _sprites.has(b):
			_place(f, b, _sprites[b])
		else:
			_place_rail(f, b)


func _place_rail(f: Factory, b: Building) -> void:
	var center := (Vector2(b.pos) + Vector2(0.5, 0.5)) * TILE
	var out := Vector2(b.dir_vec())
	var entry := out
	var row := b.rot
	var side = _curve_side(f, b)
	if side != null:
		entry = Vector2(b.pos - side)
		row = 4 + b.rot * 2 + (0 if side == b.left_cell() else 1)
	conveyors.append([b, center, entry, out])
	if not f.held.has(b):   # 이동 모드로 들린 레일은 미리보기로만
		_rails.append([b, Rect2(Vector2(b.pos) * TILE, Vector2(TILE, TILE)), Art.building_key(b.name), row, 0])


func _draw() -> void:
	var vis: Rect2 = world.visible_rect()
	for e in _rails:
		var r: Rect2 = e[1]
		if not vis.intersects(r):
			continue
		var tex := Art.tex(e[2])
		var fw := float(tex.get_width()) / SpriteGen.FRAMES
		var fh := float(tex.get_height()) / Art.vframes(e[2])
		draw_texture_rect_region(tex, r, Rect2(int(e[4]) * fw, int(e[3]) * fh, fw, fh))


func _make(b: Building) -> Sprite2D:
	var key := Art.building_key(b.name)
	var pooled: Array = _pool.get(key, [])
	if not pooled.is_empty() and key != "trash_heap":
		var r: Sprite2D = pooled.pop_back()
		r.frame = 0
		r.get_meta("shadow").frame = 0
		return r   # 보이기·위치는 _place가 맞춰요
	var s := Sprite2D.new()
	s.texture = Art.tex(key)
	s.scale = Vector2(Art.SCALE, Art.SCALE)
	if key == "trash_heap":
		# 거대한 더미는 64×64 그림을 세로로 이어 붙여요
		s.region_enabled = true
		s.region_rect = Rect2(Vector2.ZERO, Vector2(b.size) * Art.DOT)
		s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	else:
		s.hframes = SpriteGen.FRAMES
		s.vframes = Art.vframes(key)
	var sh := Sprite2D.new()
	sh.texture = s.texture
	sh.hframes = s.hframes
	sh.vframes = s.vframes
	sh.region_enabled = s.region_enabled
	sh.region_rect = s.region_rect
	sh.texture_repeat = s.texture_repeat
	sh.scale = s.scale
	sh.self_modulate = SHADOW
	sh.name = "Shadow"
	s.set_meta("key", key)
	s.set_meta("shadow", sh)
	# 그림자는 모든 설비보다 먼저, 같은 그림끼리 이어서 그려요 (색이 다른 그림이 끼면 그리기 묶음이 끊겨요)
	_group("shadow:" + key, 0).add_child(sh)
	_group(key, -1).add_child(s)
	return s


func _group(key: String, at: int) -> Node2D:
	if not _groups.has(key):
		var g := Node2D.new()
		g.name = key.replace(":", "_")
		add_child(g)
		if at >= 0:
			move_child(g, at)
		_groups[key] = g
	return _groups[key]


func _place(f: Factory, b: Building, s: Sprite2D) -> void:
	var key: String = s.get_meta("key")
	var center := (Vector2(b.pos) + Vector2(b.size) * 0.5) * TILE
	s.position = center
	s.visible = not f.held.has(b)   # 이동 모드로 들린 설비는 미리보기로만 보여요
	s.rotation = b.rot * PI * 0.5 if key in Art.DIRECTIONAL else 0.0
	var sh: Sprite2D = s.get_meta("shadow")
	# 그림자는 언제나 화면 아래쪽으로 1도트
	sh.position = center + Vector2(0, Art.SCALE)
	sh.rotation = s.rotation
	sh.visible = s.visible
	var out := Vector2(b.dir_vec())
	var entry := out
	var row := 0
	var kind := K.MACHINE
	if key == "trash_heap":
		kind = K.STATIC
	elif b is StorageBlock:
		kind = K.STORAGE
	elif b is Shelf:
		kind = K.SHELF
	elif b is Sorter:
		kind = K.SORTER
	_anim.append([b, s, sh, kind, row])
	if b is Conveyor:
		conveyors.append([b, center, entry, out])
	others.append([b, Rect2(Vector2(b.pos) * TILE, Vector2(b.size) * TILE)])


func _feeds(f: Factory, b: Building, cell: Vector2i) -> bool:
	var n = f.get_at(cell)
	return n != null and n != b and n.is_conveyor() and n.size == Vector2i.ONE and n.front_cell() == b.pos


func _curve_side(f: Factory, b: Building):
	## 뒤에서 받으면 직선(null), 뒤가 비고 한쪽 옆에서만 받으면 그 옆 칸 → 그쪽으로 꺾인 모양
	if _feeds(f, b, b.back_cell()):
		return null
	var lf := _feeds(f, b, b.left_cell())
	var rf := _feeds(f, b, b.right_cell())
	if lf == rf:
		return null
	return b.left_cell() if lf else b.right_cell()


func _fill_frame(n: int, cap: int) -> int:
	if n <= 0:
		return 0
	return clampi(1 + int(float(n) / float(maxi(1, cap)) * 3.0), 1, SpriteGen.FRAMES - 1)
