class_name BuildItems
extends RefCounted
## Battle effects of the 0.97 빌드 지원 아이템 (ItemEffects calls in here; numbers in ItemTuning).
## Item damage goes through the resolver as a status hit, like the 0.95 items.

static func has(u,effect: StringName) -> bool:return ItemEffects.has(u,effect)
static func _now(u) -> float:return u.battle.clock.elapsed
static func _p(v: Vector2) -> Dictionary:return CharacterPersistence.point(v)
static func _foes(u) -> Array:return u.enemies(false).filter(func(e):return e.alive and not e.unavailable())
static func _hit(source,target,key: StringName,status: StringName,amount: float,extra: Dictionary={}) -> DamageOutcome:
	return ItemEffects._hit(source,target,key,status,amount,extra)
## A one-per-attack count: several pellets or hits of one attack count once.
static func _count(u,key: String) -> int:
	var at: String=key+"At"
	if _now(u)-u.state_value(at)<.12 and u.character_specific_state.has(at):return 0
	u.set_state(at,_now(u));var n: int=int(u.state_value(key))+1;u.set_state(key,n);return n
static func _element(u) -> StringName:
	var e: StringName=CharacterCatalog.element(u.data.type_id)
	return e if e!=&"" else ItemTuning.ENCHANT_DEFAULT_ELEMENT
## An element landing from an item hit (status hits do not add stacks by themselves).
static func apply_element(source,target,element: StringName) -> void:
	if not target.alive:return
	match element:
		&"fire":ElementEffects.add_burn(source,target,ElementEffects.BURN_STACKS)
		&"poison":target.set_state("poisonStacks",target.state_value("poisonStacks")+1);target.set_state("poisonSource",source.actor_id())
		&"ice":ElementEffects.add_frost(source,target,1)
		&"lightning":ElementEffects.add_shock(target,1)
		&"wind":target.set_state("headwindTime",ElementEffects.HEADWIND_TIME)
		&"dark":target.set_state("erosionTime",erosion_time(source));target.set_state("erosionSource",source.actor_id())
		&"light":
			for a in ItemEffects._allies(source):
				if a.position.distance_to(source.position)<=ElementEffects.LIGHT_RADIUS:CharacterAbility.restore_hp(a,a.max_hp*.02,source)
## Whether the battle is a miniboss or chapter boss room (custom: an elite or boss on the field).
static func boss_room(battle) -> bool:
	if battle.has_meta("room_type"):return StringName(battle.get_meta("room_type")) in [RoomType.MINIBOSS,RoomType.BOSS]
	return battle.units.any(func(e):return ItemEffects.elite(e))
static func spirit(u) -> bool:return u.character_specific_state.has("spiritOf")

# ---- Battle start ----
static func on_battle_start(battle,u,stats: UnitCombatStats) -> void:
	var allies: int=battle.units.filter(func(a):return a.team==u.team and a.alive and not ItemEffects._clone(a)).size()
	var k: float=1.0
	if stats.has(&"heroBadge") and boss_room(battle):k*=1+ItemTuning.HERO_STATS;ItemEffects.proc(u,&"heroBadge");ItemEffects.fx(u,&"heroBadge",u.position)
	if stats.has(&"lonelyKingSword"):
		var limit: int=int(battle.get_meta("sortie_limit",GrowthRules.SORTIE_BASE))
		var empty: int=maxi(0,limit-allies)
		u.set_state("lonelyEmpty",float(empty))
		if empty>0:k*=1+ItemTuning.LONELY_STEP*empty;ItemEffects.proc(u,&"lonelyKingSword");ItemEffects.fx(u,&"lonelyKingSword",u.position,{"count":empty})
	if stats.has(&"pactSeal") and u.source_member_id in Array(battle.get_meta("pact_off",[])):
		k*=(1+stats.all_stats-ItemTuning.PACT_STATS*int(stats.effects.get(&"pactSeal",1)))/(1+stats.all_stats);u.set_state("pactOff",1.0);ItemEffects.fx(u,&"pactSeal",u.position,{"off":true})
	elif stats.has(&"pactSeal"):ItemEffects.proc(u,&"pactSeal");ItemEffects.fx(u,&"pactSeal",u.position)
	if not is_equal_approx(k,1.0):
		var own: UnitCombatStats=ItemEffects._own(u);var ratio: float=u.current_hp/maxf(1,own.max_hp)
		# The guild's max HP is the cap the tower keeps after the battle.
		if not u.has_meta("hp_cap"):u.set_meta("hp_cap",own.max_hp)
		own.scale_all(k);u.current_hp=clampf(own.max_hp*ratio,1,own.max_hp)
	if stats.has(&"chargeHorn"):
		var near=CharacterAbility.nearest(u,_foes(u))
		if near!=null:u.set_state("hornDash",.9);u.set_state("hornTarget",near.actor_id());u.set_state("hornStun",1.0);ItemEffects.proc(u,&"chargeHorn");ItemEffects.fx(u,&"chargeHorn",u.position,{"to":_p(near.position)})
	if stats.has(&"knightCrest"):u.set_state("crestClock",1.5)
	if stats.has(&"spiritLantern"):u.set_state("spiritClock",ItemTuning.SPIRIT_EVERY)
	if stats.has(&"legionBanner"):
		u.set_state("bannerX",u.position.x);u.set_state("bannerY",u.position.y)
		ItemEffects.proc(u,&"legionBanner");ItemEffects.fx(u,&"legionBanner",u.position,{"plant":true,"radius":ItemTuning.BANNER_RADIUS})
	if stats.has(&"dragonEgg"):
		u.set_state("dragonClock",1.5);u.set_state("dragonStage",float(dragon_stage(stats)))
		ItemEffects.fx(u,&"dragonEgg",u.position,{"hatch":true,"stage":dragon_stage(stats)})
	if stats.has(&"thiefWatch"):u.set_state("watchClock",ItemTuning.WATCH_EVERY)
	if stats.has(&"blackHoleOrb"):u.set_state("holeClock",ItemTuning.BLACKHOLE_EVERY*.6)
	if stats.has(&"beastHide"):u.set_state("beastReady",1.0)
	if stats.has(&"giantRing"):ItemEffects.fx(u,&"giantRing",u.position)
static func dragon_stage(stats: UnitCombatStats) -> int:return clampi(1+int(stats.growth.get(&"dragonEgg",0)),1,ItemTuning.DRAGON_STAGES)

# ---- Damage factors ----
static func outgoing(source,target,stats: UnitCombatStats,direct: bool) -> float:
	var f: float=1.0
	if stats.has(&"fangNecklace") and target.state_value("poisonStacks")>=ItemTuning.FANG_POISON_STACKS:f*=1+ItemTuning.FANG_DEALT;_mark(source,&"fangNecklace",target)
	if stats.has(&"frostOrb") and (target.state_value("frozenTime")>0 or target.state_value("frostbiteTime")>0):f*=1+ItemTuning.FROST_ORB_DEALT;_mark(source,&"frostOrb",target)
	if stats.has(&"shieldHammer") and source.shield_hp>0 and source.shield_remaining>0:f*=1+ItemTuning.SHIELD_HAMMER_ATTACK;_mark(source,&"shieldHammer",target)
	if stats.has(&"heroBadge") and ItemEffects.elite(target) and boss_room(source.battle):f*=1+ItemTuning.HERO_ELITE_DEALT;_mark(source,&"heroBadge",target)
	return f
## The item icon and a small mark on the target, at most every PROC_ICON_GAP.
static func _mark(u,item: StringName,target) -> void:
	var key: String="mark_"+String(item)
	if _now(u)-float(u.character_specific_state.get(key,-99.0))<ItemTuning.PROC_ICON_GAP:return
	u.character_specific_state[key]=_now(u);ItemEffects.proc(u,item);ItemEffects.fx(u,item,target.position)
static func incoming(target) -> float:
	var f: float=1.0
	if target.state_value("frozenTime")>0 and target.state_value("deepFreeze")>0:f*=ItemTuning.PERMAFROST_TAKEN
	if bannered(target):f*=ItemTuning.BANNER_TAKEN
	return f
## Attack % in battle: 복수의 가면, 군단장의 깃발.
static func attack_factor(u) -> float:
	var f: float=1+u.state_value("vengeance")*ItemTuning.VENGEANCE_STEP
	if bannered(u):f*=1+ItemTuning.BANNER_ATTACK
	return f
static func attack_speed(u) -> float:
	var f: float=1+u.state_value("vengeance")*ItemTuning.VENGEANCE_STEP
	if u.state_value("capeTime")>0:f*=1+u.state_value("capeStacks")*ItemTuning.CAPE_ATTACK_SPEED
	if u.state_value("beastTime")>0:f*=1+ItemTuning.BEAST_BOOST
	return f
static func move_speed(u) -> float:
	var f: float=1.0
	if has(u,&"stormWings"):f*=1+u.state_value("windStacks")*ItemTuning.WINGS_MOVE
	if u.state_value("beastTime")>0:f*=1+ItemTuning.BEAST_BOOST
	return f
## Within reach of a living 군단장의 깃발 bearer's flag of its side.
static func bannered(u) -> bool:
	if u.battle==null:return false
	for a in u.battle.units:
		if a.alive and a.team==u.team and a.character_specific_state.has("bannerX") and has(a,&"legionBanner"):
			if u.position.distance_to(Vector2(a.state_value("bannerX"),a.state_value("bannerY")))<=ItemTuning.BANNER_RADIUS:return true
	return false
## 심연의 낫: an eroded target is always struck critically.
static func sure_crit(source,target) -> bool:
	return is_instance_valid(target) and target.state_value("erosionTime")>0 and has(source,&"abyssScythe")
## Added tags for an attack: 일곱 빛깔 왕관석 turns its seven elements over the bearer's attacks.
static func extra_tags(source,spec: Dictionary) -> Array:
	if not has(source,&"rainbowStone") or not spec.get("skill",&"") in [&"basic",&"ultimate"]:return []
	return [ItemTuning.RAINBOW_ORDER[int(source.state_value("rainbowIndex"))%ItemTuning.RAINBOW_ORDER.size()]]
static func erosion_time(source) -> float:
	return ItemTuning.CLAW_EROSION_TIME if is_instance_valid(source) and has(source,&"shadowClaw") else ElementEffects.EROSION_TIME

# ---- Hits ----
## `source` (with items) struck an enemy.
static func struck(source,target,out: DamageOutcome,spec: Dictionary,options: Dictionary,stats: UnitCombatStats,direct: bool) -> void:
	var dealt: float=out.hp_damage+out.shield_absorbed
	var basic: bool=direct and spec.get("skill",&"")==&"basic"
	if stats.has(&"dawnSword") and dealt>0:_dawn(source,dealt)
	if direct and source.state_value("beastTime")>0 and dealt>0 and CharacterAbility.restore_hp(source,dealt*ItemTuning.BEAST_LEECH,source)>0:_mark(source,&"beastHide",source)
	if direct and stats.has(&"rainbowStone"):
		var element: StringName=ItemTuning.RAINBOW_ORDER[int(source.state_value("rainbowIndex"))%ItemTuning.RAINBOW_ORDER.size()]
		if _count(source,"rainbowHits")>0:source.set_state("rainbowIndex",source.state_value("rainbowIndex")+1)
		ItemEffects.fx(source,&"rainbowStone",target.position,{"element":String(element)})
	if direct and source.state_value("hornStun")>0 and target.alive:
		source.set_state("hornStun",0.0);StatusController.stun(target,ItemTuning.HORN_STUN);ItemEffects.proc(source,&"chargeHorn");ItemEffects.fx(source,&"chargeHorn",target.position,{"stun":true})
	if direct and spec.get("tags",[]).has(&"explosion") and stats.has(&"powderKeg") and target.alive:
		var from: Vector2=options.get("attack_origin",source.position)
		KnockbackController.apply(target,(target.position-from).normalized()*ItemTuning.KEG_PUSH,source);_mark(source,&"powderKeg",target)
	if not basic:return
	if stats.has(&"giantSpear") and target.alive:
		var share: float=ItemTuning.SPEAR_ELITE_HP if ItemEffects.elite(target) else ItemTuning.SPEAR_HP
		_hit(source,target,&"giant_spear",&"item_spear",target.max_hp*share,{"fixed":true});_mark(source,&"giantSpear",target)
	if stats.has(&"giantRing"):
		var radius: float=ItemTuning.GIANT_RING_RADIUS*source.combat_scale();var hit: Array=[]
		for e in _foes(source):
			if e!=target and e.position.distance_to(target.position)<=radius:_hit(source,e,&"giant_ring",&"item_splash",out.resolved_damage*ItemTuning.GIANT_RING_SPLASH,{"plain":true});hit.append(_p(e.position))
		if not hit.is_empty():ItemEffects.fx(source,&"giantRing",target.position,{"radius":radius,"to":hit})
	if stats.has(&"thunderHammer") and _count(source,"thunderCount")%ItemTuning.THUNDER_EVERY==0 and source.state_value("thunderCount")>0:
		var radius: float=ItemTuning.THUNDER_RADIUS*source.combat_scale();var hit: Array=[]
		for e in _foes(source):
			if e.position.distance_to(target.position)>radius+24*e.combat_scale():continue
			_hit(source,e,&"thunder_hammer",&"item_thunder",UnitStatTable.raw(source,&"thunder_hammer"));hit.append(_p(e.position))
			if e.alive:ElementEffects.add_shock(e,ItemTuning.THUNDER_SHOCK)
		ItemEffects.proc(source,&"thunderHammer");ItemEffects.fx(source,&"thunderHammer",target.position,{"radius":radius,"to":hit})
	if stats.has(&"gunnerSight") and _count(source,"gunnerCount")%ItemTuning.GUNNER_EVERY==0 and source.state_value("gunnerCount")>0:
		var angle: float=(target.position-source.position).angle()
		CharacterAbility.shoot(source,angle,UnitStatTable.raw(source,&"basic")*ItemTuning.GUNNER_DEALT,{"dmg":&"gunner_shell","kind":"gunnerShell","speed":620,"radius":20,"life":1.6,"impulse":260,"shell":true,"blast_radius":ItemTuning.GUNNER_RADIUS*source.combat_scale()})
		ItemEffects.proc(source,&"gunnerSight");ItemEffects.fx(source,&"gunnerSight",source.position,{"angle":angle})
## 여명의 성검: a share of the damage heals the ally lowest on HP.
static func _dawn(source,dealt: float) -> void:
	var low=null
	for a in ItemEffects._allies(source):
		if ItemEffects._clone(a) or a.current_hp>=a.max_hp:continue
		if low==null or a.current_hp/a.max_hp<low.current_hp/low.max_hp:low=a
	if low==null:return
	if CharacterAbility.restore_hp(low,dealt*ItemTuning.DAWN_HEAL,source)>0 and _now(source)-source.state_value("dawnFx")>.35:
		source.set_state("dawnFx",_now(source));ItemEffects.proc(source,&"dawnSword");ItemEffects.fx(source,&"dawnSword",source.position,{"to":_p(low.position)})
## `target` (with items) was struck by an enemy.
static func was_struck(target,stats: UnitCombatStats) -> void:
	if stats.has(&"beastHide") and target.state_value("beastReady")>0 and target.current_hp<target.max_hp*ItemTuning.BEAST_HP:
		target.set_state("beastReady",0.0);target.set_state("beastTime",ItemTuning.BEAST_TIME)
		ItemEffects._own(target).scale*=1+ItemTuning.BEAST_BOOST
		ItemEffects.proc(target,&"beastHide");ItemEffects.fx(target,&"beastHide",target.position,{"transform":true})
## Gusts a hit leaves (순풍의 부채 half, 폭풍의 날개 all).
static func gust_keep(u) -> float:
	if has(u,&"stormWings"):return 1.0
	if has(u,&"tailwindFan"):return ItemTuning.FAN_KEEP
	return 0.0
## A parry or a dodge the unit made.
static func on_defended(u,parried: bool) -> void:
	if parried:
		if has(u,&"practiceSword") and CharacterAbility.restore_hp(u,u.max_hp*ItemTuning.PRACTICE_PARRY_HEAL,u)>0:ItemEffects.proc(u,&"practiceSword");ItemEffects.fx(u,&"practiceSword",u.position)
		if has(u,&"overlordGauntlet"):
			var radius: float=ItemTuning.GAUNTLET_RADIUS*u.combat_scale();var hit: Array=[]
			for e in _foes(u):
				if e.position.distance_to(u.position)>radius+24*e.combat_scale():continue
				_hit(u,e,&"overlord_wave",&"item_wave",UnitStatTable.raw(u,&"overlord_wave"));hit.append(_p(e.position))
				if e.alive:KnockbackController.apply(e,(e.position-u.position).normalized()*ItemTuning.GAUNTLET_PUSH,u)
			ItemEffects.proc(u,&"overlordGauntlet");ItemEffects.fx(u,&"overlordGauntlet",u.position,{"radius":radius,"to":hit})
	elif has(u,&"duelCape"):
		u.set_state("capeStacks",minf(ItemTuning.CAPE_STACKS,(u.state_value("capeStacks") if u.state_value("capeTime")>0 else 0.0)+1));u.set_state("capeTime",ItemTuning.CAPE_TIME)
		ItemEffects.proc(u,&"duelCape");ItemEffects.fx(u,&"duelCape",u.position,{"stacks":int(u.state_value("capeStacks"))})
## 결투가의 망토: its own dodge roll (at most once per CAPE_DODGE_GAP).
static func dodge(target) -> bool:
	if not has(target,&"duelCape") or _now(target)-target.state_value("capeDodgeAt")<ItemTuning.CAPE_DODGE_GAP and target.character_specific_state.has("capeDodgeAt"):return false
	if target.battle.rng.randf()>=ItemTuning.CAPE_DODGE:return false
	target.set_state("capeDodgeAt",_now(target));return true
static func parry_bonus(u) -> float:return ItemTuning.GAUNTLET_PARRY if has(u,&"overlordGauntlet") else 0.0
## 벽치기 장갑: an enemy the bearer pushed slams into a wall or a unit.
static func slam(unit,source) -> void:
	if not is_instance_valid(source) or source.team==unit.team or not unit.alive or not has(source,&"wallGlove"):return
	if unit.character_specific_state.has("wallStunAt") and _now(unit)-unit.state_value("wallStunAt")<ItemTuning.WALL_STUN_GAP:return
	unit.set_state("wallStunAt",_now(unit));StatusController.stun(unit,ItemTuning.WALL_STUN)
	_hit(source,unit,&"wall_slam",&"item_slam",UnitStatTable.raw(source,&"wall_slam"))
	ItemEffects.proc(source,&"wallGlove");ItemEffects.fx(source,&"wallGlove",unit.position)
## 쌍발 석궁: a basic projectile brings a second, weaker one (once per attack).
static func twin(u,angle: float,damage: float,settings: Dictionary) -> void:
	if settings.get("twin",false) or settings.get("shell",false) or settings.has("dmg_type") or StringName(settings.get("dmg",&""))!=&"basic" or damage<=0 or not has(u,&"twinCrossbow"):return
	if u.battle.ultimate_actor==u or _now(u)-u.state_value("twinAt")<.12 and u.character_specific_state.has("twinAt"):return
	u.set_state("twinAt",_now(u))
	var more: Dictionary=settings.duplicate(true);more["twin"]=true;more["offset"]=float(settings.get("offset",32))+10
	CharacterAbility.shoot(u,angle+.09,damage*ItemTuning.TWIN_SHARE,more)
	ItemEffects.fx(u,&"twinCrossbow",u.position,{"angle":angle})
## 폭발 화약통: the bearer's blasts are wider.
static func blast_radius(u,radius: float) -> float:return radius*ItemTuning.KEG_RADIUS if has(u,&"powderKeg") else radius
## 거울 방패: half of the enemy shots turn back to the shooter.
static func reflect(p,target) -> bool:
	if not has(target,&"mirrorShield") or not is_instance_valid(p.source) or p.source.team==target.team or p.metadata.get("mirror_back",false):return false
	if p.kind in ["bomb","tankShell","frogBody","frogTongue","openingAwl","boostVial","controlThread","gunnerShell"]:return false
	if target.battle.rng.randf()>=ItemTuning.MIRROR_REFLECT:return false
	p.live=false;p.attack_instance.life=0
	if not p.source.alive:return true
	var angle: float=(p.source.position-target.position).angle()
	CharacterAbility.shoot(target,angle,p.damage,{"dmg":p.metadata.get("dmg",&"basic"),"dmg_type":p.source.data.type_id,"kind":"mirrorReflection","speed":680,"radius":18,"offset":30,"life":1.6,"impulse":120,"mirror_back":true})
	ItemEffects.proc(target,&"mirrorShield");ItemEffects.fx(target,&"mirrorShield",target.position,{"angle":angle})
	return true

# ---- Ultimates, kills, deaths ----
static func after_ultimate(u,stats: UnitCombatStats) -> void:
	if stats.has(&"ultScore"):
		var to: Array=[]
		for a in ItemEffects._allies(u):
			if a!=u and not ItemEffects._clone(a) and a.ultimate.gain(a,ItemTuning.SCORE_GAUGE)>0:to.append(_p(a.position))
		ItemEffects.proc(u,&"ultScore");ItemEffects.fx(u,&"ultScore",u.position,{"to":to})
	if stats.has(&"ultScepter") and u.state_value("scepterEcho")<=0:
		var near=ItemEffects._nearest_ally(u)
		if near!=null and near.alive and near.ultimate.cast.is_empty():
			var keep: float=near.ultimate_gauge;near.ultimate_gauge=100;near.set_state("scepterEcho",1.0)
			if near.ultimate.request(near,near.ability.ultimate_target(near)):ItemEffects.proc(u,&"ultScepter");ItemEffects.fx(u,&"ultScepter",u.position,{"to":_p(near.position)});near.ultimate_gauge=keep
			else:near.ultimate_gauge=keep;near.set_state("scepterEcho",0.0)
	elif u.state_value("scepterEcho")>0:u.set_state("scepterEcho",0.0)
## 역병 향로: what burned, poisoned or bled on a kill moves to the nearest enemy.
static func on_kill(source,victim) -> void:
	if victim==null or not has(source,&"plagueCenser"):return
	var next=CharacterAbility.nearest(victim,_foes(source).filter(func(e):return e!=victim))
	if next==null:return
	var moved: bool=false
	if victim.state_value("burnStacks")>0:ElementEffects.add_burn(source,next,int(victim.state_value("burnStacks")));moved=true
	if victim.state_value("poisonStacks")>0:next.set_state("poisonStacks",next.state_value("poisonStacks")+victim.state_value("poisonStacks"));next.set_state("poisonSource",source.actor_id());moved=true
	if victim.state_value("bleedTime")>0:
		next.set_state("bleedTime",ItemTuning.BLEED_TIME);next.set_state("bleedPer",maxf(next.state_value("bleedPer"),victim.state_value("bleedPer")));next.set_state("bleedSource",source.actor_id())
		if next.state_value("bleedTick")<=0:next.set_state("bleedTick",ItemTuning.BLEED_EVERY)
		moved=true
	if moved:ItemEffects.proc(source,&"plagueCenser");ItemEffects.fx(source,&"plagueCenser",victim.position,{"to":_p(next.position)})
static func on_death(victim) -> void:
	var battle=victim.battle
	# 화산의 심장: a burning unit lit by a bearer bursts.
	var fire=battle.find_actor(str(victim.character_specific_state.get("burnSource","")))
	if victim.state_value("burnStacks")>0 and fire!=null and has(fire,&"volcanoHeart") and fire.team!=victim.team:
		var radius: float=ItemTuning.VOLCANO_RADIUS*victim.combat_scale();var to: Array=[]
		for e in _foes(fire):
			if e==victim or e.position.distance_to(victim.position)>radius+24*e.combat_scale():continue
			_hit(fire,e,&"volcano_burst",&"item_volcano",UnitStatTable.raw(fire,&"volcano_burst"))
			if e.alive:ElementEffects.add_burn(fire,e,ItemTuning.VOLCANO_STACKS)
			to.append(_p(e.position))
		ItemEffects.proc(fire,&"volcanoHeart");ItemEffects.fx(fire,&"volcanoHeart",victim.position,{"radius":radius,"to":to})
	# 역병 군주의 잔: all the poison moves on.
	var venom=battle.find_actor(str(victim.character_specific_state.get("poisonSource","")))
	if victim.state_value("poisonStacks")>0 and venom!=null and has(venom,&"plagueChalice") and venom.team!=victim.team:
		var next=CharacterAbility.nearest(victim,_foes(venom).filter(func(e):return e!=victim))
		if next!=null:
			next.set_state("poisonStacks",next.state_value("poisonStacks")+victim.state_value("poisonStacks"));next.set_state("poisonSource",venom.actor_id())
			ItemEffects.proc(venom,&"plagueChalice");ItemEffects.fx(venom,&"plagueChalice",victim.position,{"to":_p(next.position)})
	if ItemEffects._clone(victim):return
	for u in battle.units:
		if u==victim or not u.alive or u.team!=victim.team or ItemEffects._clone(u):continue
		if has(u,&"vengeanceMask"):
			u.set_state("vengeance",u.state_value("vengeance")+1);ItemEffects.proc(u,&"vengeanceMask");ItemEffects.fx(u,&"vengeanceMask",u.position,{"stacks":int(u.state_value("vengeance"))})
	# 영혼의 등불: the fallen fights on as a spirit while a bearer lives.
	var lantern=null
	for u in battle.units:
		if u!=victim and u.alive and u.team==victim.team and has(u,&"soulLantern"):lantern=u;break
	if lantern==null or victim.combat_stats==null:return
	var stats: UnitCombatStats=victim.combat_stats.copy()
	stats.max_hp*=ItemTuning.SOUL_HP;stats.effects={};stats.items=[];stats.growth={}
	_strip(stats)
	battle.queue_spawn(victim,victim.position,stats,{"mirrorOf":victim.actor_id(),"spiritOf":victim.actor_id(),"spiritTime":ItemTuning.SOUL_TIME})
	ItemEffects.proc(lantern,&"soulLantern");ItemEffects.fx(lantern,&"soulLantern",victim.position,{"from":_p(lantern.position)})
## A copy with no item abilities (거울 분신, 영혼).
static func _strip(stats: UnitCombatStats) -> void:
	for flag in ["duelist","vanguard","elementalist","enchant","chain_ring","sovereign","immovable","sanctuary"]:stats.set(flag,false)
	for count in ["vigor_totem_count","charge_totem_count","fang_count","opening_awl_count","phoenix_count","hourglass_count","dragon_heart_count","overcharge_count","victory_gold"]:stats.set(count,0)

# ---- Every tick ----
static func advance(u,stats: UnitCombatStats,dt: float) -> void:
	for key in ["capeTime"]:
		if u.state_value(key)>0:u.set_state(key,maxf(0,u.state_value(key)-dt))
	if u.state_value("beastTime")>0:
		u.set_state("beastTime",maxf(0,u.state_value("beastTime")-dt))
		if u.state_value("beastTime")<=0:ItemEffects._own(u).scale/=1+ItemTuning.BEAST_BOOST;ItemEffects.fx(u,&"beastHide",u.position,{"end":true})
	if u.state_value("hornDash")>0:
		u.set_state("hornDash",maxf(0,u.state_value("hornDash")-dt))
		var t=u.battle.find_actor(str(u.character_specific_state.get("hornTarget","")))
		if t==null or not t.alive or CharacterAbility.dash_to(u,t.position,ItemTuning.HORN_CHARGE_SPEED,dt,(30+u.data.attack_range*.5)*u.combat_scale()):u.set_state("hornDash",0.0)
		else:u.facing=(t.position-u.position).angle()
	if stats.has(&"knightCrest"):
		u.set_state("crestClock",u.state_value("crestClock")-dt)
		if u.state_value("crestClock")<=0:u.set_state("crestClock",ItemTuning.CREST_EVERY);_taunt(u)
	if stats.has(&"spiritLantern"):
		u.set_state("spiritClock",u.state_value("spiritClock")-dt)
		if u.state_value("spiritClock")<=0:u.set_state("spiritClock",ItemTuning.SPIRIT_EVERY);_spirit_bolt(u)
	if stats.has(&"dragonEgg"):
		u.set_state("dragonClock",u.state_value("dragonClock")-dt)
		if u.state_value("dragonClock")<=0:u.set_state("dragonClock",ItemTuning.DRAGON_EVERY);_breath(u)
	if stats.has(&"thiefWatch"):
		u.set_state("watchClock",u.state_value("watchClock")-dt)
		if u.state_value("watchClock")<=0:u.set_state("watchClock",ItemTuning.WATCH_EVERY);_time_stop(u)
	if stats.has(&"blackHoleOrb"):
		u.set_state("holeClock",u.state_value("holeClock")-dt)
		if u.state_value("holeClock")<=0:u.set_state("holeClock",ItemTuning.BLACKHOLE_EVERY);_open_hole(u)
	if u.state_value("holeTime")>0:_pull(u,dt)
## Ticks for every unit (spirits and stopped time).
static func tick(u,dt: float) -> void:
	if u.state_value("timeStopTime")>0:u.set_state("timeStopTime",maxf(0,u.state_value("timeStopTime")-dt))
	if spirit(u):
		if not u.has_meta("spirit_shown"):u.set_meta("spirit_shown",true);u.modulate=Color(.78,1,.95,.62);u.ultimate_gauge=0;u.transcendence_gauge=0
		u.set_state("spiritTime",u.state_value("spiritTime")-dt)
		if u.state_value("spiritTime")<=0:
			u.invincible_remaining=0;u.receive_damage(u.current_hp+u.shield_hp+1,null)
## 수호 기사의 문장: the two nearest enemies go for the bearer only.
static func _taunt(u) -> void:
	var foes: Array=_foes(u);foes.sort_custom(func(a,b):return a.position.distance_to(u.position)<b.position.distance_to(u.position))
	var to: Array=[]
	var id: String=u.source_member_id if not u.source_member_id.is_empty() else u.actor_id()
	for e in foes.slice(0,ItemTuning.CREST_TARGETS):
		if e.position.distance_to(u.position)>420:continue
		e.taunted_member_id=id;e.taunted_until=_now(u)+ItemTuning.CREST_TIME;e.target=u;e.set_state("crestTaunt",ItemTuning.CREST_TIME);to.append(_p(e.position))
	if to.is_empty():return
	ItemEffects.proc(u,&"knightCrest");ItemEffects.fx(u,&"knightCrest",u.position,{"to":to})
## 정령 등불: the spirit's shot of the bearer's element.
static func _spirit_bolt(u) -> void:
	var near=CharacterAbility.nearest(u,_foes(u))
	if near==null or near.position.distance_to(u.position)>ItemTuning.SPIRIT_RANGE:return
	var element: StringName=_element(u);var from: Vector2=u.position+Vector2(-26,-34)*u.combat_scale()
	_hit(u,near,&"spirit_bolt",&"item_spirit",UnitStatTable.raw(u,&"spirit_bolt"),{"extra_tags":[element]})
	apply_element(u,near,element)
	ItemEffects.fx(u,&"spiritLantern",from,{"to":_p(near.position),"element":String(element)})
## 새끼 용의 알: a breath of fire on the nearest enemy and those around it.
static func _breath(u) -> void:
	var near=CharacterAbility.nearest(u,_foes(u))
	if near==null or near.position.distance_to(u.position)>ItemTuning.DRAGON_RANGE*u.combat_scale():return
	var stage: int=int(u.state_value("dragonStage"));var grow: float=1+ItemTuning.DRAGON_GROW*(stage-1)
	var radius: float=(46+stage*4)*u.combat_scale();var to: Array=[]
	for e in _foes(u):
		if e.position.distance_to(near.position)>radius+20*e.combat_scale():continue
		_hit(u,e,&"dragon_breath",&"item_dragon",UnitStatTable.raw(u,&"dragon_breath")*grow)
		if e.alive:ElementEffects.add_burn(u,e,ElementEffects.BURN_STACKS)
		to.append(_p(e.position))
	ItemEffects.proc(u,&"dragonEgg");ItemEffects.fx(u,&"dragonEgg",u.position+Vector2(30,-38)*u.combat_scale(),{"to":_p(near.position),"stage":stage,"radius":radius})
## 시간 도둑의 회중시계: every enemy stops (bosses for less).
static func _time_stop(u) -> void:
	var to: Array=[]
	for e in _foes(u):
		var t: float=ItemTuning.WATCH_BOSS_STOP if e.combat_stats!=null and e.combat_stats.rank==&"boss" else ItemTuning.WATCH_STOP
		StatusController.stun(e,t);e.set_state("timeStopTime",t);to.append(_p(e.position))
	if to.is_empty():return
	ItemEffects.proc(u,&"thiefWatch");ItemEffects.fx(u,&"thiefWatch",u.position,{"to":to})
## 블랙홀 구슬: a hole where the enemies stand thickest.
static func _open_hole(u) -> void:
	var foes: Array=_foes(u)
	if foes.is_empty():return
	var best: Vector2=foes[0].position;var most: int=-1
	for e in foes:
		var n: int=foes.filter(func(o):return o.position.distance_to(e.position)<=ItemTuning.BLACKHOLE_RADIUS).size()
		if n>most:most=n;best=e.position
	u.set_state("holeX",best.x);u.set_state("holeY",best.y);u.set_state("holeTime",ItemTuning.BLACKHOLE_TIME)
	ItemEffects.proc(u,&"blackHoleOrb");ItemEffects.fx(u,&"blackHoleOrb",best,{"radius":ItemTuning.BLACKHOLE_RADIUS,"time":ItemTuning.BLACKHOLE_TIME})
static func _pull(u,dt: float) -> void:
	u.set_state("holeTime",maxf(0,u.state_value("holeTime")-dt))
	var at: Vector2=Vector2(u.state_value("holeX"),u.state_value("holeY"))
	for e in _foes(u):
		var d: float=e.position.distance_to(at)
		if d>ItemTuning.BLACKHOLE_RADIUS*1.25 or d<8 or ItemEffects.immovable(e) or e.state_value("guardRemaining")>0 or not e.duel.is_empty():continue
		e.position=MovementController.clamp_position(e.position+(at-e.position).normalized()*minf(d-6,ItemTuning.BLACKHOLE_PULL*dt))

# ---- Tower (run rules) ----
## Members with 계약의 인장 in the plan (they pay at the sortie, in plan order).
static func pact_bearers(guild: GuildManager,plan: DeploymentPlan) -> Array:
	var out: Array=[]
	for e in plan.entries():
		var m: GuildMemberState=guild.get_member(e.member_id)
		if m!=null and guild.member_stats(m).has(&"pactSeal"):out.append(e.member_id)
	return out
## Equipped instances of members, as [member, instance, effect].
static func _worn(guild: GuildManager) -> Array:
	var out: Array=[];var inventory:=InventoryService.new(guild.state)
	for m in guild.all_members():
		for i in inventory.equipped(m.member_id):
			var item: ItemData=ItemCatalog.get_item(i.kind)
			if item!=null and item.effect!=&"":out.append([m,i,item.effect])
	return out
## Battle settled (tower): victory healing, EXP, gold, and what items grow by.
## Returns how many extra reward choices 황금 거위 adds and the gold paid.
static func settle(guild: GuildManager,result: BattleResult) -> Dictionary:
	var victory: bool=result.end_reason==BattleEndReason.Value.VICTORY
	var out: Dictionary={"choices":0,"gold":0,"notes":[]}
	var grails: int=0
	for row in _worn(guild):
		var m: GuildMemberState=row[0];var i: ItemInstance=row[1]
		var went: bool=m.member_id in result.participating_member_ids;var lived: bool=m.member_id in result.surviving_member_ids
		match row[2]:
			&"reserveBadge":
				if went:i.growth=0
				elif m.is_alive():i.growth=mini(ItemTuning.RESERVE_MAX,i.growth+1)
			&"streakBelt":
				if went:i.growth=mini(ItemTuning.STREAK_MAX,i.growth+1) if victory else 0
			&"dragonEgg":
				if went and victory:i.growth=mini(ItemTuning.DRAGON_STAGES-1,i.growth+1)
			&"mangoRosary":
				if went and victory:
					i.growth+=1
					if i.growth>=ItemTuning.ROSARY_WINS:i.growth=0;guild.state.mango_faith+=1
			&"victoryCup":
				if lived and victory:GuildMemberCombatStats.heal(guild,m,guild.member_max_hp(m)*ItemTuning.CUP_HEAL)
			&"rookieBadge":
				if lived and victory:
					var old_max: float=guild.member_max_hp(m);m.total_exp+=ItemTuning.ROOKIE_EXP
					GuildMemberCombatStats.heal(guild,m,maxf(0,guild.member_max_hp(m)-old_max))
			&"goldenGoose":
				if lived and victory:out.choices+=1;out.gold+=ItemTuning.GOOSE_GOLD
			&"victoryGrail":
				if lived and victory:grails+=1
	for n in range(grails):
		for id in result.surviving_member_ids:
			var m: GuildMemberState=guild.get_member(id)
			if m!=null:GuildMemberCombatStats.heal(guild,m,guild.member_max_hp(m)*ItemTuning.GRAIL_HEAL)
	guild.state.gold+=int(out.gold)
	return out
## A floor was conquered: every 정복자의 왕관 grows.
static func on_floor_conquered(guild: GuildManager) -> void:
	for row in _worn(guild):
		if row[2]==&"conquerorCrown":row[1].growth=mini(ItemTuning.CONQUEROR_MAX,row[1].growth+1)
## A room entered for the first time: 개척자의 지도 pays while its bearer lives.
static func on_room_discovered(guild: GuildManager) -> int:
	var gold: int=0
	for row in _worn(guild):
		if row[2]==&"pioneerMap" and row[0].is_alive():gold+=ItemTuning.PIONEER_GOLD
	guild.state.gold+=gold;return gold
## Stats that grow over the run (applied when a member's stats are put together).
static func run_stats(stats: UnitCombatStats,run: RunState) -> void:
	if stats.has(&"reserveBadge"):stats.attack*=1+ItemTuning.RESERVE_STEP*int(stats.growth.get(&"reserveBadge",0))
	if stats.has(&"streakBelt"):stats.attack*=1+ItemTuning.STREAK_STEP*int(stats.growth.get(&"streakBelt",0))
	if stats.has(&"conquerorCrown") and int(stats.growth.get(&"conquerorCrown",0))>0:stats.scale_all(1+ItemTuning.CONQUEROR_STEP*int(stats.growth.conquerorCrown))
	if stats.has(&"mangoRosary") and run!=null and run.mango_faith>0:stats.scale_all(1+ItemTuning.ROSARY_STEP*run.mango_faith)
## 배수진의 인장: a retreat costs its bearers their lives (the result is a defeat if none is left).
static func retreat_victims(battle) -> Array:
	return battle.units.filter(func(u):return u.alive and not u.source_member_id.is_empty() and has(u,&"lastStandSeal"))
