class_name SpriteGen
extends RefCounted
## 임시 도트 스프라이트 생성기. 모든 색은 Palette(32색 고정)에서만 가져와요.
## tools/gen_assets.gd가 이 결과를 assets/gen/*.png로 구워 두고, 실행 중에는 Art가 그 PNG를 읽어요.
##
## 시트 규칙 (사람이 그린 PNG로 바꿀 때도 같은 배치를 지켜 주세요)
##  - 설비: 가로 4프레임. 0 = 멈춤, 1~3 = 가동 애니메이션. 한 프레임 = 설비 칸 수 × 16px. 오른쪽(→)을 향해 그려요.
##    (창고 블록·출하대는 0~3이 '얼마나 찼는지', 분류기는 2줄: 위 = 옆 출력 오른쪽, 아래 = 왼쪽)
##  - 레일: 가로 4프레임(벨트 움직임) × 세로 12줄.
##    0~3줄 직선 →↓←↑, 4+방향×2 줄 = 그 방향으로 나가는 꺾임 (+0 왼쪽에서 들어옴, +1 오른쪽에서 들어옴)
##  - 아이템: items8(8×8) · items16(16×16) 아틀라스, 한 줄 16개, 순서 = ITEMS 순서
##  - 타일: tiles.png 한 줄, 순서 = TILES
##  - 플레이어: 16×24 한 칸, 가로 8칸 (0~3 걷기, 4~5 대기, 6~7 휘두르기) × 세로 4줄 (→ ↓ ← ↑)
##  - UI 아이콘: 8×8 한 줄, 순서 = UI_ICONS (말풍선 안에 그려요)

const P := preload("res://assets/palette.gd")
const FRAMES := 4

const TILES := ["floor", "floor_quad", "floor_worn", "office", "hazard", "corridor", "wall", "wall_poster", "door", "barrier", "water", "corridor_wall"]

## 아이템 이름 -> [모양, 색1, 색2, 반짝임]
const ITEMS := {
	"장난감": ["duck", P.YELLOW, P.ORANGE],
	"먹다 남은 음식": ["drumstick", P.BROWN, P.PAPER],
	"나뭇가지": ["twig", P.BROWN, P.GREEN],
	"바위": ["rock", P.G3, P.G4],
	"가전": ["tv", P.G4, P.BLUE_D],
	"헌옷": ["shirt", P.BLUE_D, P.G3],
	"쓰레기": ["trashbag", P.G1, P.YELLOW],
	"작은 사체": ["carcass_s", P.PINK, P.SKIN],
	"중간 사체": ["carcass_m", P.PURPLE, P.PINK],
	"큰 사체": ["carcass_l", P.RED_D, P.RED],
	"석탄": ["coal", P.G1, P.G3],
	"플라스틱": ["pellets", P.CYAN, P.PINK],
	"유기물": ["blob", P.GREEN, P.LIME],
	"종이": ["paper", P.PAPER, P.G4],
	"조약돌": ["pebbles", P.G4, P.G5],
	"고철": ["scrap", P.G3, P.BROWN],
	"섬유": ["yarn", P.PINK, P.RED],
	"고무": ["rubber", P.G1, P.G3],
	"접착제": ["glue", P.PAPER, P.RED],
	"원석": ["gem", P.PURPLE, P.PINK],
	"이상한 고기": ["meat", P.SKIN, P.GREEN],
	"양동이": ["bucket", P.G4, P.CLEAR],
	"페트병": ["bottle", P.CYAN, P.PAPER],
	"금속판": ["plate", P.G4, P.G5],
	"유리": ["glass", P.CYAN, P.PAPER],
	"물 양동이": ["bucket", P.G4, P.BLUE],
	"요청서": ["request", P.PAPER, P.RED],
	"박스 테이프": ["tape", P.CARD, P.ORANGE_L],
	"작은 택배 박스": ["box_s", P.CARD, P.BROWN],
	"큰 택배 박스": ["box_l", P.CARD, P.BROWN],
	"완충재": ["bubble", P.PAPER, P.CYAN],
	"리본": ["bow", P.RED, P.PINK],
	"나무 판자": ["plank", P.CARD, P.BROWN],
	"나사": ["screw", P.G4, P.G2],
	"플라스틱 판": ["plate", P.BLUE, P.CYAN],
	"톱니바퀴": ["gear", P.G4, P.G2],
	"전선 뭉치": ["coil", P.RED, P.YELLOW],
	"모터": ["motor", P.G3, P.ORANGE],
	"강철 프레임": ["frame", P.G2, P.G4],
	"제어 장치": ["panel", P.G2, P.LIME],
	"전자 부품": ["chip", P.GREEN_D, P.YELLOW],
	"정밀 부품": ["precision", P.YELLOW, P.GREEN_D],
	"온전한 장난감": ["duck", P.YELLOW, P.ORANGE, true],
	"온전한 음식": ["burger", P.CARD, P.GREEN],
	"온전한 옷": ["fold", P.BLUE, P.PAPER],
	"온전한 가전": ["tv", P.G5, P.CYAN, true],
	"판매용 장난감": ["sale", P.YELLOW, P.ORANGE],
	"판매용 음식": ["sale", P.BROWN, P.GREEN],
	"판매용 옷": ["sale", P.BLUE, P.PAPER],
	"판매용 가전": ["sale", P.G4, P.CYAN],
	"도시락": ["bento", P.RED, P.PAPER],
	"생수": ["bottle", P.BLUE, P.PAPER],
	"콘크리트 양동이": ["bucket", P.G4, P.G2],
	"스탠드 조명": ["lamp", P.YELLOW, P.G3],
	"통조림": ["can", P.RED, P.G4],
	"신품 가전": ["fridge", P.PAPER, P.G4, true],
	"종합 선물 세트": ["basket", P.CARD, P.RED],
	"배송 로봇": ["robot", P.G4, P.CYAN],
	"수리 키트": ["toolbox", P.RED, P.G3],
	"현금 인쇄지": ["paper", P.LIME, P.GREEN_D],
	"돈다발": ["money", P.GREEN, P.PAPER],
	"고급 가죽": ["leather", P.BROWN, P.CARD],
	"가방": ["bag", P.BROWN_D, P.CARD],
	"돈다발이 든 가죽 가방": ["bag_money", P.BROWN, P.GREEN],
	"택배": ["parcel", P.ORANGE, P.CARD],
	"선물용 택배": ["gift", P.ORANGE, P.RED],
	"[설비] 전선": ["coil", P.YELLOW, P.G2],
	"[설비] 파이프": ["pipe", P.CYAN, P.BLUE_D],
	"[설비] 물 샘": ["blob", P.BLUE, P.CYAN],
	"[설비]": ["kit", P.CARD, P.G3],
	"?": ["unknown", P.PINK, P.INK],
}
const ATLAS_COLS := 16
const PLAYER_W := 16
const PLAYER_H := 24
const PLAYER_COLS := 8
const UI_ICONS := ["hand", "gear", "box", "hammer", "fist", "move", "crowbar", "rotate", "check", "warn", "bolt", "stop",
	"empty", "blocked", "bolt_red", "question", "drop", "broken"]   # empty부터: 설비 상태 아이콘 (StatusIcons)


# ---------- 진입점 ----------

static func make(key: String, cells: Vector2i = Vector2i.ONE) -> Image:
	match key:
		"tiles":
			return tiles()
		"items8":
			return items(8)
		"items16":
			return items(16)
		"rail_mk1":
			return rail_sheet(1)
		"rail_mk2":
			return rail_sheet(2)
		"rail_mk3":
			return rail_sheet(3)
		"trash_heap":
			return trash_heap()
		"player":
			return player_sheet()
		"worker_delivery":
			return worker_sheet({P.ORANGE: P.GREEN, P.ORANGE_L: P.LIME, P.BLUE: P.RED_D, P.CYAN: P.RED, P.BLUE_D: P.BROWN_D})
		"worker_repair":
			return worker_sheet({P.ORANGE: P.YELLOW, P.ORANGE_L: P.PAPER, P.BLUE: P.G3, P.CYAN: P.G4, P.BLUE_D: P.G2})
		"ui_icons":
			return ui_icons()
	return building(key, cells)


# ---------- 타일 ----------
# 깔끔한 어두운 바닥: 단색 면 + 1px 줄눈 + 1px 윗·왼쪽 빛. 자잘한 점은 찍지 않아요.

static func tiles() -> Image:
	var c := PixelCanvas.new(16 * TILES.size(), 16)
	for i in TILES.size():
		c.frame(i * 16, 0, 16, 16)
		_tile(c, TILES[i])
	return c.img


static func _floor(c: PixelCanvas, base: int, grout: int, lit: int) -> void:
	c.rect(0, 0, 16, 16, base)
	c.rect(0, 0, 16, 1, lit)
	c.rect(0, 0, 1, 16, lit)
	c.rect(0, 15, 16, 1, grout)
	c.rect(15, 0, 1, 16, grout)


static func _tile(c: PixelCanvas, name: String) -> void:
	match name:
		"floor":
			_floor(c, P.FLOOR, P.FLOOR_D, P.G2)
		"floor_quad":
			# 작은 타일 4장
			_floor(c, P.FLOOR, P.FLOOR_D, P.G2)
			c.rect(0, 7, 16, 1, P.FLOOR_D)
			c.rect(7, 0, 1, 16, P.FLOOR_D)
			c.rect(0, 8, 16, 1, P.G2)
			c.rect(8, 0, 1, 16, P.G2)
		"floor_worn":
			# 금 간 타일 하나
			_floor(c, P.FLOOR, P.FLOOR_D, P.G2)
			c.line(4, 5, 7, 8, P.FLOOR_D)
			c.line(7, 8, 7, 11, P.FLOOR_D)
		"office":
			# 정문 쪽: 조금 밝은 사무실 타일
			_floor(c, P.G2, P.FLOOR_D, P.G3)
		"hazard":
			# 설치 금지 통로: 노랑·어두운 사선 띠
			_floor(c, P.FLOOR, P.FLOOR_D, P.G2)
			for y in range(1, 15):
				for x in range(1, 15):
					if int((x + y) / 4.0) % 2 == 0:
						c.px(x, y, P.YELLOW)
		"corridor":
			_floor(c, P.G1, P.INK, P.FLOOR_D)
		"wall", "wall_poster", "corridor_wall":
			# 누런 벽: 윗면(벽 꼭대기) + 아래 앞면 띠
			var top := P.WALL if name != "corridor_wall" else P.WALL_D
			var face := P.WALL_D if name != "corridor_wall" else P.BROWN
			c.rect(0, 0, 16, 16, top)
			c.rect(0, 0, 16, 1, P.CREAM)
			c.rect(0, 11, 16, 4, face)
			c.rect(0, 15, 16, 1, P.BROWN_D)
			c.rect(15, 1, 1, 10, face)
			if name == "wall_poster":
				c.rect(4, 2, 8, 7, P.INK)
				c.rect(5, 3, 6, 5, P.PAPER)
				c.rect(6, 4, 1, 1, P.INK)
				c.rect(9, 4, 1, 1, P.INK)
				c.rect(6, 6, 4, 1, P.RED)
		"door":
			# 정문 셔터
			for y in 16:
				c.rect(0, y, 16, 1, P.G4 if y % 4 < 3 else P.G2)
			c.rect(0, 0, 16, 1, P.G5)
			c.rect(0, 0, 2, 16, P.YELLOW)
			c.rect(14, 0, 2, 16, P.YELLOW)
		"barrier":
			_floor(c, P.G1, P.INK, P.FLOOR_D)
			c.rect(1, 5, 2, 9, P.G3)
			c.rect(13, 5, 2, 9, P.G3)
			c.rect(0, 6, 16, 4, P.INK)
			for x in range(1, 15):
				c.rect(x, 7, 1, 2, P.RED if int(x / 3.0) % 2 == 0 else P.PAPER)
		"water":
			_floor(c, P.FLOOR, P.FLOOR_D, P.G2)
			c.disc(8, 8, 7, P.BLUE_D)
			c.disc(8, 8, 6, P.BLUE)
			c.rect(4, 5, 4, 1, P.CYAN)
			c.rect(3, 6, 1, 2, P.CYAN)
			c.rect(9, 11, 3, 1, P.CYAN)


# ---------- 깔끔한 물건 조각 (쓰레기 더미용) ----------
# 각 조각은 먼저 테두리색으로 1px 크게 칠하고 안을 채워 또렷하게 보여요.

static func _o_rect(c: PixelCanvas, x: int, y: int, w: int, h: int, fill: int, hi: int, lo: int) -> void:
	c.rect(x - 1, y - 1, w + 2, h + 2, P.INK)
	c.rect(x, y, w, h, fill)
	c.rect(x, y, w, 1, hi)
	c.rect(x, y + h - 1, w, 1, lo)


static func _o_disc(c: PixelCanvas, x: float, y: float, r: float, fill: int, hi: int) -> void:
	c.disc(x, y, r + 1, P.INK)
	c.disc(x, y, r, fill)
	c.disc(x - r * 0.35, y - r * 0.35, maxf(1.0, r * 0.35), hi)


static func _junk(c: PixelCanvas, kind: int, x: int, y: int) -> void:
	match kind % 7:
		0:  # 박스
			_o_rect(c, x, y, 9, 7, P.CARD, P.ORANGE_L, P.BROWN)
			c.rect(x + 4, y, 1, 7, P.BROWN)
		1:  # 쓰레기 봉투
			_o_disc(c, x + 4, y + 4, 4, P.G1, P.G2)
			c.rect(x + 3, y - 1, 2, 2, P.YELLOW)
		2:  # 타이어
			c.disc(x + 4, y + 4, 5, P.INK)
			c.disc(x + 4, y + 4, 4, P.G1)
			c.disc(x + 4, y + 4, 1.5, P.G3)
		3:  # 병
			_o_rect(c, x, y + 2, 4, 7, P.GREEN, P.LIME, P.GREEN_D)
			_o_rect(c, x + 1, y, 2, 2, P.GREEN_D, P.GREEN, P.GREEN_D)
		4:  # 캔
			_o_rect(c, x, y, 5, 6, P.G4, P.G5, P.G3)
			c.rect(x, y + 2, 5, 2, P.RED)
		5:  # 종이 뭉치
			_o_rect(c, x, y, 7, 5, P.PAPER, P.PAPER, P.G5)
			c.rect(x + 1, y + 2, 4, 1, P.G4)
		6:  # 플라스틱 통
			_o_rect(c, x, y, 6, 6, P.BLUE, P.CYAN, P.BLUE_D)


static func trash_heap() -> Image:
	## 엄청난 쓰레기 더미: 64×64를 세로로 이어 붙여요. 어두운 흙 바탕에 또렷한 물건 조각.
	var c := PixelCanvas.new(64, 64)
	c.frame(0, 0, 64, 64)
	c.rect(0, 0, 64, 64, P.BROWN_D)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	# 바탕의 큰 덩이 그늘 (점이 아니라 둥근 면으로)
	for i in 8:
		c.disc(rng.randi_range(6, 58), rng.randi_range(8, 56), rng.randi_range(6, 9), P.BROWN)
	# 물건을 촘촘히 겹쳐 쌓아요 (위에서부터 그려 아래 것이 앞에 와요)
	var spots := []
	for i in 50:
		spots.append(Vector2i(rng.randi_range(1, 52), rng.randi_range(2, 54)))
	spots.sort_custom(func(a, b) -> bool: return a.y < b.y)
	for i in spots.size():
		_junk(c, i * 5 + 1, spots[i].x, spots[i].y)
	# 오른쪽 가장자리: 무너진 듯한 경계 + 그림자
	c.rect(62, 0, 2, 64, P.INK)
	for y in range(0, 64, 8):
		c.rect(60, y + 2, 2, 4, P.INK)
	return c.img


# ---------- 레일 ----------

static func rail_sheet(tier: int) -> Image:
	var sheet := Image.create(16 * FRAMES, 16 * 12, false, Image.FORMAT_RGBA8)
	for f in FRAMES:
		var straight := _belt(f, tier, false)
		var curve := _belt(f, tier, true)
		var curve_r := curve.duplicate() as Image
		curve_r.flip_y()
		for d in 4:
			sheet.blit_rect(_rot(straight, d), Rect2i(0, 0, 16, 16), Vector2i(f * 16, d * 16))
			sheet.blit_rect(_rot(curve, d), Rect2i(0, 0, 16, 16), Vector2i(f * 16, (4 + d * 2) * 16))
			sheet.blit_rect(_rot(curve_r, d), Rect2i(0, 0, 16, 16), Vector2i(f * 16, (5 + d * 2) * 16))
	return sheet


static func _rot(src: Image, times: int) -> Image:
	var img := src.duplicate() as Image
	for i in times:
		img.rotate_90(CLOCKWISE)
	return img


static func _tier_colors(tier: int) -> Array:
	## [테두리 어두움, 테두리 밝음]
	match tier:
		2:
			return [P.BLUE_D, P.BLUE]
		3:
			return [P.ORANGE, P.ORANGE_L]
	return [P.G3, P.G4]


static func _belt(f: int, tier: int, curve: bool) -> Image:
	## 오른쪽으로 나가는 벨트 한 칸 (curve면 위에서 들어와 오른쪽으로 꺾여요).
	## 테두리 2줄 + 어두운 벨트 + 8px마다 가는 '>' 줄. 프레임마다 2px씩 움직여요.
	var c := PixelCanvas.new(16, 16)
	var col := _tier_colors(tier)
	for y in 16:
		for x in 16:
			var cross: float
			var along: float
			if curve:
				var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(16, 0))
				if d > 15.5:
					continue
				cross = d - 0.5
				along = (PI - atan2(y + 0.5, x + 0.5 - 16.0)) * 8.0
			else:
				cross = y
				along = x
			var v: int = P.G1
			if cross < 1.0 or cross >= 15.0:
				v = P.INK
			elif cross < 2.0:
				v = col[1]
			elif cross < 3.0 or cross >= 13.0:
				v = col[0]
			elif cross >= 12.0:
				v = P.INK
			elif fposmod(along + absf(cross - 7.5) - f * 2.0, 8.0) < 1.0:
				v = P.G3
			c.px(x, y, v)
	return c.img


# ---------- 설비 ----------

static func building(key: String, cells: Vector2i) -> Image:
	var w := cells.x * 16
	var h := cells.y * 16
	var rows := 2 if key == "sorter" else 1
	var c := PixelCanvas.new(w * FRAMES, h * rows)
	for row in rows:
		for f in FRAMES:
			c.frame(f * w, row * h, w, h)
			_draw_building(c, key, f, w, h, row)
	return c.img


## 재질 색 묶음 [윗면 빛, 윗면, 앞면, 앞면 그늘]
const METAL := [P.G5, P.G4, P.G3, P.G2]
const DARK := [P.G3, P.G2, P.G1, P.INK]
const WOOD := [P.ORANGE_L, P.CARD, P.BROWN, P.BROWN_D]
const GREENS := [P.LIME, P.GREEN, P.GREEN_D, P.TEAL]
const BRICK := [P.RED, P.RED_D, P.BROWN_D, P.INK]
const PINKS := [P.PAPER, P.PINK, P.RED, P.RED_D]
const PURPLES := [P.PINK, P.PURPLE, P.BLUE_D, P.INK]
const TEALS := [P.CYAN, P.TEAL, P.BLUE_D, P.INK]


static func _cab(c: PixelCanvas, x: int, y: int, w: int, h: int, m: Array, depth: int = 6) -> void:
	## 위에서 비스듬히 본 상자: 윗면(빛 1줄) + 아래 앞면(그늘 1줄)
	c.rect(x, y, w, h, m[2])
	c.rect(x, y, w, h - depth, m[1])
	c.rect(x, y, w, 1, m[0])
	c.rect(x, y, 1, h - depth, m[0])
	c.rect(x, y + h - depth, w, 1, m[3])
	c.rect(x, y + h - 1, w, 1, m[3])


static func _inset(c: PixelCanvas, x: int, y: int, w: int, h: int, fill: int, dark: int, light: int) -> void:
	## 오목한 판 (창·구멍·화면): 위·왼쪽 그늘, 아래·오른쪽 빛
	c.rect(x, y, w, h, fill)
	c.rect(x, y, w, 1, dark)
	c.rect(x, y, 1, h, dark)
	c.rect(x, y + h - 1, w, 1, light)
	c.rect(x + w - 1, y, 1, h, light)


static func _lamp(c: PixelCanvas, x: int, y: int, on: bool, col: int) -> void:
	c.rect(x, y, 3, 3, P.INK)
	c.px(x + 1, y + 1, col if on else P.G2)


static func _bolts(c: PixelCanvas, x: int, y: int, w: int, h: int) -> void:
	for p in [Vector2i(x, y), Vector2i(x + w - 1, y), Vector2i(x, y + h - 1), Vector2i(x + w - 1, y + h - 1)]:
		c.px(p.x, p.y, P.G5)


static func _hazard_band(c: PixelCanvas, x: int, y: int, w: int, h: int) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			c.px(xx, yy, P.YELLOW if int((xx + yy - x - y) / 2.0) % 2 == 0 else P.INK)


static func _belt_base(c: PixelCanvas, f: int) -> void:
	c.img.blit_rect(_belt(f, 1, false), Rect2i(0, 0, 16, 16), Vector2i(c.ox, c.oy))


static func _arrow_r(c: PixelCanvas, x: int, y: int, col: int) -> void:
	## 오른쪽을 가리키는 작은 화살표 (가운데 x, y)
	for i in 3:
		c.px(x - 1 + i, y - 2 + i, col)
		c.px(x - 1 + i, y + 2 - i, col)


static func _post_pair(c: PixelCanvas, x: int, top: int) -> void:
	## 벨트 위를 가로지르는 문(갠트리) 기둥: 위·아래
	_cab(c, x, 0, 6, 3, METAL, 1)
	_cab(c, x, 13, 6, 3, METAL, 1)
	if top >= 0:
		c.rect(x + 1, 3, 4, 10, top)


static func _draw_building(c: PixelCanvas, key: String, f: int, w: int, h: int, row: int) -> void:
	var on := f > 0
	var ph := maxi(0, f - 1)   # 가동 중 단계 0~2
	var outline := true
	match key:
		# ----- 1칸: 벨트 위 장치 (테두리 없이 벨트와 이어져요) -----
		"exit":
			outline = false
			_belt_base(c, f)
			_cab(c, 0, 1, 6, 14, DARK, 2)
			c.rect(1, 4, 3, 7, P.INK)
			_arrow_r(c, 10, 7, P.YELLOW)
		"entrance":
			outline = false
			_belt_base(c, f)
			_cab(c, 10, 1, 6, 14, DARK, 2)
			c.rect(12, 4, 3, 7, P.INK)
			_arrow_r(c, 5, 7, P.YELLOW)
		"sorter":
			outline = false
			_belt_base(c, f)
			_post_pair(c, 5, -1)
			# 옆으로 미는 주황 날개: row 0 = 오른쪽(화면 아래), row 1 = 왼쪽(화면 위)
			var down := row == 0
			c.rect(6, 4 if down else 6, 4, 6, P.ORANGE if not on else P.ORANGE_L)
			c.rect(6, 4 if down else 11, 4, 1, P.BROWN)
			c.rect(7, 13 if down else 0, 2, 3, P.YELLOW)
		"detector":
			outline = false
			_belt_base(c, f)
			_post_pair(c, 5, -1)
			_lamp(c, 6, 0, on, P.RED)
			if on:
				c.rect(7, 3, 2, 10, P.RED)
		"judge":
			outline = false
			_belt_base(c, f)
			_post_pair(c, 5, -1)
			_lamp(c, 6, 0, on, P.LIME)
			c.rect(6, 13, 4, 3, P.LIME)
			c.px(7, 14, P.INK)
		"injector":
			outline = false
			_belt_base(c, f)
			_cab(c, 4, 0, 8, 5, METAL, 2)
			c.rect(7, 5, 2, 2, P.G3)
			c.rect(5, 1, 6, 1, P.CYAN)
			if on:
				c.rect(7, 7 + ph * 2, 2, 2, P.CYAN)
		"bridge":
			outline = false
			_belt_base(c, f)
			_cab(c, 2, 2, 12, 12, METAL, 3)
			_hazard_band(c, 2, 2, 2, 9)
			_hazard_band(c, 12, 2, 2, 9)
			_arrow_r(c, 8, 6, P.INK)
		"splitter":
			_cab(c, 1, 1, 14, 14, METAL, 3)
			_inset(c, 4, 3, 8, 7, P.G2, P.G1, P.G4)
			_arrow_r(c, 10, 6, P.ORANGE_L if ph != 0 else P.YELLOW)
			c.rect(7, 3, 2, 2, P.ORANGE_L if ph != 1 else P.YELLOW)
			c.rect(7, 8, 2, 2, P.ORANGE_L if ph != 2 else P.YELLOW)
		"merger":
			_cab(c, 1, 1, 14, 14, METAL, 3)
			_inset(c, 4, 3, 8, 7, P.G2, P.G1, P.G4)
			c.rect(5, 6, 4, 1, P.CYAN)
			c.rect(7, 4, 1, 5, P.CYAN)
			_arrow_r(c, 10, 6, P.YELLOW if on else P.CYAN)
		# ----- 1칸: 상자형 -----
		"combiner":
			_cab(c, 1, 1, 14, 14, METAL, 4)
			c.rect(3, 4, 6, 5, P.PAPER)
			c.rect(4, 5, 4, 1, P.G4)
			c.rect(4, 7, 3, 1, P.G4)
			var sy := 2 + (ph if on else 0)
			_cab(c, 9, sy, 4, 4, [P.PINK, P.RED, P.RED_D, P.RED_D], 1)
			_arrow_r(c, 12, 12, P.YELLOW)
		"pump":
			c.disc(8, 9, 7.5, P.BLUE_D)
			c.disc(8, 9, 6.5, P.BLUE)
			c.rect(3, 6, 3, 1, P.CYAN)
			_cab(c, 5, 2 + (ph if on else 0), 6, 9, METAL, 3)
			c.rect(6, 4 + (ph if on else 0), 4, 2, P.CYAN if on else P.BLUE_D)
		"storage":
			_cab(c, 1, 1, 14, 14, METAL, 4)
			_inset(c, 3, 3, 10, 7, P.G1, P.INK, P.G3)
			for i in f:
				_o_rect(c, 4 + (i % 2) * 4, 4 + int(i / 2.0) * 3, 3, 3, P.CARD, P.ORANGE_L, P.BROWN)
		"shelf":
			_cab(c, 1, 1, 14, 14, WOOD, 4)
			c.rect(2, 6, 12, 1, P.BROWN)
			for i in f:
				var px := 3 + (i % 2) * 5
				var py := 2 + int(i / 2.0) * 5
				c.rect(px, py, 4, 3, P.ORANGE)
				c.rect(px, py, 4, 1, P.ORANGE_L)
				c.rect(px + 1, py, 1, 3, P.CARD)
		"source":
			_cab(c, 1, 1, 14, 14, PURPLES, 4)
			c.disc(5.5, 6, 2, P.PAPER)
			c.disc(10.5, 6, 2, P.PAPER)
			c.disc(5.5, 6, 0.8, P.PURPLE)
			c.disc(10.5, 6, 0.8, P.PURPLE)
			if on:
				c.px(3 + ph * 4, 2, P.YELLOW)
			c.rect(12, 10, 3, 3, P.YELLOW)
		"incinerator":
			_cab(c, 1, 1, 14, 14, DARK, 4)
			_inset(c, 3, 3, 10, 6, P.INK, P.INK, P.G2)
			if on:
				c.disc(8, 6, 2.5 + (ph % 2) * 0.5, P.ORANGE)
				c.disc(8, 7, 1.5, P.YELLOW)
			else:
				c.rect(6, 6, 4, 1, P.RED_D)
			_lamp(c, 11, 10, on, P.RED)
		"turret_guard":
			c.disc(8, 9, 6, P.G2)
			c.disc(8, 8, 5, P.G3)
			c.disc(7, 7, 1.5, P.G4)
			_cab(c, 9 - (1 if on and ph == 0 else 0), 6, 6, 4, METAL, 1)
			c.rect(14 - (1 if on and ph == 0 else 0), 7, 1, 2, P.INK)
		"turret_electric":
			c.disc(8, 10, 5.5, P.G2)
			c.disc(8, 9, 4.5, P.G3)
			c.rect(6, 4, 4, 6, P.ORANGE)
			c.rect(6, 5, 4, 1, P.BROWN)
			c.rect(6, 7, 4, 1, P.BROWN)
			c.disc(8, 3, 2.5, P.G5)
			if on:
				c.line(8, 3, 3 + ph, 0, P.YELLOW)
				c.line(8, 3, 13 - ph, 0, P.YELLOW)
		# ----- 2×2 -----
		"disassembler":
			# 분해기: 분쇄 롤러 두 줄이 맞물려 돌아요
			_cab(c, 1, 1, 30, 29, METAL, 8)
			_inset(c, 5, 4, 22, 14, P.INK, P.INK, P.G2)
			for r in 2:
				var ry := 6 + r * 6
				c.rect(6, ry, 20, 4, P.G3)
				c.rect(6, ry, 20, 1, P.G4)
				for i in 5:
					var tx := 7 + i * 4 + ((ph + r) % 2 if on else 0) * 2
					c.rect(tx, ry + 1, 1, 2, P.G5)
			_hazard_band(c, 4, 24, 14, 3)
			_lamp(c, 23, 24, on, P.LIME)
		"processor":
			# 가공기: 위에서 누르는 프레스
			_cab(c, 1, 1, 30, 29, METAL, 8)
			_inset(c, 5, 3, 22, 16, P.G2, P.G1, P.G3)
			var press: int = [0, 3, 1][ph] if on else 0
			_cab(c, 8, 4 + press, 16, 10, [P.CYAN, P.BLUE, P.BLUE_D, P.INK], 3)
			_bolts(c, 9, 5 + press, 14, 5)
			_inset(c, 4, 23, 12, 5, P.GREEN_D, P.INK, P.G4)
			if on:
				c.rect(5, 25, 2 + ph * 3, 1, P.LIME)
			_lamp(c, 20, 24, on, P.YELLOW)
			_lamp(c, 25, 24, true, P.RED)
		"crafter":
			# 제작기: 작업판 위에서 주황 로봇 팔 두 개가 조립해요
			_cab(c, 1, 1, 30, 29, METAL, 8)
			_inset(c, 4, 3, 24, 16, P.G2, P.G1, P.G3)
			var reach: int = [0, 3, 5][ph] if on else 0
			for sd in [-1, 1]:
				var side: int = sd
				var bx := 16 + side * 10
				c.disc(bx, 11, 3, P.INK)
				c.disc(bx, 11, 2.2, P.ORANGE)
				var tip := bx - side * (3 + reach)
				c.rect(mini(bx, tip), 10, absi(bx - tip) + 1, 2, P.ORANGE)
				c.rect(mini(bx, tip), 10, absi(bx - tip) + 1, 1, P.ORANGE_L)
				c.rect(tip - 1, 8, 2, 6, P.G4)
			_o_rect(c, 14, 9, 4, 4, P.CARD, P.ORANGE_L, P.BROWN)
			_lamp(c, 5, 24, on, P.LIME)
			_lamp(c, 10, 24, on and ph == 1, P.YELLOW)
		"furnace":
			# 용광로: 벽돌 몸통 + 아치 아궁이 + 굴뚝
			_cab(c, 1, 5, 30, 25, BRICK, 9)
			for yy in [9, 14]:
				c.rect(2, yy, 28, 1, P.BROWN_D)
			for xx in [8, 16, 24]:
				c.rect(xx, 6, 1, 3, P.BROWN_D)
				c.rect(xx - 4, 10, 1, 4, P.BROWN_D)
			c.disc(16, 22, 6, P.INK)
			c.rect(10, 22, 12, 7, P.INK)
			if on:
				c.disc(16, 26, 4 + (ph % 2), P.ORANGE)
				c.disc(16, 27, 2, P.YELLOW)
			else:
				c.rect(13, 27, 6, 1, P.RED_D)
			_cab(c, 23, 0, 6, 9, DARK, 2)
			if on:
				c.disc(19 - ph, 2, 1.5 + ph * 0.5, P.G4)
		"workbench":
			# 설비 제작대: 나무 작업대 위 설계도·망치·렌치
			_cab(c, 1, 2, 30, 27, WOOD, 7)
			c.rect(2, 9, 28, 1, P.BROWN)
			c.rect(2, 15, 28, 1, P.BROWN)
			_o_rect(c, 17, 4, 11, 8, P.BLUE, P.CYAN, P.BLUE_D)
			c.rect(19, 6, 6, 1, P.PAPER)
			c.rect(19, 8, 4, 1, P.PAPER)
			var lift: int = [0, -2, 0][ph] if on else 0
			c.rect(5, 12 + lift, 9, 2, P.BROWN_D)
			_o_rect(c, 4, 10 + lift, 3, 5, P.G4, P.G5, P.G3)
			c.rect(19, 16, 8, 2, P.G4)
			c.disc(27, 17, 2, P.G4)
			c.disc(27, 17, 0.8, P.BROWN)
			if on and ph == 1:
				c.px(9, 9, P.YELLOW)
				c.px(11, 10, P.YELLOW)
		"cash_printer":
			_cab(c, 1, 1, 30, 29, GREENS, 8)
			_inset(c, 6, 4, 20, 4, P.INK, P.INK, P.GREEN_D)
			var my := 8 + (ph * 3 if on else 0)
			_o_rect(c, 9, my, 14, 7, P.LIME, P.PAPER, P.GREEN)
			c.disc(16, my + 3.5, 2, P.GREEN)
			_lamp(c, 4, 24, on, P.YELLOW)
			c.rect(10, 25, 12, 2, P.TEAL)
		"packer":
			# 포장기: 가운데 벨트 위에 테이프 아치
			_cab(c, 1, 1, 30, 29, METAL, 8)
			c.rect(1, 10, 30, 10, P.INK)
			c.rect(1, 11, 30, 8, P.G1)
			for i in 4:
				var sx := 2 + i * 8 + (ph * 2 if on else 0)
				c.rect(sx, 11, 1, 8, P.G2)
			var bx := 4 + (ph * 6 if on else 0)
			_o_rect(c, bx, 12, 7, 5, P.ORANGE, P.ORANGE_L, P.BROWN)
			c.rect(bx + 3, 12, 1, 5, P.CARD)
			_cab(c, 13, 3, 6, 16, [P.ORANGE_L, P.ORANGE, P.BROWN, P.BROWN_D], 2)
			c.disc(16, 6, 2.5, P.CARD)
			c.disc(16, 6, 1, P.G2)
			_lamp(c, 4, 23, on, P.LIME)
		"gift_packer":
			_cab(c, 1, 1, 30, 29, PINKS, 8)
			var bob: int = [0, -1, 0][ph] if on else 0
			c.disc(10, 10 + bob, 5, P.RED_D)
			c.disc(22, 10 + bob, 5, P.RED_D)
			c.disc(10, 10 + bob, 4, P.RED)
			c.disc(22, 10 + bob, 4, P.RED)
			c.disc(10, 10 + bob, 1.5, P.RED_D)
			c.disc(22, 10 + bob, 1.5, P.RED_D)
			c.disc(16, 11 + bob, 2.5, P.RED_D)
			c.rect(14, 13 + bob, 2, 6, P.RED)
			c.rect(17, 13 + bob, 2, 6, P.RED)
			_lamp(c, 4, 24, on, P.YELLOW)
		"computer":
			# 작업 컴퓨터: 책상 + 모니터 + 키보드 + 머그컵
			_cab(c, 1, 11, 30, 19, WOOD, 6)
			_cab(c, 7, 1, 18, 14, METAL, 3)
			_inset(c, 9, 3, 14, 7, P.BLUE_D, P.INK, P.BLUE)
			if on:
				for i in 3:
					c.rect(10, 4 + i * 2, [7, 10, 5][(i + ph) % 3], 1, P.LIME)
			else:
				c.rect(10, 4, 3, 1, P.BLUE)
			_cab(c, 7, 17, 15, 5, METAL, 2)
			for i in 6:
				c.px(8 + i * 2, 18, P.G3)
			_o_rect(c, 25, 17, 3, 4, P.PAPER, P.PAPER, P.G4)
			if on:
				_o_rect(c, 2, 14, 4, 4 + ph, P.PAPER, P.PAPER, P.G5)
		"bio_generator":
			# 바이오 발전기: 초록 배양 탱크 + 계기판
			_cab(c, 1, 3, 30, 27, METAL, 7)
			c.disc(12, 12, 9, P.INK)
			c.disc(12, 12, 8, P.G4)
			c.disc(12, 12, 6.5, P.GREEN_D)
			c.disc(12, 12, 5.5, P.GREEN)
			c.disc(9, 9, 1.5, P.LIME)
			if on:
				for i in 3:
					c.px(10 + i * 3, 15 - ((ph + i) % 3) * 3, P.LIME)
			c.disc(25, 10, 3.5, P.INK)
			c.disc(25, 10, 2.5, P.PAPER)
			c.line(25, 10, 25 + (2 if on else -1), 8, P.RED)
			_lamp(c, 23, 16, on, P.LIME)
			c.rect(4, 25, 10, 2, P.G2)
		"coal_generator":
			_cab(c, 1, 3, 30, 27, DARK, 8)
			_inset(c, 4, 5, 14, 9, P.G1, P.INK, P.G3)
			c.disc(8, 10, 3, P.INK)
			c.disc(13, 9, 2.5, P.INK)
			c.disc(8, 10, 2.2, P.G2)
			c.disc(13, 9, 1.8, P.G2)
			c.px(7, 9, P.G4)
			c.px(12, 8, P.G4)
			_inset(c, 5, 22, 12, 6, P.INK, P.INK, P.G2)
			if on:
				c.disc(11, 25, 2 + (ph % 2), P.ORANGE)
				c.px(11, 25, P.YELLOW)
			_cab(c, 22, 0, 7, 12, METAL, 2)
			c.rect(23, 1, 5, 1, P.INK)
			_lamp(c, 24, 22, on, P.YELLOW)
		"pile":
			# 물건 더미 2×2: 흙 둔덕 위 또렷한 물건 조각
			c.disc(16, 18, 13, P.INK)
			c.disc(16, 18, 12, P.BROWN_D)
			c.disc(13, 15, 7, P.BROWN)
			_junk(c, 0, 5, 9)
			_junk(c, 2, 18, 8)
			_junk(c, 3, 13, 18)
			_junk(c, 4, 21, 19)
			_junk(c, 5, 6, 21)
			if on and ph == 1:
				c.px(10, 6, P.LIGHT)
		# ----- 3×3 -----
		"producer":
			# 생산기: 유리 돔 안에서 부품이 돌고, 앞면 불빛 세 개가 차례로
			_cab(c, 1, 1, 46, 45, METAL, 10)
			_bolts(c, 3, 3, 42, 30)
			c.disc(24, 17, 12, P.INK)
			c.disc(24, 17, 11, P.G3)
			c.disc(24, 17, 9, P.TEAL)
			for i in 3:
				var a := (i / 3.0 + (ph / 9.0 if on else 0.0)) * TAU
				_o_disc(c, 24 + cos(a) * 5, 17 + sin(a) * 5, 1.5, P.ORANGE, P.ORANGE_L)
			c.disc(20, 13, 2, P.CYAN)
			for s in 3:
				_inset(c, 1, 8 + s * 8, 4, 5, P.INK, P.INK, P.G2)
			for i in 3:
				_lamp(c, 10 + i * 6, 39, on and i == ph, P.YELLOW)
			c.rect(32, 39, 10, 3, P.G2)
			c.rect(32, 40, 10, 1, P.G1)
		# ----- 4×2 -----
		"dock":
			# 출하 도크: 노란 경계가 그어진 승강장 + 오른쪽 트럭 뒤칸
			_cab(c, 1, 1, 62, 30, METAL, 4)
			_hazard_band(c, 2, 2, 26, 2)
			_inset(c, 3, 6, 24, 18, P.G2, P.G1, P.G4)
			for i in f:
				_o_rect(c, 6 + i * 7, 12, 5, 5, P.ORANGE, P.ORANGE_L, P.BROWN)
			_cab(c, 31, 2, 31, 28, [P.PAPER, P.G5, P.G4, P.G3], 5)
			c.rect(31, 2, 1, 23, P.G3)
			c.rect(46, 3, 1, 21, P.G4)
			c.rect(40, 12, 2, 4, P.G3)
			c.rect(51, 12, 2, 4, P.G3)
			c.rect(33, 26, 6, 3, P.RED)
			c.rect(55, 26, 6, 3, P.RED)
		_:
			_cab(c, 1, 1, w - 2, h - 2, METAL)
	if outline:
		c.outline()


# ---------- 플레이어 (택배 공장 직원: 주황 모자 · 파란 작업복) ----------

static func player_sheet() -> Image:
	var w := PLAYER_W
	var h := PLAYER_H
	var sheet := Image.create(w * PLAYER_COLS, h * 4, false, Image.FORMAT_RGBA8)
	for dir in [0, 1, 3]:
		for col in PLAYER_COLS:
			var c := PixelCanvas.new(w, h)
			c.frame(0, 0, w, h)
			_player(c, dir, col)
			c.outline()
			sheet.blit_rect(c.img, Rect2i(0, 0, w, h), Vector2i(col * w, dir * h))
			if dir == 0:
				# 왼쪽은 오른쪽을 좌우로 뒤집어요
				var m := c.img.duplicate() as Image
				m.flip_x()
				sheet.blit_rect(m, Rect2i(0, 0, w, h), Vector2i(col * w, 2 * h))
	return sheet


static func worker_sheet(swap: Dictionary) -> Image:
	## 아르바이트 직원: 플레이어와 같은 16×24 걷기 칸을 쓰고 모자·옷 색만 바꿔요 (화면에선 조금 작게 그려요)
	var sheet := player_sheet()
	var map := {}
	for k in swap:
		map[P.COLORS[k]] = P.COLORS[swap[k]]
	for y in sheet.get_height():
		for x in sheet.get_width():
			var col := sheet.get_pixel(x, y)
			if map.has(col):
				sheet.set_pixel(x, y, map[col])
	return sheet


static func _player(c: PixelCanvas, dir: int, col: int) -> void:
	var walk := col < 4
	var step := 0          # -1 / 1 : 어느 발이 앞인지
	if walk and col == 1:
		step = 1
	elif walk and col == 3:
		step = -1
	var bob := 1 if (walk and step != 0) or col == 5 else 0
	var o := -bob          # 몸·머리가 위로 1도트 들썩여요
	var swing := col - 6   # 0 = 들어올림, 1 = 휘두름 (공격 칸일 때만)
	var attack := col >= 6
	if dir == 0:
		_player_side(c, step, o, attack, swing)
	else:
		_player_front(c, dir == 3, step, o, attack, swing)


static func _player_front(c: PixelCanvas, back: bool, step: int, o: int, attack: bool, swing: int) -> void:
	# 다리·신발
	var ll := 2 if step == 1 else 3
	var rl := 2 if step == -1 else 3
	c.rect(5, 19, 2, ll, P.BROWN_D)
	c.rect(9, 19, 2, rl, P.BROWN_D)
	c.rect(5, 19 + ll, 2, 1, P.G1)
	c.rect(9, 19 + rl, 2, 1, P.G1)
	# 몸통 (파란 작업복 + 벨트)
	c.rect(4, 13 + o, 8, 6, P.BLUE)
	c.rect(4, 13 + o, 8, 1, P.CYAN)
	c.rect(4, 18 + o, 8, 1, P.BROWN)
	c.rect(7, 14 + o, 2, 3, P.BLUE_D if not back else P.BLUE)
	# 팔
	var la := 1 if step == -1 else 0
	var ra := 1 if step == 1 else 0
	c.rect(3, 13 + o + la, 1, 4, P.BLUE_D)
	c.rect(3, 17 + o + la, 1, 1, P.SKIN)
	if attack:
		var hy := 9 if swing == 0 else 20
		var top := mini(13 + o, hy)
		c.rect(12, top, 1, absi(hy - (13 + o)) + 1, P.BLUE_D)
		c.rect(12, hy, 2, 2, P.SKIN)
		if swing == 1:
			c.line(14, 15, 15, 21, P.PAPER)
	else:
		c.rect(12, 13 + o + ra, 1, 4, P.BLUE_D)
		c.rect(12, 17 + o + ra, 1, 1, P.SKIN)
	# 머리
	c.rect(3, 3 + o, 10, 9, P.BROWN_D)
	if back:
		c.rect(5, 11 + o, 6, 1, P.SKIN)
	else:
		c.rect(4, 6 + o, 8, 6, P.SKIN)
		c.rect(3, 8 + o, 1, 2, P.SKIN)
		c.rect(12, 8 + o, 1, 2, P.SKIN)
		c.rect(6, 8 + o, 1, 2, P.INK)
		c.rect(9, 8 + o, 1, 2, P.INK)
		c.px(5, 10 + o, P.PINK)
		c.px(10, 10 + o, P.PINK)
	# 주황 모자
	c.rect(3, 1 + o, 10, 4, P.ORANGE)
	c.rect(4, 1 + o, 8, 1, P.ORANGE_L)
	if back:
		c.rect(6, 4 + o, 4, 1, P.BROWN)
	else:
		c.rect(3, 5 + o, 10, 1, P.BROWN)


static func _player_side(c: PixelCanvas, step: int, o: int, attack: bool, swing: int) -> void:
	# 다리: 걸을 때 앞뒤로 벌어져요
	var back_x := 6 - (1 if step != 0 else 0)
	var front_x := 8 + (1 if step != 0 else 0)
	c.rect(back_x, 19, 2, 3, P.G1)
	c.rect(front_x, 19, 2, 3, P.BROWN_D)
	c.rect(back_x, 22, 2, 1, P.INK)
	c.rect(front_x, 22, 3, 1, P.G1)
	# 몸통
	c.rect(5, 13 + o, 7, 6, P.BLUE)
	c.rect(5, 13 + o, 7, 1, P.CYAN)
	c.rect(5, 18 + o, 7, 1, P.BROWN)
	# 머리 (뒤통수는 머리카락, 앞쪽은 얼굴)
	c.rect(4, 3 + o, 9, 9, P.BROWN_D)
	c.rect(8, 6 + o, 5, 6, P.SKIN)
	c.rect(10, 8 + o, 1, 2, P.INK)
	c.px(12, 10 + o, P.PINK)
	c.px(7, 8 + o, P.SKIN)
	# 주황 모자 + 앞으로 나온 챙
	c.rect(4, 1 + o, 9, 4, P.ORANGE)
	c.rect(5, 1 + o, 7, 1, P.ORANGE_L)
	c.rect(11, 5 + o, 4, 1, P.BROWN)
	# 팔 (앞쪽 팔)
	if attack:
		if swing == 0:
			c.rect(6, 10 + o, 2, 5, P.BLUE_D)
			c.rect(6, 9 + o, 2, 1, P.SKIN)
		else:
			c.rect(9, 14 + o, 5, 2, P.BLUE_D)
			c.rect(14, 14 + o, 1, 2, P.SKIN)
			c.line(14, 10, 15, 18, P.PAPER)
	else:
		var ax := 8 + step
		c.rect(ax, 13 + o, 2, 4, P.BLUE_D)
		c.rect(ax, 17 + o, 2, 1, P.SKIN)


# ---------- UI 아이콘 (말풍선용 8×8) ----------

static func ui_icons() -> Image:
	var c := PixelCanvas.new(8 * UI_ICONS.size(), 8)
	for i in UI_ICONS.size():
		c.frame(i * 8, 0, 8, 8)
		match UI_ICONS[i]:
			"hand":
				c.rect(2, 3, 4, 4, P.SKIN)
				for fx in 4:
					c.rect(2 + fx, 1 + (1 if fx == 0 or fx == 3 else 0), 1, 2, P.SKIN)
				c.rect(1, 4, 1, 2, P.SKIN)
			"gear":
				c.disc(4, 4, 2.6, P.G4)
				c.rect(3, 0, 2, 8, P.G4)
				c.rect(0, 3, 8, 2, P.G4)
				c.rect(3, 3, 2, 2, P.INK)
			"box":
				c.rect(1, 2, 6, 5, P.CARD)
				c.rect(1, 2, 6, 1, P.ORANGE_L)
				c.rect(3, 2, 2, 5, P.BROWN)
			"hammer":
				c.line(1, 7, 4, 4, P.BROWN)
				c.rect(3, 1, 4, 3, P.G4)
			"fist":
				# 주먹: 손가락 마디 네 개 + 엄지
				c.rect(1, 3, 6, 4, P.SKIN)
				for fx in 4:
					c.rect(1 + fx + (1 if fx > 1 else 0), 1, 1, 2, P.SKIN)
				c.rect(1, 1, 6, 1, P.SKIN)
				c.px(3, 2, P.BROWN)
				c.px(5, 2, P.BROWN)
				c.rect(1, 5, 3, 1, P.BROWN)
			"move":
				c.rect(3, 0, 2, 8, P.CYAN)
				c.rect(0, 3, 8, 2, P.CYAN)
				c.px(2, 1, P.CYAN)
				c.px(5, 1, P.CYAN)
				c.px(2, 6, P.CYAN)
				c.px(5, 6, P.CYAN)
				c.px(1, 2, P.CYAN)
				c.px(6, 2, P.CYAN)
				c.px(1, 5, P.CYAN)
				c.px(6, 5, P.CYAN)
			"crowbar":
				c.line(1, 7, 6, 2, P.RED)
				c.line(2, 7, 7, 2, P.RED)
				c.rect(5, 0, 3, 2, P.RED)
				c.px(5, 2, P.RED_D)
			"check":
				c.line(1, 4, 3, 6, P.LIME)
				c.line(1, 3, 3, 5, P.LIME)
				c.line(3, 6, 7, 1, P.LIME)
				c.line(3, 5, 7, 0, P.LIME)
			"warn":
				for wy in 7:
					c.rect(4 - wy * 0.5, wy + 1, 1 + wy, 1, P.YELLOW)
				c.rect(3.5, 3, 1, 2, P.INK)
				c.px(3, 6, P.INK)
			"bolt":
				c.line(5, 0, 2, 4, P.YELLOW)
				c.line(6, 0, 3, 4, P.YELLOW)
				c.rect(2, 4, 4, 1, P.YELLOW)
				c.line(5, 4, 2, 8, P.YELLOW)
			"stop":
				c.rect(1, 1, 6, 6, P.RED)
				c.rect(2, 3, 4, 2, P.PAPER)
			"empty":
				# 빈 상자: 뚜껑 열린 상자 테두리, 안은 비어 있어요
				c.rect(1, 3, 6, 4, P.CARD)
				c.rect(2, 4, 4, 2, P.INK)
				c.rect(0, 2, 2, 1, P.ORANGE_L)
				c.rect(6, 2, 2, 1, P.ORANGE_L)
			"blocked":
				# 빨간 화살표가 벽에 막힘
				c.rect(0, 3, 4, 2, P.RED)
				c.line(4, 1, 6, 4, P.RED)
				c.line(4, 6, 6, 4, P.RED)
				c.rect(4, 2, 1, 4, P.RED)
				c.rect(7, 0, 1, 8, P.PAPER)
			"bolt_red":
				c.line(5, 0, 2, 4, P.RED)
				c.line(6, 0, 3, 4, P.RED)
				c.rect(2, 4, 4, 1, P.RED)
				c.line(5, 4, 2, 8, P.RED)
			"question":
				c.rect(2, 0, 4, 1, P.YELLOW)
				c.rect(1, 1, 2, 2, P.YELLOW)
				c.rect(5, 1, 2, 2, P.YELLOW)
				c.rect(4, 3, 2, 1, P.YELLOW)
				c.rect(3, 4, 2, 1, P.YELLOW)
				c.rect(3, 6, 2, 2, P.YELLOW)
			"broken":
				# 고장: 빨간 바탕 위 렌치
				c.rect(0, 0, 8, 8, P.RED_D)
				c.line(1, 6, 5, 2, P.PAPER)
				c.line(2, 7, 6, 3, P.PAPER)
				c.rect(5, 0, 3, 2, P.PAPER)
				c.px(6, 1, P.RED_D)
			"drop":
				c.px(4, 0, P.CYAN)
				c.rect(3, 1, 2, 2, P.CYAN)
				c.rect(2, 3, 4, 2, P.CYAN)
				c.rect(1, 5, 6, 2, P.CYAN)
				c.rect(2, 7, 4, 1, P.CYAN)
				c.px(2, 5, P.PAPER)
			"rotate":
				# 돌아가는 화살표: 고리 + 오른쪽 위 화살촉
				c.disc(4, 4, 3.6, P.PAPER)
				c.disc(4, 4, 2.0, P.CLEAR)
				c.rect(4, 0, 4, 4, P.CLEAR)
				c.rect(4, 0, 3, 1, P.PAPER)
				c.rect(5, 1, 1, 2, P.PAPER)
				c.px(6, 1, P.PAPER)
		c.outline()
	return c.img


# ---------- 아이템 ----------

static func items(size: int) -> Image:
	var names := ITEMS.keys()
	var rows := int(ceil(names.size() / float(ATLAS_COLS)))
	var c := PixelCanvas.new(ATLAS_COLS * size, rows * size)
	c.k = size / 16.0
	for i in names.size():
		c.frame((i % ATLAS_COLS) * size, int(i / float(ATLAS_COLS)) * size, size, size)
		var spec: Array = ITEMS[names[i]]
		_item(c, spec[0], spec[1], spec[2])
		if spec.size() > 3 and spec[3]:
			c.rect(12, 1, 2, 2, P.LIGHT)
			c.rect(2, 12, 1, 1, P.LIGHT)
		c.outline()
	return c.img


static func _box_item(c: PixelCanvas, x: float, y: float, w: float, h: float, a: int, b: int) -> void:
	c.rect(x, y, w, h, a)
	c.rect(x, y, w, 2, b)


static func _item(c: PixelCanvas, shape: String, a: int, b: int) -> void:
	match shape:
		"duck":
			c.disc(7, 10, 5, a)
			c.disc(10, 5, 3, a)
			c.rect(12.5, 5, 3, 2, b)
			c.rect(10, 4, 1, 1, P.INK)
		"drumstick":
			c.disc(6, 7, 4.5, a)
			c.rect(9, 9, 4, 2.5, b)
			c.disc(13, 12, 1.8, b)
		"twig":
			c.line(3, 13, 13, 3, a)
			c.line(4, 13, 14, 3, a)
			c.line(7, 9, 4, 5, a)
			c.disc(11, 8, 2.2, b)
		"rock":
			c.disc(8, 9, 5.5, a)
			c.disc(6, 7, 2, b)
		"tv":
			c.rect(2, 4, 12, 10, a)
			c.rect(4, 6, 8, 6, b)
			c.line(6, 1, 8, 4, P.G2)
			c.line(10, 1, 8, 4, P.G2)
		"shirt":
			c.rect(4, 4, 8, 10, a)
			c.rect(1, 4, 3, 4, a)
			c.rect(12, 4, 3, 4, a)
			c.rect(6, 4, 4, 1.5, b)
		"fold":
			c.rect(2, 5, 12, 8, a)
			c.rect(5, 5, 6, 2, b)
			c.rect(2, 10, 12, 1, b)
		"trashbag":
			c.disc(8, 10, 5.5, a)
			c.rect(6, 2, 4, 4, a)
			c.rect(5, 5, 6, 1.5, b)
		"carcass_s", "carcass_m", "carcass_l":
			var r: float = {"carcass_s": 3.5, "carcass_m": 4.8, "carcass_l": 6.2}[shape]
			c.disc(8, 9, r, a)
			c.line(8 - r, 13, 8 - r - 1, 15, a)
			c.line(8 + r, 13, 8 + r + 1, 15, a)
			c.rect(6, 7, 1, 1, P.INK)
			c.rect(10, 7, 1, 1, P.INK)
			c.rect(7, 10, 3, 1, b)
		"coal":
			c.disc(6, 9, 3.5, a)
			c.disc(10, 7, 3.5, a)
			c.disc(10, 11, 3, a)
			c.rect(9, 6, 1, 1, b)
		"pellets":
			c.disc(5, 6, 2.5, a)
			c.disc(10, 6, 2.5, b)
			c.disc(7, 11, 2.5, a)
			c.disc(12, 11, 2, b)
		"blob":
			c.disc(8, 9, 5.5, a)
			c.disc(6, 7, 1.5, b)
			c.disc(10, 11, 1, b)
		"paper", "request":
			c.rect(3, 2, 10, 12, a)
			c.rect(5, 5, 6, 1, b if shape == "paper" else P.G4)
			c.rect(5, 8, 6, 1, b if shape == "paper" else P.G4)
			if shape == "request":
				c.disc(11, 11, 2, b)
		"pebbles":
			c.disc(5, 6, 2.5, a)
			c.disc(10, 8, 2.5, b)
			c.disc(6, 11, 2.5, a)
		"scrap":
			c.rect(2, 7, 12, 4, a)
			c.rect(5, 3, 4, 10, a)
			c.rect(10, 8, 2, 2, b)
		"yarn":
			c.disc(8, 8, 5.5, a)
			c.line(4, 6, 12, 10, b)
			c.line(5, 11, 11, 4, b)
		"rubber":
			c.disc(8, 9, 5, a)
			c.disc(6, 7, 1.5, b)
		"glue":
			c.rect(2, 6, 10, 5, a)
			c.rect(12, 7, 3, 3, b)
			c.rect(4, 7, 4, 3, b)
		"gem":
			for i in 6:
				c.rect(8 - i, 3 + i, i * 2 + 1, 1, a)
			for i in 5:
				c.rect(3 + i, 9 + i, 11 - i * 2, 1, a)
			c.rect(6, 6, 2, 2, b)
		"meat":
			c.disc(8, 9, 5.5, a)
			c.disc(6, 8, 1.5, b)
			c.disc(10, 11, 1.2, b)
		"bucket":
			c.rect(4, 6, 8, 8, a)
			c.rect(3, 5, 10, 2, a)
			c.line(4, 5, 8, 1, P.G2)
			c.line(12, 5, 8, 1, P.G2)
			if b != P.CLEAR:
				c.rect(4, 6, 8, 3, b)
		"bottle":
			c.rect(5, 5, 6, 10, a)
			c.rect(7, 2, 2, 3, a)
			c.rect(7, 1, 2, 1, P.G5)
			c.rect(5, 8, 6, 3, b)
		"plate":
			c.rect(2, 5, 12, 7, a)
			c.rect(3, 6, 10, 1, b)
		"glass":
			c.rect(3, 3, 10, 10, a)
			c.line(5, 10, 10, 5, b)
		"tape":
			c.disc(8, 8, 5.5, a)
			c.disc(8, 8, 2.5, P.CLEAR)
			c.rect(10, 11, 4, 2, b)
		"box_s":
			_box_item(c, 3, 5, 10, 9, a, b)
		"box_l":
			_box_item(c, 1, 3, 14, 12, a, b)
		"parcel":
			_box_item(c, 2, 4, 12, 10, a, b)
			c.rect(7, 4, 2, 10, P.CARD)
		"gift":
			_box_item(c, 2, 5, 12, 9, a, P.ORANGE_L)
			c.rect(7, 5, 2, 9, b)
			c.rect(2, 8, 12, 2, b)
			c.disc(6, 4, 2, b)
			c.disc(10, 4, 2, b)
		"bubble":
			c.rect(2, 4, 12, 9, a)
			for i in 6:
				c.disc(4.5 + (i % 3) * 3.5, 6.5 + int(i / 3.0) * 4, 1.2, b)
		"bow":
			c.disc(5, 7, 3, a)
			c.disc(11, 7, 3, a)
			c.disc(8, 8, 1.8, b)
			c.line(7, 9, 5, 14, a)
			c.line(9, 9, 11, 14, a)
		"plank":
			c.rect(1, 6, 14, 5, a)
			c.rect(3, 8, 9, 1, b)
		"screw":
			c.rect(4, 2, 8, 3, a)
			c.rect(7, 5, 2, 9, a)
			c.rect(7, 7, 2, 1, b)
			c.rect(7, 10, 2, 1, b)
		"gear", "precision":
			c.disc(8, 8, 4.5, a)
			for i in 8:
				var ang := i * TAU / 8.0
				c.disc(8 + cos(ang) * 5, 8 + sin(ang) * 5, 1.4, a)
			c.disc(8, 8, 1.8, b)
			if shape == "precision":
				c.rect(10, 10, 5, 5, b)
				c.rect(11, 11, 3, 3, P.LIME)
		"coil":
			c.disc(8, 8, 5.5, a)
			c.disc(8, 8, 2.5, b)
			c.line(3, 13, 1, 15, b)
		"motor":
			c.rect(2, 5, 10, 7, a)
			c.rect(12, 7, 3, 3, P.G5)
			c.rect(4, 5, 2, 7, b)
			c.rect(8, 5, 2, 7, b)
		"frame":
			c.rect(2, 2, 12, 2, a)
			c.rect(2, 12, 12, 2, a)
			c.rect(2, 2, 2, 12, a)
			c.rect(12, 2, 2, 12, a)
			c.line(3, 3, 12, 12, b)
		"panel":
			c.rect(2, 3, 12, 10, a)
			c.rect(4, 5, 2, 2, b)
			c.rect(7, 5, 2, 2, P.RED)
			c.rect(10, 5, 2, 2, P.YELLOW)
			c.rect(4, 9, 8, 2, P.G4)
		"chip":
			c.rect(4, 4, 8, 8, a)
			for i in 3:
				c.rect(2, 5 + i * 2.5, 2, 1, P.G5)
				c.rect(12, 5 + i * 2.5, 2, 1, P.G5)
			c.rect(6, 6, 2, 2, b)
		"burger":
			c.rect(3, 3, 10, 4, a)
			c.rect(2, 7, 12, 1, b)
			c.rect(2, 8, 12, 2, P.BROWN_D)
			c.rect(3, 10, 10, 3, a)
		"sale":
			c.rect(2, 3, 12, 11, P.CARD)
			c.rect(4, 5, 8, 7, a)
			c.rect(4, 5, 8, 2, b)
			c.rect(11, 2, 3, 3, P.ORANGE)
		"bento":
			c.rect(2, 4, 12, 9, a)
			c.rect(3, 5, 5, 7, b)
			c.rect(9, 5, 4, 3, P.GREEN)
			c.rect(9, 9, 4, 3, P.YELLOW)
		"lamp":
			c.rect(4, 2, 8, 4, a)
			c.rect(7, 6, 2, 6, b)
			c.rect(4, 12, 8, 2, P.G2)
		"can":
			c.rect(4, 3, 8, 11, b)
			c.rect(4, 6, 8, 5, a)
			c.rect(4, 3, 8, 1, P.G5)
		"fridge":
			c.rect(4, 1, 8, 14, a)
			c.rect(4, 6, 8, 1, b)
			c.rect(10, 3, 1, 2, b)
			c.rect(10, 8, 1, 3, b)
		"basket":
			c.disc(5, 7, 2.5, P.RED)
			c.disc(9, 6, 2.5, P.YELLOW)
			c.disc(12, 8, 2, P.GREEN)
			c.rect(2, 8, 12, 6, a)
			c.rect(2, 10, 12, 1, b)
		"robot":
			c.rect(4, 2, 8, 6, a)
			c.rect(5, 4, 2, 2, b)
			c.rect(9, 4, 2, 2, b)
			c.rect(5, 9, 6, 5, P.G3)
			c.rect(7, 0, 2, 2, P.RED)
		"toolbox":
			c.rect(2, 6, 12, 8, a)
			c.rect(5, 3, 6, 3, b)
			c.rect(6, 4, 4, 2, P.CLEAR)
			c.rect(2, 9, 12, 1, P.RED_D)
		"money":
			c.rect(2, 5, 12, 8, a)
			c.rect(3, 4, 12, 1, P.GREEN_D)
			c.rect(7, 5, 2, 8, b)
		"leather":
			c.disc(8, 8, 5.5, a)
			c.disc(4, 4, 2, a)
			c.disc(12, 12, 2, a)
			c.disc(9, 7, 1.5, b)
		"bag", "bag_money":
			c.rect(3, 6, 10, 8, a)
			c.line(5, 6, 8, 2, b)
			c.line(11, 6, 8, 2, b)
			if shape == "bag_money":
				c.rect(4, 4, 4, 3, b)
				c.rect(8, 3, 4, 3, b)
		"pipe":
			c.rect(1, 6, 14, 4, a)
			c.rect(1, 6, 14, 1, P.PAPER)
			c.rect(2, 5, 3, 6, b)
			c.rect(11, 5, 3, 6, b)
		"kit":
			_box_item(c, 2, 3, 12, 11, a, P.CARD)
			c.disc(8, 9, 3, b)
			c.disc(8, 9, 1, a)
		_:
			c.disc(8, 8, 5.5, a)
			c.rect(7, 4, 2, 5, b)
			c.rect(7, 11, 2, 2, b)
