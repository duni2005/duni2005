class_name UnitBalance
extends RefCounted
## Balance layer (0.75.0) over the source stat values, applied wherever combat stats are built
## (UnitCombatStats.from_table: guild members, tower enemies, custom battles, the unit sheet).
## The data files and UnitStatTable keep the original numbers; HP and physical/magic damage are
## multiplied here: first by recruit-token tier (higher tiers clearly stronger per sortie slot),
## then by a per-unit correction from the 0.75.0 balance simulations.
## Tier multiplier by recruit tokens 1..5.
const TIER: Array[float] = [.95, 1.0, 1.05, 1.10, 1.15]
## Off only for the source-parity tests (formulas checked against the original web game).
static var enabled: bool = true
## Per-unit HP correction (type_id → factor).
const HP: Dictionary = {0: .9, 5: 1.15, 16: 1.1, 18: .92, 19: 1.25, 20: 1.1, 24: .9, 25: 1.2, 27: 1.7, 33: 1.2}
## Per-unit physical/magic damage correction (type_id → factor).
const DAMAGE: Dictionary = {0: .92, 2: .92, 5: 1.15, 13: .88, 15: .9, 16: 1.1, 18: .92, 19: 1.25, 20: 1.2, 24: .9, 25: 1.3, 27: 1.25, 31: 1.12, 33: .8}

static func tier(data: UnitData) -> float:return TIER[clampi(data.recruit_tokens, 1, TIER.size()) - 1]
static func hp(data: UnitData) -> float:return tier(data) * float(HP.get(data.type_id, 1.0)) if enabled else 1.0
static func damage(data: UnitData) -> float:return tier(data) * float(DAMAGE.get(data.type_id, 1.0)) if enabled else 1.0
## Level-0 maximum HP as the game shows it.
static func max_hp(data: UnitData) -> float:return floorf(data.max_hp * hp(data) + .5)
