class_name TowerEnemyStatsAssembler
extends RefCounted
## dist/tower.js towerEnemyStats: enemy scaling is independent of guild growth. 0.99.7: the items an
## enemy wears count like a guild member's, and 미니보스 / 보스 are tougher (RANK_HP, RANK_DAMAGE;
## off with the balance layer for the source-parity tests).
const RANK_HP = {&"normal": 1.0, &"elite": 1.2, &"boss": 1.25}
const RANK_DAMAGE = {&"normal": 1.0, &"elite": 1.1, &"boss": 1.15}
static func assemble(data: UnitData, entry: EnemySpawnEntry) -> UnitCombatStats:
	# Level growth scales the damage stats; elite/boss damage multipliers scale attack % (the
	# whole hit), defense multipliers every defense.
	var stats := UnitCombatStats.from_table(data, .8 * (1 + entry.level * .12) * entry.hp_multiplier, .8 * (1 + entry.level * .08), .8 * (1 + entry.level * .08) * entry.defense_multiplier, .8 * (1 + entry.level * .02) * entry.speed_multiplier)
	for kind in entry.items:
		var item: ItemData = ItemCatalog.get_item(kind)
		if item != null:stats.apply_item(item)
	stats.finish_items()
	if UnitBalance.enabled:stats.max_hp *= float(RANK_HP.get(entry.rank, 1.0))
	stats.max_hp = floorf(stats.max_hp + .5)
	stats.attack = entry.damage_multiplier * (float(RANK_DAMAGE.get(entry.rank, 1.0)) if UnitBalance.enabled else 1.0) * stats.attack
	stats.physical_defense *= entry.defense_multiplier;stats.magic_defense *= entry.defense_multiplier
	stats.scale *= entry.body_scale;stats.rank = entry.rank;stats.level = entry.level
	return stats
