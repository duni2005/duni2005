class_name WeaponDrop
extends RefCounted
## 놓침: the weapon is knocked out of the unit's hand and lands at a random spot. Until the unit
## picks it up again it can use neither its basic attack nor its ultimate, and getting the weapon
## back comes before everything else it does. Only units that hold a weapon can lose one.
## The loose weapon lives in BattleUnit.lost_sword (also used by 두비두밤's own slip).
## Units holding a weapon: swords, bows, staves, guns, the stake mallet, the flask...
const HOLDERS: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 10, 14, 16, 19, 20, 23, 26, 31, 32, 34, 40, 44, 45]
const SPEED: float = 480
const FLIGHT: float = .6
const PICKUP_RANGE: float = 34
const PICKUP_TIME: float = .25

static func holds_weapon(u) -> bool:return u != null and u.data.type_id in HOLDERS
static func lost(u) -> bool:return not u.lost_sword.is_empty()

## Knocks the weapon away. False when the unit holds no weapon or has already lost it.
static func drop(u, source = null) -> bool:
	if u == null or not u.alive or not holds_weapon(u) or lost(u) or u.unavailable():return false
	var angle: float = u.battle.rng.randf_range(-PI, PI);var dir: Vector2 = Vector2.from_angle(angle) * SPEED
	u.combat.cancel(u);u.ultimate.cast.clear()
	u.lost_sword = {"point": CharacterPersistence.point(u.position), "vx": dir.x, "vy": dir.y, "flight": FLIGHT, "rotation": angle, "sizeBoost": 1.0, "scale": u.combat_scale(), "debuff": true}
	u.set_state("pickupTime", 0)
	u.battle.emit_combat_event(&"weapon_dropped", u.position, {"actor_id": u.battle_id, "source": source.battle_id if source != null else -1})
	return true

## The loose weapon flies, lands, and is picked up after standing on it for PICKUP_TIME.
static func advance(u, dt: float) -> void:
	if not lost(u):return
	var s: Dictionary = u.lost_sword
	if float(s.flight) > 0:
		s.point = CharacterPersistence.point((CharacterPersistence.vector(s.point) + Vector2(s.vx, s.vy) * minf(dt, float(s.flight))).clamp(Vector2(35, 35), ArenaMap.hi(35)));s.flight = maxf(0, float(s.flight) - dt);s.rotation += dt * 13
	if float(s.flight) <= 0 and u.stun_remaining <= 0 and u.state_value("guardRemaining") <= 0 and u.position.distance_to(CharacterPersistence.vector(s.point)) < PICKUP_RANGE * maxf(1, u.combat_scale()):
		u.set_state("pickupTime", u.state_value("pickupTime") + dt)
		if u.state_value("pickupTime") >= PICKUP_TIME:
			u.lost_sword.clear();u.set_state("pickupTime", 0);u.combat.cooldown = minf(u.combat.cooldown, .3)
			u.battle.emit_combat_event(&"weapon_recovered", u.position, {"actor_id": u.battle_id})
	else:u.set_state("pickupTime", 0)

## Heads for the weapon (side-stepping shots on the way). Comes before all other movement.
static func move(u, dt: float) -> bool:
	if not lost(u):return false
	var point: Vector2 = CharacterPersistence.vector(u.lost_sword.point);var direction: Vector2 = (point - u.position).normalized()
	var incoming: Dictionary = u.threat_response.projectile_threat(u)
	if not incoming.is_empty() and u.position.distance_to(point) > 85:direction -= incoming.arrow.velocity.normalized().orthogonal() * u.brain.side * .4
	u.brain.movement_override = "weapon_pickup";u.brain.steer(u, direction, dt);return true
