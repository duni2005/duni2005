extends Node2D
## 설치했을 때 그 칸에서 피어오르는 먼지. 읽기만 하고 아무것도 바꾸지 않아요.

const TILE := 32.0
const SEC := 0.45
const PARTS := 6

var _puffs: Array = []   # {p, t, seed}


func puff(cell_center: Vector2) -> void:
	_puffs.append({"p": cell_center * TILE, "t": 0.0, "seed": randi()})


func _process(dt: float) -> void:
	if _puffs.is_empty():
		return
	for f in _puffs:
		f["t"] += dt
	_puffs = _puffs.filter(func(f) -> bool: return f["t"] < SEC)
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
