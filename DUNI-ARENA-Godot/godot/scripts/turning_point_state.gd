class_name TurningPointState
extends RefCounted
## One occurrence, never stored in RunState/RoomState/EnemyRoomState.
enum Phase { SLOWDOWN, PAUSED, RESOLVED, CANCELLED }
var turning_point_id: String = ""
var phase: Phase = Phase.SLOWDOWN
var trigger_simulation_time: float = 0.0
var remaining_real_time: float = 0.0
var enemy_plans: Array[EnemyTurningPlan] = []
var selected_member_id: String = ""
var resolved: bool = false
var selected_card_id: int = 0
var selection_serial: int = 0
var selected_request_id: String = ""
var pending_commands: Array[StrategyCommand] = []
var last_card_result: Dictionary = {}
