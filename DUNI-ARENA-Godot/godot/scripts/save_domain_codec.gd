class_name SaveDomainCodec
extends RefCounted
## Explicit domain schema (save version SaveMigrator.CURRENT_VERSION). Never reflects arbitrary Objects or instantiates scripts from a save.
const SCALARS = {
	"run":{"run_id":"s","next_member_number":"i","settled_battle_ids":"d","player_max_hp":"f","player_hp":"f","game_over":"b","game_over_reason":"i","death_losses_by_result_id":"d","next_strategy_card_number":"i","strategy_use_receipts":"d","gold":"i","tokens":"i","next_item_number":"i","inventory_receipts":"d","transaction_receipts":"d","content_receipts":"d","sortie_level":"i","mango_faith":"i"},
	"member":{"member_id":"s","unit_type_id":"i","total_exp":"i","stars":"i","current_hp":"f","energy":"i","ultimate_gauge":"f","transcendence_gauge":"f","stance":"n","character_specific_state":"d","fang_kills":"i"},
	"item":{"item_id":"i","kind":"n","equipped_to_member_id":"s","consumed":"b","enhance":"i"},
	"card":{"card_id":"i","kind":"n","used_depth":"i","used_floors":"ai","ready_floor":"i","consumed":"b"},
	"progress":{"current_depth":"i","unlocked_floor":"i"},
	"tower":{"current_chapter":"i","unlocked_floor":"i","selected_room_id":"s","phase":"n","visited_rooms":"d","cleared_rooms":"d","floor_conquest":"d","chapter_progress":"d","result":"n","conquered":"b","processed_results":"d","map_scroll_y":"i","last_content_outcome":"d"},
	"map":{},"formation":{},
	"deployment":{"member_id":"s","team":"i","position":"v"},
	"floor":{"floor_index":"i","chapter_index":"i","unlocked":"b","room_ids":"as","cleared_count":"i","required_clear_count":"i","conquered":"b","bonus":"n","bonus_item_kind":"n"},
	"room":{"source_run_id":"s","room_id":"s","cleared":"b","battle_attempt_count":"i","active_result_id":"s","settled_result_ids":"d","floor_index":"i","chapter_index":"i","lane":"i","room_type":"n","discovered":"b","visited":"b","consumed":"b","publicly_visible":"b","event_type":"n","gold_reward":"i","token_reward":"i","kill_rewards":"d","reward_claimed":"b","content_visits":"i"},
	"encounter":{"room_kind":"n","depth":"i","formation":"n"},
	"spawn":{"enemy_id":"s","unit_type_id":"i","level":"i","initial_position":"v","rank":"n","body_scale":"f","hp_multiplier":"f","damage_multiplier":"f","defense_multiplier":"f","speed_multiplier":"f"},
	"enemy":{"enemy_id":"s","unit_type_id":"i","current_hp":"f","position":"v","ultimate_gauge":"f","stance":"n","persistent_state":"d"},
	"recruit":{"revision":"i"},"recruit_offer":{"offer_id":"s","unit_type_id":"i","gold_price":"i","token_price":"i","purchased":"b"},
	"shop":{},"shop_offer":{"offer_id":"s","category":"n","kind":"n","gold_price":"i","purchased":"b"},
	"event":{"event_type":"n","choices":"an","selected_choice":"n","resolved":"b","reward_receipt":"s","outcome":"d","treasure_kind":"n","treasure_reward":"n","purchases":"d"},
	"prediction":{"teams":"ad","picked_team":"i","stake":"i","status":"n","result":"n","payout":"i","tokens":"i"},
	"reward":{"reward_id":"s","kind":"n","item_kind":"n","fulfilled":"b"}}
const CHILDREN = {"run":{"tower":"tower","strategy_progress":"progress","last_formation":"formation"},"tower":{"map":"map"},"room":{"encounter":"encounter","recruit":"recruit","shop":"shop","event":"event"},"event":{"prediction":"prediction"}}
const ARRAYS = {"run":{"inventory":"item","strategy_cards":"card"},"tower":{"reward_requests":"reward"},"map":{"floors":"floor"},"formation":{"entries":"deployment"},"encounter":{"enemies":"spawn"},"recruit":{"offers":"recruit_offer"},"shop":{"offers":"shop_offer"}}
const MAPS = {"run":{"guild_members":"member"},"map":{"rooms":"room"},"room":{"enemy_state":"enemy"}}
const IDENTITIES = {"member":"member_id","room":"room_id","enemy":"enemy_id"}
var values:=SaveValueCodec.new()
var error: String=""
static func raw_valid(kind: String,field: String,value: Variant) -> bool:
	if field=="stance":return value in [CombatStance.NORMAL,CombatStance.CAUTIOUS,CombatStance.RUSH,CombatStance.COVER]
	if field in ["ultimate_gauge","transcendence_gauge"]:return value>=0 and value<=100
	if field=="energy":return value>=0 and value<=5
	if field=="total_exp":return value>=0
	if field=="sortie_level":return value>=0 and value<=GrowthRules.SORTIE_COSTS.size()
	if field=="stars":return value>=0 and value<=GrowthRules.MAX_STARS
	if field=="game_over_reason":return value>=0 and value<=3
	if field=="player_max_hp":return value>0
	if field in ["player_hp","current_hp","gold","tokens","fang_kills"]:return value>=0
	return true
func fail(reason: String) -> Variant:
	if error.is_empty():error=reason
	return null
func encode(object: RefCounted,kind: String) -> Dictionary:
	var data: Dictionary={}
	for field in SCALARS[kind]:data[field]=values.encode(object.get(field))
	for field in CHILDREN.get(kind,{}):
		var child=object.get(field);data[field]=null if child==null else encode(child,CHILDREN[kind][field])
	for field in ARRAYS.get(kind,{}):
		data[field]=[]
		for child in object.get(field):data[field].append(encode(child,ARRAYS[kind][field]))
	for field in MAPS.get(kind,{}):
		data[field]=[]
		for key in object.get(field):
			var child=object.get(field)[key];var child_kind: String=MAPS[kind][field]
			if key!=child.get(IDENTITIES[child_kind]):fail("identity_map_mismatch")
			data[field].append(encode(child,child_kind))
	if not values.error.is_empty():fail(values.error)
	return data
func scalar(value: Variant,type: String) -> Variant:
	match type:
		"s","n":
			if not value is String:return fail("string_required")
			return StringName(value) if type=="n" else value
		"i":return int(value) if SaveValueCodec.integer(value) else fail("integer_required")
		"f":return float(value) if (value is float or value is int) and is_finite(float(value)) else fail("finite_number_required")
		"b":return value if value is bool else fail("boolean_required")
		"v":
			if not value is Dictionary or value.size()!=2 or not value.has("x") or not value.has("y"):return fail("position_required")
			var x: Variant=scalar(value.x,"f");var y: Variant=scalar(value.y,"f")
			if not error.is_empty():return null
			return Vector2(x,y) if Vector2(x,y).is_finite() else fail("invalid_position")
		"d":
			var decoded: Variant=values.decode(value)
			if not values.error.is_empty() or not decoded is Dictionary:return fail("dictionary_required:"+values.error)
			return decoded
	if type.begins_with("a"):
		if not value is Array:return fail("array_required")
		var array: Array=[]
		for element in value:array.append(scalar(element,type.substr(1)))
		return array
	return fail("unknown_scalar")
func decode(data: Variant,kind: String) -> RefCounted:
	if not data is Dictionary:fail(kind+":record_required");return null
	var expected: Array=SCALARS[kind].keys()+CHILDREN.get(kind,{}).keys()+ARRAYS.get(kind,{}).keys()+MAPS.get(kind,{}).keys()
	if data.size()!=expected.size():fail(kind+":field_count");return null
	for field in expected:
		if not data.has(field):fail(kind+":missing:"+field);return null
	var object: RefCounted=make(kind)
	for field in SCALARS[kind]:
		var value: Variant=scalar(data[field],SCALARS[kind][field])
		if not error.is_empty():return null
		if not raw_valid(kind,field,value):fail(kind+":range:"+field);return null
		if SCALARS[kind][field].begins_with("a"):
			for entry in value:object.get(field).append(entry)
		else:object.set(field,value)
	for field in CHILDREN.get(kind,{}):
		object.set(field,null if data[field]==null else decode(data[field],CHILDREN[kind][field]))
		if not error.is_empty():return null
	for field in ARRAYS.get(kind,{}):
		if not data[field] is Array:fail(kind+":array_required");return null
		for entry in data[field]:
			var child: RefCounted=decode(entry,ARRAYS[kind][field])
			if not error.is_empty():return null
			object.get(field).append(child)
	for field in MAPS.get(kind,{}):
		if not data[field] is Array:fail(kind+":records_required");return null
		for entry in data[field]:
			var child_kind: String=MAPS[kind][field];var child: RefCounted=decode(entry,child_kind)
			if not error.is_empty():return null
			var id: String=child.get(IDENTITIES[child_kind])
			if object.get(field).has(id):fail("duplicate_"+child_kind);return null
			object.get(field)[id]=child
	return object
static func make(kind: String) -> RefCounted:
	match kind:
		"run":return RunState.new()
		"member":return GuildMemberState.new()
		"item":return ItemInstance.new()
		"card":return StrategyCardInstance.new()
		"progress":return StrategyProgressContext.new()
		"tower":return TowerRunState.new()
		"map":return TowerMapState.new()
		"formation":return FormationState.new()
		"deployment":return DeploymentEntry.new()
		"floor":return FloorState.new()
		"room":return RoomState.new()
		"encounter":return EncounterState.new()
		"spawn":return EnemySpawnEntry.new()
		"enemy":return EnemyRoomState.new()
		"recruit":return RecruitState.new()
		"recruit_offer":return RecruitOffer.new()
		"shop":return ShopState.new()
		"shop_offer":return ShopOffer.new()
		"event":return EventState.new()
		"prediction":return PredictionState.new()
		"reward":return RewardRequest.new()
	return null
