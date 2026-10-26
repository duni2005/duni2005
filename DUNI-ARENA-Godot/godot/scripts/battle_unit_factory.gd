class_name BattleUnitFactory
extends RefCounted
## Creation adapter. The battle manager never unpacks member HP/gauges/state itself.

var unit_scene: PackedScene

func _init(scene: PackedScene) -> void:
	unit_scene = scene

static func guild_placement(guild: GuildManager, member_id: String, position: Vector2, team: int = 0) -> Dictionary:
	var member: GuildMemberState = guild.get_member(member_id)
	var data: UnitData = guild.definition(member.unit_type_id) if member != null else null
	if not position.is_finite() or not UnitStateCodec.can_spawn(member, data):
		return {}
	var result: Dictionary={"data": data, "member": member, "source_run_id": guild.state.run_id, "position": position, "team": team}
	if guild.state.tower!=null:result["combat_stats"]=guild.member_stats(member)
	return result

static func validate_placements(placements: Array[Dictionary]) -> Dictionary:
	var seen: Dictionary = {}
	var run_id: String = ""
	var seen_enemies: Dictionary = {}
	var room_id: String = ""
	for placement in placements:
		if not placement.get("data") is UnitData or not placement.get("position") is Vector2:
			return {"ok": false}
		if placement.get("combat_stats") != null:
			if not placement.combat_stats is UnitCombatStats: return {"ok": false}
			var stats: UnitCombatStats = placement.combat_stats
			if not [stats.max_hp, stats.attack, stats.defense, stats.speed, stats.scale].all(func(v):return is_finite(v)) or stats.max_hp <= 0 or stats.attack < 0 or stats.defense < 0 or stats.speed < 0 or stats.scale <= 0: return {"ok": false}
		var data: UnitData = placement.data
		var point: Vector2 = placement.position
		if not point.is_finite() or not is_finite(data.max_hp) or data.max_hp <= 0.0 or not data.attack_profile:
			return {"ok": false}
		if placement.has("enemy"):
			if placement.has("member") or not placement.enemy is EnemyRoomState or not placement.get("source_room_id") is String:
				return {"ok": false}
			var enemy: EnemyRoomState = placement.enemy
			var source_room_id: String = placement.source_room_id
			if source_room_id.is_empty() or not EnemyStateCodec.valid(enemy, data) or not enemy.alive or seen_enemies.has(enemy.enemy_id):
				return {"ok": false}
			if not room_id.is_empty() and room_id != source_room_id:
				return {"ok": false}
			room_id = source_room_id
			seen_enemies[enemy.enemy_id] = true
		if placement.has("member"):
			if not placement.member is GuildMemberState or not placement.get("source_run_id") is String:
				return {"ok": false}
			var member: GuildMemberState = placement.member
			var source_run_id: String = placement.source_run_id
			if source_run_id.is_empty() or not UnitStateCodec.can_spawn(member, data) or seen.has(member.member_id):
				return {"ok": false}
			if not run_id.is_empty() and run_id != source_run_id:
				return {"ok": false}
			run_id = source_run_id
			seen[member.member_id] = true
	return {"ok": true, "source_run_id": run_id}

func create(placement: Dictionary, battle_id: int, battle, rng: RandomNumberGenerator) -> BattleUnit:
	if not validate_placements([placement]).ok:
		return null
	var unit: BattleUnit = unit_scene.instantiate()
	unit.initialize(battle_id, int(placement.get("team", 0)), placement.data, placement.position, rng, battle)
	if placement.get("combat_stats") is UnitCombatStats:
		unit.combat_stats = placement.combat_stats
		unit.move_speed *= unit.combat_stats.speed / unit.data.move_speed
		unit.current_hp = unit.max_hp
		unit.healing_power=unit.combat_stats.healing_power;unit.healing_received=unit.combat_stats.healing_received
		unit.vigor_totem_count=unit.combat_stats.vigor_totem_count
		unit.charge_totem_count=unit.combat_stats.charge_totem_count
		unit.fang_count=unit.combat_stats.fang_count
		unit.opening_awl_count=unit.combat_stats.opening_awl_count
		unit.victory_gold=unit.combat_stats.victory_gold
	if placement.has("member"):
		UnitStateCodec.inject(unit, placement.member, placement.source_run_id)
	if placement.has("enemy"):
		EnemyStateCodec.inject(unit, placement.enemy, placement.source_room_id)
	unit.deployment_position=unit.position
	return unit
