class_name PredictionState
extends RefCounted
var teams: Array[Dictionary] = []
var picked_team: int = -1
var stake: int = 100
var status: StringName = &"ready"
var result: StringName = &""
var payout: int = 0
var tokens: int = 0
