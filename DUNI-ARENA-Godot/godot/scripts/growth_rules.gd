class_name GrowthRules
extends RefCounted
## Guild growth numbers: experience bought with gold, promotion, and how many units may sortie.
## Pure functions over plain values; no UI or Node references.

## Gold spent per point of experience is 1 G = 1 EXP.
const EXP_PER_GOLD: int = 1
## Experience is bought in packs of this size.
const EXP_PACK: int = 100
## Experience added on top of the three units' combined experience when they promote.
const PROMOTION_BONUS_EXP: int = 300
const MAX_STARS: int = 2
## Units that may sortie into a tower battle, before any upgrade.
const SORTIE_BASE: int = 3
## Gold for each sortie upgrade, in order (+1 unit each).
const SORTIE_COSTS: Array[int] = [500, 800, 1200, 1700, 2300]

## Experience needed to go from `level` to `level + 1`.
static func exp_to_next(level: int) -> int:return 80 + 20 * level
## Total experience from Lv.0 up to the start of `level`.
static func exp_for_level(level: int) -> int:return 80 * level + 10 * level * (level - 1)
static func level_for_exp(total_exp: int) -> int:
	var level: int = 0
	while exp_for_level(level + 1) <= total_exp:level += 1
	return level
## Experience gained inside the current level.
static func exp_progress(total_exp: int) -> int:return total_exp - exp_for_level(level_for_exp(total_exp))
static func gold_for_exp(amount: int) -> int:return ceili(float(amount) / EXP_PER_GOLD)
static func pack_cost() -> int:return gold_for_exp(EXP_PACK)
## Packs needed to reach the next level; the excess stays as progress.
static func packs_to_level(total_exp: int) -> int:
	return ceili(float(exp_to_next(level_for_exp(total_exp)) - exp_progress(total_exp)) / EXP_PACK)

static func sortie_limit(run: RunState) -> int:return SORTIE_BASE + run.sortie_level
## Gold for the next sortie upgrade, or -1 when fully upgraded.
static func sortie_cost(run: RunState) -> int:return SORTIE_COSTS[run.sortie_level] if run.sortie_level < SORTIE_COSTS.size() else -1
