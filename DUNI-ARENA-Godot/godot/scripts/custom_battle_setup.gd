class_name CustomBattleSetup
extends RefCounted
## Custom battle roster (web app.js custom mode): free placement on the whole map,
## up to 24 units, four teams plus free-for-all, per-unit stance and up to two free items.
## Pure data; the screen draws it and BattleManager receives plain placements.
const MAX_PARTICIPANTS: int = 24
const MIN_GAP: float = 58
const MIN_POS: float = 40
const MAX_POS: float = 760
const MAX_ITEMS: int = 2
const SOLO: int = -1
## Free-for-all units each fight as their own faction, kept clear of team ids 0-3.
const SOLO_FACTION_BASE: int = 100
## Web PLACEMENT_TEAM_ORDER: 개인, 레드, 블루, 그린, 퍼플.
const TEAM_ORDER: Array[int] = [-1, 1, 0, 2, 3]
const TEAM_NAMES: Dictionary = {-1: "개인", 0: "블루", 1: "레드", 2: "그린", 3: "퍼플"}
const TEAM_COLORS: Array[Color] = [Color("88b7ff"), Color("ff947d"), Color("a4db89"), Color("c8a1ff")]
const SOLO_COLOR: Color = Color("c0cbc5")
## Web TYPES[i].color, used for free-for-all units.
const TYPE_COLORS: Array[Color] = [Color("ef9279"), Color("a0c87e"), Color("b79ce4"), Color("74cbc5"), Color("e7bd6a"), Color("8dbce8"), Color("dba373"), Color("e4bc73"), Color("dfa2cf"), Color("f08b69"), Color("bdab8c"), Color("7fcbe2"), Color("a1bd72"), Color("e9a05f"), Color("b5dbea"), Color("99d9cc"), Color("e8d99b"), Color("ed8f91"), Color("a6b48b"), Color("c7a4de"), Color("93c8f0"), Color("b4e5e8"), Color("b69cff"), Color("dcc389"), Color("a0d67b"), Color("d891b4")]

var entries: Array[Dictionary] = []
var next_id: int = 1

static func team_color(team: int) -> Color:
	return TEAM_COLORS[team] if team >= 0 and team < TEAM_COLORS.size() else SOLO_COLOR
static func faction_color(faction: int, type_id: int) -> Color:
	if faction >= 0 and faction < TEAM_COLORS.size():return TEAM_COLORS[faction]
	return TYPE_COLORS[type_id] if type_id >= 0 and type_id < TYPE_COLORS.size() else SOLO_COLOR
static func faction_of(entry: Dictionary) -> int:
	return int(entry.team) if int(entry.team) >= 0 else SOLO_FACTION_BASE + int(entry.id)
static func equippable_items() -> Array[StringName]:
	var kinds: Array[StringName] = []
	for kind in ItemCatalog.KINDS:
		if not ItemCatalog.get_item(kind).consumable:kinds.append(kind)
	return kinds

func get_entry(id: int) -> Dictionary:
	for entry in entries:
		if int(entry.id) == id:return entry
	return {}
func clamp_point(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, MIN_POS, MAX_POS), clampf(point.y, MIN_POS, MAX_POS))
func crowded(point: Vector2, ignore_id: int = -1) -> bool:
	return entries.any(func(e): return int(e.id) != ignore_id and e.position.distance_to(point) < MIN_GAP)
func free_point() -> Vector2:
	for row in range(8):
		for col in range(8):
			var point := Vector2(85 + col * 90, 85 + row * 90)
			if not crowded(point):return point
	return Vector2.INF
func add(type_id: int, team: int, point: Vector2 = Vector2.INF) -> String:
	if not CharacterCatalog.all().has(type_id):return "존재하지 않는 캐릭터입니다."
	if not team in TEAM_ORDER:return "팀을 다시 선택하세요."
	if entries.size() >= MAX_PARTICIPANTS:return "한 전투에 최대 %d명까지 참전할 수 있습니다." % MAX_PARTICIPANTS
	var at: Vector2 = clamp_point(point) if point.is_finite() else free_point()
	if not at.is_finite() or crowded(at):return "유닛끼리 겹치지 않도록 조금 떨어진 곳에 배치하세요."
	entries.append({"id": next_id, "type": type_id, "team": team, "position": at, "stance": CombatStance.NORMAL, "items": []})
	next_id += 1
	return ""
func move(id: int, point: Vector2) -> String:
	var entry: Dictionary = get_entry(id)
	if entry.is_empty():return "이 유닛은 옮길 수 없습니다."
	var at: Vector2 = clamp_point(point)
	if crowded(at, id):return "유닛과 조금 떨어진 곳으로 옮기세요."
	entry.position = at
	return ""
func remove(id: int) -> bool:
	var before: int = entries.size()
	entries = entries.filter(func(e): return int(e.id) != id)
	return entries.size() != before
func clear() -> void:
	entries.clear()
func hit(point: Vector2, radius: float = 30) -> int:
	# Topmost (last placed) unit under the point.
	for i in range(entries.size() - 1, -1, -1):
		if entries[i].position.distance_to(point) <= radius:return int(entries[i].id)
	return -1
func set_stance(id: int, stance: StringName) -> void:
	var entry: Dictionary = get_entry(id)
	if not entry.is_empty():entry.stance = CombatStance.normalize(stance)
func equip(id: int, kind: StringName) -> String:
	var entry: Dictionary = get_entry(id)
	if entry.is_empty() or not kind in equippable_items():return "장착할 수 없는 아이템입니다."
	if entry.items.size() >= MAX_ITEMS:return "아이템 슬롯이 가득 찼습니다."
	entry.items.append(kind)
	return ""
func unequip(id: int, index: int) -> bool:
	var entry: Dictionary = get_entry(id)
	if entry.is_empty() or index < 0 or index >= entry.items.size():return false
	entry.items.remove_at(index)
	return true
func team_spending(team: int) -> int:
	var total: float = 0
	for entry in entries:
		if int(entry.team) == team:total += CharacterCatalog.all()[int(entry.type)].base_gold_cost
	return int(total)
func faction_count() -> int:
	var factions: Dictionary = {}
	for entry in entries:factions[faction_of(entry)] = true
	return factions.size()
func validate() -> String:
	if entries.size() < 2:return "캐릭터를 2명 이상 추가하세요."
	if faction_count() < 2:return "서로 다른 팀 또는 개인을 2개 이상 구성하세요."
	return ""
func stats_for(entry: Dictionary) -> UnitCombatStats:
	# Level 0 stats with the same multiplicative item rules as guild members.
	var data: UnitData = CharacterCatalog.all()[int(entry.type)]
	var stats := UnitCombatStats.new()
	stats.max_hp = data.max_hp;stats.attack = data.attack;stats.defense = data.defense_power;stats.speed = data.move_speed
	for kind in entry.items:
		var item: ItemData = ItemCatalog.get_item(kind)
		if item == null:continue
		stats.max_hp *= item.max_hp_multiplier;stats.attack *= item.attack_multiplier;stats.speed *= item.speed_multiplier
		stats.healing_power *= item.healing_multiplier;stats.victory_gold += item.victory_gold
		stats.vigor_totem_count += int(item.vigor_totem);stats.charge_totem_count += int(item.charge_totem)
		stats.fang_count += int(item.kill_growth);stats.opening_awl_count += int(item.opening_awl)
	stats.max_hp = floorf(stats.max_hp + .5)
	stats.equipment_attack_without_growth = stats.attack
	return stats
func placements() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for entry in entries:
		rows.append({"data": CharacterCatalog.all()[int(entry.type)], "position": entry.position, "team": faction_of(entry), "combat_stats": stats_for(entry)})
	return rows
