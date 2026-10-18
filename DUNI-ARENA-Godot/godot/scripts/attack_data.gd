class_name AttackData
extends Resource
## Immutable attack profile; durations/reach come from ATTACK_PROFILES, not TYPES.range.

enum Kind { MELEE, PROJECTILE }

@export var kind: Kind = Kind.MELEE
@export var windup: float
@export var active: float
@export var recovery: float
@export var reach: float
@export var impulse: float = 0.0
@export var cone: float
@export var projectile_speed: float
@export var projectile_lifetime: float
@export var projectile_radius: float
@export var projectile_offset: float
@export var projectile_spread: float
@export var aim_lead: float

func start_distance() -> float:
	return reach * (0.9 if kind == Kind.MELEE else 1.0)

@export var projectile_clash_radius: float = 9
