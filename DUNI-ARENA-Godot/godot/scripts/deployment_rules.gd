class_name DeploymentRules
extends RefCounted
## Tower rules, not custom mode's 24-unit limit. No UI strings or state writes.
enum Code { OK, UNKNOWN_MEMBER, DEAD_MEMBER, ALREADY_DEPLOYED, NOT_DEPLOYED, OUTSIDE_DEPLOYMENT_ZONE, TOO_CLOSE, INVALID_POSITION, INVALID_TEAM, EMPTY_DEPLOYMENT, INVALID_ENEMY, SORTIE_FULL }
const MIN_POSITION := Vector2(40, 40)
const MAX_POSITION := Vector2(380, 760)
## MIGRATION_NOTE: fixed center distance ignores character body size.
const MIN_DISTANCE: float = 58.0

static func position_error(point: Vector2, entries: Array[DeploymentEntry], blockers: Array[Vector2], ignore_member_id: String = "") -> Code:
	if not point.is_finite():
		return Code.INVALID_POSITION
	if point.x < MIN_POSITION.x or point.x > MAX_POSITION.x or point.y < MIN_POSITION.y or point.y > MAX_POSITION.y:
		return Code.OUTSIDE_DEPLOYMENT_ZONE
	for entry in entries:
		if entry.member_id != ignore_member_id and entry.position.distance_to(point) < MIN_DISTANCE:
			return Code.TOO_CLOSE
	for enemy_position in blockers:
		if not enemy_position.is_finite():
			return Code.INVALID_POSITION
		if enemy_position.distance_to(point) < MIN_DISTANCE:
			return Code.TOO_CLOSE
	return Code.OK

static func validate(guild: GuildManager, entry: DeploymentEntry, entries: Array[DeploymentEntry], blockers: Array[Vector2], moving: bool = false) -> Code:
	if guild == null or entry == null:
		return Code.UNKNOWN_MEMBER
	var member: GuildMemberState = guild.get_member(entry.member_id)
	if member == null:
		return Code.UNKNOWN_MEMBER
	if not member.is_alive():
		return Code.DEAD_MEMBER
	if entry.team != 0:
		return Code.INVALID_TEAM
	var exists: bool = false
	for other in entries:
		if other.member_id == entry.member_id:
			exists = true
	if exists and not moving:
		return Code.ALREADY_DEPLOYED
	if moving and not exists:
		return Code.NOT_DEPLOYED
	if not moving and entries.size() >= GrowthRules.sortie_limit(guild.state):
		return Code.SORTIE_FULL
	return position_error(entry.position, entries, blockers, entry.member_id if moving else "")

static func validate_all(guild: GuildManager, entries: Array[DeploymentEntry], blockers: Array[Vector2]) -> Code:
	if entries.is_empty():
		return Code.EMPTY_DEPLOYMENT
	var checked: Array[DeploymentEntry] = []
	for entry in entries:
		var error: Code = validate(guild, entry, checked, blockers)
		if error != Code.OK:
			return error
		checked.append(entry)
	return Code.OK
