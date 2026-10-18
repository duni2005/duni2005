class_name DeploymentPlan
extends RefCounted
## Editable pure draft. Never settles battles or changes guild member state.
var guild: GuildManager
var _entries: Array[DeploymentEntry] = []
var _blockers: Array[Vector2] = []

func _init(manager: GuildManager, enemy_positions: Array[Vector2] = []) -> void:
	guild = manager
	_blockers.assign(enemy_positions)

func entries() -> Array[DeploymentEntry]:
	var result: Array[DeploymentEntry] = []
	for entry in _entries:
		result.append(entry.copy())
	return result

func get_entry(member_id: String) -> DeploymentEntry:
	for entry in _entries:
		if entry.member_id == member_id:
			return entry.copy()
	return null

func place(member_id: String, point: Vector2) -> DeploymentRules.Code:
	var entry := DeploymentEntry.new(member_id, point)
	var error: DeploymentRules.Code = DeploymentRules.validate(guild, entry, _entries, _blockers)
	if error == DeploymentRules.Code.OK:
		_entries.append(entry)
	return error

func move(member_id: String, point: Vector2) -> DeploymentRules.Code:
	var entry := DeploymentEntry.new(member_id, point)
	var error: DeploymentRules.Code = DeploymentRules.validate(guild, entry, _entries, _blockers, true)
	if error == DeploymentRules.Code.OK:
		for existing in _entries:
			if existing.member_id == member_id:
				existing.position = point
	return error

func remove(member_id: String) -> bool:
	for index in range(_entries.size()):
		if _entries[index].member_id == member_id:
			_entries.remove_at(index)
			return true
	return false

func clear() -> void:
	_entries.clear()

func restore(formation: FormationState) -> int:
	clear()
	if formation == null:
		return 0
	for saved in formation.snapshot():
		var member: GuildMemberState = guild.get_member(saved.member_id)
		if member == null or not member.is_alive() or get_entry(saved.member_id) != null:
			continue
		var free: Dictionary = FormationPositionFinder.find(saved.position, _entries, _blockers)
		if free.found:
			place(saved.member_id, free.position)
	return _entries.size()

func launch(battle: BattleManager, enemies: Array[Dictionary], seed_value: int = -1) -> bool:
	if battle == null or battle.started:
		return false
	# Authoritative enemy blockers come from the actual battle request, not UI Nodes.
	var enemy_points: Array[Vector2] = []
	for enemy in enemies:
		if not enemy.get("position") is Vector2 or not enemy.get("data") is UnitData or int(enemy.get("team", 1)) == 0 or enemy.has("member"):
			return false
		enemy_points.append(enemy.position)
	if DeploymentRules.validate_all(guild, _entries, enemy_points) != DeploymentRules.Code.OK:
		return false
	var payload: Array[Dictionary] = []
	for entry in _entries:
		payload.append(entry.battle_payload())
	var starting_formation := FormationState.new()
	starting_formation.capture(_entries)
	if not battle.start_guild_battle(guild, payload, enemies, seed_value):
		return false
	# Capture successful starts only; no battle end positions or unsent edits.
	guild.state.last_formation = starting_formation
	return true
