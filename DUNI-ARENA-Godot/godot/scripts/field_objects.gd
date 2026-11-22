class_name FieldObjects
extends RefCounted
## The battlefield's objects (FieldObject): where a room's 구조물 시련 put them (a layout saved with
## the room, in board space), and how they act in battle — units are kept out of solid ones,
## projectiles stop on those they cannot pass, a hit lights a 화약통, auras heal, and the AI reads
## them (danger near a keg, the statue as a place to recover).
const C = preload("res://scripts/trial_catalog.gd")
## The strip between the two deployment zones (board space) that objects stand in: right of the
## player's zone (DeploymentRules.MAX_POSITION.x) and left of the enemies' (TowerMapGenerator).
const STRIP_MIN_X: float = 381.0
const STRIP_MAX_X: float = 414.0
const STRIP_MIN_Y: float = 70.0
const STRIP_MAX_Y: float = 730.0
## A layout keeps objects this far from the room's enemies (board units); the enemies stand right
## of x 415 + their radius, so the strip's left side always is.
const ENEMY_GAP: float = 60.0
## Combat events of attacks that hit an area: a 화약통 inside one is hit.
const AREA_EVENTS: Array[StringName] = [&"ult_impact", &"slime_slam", &"slime_land", &"golem_slam", &"golem_blast", &"flame_whirl", &"drug_bomb_burst", &"snowball_burst", &"griffin_storm"]

## The objects `trials` put on a field, as saved layout rows {kind, x, y} (board space), keeping
## clear of `avoid` (the enemies' board positions).
static func layout(rng: RandomNumberGenerator, trials: Array, avoid: Array = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if &"warm_statue" in trials:out.append({"kind": String(FieldObject.STATUE), "x": ArenaMap.BOARD * .5, "y": ArenaMap.BOARD * .5})
	if &"powder_kegs" in trials:
		# One keg per band down the strip (bands wider than KEG_SPACING, a little jitter inside
		# each); one that would stand by an enemy moves to the strip's far side.
		var band: float = (STRIP_MAX_Y - STRIP_MIN_Y) / FieldObject.KEG_COUNT
		var jitter: float = maxf(0, (band - FieldObject.KEG_SPACING) * .5)
		for i in range(FieldObject.KEG_COUNT):
			var at := Vector2(rng.randf_range(STRIP_MIN_X, STRIP_MAX_X), STRIP_MIN_Y + band * (i + .5) + rng.randf_range(-jitter, jitter))
			if avoid.any(func(p):return Vector2(p).distance_to(at) < ENEMY_GAP):at.x = STRIP_MIN_X
			out.append({"kind": String(FieldObject.KEG), "x": at.x, "y": at.y})
	return out
## A saved layout row is well formed.
static func valid_row(row) -> bool:
	return row is Dictionary and row.size() == 3 and FieldObject.KINDS.has(StringName(str(row.get("kind", "")))) and (row.get("x") is float or row.get("x") is int) and (row.get("y") is float or row.get("y") is int) and is_finite(float(row.x)) and is_finite(float(row.y))
## Board-space positions a layout takes up (deployment blockers).
static func points(rows: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for row in rows:out.append(Vector2(float(row.x), float(row.y)))
	return out

## Battle start: the layout's objects in map space; units standing in a solid one step out.
static func start(battle, rows: Array) -> void:
	battle.field_objects.clear()
	for row in rows:
		var o: FieldObject = FieldObject.make(StringName(str(row.kind)), ArenaMap.from_board(Vector2(float(row.x), float(row.y))))
		o.object_id = battle.field_objects.size() + 1;battle.field_objects.append(o)
	constrain(battle)

## Keeps living units out of solid objects (sliding round them, not stuck on their face).
static func constrain(battle) -> void:
	for o in battle.field_objects:
		if not o.alive or o.units_pass:continue
		for u in battle.units:
			if not u.alive:continue
			var reach: float = o.radius + 22 * u.combat_scale()
			var away: Vector2 = u.position - o.position;var d: float = away.length()
			if d >= reach:continue
			var dir: Vector2 = away / d if d > .01 else Vector2.from_angle(u.battle_id * 2.4)
			# A nudge round the object so a unit walking straight at it slides past.
			dir = (dir + dir.orthogonal() * (.25 if u.battle_id % 2 == 0 else -.25)).normalized()
			u.position = MovementController.clamp_position(o.position + dir * reach)

## A projectile that reached an object it cannot pass stops there (and hits it).
static func blocks(p) -> bool:
	var battle = p.source.battle
	if p.kind in ["frogBody", "openingAwl"]:return false
	for o in battle.field_objects:
		if not o.alive or o.projectiles_pass:continue
		if Geometry2D.get_closest_point_to_segment(o.position, p.previous_position, p.position).distance_to(o.position) > o.radius + p.hit_radius * .5:continue
		hit(battle, o)
		if p.metadata.has("blast_radius") and battle.full_characters_enabled:ProjectileRules.explode(p)
		p.live = false
		if p.attack_instance != null:p.attack_instance.life = 0
		battle.emit_combat_event(&"object_block", p.position, {"object_id": o.object_id, "angle": p.velocity.angle()})
		return true
	return false
## Something hit `o`: a keg's fuse is lit.
static func hit(battle, o: FieldObject, fuse: float = FieldObject.KEG_FUSE) -> void:
	if not o.alive or not o.destructible or o.on_hit != &"fuse" or o.fuse >= 0:return
	o.fuse = fuse
	battle.emit_combat_event(&"keg_lit", o.position, {"object_id": o.object_id, "fuse": fuse})
## An area attack at `point` hits the objects it reaches.
static func area(battle, point: Vector2, radius: float, fuse: float = FieldObject.KEG_FUSE) -> void:
	for o in battle.field_objects:
		if o.alive and o.destructible and o.position.distance_to(point) <= radius + o.radius:hit(battle, o, fuse)
## An area combat event (AREA_EVENTS) hits the objects inside it.
static func on_event(battle, kind: StringName, point: Vector2, metadata: Dictionary) -> void:
	if kind in AREA_EVENTS and metadata.has("radius"):area(battle, point, float(metadata.radius))

static func advance(battle, dt: float) -> void:
	for o in battle.field_objects:
		if not o.alive:continue
		if not o.aura.is_empty():
			o.aura_clock += dt
			while o.aura_clock >= float(o.aura.every):
				o.aura_clock -= float(o.aura.every)
				for u in battle.units:
					if not u.alive or u.position.distance_to(o.position) > float(o.aura.radius) + 20 * u.combat_scale():continue
					u.set_state("trialWarmth", float(o.aura.every) * 1.2)
					var gain: float = StrategyEffects.heal(u, u.max_hp * float(o.aura.heal)) if u.current_hp < u.max_hp else 0.0
					if gain > 0:battle.emit_combat_event(&"statue_heal", u.position, {"actor_id": u.battle_id, "amount": gain})
		if o.fuse >= 0:
			o.fuse -= dt
			if o.fuse <= 0:_blast(battle, o)
	for u in battle.units:
		if u.alive and u.state_value("trialWarmth") > 0:u.set_state("trialWarmth", maxf(0, u.state_value("trialWarmth") - dt))
## A keg goes off: everyone near takes the blow, burns and is thrown back; kegs near light up.
static func _blast(battle, o: FieldObject) -> void:
	o.alive = false;o.fuse = -1
	var damage: float = FieldObject.KEG_BASE + FieldObject.KEG_PER_FLOOR * battle.trial_floor
	for u in battle.units.duplicate():
		if not u.alive or u.position.distance_to(o.position) > FieldObject.KEG_BLAST + 20 * u.combat_scale():continue
		TrialEffects.hit(battle, u, damage, &"trial", &"powder_kegs")
		if not u.alive:continue
		var fire = _foe_of(battle, u)
		if fire != null:ElementEffects.add_burn(fire, u, FieldObject.KEG_BURN)
		var away: Vector2 = u.position - o.position
		u.knockback_velocity = (away.normalized() if away.length() > .01 else Vector2.RIGHT) * FieldObject.KEG_PUSH
	battle.emit_combat_event(&"keg_blast", o.position, {"object_id": o.object_id, "radius": FieldObject.KEG_BLAST})
	area(battle, o.position, FieldObject.KEG_BLAST, FieldObject.KEG_CHAIN_FUSE)
## The burn needs a unit to come from: the nearest living unit of the other side.
static func _foe_of(battle, u):
	var best = null
	for v in battle.units:
		if v.alive and v.team != u.team and (best == null or v.position.distance_squared_to(u.position) < best.position.distance_squared_to(u.position)):best = v
	return best

## Danger for the AI: near a keg a little, a lit keg's blast a lot.
static func hazards(battle, body: float, out: Array) -> void:
	for o in battle.field_objects:
		if not o.alive or o.kind != FieldObject.KEG:continue
		if o.fuse >= 0:out.append([BattleZones.RISK_CIRCLE, o.position, FieldObject.KEG_BLAST + body, 3.0])
		else:out.append([BattleZones.RISK_CIRCLE, o.position, FieldObject.KEG_BLAST * .6 + body, .8])
## Places to recover for the AI (the statue's warmth), like a friendly healing zone.
static func refuges(battle, out: Array[Dictionary]) -> void:
	for o in battle.field_objects:
		if o.alive and not o.aura.is_empty() and float(o.aura.get("heal", 0)) > 0:
			out.append({"ref": "object:%d" % o.object_id, "point": CharacterPersistence.point(o.position), "radius": float(o.aura.radius), "life": 99.0, "kind": "healing"})
