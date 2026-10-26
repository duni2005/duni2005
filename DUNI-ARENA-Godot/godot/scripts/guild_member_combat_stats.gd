class_name GuildMemberCombatStats
extends RefCounted
## towerMemberStats: linear level, multiplicative gear, additive fang kills. Stars add no stats
## (promotion pays out in experience instead); they only add equipment slots.
static func assemble(data: UnitData,member: GuildMemberState,inventory: InventoryService) -> UnitCombatStats:
	var stats:=UnitCombatStats.new()
	var level: int=member.level
	stats.max_hp=data.max_hp*(1+level*.12);stats.attack=data.attack*(1+level*.08)
	stats.defense=data.defense_power*(1+level*.08);stats.speed=data.move_speed*(1+level*.02)
	for instance in inventory.equipped(member.member_id):
		var item: ItemData=ItemCatalog.get_item(instance.kind)
		if item==null:continue
		stats.apply_item(item)
	stats.max_hp=floorf(stats.max_hp+.5)
	stats.equipment_attack_without_growth=stats.attack
	stats.attack*=1+member.fang_kills*stats.fang_rate()
	return stats
static func equipment_limit(member: GuildMemberState) -> int:return 2+clampi(member.stars,0,GrowthRules.MAX_STARS)
static func heal(guild: GuildManager,member: GuildMemberState,base: float,revive: bool=false) -> float:
	if member==null or base<=0 or not is_finite(base) or not member.is_alive() and not revive:return 0
	var stats: UnitCombatStats=guild.member_stats(member)
	var gain: float=minf(maxf(0,stats.max_hp-member.current_hp),base*stats.healing_power)
	member.current_hp+=gain
	return gain
static func reset_bomber(member: GuildMemberState) -> void:
	var state: Dictionary=member.character_specific_state;state["bomberRush"]=false;state["bomberRushTime"]=0;state["bomberFuse"]=null;member.character_specific_state=state

## Gold to buy the experience still missing for the next level.
static func upgrade_cost(member: GuildMemberState) -> int:return GrowthRules.gold_for_exp(GrowthRules.exp_to_next(member.level)-GrowthRules.exp_progress(member.total_exp))
