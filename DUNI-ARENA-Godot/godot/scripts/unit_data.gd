class_name UnitData
extends Resource
## Shared type definition. Never write runtime HP/target/cooldowns into this resource.

@export var type_id: int
@export var display_name: String
@export var base_gold_cost: float
@export var max_hp: float
@export var defense_power: float = 1.0
@export var attack: float
@export var move_speed: float
@export var attack_range: float
@export var attack_interval: float
@export_range(0.0, 1.0) var critical_chance: float
@export var attack_profile: AttackData

@export var tags: PackedStringArray = []
@export var emoji: String = ""
@export var body_scale: float = 1
@export var ultimate_windup: float = -1
@export var recruit_tokens: int = 2
