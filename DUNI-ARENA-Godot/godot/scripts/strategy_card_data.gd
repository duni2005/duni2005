class_name StrategyCardData
extends Resource
## Shared immutable definition; no per-copy use/cooldown state.
enum Usage { ONCE, FLOOR, COOLDOWN }
@export var kind: StringName
@export var display_name: String
@export var targeting_type: StringName = &"living_ally"
@export var usage_rule: Usage
@export var description: String
@export var amount: float
@export var duration: float

@export var gold_price: int = 0
