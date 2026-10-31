class_name GrowthRules
extends RefCounted
## Guild growth numbers: experience bought with gold, promotion, and guild expansion (how many
## units may sortie, how many the guild can hold, and the recruit odds).
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
## Members the guild can hold (dead ones count), before any upgrade; each upgrade adds ROSTER_STEP.
const ROSTER_BASE: int = 10
const ROSTER_STEP: int = 2
const ROSTER_COSTS: Array[int] = [300, 500, 800, 1200]
## Recruit odds (%) by recruit price (1-5 tokens) at each odds upgrade level: higher levels shift
## candidates towards rarer units, like a shop level.
const RECRUIT_ODDS: Array = [
	{1:40, 2:30, 3:18, 4:9, 5:3},
	{1:32, 2:30, 3:22, 4:12, 5:4},
	{1:25, 2:28, 3:25, 4:16, 5:6},
	{1:18, 2:25, 3:28, 4:20, 5:9},
	{1:12, 2:20, 3:30, 4:25, 5:13},
]
const ODDS_COSTS: Array[int] = [400, 700, 1100, 1600]

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
static func roster_limit(run: RunState) -> int:return ROSTER_BASE + ROSTER_STEP * run.roster_level
static func roster_cost(run: RunState) -> int:return ROSTER_COSTS[run.roster_level] if run.roster_level < ROSTER_COSTS.size() else -1
static func recruit_odds(run: RunState) -> Dictionary:return RECRUIT_ODDS[clampi(run.odds_level, 0, RECRUIT_ODDS.size() - 1)]
static func odds_cost(run: RunState) -> int:return ODDS_COSTS[run.odds_level] if run.odds_level < ODDS_COSTS.size() else -1
