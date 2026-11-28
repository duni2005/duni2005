class_name Room
extends RefCounted
## 게임의 무대 '큰방'의 지형 정보.
## 시뮬레이션과 따로 두고, Factory는 can_place에서 is_buildable()만 물어봐요.
## 칸 좌표: 방 안쪽(바닥)이 (0,0) ~ (W-1, H-1). 벽은 그 바깥 1칸 둘레(x=-1, x=W, y=-1, y=H).

enum T { OUTSIDE, FLOOR, WALL, NO_BUILD, DOOR, CORRIDOR, RESERVED }

const W := 50                 # 방 안쪽 가로 칸
const H := 40                 # 방 안쪽 세로 칸
const DOOR_W := 10            # 정문 폭 (오른쪽 벽)
const DOOR_APRON := 2         # 정문 앞 설치 금지 칸 수 (통로)
const CORRIDOR_W := 5         # 위·아래 복도 입구 폭
const CORRIDOR_LEN := 6       # 벽 바깥으로 그려 보이는 복도 길이 (그림용)

const PILE_NAME := "엄청난 쓰레기 더미"   # 크기는 data/buildings.json
const PILE_POS := Vector2i(0, 0)
const WATER_RECT := Rect2i(W - 2, 0, 2, 2)  # 오른쪽 위 구석
const WORKBENCH_RECT := Rect2i(44, 24, 2, 2)  # '작업대' 자리 (설비가 아직 없어 비워 둬요)

## 처음부터 깔려 있는 지급 설비 (정문 근처)
const GIVEN := [
	{"name": "작업 컴퓨터", "pos": Vector2i(44, 11), "rot": 0},
	{"name": "출하대", "pos": Vector2i(46, 19), "rot": 0},
	{"name": "바이오 발전기", "pos": Vector2i(44, 28), "rot": 0},
]

## 확장 예정 구간 (점선 테두리로만 보여줘요)
const EXPANSIONS := [
	{"name": "A", "rect": Rect2i(8, -28, 34, 20)},
	{"name": "B", "rect": Rect2i(8, H + 8, 34, 20)},
	{"name": "C", "rect": Rect2i(-24, 0, 20, H)},
	{"name": "D", "rect": Rect2i(-24, -28, 20, 20)},
	{"name": "E", "rect": Rect2i(44, -28, 20, 20)},
	{"name": "F", "rect": Rect2i(-24, H + 8, 20, 20)},
]

var _special := {}   # Vector2i -> T (바닥이 아닌 칸만)


func _init() -> void:
	for x in range(-1, W + 1):
		_special[Vector2i(x, -1)] = T.WALL
		_special[Vector2i(x, H)] = T.WALL
	for y in range(0, H):
		_special[Vector2i(-1, y)] = T.WALL
		_special[Vector2i(W, y)] = T.WALL
	var d := door_rect()
	for y in range(d.position.y, d.end.y):
		_special[Vector2i(W, y)] = T.DOOR
		for k in DOOR_APRON:
			_special[Vector2i(W - 1 - k, y)] = T.NO_BUILD
	for r in corridor_rects():
		for x in range(r.position.x, r.end.x):
			_special[Vector2i(x, r.position.y)] = T.CORRIDOR
	for y in range(WORKBENCH_RECT.position.y, WORKBENCH_RECT.end.y):
		for x in range(WORKBENCH_RECT.position.x, WORKBENCH_RECT.end.x):
			_special[Vector2i(x, y)] = T.RESERVED


# ---------- 칸 정보 ----------

func interior() -> Rect2i:
	return Rect2i(0, 0, W, H)


func door_rect() -> Rect2i:
	## 오른쪽 벽의 정문 칸들
	return Rect2i(W, int((H - DOOR_W) / 2.0), 1, DOOR_W)


func apron_rect() -> Rect2i:
	var d := door_rect()
	return Rect2i(W - DOOR_APRON, d.position.y, DOOR_APRON, DOOR_W)


func corridor_rects() -> Array:
	## 위·아래 벽에 뚫린 복도 입구 칸들 [위, 아래]
	var x0 := int((W - CORRIDOR_W) / 2.0)
	return [Rect2i(x0, -1, CORRIDOR_W, 1), Rect2i(x0, H, CORRIDOR_W, 1)]


func terrain_at(c: Vector2i) -> int:
	if _special.has(c):
		return _special[c]
	return T.FLOOR if interior().has_point(c) else T.OUTSIDE


func is_buildable(c: Vector2i) -> bool:
	return terrain_at(c) == T.FLOOR


# ---------- 처음 배치 ----------

func build_fixed(f) -> void:
	## 지울 수 없는 지형 설비: 쓰레기 더미, 물 샘
	var pile = f.place(PILE_NAME, PILE_POS, 0)
	if pile == null:
		push_warning("쓰레기 더미를 놓지 못했어요")
	for y in range(WATER_RECT.position.y, WATER_RECT.end.y):
		for x in range(WATER_RECT.position.x, WATER_RECT.end.x):
			f.place("물 샘", Vector2i(x, y), 0)


func build_given(f) -> void:
	for g in GIVEN:
		var b = f.place(g["name"], g["pos"], g["rot"])
		if b == null:
			push_warning("지급 설비를 놓지 못했어요: " + str(g["name"]))
		else:
			b.given = true
