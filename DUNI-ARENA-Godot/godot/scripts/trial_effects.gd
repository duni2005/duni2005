class_name TrialEffects
extends RefCounted
## Runs a battle's 시련 (TrialCatalog; numbers there). "Enemies" are the units not on the
## player's side (original team 0): the room's enemies in the tower, every other team in a custom
## battle. Battle-long state lives in battle.trial_state: the clocks, falling meteors and the
## sniper's aim. Every hook returns at once when the battle has no trials.
const C = preload("res://scripts/trial_catalog.gd")

static func on(battle, id: StringName) -> bool:return battle != null and not battle.trials.is_empty() and id in battle.trials
static func enemy_side(u) -> bool:return u.original_team != 0

## Battle start: clocks, 짙은 안개 range, 선봉대 charge; in custom battles also the spawn changes the
## tower bakes into its rooms (정예 부대, 보물 수호자).
static func start(battle) -> void:
	if battle.trials.is_empty():return
	battle.trial_state = {"meteor_clock": C.METEOR_EVERY, "quake_clock": C.QUAKE_EVERY, "sniper_clock": C.SNIPER_EVERY, "regen_clock": 0.0, "meteors": [], "aim": {}, "quake_warned": false, "lightning_clock": C.LIGHTNING_EVERY, "bolts": [], "blasts": []}
	# 구조물: the room's saved layout; a custom battle lays its objects out from a fixed seed.
	if battle.trials.any(func(t):return C.kind_of(t) == C.STRUCTURE):
		var rows: Array = battle.field_layout
		if rows.is_empty() and battle.custom_mode:
			var rng := RandomNumberGenerator.new();rng.seed = hash("custom:objects")
			rows = FieldObjects.layout(rng, battle.trials, battle.units.filter(func(u):return enemy_side(u)).map(func(u):return u.position * ArenaMap.BOARD / ArenaMap.side))
		FieldObjects.start(battle, rows)
	if battle.custom_mode and on(battle, &"elite_squad"):_elite(battle)
	for u in battle.units:
		if on(battle, &"fog"):_fog(u)
		if not enemy_side(u):continue
		if battle.custom_mode and on(battle, &"treasure_guard"):
			var stats: UnitCombatStats = ItemEffects._own(u);stats.max_hp = floorf(stats.max_hp * C.TREASURE_HP + .5);u.max_hp = stats.max_hp;u.current_hp = u.max_hp
		if on(battle, &"vanguard") and battle.full_characters_enabled:u.brain.commit_until = C.VANGUARD_TIME
## 짙은 안개: the unit's own copy of its data with a shorter reach.
static func _fog(u) -> void:
	var data: UnitData = u.data.duplicate(true)
	var k: float = maxf(C.FOG_MIN_RANGE, data.attack_range * C.FOG_RANGE) / maxf(1, data.attack_range)
	if k >= 1:return
	data.attack_range *= k;data.attack_profile.reach *= k;data.attack_profile.projectile_lifetime *= k;u.data = data
	u.set_state("fogRange", k)
## Custom battles: the costliest enemy becomes an elite (the tower makes it one in the room).
static func _elite(battle) -> void:
	var best = null
	for u in battle.units:
		if enemy_side(u) and (best == null or u.data.base_gold_cost > best.data.base_gold_cost):best = u
	if best == null:return
	var e := EnemySpawnEntry.new();e.set_rank(&"elite")
	var stats: UnitCombatStats = ItemEffects._own(best)
	stats.max_hp = floorf(stats.max_hp * e.hp_multiplier + .5);stats.attack *= e.damage_multiplier
	stats.physical_defense *= e.defense_multiplier;stats.magic_defense *= e.defense_multiplier;stats.scale *= e.body_scale
	best.max_hp = stats.max_hp;best.current_hp = best.max_hp;best.base_move_speed *= e.speed_multiplier
	best.set_state("trialElite", 1.0)

static func advance(battle, dt: float) -> void:
	var s: Dictionary = battle.trial_state
	if s.is_empty() or battle.finished or dt <= 0:return
	for u in battle.units:
		if u.alive and u.state_value("quakeTime") > 0:u.set_state("quakeTime", maxf(0, u.state_value("quakeTime") - dt))
	if on(battle, &"meteor"):_meteors(battle, s, dt)
	if on(battle, &"quake"):_quake(battle, s, dt)
	if on(battle, &"sniper"):_sniper(battle, s, dt)
	if on(battle, &"lightning"):_lightning(battle, s, dt)
	if not s.blasts.is_empty():_blasts(battle, s, dt)
	if not battle.field_objects.is_empty():FieldObjects.advance(battle, dt)
	if on(battle, &"regen"):
		s.regen_clock = float(s.regen_clock) + dt
		while float(s.regen_clock) >= 1.0:
			s.regen_clock = float(s.regen_clock) - 1.0
			for u in battle.units:
				if u.alive and enemy_side(u) and u.current_hp < u.max_hp:
					var gain: float = StrategyEffects.heal(u, u.max_hp * C.REGEN_PER_SECOND)
					if gain > 0:battle.emit_combat_event(&"trial_regen", u.position, {"actor_id": u.battle_id, "amount": gain})

## 소행성: a warning circle, then a blow to everyone inside it.
static func _meteors(battle, s: Dictionary, dt: float) -> void:
	s.meteor_clock = float(s.meteor_clock) - dt
	if float(s.meteor_clock) <= 0:
		s.meteor_clock = float(s.meteor_clock) + C.METEOR_EVERY
		var margin: float = 80
		var at := Vector2(battle.rng.randf_range(margin, ArenaMap.side - margin), battle.rng.randf_range(margin, ArenaMap.side - margin))
		s.meteors.append({"point": at, "left": C.METEOR_WARN, "radius": C.METEOR_RADIUS})
		battle.emit_combat_event(&"trial_meteor_warn", at, {"radius": C.METEOR_RADIUS, "warn": C.METEOR_WARN})
	for m in s.meteors.duplicate():
		m.left = float(m.left) - dt
		if float(m.left) > 0:continue
		s.meteors.erase(m)
		var damage: float = C.METEOR_BASE + C.METEOR_PER_FLOOR * battle.trial_floor
		for u in battle.units.duplicate():
			if u.alive and u.position.distance_to(m.point) <= float(m.radius) + 20 * u.combat_scale():hit(battle, u, damage, &"trial", &"meteor")
		battle.emit_combat_event(&"trial_meteor", m.point, {"radius": float(m.radius)})
## 낙뢰: three warned spots (two by random units, so they threaten someone), then bolts that hurt
## and shock everyone inside.
static func _lightning(battle, s: Dictionary, dt: float) -> void:
	s.lightning_clock = float(s.lightning_clock) - dt
	if float(s.lightning_clock) <= 0:
		s.lightning_clock = float(s.lightning_clock) + C.LIGHTNING_EVERY
		var living: Array = battle.units.filter(func(u):return u.alive and not u.unavailable())
		var margin: float = 60
		for i in range(C.LIGHTNING_STRIKES):
			var at := Vector2(battle.rng.randf_range(margin, ArenaMap.side - margin), battle.rng.randf_range(margin, ArenaMap.side - margin))
			if i < C.LIGHTNING_NEAR and not living.is_empty():
				var near = living[battle.rng.randi_range(0, living.size() - 1)]
				at = ArenaMap.clamp_in(near.position + Vector2(battle.rng.randf_range(-C.LIGHTNING_SPREAD, C.LIGHTNING_SPREAD), battle.rng.randf_range(-C.LIGHTNING_SPREAD, C.LIGHTNING_SPREAD)), margin)
			s.bolts.append({"point": at, "left": C.LIGHTNING_WARN, "radius": C.LIGHTNING_RADIUS})
			battle.emit_combat_event(&"trial_lightning_warn", at, {"radius": C.LIGHTNING_RADIUS, "warn": C.LIGHTNING_WARN})
	for b in s.bolts.duplicate():
		b.left = float(b.left) - dt
		if float(b.left) > 0:continue
		s.bolts.erase(b)
		var damage: float = C.LIGHTNING_BASE + C.LIGHTNING_PER_FLOOR * battle.trial_floor
		for u in battle.units.duplicate():
			if not u.alive or u.position.distance_to(b.point) > float(b.radius) + 20 * u.combat_scale():continue
			hit(battle, u, damage, &"trial", &"lightning")
			if u.alive:ElementEffects.add_shock(u, C.LIGHTNING_SHOCK)
		if not battle.field_objects.is_empty():FieldObjects.area(battle, b.point, float(b.radius))
		battle.emit_combat_event(&"trial_lightning", b.point, {"radius": float(b.radius)})
## 순교자: marked circles shrinking to their blast (the player's side only).
static func _blasts(battle, s: Dictionary, dt: float) -> void:
	for m in s.blasts.duplicate():
		m.left = float(m.left) - dt
		if float(m.left) > 0:continue
		s.blasts.erase(m)
		for u in battle.units.duplicate():
			if not u.alive or enemy_side(u) or u.position.distance_to(m.point) > float(m.radius) + 20 * u.combat_scale():continue
			hit(battle, u, float(m.damage), &"trial", &"martyr")
			var away: Vector2 = u.position - Vector2(m.point)
			if u.alive:u.knockback_velocity = (away.normalized() if away.length() > .01 else Vector2.LEFT) * C.MARTYR_PUSH
		if not battle.field_objects.is_empty():FieldObjects.area(battle, m.point, float(m.radius))
		battle.emit_combat_event(&"trial_martyr", m.point, {"radius": float(m.radius)})
## 지진: shakes QUAKE_WARN s before, then everyone falls.
static func _quake(battle, s: Dictionary, dt: float) -> void:
	s.quake_clock = float(s.quake_clock) - dt
	if not bool(s.quake_warned) and float(s.quake_clock) <= C.QUAKE_WARN:
		s.quake_warned = true;battle.emit_combat_event(&"trial_quake_warn", ArenaMap.center(), {})
	if float(s.quake_clock) > 0:return
	s.quake_clock = float(s.quake_clock) + C.QUAKE_EVERY;s.quake_warned = false
	for u in battle.units:
		if not u.alive or u.unavailable():continue
		StatusController.stun(u, C.QUAKE_FALL);u.set_state("quakeTime", C.QUAKE_FALL)
	battle.emit_combat_event(&"trial_quake", ArenaMap.center(), {})
## 저격 지원: aims at the ally with the most HP from beyond the enemy edge, then fires.
static func _sniper(battle, s: Dictionary, dt: float) -> void:
	var aim: Dictionary = s.aim
	if aim.is_empty():
		s.sniper_clock = float(s.sniper_clock) - dt
		if float(s.sniper_clock) > 0:return
		var target = null
		for u in battle.units:
			if u.alive and not enemy_side(u) and not u.unavailable() and (target == null or u.current_hp > target.current_hp):target = u
		if target == null:s.sniper_clock = 1.0;return
		s.aim = {"target": target.actor_id(), "left": C.SNIPER_AIM};return
	var target = battle.find_actor(String(aim.target))
	aim.left = float(aim.left) - dt
	if target == null or not target.alive:s.aim = {};s.sniper_clock = C.SNIPER_EVERY;return
	if float(aim.left) > 0:return
	s.aim = {};s.sniper_clock = C.SNIPER_EVERY
	hit(battle, target, C.SNIPER_BASE + C.SNIPER_PER_FLOOR * battle.trial_floor, &"physical", &"sniper")
	battle.emit_combat_event(&"trial_snipe", target.position, {"from": sniper_origin(battle, target.position)})
## Where the sniper fires from: just beyond the enemies' edge of the field, level with the target.
static func sniper_origin(_battle, at: Vector2) -> Vector2:return Vector2(ArenaMap.side + 60, at.y)

## A hit from a trial (not a unit): 소행성 is 시련 피해 (only defense applies), 저격 지원 physical.
## No counter, element or tag bonus; invincible units are spared. Returns the HP lost.
static func hit(battle, target, raw: float, kind: StringName, trial: StringName = &"") -> float:
	if not target.alive or target.invincible_remaining > 0 or not battle.started or battle.finished or battle.clock.is_turning_paused():return 0.0
	var mitigation: float = UnitStatTable.mitigation(CombatRules.defense_sum(target)) if kind == &"trial" else CombatRules.mitigation(target, kind)
	var amount: float = CombatRules.js_round(raw * mitigation)
	var absorbed: float = StrategyEffects.absorb(target, amount)
	var lost: float = target.receive_damage(amount - absorbed, null, true)
	battle.stats.damage(null, target, lost + absorbed)
	battle.emit_combat_event(&"trial_hit", target.position, {"actor_id": target.battle_id, "amount": lost + absorbed, "kind": String(kind), "trial": String(trial)})
	target.announce_death(null)
	return lost

## 카운터: share of a hit an enemy takes (COUNTER_TAKEN once, however many counters match).
static func counter_factor(battle, target, kind: StringName, tags: Array) -> float:
	return C.COUNTER_TAKEN if counter_of(battle, target, kind, tags) != &"" else 1.0
## The first 카운터 of the battle that cuts this hit on `target` (&"" when none does).
static func counter_of(battle, target, kind: StringName, tags: Array) -> StringName:
	if battle.trials.is_empty() or not enemy_side(target):return &""
	var hits: Array[StringName] = C.counters_for(battle.trials, kind, tags)
	return hits[0] if not hits.is_empty() else &""
## 광전사들 attack speed.
static func attack_speed(u) -> float:
	if u.battle == null or u.battle.trials.is_empty() or not enemy_side(u):return 1.0
	return C.BERSERK_ATTACK_SPEED if berserk(u) else 1.0
## 광전사들 / 선봉대 (and 금괴 운반대 in custom battles; the tower bakes it into the room) move speed.
static func move_speed(u) -> float:
	var battle = u.battle
	if battle == null or battle.trials.is_empty() or not enemy_side(u):return 1.0
	var k: float = C.BERSERK_MOVE if berserk(u) else 1.0
	if vanguard(u):k *= C.VANGUARD_MOVE
	if battle.custom_mode and on(battle, &"gold_convoy"):k *= C.CONVOY_SPEED
	return k
## 복수심 attack %.
static func attack_factor(u) -> float:
	if u.battle == null or u.battle.trials.is_empty():return 1.0
	return 1 + C.VENGEANCE_ATTACK * u.state_value("vengeanceStacks")
static func berserk(u) -> bool:return on(u.battle, &"berserkers") and enemy_side(u) and u.alive and u.current_hp <= u.max_hp * C.BERSERK_HP
static func vanguard(u) -> bool:return on(u.battle, &"vanguard") and enemy_side(u) and u.battle.clock.elapsed < C.VANGUARD_TIME
## 복수심: a fallen enemy spurs the enemies around it. 순교자: it leaves a blast behind (the last
## of a split family only, for less).
static func on_death(battle, victim) -> void:
	if battle.trials.is_empty() or not enemy_side(victim):return
	if on(battle, &"martyr") and battle.full_characters_enabled and not victim.character_specific_state.has("mirrorOf") and not family_alive(victim):
		var damage: float = victim.max_hp * C.MARTYR_HP * (C.MARTYR_SPLIT_FACTOR if victim.character_specific_state.has("slimeFamily") else 1.0)
		battle.trial_state.blasts.append({"point": victim.position, "left": C.MARTYR_FUSE, "radius": C.MARTYR_RADIUS, "damage": damage})
		battle.emit_combat_event(&"trial_martyr_mark", victim.position, {"radius": C.MARTYR_RADIUS, "warn": C.MARTYR_FUSE})
	if not on(battle, &"vengeance"):return
	for u in battle.units:
		if u.alive and u != victim and enemy_side(u) and u.position.distance_to(victim.position) <= C.VENGEANCE_RADIUS:
			u.set_state("vengeanceStacks", minf(C.VENGEANCE_MAX, u.state_value("vengeanceStacks") + 1))
## Another of `u`'s split family (슬라임, 분열) is still alive.
static func family_alive(u) -> bool:
	var family: String = str(u.character_specific_state.get("slimeFamily", ""))
	if family.is_empty():return false
	return u.battle.units.any(func(v):return v != u and v.alive and v.team == u.team and str(v.character_specific_state.get("slimeFamily", "")) == family)
## The room enemy a fallen unit counts for (kill gold): its own, or the one its family split from.
static func reward_enemy_id(u) -> String:
	return u.source_enemy_id if not u.source_enemy_id.is_empty() else str(u.character_specific_state.get("splitSource", ""))

## 분열: an enemy's first deadly blow splits it in two instead, the slime's way (SlimeAbility): each
## keeps SPLIT_HP of its HP, SPLIT_FACTOR of its damage and a smaller body, and is briefly
## invincible. Once only, no ultimate afterwards; elites lose their elite multipliers; slimes keep
## their own rule and 챕터 보스 never split.
static func split(u) -> bool:
	var battle = u.battle
	if not on(battle, &"split") or not enemy_side(u) or u.data.type_id == SLIME_TYPE or u.state_value("trialSplit") > 0 or u.character_specific_state.has("mirrorOf"):return false
	if u.combat_stats == null:u.combat_stats = UnitCombatStats.from_table(u.data)
	if u.combat_stats.rank == &"boss":return false
	var slime = preload("res://scripts/abilities/slime_ability.gd")
	var stats: UnitCombatStats = slime.halved(_plain(u))
	u.combat_stats = stats;u.current_hp = stats.max_hp
	u.set_state("trialSplit", 1.0);u.set_state("trialElite", 0.0)
	if not u.character_specific_state.has("slimeFamily"):u.set_state("slimeFamily", u.actor_id())
	if not u.source_enemy_id.is_empty():u.set_state("splitSource", u.source_enemy_id)
	u.invincible_remaining = maxf(u.invincible_remaining, .35)
	var away: Vector2 = Vector2.from_angle(battle.rng.randf_range(0, TAU))
	u.knockback_velocity = away * 260
	var state: Dictionary = u.character_specific_state.duplicate(true)
	for key in ["burnStacks", "poisonStacks", "darkMark", "lightMark", "vengeanceStacks"]:state.erase(key)
	battle.queue_spawn(u, u.position - away * 30, slime.halved(stats, 1.0), state, -away * 260)
	battle.emit_combat_event(&"trial_split", u.position, {"actor_id": u.battle_id})
	return true
const SLIME_TYPE: int = 35
## `u`'s stats without the elite multipliers (tower elites, or 정예 부대 in a custom battle).
static func _plain(u) -> UnitCombatStats:
	var stats: UnitCombatStats = u.combat_stats
	var tower: bool = stats.rank == &"elite";var custom: bool = u.state_value("trialElite") > 0 and not tower
	if not tower and not custom:return stats
	var e := EnemySpawnEntry.new();e.set_rank(&"elite")
	var plain: UnitCombatStats = preload("res://scripts/abilities/slime_ability.gd").halved(stats, 1.0)
	var hp: float = e.hp_multiplier * (float(TowerEnemyStatsAssembler.RANK_HP[&"elite"]) if tower and UnitBalance.enabled else 1.0)
	var dmg: float = e.damage_multiplier * (float(TowerEnemyStatsAssembler.RANK_DAMAGE[&"elite"]) if tower and UnitBalance.enabled else 1.0)
	var def: float = e.defense_multiplier * (e.defense_multiplier if tower else 1.0)
	plain.max_hp = floorf(stats.max_hp / hp + .5);plain.attack = stats.attack / dmg;plain.physical_defense = stats.physical_defense / def;plain.magic_defense = stats.magic_defense / def
	plain.scale = stats.scale / e.body_scale;plain.rank = &"normal"
	if tower:plain.speed = stats.speed / e.speed_multiplier
	else:u.base_move_speed /= e.speed_multiplier
	return plain

## Kill gold factor (금괴 운반대) for a room's battle.
static func kill_gold(trials: Array) -> float:return C.CONVOY_KILL_GOLD if &"gold_convoy" in trials else 1.0
static func victory_gold(trials: Array) -> float:return C.CONVOY_VICTORY_GOLD if &"gold_convoy" in trials else 1.0
static func extra_choices(trials: Array) -> int:return C.TREASURE_CHOICES if &"treasure_guard" in trials else 0
