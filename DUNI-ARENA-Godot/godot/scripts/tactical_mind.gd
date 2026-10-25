class_name TacticalMind
extends RefCounted
## Situational judgment layered over BattleBrain and ThreatResponseController (full-character
## battles only). It reads the unit's role, its HP and how the fight is going, and turns them
## into a temper between cautious (-1) and reckless (+1). The existing systems keep making the
## choices; the mind only tilts them: reaction odds, parry timing and success, how eagerly the
## unit attacks, how much space it keeps, and which enemy it picks.
## Deterministic and free of the battle RNG, so seeded replays stay stable.
const REAR: StringName = &"rear"
const STANDOFF: StringName = &"standoff"
const MELEE: StringName = &"melee"
const ROAM: StringName = &"roam"
const FIXED: StringName = &"fixed"
const ROLE_NAMES = {REAR:"후열", STANDOFF:"대치형", MELEE:"근접형", ROAM:"방황형", FIXED:"고정"}
## Unit tags as the player sees them (the data keeps its original tag names).
const TAG_NAMES = {"돌격형":"근접형", "호위형":"엄호형", "방황":"방황형"}
const EVAL_EVERY: float = .25
var enabled: bool = true
var temper: float = 0
var advantage: float = 0
var next_eval: float = -INF

## Base role: every unit has exactly one of rear / standoff / melee / roam / fixed.
static func role(data: UnitData) -> StringName:
	var tags: PackedStringArray = data.tags
	if tags.has("고정"):return FIXED
	if tags.has("후열") or tags.has("은둔형"):return REAR
	if tags.has("방황") or tags.has("비전투"):return ROAM
	if tags.has("대치형"):return STANDOFF
	return MELEE
static func guards(data: UnitData) -> bool:return data.tags.has("호위형")
## The unit's traits for display: its base role first, then the rest (엄호형, 회피형, ...).
static func trait_names(data: UnitData) -> Array:
	var out: Array = [ROLE_NAMES[role(data)]]
	for tag in data.tags:
		var name: String = TAG_NAMES.get(tag, tag)
		if tag != "일반" and name not in out:out.append(name)
	return out

func active(u) -> bool:return enabled and u.battle.full_characters_enabled
static func stance_lean(u) -> float:
	return -.5 if u.stance == CombatStance.CAUTIOUS else .5 if u.stance == CombatStance.RUSH else -.15 if u.stance == CombatStance.COVER else 0.0

## Refreshes temper from stance, role, HP and the balance of the fight.
func evaluate(u) -> void:
	var now: float = u.battle.clock.elapsed
	if now < next_eval:return
	next_eval = now + EVAL_EVERY
	var lean: float = stance_lean(u)
	match role(u.data):
		REAR:lean -= .3
		STANDOFF:lean -= .25
		MELEE:lean += .25
	if guards(u.data):lean -= .05
	# Plenty of HP emboldens, low HP makes it careful.
	lean += (clampf(u.current_hp / maxf(1, u.max_hp), 0, 1) - .55) * .9
	# Outnumbering the enemy emboldens, being outnumbered makes it careful.
	var ours: float = 0;var theirs: float = 0
	for other in u.battle.units:
		if not other.alive or other.unavailable():continue
		var weight: float = .4 + .6 * clampf(other.current_hp / maxf(1, other.max_hp), 0, 1)
		if other.team == u.team:ours += weight
		else:theirs += weight
	advantage = (ours - theirs) / maxf(1, ours + theirs)
	lean += advantage * .5
	temper = clampf(lean, -1, 1)
## How far the situation pushes past what the stance alone already does (stance effects are
## built into the base systems, so only the rest is applied on top).
func bias(u) -> float:
	if not active(u):return 0
	evaluate(u)
	return temper - stance_lean(u)
func cautious(u) -> bool:return bias(u) < -.3
func reckless(u) -> bool:return bias(u) > .3

## Tilts the base reaction odds for a perceived attack. Attacks clearly meant for someone else
## out of reach are ignored. Against a ranged shot aimed at this unit it chooses between holding
## ground to parry (healthy) and sidestepping (hurt).
func adjust_reaction(u, chances: Dictionary, source) -> Dictionary:
	if not active(u):return chances
	var out: Dictionary = chances.duplicate()
	var target = source.combat.attack_target if source.ultimate.cast.is_empty() else null
	var reach: float = source.combat.profile(source).reach * source.combat_scale()
	if target != null and target != u and target.team == u.team and u.position.distance_to(source.position) > reach + 30:
		return {"parry":0.0, "dodge":0.0, "counter":0.0, "hold":1.0}
	var b: float = bias(u)
	var guard: float = out.parry + out.dodge
	if b < 0:
		var shift: float = out.counter * minf(.6, -b * .45)
		out.counter -= shift
		if guard > 0:out.parry += shift * out.parry / guard;out.dodge += shift * out.dodge / guard
		else:out.dodge += shift
	elif guard > 0:
		var shift: float = guard * minf(.5, b * .35)
		out.parry -= shift * out.parry / guard;out.dodge -= shift * out.dodge / guard;out.counter += shift
	if source.data.attack_range > 150 and target == u:
		var healthy: bool = u.current_hp / maxf(1, u.max_hp) >= .55
		if healthy and ParryController.available(u):out.parry += out.dodge;out.dodge = 0
		else:out.dodge += out.parry * .7;out.parry *= .3
	return out
## Ranged shot aimed at a healthy unit that chose to parry: it steps in while parrying.
func advance_while_parrying(u, source) -> bool:
	return active(u) and source.data.attack_range > 150 and source.combat.attack_target == u and u.current_hp / maxf(1, u.max_hp) >= .55
## Chance of misjudging parry timing, and how tightly the parry is placed.
func parry_mistake(u, base: float) -> float:
	return clampf(base + bias(u) * .15, .06, .45) if active(u) else base
## Parry success multiplier: cautious minds read the blow better, reckless ones less.
func parry_factor(u) -> float:
	return clampf(1 - bias(u) * .3, .75, 1.3) if active(u) else 1.0

## Paces initiative: a cautious mind waits out the enemy's swing and strikes as it recovers;
## a reckless one goes in sooner.
func pace(u, enemy) -> void:
	if not active(u) or enemy == null:return
	var brain: BattleBrain = u.brain;var now: float = u.battle.clock.elapsed;var b: float = bias(u)
	var swinging: bool = enemy.combat_state in [CombatController.State.WINDUP, CombatController.State.ACTIVE] and enemy.combat.attack_target == u
	if b < -.3:
		if swinging:
			brain.next_initiative_at = maxf(brain.next_initiative_at, now + .35)
			if not brain.attack_decision.is_empty():brain.attack_decision.at = maxf(float(brain.attack_decision.at), now + .3)
		elif enemy.combat_state == CombatController.State.RECOVERY and u.combat.cooldown <= 0 and u.position.distance_to(enemy.position) < u.data.attack_range + 140:
			brain.next_initiative_at = minf(brain.next_initiative_at, now)
	elif b > .3 and brain.next_initiative_at > now:
		brain.next_initiative_at = now + (brain.next_initiative_at - now) * (1 - minf(.6, b * .6))
## Strongly reckless: presses the attack whenever it can, like the rush stance.
func charging(u) -> bool:return bias(u) > .45

## Target priority on top of the character's own choice: a guard goes for whoever is attacking
## a nearby ally, a cautious mind answers whoever is attacking it, a reckless one finishes off a
## badly hurt enemy within reach.
func pick_target(u, best):
	if not active(u):return best
	var foes: Array = u.enemies()
	if guards(u.data):
		var threat = null;var closest: float = INF
		for e in foes:
			var victim = e.combat.attack_target
			if victim == null or victim == u or victim.team != u.team or e.combat_state == CombatController.State.IDLE:continue
			var d: float = victim.position.distance_to(u.position)
			if d < 260 and d < closest:closest = d;threat = e
		if threat != null:return threat
	if cautious(u):
		for e in foes:
			if e.combat.attack_target == u and e.combat_state != CombatController.State.IDLE and u.position.distance_to(e.position) < u.data.attack_range + 160:return e
	if reckless(u):
		var reach: float = u.data.attack_range * 1.5 + 60
		for e in foes:
			if e.current_hp / maxf(1, e.max_hp) < .3 and u.position.distance_to(e.position) < reach:return e
	return best
