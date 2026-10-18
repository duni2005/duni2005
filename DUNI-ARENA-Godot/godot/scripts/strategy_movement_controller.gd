class_name StrategyMovementController
extends RefCounted
## Port of safestPosition, start/advanceStrategyEscapeDash and fleeing moveStrategy.
## Shared by enemy turning plans and allied strategy-card escape commands.
static func opponents(unit) -> Array:
	return unit.battle.units.filter(func(v): return v.alive and v.team != unit.team)

static func safest_position(unit, rng: RandomNumberGenerator) -> Vector2:
	var best: Vector2 = unit.position
	var best_score: float = -INF
	var enemies: Array = opponents(unit)
	for x in range(85, 716, 90):
		for y in range(85, 716, 90):
			var point := Vector2(x + rng.randf_range(-15, 15), y + rng.randf_range(-15, 15))
			var clearance: float = 400.0
			if not enemies.is_empty():
				clearance = INF
				for enemy in enemies:
					clearance = minf(clearance, point.distance_to(enemy.position))
			var occupied: int = 0
			for other in unit.battle.units:
				if other != unit and other.alive and point.distance_to(other.position) < 65:
					occupied += 1
			var score: float = clearance - occupied * 90 + minf(point.distance_to(unit.position), 400) * 0.1
			if score > best_score:
				best = point
				best_score = score
	return best

static func begin_retreat(unit, rng: RandomNumberGenerator, duration: float = 6.0) -> void:
	unit.command_retreat_until = unit.battle.clock.elapsed + duration
	unit.retreat_point = safest_position(unit, rng)
	unit.strategy_heading = Vector2.ZERO
	if unit.battle.full_characters_enabled:unit.brain.heading=Vector2.ZERO
	var enemies: Array = opponents(unit)
	var best: Vector2 = unit.retreat_point
	var best_score: float = -INF
	for index in range(16):
		var point: Vector2 = (unit.position + Vector2.from_angle(index * PI / 8) * 260).clamp(Vector2(35, 35), Vector2(765, 765))
		var distance: float = point.distance_to(unit.position)
		if distance < 80:
			continue
		var clearance: float = 300.0
		if not enemies.is_empty():
			clearance = INF
			for enemy in enemies:
				clearance = minf(clearance, point.distance_to(enemy.position))
		var route: int = 0
		for other in unit.battle.units:
			if other != unit and other.alive and other.position.distance_to(Geometry2D.get_closest_point_to_segment(other.position, unit.position, point)) < 54:
				route += 1
		var score: float = clearance - route * 55 - point.distance_to(unit.retreat_point) * 0.2
		if score > best_score:
			best = point
			best_score = score
	unit.strategy_dash = {"direction": (best - unit.position).normalized(), "remaining": best.distance_to(unit.position), "speed": 720.0}
	unit.velocity = Vector2.ZERO

static func advance(unit, delta: float) -> bool:
	if not unit.strategy_dash.is_empty():
		if unit.battle.full_characters_enabled:unit.brain.heading=Vector2.ZERO
		var before: Vector2 = unit.position
		var distance: float = minf(unit.strategy_dash.remaining, unit.strategy_dash.speed * delta)
		unit.position = MovementController.clamp_position(before + unit.strategy_dash.direction * distance)
		unit.strategy_dash.remaining -= unit.position.distance_to(before)
		unit.velocity = (unit.position - before) / delta
		if unit.strategy_dash.remaining < 1 or before.distance_to(unit.position) < 0.01:
			unit.strategy_dash.clear()
		return true
	if unit.command_retreat_until <= unit.battle.clock.elapsed:
		return false
	var enemies: Array = opponents(unit)
	if unit.position.distance_to(unit.retreat_point) < 50 or enemies.any(func(e): return e.position.distance_to(unit.retreat_point) < 130):
		unit.retreat_point = safest_position(unit, unit.battle.rng)
	var direction: Vector2 = (unit.retreat_point - unit.position).normalized() * 1.25
	if unit.battle.full_characters_enabled:
		unit.brain.movement_override="forced_retreat"
		unit.brain.steer(unit,direction,delta,1.25,"strategy");unit.strategy_heading=unit.brain.heading
		return true
	for other in unit.battle.units:
		if other == unit or not other.alive:
			continue
		var d: float = unit.position.distance_to(other.position)
		if d < 55:
			direction += (unit.position - other.position).normalized() * (55 - d) / 22
	if unit.position.x < 55: direction.x += (55 - unit.position.x) / 30
	if unit.position.x > 745: direction.x -= (unit.position.x - 745) / 30
	if unit.position.y < 55: direction.y += (55 - unit.position.y) / 30
	if unit.position.y > 745: direction.y -= (unit.position.y - 745) / 30
	if direction.length() > 1: direction = direction.normalized()
	unit.strategy_heading = unit.strategy_heading.lerp(direction, 1.0 - exp(-delta * 9))
	var before: Vector2 = unit.position
	unit.position = MovementController.clamp_position(before + unit.strategy_heading * unit.move_speed * 1.25 * delta)
	unit.velocity = (unit.position - before) / delta
	return true
