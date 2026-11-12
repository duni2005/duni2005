class_name ItemEffects
extends RefCounted
## Battle effects of the 0.94 items. Numbers live in ItemTuning; units without item stats
## (enemies, tests) are left alone.

static func _stats(u) -> UnitCombatStats:
	return u.combat_stats if is_instance_valid(u) and u.combat_stats!=null else null

## Spawn: 도박사의 주사위 rolls this battle's stat swing (seeded by the battle), 망원 렌즈 widens
## the unit's reach. Works on a copy so the guild's stats and the shared unit data never change.
static func on_spawn(u) -> void:
	var stats: UnitCombatStats=_stats(u)
	if stats==null:return
	if stats.dice:
		stats=stats.copy();u.combat_stats=stats
		var picks: Array=ItemTuning.DICE_STATS.duplicate();var up: String=picks.pop_at(u.battle.rng.randi_range(0,picks.size()-1));var down: String=picks[u.battle.rng.randi_range(0,picks.size()-1)]
		stats.set(up,float(stats.get(up))*(1+ItemTuning.DICE_UP));stats.set(down,float(stats.get(down))*(1+ItemTuning.DICE_DOWN))
		u.set_state("diceUp",up);u.set_state("diceDown",down)
	if not is_equal_approx(stats.range_multiplier,1.0):
		var data: UnitData=u.data.duplicate(true);var k: float=stats.range_multiplier
		data.attack_range*=k;data.attack_profile.reach*=k;data.attack_profile.projectile_lifetime*=k;u.data=data

## 두 얼굴의 가면: physical becomes magic and back.
static func flip(kind: StringName) -> StringName:return &"magic" if kind==&"physical" else &"physical" if kind==&"magic" else kind
## The damage instance as this attacker really deals it: the mask swaps its kind, the
## enchanted blade adds the bearer's element to basic attacks.
static func adjust_spec(source,spec: Dictionary) -> Dictionary:
	var stats: UnitCombatStats=_stats(source)
	if stats==null or not (stats.kind_swap or stats.enchant):return spec
	var out: Dictionary=spec.duplicate();out.tags=Array(spec.get("tags",[])).duplicate()
	if stats.kind_swap:out.kind=flip(StringName(spec.get("kind",&"physical")))
	if stats.enchant and spec.get("skill",&"")==&"basic":
		var element: StringName=CharacterCatalog.element(source.data.type_id)
		if element==&"":element=ItemTuning.ENCHANT_DEFAULT_ELEMENT
		if not element in out.tags:out.tags.append(element)
	return out

## Damage the attacker deals: 결투가의 장갑 stacks on the same target, 원소술사의 서 hits harder
## on targets with an element status.
static func outgoing(source,target,options: Dictionary) -> float:
	var stats: UnitCombatStats=_stats(source)
	if stats==null or not is_instance_valid(target):return 1.0
	var factor: float=1.0
	if stats.duelist:
		var stacks: int=int(source.state_value("duelStacks"))
		if str(source.character_specific_state.get("duelTarget",""))==target.actor_id():stacks=mini(stacks+1,roundi(ItemTuning.DUELIST_MAX/ItemTuning.DUELIST_STEP))
		else:stacks=0
		source.set_state("duelTarget",target.actor_id());source.set_state("duelStacks",stacks)
		factor*=1+stacks*ItemTuning.DUELIST_STEP
	if stats.elementalist and elemental(target):factor*=ItemTuning.ELEMENTALIST_DEALT
	return factor
static func elemental(u) -> bool:
	return u.state_value("burnStacks")>0 or u.state_value("poisonStacks")>0 or u.state_value("frostStacks")>0 or u.state_value("frozenTime")>0 or u.state_value("shockStacks")>0 or u.state_value("erosionTime")>0

## Damage the target takes: 선봉의 방패 early in the battle, 성역의 등불 near a lamp bearer.
static func incoming(target) -> float:
	var factor: float=1.0;var stats: UnitCombatStats=_stats(target)
	if stats!=null and stats.vanguard and target.battle.clock.elapsed<ItemTuning.VANGUARD_TIME:factor*=ItemTuning.VANGUARD_TAKEN
	for ally in target.battle.units:
		var lamp: UnitCombatStats=_stats(ally)
		if lamp!=null and lamp.sanctuary and ally.alive and ally.team==target.team and ally.position.distance_to(target.position)<=ItemTuning.SANCTUARY_RADIUS*ally.combat_scale():
			factor*=ItemTuning.SANCTUARY_TAKEN;break
	return factor

## Attack bonus from 군주의 검 kills nearby.
static func attack_factor(u) -> float:
	var stacks: float=u.state_value("sovereignStacks") if u.state_value("sovereignTime")>0 else 0.0
	return 1+stacks*ItemTuning.SOVEREIGN_BUFF

## After a basic hit: 연쇄의 고리 counts it and every CHAIN_EVERY-th one jumps (not a direct hit).
static func after_hit(source,target,out: DamageOutcome,spec: Dictionary,options: Dictionary) -> void:
	var stats: UnitCombatStats=_stats(source)
	if stats==null or not stats.chain_ring or spec.get("skill",&"")!=&"basic" or options.get("chain_ring",false) or out.hp_damage+out.shield_absorbed<=0:return
	var count: int=int(source.state_value("chainCount"))+1;source.set_state("chainCount",count)
	if count%ItemTuning.CHAIN_EVERY!=0:return
	var best=null;var near: float=ItemTuning.CHAIN_RANGE*source.combat_scale()
	for e in source.enemies(false):
		if e==target or not e.alive or e.unavailable():continue
		var d: float=e.position.distance_to(target.position)
		if d<=near:near=d;best=e
	if best==null:return
	source.battle.emit_combat_event(&"chain_ring",target.position,{"actor_id":source.battle_id,"to":CharacterPersistence.point(best.position)})
	source.battle.damage_resolver.resolve(source,best,out.resolved_damage,{"dmg":&"chain_ring","plain":true,"status":&"chain_ring","chain_ring":true,"critical":false,"impulse":0,"attack_origin":target.position})

## 과충전 코어: part of the gauge comes back right after an ultimate.
static func after_ultimate(u) -> void:
	var stats: UnitCombatStats=_stats(u)
	if stats!=null and stats.overcharge_count>0:u.ultimate_gauge=clampf(u.ultimate_gauge+ItemTuning.OVERCHARGE_REFUND*stats.overcharge_count,0,100)

## 군주의 검: a kill raises the attack of allies nearby (the bearer too).
static func on_kill(source) -> void:
	var stats: UnitCombatStats=_stats(source)
	if stats==null or not stats.sovereign:return
	source.battle.emit_combat_event(&"sovereign_roar",source.position,{"actor_id":source.battle_id,"radius":ItemTuning.SOVEREIGN_RADIUS*source.combat_scale()})
	for ally in source.battle.units:
		if not ally.alive or ally.team!=source.team or ally.position.distance_to(source.position)>ItemTuning.SOVEREIGN_RADIUS*source.combat_scale():continue
		var stacks: float=ally.state_value("sovereignStacks") if ally.state_value("sovereignTime")>0 else 0.0
		ally.set_state("sovereignStacks",minf(ItemTuning.SOVEREIGN_STACKS,stacks+1));ally.set_state("sovereignTime",ItemTuning.SOVEREIGN_TIME)

## 거인의 심장: not knocked back or pulled.
static func immovable(u) -> bool:
	var stats: UnitCombatStats=_stats(u);return stats!=null and stats.immovable
