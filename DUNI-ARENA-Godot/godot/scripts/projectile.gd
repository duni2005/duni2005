class_name BattleProjectile
extends Node2D
## Explicit swept collision. CollisionShape2D/Area2D alone would tunnel at speed.
## Piercing, bounces and character contacts use shared ordered swept processing.

var kind: String = ""
var metadata: Dictionary = {}
var piercing: bool = false
var bounces: int = 0
var bounce_count: int = 0
var projectile_id: int = 0
var power: float = 0
var hidden_launch: bool = false
var attack_instance: AttackInstance
var previous_position: Vector2 = Vector2.ZERO
var source: BattleUnit
var velocity: Vector2
var damage: float
var hit_radius: float
var lifetime: float
var live: bool = true

func initialize(owner: BattleUnit, heading: float) -> void:
	source = owner
	var profile: AttackData = owner.data.attack_profile
	var direction := Vector2.from_angle(heading)
	position = owner.position + direction * profile.projectile_offset
	previous_position = position
	velocity = direction * profile.projectile_speed
	damage = CombatRules.attack(owner) if owner.battle.common_combat_enabled else owner.attack_power
	power = damage
	hidden_launch = owner.combat.hidden_launch
	hit_radius = profile.projectile_radius
	lifetime = profile.projectile_lifetime

func contact_time(point: Vector2, delta: float) -> float:
	# dist(projectile, target) <= 26 for web scale=1, not 26 + unit body radius.
	var relative: Vector2 = position - point
	var c: float = relative.length_squared() - hit_radius * hit_radius
	if c <= 0.0:
		return 0.0
	var a: float = velocity.length_squared()
	if a < 0.00000001:
		return -1.0
	var b: float = 2.0 * relative.dot(velocity)
	var discriminant: float = b * b - 4.0 * a * c
	if discriminant < 0.0:
		return -1.0
	var time: float = (-b - sqrt(discriminant)) / (2.0 * a)
	return time if time >= 0.0 and time <= delta else -1.0

func boundary_time() -> float:
	var time: float = INF
	if position.x <= 20.0 or position.x >= 780.0 or position.y <= 20.0 or position.y >= 780.0:
		return 0.0
	if velocity.x > 0.0:
		time = minf(time, (780.0 - position.x) / velocity.x)
	elif velocity.x < 0.0:
		time = minf(time, (20.0 - position.x) / velocity.x)
	if velocity.y > 0.0:
		time = minf(time, (780.0 - position.y) / velocity.y)
	elif velocity.y < 0.0:
		time = minf(time, (20.0 - position.y) / velocity.y)
	return time

func collect_hits(candidates: Array, delta: float) -> Array[Dictionary]:
	var contacts: Array[Dictionary] = []
	if not live:
		return contacts
	var available: float = minf(delta, minf(lifetime, boundary_time()))
	for enemy in candidates:
		if not source.target_selector.is_valid_enemy(source, enemy):
			continue
		var time: float = contact_time(enemy.position, available)
		if time >= 0.0:
			contacts.append({"time": time, "source": source, "target": enemy, "damage": damage, "projectile": true, "object": self})
	return contacts

func advance(delta: float) -> void:
	if not live:
		return
	if source.battle.full_characters_enabled:
		ProjectileRules.prepare(self,delta)
		if not live:return
	var available: float = minf(delta, minf(lifetime, boundary_time()))
	previous_position = position
	position += velocity * (minf(available,float(metadata.get("flight",available))) if source.battle.full_characters_enabled and kind=="bomb" else available)
	lifetime -= delta
	if source.battle.full_characters_enabled:
		if kind=="bomb":
			metadata.flight=maxf(0,float(metadata.flight)-delta)
			if float(metadata.flight)<=0:velocity=Vector2.ZERO
			metadata.fuse=float(metadata.fuse)-delta
			if float(metadata.fuse)<=1e-8:ProjectileRules.explode(self)
		ProjectileRules.boundary(self)
		if kind=="frogBody":
			var cargo=source.battle.find_actor(metadata.get("cargo",""))
			if cargo!=null:cargo.position=MovementController.clamp_position(position)
		if lifetime<=0:live=false;ProjectileRules.finish(self)
	elif available < delta or lifetime <= 0.0:
		live = false
	queue_redraw()

func _draw() -> void:
	if live:
		var direction: Vector2 = velocity.normalized()
		draw_line(-direction * 15.0, direction * 5.0, source.team_color().lightened(0.3), 4.0, true)
