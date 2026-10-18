class_name GuildManager
extends RefCounted
## Registry operations, not recruitment/economy UI. Identity is run-owned, not Node ID.

const WARRIOR: UnitData = preload("res://data/warrior.tres")
const ARCHER: UnitData = preload("res://data/archer.tres")

var state: RunState
var definitions: Dictionary = {} # immutable type_id -> UnitData

func _init(run_state: RunState = null) -> void:
	state = run_state if run_state != null else RunState.new()
	definitions = CharacterCatalog.all()

func definition(type_id: int) -> UnitData:
	return definitions.get(type_id)

func create_member(type_id: int) -> GuildMemberState:
	var data: UnitData = definition(type_id)
	if data == null:
		return null
	var member := GuildMemberState.new()
	while state.guild_members.has("member_%06d" % state.next_member_number):
		state.next_member_number += 1
	member.member_id = "member_%06d" % state.next_member_number
	member.unit_type_id = type_id
	member.current_hp = data.max_hp
	if not register_member(member):
		return null
	state.next_member_number += 1
	return member

func register_member(member: GuildMemberState) -> bool:
	if member == null or state.guild_members.has(member.member_id):
		return false
	if not UnitStateCodec.valid_member(member, definition(member.unit_type_id)):
		return false
	state.guild_members[member.member_id] = member
	return true

func get_member(member_id: String) -> GuildMemberState:
	return state.guild_members.get(member_id)

func all_members() -> Array[GuildMemberState]:
	var members: Array[GuildMemberState] = []
	for member in state.guild_members.values():
		members.append(member)
	return members

func living_members() -> Array[GuildMemberState]:
	var members: Array[GuildMemberState] = []
	for member in all_members():
		if member.is_alive():
			members.append(member)
	return members

func member_stats(member: GuildMemberState) -> UnitCombatStats:
	return GuildMemberCombatStats.assemble(definition(member.unit_type_id),member,InventoryService.new(state))
func member_max_hp(member: GuildMemberState) -> float:
	return member_stats(member).max_hp if state.tower!=null else definition(member.unit_type_id).max_hp
