class_name BattleUnit
extends Node2D
## Runtime instance; repeated types share UnitData but none of their mutable state.

signal died(unit, source)

var battle_id: int
var source_member_id: String = "" # Empty for Phase 1/test enemies; never a type ID.
var source_enemy_id: String = "" # Separate room actor identity; never a member ID.
var source_room_id: String = ""
var source_run_id: String = ""
var ultimate_gauge: float = 0.0
var transcendence_gauge: float = 0.0
var stance: StringName = CombatStance.NORMAL
var character_specific_state: Dictionary = {}
# Battle-only strategy commands. Never store TP/plan objects in persistent state.
var command_retreat_until: float = 0.0
var retreat_point: Vector2 = Vector2.ZERO
var strategy_dash: Dictionary = {}
var strategy_cast: Dictionary = {} # an enemy special strategy (smash/cleave) being carried out
var strategy_heading: Vector2 = Vector2.ZERO
var strategy_special_until: float = 0.0
var shield_hp: float = 0.0
var shield_remaining: float = 0.0
var iron_defense_remaining: float = 0.0
var parry_cooldown: float = 0.0
var parry_remaining: float = 0.0
var defense_cooldown: float = 0.0
var taunted_member_id: String = ""
var taunted_until: float = 0.0
# Phase 7 runtime; only whitelist fields are exported by StrategyEffects.
var additional_defense: float = 0
var stun_remaining: float = 0
var stun_revision: int = 0
var invincible_remaining: float = 0
var facing: float = 0
var hidden_from_enemies: bool = false
var parry_counter_used: bool = false
var parry_pulse_used: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_source_id: int = 0
var knockback_chain: int = 0
var dodge_state: Dictionary = {}
var evade_remaining: float = 0
var parry := ParryController.new()
var threat_response := ThreatResponseController.new()
var area_evaluator := AreaEvaluator.new()
var ability: CharacterAbility
var brain := BattleBrain.new()
var mind := TacticalMind.new()
var ultimate := UltimateController.new()
var original_team: int = 0
var deployment_position: Vector2 = Vector2.ZERO
var healing_power: float = 1
var healing_received: float = 1
var vigor_totem_count: int = 0
var charge_totem_count: int = 0
var last_damage_time: float = -10
var last_damage_actor: String = ""
var damage_dealt: float = 0
var cover_actor_id: String = ""
var lost_sword: Dictionary = {}
var guard_anchor: Vector2
var duel: Dictionary = {}
var frog_action: Dictionary = {}
var frog_carrier: String = ""
var frog_flight: int = 0
var frog_rescue_guard: bool = false
var frog_hop_wait: float = .8
var persistent_extra_fields: Dictionary = {}
var frog_hop: Dictionary = {}
var hero_rescue_used: bool = false
var hero_rescue: Dictionary = {}
var hero_rescue_owner: String = ""
var machine_dash: Dictionary = {}
var puppet_control: Dictionary = {}
var restored_control: Dictionary = {}
var puppet_links: Array[String] = []
var saint_actor: String = ""
var cosmic_marked: bool = false
var knockback_collision_stun: float = 0
var battle
var team: int
var data: UnitData
var combat_stats: UnitCombatStats
var max_hp: float:
	get: return combat_stats.max_hp if combat_stats != null else data.max_hp
## Representative attack strength for AI, knockback and parry checks. Full-character battles use
## the main damage stat x attack %; the golden harnesses keep the original attack number.
var attack_power: float:
	get:
		if not _new_stats():return data.attack
		return UnitStatTable.damage_stat(self, UnitStatTable.main_kind(data.type_id)) * (combat_stats.attack if combat_stats != null else 1.0)
var defense_power: float:
	get: return combat_stats.defense if combat_stats != null else UnitStatTable.base_defense(data.type_id) if _new_stats() else data.defense_power
func _new_stats() -> bool:return combat_stats != null or battle != null and battle.full_characters_enabled
var base_body_scale: float:
	get: return data.body_scale * (combat_stats.scale if combat_stats != null else 1)
var current_hp: float
var velocity: Vector2 = Vector2.ZERO
var move_speed: float
var target = null
var alive: bool = true
var combat_state: CombatController.State = CombatController.State.IDLE
var death_emitted: bool = false
var target_selector := TargetSelector.new()
var movement := MovementController.new()
var combat := CombatController.new()

func initialize(id: int, faction: int, definition: UnitData, at: Vector2, rng: RandomNumberGenerator, battle_owner) -> void:
	battle_id = id
	battle = battle_owner
	team = faction
	original_team = faction
	data = definition
	current_hp = data.max_hp
	position = MovementController.clamp_position(at)
	deployment_position=position
	move_speed = data.move_speed * rng.randf_range(0.93, 1.07)
	combat.cooldown = rng.randf_range(0.2, 1.0)
	if battle.common_combat_enabled:
		facing = 0 if team == 0 else PI
		threat_response.initialize(rng)
		area_evaluator.initialize(rng)
	if battle.full_characters_enabled:
		ability=AbilityRegistry.create(data.type_id)
		facing=rng.randf_range(-PI,PI)
		movement_phase=rng.randf_range(0,TAU)
		brain.initialize(rng)
		threat_response.reaction=brain.reaction;threat_response.side=brain.side
		area_evaluator.boldness=brain.boldness;area_evaluator.patience=brain.patience;area_evaluator.phase=brain.phase
		ultimate.think=rng.randf_range(.3,1)

func receive_damage(amount: float, source, defer_death: bool = false) -> float:
	# Final HP-loss stage only. Attacks MUST use DamageResolver for shield/crit.
	if not battle.started or battle.finished or battle.clock.is_turning_paused() or not alive or not is_finite(amount) or amount <= 0.0:
		return 0.0
	var previous: float = current_hp
	current_hp = clampf(current_hp - amount, 0.0, max_hp)
	if current_hp <= 0.0:
		alive = false
		shield_hp = 0
		shield_remaining = 0
		iron_defense_remaining = 0
		parry_remaining = 0
		velocity = Vector2.ZERO
		target = null
		combat.cancel(self)
		if not defer_death: announce_death(source)
	queue_redraw()
	return previous - current_hp

func announce_death(source) -> void:
	# Common resolver announces after impact stage, matching web eliminateUnit.
	# Legacy receive_damage still announces immediately through its default API.
	if not alive and not death_emitted:
		if battle.full_characters_enabled: battle.character_death(self,source)
		death_emitted=true
		died.emit(self,source)

func team_color() -> Color:
	if battle != null and battle.get("custom_mode") == true:return CustomBattleSetup.faction_color(team, data.type_id)
	return Color("88b7ff") if team == 0 else Color("ff947d")

func debug_state() -> String:
	return CombatController.State.keys()[combat_state] if alive else "DEAD"

func _draw() -> void:
	if not data or not alive:
		return
	if battle.full_characters_enabled:draw_set_transform(Vector2.ZERO,0,Vector2.ONE*combat_scale())
	var color: Color = team_color()
	draw_circle(Vector2.ZERO, 25.0, Color("151e2d"))
	draw_arc(Vector2.ZERO, 25.0, 0.0, TAU, 40, color, 3.0, true)
	var font: Font = ThemeDB.fallback_font
	var glyph: String = data.emoji if battle.full_characters_enabled else "W" if data.type_id == 0 else "A"
	draw_string(font, Vector2(-9, 8), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 23, color)
	draw_rect(Rect2(-28, -42, 56, 6), Color("293142"))
	draw_rect(Rect2(-28, -42, 56 * current_hp / max_hp, 6), color)
	var hp_text: String = "%d/%d" % [ceili(current_hp), int(max_hp)]
	draw_string(font, Vector2(-28, -48), hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	draw_string(font, Vector2(-32, 44), debug_state(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("bfc9da"))
	if battle.common_combat_enabled:
		draw_line(Vector2.ZERO,Vector2.from_angle(facing)*30,Color(1,1,1,.35),1)
		if parry_remaining > .8: draw_arc(Vector2.ZERO,29, facing-1.2,facing+1.2,12,Color("b7f9ff"),4)
		if stun_remaining > 0: draw_string(font,Vector2(-18,-65),"STUN",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("ffe380"))
		draw_string(font, Vector2(-30, 58), "S%.0f ST%.1f" % [shield_hp,stun_remaining], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("a9d4c9"))
		draw_string(font, Vector2(-38, 71), "P%.1f/%.1f I%.1f" % [parry_cooldown,parry_remaining,iron_defense_remaining], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("a9d4c9"))
		if invincible_remaining > 0: draw_string(font, Vector2(-20, -60), "INV", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.YELLOW)
		if knockback_velocity.length() > 10: draw_line(Vector2.ZERO, knockback_velocity.limit_length(65), Color("ffac94"), 2)
	if battle.full_characters_enabled:
		draw_string(font,Vector2(-35,85),"%s/%d U%.0f T%.0f" % [data.display_name,data.type_id,ultimate_gauge,transcendence_gauge],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("cd9aff"))
	if battle.full_characters_enabled:
		draw_string(font,Vector2(-35,98),ability.debug_state(self),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("b5c5db"))
	# Minimal debugging of attack facing/progress, not completed VFX/animation.
	if combat_state == CombatController.State.WINDUP:
		var direction := Vector2.from_angle(combat.aim_angle)
		draw_line(direction * 28, direction * 48, Color("ffda80"), 3.0)
	elif not battle.common_combat_enabled and combat_state == CombatController.State.ACTIVE and data.attack_profile.kind == AttackData.Kind.MELEE:
		var blade: Array[Vector2] = combat.blade_segment(self, combat.melee_age)
		draw_line(blade[0] - position, blade[1] - position, Color("fff4c0"), 5.0, true)

func actor_id() -> String:
	return "member:"+source_member_id if not source_member_id.is_empty() else "enemy:"+source_room_id+":"+source_enemy_id if not source_enemy_id.is_empty() else "battle:%d" % battle_id
func state_value(key: String, fallback: float=0) -> float:
	var v=character_specific_state.get(key,fallback)
	return float(v) if v is int or v is float else fallback
func set_state(key: String,value: Variant) -> void:character_specific_state[key]=value
func friends() -> Array:
	return battle.units.filter(func(u):return u!=self and u.alive and u.team==team and not u.unavailable())
func enemies(perceived: bool=true) -> Array:
	return battle.units.filter(func(u):return u.alive and u.team!=team and (not perceived or CombatPerception.can_perceive(self,u)))
func unavailable() -> bool:return not frog_carrier.is_empty() or frog_flight!=0
func is_dashing() -> bool:return not hero_rescue.is_empty() or ultimate.cast.get("dashing",false)
func combat_scale() -> float:
	var permanent: float=maxf(.4,pow(.94,state_value("dolphinStacks"))) if data.type_id==11 else minf(2.4,1+state_value("predatorStacks")*.04) if data.type_id==12 else 1
	return permanent*base_body_scale*(.65 if state_value("curseTime")>0 else 1)

var movement_phase: float = 0
var equipment_fang_kills: int = 0
var fang_count: int = 0
var opening_awl_count: int = 0
var victory_gold: int = 0
var phoenix_used: bool = false # 불사조의 깃털, once per battle (never saved)
