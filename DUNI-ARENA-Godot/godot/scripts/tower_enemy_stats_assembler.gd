class_name TowerEnemyStatsAssembler
extends RefCounted
## dist/tower.js towerEnemyStats: enemy scaling is independent of guild growth.
static func assemble(data: UnitData, entry: EnemySpawnEntry) -> UnitCombatStats:
	# Level growth scales the damage stats; elite/boss damage multipliers scale attack % (the
	# whole hit), defense multipliers every defense.
	var stats := UnitCombatStats.from_table(data, .8 * (1 + entry.level * .12) * entry.hp_multiplier, .8 * (1 + entry.level * .08), .8 * (1 + entry.level * .08) * entry.defense_multiplier, .8 * (1 + entry.level * .02) * entry.speed_multiplier)
	stats.max_hp = floorf(stats.max_hp + .5)
	stats.attack = entry.damage_multiplier
	stats.physical_defense *= entry.defense_multiplier;stats.magic_defense *= entry.defense_multiplier
	stats.scale = entry.body_scale
	return stats
