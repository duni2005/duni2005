class_name BattlePassives
extends RefCounted
## Passive strategy cards: taken into a battle in a loadout slot and on for that battle, never
## played. When the battle starts (TurningPointManager is created) every passive in the hand is
## marked used: 소모 is consumed, 일반 is used this battle, 쿨타임 N starts its cooldown. Copies of
## the same passive apply once. A passive with a condition is on only while it holds.
## The battle keeps meta "passives" (kinds in hand order) and "passive_fired" (kind -> clock time
## of the last time its effect fired, for the HUD flash).
## 전열 정비 rally · 원소 공명 resonance · 지휘 깃발 command_flag · 불굴의 의지 indomitable ·
## 망고 도시락 lunchbox.

static func start(manager: TurningPointManager) -> void:
	var battle: BattleManager = manager.battle
	var kinds: Array = []
	for card in manager.hand_cards():
		var data: StrategyCardData = StrategyCardCatalog.get_card(card.kind)
		if data == null or not data.passive():continue
		StrategyCardExecutor.record_use(manager, card, data)
		manager.passive_cards.append(card.card_id)
		if not card.kind in kinds:kinds.append(card.kind)
	battle.set_meta("passives", kinds)
	battle.set_meta("passive_fired", {})
	for kind in kinds:
		var data: StrategyCardData = StrategyCardCatalog.get_card(kind)
		match kind:
			&"rally":
				for u in allies(battle):
					u.shield_hp = maxf(u.shield_hp, u.max_hp * data.amount);u.shield_remaining = maxf(u.shield_remaining, data.duration)
					battle.emit_combat_event(&"passive_rally", u.position, {"actor_id": u.battle_id})
				fire(battle, kind)
			&"resonance":
				for e in element_counts(battle):
					var points: Array = allies(battle).filter(func(u): return CharacterCatalog.element(u.data.type_id) == e).map(func(u): return u.position)
					battle.emit_combat_event(&"passive_resonance", points[0], {"element": String(e), "points": points})
				if not element_counts(battle).is_empty():fire(battle, kind)

static func active(battle) -> Array:
	return battle.get_meta("passives", []) if battle != null else []
static func has(battle, kind: StringName) -> bool:return kind in active(battle)
## The deployed guild members still standing.
static func allies(battle) -> Array:
	return battle.units.filter(func(u): return u.alive and u.original_team == 0 and not u.source_member_id.is_empty())
## 지휘 깃발: every turning point heals the deployed allies by its share of their max HP.
static func on_turning_point(manager: TurningPointManager) -> void:
	var battle: BattleManager = manager.battle
	if not has(battle, &"command_flag"):return
	var data: StrategyCardData = StrategyCardCatalog.get_card(&"command_flag")
	for u in allies(battle):StrategyEffects.heal(u, u.max_hp * data.amount)
	fire(battle, &"command_flag")
## Living deployed allies per element (원소 공명): element -> count.
static func element_counts(battle) -> Dictionary:
	var count: Dictionary = {}
	for u in allies(battle):
		var e: StringName = CharacterCatalog.element(u.data.type_id)
		if e != &"":count[e] = int(count.get(e, 0)) + 1
	return count
## Elements two or more living deployed allies share.
static func paired_elements(battle) -> Array:
	var count: Dictionary = {}
	for u in allies(battle):
		var e: StringName = CharacterCatalog.element(u.data.type_id)
		if e != &"":count[e] = int(count.get(e, 0)) + 1
	return count.keys().filter(func(e): return count[e] >= 2)
static func condition_holds(battle, data: StrategyCardData) -> bool:
	for c in data.conditions:
		if c == &"element_pair" and paired_elements(battle).is_empty():return false
	return true
## The HUD icon of the passive flashes.
static func fire(battle, kind: StringName) -> void:
	var fired: Dictionary = battle.get_meta("passive_fired", {})
	fired[kind] = battle.clock.elapsed;battle.set_meta("passive_fired", fired)

## 원소 공명: an ally's damage grows by its share for every living deployed ally of its element
## (itself included).
static func outgoing(source) -> float:
	if source == null or source.battle == null or source.team != 0 or source.source_member_id.is_empty() or not has(source.battle, &"resonance"):return 1.0
	var e: StringName = CharacterCatalog.element(source.data.type_id)
	if e == &"":return 1.0
	var battle = source.battle
	var n: int = int(element_counts(battle).get(e, 0))
	if n <= 0:return 1.0
	if battle.clock.elapsed - float(battle.get_meta("passive_fired", {}).get(&"resonance", -9.0)) > 1.5:fire(battle, &"resonance")
	return 1.0 + StrategyCardCatalog.get_card(&"resonance").amount * n

## 불굴의 의지: the first ally that would fall stays at 30% HP with 2 s invincibility (once).
static func indomitable(u) -> bool:
	var battle = u.battle
	if battle == null or u.team != 0 or u.source_member_id.is_empty() or not has(battle, &"indomitable") or battle.get_meta("indomitable_used", false):return false
	var data: StrategyCardData = StrategyCardCatalog.get_card(&"indomitable")
	battle.set_meta("indomitable_used", true)
	u.current_hp = maxf(1, u.max_hp * data.amount);u.invincible_remaining = maxf(u.invincible_remaining, data.duration)
	u.velocity = Vector2.ZERO;u.knockback_velocity = Vector2.ZERO
	battle.emit_combat_event(&"passive_indomitable", u.position, {"actor_id": u.battle_id})
	fire(battle, &"indomitable")
	return true

## 망고 도시락: a won battle heals the deployed members still standing by 15% of max HP.
## Returns member_id -> healed HP (also kept as battle meta "lunchbox_healed" for the result).
static func settle(battle, guild: GuildManager, victory: bool) -> Dictionary:
	var healed: Dictionary = {}
	if not victory or not has(battle, &"lunchbox"):return healed
	var data: StrategyCardData = StrategyCardCatalog.get_card(&"lunchbox")
	for u in battle.units:
		if u.original_team != 0 or u.source_member_id.is_empty():continue
		var member: GuildMemberState = guild.get_member(u.source_member_id)
		if member == null or not member.is_alive():continue
		var gain: float = GuildMemberCombatStats.heal(guild, member, guild.member_stats(member).max_hp * data.amount)
		if gain > 0:healed[member.member_id] = gain
	battle.set_meta("lunchbox_healed", healed)
	fire(battle, &"lunchbox")
	return healed
