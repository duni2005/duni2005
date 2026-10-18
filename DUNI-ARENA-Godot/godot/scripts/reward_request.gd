class_name RewardRequest
extends RefCounted
## Deferred inventory reward. Phase10 consumes these; no substitute effect.
var reward_id: String
var kind: StringName
var item_kind: StringName
var fulfilled: bool = false
