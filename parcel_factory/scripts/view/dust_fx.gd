extends Node2D
## 설치했을 때 그 칸에서 피어오르는 먼지, 철거했을 때 튀는 파편. 읽기만 하고 아무것도 바꾸지 않아요.

const TILE := 32.0
const SEC := 0.45
const PARTS := 6
const BREAK_SEC := 0.4
const BREAK_PARTS := 10

var _puffs: Array = []   # {p, t, seed}
var _breaks: Array = []  # {p, r, t, seed} 철거 파편


func burst(center: Vector2, cells: Vector2) -> void:
	## 철거: 설비 크기(칸)만큼 퍼지는 파편 + 먼지
	_breaks.append({"p": center * TILE, "r": maxf(cells.x, cells.y) * TILE * 0.5, "t": 0.0, "seed": randi()})
	puff(center)


func puff(cell_center: Vector2) -> void:
	_puffs.append({"p": cell_center * TILE, "t": 0.0, "seed": randi()})


func _process(dt: float) -> void:
	if _puffs.is_empty() and _breaks.is_empty():
		return
	for f in _puffs:
		f["t"] += dt
	for f in _breaks:
		f["t"] += dt
	_puffs = _puffs.filter(func(f) -> bool: return f["t"] < SEC)
	_breaks = _breaks.filter(func(f) -> bool: return f["t"] < BREAK_SEC)
	queue_redraw()


func _draw() -> void:
	var col := Palette.c(Palette.G5)
	for f in _puffs:
		var k: float = f["t"] / SEC
		var rng := RandomNumberGenerator.new()
		rng.seed = f["seed"]
		for i in PARTS:
			var ang := TAU * i / PARTS + rng.randf() * 0.5
			var p: Vector2 = f["p"] + Vector2.from_angle(ang) * (8.0 + 18.0 * k) + Vector2(0, 8.0 - 6.0 * k)
			draw_circle(p, 4.0 * (1.0 - k) + 1.0, Color(col, 0.7 * (1.0 - k)))
	var cols := [Palette.c(Palette.G3), Palette.c(Palette.G4), Palette.c(Palette.BROWN)]
	for f in _breaks:
		var k: float = f["t"] / BREAK_SEC
		var rng := RandomNumberGenerator.new()
		rng.seed = f["seed"]
		for i in BREAK_PARTS:
			var ang := rng.randf() * TAU
			var dist: float = f["r"] * (0.3 + 0.9 * k) * rng.randf_range(0.6, 1.2)
			var p: Vector2 = f["p"] + Vector2.from_angle(ang) * dist + Vector2(0, 30.0 * k * k)
			var s := 4.0 * (1.0 - k * 0.5)
			draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), Color(cols[i % 3], 1.0 - k))
