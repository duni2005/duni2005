extends Node2D
## 설비 스프라이트 묶음. 설비 하나당 Sprite2D 하나(+ 1도트 그림자)를 두고 시뮬레이션 객체와 짝지어요.
## 설치·철거·회전(factory.revision)이 바뀔 때만 노드와 목록을 다시 맞추고,
## 매 프레임은 미리 만든 목록을 돌며 애니메이션 프레임만 바꿔요. 시뮬레이션 상태는 읽기만 해요.
## 다른 층이 함께 쓰는 목록: conveyors(레일 위 물건 그리기), others(전력 등·아이콘 그리기)

const TILE := 32.0
const ANIM_FPS := 6.0            # 설비 가동 애니메이션 속도
const BELT_FPS_PER_SPEED := 4.0  # 레일: 속도 1칸/초 = 초당 4프레임 (벨트 무늬가 물건과 같이 움직여요)
const SHADOW := Color(0, 0, 0, 0.35)

enum K { RAIL, STORAGE, SHELF, SORTER, MACHINE, STATIC }

## 애니메이션 목록 한 줄: [설비, 스프라이트, 그림자(또는 null), 종류 K, 줄(레일 모양)]
var _anim: Array = []
## 레일 계열 목록 한 줄: [설비, 칸 가운데, 들어오는 방향, 나가는 방향]
var conveyors: Array = []
## 레일이 아닌 설비 목록 한 줄: [설비, 칸 사각형]
var others: Array = []

var world = null
var revision := -1        # 목록을 마지막으로 맞춘 factory.revision
var _sprites := {}        # Building -> Sprite2D
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
	for e in _anim:
		var b = e[0]
		var fr := 0
		match e[3]:
			K.RAIL:
				if b.item != null and b.progress >= 1.0:
					continue   # 막힌 레일은 벨트를 멈춰요
				fr = e[4] * SpriteGen.FRAMES + int(_clock * BELT_FPS_PER_SPEED * b.speed) % SpriteGen.FRAMES
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
		var s: Sprite2D = e[1]
		if s.frame != fr:
			s.frame = fr
			if e[2] != null:
				e[2].frame = fr


# ---------- 목록 맞추기 ----------

func _sync(f: Factory) -> void:
	var alive := {}
	for b in f.buildings:
		alive[b] = true
		if not _sprites.has(b):
			_sprites[b] = _make(b)
	for b in _sprites.keys():
		if not alive.has(b):
			_sprites[b].queue_free()
			_sprites.erase(b)
	_anim.clear()
	conveyors.clear()
	others.clear()
	for b in f.buildings:
		_place(f, b, _sprites[b])


func _make(b: Building) -> Sprite2D:
	var key := Art.building_key(b.name)
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
	if not key.begins_with("rail_"):
		var sh := Sprite2D.new()
		sh.texture = s.texture
		sh.hframes = s.hframes
		sh.vframes = s.vframes
		sh.region_enabled = s.region_enabled
		sh.region_rect = s.region_rect
		sh.texture_repeat = s.texture_repeat
		sh.self_modulate = SHADOW
		sh.show_behind_parent = true
		sh.name = "Shadow"
		s.add_child(sh)
	s.set_meta("key", key)
	add_child(s)
	return s


func _place(f: Factory, b: Building, s: Sprite2D) -> void:
	var key: String = s.get_meta("key")
	var center := (Vector2(b.pos) + Vector2(b.size) * 0.5) * TILE
	s.position = center
	s.rotation = b.rot * PI * 0.5 if key in Art.DIRECTIONAL else 0.0
	var sh := s.get_node_or_null("Shadow") as Sprite2D
	if sh != null:
		# 그림자는 언제나 화면 아래쪽으로 1도트
		sh.position = Vector2(0, 1).rotated(-s.rotation)
	var out := Vector2(b.dir_vec())
	var entry := out
	var row := 0
	var kind := K.MACHINE
	if key.begins_with("rail_"):
		kind = K.RAIL
		row = b.rot
		var side = _curve_side(f, b)
		if side != null:
			entry = Vector2(b.pos - side)
			row = 4 + b.rot * 2 + (0 if side == b.left_cell() else 1)
	elif key == "trash_heap":
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
	if kind != K.RAIL:
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
