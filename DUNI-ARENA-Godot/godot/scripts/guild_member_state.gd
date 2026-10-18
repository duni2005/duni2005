class_name GuildMemberState
extends RefCounted
## One recruited member. No Node, UI, target or battle-instance references.
## Identity and growth metadata survive; growth effects are outside Phase 2.

const MAX_ENERGY: int = 5
const MAX_GAUGE: float = 100.0
## MIGRATION_NOTE: per missing energy, web damage -5%, taken damage +3%,
## charge efficiency -7%. These effects are not implemented in Phase 2.

var member_id: String = "":
	set(value):
		# Assigned once, including future reconstruction from stored pure data.
		if member_id.is_empty():
			member_id = value
var unit_type_id: int
var level: int = 0
var stars: int = 0
var current_hp: float
var energy: int = MAX_ENERGY:
	set(value):
		energy = clampi(value, 0, MAX_ENERGY)
var ultimate_gauge: float = 0.0:
	set(value):
		ultimate_gauge = clampf(value, 0.0, MAX_GAUGE)
var transcendence_gauge: float = 0.0:
	set(value):
		transcendence_gauge = clampf(value, 0.0, MAX_GAUGE)
var stance: StringName = CombatStance.NORMAL:
	set(value):
		stance = CombatStance.normalize(value)
var character_specific_state: Dictionary = {}:
	set(value):
		character_specific_state = value.duplicate(true)

func is_alive() -> bool:
	return is_finite(current_hp) and current_hp > 0.0

var fang_kills: int = 0 # web fangKills, permanent run-local equipment growth
