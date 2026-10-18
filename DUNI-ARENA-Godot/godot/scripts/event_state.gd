class_name EventState
extends RefCounted
var event_type: StringName
var choices: Array[StringName] = []
var selected_choice: StringName = &""
var resolved: bool = false
var reward_receipt: String = ""
var outcome: Dictionary = {}
var promotion_limit: int = 0
var promotion_used: int = 0
var selected_members: Array[String] = []
var treasure_kind: StringName = &""
var treasure_reward: StringName = &""
var prediction: PredictionState
