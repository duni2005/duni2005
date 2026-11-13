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
static func adjust_spec(source,spec: Dictionary,target=null) -> Dictionary:
	var stats: UnitCombatStats=_stats(source)
	if stats==null or not (stats.kind_swap or stats.enchant or stats.has(&"hexRing")):return spec
	var out: Dictionary=spec.duplicate();out.tags=Array(spec.get("tags",[])).duplicate()
	if stats.kind_swap:out.kind=flip(StringName(spec.get("kind",&"physical")))
	# 주술 반지: a basic attack takes the kind the target defends worse against (raw damage unchanged).
	if stats.has(&"hexRing") and spec.get("skill",&"")==&"basic" and is_instance_valid(target):
		var weak: StringName=&"physical" if CombatRules.mitigation(target,&"physical")>=CombatRules.mitigation(target,&"magic") else &"magic"
		if weak!=StringName(out.get("kind",&"physical")):out.kind=weak;fx(source,&"hexRing",target.position,{"kind":String(weak)})
	if stats.enchant and spec.get("skill",&"")==&"basic":
		var element: StringName=CharacterCatalog.element(source.data.type_id)
		if element==&"":element=ItemTuning.ENCHANT_DEFAULT_ELEMENT
		if not element in out.tags:out.tags.append(element)
	return out

## Damage the attacker deals: 결투가의 장갑 stacks on the same target, 원소술사의 서 hits harder
## on targets with an element status.
static func outgoing(source,target,options: Dictionary,spec: Dictionary={}) -> float:
	var stats: UnitCombatStats=_stats(source)
	if stats==null or not is_instance_valid(target):return 1.0
	var factor: float=1.0
	var basic: bool=spec.get("skill",&"")==&"basic" and ElementEffects.direct(spec,options)
	if stats.has(&"sniperScope") and source.position.distance_to(target.position)>=ItemTuning.SCOPE_DISTANCE:
		factor*=1+ItemTuning.SCOPE_DEALT;proc(source,&"sniperScope");fx(source,&"sniperScope",target.position)
	if stats.has(&"firstStrikeRing") and basic and source.state_value("firstStrike")>0:
		source.set_state("firstStrike",0.0);factor*=1+ItemTuning.FIRST_STRIKE;proc(source,&"firstStrikeRing");fx(source,&"firstStrikeRing",target.position)
	if stats.has(&"oblivionVeil") and source.state_value("veilReady")>0 and ElementEffects.direct(spec,options):
		source.set_state("veilReady",0.0);source.set_state("shadowTime",0.0);factor*=ItemTuning.VEIL_STRIKE;proc(source,&"oblivionVeil");fx(source,&"oblivionVeil",target.position)
	if stats.has(&"steelGreatsword") and basic and source.state_value("smashCount")>=ItemTuning.GREATSWORD_EVERY-1:
		source.set_state("smashCount",0.0);source.set_state("smashHit",1.0);factor*=ItemTuning.GREATSWORD_DEALT;proc(source,&"steelGreatsword")
	if stats.has(&"shadowDoll"):factor*=ItemTuning.DOLL_DEALT
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
	if stats!=null:
		# 광폭의 뿔: the 저돌적 damage-taken penalty does not apply.
		if stats.has(&"rageHorn") and target.stance==CombatStance.RUSH:factor/=StanceRules.RUSH_TAKEN
		if target.state_value("regenTime")>0:factor*=ItemTuning.REGEN_TAKEN
		if stats.has(&"greedPouch"):factor*=ItemTuning.GREED_TAKEN
	for ally in target.battle.units:
		var lamp: UnitCombatStats=_stats(ally)
		if lamp!=null and lamp.sanctuary and ally.alive and ally.team==target.team and ally.position.distance_to(target.position)<=ItemTuning.SANCTUARY_RADIUS*ally.combat_scale():
			factor*=ItemTuning.SANCTUARY_TAKEN;break
	return factor

## Attack bonus from 군주의 검 kills nearby.
static func attack_factor(u) -> float:
	var stacks: float=u.state_value("sovereignStacks") if u.state_value("sovereignTime")>0 else 0.0
	return (1+stacks*ItemTuning.SOVEREIGN_BUFF)*(1+void_bonus(u))
## 공허의 심장: attack bonus from the healing turned away.
static func void_bonus(u) -> float:return minf(ItemTuning.VOID_MAX,floorf(u.state_value("voidHeal")/ItemTuning.VOID_PER)*ItemTuning.VOID_STEP)

## After a basic hit: 연쇄의 고리 counts it and every CHAIN_EVERY-th one jumps (not a direct hit).
static func after_hit(source,target,out: DamageOutcome,spec: Dictionary,options: Dictionary) -> void:
	if is_instance_valid(source) and source.team!=target.team:
		_struck(source,target,out,spec,options)
		_was_struck(target,source,out,spec,options)
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
	if stats==null or not u.alive:return
	if stats.has(&"stormCrown"):
		var radius: float=ItemTuning.STORM_RADIUS*u.combat_scale();var struck: Array=[]
		for e in u.enemies(false):
			if not e.alive or e.unavailable() or e.position.distance_to(u.position)>radius:continue
			struck.append(CharacterPersistence.point(e.position))
			u.battle.damage_resolver.resolve(u,e,UnitStatTable.raw(u,&"storm_crown"),{"dmg":&"storm_crown","status":&"item_storm","critical":false,"impulse":0})
			if e.alive:ElementEffects.add_shock(e,ItemTuning.STORM_SHOCK)
		proc(u,&"stormCrown");fx(u,&"stormCrown",u.position,{"to":struck,"radius":radius})
	if stats.has(&"regenCore"):
		CharacterAbility.restore_hp(u,u.max_hp*ItemTuning.REGEN_HEAL,u);u.set_state("regenTime",ItemTuning.REGEN_TIME)
		proc(u,&"regenCore");fx(u,&"regenCore",u.position)
	if stats.has(&"lifeResonance"):
		var radius: float=ItemTuning.RESONANCE_RADIUS*u.combat_scale();var healed: Array=[]
		for a in u.battle.units:
			if a.alive and a.team==u.team and not a.unavailable() and a.position.distance_to(u.position)<=radius:
				CharacterAbility.restore_hp(a,a.max_hp*ItemTuning.RESONANCE_HEAL,u);healed.append(CharacterPersistence.point(a.position))
		proc(u,&"lifeResonance");fx(u,&"lifeResonance",u.position,{"radius":radius,"to":healed})

## 군주의 검: a kill raises the attack of allies nearby (the bearer too).
static func on_kill(source,victim=null) -> void:
	var stats: UnitCombatStats=_stats(source)
	if stats!=null and source.alive:
		if stats.has(&"hunterShuriken"):source.set_state("hunterTime",ItemTuning.HUNTER_TIME);proc(source,&"hunterShuriken");fx(source,&"hunterShuriken",source.position)
		if stats.has(&"rageHorn"):CharacterAbility.restore_hp(source,source.max_hp*ItemTuning.HORN_HEAL,source);proc(source,&"rageHorn");fx(source,&"rageHorn",source.position)
		if stats.has(&"frostCrown") and victim!=null and victim.state_value("frozenTime")>0:
			for e in source.enemies(false):
				if e!=victim and e.alive and not e.unavailable() and e.position.distance_to(victim.position)<=ItemTuning.FROST_CROWN_RADIUS*source.combat_scale():ElementEffects.add_frost(source,e,ItemTuning.FROST_CROWN_STACKS)
			proc(source,&"frostCrown");fx(source,&"frostCrown",victim.position,{"radius":ItemTuning.FROST_CROWN_RADIUS*source.combat_scale()})
	if stats==null or not stats.sovereign:return
	source.battle.emit_combat_event(&"sovereign_roar",source.position,{"actor_id":source.battle_id,"radius":ItemTuning.SOVEREIGN_RADIUS*source.combat_scale()})
	for ally in source.battle.units:
		if not ally.alive or ally.team!=source.team or ally.position.distance_to(source.position)>ItemTuning.SOVEREIGN_RADIUS*source.combat_scale():continue
		var stacks: float=ally.state_value("sovereignStacks") if ally.state_value("sovereignTime")>0 else 0.0
		ally.set_state("sovereignStacks",minf(ItemTuning.SOVEREIGN_STACKS,stacks+1));ally.set_state("sovereignTime",ItemTuning.SOVEREIGN_TIME)

## 거인의 심장: not knocked back or pulled.
static func immovable(u) -> bool:
	var stats: UnitCombatStats=_stats(u);return stats!=null and stats.immovable

# ==== 0.95 items ====
## Whether the unit wears an item with this effect (its stats; a 거울 분신 has none).
static func has(u,effect: StringName) -> bool:
	var stats: UnitCombatStats=_stats(u);return stats!=null and stats.has(effect)
static func _now(u) -> float:return u.battle.clock.elapsed
## The item's icon rises over the unit's head (same item at most once per PROC_ICON_GAP).
static func proc(u,item: StringName) -> void:
	var key: String="proc_"+String(item);var now: float=_now(u)
	if now-float(u.character_specific_state.get(key,-99.0))<ItemTuning.PROC_ICON_GAP:return
	u.character_specific_state[key]=now
	u.battle.emit_combat_event(&"item_proc",u.position,{"actor_id":u.battle_id,"item":String(item)})
## An item effect for the presentation (ItemFx draws it by item).
static func fx(u,item: StringName,at: Vector2,meta: Dictionary={}) -> void:
	var m: Dictionary=meta.duplicate();m["item"]=String(item);m["actor_id"]=u.battle_id
	u.battle.emit_combat_event(&"item_fx",at,m)
static func _hit(source,target,key: StringName,status: StringName,amount: float,extra: Dictionary={}) -> DamageOutcome:
	var options: Dictionary={"dmg":key,"status":status,"critical":false,"impulse":0}
	options.merge(extra,true)
	return target.battle.damage_resolver.resolve(source,target,amount,options)
static func _clone(u) -> bool:return u.character_specific_state.has("mirrorOf")

## Battle start (all units placed): one-off setup of the items that act from the first second.
static func on_battle_start(battle) -> void:
	if not battle.full_characters_enabled:return
	for u in battle.units.duplicate():
		var stats: UnitCombatStats=_stats(u)
		if stats==null or stats.effects.is_empty() or not u.alive:continue
		if stats.has(&"firstStrikeRing"):u.set_state("firstStrike",1.0)
		if stats.has(&"salvationFeather"):u.set_state("salvationUses",float(ItemTuning.SALVATION_USES))
		if stats.has(&"oblivionVeil"):
			u.set_state("shadowTime",maxf(u.state_value("shadowTime"),ItemTuning.VEIL_TIME));u.set_state("veilReady",1.0);u.hidden_from_enemies=true
			fx(u,&"oblivionVeil",u.position,{"cloak":true})
		if stats.has(&"rewindClock"):
			u.set_state("rewindLeft",ItemTuning.REWIND_AT);u.set_state("rewindHp",u.current_hp);u.set_state("rewindFrom",CharacterPersistence.point(u.position));u.set_state("rewindPath",[CharacterPersistence.point(u.position)])
		if stats.has(&"mangoSeed"):u.set_state("mangoStage",float(stats.mango_stage));u.set_state("mangoClock",ItemTuning.MANGO_EVERY)
		if stats.has(&"elderHeart"):u.set_state("elderHealClock",ItemTuning.ELDER_HEAL_EVERY);u.set_state("elderGrowClock",ItemTuning.ELDER_GROW_EVERY)
		if stats.has(&"overdriveEngine"):u.set_state("overdrive",0.0)
		if stats.has(&"invertedHourglass") and battle.turning==null:u.set_state("hourglassAt",ItemTuning.HOURGLASS_FIRST)
		if stats.has(&"greedPouch"):u.set_state("greedGold",0.0)
		if stats.has(&"emptyFrame"):_copy_item(u)
		if stats.has(&"twinMirror"):_spawn_mirror(u)
## 빈 액자: one item (not 고대) of the nearest ally, picked with the battle's rng.
static func _copy_item(u) -> void:
	var near=null
	for a in u.battle.units:
		if a==u or not a.alive or a.team!=u.team or _stats(a)==null:continue
		if near==null or a.position.distance_to(u.position)<near.position.distance_to(u.position):near=a
	if near==null:return
	var pool: Array=_stats(near).items.filter(func(i):return i.grade!=&"ancient" and not i.consumable)
	if pool.is_empty():return
	var item: ItemData=pool[u.battle.rng.randi_range(0,pool.size()-1)]
	var stats: UnitCombatStats=u.combat_stats.copy();u.combat_stats=stats
	var before: float=stats.max_hp;stats.add_item_live(item)
	if stats.max_hp>before:u.current_hp+=stats.max_hp-before
	u.set_state("frameItem",item.display_name);u.set_state("frameKind",String(item.kind))
	proc(u,&"emptyFrame");fx(u,&"emptyFrame",u.position,{"copy":String(item.kind),"from":CharacterPersistence.point(near.position)})
## 쌍둥이의 거울: a copy at half HP and damage, with no item effects and no ultimate.
static func _spawn_mirror(u) -> void:
	var stats: UnitCombatStats=u.combat_stats.copy()
	stats.max_hp*=ItemTuning.MIRROR_HP;stats.physical_damage*=ItemTuning.MIRROR_DAMAGE;stats.magic_damage*=ItemTuning.MIRROR_DAMAGE
	stats.effects={};stats.items=[]
	for flag in ["duelist","vanguard","elementalist","enchant","chain_ring","sovereign","immovable","sanctuary","kind_swap","crown","dice"]:stats.set(flag,false)
	for count in ["vigor_totem_count","charge_totem_count","fang_count","opening_awl_count","phoenix_count","hourglass_count","dragon_heart_count","overcharge_count","victory_gold"]:stats.set(count,0)
	var side: Vector2=Vector2.from_angle(u.facing+PI*.5)*44*u.combat_scale()
	u.battle.queue_spawn(u,u.position+side,stats,{"mirrorOf":u.actor_id()},side*3)
	proc(u,&"twinMirror");fx(u,&"twinMirror",u.position+side)

## Every tick (after the element upkeep).
static func advance(battle,dt: float) -> void:
	if not battle.full_characters_enabled:return
	_bend_projectiles(battle,dt)
	for u in battle.units.duplicate():
		if not u.alive:continue
		if u.state_value("bleedTime")>0:_bleed(u,dt)
		if u.character_specific_state.has("echoes"):_echoes(u,dt)
		for key in ["hunterTime","regenTime","overheatTime"]:
			if u.state_value(key)>0:u.set_state(key,maxf(0,u.state_value(key)-dt))
		if _clone(u) and not u.has_meta("mirror_shown"):u.set_meta("mirror_shown",true);u.modulate=Color(.85,.92,1,.72);u.ultimate_gauge=0;u.transcendence_gauge=0
		var stats: UnitCombatStats=_stats(u)
		if stats==null or stats.effects.is_empty() or not u.alive:continue
		if stats.has(&"oblivionVeil") and u.data.type_id!=3:u.hidden_from_enemies=u.state_value("shadowTime")>0
		if stats.has(&"salvationFeather"):_salvation(u)
		if stats.has(&"windTrail"):_wind_trail(u,dt)
		if stats.has(&"elderHeart"):_elder(u,dt)
		if stats.has(&"mangoSeed") and int(u.state_value("mangoStage"))>=ItemTuning.MANGO_STAGES:
			u.set_state("mangoClock",u.state_value("mangoClock")-dt)
			if u.state_value("mangoClock")<=0:
				u.set_state("mangoClock",ItemTuning.MANGO_EVERY);var healed: Array=[]
				for a in battle.units:
					if a.alive and a.team==u.team and not a.unavailable():CharacterAbility.restore_hp(a,a.max_hp*ItemTuning.MANGO_HEAL,u);healed.append(CharacterPersistence.point(a.position))
				proc(u,&"mangoSeed");fx(u,&"mangoSeed",u.position,{"to":healed})
		if stats.has(&"rewindClock") and u.state_value("rewindLeft")>0:_rewind(u,dt)
		if stats.has(&"invertedHourglass") and u.character_specific_state.has("hourglassAt") and _now(u)>=u.state_value("hourglassAt"):
			u.set_state("hourglassAt",u.state_value("hourglassAt")+ItemTuning.HOURGLASS_EVERY);_fill_gauge(u)
		if stats.has(&"overdriveEngine") and u.state_value("overheatTime")<=0:
			u.set_state("overdrive",u.state_value("overdrive")+dt)
			if u.state_value("overdrive")>=ItemTuning.OVERDRIVE_TIME:
				u.set_state("overdrive",0.0);u.set_state("overheatTime",ItemTuning.OVERHEAT_TIME);StatusController.stun(u,ItemTuning.OVERHEAT_TIME)
				proc(u,&"overdriveEngine");fx(u,&"overdriveEngine",u.position,{"overheat":true})

## Attack-speed factor: 광전사의 투구 (low HP), 사냥꾼의 표창 (after a kill), 폭주 기관 (wind-up).
static func attack_speed(u) -> float:
	var stats: UnitCombatStats=_stats(u)
	if stats==null or stats.effects.is_empty():return 1.0
	var k: float=1.0
	if stats.has(&"berserkerHelm") and berserk(u):k*=1+ItemTuning.BERSERK_ATTACK_SPEED
	if u.state_value("hunterTime")>0:k*=1+ItemTuning.HUNTER_ATTACK_SPEED
	if stats.has(&"overdriveEngine"):k*=1+floorf(u.state_value("overdrive"))*ItemTuning.OVERDRIVE_STEP
	return k
static func berserk(u) -> bool:return u.alive and u.current_hp<=u.max_hp*ItemTuning.BERSERK_HP
## Move-speed factor: 구원의 깃털 while running to a wounded ally.
static func move_speed(u) -> float:
	return 1+ItemTuning.SALVATION_SPEED if u.character_specific_state.get("salvationRun",false)==true else 1.0

## 구원의 깃털: running to the nearest ally at low HP; touching it shields it.
static func _salvation(u) -> void:
	u.set_state("salvationRun",false)
	if u.state_value("salvationUses")<=0:return
	var low=null
	for a in u.battle.units:
		if a==u or not a.alive or a.team!=u.team or a.unavailable() or a.current_hp>a.max_hp*ItemTuning.SALVATION_HP:continue
		if a.position.distance_to(u.position)>ItemTuning.SALVATION_RANGE:continue
		if low==null or a.position.distance_to(u.position)<low.position.distance_to(u.position):low=a
	if low==null:return
	var to: Vector2=low.position-u.position
	if to.length()<=ItemTuning.SALVATION_REACH*u.combat_scale():
		u.set_state("salvationUses",u.state_value("salvationUses")-1)
		low.shield_hp=low.shield_hp+low.max_hp*ItemTuning.SALVATION_SHIELD;low.shield_remaining=maxf(low.shield_remaining,ItemTuning.SALVATION_SHIELD_TIME)
		proc(u,&"salvationFeather");fx(u,&"salvationFeather",low.position,{"shield":true})
	elif u.velocity.length()>5 and u.velocity.dot(to)>0:
		u.set_state("salvationRun",true);fx_trail(u,&"salvationFeather")
## A trail puff for effects that last while moving (drawn sparsely).
static func fx_trail(u,item: StringName) -> void:
	var key: String="trail_"+String(item)
	if _now(u)-float(u.character_specific_state.get(key,-9.0))<.12:return
	u.character_specific_state[key]=_now(u);fx(u,item,u.position,{"trail":true})

## 출혈: every BLEED_EVERY a tick of physical damage over time.
static func bleed(source,target,dealt: float) -> void:
	var per: float=dealt*ItemTuning.BLEED_SHARE/(ItemTuning.BLEED_TIME/ItemTuning.BLEED_EVERY)
	if per<=0:return
	var old: float=target.state_value("bleedPer") if target.state_value("bleedTime")>0 else 0.0
	if target.state_value("bleedTime")<=0:target.set_state("bleedTick",ItemTuning.BLEED_EVERY)
	target.set_state("bleedTime",ItemTuning.BLEED_TIME);target.set_state("bleedPer",maxf(per,old));target.set_state("bleedSource",source.actor_id())
static func _bleed(u,dt: float) -> void:
	u.set_state("bleedTime",maxf(0,u.state_value("bleedTime")-dt));u.set_state("bleedTick",u.state_value("bleedTick")-dt)
	if u.state_value("bleedTick")<=0:
		u.set_state("bleedTick",u.state_value("bleedTick")+ItemTuning.BLEED_EVERY)
		var by=u.battle.find_actor(str(u.character_specific_state.get("bleedSource","")))
		if by!=null:
			var stats: UnitCombatStats=_stats(by)
			_hit(by,u,&"bleed",&"bleed",u.state_value("bleedPer")*(1+UnitStatTable.tag_bonus(stats,[&"dot"])),{"fixed":true})
	if u.state_value("bleedTime")<=0:u.set_state("bleedPer",0.0)
## 메아리 지팡이: queued repeats land after ECHO_DELAY.
static func _echoes(u,dt: float) -> void:
	var left: Array=[]
	for e in u.character_specific_state.echoes:
		e.t=float(e.t)-dt
		if float(e.t)>0:left.append(e);continue
		var by=u.battle.find_actor(str(e.by))
		if by!=null and u.alive:_hit(by,u,&"echo_staff",&"item_echo",float(e.amount),{"fixed":true});fx(by,&"echoStaff",u.position,{"from":e.from})
	if left.is_empty():u.character_specific_state.erase("echoes")
	else:u.character_specific_state.echoes=left
## 바람의 궤적: points left behind for WIND_TRAIL_TIME; enemies crossing them catch headwind.
static func _wind_trail(u,dt: float) -> void:
	var trail: Array=u.character_specific_state.get("windTrail",[]);var now: float=_now(u)
	trail=trail.filter(func(p):return now-float(p.t)<ItemTuning.WIND_TRAIL_TIME)
	if (trail.is_empty() or Vector2(float(trail[-1].x),float(trail[-1].y)).distance_to(u.position)>18) and now-float(u.character_specific_state.get("windTrailAt",-9.0))>=ItemTuning.WIND_TRAIL_STEP:
		trail.append({"x":u.position.x,"y":u.position.y,"t":now});u.set_state("windTrailAt",now)
	u.set_state("windTrail",trail)
	var width: float=ItemTuning.WIND_TRAIL_WIDTH*u.combat_scale();var touched: bool=false
	for e in u.enemies(false):
		if not e.alive or e.unavailable():continue
		for p in trail:
			if Vector2(float(p.x),float(p.y)).distance_to(e.position)<=width:
				if e.state_value("headwindTime")<=0:touched=true
				e.set_state("headwindTime",ElementEffects.HEADWIND_TIME);break
	if touched:proc(u,&"windTrail")
## 거목의 심장: periodic healing and growth (max HP up, current HP with it).
static func _elder(u,dt: float) -> void:
	u.set_state("elderHealClock",u.state_value("elderHealClock")-dt);u.set_state("elderGrowClock",u.state_value("elderGrowClock")-dt)
	if u.state_value("elderHealClock")<=0:
		u.set_state("elderHealClock",ItemTuning.ELDER_HEAL_EVERY)
		if CharacterAbility.restore_hp(u,u.max_hp*ItemTuning.ELDER_HEAL,u)>0:fx(u,&"elderHeart",u.position,{"heal":true})
	if u.state_value("elderGrowClock")<=0 and u.state_value("elderStacks")<ItemTuning.ELDER_STACKS:
		u.set_state("elderGrowClock",ItemTuning.ELDER_GROW_EVERY);u.set_state("elderStacks",u.state_value("elderStacks")+1)
		if not u.has_meta("own_stats"):u.combat_stats=u.combat_stats.copy();u.set_meta("own_stats",true)
		var gain: float=u.combat_stats.max_hp*ItemTuning.ELDER_GROW;u.combat_stats.max_hp+=gain;u.current_hp+=gain
		proc(u,&"elderHeart");fx(u,&"elderHeart",u.position,{"grow":int(u.state_value("elderStacks"))})
## 역행의 시계: counts down, records the path, then puts HP and position back once.
static func _rewind(u,dt: float) -> void:
	u.set_state("rewindLeft",maxf(0,u.state_value("rewindLeft")-dt))
	var path: Array=u.character_specific_state.get("rewindPath",[])
	if path.is_empty() or CharacterPersistence.vector(path[-1]).distance_to(u.position)>30:
		path.append(CharacterPersistence.point(u.position))
		if path.size()>40:path.remove_at(1)
		u.set_state("rewindPath",path)
	if u.state_value("rewindLeft")>0:return
	var back: Vector2=CharacterPersistence.vector(u.character_specific_state.get("rewindFrom",{}),u.position)
	fx(u,&"rewindClock",back,{"path":path.duplicate(true)})
	u.current_hp=clampf(u.state_value("rewindHp"),1,u.max_hp);u.position=MovementController.clamp_position(back)
	u.velocity=Vector2.ZERO;u.knockback_velocity=Vector2.ZERO;u.combat.cancel(u)
	u.character_specific_state.erase("rewindPath");proc(u,&"rewindClock")
## 거꾸로 된 모래시계: a full gauge.
static func _fill_gauge(u) -> void:
	u.ultimate_gauge=100;proc(u,&"invertedHourglass");fx(u,&"invertedHourglass",u.position)
## A turning point opened (tower battles): every 거꾸로 된 모래시계 fills its bearer's gauge.
static func on_turning_point(battle) -> void:
	for u in battle.units:
		if u.alive and has(u,&"invertedHourglass"):_fill_gauge(u)

## A hit by `source` landed on `target` (an enemy).
static func _struck(source,target,out: DamageOutcome,spec: Dictionary,options: Dictionary) -> void:
	var stats: UnitCombatStats=_stats(source);var dealt: float=out.hp_damage+out.shield_absorbed
	var direct: bool=ElementEffects.direct(spec,options) and out.status==&""
	var battle=source.battle
	if direct and source.alive and dealt>0:
		var leech: float=0
		if stats!=null and stats.has(&"vampireFang"):leech+=ItemTuning.VAMPIRE_LEECH
		if blood_blessed(source):leech+=ItemTuning.BLOOD_LEECH
		if leech>0 and CharacterAbility.restore_hp(source,dealt*leech,source)>0:
			if stats!=null and stats.has(&"vampireFang"):fx(source,&"vampireFang",target.position,{"to":CharacterPersistence.point(source.position)})
			if blood_blessed(source):fx(source,&"bloodChalice",target.position,{"to":CharacterPersistence.point(source.position)})
		if stats!=null and stats.has(&"greedPouch") and source.state_value("greedGold")<ItemTuning.GREED_MAX:
			source.set_state("greedGold",minf(ItemTuning.GREED_MAX,source.state_value("greedGold")+ItemTuning.GREED_GOLD));fx(source,&"greedPouch",target.position)
	if stats==null or stats.effects.is_empty():return
	if direct and spec.get("skill",&"")==&"basic":
		if stats.has(&"steelGreatsword"):
			if source.state_value("smashHit")>0:
				source.set_state("smashHit",0.0);fx(source,&"steelGreatsword",target.position)
				if target.alive:KnockbackController.apply(target,(target.position-source.position).normalized()*ItemTuning.GREATSWORD_PUSH,source)
			else:source.set_state("smashCount",source.state_value("smashCount")+1)
	if direct and stats.has(&"echoStaff") and StringName(spec.get("kind",&"physical"))==&"magic" and dealt>0 and battle.rng.randf()<ItemTuning.ECHO_CHANCE:
		var echoes: Array=target.character_specific_state.get("echoes",[])
		echoes.append({"t":ItemTuning.ECHO_DELAY,"by":source.actor_id(),"amount":dealt*ItemTuning.ECHO_SHARE,"from":CharacterPersistence.point(source.position)})
		target.set_state("echoes",echoes);proc(source,&"echoStaff")
	if not out.critical:return
	if stats.has(&"infinityEdge"):fx(source,&"infinityEdge",target.position)
	if stats.has(&"bleedBlade") and dealt>0 and target.alive:bleed(source,target,dealt);proc(source,&"bleedBlade");fx(source,&"bleedBlade",target.position)
	if stats.has(&"elementStone"):_element_burst(source,target)
	var elite: bool=_stats(target)!=null and _stats(target).rank!=&"normal"
	if stats.has(&"executionScythe") and target.alive and not elite and target.current_hp+out.hp_damage<=target.max_hp*ItemTuning.SCYTHE_HP:
		fx(source,&"executionScythe",target.position);proc(source,&"executionScythe")
		_hit(source,target,&"execution",&"item_execute",target.current_hp+target.shield_hp,{"fixed":true})
## 원소 폭발석: a critical hit on a unit carrying burn / poison / frost / shock stacks spreads half
## of each to the enemies around it and bursts for magic damage.
static func _element_burst(source,target) -> void:
	var stacks: Dictionary={"burn":int(target.state_value("burnStacks"))/2,"poison":int(target.state_value("poisonStacks"))/2,"frost":int(target.state_value("frostStacks"))/2,"shock":int(target.state_value("shockStacks"))/2}
	if stacks.values().all(func(v):return v<=0) and not ["burnStacks","poisonStacks","frostStacks","shockStacks"].any(func(k):return target.state_value(k)>0):return
	var radius: float=ItemTuning.STONE_RADIUS*source.combat_scale();var to: Array=[]
	for e in source.enemies(false):
		if not e.alive or e.unavailable() or e.position.distance_to(target.position)>radius:continue
		if e!=target:
			to.append(CharacterPersistence.point(e.position))
			if stacks.burn>0:ElementEffects.add_burn(source,e,stacks.burn)
			if stacks.poison>0:e.set_state("poisonStacks",e.state_value("poisonStacks")+stacks.poison);e.set_state("poisonSource",source.actor_id())
			if stacks.frost>0:ElementEffects.add_frost(source,e,stacks.frost)
			if stacks.shock>0:ElementEffects.add_shock(e,stacks.shock)
		_hit(source,e,&"element_stone",&"item_burst",UnitStatTable.raw(source,&"element_stone"))
	var color: String="fire" if stacks.burn>0 or target.state_value("burnStacks")>0 else "poison" if target.state_value("poisonStacks")>0 else "ice" if target.state_value("frostStacks")>0 else "lightning"
	proc(source,&"elementStone");fx(source,&"elementStone",target.position,{"radius":radius,"to":to,"element":color})
## `target` (with items) was hit by an enemy `source`.
static func _was_struck(target,source,out: DamageOutcome,spec: Dictionary,options: Dictionary) -> void:
	var stats: UnitCombatStats=_stats(target)
	if stats==null or stats.effects.is_empty() or not target.alive:return
	var taken: float=out.hp_damage+out.shield_absorbed
	var direct: bool=ElementEffects.direct(spec,options) and out.status==&""
	if stats.has(&"thornArmor") and direct and spec.get("tags",[]).has(&"melee") and taken>0 and source.alive:
		_hit(target,source,&"thorn_armor",&"item_thorns",taken*ItemTuning.THORN_REFLECT,{"plain":true});proc(target,&"thornArmor");fx(target,&"thornArmor",target.position,{"to":CharacterPersistence.point(source.position)})
	if stats.has(&"sporeMoss") and direct and target.battle.rng.randf()<ItemTuning.SPORE_CHANCE:
		for e in target.enemies(false):
			if e.alive and not e.unavailable() and e.position.distance_to(target.position)<=ItemTuning.SPORE_RADIUS*target.combat_scale():
				e.set_state("poisonStacks",e.state_value("poisonStacks")+1);e.set_state("poisonSource",target.actor_id())
		proc(target,&"sporeMoss");fx(target,&"sporeMoss",target.position,{"radius":ItemTuning.SPORE_RADIUS*target.combat_scale()})
	if stats.has(&"oathChain") and target.stance==CombatStance.COVER and taken>0:
		var ward=target.battle.find_actor(target.cover_actor_id)
		if ward!=null and ward.alive and ward.position.distance_to(target.position)<=ItemTuning.OATH_RADIUS*target.combat_scale():
			var cap: float=target.max_hp*ItemTuning.OATH_CAP
			if target.shield_hp<cap:
				target.shield_hp=minf(cap,target.shield_hp+taken*ItemTuning.OATH_SHARE);target.shield_remaining=maxf(target.shield_remaining,ItemTuning.OATH_SHIELD_TIME)
				proc(target,&"oathChain");fx(target,&"oathChain",target.position,{"to":CharacterPersistence.point(ward.position)})

## 피의 성배: a living bearer on the unit's side.
static func blood_blessed(u) -> bool:
	for a in u.battle.units:
		if a.alive and a.team==u.team and has(a,&"bloodChalice"):return true
	return false
## 반격의 방패: a parry or dodge arms a sure critical hit.
static func on_defended(u) -> void:
	if not is_instance_valid(u) or not u.alive or not has(u,&"counterShield"):return
	u.set_state("counterCritUntil",_now(u)+ItemTuning.COUNTER_SHIELD_TIME);proc(u,&"counterShield");fx(u,&"counterShield",u.position)
## The armed sure critical (spent by the next attack).
static func sure_crit(source,options: Dictionary) -> bool:
	if not is_instance_valid(source) or source.state_value("counterCritUntil")<=_now(source) or options.get("collision",false):return false
	source.set_state("counterCritUntil",0.0);fx(source,&"counterShield",source.position,{"strike":true});return true
## 영겁의 갑주: one hit (not status damage) takes at most ETERNAL_CAP of max HP.
static func cap_hit(target,amount: float,status: bool) -> float:
	if status or not has(target,&"eternalArmor"):return amount
	var cap: float=ceilf(target.max_hp*ItemTuning.ETERNAL_CAP)
	if amount<=cap:return amount
	proc(target,&"eternalArmor");fx(target,&"eternalArmor",target.position,{"cut":amount-cap})
	return cap
## 그림자 인형: part of the damage goes to the nearest enemy (mitigated by its own defense only).
static func plan_share(target,hp_damage: float,source,kind: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary]=[]
	if hp_damage<=0 or not has(target,&"shadowDoll"):return out
	var near=doll_link(target)
	if near==null:return out
	var share: float=CombatRules.js_round(hp_damage*ItemTuning.DOLL_SHARE)
	if share>0:out.append({"unit":near,"damage":share,"source":target,"kind":kind,"doll":true})
	return out
static func doll_link(u):
	var near=null
	for e in u.enemies(false):
		if e.alive and not e.unavailable() and (near==null or e.position.distance_to(u.position)<near.position.distance_to(u.position)):near=e
	return near

## Healing about to land: 공허의 심장 turns it into attack (returns true: nothing heals).
static func void_heal(target,amount: float) -> bool:
	if amount<=0 or not has(target,&"voidHeart"):return false
	var before: float=void_bonus(target);target.set_state("voidHeal",target.state_value("voidHeal")+amount)
	if void_bonus(target)>before:proc(target,&"voidHeart")
	fx_trail(target,&"voidHeart");return true
## 생명의 성배: healing past full becomes a shield (up to CHALICE_SHIELD_CAP of the target's max HP).
static func overflow(target,extra: float,source) -> void:
	if extra<=.5 or not is_instance_valid(source) or not has(source,&"lifeChalice") or not target.alive:return
	var cap: float=target.max_hp*ItemTuning.CHALICE_SHIELD_CAP
	if target.shield_hp>=cap:return
	target.shield_hp=minf(cap,target.shield_hp+extra);target.shield_remaining=maxf(target.shield_remaining,ItemTuning.CHALICE_SHIELD_TIME)
	proc(source,&"lifeChalice");fx(source,&"lifeChalice",target.position,{"from":CharacterPersistence.point(source.position)})
## 표식 사냥꾼의 휘장: light / dark marks the bearer pops are twice as strong.
static func light_pop(u) -> float:
	if has(u,&"markBadge"):proc(u,&"markBadge");fx(u,&"markBadge",u.position,{"light":true});return ItemTuning.BADGE_LIGHT_HEAL
	return ElementEffects.LIGHT_POP_HEAL
static func dark_pop(u,at: Vector2) -> float:
	if has(u,&"markBadge"):proc(u,&"markBadge");fx(u,&"markBadge",at,{"light":false});return ItemTuning.BADGE_DARK_POP
	return ElementEffects.DARK_POP
## A unit starts an action: an attack ends 망각의 장막's cover.
static func on_action(u,attack: bool) -> void:
	if attack and has(u,&"oblivionVeil") and u.state_value("shadowTime")>0 and u.data.type_id!=3:u.set_state("shadowTime",0.0);u.hidden_from_enemies=false
## A projectile of a 천공의 활시위 bearer hit: it flies on (up to BOWSTRING_PIERCE times), stronger.
static func pierce(p) -> bool:
	if not has(p.source,&"skyBowstring") or p.kind in ["bomb","tankShell","frogBody","openingAwl"]:return false
	var done: int=int(p.metadata.get("pierced",0))
	if done>=ItemTuning.BOWSTRING_PIERCE:return false
	p.metadata["pierced"]=done+1;p.damage*=1+ItemTuning.BOWSTRING_STEP;p.power=p.damage
	if p.attack_instance!=null:p.attack_instance.damage=p.damage;p.attack_instance.power=p.power
	if done==0:proc(p.source,&"skyBowstring")
	return true
## 자석 나침반: projectiles near a bearer turn toward it. Enemy shots then hit the bearer; allied
## shots pass through it once, stronger.
static func _bend_projectiles(battle,dt: float) -> void:
	var bearers: Array=battle.units.filter(func(u):return u.alive and has(u,&"magnetCompass"))
	if bearers.is_empty():return
	for p in battle.projectiles:
		if not p.live or p.kind in ["bomb","tankShell","frogBody"] or p.velocity.length()<1:continue
		for b in bearers:
			var to: Vector2=b.position-p.position;var r: float=ItemTuning.COMPASS_RADIUS*b.combat_scale()
			if to.length()>r:continue
			var ally: bool=p.source.team==b.team
			if ally:
				if p.metadata.get("compassed",false):continue
				if to.length()<=30*b.combat_scale():
					p.metadata["compassed"]=true;p.damage*=1+ItemTuning.COMPASS_BOOST;p.power=p.damage
					if p.attack_instance!=null:p.attack_instance.damage=p.damage;p.attack_instance.power=p.power
					proc(b,&"magnetCompass");continue
			var turn: float=clampf(wrapf(to.angle()-p.velocity.angle(),-PI,PI),-ItemTuning.COMPASS_TURN*dt,ItemTuning.COMPASS_TURN*dt)
			p.velocity=p.velocity.rotated(turn)
			if p.attack_instance!=null:p.attack_instance.velocity=p.velocity
			p.metadata["bent"]=true
			break
## 탐욕의 주머니 gold the tower pays for one unit.
static func greed_gold(u) -> int:return int(u.state_value("greedGold")) if has(u,&"greedPouch") else 0
