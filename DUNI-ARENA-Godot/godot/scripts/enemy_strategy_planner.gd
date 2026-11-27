class_name EnemyStrategyPlanner
extends RefCounted
## Picks an enemy's special strategy at a turning point. Each turning point has an intensity from
## the tower's progress (chapter and floor) and the room (miniboss and chapter boss rooms weigh
## more). Intensity raises the chance that an enemy acts and shifts its pick from 일반 toward
## 주의 and 위험 strategies; the more enemies there are, the less likely each one is to act.
## Ranks (0.99.10): 보스 units only use 위험 and 고위험; 고위험 is for 보스급 (보스 and 미니보스) only.
const LAST_FLOOR: float = 14
const MOVE_LIMIT: float = 320
const ROOM_WEIGHT = {&"miniboss":.15, &"boss":.3}
const RANK_BONUS = {&"elite":.1, &"boss":.25}
## 참격: a circle in front of the enemy. 휩쓸어 모으기: a wide circle around it.
const SLASH_RADIUS: float = 85
const SWEEP_RADIUS: float = 210

static func progress(depth: int) -> float:return clampf(depth / LAST_FLOOR, 0, 1)
static func intensity(depth: int, room_type: StringName = &"battle") -> float:return progress(depth) + float(ROOM_WEIGHT.get(room_type, 0))
## Chance that one enemy acts at a turning point: rare low in the tower, common at the top.
static func act_chance(i: float, enemy_count: int = 3, rank: StringName = &"normal") -> float:
	var crowd: float = clampf(sqrt(3.0 / maxi(1, enemy_count)), .55, 1.5)
	return clampf((.06 + .6 * i) * crowd + float(RANK_BONUS.get(rank, 0)), 0, .9)
## Relative weight of each grade. Low in the tower mostly 일반 with a little 주의 and 위험; the
## average grade rises with intensity. 보스 units: 위험 and 고위험 only; 고위험 for 보스급 only.
static func tier_weights(i: float, rank: StringName = &"normal") -> Dictionary:
	var p: float = clampf(i, 0, 1)
	if rank == &"boss":return {EnemyTurningPlan.NORMAL:0.0, EnemyTurningPlan.CAUTION:0.0, EnemyTurningPlan.DANGER:1.0, EnemyTurningPlan.HIGH:.5 + .8 * p}
	return {EnemyTurningPlan.NORMAL:maxf(.3, 1.0 - .65 * p), EnemyTurningPlan.CAUTION:.12 + .8 * p, EnemyTurningPlan.DANGER:.08 + .9 * p, EnemyTurningPlan.HIGH:maxf(0, p - .2) * .8 if rank == &"elite" else 0.0}
## How many 고위험 strategies one turning point may hold.
static func high_cap(i: float, room_type: StringName = &"battle") -> int:
	return int(i >= .3) + int(i >= .9) + int(room_type == &"boss")

## Returns null when the enemy holds back this turning point.
static func plan(enemy: BattleUnit, i: float, rng: RandomNumberGenerator, enemy_count: int = 3, rank: StringName = &"normal", allow_high: bool = true) -> EnemyTurningPlan:
	# A boss with its own strategy uses it at every turning point (no roll, no grade cap).
	if EnemyTurningPlan.EXCLUSIVE.has(enemy.data.type_id):return exclusive(enemy, i)
	if rng.randf() >= act_chance(i, enemy_count, rank):return null
	var p: float = clampf(i, 0, 1)
	var foes: Array = enemy.battle.units.filter(func(u): return u.alive and u.team != enemy.team)
	var nearest: BattleUnit = null
	for foe in foes:
		if nearest == null or enemy.position.distance_to(foe.position) < enemy.position.distance_to(nearest.position):nearest = foe
	var gap: float = enemy.position.distance_to(nearest.position) if nearest != null else INF
	var ranged: bool = enemy.data.attack_range > 150
	var fights: bool = not enemy.data.tags.has("비전투")
	var has_ultimate: bool = enemy.data.ultimate_windup >= 0
	var ratio: float = enemy.current_hp / maxf(1, enemy.max_hp)
	var sweep_reach: float = SWEEP_RADIUS * sqrt(enemy.combat_scale())
	var weights: Dictionary = {}
	if ratio < .65:weights[EnemyTurningPlan.HEAL] = (.65 - ratio) * 6
	if fights and gap < 150 * enemy.combat_scale():weights[EnemyTurningPlan.SMASH] = 1.4 if not ranged else .6
	if fights and gap >= 110 and gap < 340:weights[EnemyTurningPlan.CLEAVE] = 1.2 if not ranged else .5
	if fights and gap < 260:weights[EnemyTurningPlan.SLASH] = 1.2 if not ranged else .7
	if nearest != null and not ranged and gap > 260:weights[EnemyTurningPlan.MOVE] = 1.0
	if nearest != null and (gap < 170 * enemy.combat_scale() and (ranged or ratio < .5)):weights[EnemyTurningPlan.EVADE] = 1.6 if ranged else 1.0
	if has_ultimate and enemy.ultimate_gauge < 80:weights[EnemyTurningPlan.CHARGE] = 1.0
	if (has_ultimate or enemy.data.type_id == 7) and enemy.ultimate_gauge < 100 and p >= .2:weights[EnemyTurningPlan.OVERCHARGE] = .4 + 1.2 * p
	var caught: int = foes.filter(func(u): return u.position.distance_to(enemy.position) <= sweep_reach).size()
	if fights and allow_high and caught > 0:weights[EnemyTurningPlan.SWEEP] = .6 + .5 * caught
	# 0.99.10 strategies.
	var allies: Array = enemy.battle.units.filter(func(u): return u.alive and u.team == enemy.team)
	var wounded: BattleUnit = _wounded_ally(enemy, allies)
	if wounded != null and EnemyTurningPlan.usable(EnemyTurningPlan.MEND, enemy.data.type_id):weights[EnemyTurningPlan.MEND] = (1 - wounded.current_hp / maxf(1, wounded.max_hp)) * 4
	if fights and gap < 200 * enemy.combat_scale():weights[EnemyTurningPlan.SHOUT] = 1.0
	if enemy.state_value("shadowTime") <= 0:weights[EnemyTurningPlan.STEALTH] = .8 if ranged or ratio < .6 else .4
	weights[EnemyTurningPlan.UNITE] = .4 + .2 * allies.size()
	var lava_at = _cluster(foes, enemy.position, 420, EnemyTurningPlan.LAVA_RADIUS)
	if lava_at != null and EnemyTurningPlan.usable(EnemyTurningPlan.LAVA, enemy.data.type_id):weights[EnemyTurningPlan.LAVA] = 1.0
	var missile_reach: float = EnemyTurningPlan.MISSILE_RADIUS * sqrt(enemy.combat_scale())
	var missile_at = _cluster(foes, enemy.position, 560, missile_reach)
	if allow_high and missile_at != null and EnemyTurningPlan.usable(EnemyTurningPlan.MISSILE, enemy.data.type_id):weights[EnemyTurningPlan.MISSILE] = 1.2
	if weights.is_empty():return null
	# A grade first (by intensity and rank), then a strategy of that grade (by the situation).
	var grades: Dictionary = {}
	var grade_weights: Dictionary = tier_weights(i, rank)
	for kind in weights:
		var grade: StringName = EnemyTurningPlan.TIERS[kind];var w: float = float(grade_weights[grade])
		if w > 0:grades[grade] = w
	if grades.is_empty():return null
	var grade: StringName = _pick(grades, rng)
	var options: Dictionary = {}
	for kind in weights:
		if EnemyTurningPlan.TIERS[kind] == grade:options[kind] = weights[kind]
	var kind: StringName = _pick(options, rng)
	var result := EnemyTurningPlan.new()
	result.plan_type = kind
	# Damage before 공격력%, which the resolver applies.
	var power: float = UnitStatTable.damage_stat(enemy, UnitStatTable.main_kind(enemy.data.type_id))
	match kind:
		EnemyTurningPlan.HEAL:result.metadata = {"amount": snappedf(.2 + .1 * p, .01)}
		EnemyTurningPlan.CHARGE:result.metadata = {"gauge": roundf(20 + 10 * p)}
		EnemyTurningPlan.OVERCHARGE:result.metadata = EnemyTurningPlan.special_metadata(enemy.data.type_id)
		EnemyTurningPlan.SMASH:
			result.metadata = {"angle": (nearest.position - enemy.position).angle(), "range": 150 * enemy.combat_scale(), "damage": roundf(power * (2 + p)), "stun": 2.0}
		EnemyTurningPlan.CLEAVE:
			var direction: Vector2 = (nearest.position - enemy.position).normalized()
			var to: Vector2 = MovementController.clamp_position(enemy.position + direction * minf(gap + 60, 380))
			result.metadata = {"from": CharacterPersistence.point(enemy.position), "to": CharacterPersistence.point(to), "width": 64.0, "damage": roundf(power * (1.5 + .8 * p))}
		EnemyTurningPlan.SLASH:
			var center: Vector2 = enemy.position + (nearest.position - enemy.position).limit_length(140)
			result.metadata = {"center": CharacterPersistence.point(center), "radius": SLASH_RADIUS * enemy.combat_scale(), "damage": roundf(power * (1.3 + .6 * p))}
		EnemyTurningPlan.SWEEP:
			# Everyone caught is dragged to a point just in front of the enemy.
			var gather: Vector2 = MovementController.clamp_position(enemy.position + (nearest.position - enemy.position).normalized() * 60 * enemy.combat_scale())
			result.metadata = {"center": CharacterPersistence.point(enemy.position), "radius": sweep_reach, "gather": CharacterPersistence.point(gather), "damage": roundf(power * (2.4 + p)), "windup": EnemyTurningPlan.WINDUP_HIGH}
		EnemyTurningPlan.MEND:result.metadata = {"target": wounded.actor_id(), "amount": EnemyTurningPlan.MEND_AMOUNT}
		EnemyTurningPlan.SHOUT:
			result.metadata = {"angle": (nearest.position - enemy.position).angle(), "range": EnemyTurningPlan.SHOUT_RADIUS * enemy.combat_scale(), "damage": roundf(power * (1 + .5 * p)), "headwind": EnemyTurningPlan.SHOUT_TIME}
		EnemyTurningPlan.UNITE:result.metadata = {"shield": EnemyTurningPlan.UNITE_SHIELD, "time": EnemyTurningPlan.UNITE_TIME}
		EnemyTurningPlan.STEALTH:result.metadata = {"time": EnemyTurningPlan.STEALTH_TIME}
		EnemyTurningPlan.LAVA:
			# Per half-second tick on the pool, plus one burn stack.
			result.metadata = {"center": CharacterPersistence.point(lava_at), "radius": EnemyTurningPlan.LAVA_RADIUS * sqrt(enemy.combat_scale()), "damage": roundf(power * (.18 + .1 * p)), "time": EnemyTurningPlan.LAVA_TIME}
		EnemyTurningPlan.MISSILE:
			result.metadata = {"center": CharacterPersistence.point(missile_at), "radius": missile_reach, "damage": roundf(power * (2.6 + 1.2 * p)), "windup": EnemyTurningPlan.WINDUP_MISSILE}
		EnemyTurningPlan.MOVE, EnemyTurningPlan.EVADE:
			var to: Vector2 = StrategyMovementController.safest_position(enemy, rng) if kind == EnemyTurningPlan.EVADE else nearest.position - (nearest.position - enemy.position).normalized() * enemy.data.attack_range * .8
			to = MovementController.clamp_position(enemy.position + (to - enemy.position).limit_length(MOVE_LIMIT))
			result.metadata = {"from": CharacterPersistence.point(enemy.position), "to": CharacterPersistence.point(to)}
	return result

## A boss's own strategy (EnemyTurningPlan.EXCLUSIVE), aimed at the nearest foe; null with none.
static func exclusive(enemy: BattleUnit, i: float) -> EnemyTurningPlan:
	var nearest: BattleUnit = null
	for foe in enemy.battle.units:
		if foe.alive and foe.team != enemy.team and (nearest == null or enemy.position.distance_to(foe.position) < enemy.position.distance_to(nearest.position)):nearest = foe
	if nearest == null:return null
	var p: float = clampf(i, 0, 1);var power: float = UnitStatTable.damage_stat(enemy, UnitStatTable.main_kind(enemy.data.type_id))
	var result := EnemyTurningPlan.new();result.plan_type = EnemyTurningPlan.EXCLUSIVE[enemy.data.type_id]
	match result.plan_type:
		EnemyTurningPlan.SLUG:
			result.metadata = {"angle": (nearest.position - enemy.position).angle(), "range": EnemyTurningPlan.SLUG_RANGE * sqrt(enemy.combat_scale()), "near": EnemyTurningPlan.SLUG_NEAR * sqrt(enemy.combat_scale()), "damage": roundf(power * (EnemyTurningPlan.SLUG_BASE + EnemyTurningPlan.SLUG_PER_PROGRESS * p)), "windup": EnemyTurningPlan.WINDUP_HIGH}
	return result
## The most hurt ally (not the unit itself) within reach, below 80% HP; null when none.
static func _wounded_ally(enemy: BattleUnit, allies: Array) -> BattleUnit:
	var best: BattleUnit = null
	for a in allies:
		if a == enemy or a.position.distance_to(enemy.position) > 340 or a.current_hp >= a.max_hp * .8:continue
		if best == null or a.current_hp / maxf(1, a.max_hp) < best.current_hp / maxf(1, best.max_hp):best = a
	return best
## The foe position within `reach` of `from` whose circle of `radius` holds the most foes; null
## when no foe is in reach.
static func _cluster(foes: Array, from: Vector2, reach: float, radius: float):
	var best = null;var most: int = 0
	for f in foes:
		if f.position.distance_to(from) > reach:continue
		var n: int = foes.filter(func(o): return o.position.distance_to(f.position) <= radius).size()
		if n > most:most = n;best = f.position
	return best

static func _pick(weights: Dictionary, rng: RandomNumberGenerator) -> StringName:
	var total: float = 0
	for w in weights.values():total += w
	var roll: float = rng.randf() * total
	for key in weights:
		roll -= weights[key]
		if roll < 0:return key
	return weights.keys().back()
