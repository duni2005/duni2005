class_name RoomState
extends RefCounted
## A single encounter, not a map or a generator. No Unit/scene references.
var source_run_id: String = ""
var room_id: String
var cleared: bool = false
var enemy_state: Dictionary = {} # enemy_id -> EnemyRoomState, including the dead
var battle_attempt_count: int = 0
var active_result_id: String = ""
var settled_result_ids: Dictionary = {}

func _init(id: String = "test_room_01") -> void:
	room_id = id

func add_enemy(id: String, data: UnitData, at: Vector2) -> EnemyRoomState:
	if id.is_empty() or enemy_state.has(id) or data == null or active_result_id != "" or cleared:
		return null
	var enemy := EnemyRoomState.new()
	enemy.enemy_id = id
	enemy.unit_type_id = data.type_id
	enemy.current_hp = data.max_hp
	enemy.position = at
	enemy_state[id] = enemy
	return enemy

func living_enemies() -> Array[EnemyRoomState]:
	var result: Array[EnemyRoomState] = []
	for enemy in enemy_state.values():
		if enemy.alive:
			result.append(enemy)
	return result

# Phase9 route metadata. Standalone Phase4 rooms keep defaults.
var floor_index: int = -1
var chapter_index: int = 1
var lane: int = 0
var room_type: StringName = RoomType.BATTLE
var discovered: bool = false
var visited: bool = false
var consumed: bool = false
var publicly_visible: bool = false
var event_type: StringName = &""
var encounter: EncounterState
var gold_reward: int = 0
var token_reward: int = 0
var kill_rewards: Dictionary = {}
var reward_claimed: bool = false
func visible_kind() -> StringName:
	return room_type if discovered or publicly_visible else &"hidden"

var recruit: RecruitState
var shop: ShopState
var event: EventState
var content_visits: int = 0
