class_name InventoryService
extends RefCounted
var run: RunState
func _init(state: RunState) -> void:run=state
func get_item(id: int) -> ItemInstance:
	for item in run.inventory:
		if item.item_id==id:return item
	return null
func equipped(member_id: String) -> Array[ItemInstance]:
	return run.inventory.filter(func(i):return not i.consumed and i.equipped_to_member_id==member_id)
func available() -> Array[ItemInstance]:
	return run.inventory.filter(func(i):return not i.consumed and i.equipped_to_member_id.is_empty())
func give(kind: StringName,receipt: String="") -> ItemInstance:
	if ItemCatalog.get_item(kind)==null or not valid():return null
	if not receipt.is_empty() and run.inventory_receipts.has(receipt):return get_item(run.inventory_receipts[receipt])
	var item:=ItemInstance.new();item.item_id=run.next_item_number;item.kind=kind;run.next_item_number+=1;run.inventory.append(item)
	if not receipt.is_empty():run.inventory_receipts[receipt]=item.item_id
	return item
func consume_reward(request: RewardRequest) -> bool:
	if request==null or request.fulfilled or request.kind!=&"item":return false
	var item: ItemInstance=give(request.item_kind,"reward:"+request.reward_id)
	if item==null:return false
	request.fulfilled=true;return true

func valid() -> bool:
	var seen: Dictionary={};var highest: int=0
	for item in run.inventory:
		if item==null or item.item_id<=0 or seen.has(item.item_id) or ItemCatalog.get_item(item.kind)==null:return false
		if not item.equipped_to_member_id.is_empty() and (item.consumed or not run.guild_members.has(item.equipped_to_member_id)):return false
		seen[item.item_id]=true;highest=maxi(highest,item.item_id)
	return run.next_item_number>highest
