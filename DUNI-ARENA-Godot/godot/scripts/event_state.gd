class_name EventState
extends RefCounted
var event_type: StringName
var choices: Array[StringName] = []
var selected_choice: StringName = &""
var resolved: bool = false
var reward_receipt: String = ""
var outcome: Dictionary = {}
var treasure_kind: StringName = &""
var treasure_reward: StringName = &""
var prediction: PredictionState
## Token shop: purchases so far this visit, offer name -> count.
var purchases: Dictionary = {}
