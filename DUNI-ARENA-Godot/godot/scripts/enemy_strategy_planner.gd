class_name EnemyStrategyPlanner
extends RefCounted
## Picks an enemy's special strategy at a turning point from its situation. Not every enemy uses
## one: the chance and the strength grow with tower progress (0 on the first floor, 1 on the top).
const LAST_FLOOR: float = 14
const MOVE_LIMIT: float = 320

static func progress(depth: int) -> float:return clampf(depth / LAST_FLOOR, 0, 1)
static func chance(p: float) -> float:return .25 + .45 * p

## Returns null when the enemy holds back this turning point.
static func plan(enemy: BattleUnit, p: float, rng: RandomNumberGenerator) -> EnemyTurningPlan:
	if rng.randf() >= chance(p):return null
	var foes: Array = enemy.battle.units.filter(func(u): return u.alive and u.team != enemy.team)
	var nearest: BattleUnit = null
	for foe in foes:
		if nearest == null or enemy.position.distance_to(foe.position) < enemy.position.distance_to(nearest.position):nearest = foe
	var gap: float = enemy.position.distance_to(nearest.position) if nearest != null else INF
	var ranged: bool = enemy.data.attack_range > 150
	var fights: bool = not enemy.data.tags.has("비전투")
	var has_ultimate: bool = enemy.data.ultimate_windup >= 0
	var ratio: float = enemy.current_hp / maxf(1, enemy.max_hp)
	var weights: Dictionary = {}
	if ratio < .65:weights[EnemyTurningPlan.HEAL] = (.65 - ratio) * 6
	if fights and gap < 150 * enemy.combat_scale():weights[EnemyTurningPlan.SMASH] = 1.4 if not ranged else .6
	if fights and gap >= 110 and gap < 340:weights[EnemyTurningPlan.CLEAVE] = 1.2 if not ranged else .5
	if nearest != null and (ranged and gap < 150 or not ranged and gap > 260):weights[EnemyTurningPlan.MOVE] = 1.6 if ranged else 1.0
	if has_ultimate and enemy.ultimate_gauge < 80:weights[EnemyTurningPlan.CHARGE] = 1.0
	if (has_ultimate or enemy.data.type_id == 7) and enemy.ultimate_gauge < 100 and p >= .2:weights[EnemyTurningPlan.OVERCHARGE] = .4 + 1.2 * p
	if weights.is_empty():return null
	var total: float = 0
	for w in weights.values():total += w
	var roll: float = rng.randf() * total
	var kind: StringName = weights.keys().back()
	for key in weights:
		roll -= weights[key]
		if roll < 0:kind = key;break
	var result := EnemyTurningPlan.new()
	result.plan_type = kind
	var power: float = enemy.attack_power
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
		EnemyTurningPlan.MOVE:
			var to: Vector2 = StrategyMovementController.safest_position(enemy, rng) if ranged else nearest.position - (nearest.position - enemy.position).normalized() * enemy.data.attack_range * .8
			to = MovementController.clamp_position(enemy.position + (to - enemy.position).limit_length(MOVE_LIMIT))
			result.metadata = {"from": CharacterPersistence.point(enemy.position), "to": CharacterPersistence.point(to)}
	return result
