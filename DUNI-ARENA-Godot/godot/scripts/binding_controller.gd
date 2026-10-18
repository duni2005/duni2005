class_name BindingController
extends RefCounted
## Position constraints applied after movement each tick:
## - stake tether: a unit may only move within a small circle around the stake;
## - magnet link: two units are pulled together, damaging enemies on the way, then move as one.
const TETHER_RADIUS: float = 72
const MAGNET_PULL_SPEED: float = 900
const MAGNET_GAP: float = 46
const MAGNET_SHARE: float = .1

static func tether(unit, center: Vector2, duration: float, radius: float = TETHER_RADIUS) -> void:
	unit.set_state("tetherTime", duration);unit.set_state("tetherRadius", radius)
	unit.character_specific_state["tetherPoint"] = CharacterPersistence.point(center)

static func link(source, a, b, duration: float) -> void:
	for pair in [[a, b, "N"], [b, a, "S"]]:
		var u = pair[0]
		u.character_specific_state["magnetPartner"] = pair[1].actor_id()
		u.character_specific_state["magnetPole"] = pair[2]
		u.character_specific_state["magnetSource"] = source.actor_id()
		u.character_specific_state["magnetHits"] = {}
		u.set_state("magnetTime", duration);u.set_state("magnetPull", 1)

static func advance(battle, dt: float) -> void:
	for u in battle.units:
		if not u.alive:continue
		_advance_fx(u, dt)
		if u.state_value("tetherTime") > 0:_advance_tether(u, dt)
		if u.state_value("magnetTime") > 0:_advance_magnet(battle, u, dt)

static func _advance_fx(u, dt: float) -> void:
	if u.state_value("deliveryFx") > 0:u.set_state("deliveryFx", maxf(0, u.state_value("deliveryFx") - dt))
	for key in ["refractFx", "magnetShockFx", "magnetCastFx"]:
		if u.state_value(key) > 0:u.set_state(key, maxf(0, u.state_value(key) - dt))

static func _advance_tether(u, dt: float) -> void:
	u.set_state("tetherTime", maxf(0, u.state_value("tetherTime") - dt))
	var center: Vector2 = CharacterPersistence.vector(u.character_specific_state.get("tetherPoint", CharacterPersistence.point(u.position)))
	var radius: float = u.state_value("tetherRadius", TETHER_RADIUS)
	var offset: Vector2 = u.position - center
	if offset.length() > radius:
		u.position = center + offset.normalized() * radius
		# Drop the outward part of the motion so the unit slides along the edge.
		var out: Vector2 = offset.normalized()
		if u.velocity.dot(out) > 0:u.velocity -= out * u.velocity.dot(out)
		if u.knockback_velocity.dot(out) > 0:u.knockback_velocity -= out * u.knockback_velocity.dot(out)

static func _advance_magnet(battle, u, dt: float) -> void:
	var partner = battle.find_actor(u.character_specific_state.get("magnetPartner", ""))
	if partner == null or not partner.alive:
		_unlink(u);return
	# The "N" unit owns the pair so the pair is processed once per tick.
	if u.character_specific_state.get("magnetPole", "") != "N":return
	var remaining: float = maxf(0, u.state_value("magnetTime") - dt)
	u.set_state("magnetTime", remaining);partner.set_state("magnetTime", remaining)
	if remaining <= 0:_unlink(u);_unlink(partner);return
	var source = battle.find_actor(u.character_specific_state.get("magnetSource", ""))
	var axis: Vector2 = partner.position - u.position
	if u.state_value("magnetPull") > 0:
		var step: float = MAGNET_PULL_SPEED * dt
		if axis.length() <= MAGNET_GAP + step * 2:
			u.set_state("magnetPull", 0);partner.set_state("magnetPull", 0)
			if source != null:
				# The slam: both magnetised units take a heavy hit.
				for v in [u, partner]:battle.damage_resolver.resolve(source, v, 30, {"critical": false, "impulse": 0, "visible_hazard": true})
		else:
			for v in [[u, axis.normalized()], [partner, -axis.normalized()]]:
				var mover = v[0]
				mover.position = MovementController.clamp_position(mover.position + v[1] * step)
				mover.velocity = Vector2.ZERO;mover.knockback_velocity = Vector2.ZERO
				if source != null:_path_hits(battle, source, u, mover)
			return
	# Stuck together: keep the pair at a fixed gap around their midpoint.
	var mid: Vector2 = (u.position + partner.position) * .5
	var dir: Vector2 = axis.normalized() if axis.length() > .01 else Vector2.RIGHT
	u.position = MovementController.clamp_position(mid - dir * MAGNET_GAP * .5)
	partner.position = MovementController.clamp_position(mid + dir * MAGNET_GAP * .5)

static func _path_hits(battle, source, owner, mover) -> void:
	var hits: Dictionary = owner.character_specific_state.get("magnetHits", {})
	for enemy in source.enemies(false):
		if enemy == mover or enemy.unavailable() or hits.has(enemy.actor_id()):continue
		if enemy.character_specific_state.get("magnetPartner", "") != "" and enemy.state_value("magnetTime") > 0:continue
		if enemy.position.distance_to(mover.position) < 40 * enemy.combat_scale() + 20:
			hits[enemy.actor_id()] = true
			battle.damage_resolver.resolve(source, enemy, 20, {"critical": false, "impulse": 420, "angle": (enemy.position - mover.position).angle(), "visible_hazard": true})
	owner.character_specific_state["magnetHits"] = hits

static func _unlink(u) -> void:
	u.set_state("magnetTime", 0);u.set_state("magnetPull", 0)
	for key in ["magnetPartner", "magnetPole", "magnetSource", "magnetHits"]:u.character_specific_state.erase(key)
