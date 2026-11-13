class_name ItemEffects
extends RefCounted
## Battle effects of the items of 희귀 and up (0.94 → 0.96 아이템 재점검). Numbers live in
## ItemTuning; units without item stats (enemies, tests) are left alone. Item damage is never a
## direct hit: it goes through the resolver with a "status" (no parry, dodge or critical) and
## shows as a small coloured number.

static func _stats(u) -> UnitCombatStats:
	return u.combat_stats if is_instance_valid(u) and u.combat_stats!=null else null
## Whether the unit wears an item with this effect (its stats; a 거울 분신 has none).
static func has(u,effect: StringName) -> bool:
	var stats: UnitCombatStats=_stats(u);return stats!=null and stats.has(effect)
static func _now(u) -> float:return u.battle.clock.elapsed
static func _clone(u) -> bool:return u.character_specific_state.has("mirrorOf")
## A stats copy owned by this unit for this battle (the guild's stats never change).
static func _own(u) -> UnitCombatStats:
	if not u.has_meta("own_stats"):u.combat_stats=u.combat_stats.copy();u.set_meta("own_stats",true)
	return u.combat_stats
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
static func _allies(u) -> Array:return u.battle.units.filter(func(a):return a.alive and a.team==u.team and not a.unavailable())

# ---- Spawn and battle start ----
## Spawn: 행운의 주사위 rolls this battle's stat (seeded by the battle), 망원 렌즈 widens the reach.
static func on_spawn(u) -> void:
	var stats: UnitCombatStats=_stats(u)
	if stats==null:return
	if stats.has(&"gamblerDice"):
		stats=_own(u)
		var stat: String=ItemTuning.DICE_STATS[u.battle.rng.randi_range(0,ItemTuning.DICE_STATS.size()-1)]
		var roll: float=u.battle.rng.randf_range(ItemTuning.DICE_MIN,ItemTuning.DICE_MAX)
		stats.set(stat,float(stats.get(stat))*(1+roll))
		if stat=="max_hp":u.current_hp=stats.max_hp
		u.set_state("diceUp",stat);u.set_state("diceRoll",roll)
	if not is_equal_approx(stats.range_multiplier,1.0):
		var data: UnitData=u.data.duplicate(true);var k: float=stats.range_multiplier
		data.attack_range*=k;data.attack_profile.reach*=k;data.attack_profile.projectile_lifetime*=k;u.data=data
## Battle start (all units placed): items that act from the first second.
static func on_battle_start(battle) -> void:
	if not battle.full_characters_enabled:return
	for u in battle.units.duplicate():
		var stats: UnitCombatStats=_stats(u)
		if stats==null or stats.effects.is_empty() or not u.alive:continue
		if stats.has(&"firstStrikeRing"):u.set_state("firstStrike",1.0)
		if stats.has(&"guardFeather"):u.set_state("guardFeatherReady",1.0)
		if stats.has(&"oblivionVeil"):_cloak(u)
		if stats.has(&"rewindClock"):u.set_state("rewindReady",1.0);u.set_state("rewindPath",[_snap(u)])
		if stats.has(&"mangoSeed"):
			u.set_state("mangoClock",ItemTuning.MANGO_EVERY)
			for a in _allies(u):
				a.shield_hp+=a.max_hp*ItemTuning.MANGO_SHIELD;a.shield_remaining=maxf(a.shield_remaining,ItemTuning.MANGO_SHIELD_TIME)
			proc(u,&"mangoSeed");fx(u,&"mangoSeed",u.position,{"to":_allies(u).map(func(a):return CharacterPersistence.point(a.position)),"shield":true})
		if stats.has(&"invertedHourglass") and battle.turning==null:u.set_state("hourglassAt",ItemTuning.HOURGLASS_FIRST)
		if stats.has(&"starShard"):u.set_state("starClock",ItemTuning.STAR_EVERY)
		if stats.has(&"twinMirror"):_spawn_mirror(u)
		if stats.has(&"warDrum"):proc(u,&"warDrum");fx(u,&"warDrum",u.position)
## 쌍둥이의 거울: a copy at MIRROR_HP / MIRROR_DAMAGE with no item effects and no ultimate.
static func _spawn_mirror(u) -> void:
	var stats: UnitCombatStats=u.combat_stats.copy()
	stats.max_hp*=ItemTuning.MIRROR_HP;stats.physical_damage*=ItemTuning.MIRROR_DAMAGE;stats.magic_damage*=ItemTuning.MIRROR_DAMAGE
	stats.effects={};stats.items=[]
	for flag in ["duelist","vanguard","elementalist","enchant","chain_ring","sovereign","immovable","sanctuary"]:stats.set(flag,false)
	for count in ["vigor_totem_count","charge_totem_count","fang_count","opening_awl_count","phoenix_count","hourglass_count","dragon_heart_count","overcharge_count","victory_gold"]:stats.set(count,0)
	var side: Vector2=Vector2.from_angle(u.facing+PI*.5)*44*u.combat_scale()
	u.battle.queue_spawn(u,u.position+side,stats,{"mirrorOf":u.actor_id()},side*3)
	proc(u,&"twinMirror");fx(u,&"twinMirror",u.position+side)
## 암살자의 장막: hidden for VEIL_TIME.
static func _cloak(u) -> void:
	u.set_state("shadowTime",maxf(u.state_value("shadowTime"),ItemTuning.VEIL_TIME));u.set_state("veilHidden",1.0);u.hidden_from_enemies=true
	fx(u,&"oblivionVeil",u.position,{"cloak":true})

# ---- The damage pipeline ----
## The damage instance as this attacker really deals it: 마법 부여 검 adds the bearer's element to
## basic attacks.
static func adjust_spec(source,spec: Dictionary,target=null) -> Dictionary:
	var stats: UnitCombatStats=_stats(source)
	if stats==null or not stats.enchant or spec.get("skill",&"")!=&"basic":return spec
	var out: Dictionary=spec.duplicate();out.tags=Array(spec.get("tags",[])).duplicate()
	var element: StringName=CharacterCatalog.element(source.data.type_id)
	if element==&"":element=ItemTuning.ENCHANT_DEFAULT_ELEMENT
	if not element in out.tags:out.tags.append(element)
	if is_instance_valid(target):proc(source,&"enchantedBlade");fx(source,&"enchantedBlade",target.position,{"element":String(element)})
	return out
## Share of the target's defense the attack ignores: 관통의 송곳 always, 무한의 칼날 on criticals.
static func defense_pen(source,critical: bool) -> float:
	var stats: UnitCombatStats=_stats(source)
	if stats==null:return 0.0
	return ItemTuning.PIERCE_DEFENSE if stats.has(&"piercingAwl") or critical and stats.has(&"infinityEdge") else 0.0
## Damage the attacker deals.
static func outgoing(source,target,options: Dictionary,spec: Dictionary={}) -> float:
	var stats: UnitCombatStats=_stats(source)
	if stats==null or not is_instance_valid(target):return 1.0
	var factor: float=1.0
	var direct: bool=ElementEffects.direct(spec,options)
	var basic: bool=spec.get("skill",&"")==&"basic" and direct
	if stats.has(&"sniperScope") and source.position.distance_to(target.position)>=ItemTuning.SCOPE_DISTANCE:
		factor*=1+ItemTuning.SCOPE_DEALT;proc(source,&"sniperScope");fx(source,&"sniperScope",target.position)
	if stats.has(&"firstStrikeRing") and basic and source.state_value("firstStrike")>0:
		source.set_state("firstStrike",0.0);source.set_state("firstStrikeClock",ItemTuning.FIRST_STRIKE_EVERY)
		factor*=1+ItemTuning.FIRST_STRIKE;proc(source,&"firstStrikeRing");fx(source,&"firstStrikeRing",target.position)
	if stats.has(&"oblivionVeil") and direct and (source.state_value("veilStrike")>0 or source.state_value("veilHidden")>0 and source.state_value("shadowTime")>0):
		source.set_state("veilStrike",0.0);factor*=ItemTuning.VEIL_STRIKE;proc(source,&"oblivionVeil");fx(source,&"oblivionVeil",target.position)
	if stats.has(&"steelGreatsword") and basic and source.state_value("smashCount")>=ItemTuning.GREATSWORD_EVERY-1:
		source.set_state("smashCount",0.0);source.set_state("smashHit",1.0);factor*=ItemTuning.GREATSWORD_DEALT;proc(source,&"steelGreatsword")
	if stats.has(&"executionScythe") and elite(target) and target.current_hp<=target.max_hp*ItemTuning.SCYTHE_HP:factor*=1+ItemTuning.SCYTHE_ELITE
	# 흉내쟁이의 가면: the repeated ultimate hits at half.
	if source.state_value("mimicEcho")>0 and (spec.get("skill",&"")==&"ultimate" or source.battle.ultimate_actor==source):factor*=.5
	if stats.duelist:
		var stacks: int=int(source.state_value("duelStacks"))
		if str(source.character_specific_state.get("duelTarget",""))==target.actor_id():stacks=mini(stacks+1,roundi(ItemTuning.DUELIST_MAX/ItemTuning.DUELIST_STEP))
		else:stacks=0
		source.set_state("duelTarget",target.actor_id());source.set_state("duelStacks",stacks)
		factor*=1+stacks*ItemTuning.DUELIST_STEP
		if stacks>0:proc(source,&"duelistGlove");fx(source,&"duelistGlove",target.position,{"stacks":stacks})
	if stats.elementalist and elemental(target):factor*=ItemTuning.ELEMENTALIST_DEALT;proc(source,&"elementTome");fx(source,&"elementTome",target.position)
	return factor
static func elemental(u) -> bool:
	return u.state_value("burnStacks")>0 or u.state_value("poisonStacks")>0 or u.state_value("frostStacks")>0 or u.state_value("frozenTime")>0 or u.state_value("shockStacks")>0 or u.state_value("erosionTime")>0
static func elite(u) -> bool:
	var stats: UnitCombatStats=_stats(u);return stats!=null and stats.rank!=&"normal"
## Damage the target takes.
static func incoming(target,spec: Dictionary={}) -> float:
	var factor: float=1.0;var stats: UnitCombatStats=_stats(target)
	if stats!=null:
		if stats.vanguard and target.battle.clock.elapsed<ItemTuning.VANGUARD_TIME:factor*=ItemTuning.VANGUARD_TAKEN;proc(target,&"vanguardShield");fx(target,&"vanguardShield",target.position)
		# 광폭의 뿔: the 저돌적 damage-taken penalty does not apply.
		if stats.has(&"rageHorn") and target.stance==CombatStance.RUSH:factor/=StanceRules.RUSH_TAKEN
		if stats.has(&"swiftCloak") and spec.get("tags",[]).has(&"projectile"):factor*=ItemTuning.SWIFT_PROJECTILE_TAKEN
	if target.state_value("regenTime")>0:factor*=ItemTuning.REGEN_TAKEN
	if target.state_value("weakTime")>0:factor*=ItemTuning.WEAK_TAKEN
	if king_blessed(target):factor/=1+ItemTuning.KING_AURA
	for ally in target.battle.units:
		var lamp: UnitCombatStats=_stats(ally)
		if lamp!=null and lamp.sanctuary and ally.alive and ally.team==target.team and ally.position.distance_to(target.position)<=ItemTuning.SANCTUARY_RADIUS*ally.combat_scale():
			factor*=ItemTuning.SANCTUARY_TAKEN;proc(ally,&"sanctuaryLamp");fx(ally,&"sanctuaryLamp",target.position,{"from":CharacterPersistence.point(ally.position)});break
	return factor
## Attack % from items in battle: 군주의 검 stacks, 영혼 수확자, 왕의 왕관's aura.
static func attack_factor(u) -> float:
	var stacks: float=u.state_value("sovereignStacks") if u.state_value("sovereignTime")>0 else 0.0
	return (1+stacks*ItemTuning.SOVEREIGN_BUFF)*(1+u.state_value("soulStacks")*ItemTuning.SOUL_GROW)*(1+ItemTuning.KING_AURA if king_blessed(u) else 1.0)
## 탐욕의 황금손: attack % from the gold held.
static func greed_attack(gold: int) -> float:return minf(ItemTuning.GREED_MAX,floorf(float(gold)/ItemTuning.GREED_PER)*ItemTuning.GREED_STEP)
## Attack-speed factor: 광전사의 투구, 사냥꾼의 표창, 폭주 기관, 전쟁의 북, 왕의 왕관.
static func attack_speed(u) -> float:
	var k: float=1.0;var stats: UnitCombatStats=_stats(u)
	if stats!=null and not stats.effects.is_empty():
		if stats.has(&"berserkerHelm") and berserk(u):k*=1+ItemTuning.BERSERK_ATTACK_SPEED
		if stats.has(&"overdriveEngine"):k*=1+minf(ItemTuning.OVERDRIVE_MAX,floorf(u.state_value("overdrive"))*ItemTuning.OVERDRIVE_STEP)
	if u.state_value("hunterTime")>0:k*=1+ItemTuning.HUNTER_ATTACK_SPEED
	if drummed(u):k*=1+(ItemTuning.DRUM_OPENING if _now(u)<ItemTuning.DRUM_OPENING_TIME else ItemTuning.DRUM_SPEED)
	if king_blessed(u):k*=1+ItemTuning.KING_AURA
	return k
static func berserk(u) -> bool:return u.alive and u.current_hp<=u.max_hp*ItemTuning.BERSERK_HP
## Move-speed factor: 왕의 왕관's aura.
static func move_speed(u) -> float:return 1+ItemTuning.KING_AURA if king_blessed(u) else 1.0
## A living bearer of the effect on the unit's side (team auras; one bearer is enough).
static func _side_has(u,effect: StringName) -> bool:
	if u.battle==null:return false
	for a in u.battle.units:
		if a.alive and a.team==u.team and has(a,effect):return true
	return false
static func blood_blessed(u) -> bool:return _side_has(u,&"bloodChalice")
static func drummed(u) -> bool:return _side_has(u,&"warDrum")
static func king_blessed(u) -> bool:return _side_has(u,&"cursedCrown")
## 영겁의 갑주: one hit (not status or item damage) takes at most ETERNAL_CAP of max HP.
static func cap_hit(target,amount: float,status: bool) -> float:
	if status or not has(target,&"eternalArmor"):return amount
	var cap: float=ceilf(target.max_hp*ItemTuning.ETERNAL_CAP)
	if amount<=cap:return amount
	proc(target,&"eternalArmor");fx(target,&"eternalArmor",target.position,{"cut":amount-cap})
	return cap
## 수호의 사슬: a bearer whose nearest ally is the target takes GUARD_CHAIN_SHARE of the hit off it
## and takes only half of that itself ("cut" is what the target is spared).
static func plan_share(target,hp_damage: float,source,kind: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary]=[]
	if hp_damage<=0:return out
	for b in target.battle.units:
		if b==target or not b.alive or b.team!=target.team or not has(b,&"guardChain") or b.unavailable():continue
		if _nearest_ally(b)!=target:continue
		var cut: float=CombatRules.js_round(hp_damage*ItemTuning.GUARD_CHAIN_SHARE)
		if cut<=0:continue
		out.append({"unit":b,"damage":CombatRules.js_round(cut*ItemTuning.GUARD_CHAIN_CUT),"cut":cut,"source":source,"kind":kind,"chain":true})
		proc(b,&"guardChain");fx(b,&"guardChain",b.position,{"to":CharacterPersistence.point(target.position)})
		break
	return out
static func _nearest_ally(u):
	var near=null
	for a in u.battle.units:
		if a==u or not a.alive or a.team!=u.team or _clone(a):continue
		if near==null or a.position.distance_to(u.position)<near.position.distance_to(u.position):near=a
	return near
## 반격의 방패: a parry or dodge arms a sure critical hit.
static func on_defended(u) -> void:
	if not is_instance_valid(u) or not u.alive or not has(u,&"counterShield"):return
	u.set_state("counterCritUntil",_now(u)+ItemTuning.COUNTER_SHIELD_TIME);proc(u,&"counterShield");fx(u,&"counterShield",u.position)
static func sure_crit(source,options: Dictionary) -> bool:
	if not is_instance_valid(source) or source.state_value("counterCritUntil")<=_now(source) or options.get("collision",false):return false
	source.set_state("counterCritUntil",0.0);fx(source,&"counterShield",source.position,{"strike":true});return true

## A hit landed (on HP or shield).
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
	proc(source,&"chainRing");fx(source,&"chainRing",target.position,{"to":[CharacterPersistence.point(best.position)]})
	source.battle.damage_resolver.resolve(source,best,out.resolved_damage,{"dmg":&"chain_ring","plain":true,"status":&"chain_ring","chain_ring":true,"critical":false,"impulse":0,"attack_origin":target.position})
## `source` (with items) hit an enemy `target`.
static func _struck(source,target,out: DamageOutcome,spec: Dictionary,options: Dictionary) -> void:
	var stats: UnitCombatStats=_stats(source);var dealt: float=out.hp_damage+out.shield_absorbed
	var direct: bool=ElementEffects.direct(spec,options) and out.status==&""
	if direct and source.alive and dealt>0:
		var leech: float=0
		if stats!=null and stats.has(&"vampireFang"):leech+=ItemTuning.VAMPIRE_LEECH
		var blood: bool=blood_blessed(source)
		if blood:leech+=ItemTuning.BLOOD_LEECH_SELF if has(source,&"bloodChalice") else ItemTuning.BLOOD_LEECH
		if leech>0 and CharacterAbility.restore_hp(source,dealt*leech,source)>0:
			fx(source,&"bloodChalice" if blood else &"vampireFang",target.position,{"to":CharacterPersistence.point(source.position)})
	if stats==null or stats.effects.is_empty():return
	if direct and stats.has(&"weakEye") and target.alive:
		if target.state_value("weakTime")<=0:fx(source,&"weakEye",target.position)
		target.set_state("weakTime",ItemTuning.WEAK_TIME)
	if direct and spec.get("skill",&"")==&"basic":
		if stats.has(&"steelGreatsword"):
			if source.state_value("smashHit")>0:
				source.set_state("smashHit",0.0);fx(source,&"steelGreatsword",target.position)
				if target.alive:KnockbackController.apply(target,(target.position-source.position).normalized()*ItemTuning.GREATSWORD_PUSH,source)
			else:source.set_state("smashCount",source.state_value("smashCount")+1)
		if stats.has(&"poisonDagger") and target.alive and source.battle.rng.randf()<ItemTuning.POISON_DAGGER_CHANCE:
			target.set_state("poisonStacks",target.state_value("poisonStacks")+1);target.set_state("poisonSource",source.actor_id())
			proc(source,&"poisonDagger");fx(source,&"poisonDagger",target.position)
	if direct and stats.has(&"echoStaff") and StringName(spec.get("kind",&"physical"))==&"magic" and dealt>0 and source.battle.rng.randf()<ItemTuning.ECHO_CHANCE:
		var echoes: Array=target.character_specific_state.get("echoes",[])
		echoes.append({"t":ItemTuning.ECHO_DELAY,"by":source.actor_id(),"amount":dealt*ItemTuning.ECHO_SHARE,"from":CharacterPersistence.point(source.position)})
		target.set_state("echoes",echoes);proc(source,&"echoStaff")
	# 처형의 낫: an attack on an enemy (not elite or boss) at SCYTHE_HP or less finishes it.
	if direct and stats.has(&"executionScythe") and target.alive and not elite(target) and target.current_hp+out.hp_damage<=target.max_hp*ItemTuning.SCYTHE_HP:
		fx(source,&"executionScythe",target.position);proc(source,&"executionScythe")
		_hit(source,target,&"execution",&"item_execute",target.current_hp+target.shield_hp,{"fixed":true})
	if not out.critical:return
	if stats.has(&"infinityEdge"):fx(source,&"infinityEdge",target.position)
	if stats.has(&"bleedBlade") and dealt>0 and target.alive:bleed(source,target,dealt);proc(source,&"bleedBlade");fx(source,&"bleedBlade",target.position)
## `target` (with items) was hit by an enemy `source`.
static func _was_struck(target,source,out: DamageOutcome,spec: Dictionary,options: Dictionary) -> void:
	var stats: UnitCombatStats=_stats(target)
	if stats==null or stats.effects.is_empty() or not target.alive:return
	var taken: float=out.hp_damage+out.shield_absorbed
	var direct: bool=ElementEffects.direct(spec,options) and out.status==&""
	if stats.has(&"thornArmor") and direct and spec.get("tags",[]).has(&"melee") and taken>0 and source.alive:
		_hit(target,source,&"thorn_armor",&"item_thorns",taken*ItemTuning.THORN_REFLECT,{"plain":true});proc(target,&"thornArmor");fx(target,&"thornArmor",target.position,{"to":CharacterPersistence.point(source.position)})
	# 저주 인형: every hit (but a reflection) sends a share back to its attacker.
	if stats.has(&"shadowDoll") and taken>0 and source.alive and not out.status in [&"item_thorns",&"item_doll"]:
		_hit(target,source,&"cursed_doll",&"item_doll",taken*ItemTuning.DOLL_REFLECT,{"plain":true});proc(target,&"shadowDoll")
		fx(target,&"shadowDoll",source.position,{"from":CharacterPersistence.point(target.position)})
	if stats.has(&"guardFeather") and target.state_value("guardFeatherReady")>0 and target.current_hp<target.max_hp*ItemTuning.GUARD_FEATHER_HP:
		target.set_state("guardFeatherReady",0.0)
		target.shield_hp+=target.max_hp*ItemTuning.GUARD_FEATHER_SHIELD;target.shield_remaining=maxf(target.shield_remaining,ItemTuning.GUARD_FEATHER_TIME)
		proc(target,&"guardFeather");fx(target,&"guardFeather",target.position)

## 출혈: every BLEED_EVERY a tick of physical damage over time.
static func bleed(source,target,dealt: float) -> void:
	var per: float=dealt*ItemTuning.BLEED_SHARE/(ItemTuning.BLEED_TIME/ItemTuning.BLEED_EVERY)
	if per<=0:return
	var old: float=target.state_value("bleedPer") if target.state_value("bleedTime")>0 else 0.0
	if target.state_value("bleedTime")<=0:target.set_state("bleedTick",ItemTuning.BLEED_EVERY)
	target.set_state("bleedTime",ItemTuning.BLEED_TIME);target.set_state("bleedPer",maxf(per,old));target.set_state("bleedSource",source.actor_id())

# ---- Ultimates, kills, deaths ----
static func after_ultimate(u) -> void:
	var stats: UnitCombatStats=_stats(u)
	if stats!=null and stats.overcharge_count>0:
		u.ultimate_gauge=clampf(u.ultimate_gauge+ItemTuning.OVERCHARGE_REFUND*stats.overcharge_count,0,100);proc(u,&"overchargeCore");fx(u,&"overchargeCore",u.position)
	if stats!=null and stats.hourglass_count>0:proc(u,&"hourglass");fx(u,&"hourglass",u.position)
	if stats==null or not u.alive:return
	if stats.has(&"stormCrown"):
		var radius: float=ItemTuning.STORM_RADIUS*u.combat_scale();var struck: Array=[]
		for e in u.enemies(false):
			if not e.alive or e.unavailable() or e.position.distance_to(u.position)>radius:continue
			struck.append(CharacterPersistence.point(e.position))
			_hit(u,e,&"storm_crown",&"item_storm",UnitStatTable.raw(u,&"storm_crown"))
			if e.alive:ElementEffects.add_shock(e,ItemTuning.STORM_SHOCK)
		proc(u,&"stormCrown");fx(u,&"stormCrown",u.position,{"to":struck,"radius":radius})
	if stats.has(&"lifeResonance"):
		var radius: float=ItemTuning.RESONANCE_RADIUS*u.combat_scale();var healed: Array=[]
		for a in _allies(u):
			if a.position.distance_to(u.position)>radius:continue
			CharacterAbility.restore_hp(a,a.max_hp*ItemTuning.RESONANCE_HEAL,u);a.set_state("regenTime",ItemTuning.REGEN_TIME);healed.append(CharacterPersistence.point(a.position))
		proc(u,&"lifeResonance");fx(u,&"lifeResonance",u.position,{"radius":radius,"to":healed})
	# 흉내쟁이의 가면: the same ultimate once more at half (not the echo itself).
	if stats.has(&"mimicMask"):
		if u.state_value("mimicEcho")>0:u.set_state("mimicEcho",0.0)
		else:
			var keep: float=u.ultimate_gauge;u.ultimate_gauge=100;u.set_state("mimicEcho",1.0)
			if u.ultimate.request(u,u.ability.ultimate_target(u)):proc(u,&"mimicMask");fx(u,&"mimicMask",u.position)
			else:u.set_state("mimicEcho",0.0)
			u.ultimate_gauge=keep
## A turning point opened (tower battles): every 끝없는 모래시계 fills its bearer's gauge.
static func on_turning_point(battle) -> void:
	for u in battle.units:
		if u.alive and has(u,&"invertedHourglass"):_fill_gauge(u)
static func _fill_gauge(u) -> void:
	u.ultimate_gauge=100;proc(u,&"invertedHourglass");fx(u,&"invertedHourglass",u.position)
static func on_kill(source,victim=null) -> void:
	var stats: UnitCombatStats=_stats(source)
	if stats!=null and source.alive:
		if stats.has(&"hunterShuriken"):source.set_state("hunterTime",ItemTuning.HUNTER_TIME);proc(source,&"hunterShuriken");fx(source,&"hunterShuriken",source.position)
		if stats.has(&"rageHorn"):CharacterAbility.restore_hp(source,source.max_hp*ItemTuning.HORN_HEAL,source);proc(source,&"rageHorn");fx(source,&"rageHorn",source.position)
		if stats.has(&"oblivionVeil"):_cloak(source);proc(source,&"oblivionVeil")
		if stats.has(&"greedPouch"):source.set_state("greedGold",source.state_value("greedGold")+ItemTuning.GREED_KILL_GOLD);proc(source,&"greedPouch");fx(source,&"greedPouch",victim.position if victim!=null else source.position)
		if stats.has(&"elementStone") and victim!=null:_element_burst(source,victim)
	if stats==null or not stats.sovereign:return
	proc(source,&"sovereignSword");fx(source,&"sovereignSword",source.position,{"radius":ItemTuning.SOVEREIGN_RADIUS*source.combat_scale()})
	source.battle.emit_combat_event(&"sovereign_roar",source.position,{"actor_id":source.battle_id,"radius":ItemTuning.SOVEREIGN_RADIUS*source.combat_scale()})
	for ally in source.battle.units:
		if not ally.alive or ally.team!=source.team or ally.position.distance_to(source.position)>ItemTuning.SOVEREIGN_RADIUS*source.combat_scale():continue
		var stacks: float=ally.state_value("sovereignStacks") if ally.state_value("sovereignTime")>0 else 0.0
		ally.set_state("sovereignStacks",minf(ItemTuning.SOVEREIGN_STACKS,stacks+1));ally.set_state("sovereignTime",ItemTuning.SOVEREIGN_TIME)
## 원소 폭발석: a kill on a unit with burn / poison / frost / shock bursts around it and passes
## STONE_STACKS of each of those elements on.
static func _element_burst(source,victim) -> void:
	var kinds: Array=[]
	for pair in [["burnStacks","fire"],["poisonStacks","poison"],["frostStacks","ice"],["frozenTime","ice"],["shockStacks","lightning"]]:
		if victim.state_value(pair[0])>0 and not pair[1] in kinds:kinds.append(pair[1])
	if kinds.is_empty():return
	var radius: float=ItemTuning.STONE_RADIUS*source.combat_scale();var to: Array=[]
	for e in source.enemies(false):
		if e==victim or not e.alive or e.unavailable() or e.position.distance_to(victim.position)>radius:continue
		to.append(CharacterPersistence.point(e.position))
		_hit(source,e,&"element_stone",&"item_burst",UnitStatTable.raw(source,&"element_stone"))
		if not e.alive:continue
		for k in kinds:
			match k:
				"fire":ElementEffects.add_burn(source,e,ItemTuning.STONE_STACKS)
				"poison":e.set_state("poisonStacks",e.state_value("poisonStacks")+ItemTuning.STONE_STACKS);e.set_state("poisonSource",source.actor_id())
				"ice":ElementEffects.add_frost(source,e,ItemTuning.STONE_STACKS)
				"lightning":ElementEffects.add_shock(e,ItemTuning.STONE_STACKS)
	proc(source,&"elementStone");fx(source,&"elementStone",victim.position,{"radius":radius,"to":to,"element":kinds[0]})
## Anyone fell: 영혼 수확자 bearers heal and grow (a fallen 거울 분신 counts too).
static func on_death(victim) -> void:
	if victim.battle==null or not victim.battle.full_characters_enabled:return
	for u in victim.battle.units:
		if u==victim or not u.alive or not has(u,&"soulReaper"):continue
		var stats: UnitCombatStats=_own(u)
		var stacks: float=u.state_value("soulStacks")+1;u.set_state("soulStacks",stacks)
		if not u.character_specific_state.has("soulBaseHp"):u.set_state("soulBaseHp",stats.max_hp)
		var grown: float=u.state_value("soulBaseHp")*(1+stacks*ItemTuning.SOUL_GROW);var gain: float=grown-stats.max_hp
		stats.max_hp=grown;u.current_hp=minf(stats.max_hp,u.current_hp+maxf(0,gain))
		CharacterAbility.restore_hp(u,u.max_hp*ItemTuning.SOUL_HEAL,u)
		proc(u,&"soulReaper");fx(u,&"soulReaper",victim.position,{"to":CharacterPersistence.point(u.position)})
## 시간술사의 시계: a lethal blow sends the bearer back to its HP and place REWIND_BACK s ago (once).
static func rewind_lethal(u) -> bool:
	if u.state_value("rewindReady")<=0 or not has(u,&"rewindClock"):return false
	u.set_state("rewindReady",0.0)
	var path: Array=u.character_specific_state.get("rewindPath",[]);var back: Dictionary=path[0] if not path.is_empty() else _snap(u)
	for p in path:
		if float(p.t)<=_now(u)-ItemTuning.REWIND_BACK:back=p
	var trail: Array=path.filter(func(p):return float(p.t)>=float(back.t)).map(func(p):return {"x":p.x,"y":p.y})
	fx(u,&"rewindClock",Vector2(float(back.x),float(back.y)),{"path":trail})
	u.current_hp=clampf(float(back.hp),1,u.max_hp);u.position=MovementController.clamp_position(Vector2(float(back.x),float(back.y)))
	u.velocity=Vector2.ZERO;u.knockback_velocity=Vector2.ZERO;u.combat.cancel(u);u.invincible_remaining=maxf(u.invincible_remaining,.3)
	u.character_specific_state.erase("rewindPath");proc(u,&"rewindClock")
	return true
static func _snap(u) -> Dictionary:return {"t":_now(u),"hp":u.current_hp,"x":u.position.x,"y":u.position.y}
static func immovable(u) -> bool:
	var stats: UnitCombatStats=_stats(u);return stats!=null and stats.immovable

# ---- Healing ----
## 생명의 성배: healing past full becomes a shield (up to CHALICE_SHIELD_CAP of the target's max HP).
static func overflow(target,extra: float,source) -> void:
	if extra<=.5 or not is_instance_valid(source) or not has(source,&"lifeChalice") or not target.alive:return
	var cap: float=target.max_hp*ItemTuning.CHALICE_SHIELD_CAP
	if target.shield_hp>=cap:return
	target.shield_hp=minf(cap,target.shield_hp+extra);target.shield_remaining=maxf(target.shield_remaining,ItemTuning.CHALICE_SHIELD_TIME)
	proc(source,&"lifeChalice");fx(source,&"lifeChalice",target.position,{"from":CharacterPersistence.point(source.position)})

# ---- Actions and projectiles ----
## A unit starts an action: an attack ends 암살자의 장막's cover (that attack still hits x2).
static func on_action(u,attack: bool) -> void:
	if attack and has(u,&"oblivionVeil") and u.state_value("veilHidden")>0 and u.state_value("shadowTime")>0:
		u.set_state("veilStrike",1.0);u.set_state("veilHidden",0.0)
		if u.data.type_id!=3:u.set_state("shadowTime",0.0);u.hidden_from_enemies=false
## A projectile of a 천공의 활시위 bearer hit: it flies on (up to BOWSTRING_PIERCE times), stronger.
static func pierce(p) -> bool:
	if not has(p.source,&"skyBowstring") or p.kind in ["bomb","tankShell","frogBody","openingAwl"]:return false
	var done: int=int(p.metadata.get("pierced",0))
	if done>=ItemTuning.BOWSTRING_PIERCE:return false
	p.metadata["pierced"]=done+1;p.damage*=1+ItemTuning.BOWSTRING_STEP;p.power=p.damage
	if p.attack_instance!=null:p.attack_instance.damage=p.damage;p.attack_instance.power=p.power
	if done==0:proc(p.source,&"skyBowstring")
	return true
## 탐욕의 황금손 gold the tower pays for one unit.
static func greed_gold(u) -> int:return int(u.state_value("greedGold")) if has(u,&"greedPouch") else 0
## 지휘관의 홀: the member does not count toward the sortie limit.
static func sortie_free(stats: UnitCombatStats) -> bool:return stats!=null and stats.has(&"commanderScepter")

# ---- Every tick ----
static func advance(battle,dt: float) -> void:
	if not battle.full_characters_enabled:return
	for u in battle.units.duplicate():
		if not u.alive:continue
		if u.state_value("bleedTime")>0:_bleed(u,dt)
		if u.character_specific_state.has("echoes"):_echoes(u,dt)
		for key in ["hunterTime","regenTime","weakTime"]:
			if u.state_value(key)>0:u.set_state(key,maxf(0,u.state_value(key)-dt))
		if _clone(u) and not u.has_meta("mirror_shown"):u.set_meta("mirror_shown",true);u.modulate=Color(.85,.92,1,.72);u.ultimate_gauge=0;u.transcendence_gauge=0
		var stats: UnitCombatStats=_stats(u)
		if stats==null or stats.effects.is_empty() or not u.alive:continue
		if stats.has(&"oblivionVeil") and u.data.type_id!=3:
			u.hidden_from_enemies=u.state_value("shadowTime")>0
			if u.state_value("shadowTime")<=0:u.set_state("veilHidden",0.0)
		if stats.has(&"firstStrikeRing") and u.state_value("firstStrike")<=0:
			u.set_state("firstStrikeClock",u.state_value("firstStrikeClock")-dt)
			if u.state_value("firstStrikeClock")<=0:u.set_state("firstStrike",1.0)
		if stats.has(&"elderHeart"):
			u.set_state("elderClock",u.state_value("elderClock")+dt)
			if u.state_value("elderClock")>=1:
				u.set_state("elderClock",u.state_value("elderClock")-1)
				if CharacterAbility.restore_hp(u,u.max_hp*ItemTuning.ELDER_REGEN,u)>0:fx(u,&"elderHeart",u.position,{"heal":true})
		if stats.has(&"mangoSeed"):
			u.set_state("mangoClock",u.state_value("mangoClock")-dt)
			if u.state_value("mangoClock")<=0:
				u.set_state("mangoClock",ItemTuning.MANGO_EVERY);var healed: Array=[]
				for a in _allies(u):CharacterAbility.restore_hp(a,a.max_hp*ItemTuning.MANGO_HEAL,u);healed.append(CharacterPersistence.point(a.position))
				proc(u,&"mangoSeed");fx(u,&"mangoSeed",u.position,{"to":healed})
		if stats.has(&"rewindClock") and u.state_value("rewindReady")>0:_record(u)
		if stats.has(&"invertedHourglass") and u.character_specific_state.has("hourglassAt") and _now(u)>=u.state_value("hourglassAt"):
			u.set_state("hourglassAt",u.state_value("hourglassAt")+ItemTuning.HOURGLASS_EVERY);_fill_gauge(u)
		if stats.has(&"overdriveEngine"):u.set_state("overdrive",u.state_value("overdrive")+dt)
		if stats.has(&"starShard"):
			u.set_state("starClock",u.state_value("starClock")-dt)
			if u.state_value("starClock")<=0:u.set_state("starClock",ItemTuning.STAR_EVERY);_meteors(u)
## 시간술사의 시계: the last REWIND_BACK s of HP and position, sampled four times a second.
static func _record(u) -> void:
	var path: Array=u.character_specific_state.get("rewindPath",[])
	if not path.is_empty() and _now(u)-float(path[-1].t)<.25:return
	path.append(_snap(u))
	while path.size()>2 and float(path[1].t)<=_now(u)-ItemTuning.REWIND_BACK:path.remove_at(0)
	u.set_state("rewindPath",path)
## 별의 파편: meteors on up to STAR_TARGETS random enemies, each an area hit.
static func _meteors(u) -> void:
	var foes: Array=u.enemies(false).filter(func(e):return e.alive and not e.unavailable())
	if foes.is_empty():return
	var points: Array=[]
	for i in range(mini(ItemTuning.STAR_TARGETS,foes.size())):
		var e=foes.pop_at(u.battle.rng.randi_range(0,foes.size()-1));points.append(e.position)
	var radius: float=ItemTuning.STAR_RADIUS*u.combat_scale()
	for at in points:
		for e in u.enemies(false):
			if e.alive and not e.unavailable() and e.position.distance_to(at)<=radius+24*e.combat_scale():_hit(u,e,&"star_shard",&"item_star",UnitStatTable.raw(u,&"star_shard"))
	proc(u,&"starShard");fx(u,&"starShard",u.position,{"to":points.map(func(p):return CharacterPersistence.point(p)),"radius":radius})
static func _bleed(u,dt: float) -> void:
	u.set_state("bleedTime",maxf(0,u.state_value("bleedTime")-dt));u.set_state("bleedTick",u.state_value("bleedTick")-dt)
	if u.state_value("bleedTick")<=0:
		u.set_state("bleedTick",u.state_value("bleedTick")+ItemTuning.BLEED_EVERY)
		var by=u.battle.find_actor(str(u.character_specific_state.get("bleedSource","")))
		if by!=null:_hit(by,u,&"bleed",&"bleed",u.state_value("bleedPer")*(1+UnitStatTable.tag_bonus(_stats(by),[&"dot"])),{"fixed":true})
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
