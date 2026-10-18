class_name TowerRunState
extends RefCounted
## Map progression owns neither UI Nodes nor combat instances.
var map := TowerMapState.new()
var current_chapter: int = 1
var unlocked_floor: int = 0
var selected_room_id: String = ""
var phase: StringName = &"route"
var visited_rooms: Dictionary = {}
var cleared_rooms: Dictionary = {}
var floor_conquest: Dictionary = {}
var chapter_progress: Dictionary = {}
var reward_requests: Array[RewardRequest] = []
var result: StringName = &""
var conquered: bool = false
var processed_results: Dictionary = {}

var map_scroll_y: int = 0

var last_content_outcome: Dictionary = {}
