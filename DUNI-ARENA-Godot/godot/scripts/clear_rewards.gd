class_name ClearRewards
extends RefCounted
## 클리어 보상: a won battle room offers REWARD_CHOICES rewards. Each one rolls its kind first
## (WEIGHTS), then a grade from the floor's item grade table (cut to the room's lowest grade):
## - item: an item of that grade (owned 전설 and items already offered left out);
## - card: a random strategy card (cards have no grade);
## - tokens / gold / heal (player HP) / restore (living members' HP %): the grade's amount.
## A reward is stored as one StringName in RoomState.item_choices: "item:<kind>", "card:<kind>",
## "tokens:<grade>", "gold:<grade>", "heal:<grade>", "restore:<grade>". A bare item kind (saves
## from before 0.99.2) is an item.
const WEIGHTS = {&"item": 50, &"card": 20, &"tokens": 10, &"gold": 10, &"heal": 5, &"restore": 5}
const AMOUNTS = {
	&"tokens": {&"common": 1, &"rare": 2, &"epic": 3, &"legendary": 5},
	&"gold": {&"common": 200, &"rare": 350, &"epic": 600, &"legendary": 900},
	&"heal": {&"common": 5, &"rare": 10, &"epic": 15, &"legendary": 25},
	&"restore": {&"common": .07, &"rare": .12, &"epic": .2, &"legendary": .3},
}
const ICONS = {&"tokens": "gem", &"gold": "gold", &"heal": "heart", &"restore": "rest"}

## `count` rewards for a room on a floor (grade odds from ItemRewards.odds).
static func roll(rng: RandomNumberGenerator, run: RunState, grade_odds: Dictionary, count: int) -> Array[StringName]:
	var out: Array[StringName] = [];var items: Array = []
	var owned: Array = ItemRewards.owned_legendaries(run)
	for i in range(count):
		var type: StringName = _pick(rng, WEIGHTS)
		var grade: StringName = _pick(rng, grade_odds)
		match type:
			&"item":
				var got: Array[StringName] = ItemRewards.roll(rng, {grade: 100.0}, 1, owned + items)
				if got.is_empty():got = ItemRewards.roll(rng, grade_odds, 1, owned + items)
				if got.is_empty():type = &"gold"
				else:items.append(got[0]);out.append(StringName("item:" + String(got[0])));continue
			&"card":
				var cards: Array = StrategyCardCatalog.DEFINITIONS.keys()
				out.append(StringName("card:" + String(cards[rng.randi_range(0, cards.size() - 1)])));continue
		out.append(StringName("%s:%s" % [type, grade]))
	return out
static func _pick(rng: RandomNumberGenerator, weights: Dictionary) -> StringName:
	var total: float = 0
	for k in weights:total += maxf(0, float(weights[k]))
	var roll: float = rng.randf() * total
	for k in weights:
		roll -= maxf(0, float(weights[k]))
		if roll < 0:return k
	return weights.keys().back()

## {type, value}: value is the item / card kind, or the grade of an amount reward.
static func parse(entry: StringName) -> Dictionary:
	var s: String = String(entry);var at: int = s.find(":")
	if at < 0:return {"type": &"item", "value": entry}
	return {"type": StringName(s.substr(0, at)), "value": StringName(s.substr(at + 1))}
static func valid(entry: StringName) -> bool:
	var r: Dictionary = parse(entry)
	match r.type:
		&"item":return ItemCatalog.get_item(r.value) != null
		&"card":return StrategyCardCatalog.get_card(r.value) != null
	return AMOUNTS.has(r.type) and AMOUNTS[r.type].has(r.value)
static func item_kind(entry: StringName) -> StringName:
	var r: Dictionary = parse(entry);return r.value if r.type == &"item" else &""
## The grade the reward shows (strategy cards: none).
static func grade(entry: StringName) -> StringName:
	var r: Dictionary = parse(entry)
	match r.type:
		&"item":return ItemCatalog.grade_of(r.value)
		&"card":return &""
	return r.value
## "골드 +350", "플레이어 HP +10", "생존 유닛 HP +12%", or the item / card name.
static func title(entry: StringName) -> String:
	var r: Dictionary = parse(entry)
	match r.type:
		&"item":return ItemCatalog.get_item(r.value).display_name
		&"card":return StrategyCardCatalog.get_card(r.value).display_name
		&"tokens":return "토큰 +%d" % int(AMOUNTS.tokens[r.value])
		&"gold":return "골드 +%d" % int(AMOUNTS.gold[r.value])
		&"heal":return "플레이어 HP +%d" % int(AMOUNTS.heal[r.value])
		&"restore":return "생존 유닛 HP +%d%%" % roundi(float(AMOUNTS.restore[r.value]) * 100)
	return ""
static func icon(entry: StringName) -> String:
	var r: Dictionary = parse(entry);return ICONS.get(r.type, String(r.value))

## Gives the reward. Returns what changed (item_id / card_id / gold / tokens / player_hp / healed).
static func apply(entry: StringName, guild: GuildManager, inventory: InventoryService, source: String) -> Dictionary:
	var r: Dictionary = parse(entry);var out: Dictionary = {"reward": entry}
	match r.type:
		&"item":
			var item: ItemInstance = inventory.give(r.value, source)
			if item == null:return {}
			out["item_id"] = item.item_id;out["kind"] = r.value
		&"card":out["card_id"] = guild.state.give_strategy_card(r.value).card_id
		&"tokens":guild.state.tokens += int(AMOUNTS.tokens[r.value]);out["tokens"] = int(AMOUNTS.tokens[r.value])
		&"gold":guild.state.gold += int(AMOUNTS.gold[r.value]);out["gold"] = int(AMOUNTS.gold[r.value])
		&"heal":
			var before: float = guild.state.player_hp;guild.state.player_hp += float(AMOUNTS.heal[r.value]);out["player_hp_gained"] = guild.state.player_hp - before
		&"restore":
			var healed: float = 0
			for member in guild.living_members():healed += GuildMemberCombatStats.heal(guild, member, guild.member_stats(member).max_hp * float(AMOUNTS.restore[r.value]))
			out["healed"] = healed
	return out
