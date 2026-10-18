class_name TowerEnemyStatsAssembler
extends RefCounted
## dist/tower.js towerEnemyStats: enemy scaling is independent of guild growth.
static func assemble(data: UnitData, entry: EnemySpawnEntry) -> UnitCombatStats:
	var stats := UnitCombatStats.new()
	stats.max_hp = floorf(data.max_hp * .8 * (1 + entry.level * .12) * entry.hp_multiplier + .5)
	stats.attack = data.attack * .8 * (1 + entry.level * .08) * entry.damage_multiplier
	stats.defense = data.defense_power * .8 * (1 + entry.level * .08) * entry.defense_multiplier
	stats.speed = data.move_speed * .8 * (1 + entry.level * .02) * entry.speed_multiplier
	stats.scale = entry.body_scale
	return stats
