class_name EnemyItems
extends RefCounted
## Tower enemies wear items (0.99.7). How many and how good grow with the floor; 미니보스 (elite)
## and 보스 wear more and better ones. At most MAX_ITEMS each.
## - count: a floor's expected count (COUNT_FIRST on floor 1 → COUNT_LAST on floor 15, plus
##   RANK_COUNT for elites / bosses), its fraction rolled (floor 1: a 10% chance of one item);
## - grade: the item reward table of the floor (ItemRewards.odds) RANK_DEPTH floors higher for
##   elites / bosses, bosses at least 희귀;
## - pool: equipment that works without a guild — no consumables, no 대가 items and no item whose
##   effect is about the run's gold, cards or rewards (DENY).
const MAX_ITEMS: int = 4
const COUNT_FIRST: float = .1
const COUNT_LAST: float = 2.4
const RANK_COUNT = {&"normal": 0.0, &"elite": 1.0, &"boss": 2.0}
const RANK_DEPTH = {&"normal": 0, &"elite": 3, &"boss": 6}
const RANK_MIN_GRADE = {&"normal": &"common", &"elite": &"common", &"boss": &"rare"}
const DENY = [&"conquerorCrown", &"lastStandSeal", &"mangoRosary", &"reserveBadge", &"streakBelt", &"dragonEgg", &"goldenGoose", &"rookieBadge", &"victoryCup", &"victoryGrail", &"greedPouch", &"pactSeal", &"huntLicense", &"tacticianQuill", &"mangoSeed"]
static var _excluded: Array = []

## Items that never go on an enemy (kinds).
static func excluded() -> Array:
	if _excluded.is_empty():
		for grade in ItemCatalog.POOLS:
			for kind in ItemCatalog.POOLS[grade]:
				var data: ItemData = ItemCatalog.get_item(kind)
				if data == null or data.consumable or data.effect in DENY or kind in DENY or kind == &"prismShard" or not ItemCatalog.cost_text(kind).is_empty():_excluded.append(kind)
	return _excluded

static func expected_count(depth: int, rank: StringName) -> float:
	return minf(MAX_ITEMS, lerpf(COUNT_FIRST, COUNT_LAST, clampf(depth / 14.0, 0, 1)) + float(RANK_COUNT.get(rank, 0.0)))

static func roll(rng: RandomNumberGenerator, depth: int, rank: StringName) -> Array[StringName]:
	var expected: float = expected_count(depth, rank)
	var count: int = mini(MAX_ITEMS, int(expected) + int(rng.randf() < expected - floorf(expected)))
	var odds: Dictionary = ItemRewards.odds(clampi(depth + int(RANK_DEPTH.get(rank, 0)), 0, 14), RANK_MIN_GRADE.get(rank, &"common"))
	var out: Array[StringName] = []
	for kind in ItemRewards.roll(rng, odds, count, excluded()):out.append(kind)
	return out
