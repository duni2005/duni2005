class_name SaveMigrator
extends RefCounted
## Brings older saves up to the current schema before validation. Steps work on a copy of the raw
## document, never on combat/domain objects.
## v2: members store total experience instead of a level, the run stores sortie upgrades, and the
## promotion event room is gone.
## v3: events record token shop purchases.
## v4: items store their blacksmith enhancement.
## v5: the run stores mango faith.
## v6: the run stores guild expansion (roster size and recruit odds upgrades).
## v7: items by grade (0.94): the 40 removed combined items are taken away and refunded, rooms
## store their item reward pick, blacksmith trade counts are dropped.
## v8: items store a variant (프리즘 조각's element) and a growth stage (망고 씨앗) (0.95).
const CURRENT_VERSION=8
const MIGRATION_LABEL="item-variants-v8"
static func prepare(value: Variant) -> SaveLoadResult:
	if not value is Dictionary or not SaveValueCodec.integer(value.get("schema_version")):
		return SaveLoadResult.failure(SaveLoadResult.Code.VALIDATION_ERROR,"schema_required")
	var document: Dictionary=value
	if int(document.schema_version)==1:document=v1_to_v2(document)
	if int(document.schema_version)==2:document=v2_to_v3(document)
	if int(document.schema_version)==3:document=v3_to_v4(document)
	if int(document.schema_version)==4:document=v4_to_v5(document)
	if int(document.schema_version)==5:document=v5_to_v6(document)
	if int(document.schema_version)==6:document=v6_to_v7(document)
	if int(document.schema_version)==7:document=v7_to_v8(document)
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
				event.merge({"event_type":"supply","choices":["heal","guild","gold","loot"],"treasure_kind":"item","treasure_reward":"warmNecklace"},true)
	return document
## Every stored event gets an empty token shop purchase record.
static func v2_to_v3(source: Dictionary) -> Dictionary:
	var document: Dictionary=source.duplicate(true);document.schema_version=3;document.migration_version=MIGRATION_LABEL
	var run=document.get("run");var tower=run.get("tower") if run is Dictionary else null;var map=tower.get("map") if tower is Dictionary else null
	for room in map.get("rooms",[]) if map is Dictionary and map.get("rooms") is Array else []:
		if room is Dictionary and room.get("event") is Dictionary and not room.event.has("purchases"):room.event["purchases"]={}
	return document
## Every item starts unenhanced.
static func v3_to_v4(source: Dictionary) -> Dictionary:
	var document: Dictionary=source.duplicate(true);document.schema_version=4;document.migration_version=MIGRATION_LABEL
	var run=document.get("run")
	for item in run.get("inventory",[]) if run is Dictionary and run.get("inventory") is Array else []:
		if item is Dictionary and not item.has("enhance"):item["enhance"]=0
	return document
## Runs start without mango faith.
static func v4_to_v5(source: Dictionary) -> Dictionary:
	var document: Dictionary=source.duplicate(true);document.schema_version=5;document.migration_version=MIGRATION_LABEL
	if document.get("run") is Dictionary and not document.run.has("mango_faith"):document.run["mango_faith"]=0
	return document
static func v5_to_v6(source: Dictionary) -> Dictionary:
	var document: Dictionary=source.duplicate(true);document.schema_version=6;document.migration_version=MIGRATION_LABEL
	if document.get("run") is Dictionary:
		for field in ["roster_level","odds_level"]:
			if not document.run.has(field):document.run[field]=0
	return document
## Combined items that no longer exist leave the inventory (worn or not) and their two
## materials' shop price comes back as gold; the run keeps a note shown once after continuing.
## Rooms get an empty item reward; blacksmith trade counts are dropped.
static func v6_to_v7(source: Dictionary) -> Dictionary:
	var document: Dictionary=source.duplicate(true);document.schema_version=7;document.migration_version=MIGRATION_LABEL
	var run=document.get("run")
	if not run is Dictionary:return document
	var kept: Array=[];var refunded: Array=[];var gold: int=0;var gone: Dictionary={}
	for item in run.get("inventory",[]) if run.get("inventory") is Array else []:
		if item is Dictionary and item.get("kind") is String and ItemCatalog.removed_combination(item.kind):
			gone[int(item.get("item_id",0))]=true
			if not item.get("consumed",false):gold+=ItemCatalog.refund(item.kind);refunded.append(item.kind)
			continue
		kept.append(item)
	if run.get("inventory") is Array:run.inventory=kept
	# Receipts that made a removed item point nowhere now.
	if run.get("inventory_receipts") is Dictionary:
		for receipt in run.inventory_receipts.keys():
			if SaveValueCodec.integer(run.inventory_receipts[receipt]) and gone.has(int(run.inventory_receipts[receipt])):run.inventory_receipts.erase(receipt)
	if gold>0 and SaveValueCodec.integer(run.get("gold")):
		run.gold=int(run.gold)+gold
		# The save list shows gold from the metadata; it must match the run.
		if document.get("metadata") is Dictionary and document.metadata.has("gold"):document.metadata.gold=run.gold
	run["item_notice"]=refund_notice(refunded,gold)
	var tower=run.get("tower");var map=tower.get("map") if tower is Dictionary else null
	for room in map.get("rooms",[]) if map is Dictionary and map.get("rooms") is Array else []:
		if not room is Dictionary:continue
		if not room.has("item_choices"):room["item_choices"]=[]
		if not room.has("item_choice"):room["item_choice"]=""
		var event=room.get("event")
		if event is Dictionary and event.get("purchases") is Dictionary:event.purchases.erase("trade")
	return document
## Every item gets an empty variant and growth stage 0 (no 0.94 item has either).
static func v7_to_v8(source: Dictionary) -> Dictionary:
	var document: Dictionary=source.duplicate(true);document.schema_version=8;document.migration_version=MIGRATION_LABEL
	var run=document.get("run")
	if run is Dictionary and run.get("inventory") is Array:
		for item in run.inventory:
			if not item is Dictionary:continue
			if not item.has("variant"):item["variant"]=""
			if not item.has("growth"):item["growth"]=0
	return document
## "아이템 개편으로 사라진 조합 아이템 2개를 회수하고 520 G를 돌려드렸습니다." (empty when nothing changed)
static func refund_notice(kinds: Array,gold: int) -> String:
	if kinds.is_empty():return ""
	return "아이템 개편으로 사라진 조합 아이템 %d개(%s)를 회수하고 %d G를 돌려드렸습니다."%[kinds.size(),", ".join(kinds.map(func(k):return ItemCatalog.removed_name(k))),gold]
