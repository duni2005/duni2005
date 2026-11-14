class_name StrategyCardInstance
extends RefCounted
## One owned copy. wins_left: battle rooms still to win before a used 쿨타임 card is ready
## (0 = ready). A used 소모 copy is consumed and kept for audit.
var card_id: int
var kind: StringName
var wins_left: int = 0
var consumed: bool = false
