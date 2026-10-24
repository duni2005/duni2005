class_name CombatController
extends RefCounted
## Shared WINDUP -> ACTIVE -> RECOVERY flow. Only idle may start another attack.

enum State { IDLE, WINDUP, ACTIVE, RECOVERY }

var attack_metadata: Dictionary = {}
var active_profile: AttackData
var healing_target = null
var cooldown: float = 0.0
var phase_time: float = 0.0
var aim_angle: float = 0.0
var attack_target = null
var attacks_started: int = 0
var attacks_released: int = 0
var melee_live: bool = false
var melee_age: float = 0.0
var melee_hit_ids: Dictionary = {}
var attack_serial: int = 0
var fired: bool = false
var hidden_launch: bool = false
var counter: bool = false
var counter_dash_speed: float = 0
func profile(unit) -> AttackData:
	if not counter: return active_profile if active_profile!=null else unit.data.attack_profile
	var result: AttackData = unit.data.attack_profile.duplicate()
	result.windup = .19
	result.active = .16
	result.recovery = .25
	result.reach = 125
	result.impulse = 300
	return result
func start_counter(unit, enemy) -> bool:
	if not unit.alive or not is_instance_valid(enemy) or not enemy.alive or unit.stun_remaining > 0 or unit.battle.finished: return false
	cancel(unit)
	counter = true
	attack_target = enemy
	aim_angle = (enemy.position-unit.position).angle()
	counter_dash_speed = clampf(unit.position.distance_to(enemy.position)-55,12,140)/.19
	unit.knockback_velocity = Vector2.ZERO
	attack_serial += 1
	attacks_started += 1
	fired = false
	unit.combat_state = State.WINDUP
	cooldown = (.19+.16+.25+unit.data.attack_interval*unit.battle.rng.randf_range(.3,.55))/EquipmentCombatEffects.attack_speed(unit)
	return true

func can_start(unit, enemy) -> bool:
	if unit.battle.common_combat_enabled and (unit.stun_remaining > 0 or unit.evade_remaining > 0 or ParryController.perfect(unit) or unit.threat_response.response.get("mode", &"") == &"parry" or (unit.threat_response.response.get("mode", &"") in ([&"dodge"] if unit.battle.full_characters_enabled else [&"dodge", &"hold"]) and unit.threat_response.response.get("until",0) > unit.battle.clock.elapsed) or unit.area_evaluator.offense_blocked(unit)): return false
	if unit.battle.full_characters_enabled:
		if not unit.battle.started or unit.battle.finished or unit.battle.clock.is_turning_paused() or not unit.alive or unit.combat_state!=State.IDLE or cooldown>0 or not unit.target_selector.is_valid_enemy(unit,enemy):return false
		if unit.command_retreat_until>unit.battle.clock.elapsed or not unit.strategy_dash.is_empty() or unit.ability.locked(unit) or not unit.ultimate.cast.is_empty() or not unit.ability.can_attack(unit,enemy):return false
		if unit.position.distance_to(enemy.position)>=unit.ability.profile(unit).reach*(.9 if unit.data.attack_range<100 else 1)*unit.combat_scale():return false
		return not unit.ability.requires_initiative() or unit.brain.attack_ready(unit,enemy)
	return unit.battle.started and not unit.battle.finished and not unit.battle.clock.is_turning_paused() and unit.command_retreat_until <= unit.battle.clock.elapsed and unit.strategy_dash.is_empty() and unit.alive and unit.combat_state == State.IDLE and cooldown <= 0.0 and unit.target_selector.is_valid_enemy(unit, enemy) and unit.position.distance_to(enemy.position) < unit.data.attack_profile.start_distance()

func start(unit, enemy, rng: RandomNumberGenerator) -> bool:
	if not can_start(unit, enemy):
		return false
	counter = false
	attack_serial += 1
	fired = false
	hidden_launch = CombatPerception.concealed(unit)
	attack_target = enemy
	aim_angle = aim_direction(unit, enemy)
	if unit.battle.common_combat_enabled: unit.facing = aim_angle
	phase_time = 0.0
	unit.combat_state = State.WINDUP
	if unit.battle.full_characters_enabled:
		attack_metadata.clear();active_profile=unit.ability.profile(unit);unit.ability.on_attack_start(unit);unit.set_state("revealTime",3);unit.brain.attack_decision.clear();unit.brain.was_attacking=true
	var profile: AttackData = profile(unit)
	# TYPES.cd is an interval input, NOT the whole time between releases.
	cooldown = (unit.ability.attack_cooldown(unit,rng) if unit.battle.full_characters_enabled else profile.windup + profile.active + profile.recovery + unit.data.attack_interval * rng.randf_range(0.3, 0.55))/EquipmentCombatEffects.attack_speed(unit)
	attacks_started += 1
	return true

func advance(unit, delta: float, battle, tick_cooldown: bool=true) -> void:
	if not unit.alive or battle.finished or battle.clock.is_turning_paused():
		return
	var rate: float=unit.ability.attack_rate(unit) if battle.full_characters_enabled else 1
	if tick_cooldown:cooldown -= delta*rate
	if unit.combat_state == State.IDLE:
		return
	phase_time += delta*rate
	if battle.common_combat_enabled and unit.stun_remaining > 0:
		cancel(unit)
		return
	if battle.full_characters_enabled and unit.ability.attack_tick(unit,delta):return
	var profile: AttackData = profile(unit)
	match unit.combat_state:
		State.WINDUP:
			if battle.common_combat_enabled and counter:
				var before: Vector2 = unit.position
				unit.position = MovementController.clamp_position(unit.position+Vector2.from_angle(aim_angle)*counter_dash_speed*delta)
				unit.velocity = (unit.position-before)/delta
				unit.facing = aim_angle
			if not counter and unit.target_selector.is_valid_enemy(unit, attack_target) and phase_time < profile.windup * (unit.ability.windup_track_fraction(unit) if battle.full_characters_enabled else .65):
				aim_angle = unit.ability.track_aim(unit,aim_direction(unit,attack_target),delta) if battle.full_characters_enabled else lerp_angle(aim_angle, aim_direction(unit, attack_target), minf(1.0, delta * 5.0))
			if battle.common_combat_enabled: unit.facing = aim_angle
			if phase_time >= profile.windup:
				unit.combat_state = State.ACTIVE
				phase_time = 0.0
				attacks_released += 1
				fired = true
				if battle.full_characters_enabled:
					if is_instance_valid(healing_target):
						if healing_target.alive and healing_target.team==unit.team and unit.position.distance_to(healing_target.position)<280*unit.combat_scale():CharacterAbility.restore_hp(healing_target,maxf(3,(8.5 if healing_target==unit else 22)-battle.clock.elapsed*.07),unit)
						healing_target=null
					else:
						unit.ability.release_basic(unit);unit.brain.released(unit)
				elif profile.kind == AttackData.Kind.PROJECTILE:
					battle.spawn_projectile(unit, aim_angle)
				elif battle.common_combat_enabled:
					battle.spawn_melee_strike(unit, profile, CombatRules.attack(unit)*(1.25 if counter else 1))
					unit.knockback_velocity += Vector2.from_angle(aim_angle)*90
				else:
					melee_live = true
					melee_age = 0.0
					melee_hit_ids.clear()
		State.ACTIVE:
			if phase_time >= profile.active:
				unit.combat_state = State.RECOVERY
				phase_time = 0.0
		State.RECOVERY:
			if phase_time >= profile.recovery:
				unit.combat_state = State.IDLE
				phase_time = 0.0
				if battle.full_characters_enabled: unit.ability.after_recovery(unit)
				# Web advanceAttack drops the entire attack after recovery. Release
				# counter/profile state too, or its movement lock survives forever.
				# A combo may have queued its next WINDUP in after_recovery.
				if unit.combat_state==State.IDLE: cancel(unit)
	# MIGRATION_NOTE: phase transition discards overshoot, matching advanceAttack.
	# A dead target does not cancel a windup in the web; the locked aim may miss.

func aim_direction(unit, enemy) -> float:
	var predicted: Vector2 = enemy.position
	var profile: AttackData = profile(unit)
	if profile.kind == AttackData.Kind.PROJECTILE:
		var flight: float = unit.position.distance_to(predicted) / profile.projectile_speed
		predicted += enemy.velocity * flight * profile.aim_lead
	return (predicted - unit.position).angle()

func blade_segment(unit, age: float) -> Array[Vector2]:
	var profile: AttackData = unit.data.attack_profile
	var angle: float = aim_angle - profile.cone + 2.0 * profile.cone * clampf(age / profile.active, 0.0, 1.0)
	var direction := Vector2.from_angle(angle)
	return [unit.position + direction * 25.0, unit.position + direction * profile.reach]

func collect_melee_hits(unit, candidates: Array, delta: float) -> Array[Dictionary]:
	var contacts: Array[Dictionary] = []
	if not melee_live or not unit.alive:
		return contacts
	var duration: float = unit.data.attack_profile.active
	for enemy in candidates:
		if not unit.target_selector.is_valid_enemy(unit, enemy) or melee_hit_ids.has(enemy.battle_id):
			continue
		# Web sampledContact checks 0, 1/4, 1/2, 3/4 and 1 of a <=1/120 slice.
		for sample in range(5):
			var offset: float = delta * sample / 4.0
			if melee_age + offset > duration:
				break
			var blade: Array[Vector2] = blade_segment(unit, melee_age + offset)
			if enemy.position.distance_to(Geometry2D.get_closest_point_to_segment(enemy.position, blade[0], blade[1])) <= 27.0:
				melee_hit_ids[enemy.battle_id] = true
				contacts.append({"time": offset, "source": unit, "target": enemy, "damage": unit.attack_power, "projectile": false})
				break
	melee_age += delta
	if melee_age >= duration:
		melee_live = false
	return contacts

func cancel(unit) -> void:
	counter = false
	active_profile=null
	healing_target=null
	attack_metadata.clear()
	unit.combat_state = State.IDLE
	attack_target = null
	phase_time = 0.0
	melee_live = false

func start_heal(unit,patient) -> void:
	counter=false;healing_target=patient;active_profile=unit.ability.profile(unit)
	attack_target=patient;aim_angle=(patient.position-unit.position).angle();phase_time=0;attack_serial+=1
	unit.combat_state=State.WINDUP

func force_start(unit,enemy) -> void:
	counter=false;attack_metadata.clear();active_profile=unit.ability.profile(unit);attack_target=enemy;aim_angle=(enemy.position-unit.position).angle();phase_time=0;attack_serial+=1;unit.combat_state=State.WINDUP;unit.ability.on_attack_start(unit);cooldown=unit.ability.attack_cooldown(unit,unit.battle.rng);unit.set_state("revealTime",3)
