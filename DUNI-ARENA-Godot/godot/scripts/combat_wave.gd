class_name CombatWave
extends RefCounted
## Simulation wave; no drawing or Node references, never persisted.
var kind: StringName
var origin: Vector2
var source_ids: Array[int] = []
var hit_ids: Dictionary = {}
var radius: float
var stun_duration: float
var force: float
var age: float = 0
var duration: float = .32
var life: float = .65
func advance(battle, delta: float) -> void:
	var previous: float = age
	age += delta
	life -= delta
	if previous >= duration: return
	var current_radius: float = radius*minf(1,age/duration)
	for unit in battle.units:
		if not unit.alive or hit_ids.has(unit.battle_id) or origin.distance_to(unit.position) > current_radius: continue
		var source = null
		for id in source_ids:
			var candidate = battle.find_unit(id)
			if candidate != null and candidate.team != unit.team:
				source = candidate
				break
		if source == null: continue
		hit_ids[unit.battle_id] = true
		StatusController.stun(unit,stun_duration)
		var direction: Vector2 = (unit.position-origin).normalized()
		KnockbackController.apply(unit,direction*force*(1-.25*clampf(origin.distance_to(unit.position)/radius,0,1)),source)
		battle.emit_combat_event(&"wave_stun",unit.position,{"kind":kind,"actor_id":unit.battle_id,"duration":stun_duration})
