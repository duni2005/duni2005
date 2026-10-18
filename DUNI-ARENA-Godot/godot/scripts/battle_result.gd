class_name BattleResult
extends RefCounted
## Detached final snapshot. Not a run result and contains no player/guild state.

var draw: bool
var winner_team: int
var elapsed: float
var survivors: Array[int] = []
var units: Array[Dictionary] = []
var completed: bool = false
var battle_result_id: String = ""
var source_run_id: String = ""
var participating_member_ids: Array[String] = []
var surviving_member_ids: Array[String] = []
var dead_member_ids: Array[String] = []
var final_hp_by_member_id: Dictionary = {}
var member_states: Dictionary = {} # Detached codec snapshots, no Unit references.

func capture_member(unit: BattleUnit) -> void:
	if unit.source_member_id.is_empty():
		return
	var member_id: String = unit.source_member_id
	participating_member_ids.append(member_id)
	if unit.alive:
		surviving_member_ids.append(member_id)
	else:
		dead_member_ids.append(member_id)
	final_hp_by_member_id[member_id] = unit.current_hp
	member_states[member_id] = UnitStateCodec.snapshot(unit)
	member_victory_gold[member_id]=unit.victory_gold

var room_id: String = ""
var end_reason: BattleEndReason.Value = BattleEndReason.Value.DRAW
var surviving_enemy_ids: Array[String] = []
var dead_enemy_ids: Array[String] = []
var enemy_states: Dictionary = {}
# Compatibility aliases; original Phase 1/2 result contract remains valid.
var result_id: String:
	get: return battle_result_id
var winning_team: int:
	get: return winner_team
var battle_time: float:
	get: return elapsed

func capture_enemy(unit: BattleUnit) -> void:
	if unit.source_enemy_id.is_empty():
		return
	if unit.alive:
		surviving_enemy_ids.append(unit.source_enemy_id)
	else:
		dead_enemy_ids.append(unit.source_enemy_id)
	enemy_states[unit.source_enemy_id] = EnemyStateCodec.snapshot(unit)

var member_victory_gold: Dictionary = {}
