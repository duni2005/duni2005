class_name StanceRules
extends RefCounted
## Every number of the player stances (rush / cautious / cover) in one place.
## These effects read the unit's stance only; the situational TacticalMind never turns them on.
## The Phase 1-7 golden harnesses (full characters off) keep the web values marked LEGACY.

# --- Damage dealt / taken ---------------------------------------------------------------
const RUSH_DAMAGE: float = 1.1
const RUSH_TAKEN: float = 1.2
const CAUTIOUS_DAMAGE: float = 1.0
const CAUTIOUS_TAKEN: float = .85
const COVER_DAMAGE: float = .85
const LEGACY_RUSH_DAMAGE: float = 1.25
const LEGACY_CAUTIOUS_DAMAGE: float = .8
const LEGACY_CAUTIOUS_TAKEN: float = 1.0

# --- Defense reactions (shifts of the parry / dodge / counter odds) -------------------------
const RUSH_PARRY: float = -.12
const RUSH_DODGE: float = -.07
const RUSH_COUNTER: float = 0
const LEGACY_RUSH_COUNTER: float = .12
const CAUTIOUS_PARRY: float = .09
const CAUTIOUS_DODGE: float = .05
const CAUTIOUS_COUNTER: float = -.12
const COVER_PARRY: float = .05
## Cautious parries succeed more often and are timed better.
const CAUTIOUS_PARRY_SUCCESS: float = 1.25
const PARRY_MISTAKE: float = .3
const CAUTIOUS_PARRY_MISTAKE: float = .15
## Time to read an attack's windup (x the unit's own read time).
const CAUTIOUS_READ: float = .72
const RUSH_READ: float = 1.45
## Projectiles: chance to notice one, and how far ahead (seconds) it is noticed.
const NOTICE: float = .84
const CAUTIOUS_NOTICE: float = .93
const RUSH_NOTICE: float = .50
const HORIZON: float = .46
const CAUTIOUS_HORIZON: float = .56
const RUSH_HORIZON: float = .28
## Sidestep window against a projectile in stance movement (x reaction time).
const CAUTIOUS_SIDESTEP: float = 1.35
const RUSH_SIDESTEP: float = .65
const CAUTIOUS_DEFENSIVE_SIDESTEP: float = 1.2
## Bomb escape: notice roll needed to run from a fusing bomb.
const BOMB_NOTICE: float = .62
const CAUTIOUS_BOMB_NOTICE: float = .8
const RUSH_BOMB_NOTICE: float = .35
## Chance a hit is dodged outright while cautious (cooldown in seconds).
const CAUTIOUS_DODGE_CHANCE: float = .1
const CAUTIOUS_DODGE_COOLDOWN: float = 3
## Role dodges (archer, assassin ...) happen this much less often while rushing.
const RUSH_ROLE_DODGE: float = .5
## Dodge step speed while cautious.
const CAUTIOUS_DODGE_SPEED: float = 1.1

# --- Counter boost (cautious only) ----------------------------------------------------------
## After a dodge or a parry, the next hit within the window deals more damage; more when the
## blocked attack came from a rushing unit. It does not stack; a new block refreshes it.
const COUNTER_WINDOW: float = 3
const COUNTER_BONUS: float = .5
const COUNTER_BONUS_VS_RUSH: float = 1.0

# --- Area judgment (escape / safe zones) ----------------------------------------------------
const RUSH_FIGHT: float = 1.6
const RUSH_ESCAPE: float = .2
const RUSH_SUPPORT: float = .3
const CAUTIOUS_ESCAPE: float = .9

# --- Rush behavior --------------------------------------------------------------------------
## Straight approach: tiny side sway on the way in.
const RUSH_SIDE: float = .05
const RUSH_SWAY: float = .05
const RUSH_SPEED: float = 1.07
## Attack as soon as the target is in reach (seconds before the swing starts).
const RUSH_INTENT_DELAY: Vector2 = Vector2(0, .08)
## Ranged rushers walk in to half their range, at most this close.
const RUSH_RANGED_DISTANCE: float = 110

# --- Cautious behavior ----------------------------------------------------------------------
const CAUTIOUS_INTENT: float = 1.15
const CAUTIOUS_INITIATIVE: float = 1.25
## Preferred share of the attack range for back-line positions.
const CAUTIOUS_REAR_RANGE: float = .92
const REAR_RANGE: float = .86
## Waits this long for the enemy to swing first before taking the initiative anyway.
const CAUTIOUS_FIRST_WAIT: float = 4
## Sideways share of the approach (curves in, aiming at the target's flank).
const CAUTIOUS_FLANK: float = .9
const CAUTIOUS_COUNTER_FLANK: float = .5
## A target that gets this far beyond attack range is not chased; the unit walks back to
## where it last fought and waits there up to CAUTIOUS_HOME_TIME before closing in again.
const CAUTIOUS_LEASH: float = 90
const CAUTIOUS_HOME_TIME: float = 3
## Formation: drifts back toward the nearest ally beyond this distance.
const CAUTIOUS_COHESION: float = 120
const CAUTIOUS_COHESION_PULL: float = 1.0
## Back-line stations score this much per pixel beyond formation distance.
const CAUTIOUS_REAR_COHESION: float = 1.2
## Avoids spots where two or more enemies are this close.
const CAUTIOUS_EXPOSURE: float = 230
const CAUTIOUS_EXPOSURE_PUSH: float = .7
## Target choice: each other enemy near a candidate counts as this much extra distance.
const CAUTIOUS_ISOLATION_RADIUS: float = 200
const CAUTIOUS_ISOLATION_WEIGHT: float = 120
## Share of a step straight away from the target right after each attack (back line and
## spacing movement).
const CAUTIOUS_SHOT_STEP: float = .9
## Backs off facing the enemy, a little slower than walking forward.
const CAUTIOUS_BACKPEDAL: float = .85

static func full(unit) -> bool:return unit.battle != null and unit.battle.full_characters_enabled
## Multiplier on damage dealt (part of attack %).
static func damage(unit) -> float:
	match unit.stance:
		CombatStance.RUSH:return RUSH_DAMAGE if full(unit) else LEGACY_RUSH_DAMAGE
		CombatStance.CAUTIOUS:return CAUTIOUS_DAMAGE if full(unit) else LEGACY_CAUTIOUS_DAMAGE
		CombatStance.COVER:return COVER_DAMAGE
	return 1.0
## Multiplier on damage taken.
static func taken(unit) -> float:
	match unit.stance:
		CombatStance.RUSH:return RUSH_TAKEN
		CombatStance.CAUTIOUS:return CAUTIOUS_TAKEN if full(unit) else LEGACY_CAUTIOUS_TAKEN
	return 1.0
## Parry / dodge / counter shifts of the reaction odds.
static func reaction(unit) -> Vector3:
	match unit.stance:
		CombatStance.RUSH:return Vector3(RUSH_PARRY, RUSH_DODGE, RUSH_COUNTER if full(unit) else LEGACY_RUSH_COUNTER)
		CombatStance.CAUTIOUS:return Vector3(CAUTIOUS_PARRY, CAUTIOUS_DODGE, CAUTIOUS_COUNTER)
		CombatStance.COVER:return Vector3(COVER_PARRY, 0, 0)
	return Vector3.ZERO
## Picks one of three values by stance: normal, cautious, rush.
static func pick(unit, normal: float, cautious: float, rush: float) -> float:
	return cautious if unit.stance == CombatStance.CAUTIOUS else rush if unit.stance == CombatStance.RUSH else normal

## A cautious unit that dodged or parried `source` readies its counter.
static func grant_counter(unit, source) -> void:
	if unit.stance != CombatStance.CAUTIOUS or not unit.alive:return
	var vs_rush: bool = is_instance_valid(source) and source.stance == CombatStance.RUSH
	unit.set_state("counterBoostUntil", unit.battle.clock.elapsed + COUNTER_WINDOW)
	unit.set_state("counterBoostBonus", COUNTER_BONUS_VS_RUSH if vs_rush else COUNTER_BONUS)
	unit.set_state("counterBoosts", unit.state_value("counterBoosts") + 1)
static func counter_ready(unit) -> bool:return unit.state_value("counterBoostUntil") > unit.battle.clock.elapsed
## Damage factor of the unit's next hit; spends the counter.
static func spend_counter(unit) -> float:
	if not is_instance_valid(unit) or not counter_ready(unit):return 1.0
	var bonus: float = unit.state_value("counterBoostBonus")
	unit.set_state("counterBoostUntil", 0)
	return 1 + bonus
