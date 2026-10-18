class_name BattleManager
extends Node2D

signal battle_finalizing(reason: BattleEndReason.Value)
signal battle_finished(result: BattleResult)
signal unit_died(unit: BattleUnit, source)

const UNIT_SCENE: PackedScene = preload("res://scenes/unit.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectile.tscn")
const WARRIOR: UnitData = preload("res://data/warrior.tres")
const ARCHER: UnitData = preload("res://data/archer.tres")

# Explicit golden-comparison mode preserves Phases 1–6 numerical fixtures.
# The current room/F5 screen enables the migrated common rules.
@export var common_combat_enabled: bool = true
## Custom battle: any number of teams/free-for-all units, every unit may use transcendence.
var custom_mode: bool = false
@export var full_characters_enabled: bool = true
@export var auto_start: bool = true
@export var random_seed: int = -1
var units: Array[BattleUnit] = []
var projectiles: Array[BattleProjectile] = []
var clock := BattleClock.new()
var rng := RandomNumberGenerator.new()
var damage_resolver: DamageResolver
var started: bool = false
var finished: bool = false
var result: BattleResult
var battle_result_id: String = ""
var source_run_id: String = ""
var room_id: String = ""
var run_end_requested: bool = false
var turning: TurningPointManager
var melee_strikes: Array[AttackInstance] = []
var combat_waves: Array[CombatWave] = []
var physical_serial: int = 0
var knockback_serial: int = 0
var collision_pairs: Dictionary = {}
var combat_events: Array[Dictionary] = []
var combat_event_counts: Dictionary = {}
var zones := BattleZones.new()
var transcendence: TranscendenceController
var unit_factory := BattleUnitFactory.new(UNIT_SCENE)

func _ready() -> void:
	if auto_start:
		start_battle(default_placements(), random_seed)

static func default_placements() -> Array[Dictionary]:
	return [
		{"data": WARRIOR, "team": 0, "position": Vector2(160, 260)},
		{"data": WARRIOR, "team": 0, "position": Vector2(160, 540)},
		{"data": ARCHER, "team": 0, "position": Vector2(80, 400)},
		{"data": WARRIOR, "team": 1, "position": Vector2(640, 260)},
		{"data": WARRIOR, "team": 1, "position": Vector2(640, 540)},
		{"data": ARCHER, "team": 1, "position": Vector2(720, 400)},
	]

func start_battle(placements: Array[Dictionary], seed_value: int = -1) -> bool:
	# One manager instance represents one battle; no implicit restart/persistence.
	if started:
		return false
	if full_characters_enabled:common_combat_enabled=true
	var validation: Dictionary = BattleUnitFactory.validate_placements(placements)
	if not validation.ok:
		return false
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	damage_resolver = DamageResolver.new(self, rng)
	# Independent of combat RNG, type/member IDs and Godot Node instance IDs.
	battle_result_id = "battle_" + Crypto.new().generate_random_bytes(16).hex_encode()
	source_run_id = validation.source_run_id
	started = true
	for placement in placements:
		var unit: BattleUnit = unit_factory.create(placement, units.size() + 1, self, rng)
		unit.died.connect(_on_unit_died)
		units.append(unit)
		add_child(unit)
	if full_characters_enabled:
		transcendence=TranscendenceController.new(self)
		for actor in units:
			CharacterPersistence.restore(actor)
			if not actor.character_specific_state.has("heal"):actor.set_state("heal",rng.randf_range(1,3))
			if not actor.character_specific_state.has("dash"):actor.set_state("dash",rng.randf_range(2,5))
		for actor in units:
			actor.ability.on_spawn(actor)
			if actor.stance==CombatStance.COVER:CharacterLifecycle.bind_cover(actor)
		for actor in units:CharacterPersistence.restore_control(actor)
	check_outcome()
	return true

func start_guild_battle(guild: GuildManager, deployments: Array[Dictionary], enemies: Array[Dictionary], seed_value: int = -1) -> bool:
	if started or guild == null or deployments.is_empty():
		return false
	var placements: Array[Dictionary] = []
	for deployment in deployments:
		if not deployment.get("member_id") is String or not deployment.get("position") is Vector2:
			return false
		var prepared: Dictionary = BattleUnitFactory.guild_placement(guild, deployment.member_id, deployment.position, int(deployment.get("team", 0)))
		if prepared.is_empty():
			return false
		placements.append(prepared)
	for enemy in enemies:
		if enemy.has("member"):
			return false
		placements.append(enemy)
	return start_battle(placements, seed_value)

func enable_turning_points(guild: GuildManager) -> void:
	if turning == null and started and not finished and not room_id.is_empty():
		turning = TurningPointManager.new(self, guild)

func _physics_process(delta: float) -> void:
	simulate(delta)

func simulate(real_delta: float) -> void:
	if not started or finished:
		return
	if transcendence!=null and transcendence.advance(real_delta):return
	var simulation_real_delta: float = real_delta
	if turning != null:
		# Outcomes outrank a pending trigger or resume, including during pause.
		if turning.guild.state.player_hp <= 0:
			run_end_requested = true
		check_outcome()
		if finished:
			return
		var previous_resolves: int = turning.resolve_count
		turning.advance(real_delta)
		if turning.resolve_count != previous_resolves:
			# Web resumes with capped frame dt, never the whole strategy wall time.
			simulation_real_delta = minf(real_delta, 0.1)
	var delta: float = clock.advance(real_delta, simulation_real_delta)
	if delta <= 0.0:
		return
	if common_combat_enabled:
		simulate_common(delta)
		return
	for unit in units:
		if not unit.alive:
			continue
		StrategyEffects.advance(unit, delta)
		unit.target = unit.target_selector.select_target(unit, units)
		unit.movement.advance(unit, delta)
		unit.combat.advance(unit, delta, self)
		if unit.combat.can_start(unit, unit.target):
			unit.combat.start(unit, unit.target, rng)
		unit.queue_redraw()
	# Like web physicalSlice: collect/time-sort contacts, then apply; only then end.
	var remaining: float = delta
	while remaining > 0.00000001:
		var slice: float = minf(remaining, 1.0 / 120.0)
		advance_attacks(slice)
		remaining -= slice
	check_outcome()
	queue_redraw()

func spawn_projectile(unit: BattleUnit, aim: float) -> void:
	if finished or not started or not unit.alive or clock.is_turning_paused():
		return
	var spread: float = unit.data.attack_profile.projectile_spread
	var arrow: BattleProjectile = PROJECTILE_SCENE.instantiate()
	arrow.initialize(unit, aim + rng.randf_range(-spread, spread))
	if common_combat_enabled:
		physical_serial += 1
		arrow.projectile_id = physical_serial
		var attack := AttackInstance.new()
		attack.attack_id = physical_serial
		attack.source_battle_id = unit.battle_id
		attack.team = unit.team
		attack.attack_type = &"projectile"
		attack.shape = &"circle"
		attack.position = arrow.position
		attack.start_position = arrow.position
		attack.end_position = arrow.position+arrow.velocity*arrow.lifetime
		attack.velocity = arrow.velocity
		attack.power = arrow.power
		attack.damage = arrow.damage
		attack.impulse = unit.data.attack_profile.impulse
		attack.radius = arrow.hit_radius
		attack.life = arrow.lifetime
		attack.hidden_launch = arrow.hidden_launch
		arrow.attack_instance = attack
		unit.knockback_velocity -= Vector2.from_angle(aim)*60
	projectiles.append(arrow)
	add_child(arrow)
	# MIGRATION_NOTE: archer's third-shot fan/bounces are not part of Phase 1.

func advance_attacks(delta: float) -> void:
	if finished or clock.is_turning_paused():
		return
	if common_combat_enabled:
		PhysicalAttackSystem.advance(self,delta)
		for actor in units: actor.queue_redraw()
		queue_redraw()
		return
	var contacts: Array[Dictionary] = []
	for unit in units:
		contacts.append_array(unit.combat.collect_melee_hits(unit, units, delta))
	for arrow in projectiles:
		contacts.append_array(arrow.collect_hits(units, delta))
	contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time < b.time)
	for contact in contacts:
		if not contact.target.alive:
			continue
		if contact.projectile:
			var arrow: BattleProjectile = contact.object
			if not arrow.live:
				continue
			arrow.position += arrow.velocity * float(contact.time)
			arrow.live = false
		elif not contact.source.alive:
			continue
		damage_resolver.apply(contact.source, contact.target, contact.damage)
	for arrow in projectiles:
		arrow.advance(delta)
	for index in range(projectiles.size() - 1, -1, -1):
		if not projectiles[index].live:
			projectiles[index].queue_free()
			projectiles.remove_at(index)

func _on_unit_died(unit: BattleUnit, source) -> void:
	unit_died.emit(unit, source)
	# Never decide victory during individual damage: other contacts may still kill.

func check_outcome() -> void:
	if not started or finished:
		return
	if run_end_requested:
		finish_with_reason(BattleEndReason.Value.RUN_ENDED, -1)
		return
	var factions: Dictionary = {}
	for unit in units:
		if unit.alive:
			factions[unit.original_team if full_characters_enabled else unit.team] = true
	if factions.size() > 1:
		return
	var winning_team: int = -1 if factions.is_empty() else int(factions.keys()[0])
	# Custom battles have no player side: whichever faction survives is the victor.
	var reason: BattleEndReason.Value = BattleEndReason.Value.DRAW if factions.is_empty() else BattleEndReason.Value.VICTORY if winning_team == 0 or custom_mode else BattleEndReason.Value.DEFEAT
	finish_with_reason(reason, winning_team)

func finish_with_reason(reason: BattleEndReason.Value, winning_team: int) -> bool:
	if not started or finished:
		return false
	if full_characters_enabled: CharacterLifecycle.release_cargo(self)
	finished = true
	if turning != null:
		turning.cancel()
	clock.stop()
	# Room-owned victory recovery happens once, after cargo release and before
	# detached snapshots. Combat is already stopped so no new attacks can occur.
	battle_finalizing.emit(reason)
	# Snapshot cooldown before cancelling normal attack execution.
	result = BattleResult.new()
	result.completed = true
	result.battle_result_id = battle_result_id
	result.source_run_id = source_run_id
	result.room_id = room_id
	result.end_reason = reason
	result.draw = reason == BattleEndReason.Value.DRAW
	result.winner_team = winning_team
	result.elapsed = clock.elapsed
	for unit in units:
		if unit.alive:
			result.survivors.append(unit.battle_id)
		result.units.append({"battle_id": unit.battle_id, "type_id": unit.data.type_id, "team": unit.team, "hp": unit.current_hp, "alive": unit.alive, "position": unit.position})
		result.capture_member(unit)
		result.capture_enemy(unit)
	# Discard runtime execution AFTER detached persistence snapshots are captured.
	for unit in units:
		unit.combat.cancel(unit)
		unit.velocity = Vector2.ZERO
		if not room_id.is_empty():
			unit.target = null
	for arrow in projectiles:
		arrow.queue_free()
	projectiles.clear()
	melee_strikes.clear()
	combat_waves.clear()
	zones.entries.clear()
	if transcendence!=null:transcendence.reset()
	for unit in units:
		unit.knockback_velocity = Vector2.ZERO
		unit.threat_response.response.clear()
	battle_finished.emit(result)
	queue_redraw()
	return true

func _draw() -> void:
	draw_rect(Rect2(0, 0, 800, 800), Color("101824"))
	for grid in range(0, 801, 100):
		draw_line(Vector2(grid, 0), Vector2(grid, 800), Color("1a2636"))
		draw_line(Vector2(0, grid), Vector2(800, grid), Color("1a2636"))
	draw_rect(Rect2(0, 0, 800, 800), Color("34445d"), false, 2.0)
	if full_characters_enabled:
		for zone in zones.entries:
			var color: Color=Color(.5,.9,.6,.18) if zone.kind in ["healing","holy"] else Color(.8,.5,1,.2)
			draw_circle(CharacterPersistence.vector(zone.point),float(zone.radius),color)
		if transcendence!=null:
			var action: Dictionary=transcendence.aim if not transcendence.aim.is_empty() else transcendence.cast
			if not action.is_empty():
				var actor=find_actor(action.actor)
				if actor!=null:
					var direction: Vector2=Vector2.from_angle(action.angle)
					draw_line(actor.position,actor.position+direction*310*actor.combat_scale(),Color("cd9aff"),5)
	if common_combat_enabled:
		for attack in melee_strikes:
			var owner: BattleUnit = find_unit(attack.source_battle_id)
			if owner != null:
				var blade: Array[Vector2] = attack.blade(owner.position)
				draw_line(blade[0],blade[1],Color("ffe7a0"),3)
		for event in combat_events:
			if clock.elapsed-float(event.time) > .45: continue
			if event.kind in [&"clash",&"parry_success",&"warrior_parry"]:
				var font: Font=ThemeDB.fallback_font
				draw_string(font,event.point+Vector2(-30,-75),str(event.kind),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("d7eeff"))
		for wave in combat_waves:
			# Diagnostic pulse only, deliberately subdued; final VFX remains later.
			var radius: float=wave.radius*minf(1,wave.age/wave.duration)
			for i in range(16):
				var a: float=TAU*i/16
				draw_line(wave.origin+Vector2.from_angle(a)*radius,wave.origin+Vector2.from_angle(a+.08)*radius,Color(0.7,0.8,1,.25),2)

func find_unit(id: int) -> BattleUnit:
	for unit in units:
		if unit.battle_id == id: return unit
	return null
func emit_combat_event(kind: StringName, point: Vector2, metadata: Dictionary) -> void:
	combat_event_counts[kind] = int(combat_event_counts.get(kind,0))+1
	combat_events.append({"kind":kind,"point":point,"metadata":metadata.duplicate(true),"time":clock.elapsed})
	if combat_events.size() > 64: combat_events.pop_front()
func spawn_melee_strike(unit: BattleUnit, profile: AttackData, damage: float) -> AttackInstance:
	if finished or clock.is_turning_paused() or not unit.alive or unit.stun_remaining > 0: return null
	physical_serial += 1
	var attack := AttackInstance.new()
	attack.attack_id = physical_serial
	attack.source_battle_id = unit.battle_id
	attack.source_attack_serial = unit.combat.attack_serial
	attack.team = unit.team
	attack.angle = unit.combat.aim_angle
	attack.position = unit.position
	attack.start_position = unit.position
	attack.end_position = unit.position+Vector2.from_angle(attack.angle)*profile.reach
	attack.reach = profile.reach*(unit.combat_scale() if full_characters_enabled else 1)
	attack.cone = profile.cone
	attack.damage = damage
	attack.power = damage
	attack.impulse = profile.impulse
	attack.duration = profile.active
	attack.life = profile.active+PhysicalAttackSystem.GRACE
	attack.hidden_launch = unit.combat.hidden_launch
	melee_strikes.append(attack)
	return attack
func spawn_combat_wave(kind: StringName, point: Vector2, sources: Array, radius: float, stun: float, force: float, excludes: Array) -> CombatWave:
	var wave := CombatWave.new()
	wave.kind = kind
	wave.origin = point
	for id in sources: wave.source_ids.append(int(id))
	for id in excludes: wave.hit_ids[int(id)] = true
	wave.radius = radius
	wave.stun_duration = stun
	wave.force = force
	combat_waves.append(wave)
	if combat_waves.size() > 24: combat_waves.pop_front()
	return wave
func simulate_common(delta: float) -> void:
	if full_characters_enabled:
		CharacterLifecycle.advance(self,delta)
	var old_stuns: Dictionary = {}
	for unit in units:
		if not unit.alive: continue
		if unit.stun_remaining > 0:
			old_stuns[unit.battle_id] = {"time":unit.stun_remaining,"revision":unit.stun_revision}
			StatusController.interrupt(unit)
		StrategyEffects.advance(unit,delta)
	if full_characters_enabled:zones.advance(self,delta)
	for unit in units:
		if not unit.alive: continue
		if unit.stun_remaining > 0:
			unit.velocity = Vector2.ZERO
			unit.combat.cooldown -= delta*(unit.ability.attack_rate(unit) if full_characters_enabled else 1)
			KnockbackController.advance(unit,delta)
			unit.queue_redraw()
			continue
		if full_characters_enabled:
			if unit.unavailable():continue
			unit.combat.cooldown-=delta*unit.ability.attack_rate(unit)
			unit.ultimate.advance_charge(unit,delta)
			if unit.data.type_id!=5:unit.ability.tick(unit,delta)
			if unit.ability.locked(unit):continue
		unit.threat_response.advance(unit)
		unit.target = unit.target_selector.select_target(unit,units)
		if full_characters_enabled:unit.brain.advance(unit,unit.target,delta)
		unit.movement.advance(unit,delta)
		if full_characters_enabled and unit.target!=null and unit.combat_state==CombatController.State.IDLE and unit.ultimate.cast.is_empty():unit.brain.turn_face(unit,unit.target.position,delta)
		KnockbackController.advance(unit,delta)
		if not unit.alive: continue
		if full_characters_enabled:
			unit.ultimate.advance_action(unit,delta)
		unit.combat.advance(unit,delta,self,not full_characters_enabled)
		if full_characters_enabled and unit.data.type_id==5:unit.ability.tick(unit,delta)
		if unit.combat.can_start(unit,unit.target): unit.combat.start(unit,unit.target,rng)
		unit.queue_redraw()
	if full_characters_enabled:BindingController.advance(self,delta)
	PhysicalAttackSystem.advance(self,delta)
	for wave in combat_waves: wave.advance(self,delta)
	for i in range(combat_waves.size()-1,-1,-1):
		if combat_waves[i].life <= 0: combat_waves.remove_at(i)
	for id in old_stuns:
		var unit: BattleUnit = find_unit(id)
		if unit.alive and unit.stun_revision == old_stuns[id].revision: unit.stun_remaining = maxf(0,old_stuns[id].time-delta)
	if collision_pairs.size() > 150:
		for key in collision_pairs.keys():
			if clock.elapsed-float(collision_pairs[key]) > 1: collision_pairs.erase(key)
	check_outcome()
	queue_redraw()

func find_actor(id: String) -> BattleUnit:
	for u in units:
		if u.actor_id()==id:return u
	return null
func character_death(victim,source) -> void:
	var enemy_kill: bool=is_instance_valid(source) and source.team!=victim.team
	victim.ability.on_death(victim)
	if enemy_kill:
		source.ability.on_kill(source,victim)
		EquipmentCombatEffects.on_kill(source)
	CharacterLifecycle.on_death(victim)
