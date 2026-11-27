class_name Art
extends RefCounted
## 도트 텍스처 모음 (16×16, 화면에는 2배 = 32px로 그려요).
## PATHS 경로에 PNG를 넣으면 그 그림을 쓰고, 없으면 여기서 코드로 임시 도트를 그려요.
## 그림을 바꿔 끼울 때는 PNG만 해당 경로에 넣으면 돼요 (16×16, 투명 배경 가능).

const PX := 16
const PATHS := {
	"carpet": "res://assets/tiles/carpet.png",
	"carpet_stain": "res://assets/tiles/carpet_stain.png",
	"tile": "res://assets/tiles/tile.png",
	"wall": "res://assets/tiles/wall.png",
	"door": "res://assets/tiles/door.png",
	"corridor": "res://assets/tiles/corridor.png",
	"barrier": "res://assets/tiles/barrier.png",
	"hazard": "res://assets/tiles/hazard.png",
	"trash1": "res://assets/tiles/trash1.png",
	"trash2": "res://assets/tiles/trash2.png",
	"trash3": "res://assets/tiles/trash3.png",
}

static var _cache := {}


static func tex(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var t: Texture2D = null
	var path: String = PATHS.get(key, "")
	if path != "" and ResourceLoader.exists(path):
		t = load(path)
	else:
		t = ImageTexture.create_from_image(_make(key))
	_cache[key] = t
	return t


# ---------- 임시 도트 (코드로 그리기) ----------

static func _make(key: String) -> Image:
	var img := Image.create(PX, PX, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	match key:
		"carpet", "carpet_stain":
			_carpet(img, rng, key == "carpet_stain")
		"tile":
			_tile(img, rng)
		"wall":
			_wall(img, rng)
		"door":
			_door(img)
		"corridor":
			_corridor(img, rng)
		"barrier":
			_barrier(img)
		"hazard":
			_hazard(img)
		"trash1", "trash2", "trash3":
			_trash(img, rng)
		_:
			img.fill(Color.MAGENTA)
	return img


static func _noise(img: Image, rng: RandomNumberGenerator, base: Color, amount: float) -> void:
	for y in PX:
		for x in PX:
			var v := rng.randf_range(-amount, amount)
			img.set_pixel(x, y, Color(base.r + v, base.g + v, base.b + v))


static func _carpet(img: Image, rng: RandomNumberGenerator, stain: bool) -> void:
	# 낡은 사무실 카펫: 푸른 회색 + 고리 무늬 + 해진 자국
	_noise(img, rng, Color("4a5260"), 0.025)
	for y in PX:
		for x in PX:
			if (x + y * 2) % 4 == 0:
				img.set_pixel(x, y, img.get_pixel(x, y).lightened(0.07))
	for i in 4:
		img.set_pixel(rng.randi_range(0, 15), rng.randi_range(0, 15), Color("3a404c"))
	if stain:
		var c := Vector2(rng.randi_range(4, 11), rng.randi_range(4, 11))
		for y in PX:
			for x in PX:
				var d := Vector2(x, y).distance_to(c)
				if d < 3.6 + rng.randf() * 0.8:
					img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color("5b4a3a"), 0.45))


static func _tile(img: Image, rng: RandomNumberGenerator) -> void:
	# 사무실 바닥 타일: 밝은 회색 + 줄눈
	_noise(img, rng, Color("8a877e"), 0.02)
	for i in PX:
		img.set_pixel(15, i, Color("67645d"))
		img.set_pixel(i, 15, Color("67645d"))
		img.set_pixel(0, i, Color("9a978d"))
		img.set_pixel(i, 0, Color("9a978d"))
	for i in 3:
		img.set_pixel(rng.randi_range(2, 13), rng.randi_range(2, 13), Color("75726a"))


static func _wall(img: Image, rng: RandomNumberGenerator) -> void:
	# 벽: 어두운 패널, 위쪽 턱, 세로 이음매
	_noise(img, rng, Color("39362f"), 0.02)
	for x in PX:
		for y in 4:
			img.set_pixel(x, y, Color("5c584f") if y < 3 else Color("2a2823"))
		img.set_pixel(x, 15, Color("22201c"))
	for y in range(4, 15):
		img.set_pixel(7, y, Color("2c2a25"))
		img.set_pixel(8, y, Color("45423a"))


static func _door(img: Image) -> void:
	# 정문: 금속 셔터 (가로 살)
	for y in PX:
		var c := Color("7c828a") if (y % 4) < 2 else Color("5d636b")
		if y % 4 == 3:
			c = Color("474c53")
		for x in PX:
			img.set_pixel(x, y, c)
	for y in PX:
		img.set_pixel(0, y, Color("d4a82a"))
		img.set_pixel(15, y, Color("d4a82a"))


static func _corridor(img: Image, rng: RandomNumberGenerator) -> void:
	# 어두운 복도 바닥
	_noise(img, rng, Color("17181c"), 0.012)
	for x in PX:
		img.set_pixel(x, 0, Color("1f2126"))


static func _barrier(img: Image) -> void:
	# 막힘 표시: 빨강·흰 줄무늬 차단봉 (투명 배경)
	img.fill(Color(0, 0, 0, 0))
	for x in PX:
		for y in range(6, 10):
			var red := int((x + y) / 4.0) % 2 == 0
			img.set_pixel(x, y, Color("d23c3c") if red else Color("eeeeee"))
	for y in range(4, 14):
		img.set_pixel(1, y, Color("2a2a2a"))
		img.set_pixel(14, y, Color("2a2a2a"))


static func _hazard(img: Image) -> void:
	# 설치 금지 통로: 노랑·검정 사선 (반투명, 바닥 위에 겹쳐 그려요)
	for y in PX:
		for x in PX:
			var on := int((x + y) / 4.0) % 2 == 0
			img.set_pixel(x, y, Color(0.85, 0.69, 0.16, 0.55) if on else Color(0.1, 0.1, 0.1, 0.35))


static func _trash(img: Image, rng: RandomNumberGenerator) -> void:
	# 쓰레기 더미: 흙갈색 바탕에 종이·캔·병·비닐 조각
	_noise(img, rng, Color("3f362c"), 0.04)
	var junk := [Color("b9b4a5"), Color("7f8790"), Color("4a7246"), Color("94443b"), Color("3d5f8a"), Color("a08840"), Color("5e4c3a"), Color("5e4c3a")]
	for i in 6:
		var c: Color = junk[rng.randi_range(0, junk.size() - 1)]
		var w := rng.randi_range(2, 4)
		var h := rng.randi_range(1, 3)
		var x0 := rng.randi_range(0, PX - w)
		var y0 := rng.randi_range(0, PX - h)
		for y in range(y0, y0 + h):
			for x in range(x0, x0 + w):
				img.set_pixel(x, y, c)
		for x in range(x0, x0 + w):
			if y0 + h < PX:
				img.set_pixel(x, y0 + h, c.darkened(0.55))
