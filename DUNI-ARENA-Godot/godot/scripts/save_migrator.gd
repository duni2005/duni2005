class_name SaveMigrator
extends RefCounted
## Brings older saves up to the current schema before validation. Steps work on a copy of the raw
## document, never on combat/domain objects.
## v2: members store total experience instead of a level, the run stores sortie upgrades, and the
## promotion event room is gone.
const CURRENT_VERSION=2
const MIGRATION_LABEL="growth-v2"
static func prepare(value: Variant) -> SaveLoadResult:
	if not value is Dictionary or not SaveValueCodec.integer(value.get("schema_version")):
		return SaveLoadResult.failure(SaveLoadResult.Code.VALIDATION_ERROR,"schema_required")
	var document: Dictionary=value
	if int(document.schema_version)==1:document=v1_to_v2(document)
	if int(document.schema_version)!=CURRENT_VERSION:return SaveLoadResult.failure(SaveLoadResult.Code.UNSUPPORTED_VERSION,"unsupported_schema")
	var result:=SaveLoadResult.new();result.document=document;return result
## Levels become the experience that reaches them, runs start without sortie upgrades, and a
## promotion room becomes a supply (treasure) room. Malformed records are left for the validator.
static func v1_to_v2(source: Dictionary) -> Dictionary:
	var document: Dictionary=source.duplicate(true);document.schema_version=2;document.migration_version=MIGRATION_LABEL
	var run=document.get("run")
	if not run is Dictionary:return document
	run["sortie_level"]=0
	for member in run.get("guild_members",[]) if run.get("guild_members") is Array else []:
		if member is Dictionary and member.has("level"):
			var level=member.level;member.erase("level")
			member["total_exp"]=GrowthRules.exp_for_level(clampi(int(level),0,10)) if SaveValueCodec.integer(level) else level
	var tower=run.get("tower");var map=tower.get("map") if tower is Dictionary else null
	for room in map.get("rooms",[]) if map is Dictionary and map.get("rooms") is Array else []:
		if not room is Dictionary:continue
		var event=room.get("event")
		if event is Dictionary:
			event.erase("promotion_limit");event.erase("promotion_used")
		if room.get("event_type")=="promotion":
			room.event_type="supply"
			if event is Dictionary:
				event.merge({"event_type":"supply","choices":["heal","guild","gold","loot"],"treasure_kind":"item","treasure_reward":String(ItemCatalog.KINDS[0])},true)
	return document
