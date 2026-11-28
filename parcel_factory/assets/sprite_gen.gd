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

const P := preload("res://assets/palette.gd")
const FRAMES := 4

const TILES := ["carpet_a", "carpet_b", "carpet_stain", "carpet_lit", "office", "hazard", "corridor", "wall", "wall_poster", "door", "barrier", "water", "corridor_wall"]

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
	"[설비]": ["kit", P.CARD, P.G3],
	"?": ["unknown", P.PINK, P.INK],
}
const ATLAS_COLS := 16


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
	return building(key, cells)


# ---------- 타일 ----------

static func tiles() -> Image:
	var c := PixelCanvas.new(16 * TILES.size(), 16)
	for i in TILES.size():
		c.frame(i * 16, 0, 16, 16)
		var rng := RandomNumberGenerator.new()
		rng.seed = i * 7919 + 13
		_tile(c, TILES[i], rng)
	return c.img


static func _carpet(c: PixelCanvas, rng: RandomNumberGenerator, base: int, dark: int) -> void:
	# 바랜 누런 카펫: 촘촘한 고리 무늬 + 얼룩 점
	for y in 16:
		for x in 16:
			c.px(x, y, dark if (x * 3 + y * 5) % 7 == 0 or rng.randf() < 0.08 else base)


static func _tile(c: PixelCanvas, name: String, rng: RandomNumberGenerator) -> void:
	match name:
		"carpet_a":
			_carpet(c, rng, P.CARPET, P.CARPET_D)
		"carpet_b":
			_carpet(c, rng, P.CARPET, P.CARPET_D)
			c.px(rng.randi_range(2, 13), rng.randi_range(2, 13), P.BROWN)
		"carpet_stain":
			_carpet(c, rng, P.CARPET, P.CARPET_D)
			c.disc(rng.randi_range(6, 9), rng.randi_range(6, 9), 3.6, P.CARPET_D)
			c.disc(rng.randi_range(6, 9), rng.randi_range(6, 9), 1.6, P.BROWN)
		"carpet_lit":
			# 형광등 바로 아래: 살짝 누렇게 밝은 카펫
			_carpet(c, rng, P.WALL_D, P.CARPET)
		"office", "hazard":
			for y in 16:
				for x in 16:
					var v := P.G5 if rng.randf() < 0.9 else P.G4
					if x == 15 or y == 15:
						v = P.G4
					c.px(x, y, v)
			if name == "hazard":
				for y in 16:
					for x in 16:
						if (x + y) % 8 < 4 and (x + y) % 2 == 0:
							c.px(x, y, P.YELLOW)
						elif (x + y) % 8 >= 4 and (x + y) % 2 == 0:
							c.px(x, y, P.INK)
		"corridor":
			for y in 16:
				for x in 16:
					c.px(x, y, P.G1 if rng.randf() < 0.85 else P.INK)
		"wall", "wall_poster", "corridor_wall":
			# 누런 벽지: 세로 줄무늬, 아래 걸레받이
			for y in 16:
				for x in 16:
					c.px(x, y, P.WALL_D if x % 4 == 1 else P.WALL)
			c.rect(0, 0, 16, 2, P.CREAM)
			c.rect(0, 13, 16, 3, P.BROWN)
			c.rect(0, 13, 16, 1, P.BROWN_D)
			if name == "wall_poster":
				# 병맛 포스터: '야근은 즐거워' 스마일
				c.rect(4, 3, 8, 8, P.PAPER)
				c.disc(8, 7, 2.6, P.YELLOW)
				c.px(7, 6, P.INK)
				c.px(9, 6, P.INK)
				c.rect(7, 8, 3, 1, P.INK)
			if name == "corridor_wall":
				for y in 16:
					for x in 16:
						if (x + y) % 3 == 0:
							c.px(x, y, P.WALL_D)
		"door":
			# 정문 셔터: 금속 가로 살 + 노란 테
			for y in 16:
				for x in 16:
					var v := P.G4 if y % 4 < 2 else P.G3
					if y % 4 == 3:
						v = P.G2
					c.px(x, y, v)
			c.rect(0, 0, 2, 16, P.YELLOW)
			c.rect(14, 0, 2, 16, P.YELLOW)
		"barrier":
			for y in 16:
				for x in 16:
					c.px(x, y, P.G1)
			for x in 16:
				for y in range(6, 10):
					c.px(x, y, P.RED if int((x + y) / 4.0) % 2 == 0 else P.PAPER)
			c.rect(1, 4, 2, 10, P.INK)
			c.rect(13, 4, 2, 10, P.INK)
		"water":
			for y in 16:
				for x in 16:
					c.px(x, y, P.BLUE)
			c.disc(8, 8, 6.5, P.CYAN)
			c.disc(8, 8, 4.5, P.BLUE)
			c.rect(4, 5, 3, 1, P.PAPER)
			c.rect(9, 10, 2, 1, P.PAPER)


static func trash_heap() -> Image:
	## 엄청난 쓰레기 더미: 64×64를 세로로 이어 붙여 그려요
	var c := PixelCanvas.new(64, 64)
	c.frame(0, 0, 64, 64)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for y in 64:
		for x in 64:
			c.px(x, y, P.BROWN_D if rng.randf() < 0.7 else P.BROWN)
	var junk := [P.PAPER, P.G4, P.GREEN, P.RED, P.BLUE, P.YELLOW, P.CARD, P.G2, P.PINK]
	for i in 70:
		var col: int = junk[rng.randi_range(0, junk.size() - 1)]
		var w := rng.randi_range(2, 6)
		var h := rng.randi_range(2, 4)
		var x0 := rng.randi_range(0, 63 - w)
		var y0 := rng.randi_range(0, 63 - h)
		c.rect(x0, y0, w, h, col)
		c.rect(x0, y0 + h, w, 1, P.INK)
	# 오른쪽 가장자리는 무너진 듯 들쭉날쭉
	for y in 64:
		var d := rng.randi_range(0, 2)
		for x in range(64 - d, 64):
			c.px(x, y, P.INK if x == 64 - d else P.BROWN_D)
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
	## [테두리 어두움, 테두리 밝음, 벨트 무늬]
	match tier:
		2:
			return [P.BLUE_D, P.BLUE, P.G3]
		3:
			return [P.ORANGE, P.ORANGE_L, P.G3]
	return [P.G2, P.G4, P.G3]


static func _belt(f: int, tier: int, curve: bool) -> Image:
	## 오른쪽으로 나가는 벨트 한 칸. curve면 위에서 들어와 오른쪽으로 꺾여요
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
				cross = d - 0.5        # 0(안쪽) ~ 15(바깥)
				var th := atan2(y + 0.5, x + 0.5 - 16.0)
				along = (PI - th) * 8.0
			else:
				cross = y
				along = x
			var v: int
			if cross < 1.0 or cross >= 15.0:
				v = P.INK
			elif cross < 2.0 or cross >= 13.0:
				v = col[1] if cross < 2.0 or cross >= 14.0 else col[0]
			elif cross < 3.0:
				v = col[0]
			else:
				v = P.G1
				var s := fposmod(along + absf(cross - 7.5) * 0.8 - f * 4.0, 8.0)
				if s < 2.0:
					v = col[2]
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


static func _box(c: PixelCanvas, x: int, y: int, w: int, h: int, top: int, front: int, depth: int = 3) -> void:
	## 위에서 내려다본 상자: 윗면 + 아래쪽 앞면 띠
	c.rect(x, y, w, h, front)
	c.rect(x, y, w, h - depth, top)
	c.rect(x, y, w, 1, P.G5 if top != P.G5 else P.PAPER)


static func _eyes(c: PixelCanvas, x: int, y: int, look: int) -> void:
	## 병맛 눈알 한 쌍 (look: -1 왼쪽, 0 가운데, 1 오른쪽)
	for ex in [x, x + 6]:
		c.disc(ex + 2, y + 2, 2.2, P.PAPER)
		c.px(ex + 2 + look, y + 2, P.INK)
		c.px(ex + 2 + look, y + 1, P.INK)


static func _belt_base(c: PixelCanvas, f: int) -> void:
	c.img.blit_rect(_belt(f, 1, false), Rect2i(0, 0, 16, 16), Vector2i(c.ox, c.oy))


static func _arrow_r(c: PixelCanvas, x: int, y: int, col: int) -> void:
	## 오른쪽을 가리키는 작은 화살표 (가운데 x, y)
	for i in 3:
		c.px(x - 1 + i, y - 2 + i, col)
		c.px(x - 1 + i, y + 2 - i, col)


static func _draw_building(c: PixelCanvas, key: String, f: int, w: int, h: int, row: int) -> void:
	var on := f > 0
	var ph := maxi(0, f - 1)   # 가동 중 단계 0~2
	match key:
		"exit":
			_belt_base(c, f)
			c.rect(0, 2, 6, 12, P.G2)
			c.rect(1, 4, 4, 8, P.INK)
			c.rect(0, 2, 6, 1, P.G4)
			_arrow_r(c, 11, 8, P.YELLOW)
		"entrance":
			_belt_base(c, f)
			c.rect(10, 2, 6, 12, P.G2)
			c.rect(11, 4, 4, 8, P.INK)
			c.rect(10, 2, 6, 1, P.G4)
			_arrow_r(c, 5, 8, P.YELLOW)
		"sorter":
			_belt_base(c, f)
			c.rect(5, 3, 6, 10, P.G3)
			c.rect(5, 3, 6, 1, P.G5)
			c.rect(7, 6, 2, 4, P.YELLOW if on else P.ORANGE)
			# 옆 출력: row 0 = 오른쪽(화면 아래), row 1 = 왼쪽(화면 위)
			var sy := 13 if row == 0 else 0
			c.rect(6, sy, 4, 3, P.ORANGE)
			c.px(8 if row == 0 else 7, 15 if row == 0 else 0, P.INK)
		"splitter":
			_box(c, 2, 2, 12, 12, P.G3, P.G2, 2)
			_arrow_r(c, 11, 8, P.ORANGE_L)
			c.rect(7, 3, 2, 3, P.ORANGE_L if ph != 1 else P.YELLOW)
			c.rect(7, 10, 2, 3, P.ORANGE_L if ph != 2 else P.YELLOW)
			c.rect(4, 7, 4, 2, P.ORANGE_L)
		"merger":
			_box(c, 2, 2, 12, 12, P.G3, P.G2, 2)
			c.rect(3, 7, 6, 2, P.CYAN)
			c.rect(7, 3, 2, 5, P.CYAN)
			c.rect(7, 8, 2, 5, P.CYAN)
			_arrow_r(c, 11, 8, P.YELLOW if on else P.CYAN)
		"bridge":
			_belt_base(c, f)
			for y in range(2, 14):
				c.px(2, y, P.YELLOW if y % 2 == 0 else P.INK)
				c.px(13, y, P.YELLOW if y % 2 == 0 else P.INK)
			c.rect(4, 5, 8, 6, P.G4)
			_arrow_r(c, 8, 8, P.INK)
		"detector":
			_belt_base(c, f)
			c.rect(6, 1, 4, 3, P.G4)
			c.rect(6, 12, 4, 3, P.G4)
			c.px(7, 2, P.RED if on else P.G2)
			if on:
				c.rect(7, 4, 2, 8, P.RED)
		"judge":
			_belt_base(c, f)
			c.rect(4, 1, 8, 3, P.G4)
			c.rect(6, 12, 4, 4, P.LIME)
			c.px(7, 14, P.INK)
			c.px(8, 13, P.INK)
			c.px(6, 13, P.INK)
			c.rect(7, 1, 2, 2, P.LIME if on else P.G2)
		"injector":
			_belt_base(c, f)
			c.rect(5, 0, 6, 5, P.G4)
			c.rect(7, 5, 2, 2, P.G3)
			c.rect(5, 0, 6, 1, P.CYAN)
			if on:
				c.rect(7, 7 + ph, 2, 2, P.CYAN)
		"combiner":
			_box(c, 1, 2, 14, 13, P.G4, P.G3)
			c.rect(3, 5, 7, 6, P.PAPER)
			c.rect(4, 6, 5, 1, P.G4)
			c.rect(4, 8, 4, 1, P.G4)
			var sy2 := 3 if not on else 4 + ph
			c.rect(9, sy2, 4, 3, P.RED)
			c.rect(10, 1, 2, sy2 - 1, P.G2)
			_arrow_r(c, 13, 12, P.YELLOW)
		"pump":
			c.rect(0, 0, 16, 16, P.BLUE)
			c.disc(8, 9, 6, P.CYAN)
			_box(c, 4, 4 - (ph if on else 0), 8, 9, P.G4, P.G3)
			c.rect(6, 6, 4, 2, P.CYAN if on else P.BLUE_D)
		"storage":
			_box(c, 1, 1, 14, 14, P.G3, P.G2)
			c.rect(3, 3, 10, 8, P.G1)
			for i in f:
				c.rect(3 + i * 3, 4 + (i % 2) * 3, 4, 4, P.CARD)
				c.rect(3 + i * 3, 4 + (i % 2) * 3, 4, 1, P.ORANGE_L)
		"shelf":
			_box(c, 1, 2, 14, 13, P.BROWN, P.BROWN_D)
			c.rect(2, 8, 12, 1, P.BROWN_D)
			for i in f:
				c.rect(2 + (i % 2) * 6, 3 + int(i / 2.0) * 6, 5, 4, P.ORANGE)
				c.rect(4 + (i % 2) * 6, 3 + int(i / 2.0) * 6, 1, 4, P.CARD)
		"source":
			_box(c, 1, 1, 14, 14, P.PURPLE, P.BLUE_D)
			c.disc(6, 7, 2.2, P.PAPER)
			c.disc(10, 7, 2.2, P.PAPER)
			c.disc(6, 7, 1, P.PURPLE)
			c.disc(10, 7, 1, P.PURPLE)
			if on:
				c.px(3 + ph * 4, 3, P.YELLOW)
				c.px(12 - ph * 3, 11, P.YELLOW)
			_arrow_r(c, 13, 12, P.YELLOW)
		"incinerator":
			_box(c, 1, 2, 14, 13, P.G2, P.G1)
			c.rect(3, 4, 10, 7, P.INK)
			if on:
				c.disc(6 + ph, 8, 2.5, P.RED)
				c.disc(9 - ph, 8, 2, P.ORANGE)
				c.px(8, 6 - ph, P.YELLOW)
			else:
				c.px(6, 9, P.RED_D)
				c.px(9, 9, P.RED_D)
		"turret_guard":
			c.disc(8, 9, 6, P.G2)
			c.disc(8, 9, 4, P.G3)
			c.line(8, 9, 14 - ph, 5, P.BROWN)
			c.line(8, 9, 14 - ph, 13, P.BROWN)
			c.px(14 - ph, 9, P.G5)
		"turret_electric":
			c.disc(8, 10, 5.5, P.G2)
			c.rect(6, 4, 4, 7, P.ORANGE)
			c.disc(8, 4, 3, P.G5)
			if on:
				c.line(8, 4, 2 + ph * 2, 0, P.YELLOW)
				c.line(8, 4, 14 - ph, 1, P.YELLOW)
		"pile":
			var rng := RandomNumberGenerator.new()
			rng.seed = 77
			c.disc(16, 18, 13, P.BROWN_D)
			for i in 22:
				var jc: int = [P.PAPER, P.G4, P.GREEN, P.RED, P.BLUE, P.YELLOW, P.CARD][rng.randi_range(0, 6)]
				c.rect(rng.randi_range(6, 24), rng.randi_range(8, 26), rng.randi_range(2, 4), 2, jc)
			if on:
				c.px(10 + ph * 5, 8, P.LIGHT)
		"disassembler":
			# 분해기: 이빨 달린 입 + 눈알 (씹는 애니메이션)
			_box(c, 1, 2, 30, 28, P.G4, P.G3)
			_eyes(c, 9, 4, [0, -1, 1][ph] if on else 0)
			var gap: int = 2 + ([0, 3, 1][ph] if on else 0)
			var hg := int(gap / 2.0)
			c.rect(4, 13, 24, 12, P.INK)
			c.rect(4, 13, 24, 5 - hg, P.G3)
			c.rect(4, 20 + hg, 24, 5 - hg, P.G3)
			for i in 6:
				c.px(5 + i * 4, 18 - hg, P.PAPER)
				c.px(7 + i * 4, 19 + hg, P.PAPER)
			c.rect(1, 12, 3, 10, P.G2)
		"processor":
			# 가공기: 커다란 톱니가 돌아요
			_box(c, 1, 2, 30, 28, P.G3, P.G2)
			c.disc(16, 14, 9, P.G4)
			c.disc(16, 14, 3, P.G2)
			for i in 6:
				var a := (i / 6.0 + (ph if on else 0) / 18.0) * TAU
				c.disc(16 + cos(a) * 9.5, 14 + sin(a) * 9.5, 2.2, P.G4)
			c.rect(24, 22, 5, 3, P.YELLOW if on else P.G2)
		"crafter":
			# 제작기: 주황 로봇 팔 두 개
			_box(c, 1, 2, 30, 28, P.G4, P.G3)
			c.rect(5, 16, 22, 6, P.G2)
			var arm: int = [0, 3, 6][ph] if on else 0
			c.rect(6 + arm, 6, 3, 12, P.ORANGE)
			c.rect(23 - arm, 6, 3, 12, P.ORANGE)
			c.rect(5 + arm, 17, 5, 3, P.ORANGE_L)
			c.rect(22 - arm, 17, 5, 3, P.ORANGE_L)
		"furnace":
			# 용광로: 벽돌 + 불구멍 + 굴뚝 연기
			_box(c, 1, 4, 30, 26, P.RED_D, P.BROWN_D)
			for y in range(6, 26, 4):
				for x in range(2, 30, 6):
					c.rect(x + (int(y / 4.0) % 2) * 3, y, 5, 1, P.BROWN_D)
			c.rect(9, 17, 14, 9, P.INK)
			if on:
				c.disc(16, 23, 4 + ph, P.ORANGE)
				c.disc(16, 24, 2, P.YELLOW)
			c.rect(22, 0, 6, 8, P.G2)
			if on:
				c.disc(25 - ph, 2 - ph, 2.5, P.G5)
		"workbench":
			# 설비 제작대: 나무 작업대 + 망치
			_box(c, 1, 3, 30, 26, P.CARD, P.BROWN)
			c.rect(4, 7, 10, 2, P.BROWN)
			c.rect(4, 12, 7, 7, P.G4)
			var hy: int = [0, -3, 0][ph] if on else 0
			c.rect(19, 10 + hy, 3, 10, P.BROWN_D)
			c.rect(16, 8 + hy, 9, 4, P.G3)
			c.rect(4, 21, 22, 2, P.BROWN)
		"cash_printer":
			_box(c, 1, 2, 30, 28, P.GREEN_D, P.TEAL)
			c.rect(6, 6, 20, 4, P.INK)
			var my := 10 + (ph * 3 if on else 0)
			c.rect(8, my, 16, 8, P.LIME)
			c.rect(14, my + 2, 4, 4, P.GREEN)
			c.rect(4, 26, 4, 2, P.YELLOW if on else P.G2)
		"packer":
			# 포장기: 가운데 벨트 + 테이프 롤
			_box(c, 1, 2, 30, 28, P.G4, P.G3)
			c.rect(1, 14, 30, 8, P.G1)
			var bx := 4 + (ph * 7 if on else 0)
			c.rect(bx, 15, 8, 6, P.ORANGE)
			c.rect(bx + 3, 15, 2, 6, P.CARD)
			c.disc(16, 8, 5, P.CARD)
			c.disc(16, 8, 2, P.G3)
			if on:
				var a := ph * TAU / 3.0
				c.px(16 + int(cos(a) * 3.5), 8 + int(sin(a) * 3.5), P.BROWN)
		"gift_packer":
			_box(c, 1, 2, 30, 28, P.PINK, P.RED_D)
			var b: int = [0, -1, 1][ph] if on else 0
			c.disc(10, 12 + b, 5, P.RED)
			c.disc(22, 12 - b, 5, P.RED)
			c.disc(16, 13, 3, P.RED_D)
			c.rect(14, 15, 4, 10, P.RED)
		"computer":
			# 작업 컴퓨터: 책상 위 브라운관 + 웃는 화면
			_box(c, 1, 8, 30, 22, P.BROWN, P.BROWN_D)
			_box(c, 6, 1, 20, 17, P.G5, P.G4)
			c.rect(8, 3, 16, 11, P.BLUE_D)
			var blink := on and ph == 1
			c.rect(12, 6, 2, 1 if blink else 2, P.LIME)
			c.rect(18, 6, 2, 1 if blink else 2, P.LIME)
			c.rect(12, 10, 8, 1, P.LIME)
			c.px(11, 9, P.LIME)
			c.px(20, 9, P.LIME)
			if on:
				c.rect(22, 20, 6, 3 + ph * 2, P.PAPER)
			c.rect(6, 21, 12, 4, P.G2)
		"bio_generator":
			# 바이오 발전기: 쳇바퀴 도는 햄스터
			_box(c, 1, 2, 30, 28, P.GREEN_D, P.G2)
			c.disc(16, 14, 11, P.G4)
			c.disc(16, 14, 9, P.GREEN_D)
			for i in 4:
				var a := (i / 4.0 + (ph / 12.0 if on else 0.0)) * TAU
				c.line(16, 14, 16 + cos(a) * 9, 14 + sin(a) * 9, P.G3)
			var hb: int = [0, -1, 0][ph] if on else 1
			c.disc(16, 20 + hb, 3.5, P.ORANGE_L)
			c.px(18, 19 + hb, P.INK)
			c.px(14, 18 + hb, P.CARD)
			if not on:
				c.px(21, 15, P.PAPER)   # 쿨쿨
				c.px(23, 13, P.PAPER)
		"coal_generator":
			_box(c, 1, 4, 30, 26, P.G2, P.G1)
			c.rect(4, 8, 14, 14, P.G3)
			c.disc(11, 15, 4, P.RED if on else P.RED_D)
			if on:
				c.disc(11, 15, 2, P.YELLOW)
			c.rect(22, 0, 6, 12, P.G3)
			if on:
				c.disc(25 + ph, 2 - ph, 2.5, P.G4)
		"producer":
			# 생산기 3×3: 돔 + 깜빡이는 불빛 세 개
			_box(c, 1, 2, 46, 44, P.G4, P.G3, 4)
			c.disc(24, 20, 12, P.G3)
			c.disc(24, 20, 9, P.TEAL)
			c.disc(21, 17, 3, P.CYAN)
			for i in 3:
				c.rect(6 + i * 15, 38, 6, 4, P.YELLOW if on and i == ph else P.G2)
			c.rect(1, 10, 4, 6, P.G2)
			c.rect(1, 22, 4, 6, P.G2)
			c.rect(1, 34, 4, 6, P.G2)
		"dock":
			# 출하 도크 4×2: 바닥 + 트럭 뒤칸 (오른쪽)
			c.rect(1, 1, 62, 30, P.G4)
			for x in range(1, 63):
				c.px(x, 1, P.YELLOW if x % 4 < 2 else P.INK)
			_box(c, 30, 3, 32, 26, P.PAPER, P.G4)
			c.rect(30, 8, 3, 16, P.INK)
			for i in f:
				c.rect(6 + i * 6, 12, 5, 5, P.ORANGE)
		_:
			_box(c, 1, 1, w - 2, h - 2, P.G4, P.G3)
			c.rect(4, 4, 4, 4, P.PINK)
	if not key in ["exit", "entrance", "sorter", "bridge", "detector", "judge", "injector", "pump"]:
		c.outline()


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
		"kit":
			_box_item(c, 2, 3, 12, 11, a, P.CARD)
			c.disc(8, 9, 3, b)
			c.disc(8, 9, 1, a)
		_:
			c.disc(8, 8, 5.5, a)
			c.rect(7, 4, 2, 5, b)
			c.rect(7, 11, 2, 2, b)
