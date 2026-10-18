class_name DeploymentEntry
extends RefCounted
## Pure placement data; never contains a Unit, UI Node or GuildMemberState.
var member_id: String
var team: int
var position: Vector2

func _init(id: String = "", at: Vector2 = Vector2.ZERO, faction: int = 0) -> void:
	member_id = id
	position = at
	team = faction

func copy() -> DeploymentEntry:
	return DeploymentEntry.new(member_id, position, team)

func battle_payload() -> Dictionary:
	return {"member_id": member_id, "team": team, "position": position}
