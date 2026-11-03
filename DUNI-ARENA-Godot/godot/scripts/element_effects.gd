class_name ElementEffects
extends RefCounted
## What each element does beyond its damage (full-character battles only). Every number is here.
## Stacks, timers and marks live in character_specific_state, so they end with the battle.
##
## 화염  fire-tagged hits have a PROC_CHANCE chance to add BURN_STACKS burn stacks. Every BURN_EVERY
##       seconds one stack burns away for BURN_DAMAGE, and the burning unit scorches its own
##       allies within BURN_RADIUS for BURN_SPREAD (stacks never move to them).
## 맹독  poison-tagged hits have a PROC_CHANCE chance to add one stack. Stacks last the whole
##       battle and deal POISON_DAMAGE per stack each second; a poisoned unit gives and receives
##       POISON_HEAL of its healing.
## 얼음  ice-tagged hits have a PROC_CHANCE chance to add one frost stack. FREEZE_STACKS freeze the
##       unit (a stun) for FREEZE_TIME; when it thaws it has frostbite for FROSTBITE_TIME (takes
##       FROSTBITE_TAKEN damage, and frost landing on it deals FROSTBITE_HIT instead of stacking).
## 번개  every lightning hit adds a shock stack; SHOCK_STACKS stun for SHOCK_STUN. Lightning
##       attacks also jump on: CHAIN_SHARE of the damage just dealt to the next enemy, CHAIN_HOPS
##       times at most.
## 바람  each wind attack gives the attacker a gust stack (attack speed and wind damage up); a
##       direct hit that reaches HP resets them. Enemies hit by wind are slowed (headwind).
## 빛    light damage heals the attacker's allies nearby (itself included) by LIGHT_HEAL of it and
##       marks the target; another unit's direct hit pops the mark and heals that unit.
## 어둠  dark hits erode the target for EROSION_TIME: every action but moving costs it
##       EROSION_DAMAGE and critical hits on it are stronger. Dark damage also marks the target;
##       another unit's direct hit pops the mark for DARK_POP damage.
## Units whose own ability grants an element differently opt out through
## CharacterAbility.own_element (the frost mage's crystals, the lightning mage's chain bolt).
const PROC_CHANCE: float = .5
const BURN_STACKS: int = 2
const BURN_MAX: int = 10
const BURN_EVERY: float = .5
const BURN_DAMAGE: float = 4
const BURN_SPREAD: float = 2
const BURN_RADIUS: float = 90
const POISON_EVERY: float = 1
const POISON_DAMAGE: float = 1
const POISON_HEAL: float = .6
const FREEZE_STACKS: int = 10
const FREEZE_TIME: float = 4
const FROST_DECAY: float = 4
const FROSTBITE_TIME: float = 4
const FROSTBITE_TAKEN: float = 1.1
const FROSTBITE_HIT: float = 5
const SHOCK_STACKS: int = 5
const SHOCK_STUN: float = 2
const CHAIN_SHARE: float = .6
const CHAIN_HOPS: int = 5
const CHAIN_RANGE: float = 200
const WIND_MAX: int = 10
const WIND_ATTACK_SPEED: float = .05
const WIND_DAMAGE: float = .03
const HEADWIND_TIME: float = 2
const HEADWIND_MOVE: float = .7
const HEADWIND_ATTACK_SPEED: float = .8
const LIGHT_HEAL: float = .1
const LIGHT_RADIUS: float = 160
const LIGHT_POP_HEAL: float = .05
const EROSION_TIME: float = 2
const EROSION_DAMAGE: float = 6
const EROSION_CRIT: float = .25
const DARK_POP: float = 1.2
## 목표 (석궁 궁극기): damage taken +10%, wind damage taken +15%.
const TARGETED_TAKEN: float = 1.1
const TARGETED_WIND: float = 1.15
## 둔화 (슬라임 몸통 박치기): movement -30%.
const SLOW_MOVE: float = .7

static func _on(u) -> bool:return u != null and is_instance_valid(u) and u.battle != null and u.battle.full_characters_enabled
## A direct hit: an attack landing, not damage over time, a status tick, a chain jump or a collision.
static func direct(spec: Dictionary, options: Dictionary) -> bool:
	return not options.get("collision", false) and StringName(options.get("status", &"")) == &"" and not spec.get("tags", []).has(&"dot")
static func _hit(source, target, key: StringName, amount: float, extra: Dictionary = {}) -> DamageOutcome:
	var options: Dictionary = {"dmg": key, "status": key, "critical": false, "impulse": 0}
	options.merge(extra, true)
	return target.battle.damage_resolver.resolve(source, target, amount, options)

# ---- Modifiers read by the damage, speed and healing code ----
## Outgoing multiplier for a hit about to land: gusts boost wind damage, a dark mark left by
## another unit boosts a direct hit.
static func outgoing(source, target, spec: Dictionary, options: Dictionary) -> float:
	if not _on(source):return 1
	var factor: float = 1
	if spec.get("tags", []).has(&"wind"):factor *= 1 + WIND_DAMAGE * source.state_value("windStacks")
	var mark: String = str(target.character_specific_state.get("darkMark", ""))
	if not mark.is_empty() and mark != source.actor_id() and direct(spec, options):factor *= DARK_POP
	# 목표 (석궁): wind damage taken +15% in all (the general +10% comes from taken()).
	if target.state_value("targetedTime") > 0 and spec.get("tags", []).has(&"wind"):factor *= TARGETED_WIND / TARGETED_TAKEN
	return factor
## Extra critical damage an eroded unit takes (added to the attacker's critical damage).
static func crit_taken(target) -> float:return EROSION_CRIT if target.state_value("erosionTime") > 0 else 0.0
static func taken(u) -> float:return (FROSTBITE_TAKEN if u.state_value("frostbiteTime") > 0 else 1.0) * (TARGETED_TAKEN if u.state_value("targetedTime") > 0 else 1.0)
static func attack_speed(u) -> float:
	if u.character_specific_state.is_empty():return 1
	return (1 + WIND_ATTACK_SPEED * u.state_value("windStacks")) * (HEADWIND_ATTACK_SPEED if u.state_value("headwindTime") > 0 else 1.0)
static func move_speed(u) -> float:return (HEADWIND_MOVE if u.state_value("headwindTime") > 0 else 1.0) * (SLOW_MOVE if u.state_value("slowTime") > 0 else 1.0)
static func healing(u) -> float:return POISON_HEAL if u.state_value("poisonStacks") > 0 else 1.0

# ---- Events ----
## Called when a unit acts (starts an attack or counter, parries, dodges, casts an ultimate).
static func on_action(u, attack: bool = false) -> void:
	if not _on(u):return
	if u.state_value("erosionTime") > 0:u.set_state("erodePending", u.state_value("erodePending") + 1)
	if attack and UnitStatTable.spec(u.data.type_id, &"basic").tags.has(&"wind"):u.set_state("windStacks", minf(WIND_MAX, u.state_value("windStacks") + 1))

## A hit has landed (on HP or shield). Applies the element effects of its damage instance.
static func on_hit(source, target, out: DamageOutcome, spec: Dictionary, options: Dictionary) -> void:
	if not _on(target) or not is_instance_valid(source) or source.team == target.team:return
	var battle = target.battle
	var tags: Array = spec.get("tags", [])
	var status: StringName = StringName(options.get("status", &""))
	var is_direct: bool = direct(spec, options)
	var me: String = source.actor_id()
	if is_direct:
		if out.hp_damage > 0 and target.state_value("windStacks") > 0:target.set_state("windStacks", 0)
		if str(target.character_specific_state.get("darkMark", "")) not in ["", me]:
			target.character_specific_state.erase("darkMark")
			battle.emit_combat_event(&"dark_pop", target.position, {"actor_id": target.battle_id, "to": [me]})
		if str(target.character_specific_state.get("lightMark", "")) not in ["", me]:
			target.character_specific_state.erase("lightMark")
			if source.alive:CharacterAbility.restore_hp(source, source.max_hp * LIGHT_POP_HEAL, source)
			battle.emit_combat_event(&"light_pop", target.position, {"actor_id": target.battle_id, "to": [me]})
	if tags.has(&"light") and out.hp_damage > 0 and source.alive:
		var healed: Array = []
		for ally in battle.units:
			if ally.alive and ally.team == source.team and not ally.unavailable() and ally.position.distance_to(source.position) <= LIGHT_RADIUS * source.combat_scale():
				if CharacterAbility.restore_hp(ally, out.hp_damage * LIGHT_HEAL, source) > 0:healed.append(ally.actor_id())
		# Presentation: orbs of light fly from the struck enemy to each healed ally.
		if not healed.is_empty():battle.emit_combat_event(&"light_orbs", target.position, {"to": healed})
	if status != &"" and status != &"chain_shock":return
	if target.alive:
		var rng: RandomNumberGenerator = battle.rng
		if tags.has(&"lightning"):add_shock(target, int(options.get("shock_stacks", 1)))
		if status != &"":return
		if tags.has(&"fire") and rng.randf() < PROC_CHANCE:add_burn(source, target, BURN_STACKS)
		if tags.has(&"poison") and rng.randf() < PROC_CHANCE:
			target.set_state("poisonStacks", target.state_value("poisonStacks") + 1);target.set_state("poisonSource", me)
		if tags.has(&"ice") and not source.ability.own_element(&"ice", options) and rng.randf() < PROC_CHANCE:add_frost(source, target, 1)
		if tags.has(&"wind"):target.set_state("headwindTime", HEADWIND_TIME)
		if tags.has(&"light"):
			if str(target.character_specific_state.get("lightMark", "")) != me:battle.emit_combat_event(&"light_mark", target.position, {"actor_id": target.battle_id})
			target.set_state("lightMark", me)
		if tags.has(&"dark"):
			if str(target.character_specific_state.get("darkMark", "")) != me:battle.emit_combat_event(&"dark_mark", target.position, {"actor_id": target.battle_id})
			target.set_state("erosionTime", EROSION_TIME);target.set_state("erosionSource", me);target.set_state("darkMark", me)
	if status == &"" and tags.has(&"lightning") and not source.ability.own_element(&"chain", options):
		_chain(source, target, out.hp_damage + out.shield_absorbed)

static func add_burn(source, target, stacks: int) -> void:
	if target.state_value("burnStacks") <= 0:target.set_state("burnTick", BURN_EVERY)
	target.set_state("burnStacks", minf(BURN_MAX, target.state_value("burnStacks") + stacks));target.set_state("burnSource", source.actor_id())
## Frost stacks freeze at FREEZE_STACKS. None stack while frozen or frostbitten; frost landing on
## a frostbitten unit deals FROSTBITE_HIT instead (queued, dealt on the next tick).
static func add_frost(source, target, stacks: int) -> void:
	if not target.alive or target.state_value("frozenTime") > 0:return
	if target.state_value("frostbiteTime") > 0:
		if is_instance_valid(source):target.set_state("frostbitePending", target.state_value("frostbitePending") + 1);target.set_state("frostbiteSource", source.actor_id())
		return
	var total: float = target.state_value("frostStacks") + stacks
	target.set_state("frostDecay", FROST_DECAY)
	if total >= FREEZE_STACKS:
		target.set_state("frostStacks", 0);target.set_state("frozenTime", FREEZE_TIME)
		StatusController.stun(target, FREEZE_TIME)
	else:target.set_state("frostStacks", total)
## Freezes at once (빙하 골렘's blast), as if the frost stacks had filled.
static func freeze(target, time: float = FREEZE_TIME) -> void:
	if not target.alive or target.state_value("frozenTime") > 0:return
	target.set_state("frostStacks", 0);target.set_state("frozenTime", time)
	StatusController.stun(target, time)
## Shock stacks; none build up while the unit is stunned.
static func add_shock(target, stacks: int = 1) -> void:
	if not target.alive or target.stun_remaining > 0:return
	var total: float = target.state_value("shockStacks") + stacks
	if total >= SHOCK_STACKS:
		target.set_state("shockStacks", 0);StatusController.stun(target, SHOCK_STUN)
		target.battle.emit_combat_event(&"shock_stun", target.position, {"actor_id": target.battle_id})
	else:target.set_state("shockStacks", total)
## The jump: each hop deals CHAIN_SHARE of what the previous hit dealt to the nearest enemy not
## yet struck, up to CHAIN_HOPS times.
static func _chain(source, first, dealt: float) -> void:
	var battle = first.battle
	var struck: Array = [first];var at: Vector2 = first.position;var value: float = dealt
	for i in range(CHAIN_HOPS):
		value *= CHAIN_SHARE
		if value < 1:return
		var next = null
		for e in battle.units:
			if e.alive and e.team != source.team and not e.unavailable() and e not in struck and e.position.distance_to(at) <= CHAIN_RANGE and (next == null or e.position.distance_to(at) < next.position.distance_to(at)):next = e
		if next == null:return
		battle.emit_combat_event(&"chain_shock", at, {"to": CharacterPersistence.point(next.position)})
		var out: DamageOutcome = _hit(source, next, &"chain_shock", value, {"plain": true})
		struck.append(next);at = next.position;value = out.hp_damage + out.shield_absorbed

# ---- Per-tick upkeep (burning, poison, thawing, timers, erosion) ----
static func advance(battle, dt: float) -> void:
	for u in battle.units.duplicate():
		if not u.alive or u.character_specific_state.is_empty():continue
		if u.state_value("burnStacks") > 0:
			u.set_state("burnTick", u.state_value("burnTick") - dt)
			if u.state_value("burnTick") <= 0:
				u.set_state("burnTick", u.state_value("burnTick") + BURN_EVERY);u.set_state("burnStacks", u.state_value("burnStacks") - 1)
				var fire = battle.find_actor(str(u.character_specific_state.get("burnSource", "")))
				if fire != null:
					for ally in battle.units.duplicate():
						if ally != u and ally.alive and ally.team == u.team and not ally.unavailable() and ally.position.distance_to(u.position) <= BURN_RADIUS * u.combat_scale():_hit(fire, ally, &"burn_spread", BURN_SPREAD)
					_hit(fire, u, &"burn", BURN_DAMAGE)
		if not u.alive:continue
		if u.state_value("poisonStacks") > 0:
			u.set_state("poisonTick", u.state_value("poisonTick") + dt)
			if u.state_value("poisonTick") >= POISON_EVERY:
				u.set_state("poisonTick", u.state_value("poisonTick") - POISON_EVERY)
				var venom = battle.find_actor(str(u.character_specific_state.get("poisonSource", "")))
				if venom != null:_hit(venom, u, &"poison", POISON_DAMAGE * u.state_value("poisonStacks"))
		if u.state_value("frozenTime") > 0:
			u.set_state("frozenTime", maxf(0, u.state_value("frozenTime") - dt))
			if u.state_value("frozenTime") <= 0:u.set_state("frostbiteTime", FROSTBITE_TIME)
		for key in ["frostbiteTime", "headwindTime", "erosionTime", "targetedTime", "slowTime", "charmTime"]:
			if u.state_value(key) > 0:u.set_state(key, maxf(0, u.state_value(key) - dt))
		for pair in [["frostbitePending", "frostbiteSource", &"frostbite", FROSTBITE_HIT], ["erodePending", "erosionSource", &"erosion", EROSION_DAMAGE]]:
			var count: int = int(u.state_value(pair[0]))
			if count <= 0:continue
			u.set_state(pair[0], 0)
			var by = battle.find_actor(str(u.character_specific_state.get(pair[1], "")))
			if by != null and u.alive:_hit(by, u, pair[2], pair[3] * count)
