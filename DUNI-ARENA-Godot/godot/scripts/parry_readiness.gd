class_name ParryReadiness
extends RefCounted
## Shared iron-card readiness contract. Common mode delegates real availability
## to ParryController; minimal mode preserves the Phase 6 comparison behavior.
const NORMAL_COOLDOWN: float = 12.0
static func cooldown_duration(unit: BattleUnit) -> float:
	return 3.0 if unit.iron_defense_remaining > 0 else NORMAL_COOLDOWN
static func is_ready(unit: BattleUnit) -> bool:
	if unit.battle.common_combat_enabled: return ParryController.available(unit)
	return unit.alive and unit.parry_cooldown <= 0 and unit.parry_remaining <= 0
