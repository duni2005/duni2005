class_name ArenaMap
extends RefCounted
## 사각 정원: the square battle field. 소 is the original 800-unit arena; 중 and 대 are wider.
## The battle in progress sets `side` (one battle runs at a time). Placements are always given in
## 800-unit board space and scaled up to the map at battle start.
const SMALL: int = 0
const MEDIUM: int = 1
const LARGE: int = 2
const SIDES: Array[float] = [800.0, 1100.0, 1400.0]
const NAMES: Array[String] = ["사각 정원 · 소", "사각 정원 · 중", "사각 정원 · 대"]
## Board space the deployment screens and placements use.
const BOARD: float = 800.0
static var side: float = 800.0
static var id: int = SMALL

static func use(map_id: int) -> void:
	id = clampi(map_id, SMALL, LARGE);side = SIDES[id]
static func center() -> Vector2:return Vector2.ONE * side * .5
## The far corner `margin` units in from the edges (pairs with Vector2(margin, margin)).
static func hi(margin: float) -> Vector2:return Vector2.ONE * (side - margin)
static func clamp_in(point: Vector2, margin: float) -> Vector2:return point.clamp(Vector2.ONE * margin, hi(margin))
## Board-space (800) point to map space.
static func from_board(point: Vector2) -> Vector2:return point * side / BOARD
static func label(map_id: int) -> String:return NAMES[clampi(map_id, SMALL, LARGE)]
## 전투 예측: a bigger field for a bigger crowd.
static func for_units(count: int) -> int:return SMALL if count <= 8 else MEDIUM if count <= 16 else LARGE
