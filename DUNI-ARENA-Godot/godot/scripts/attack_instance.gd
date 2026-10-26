class_name AttackInstance
extends RefCounted
## Detached physical attack. IDs/geometry only; no owner/Scene/Node references.
var metadata: Dictionary = {}
var attack_id: int = 0
var source_battle_id: int = 0
var team: int = 0
var attack_type: StringName = &"melee"
var shape: StringName = &"blade"
var power: float = 0
var damage: float = 0
var impulse: float = 0
var angle: float = 0
var reach: float = 0
var cone: float = 0
var path_width: float = 0
var position: Vector2 = Vector2.ZERO
var start_position: Vector2 = Vector2.ZERO
var end_position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var radius: float = 26
var clash_radius: float = 7
var age: float = 0
var duration: float = 0
var life: float = 0
var source_attack_serial: int = 0
var hidden_launch: bool = false
var hit_ids: Dictionary = {}
var clash_count: int = 0
func blade(origin: Vector2, offset: float = 0) -> Array[Vector2]:
	if shape == &"path": return [start_position, end_position]
	if metadata.get("shield_bash",false):
		var t: float=clampf((age+offset)/maxf(.00001,duration),0,1)
		var dir: Vector2=Vector2.from_angle(angle);var p: Vector2=origin+dir*(30+(reach-30)*sin(t*PI/2));var side: Vector2=dir.orthogonal()*64*float(metadata.get("scale",1))
		return [p-side,p+side]
	var a: float = angle - cone + 2 * cone * clampf((age + offset) / maxf(.00001, duration), 0, 1)
	var direction := Vector2.from_angle(a)
	return [origin + direction * 25*float(metadata.get("scale",1)), origin + direction * reach]
func options(origin: Vector2) -> Dictionary:
	var out: Dictionary = {"attack_token": attack_id, "angle": angle, "impulse": impulse, "hidden_launch": hidden_launch, "attack_origin": origin}
	# The damage instance (UnitStatTable) this attack carries.
	for key in ["dmg", "dmg_type"]:
		if metadata.has(key):out[key] = metadata[key]
	return out
