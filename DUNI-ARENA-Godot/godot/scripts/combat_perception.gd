class_name CombatPerception
extends RefCounted
## Target visibility is independent of the 240-degree attack warning cone.
const HALF_VIEW: float = TAU / 3.0
static func can_perceive(observer, target) -> bool:
	if not is_instance_valid(target) or not target.alive: return false
	return not target.unavailable() and (observer.team == target.team or (target.state_value("shadowTime")<=0 and (not concealed(target) or (target.battle.full_characters_enabled and observer.position.distance_to(target.position)<=160))))
static func in_attack_view(unit, point: Vector2) -> bool:
	return absf(wrapf((point - unit.position).angle() - unit.facing, -PI, PI)) <= HALF_VIEW + 1e-6
static func can_see_attack(unit, source, point: Vector2, hidden: bool = false) -> bool:
	return not hidden and is_instance_valid(source) and not concealed(source) and can_perceive(unit, source) and in_attack_view(unit, point)

static func concealed(unit) -> bool:
	if not unit.alive:return false
	return unit.state_value("shadowTime")>0 or (unit.data.tags.has("기습형") and unit.state_value("revealTime")<=0 and unit.combat_state==CombatController.State.IDLE) if unit.battle.full_characters_enabled else unit.hidden_from_enemies
