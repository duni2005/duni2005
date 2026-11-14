class_name GuildMemberCombatStats
extends RefCounted
## Linear level growth (HP +12%, physical/magic damage +8%, defense +8%, move speed +2% per
## level), multiplicative gear, attack % growth from fang kills. Stars add no stats (promotion
## pays out in experience instead); they only add equipment slots.
static func assemble(data: UnitData,member: GuildMemberState,inventory: InventoryService) -> UnitCombatStats:
	var level: int=member.level
	var stats:=UnitCombatStats.from_table(data,1+level*.12,1+level*.08,1+level*.08,1+level*.02)
	for instance in inventory.equipped(member.member_id):
		var item: ItemData=ItemCatalog.of(instance)
		if item==null:continue
		stats.apply_item(item)
		if instance.growth>0 and item.effect!=&"":stats.growth[item.effect]=instance.growth
	stats.finish_items()
	# 0.97: 예비대의 휘장, 연승의 띠, 정복자의 왕관, 망고 신자의 염주 grow over the run.
	BuildItems.run_stats(stats,inventory.run)
	# 탐욕의 황금손: attack % from the gold the guild holds.
	if stats.has(&"greedPouch"):stats.attack*=1+ItemEffects.greed_attack(inventory.run.gold)
	stats.max_hp=floorf(stats.max_hp+.5)
	stats.equipment_attack_without_growth=stats.attack
	stats.attack*=1+member.fang_kills*stats.fang_rate()
	return stats
static func equipment_limit(member: GuildMemberState) -> int:return 2+clampi(member.stars,0,GrowthRules.MAX_STARS)
static func heal(guild: GuildManager,member: GuildMemberState,base: float,revive: bool=false) -> float:
	if member==null or base<=0 or not is_finite(base) or not member.is_alive() and not revive:return 0
	var stats: UnitCombatStats=guild.member_stats(member)
	var gain: float=minf(maxf(0,stats.max_hp-member.current_hp),base*stats.healing_received)
	member.current_hp+=gain
	return gain
static func reset_bomber(member: GuildMemberState) -> void:
	var state: Dictionary=member.character_specific_state;state["bomberRush"]=false;state["bomberRushTime"]=0;state["bomberFuse"]=null;member.character_specific_state=state

