class_name EnemyPlanExecutor
extends RefCounted
## Effects use persistent actor IDs; nodes are looked up only while executing.
const SMASH_ARC: float = deg_to_rad(55) # half-angle of the smash fan
const CLEAVE_SPEED: float = 1100
static func find_enemy(battle: BattleManager, id: String) -> BattleUnit:
	for unit in battle.units:
		if unit.source_enemy_id == id and unit.alive and unit.team == 1:
			return unit
	return null

static func find_member(battle: BattleManager, id: String) -> BattleUnit:
	for unit in battle.units:
		if unit.source_member_id == id and unit.alive and unit.team == 0:
			return unit
	return null

static func execute(plan: EnemyTurningPlan, battle: BattleManager) -> Dictionary:
	if plan.executed or battle.finished:
		return {}
	plan.executed = true
	var enemy: BattleUnit = find_enemy(battle, plan.source_enemy_id)
	if enemy == null:
		return {}
	var m: Dictionary = plan.metadata
	match plan.plan_type:
		EnemyTurningPlan.HEAL:
			StrategyEffects.heal(enemy, enemy.max_hp * float(m.amount))
		EnemyTurningPlan.CHARGE:
			if not battle.common_combat_enabled or not StatusController.skill_charge_blocked(enemy):
				if battle.full_characters_enabled:enemy.ultimate.gain(enemy, float(m.gauge))
				else:enemy.ultimate_gauge = clampf(enemy.ultimate_gauge + float(m.gauge), 0, 100)
		EnemyTurningPlan.MOVE, EnemyTurningPlan.EVADE:
			StrategyCommandExecutor.cancel_intent(enemy)
			var to: Vector2 = CharacterPersistence.vector(m.to, enemy.position)
			enemy.strategy_dash = {"direction": (to - enemy.position).normalized(), "remaining": to.distance_to(enemy.position), "speed": 720.0}
		EnemyTurningPlan.SMASH, EnemyTurningPlan.CLEAVE, EnemyTurningPlan.SLASH, EnemyTurningPlan.SWEEP:
			StrategyCommandExecutor.cancel_intent(enemy)
			m["kind"] = plan.plan_type
			m["age"] = 0.0
			enemy.strategy_cast = m
		EnemyTurningPlan.OVERCHARGE:
			StrategyCommandExecutor.cancel_intent(enemy)
			if m.get("mode") == "temporary_boost":
				enemy.strategy_special_until = battle.clock.elapsed + float(m.duration)
				enemy.combat.cooldown = 0.0
				# The shotgun Ability reads these exact ammo/reload runtime fields.
				enemy.character_specific_state["ammo"] = m.ammo
				enemy.character_specific_state["reloadRemaining"] = m.reloadRemaining
			else:
				if not battle.common_combat_enabled or not StatusController.skill_charge_blocked(enemy):
					if battle.full_characters_enabled:enemy.ultimate.gain(enemy,100)
					else:enemy.ultimate_gauge = clampf(enemy.ultimate_gauge + 100.0, 0, 100)
				# UltimateController owns think; this is a one-shot strategy readiness request.
				enemy.ultimate.think=0
				enemy.character_specific_state["ultReadyAge"] = 5.0
				enemy.character_specific_state["strategyUltimateReady"] = true
				return {"source_enemy_id": enemy.source_enemy_id, "unit_type_id": enemy.data.type_id, "request": m}
	return {}

## Seconds a cast holds its warning before it lands.
static func windup(cast: Dictionary) -> float:return float(cast.get("windup", EnemyTurningPlan.WINDUP))

## Runs a smash, cleave, slash or sweep after the turning point: the unit holds still through the
## warning, then strikes. Returns true while the strategy owns the unit this frame.
static func advance(unit: BattleUnit, delta: float) -> bool:
	var cast: Dictionary = unit.strategy_cast
	if cast.is_empty():
		return false
	var battle: BattleManager = unit.battle
	cast.age = float(cast.age) + delta
	unit.velocity = Vector2.ZERO
	if cast.kind in [EnemyTurningPlan.SLASH, EnemyTurningPlan.SWEEP]:
		var center: Vector2 = CharacterPersistence.vector(cast.center, unit.position)
		if center.distance_to(unit.position) > 1:unit.facing = (center - unit.position).angle()
		if cast.age < windup(cast):
			return true
		var reach: float = float(cast.radius);var damage: float = float(cast.damage);var sweep: bool = cast.kind == EnemyTurningPlan.SWEEP
		var gather: Vector2 = CharacterPersistence.vector(cast.get("gather", {}), center)
		unit.strategy_cast = {}
		for foe in battle.units.filter(func(u): return u.alive and u.team != unit.team):
			if foe.position.distance_to(center) > reach + 20 * foe.combat_scale():continue
			battle.damage_resolver.resolve(unit, foe, damage, {"impulse": 0 if sweep else 220, "visible_hazard": true, "dmg": &"strategy_sweep" if sweep else &"strategy_slash"})
			# The sweep drags everyone it caught to one point (knockback slides about speed / 4.6).
			if sweep and foe.alive:KnockbackController.apply(foe, ((gather - foe.position) * 4.6).limit_length(KnockbackController.MAX_SPEED), unit)
		battle.emit_combat_event(&"ult_impact", center, {"actor": unit.actor_id(), "type": unit.data.type_id, "radius": reach})
		return true
	if cast.kind == EnemyTurningPlan.SMASH:
		unit.facing = float(cast.angle)
		if cast.age < windup(cast):
			return true
		# Hits can interrupt the striker (a parry, say) and clear the cast, so read it first.
		var forward := Vector2.from_angle(float(cast.angle));var reach: float = float(cast.range);var damage: float = float(cast.damage);var stun: float = float(cast.stun)
		unit.strategy_cast = {}
		for foe in battle.units.filter(func(u): return u.alive and u.team != unit.team):
			var offset: Vector2 = foe.position - unit.position
			if offset.length() <= reach + 20 * foe.combat_scale() and absf(forward.angle_to(offset)) <= SMASH_ARC:
				battle.damage_resolver.resolve(unit, foe, damage, {"impulse": 260, "visible_hazard": true, "dmg": &"strategy_smash"})
				if foe.alive:StatusController.stun(foe, stun)
		battle.emit_combat_event(&"ult_impact", unit.position + forward * reach * .5, {"actor": unit.actor_id(), "type": unit.data.type_id, "radius": reach})
		return true
	var from: Vector2 = CharacterPersistence.vector(cast.from, unit.position);var to: Vector2 = CharacterPersistence.vector(cast.to, unit.position)
	unit.facing = (to - from).angle()
	if cast.age < windup(cast):
		return true
	if not cast.has("hit"):
		cast["hit"] = []
		unit.strategy_dash = {"direction": (to - unit.position).normalized(), "remaining": to.distance_to(unit.position), "speed": CLEAVE_SPEED}
	StrategyMovementController.advance(unit, delta)
	var hit: Array = cast.hit;var half: float = float(cast.width) * .5;var damage: float = float(cast.damage)
	for foe in battle.units.filter(func(u): return u.alive and u.team != unit.team and u.battle_id not in hit):
		if foe.position.distance_to(unit.position) <= half + 25 * foe.combat_scale():
			hit.append(foe.battle_id)
			battle.damage_resolver.resolve(unit, foe, damage, {"impulse": 320, "visible_hazard": true, "dmg": &"strategy_cleave"})
	if unit.strategy_dash.is_empty() or cast.is_empty():
		unit.strategy_cast = {}
	return true
