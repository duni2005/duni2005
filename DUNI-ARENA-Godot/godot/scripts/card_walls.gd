class_name CardWalls
extends RefCounted
## 방벽 설치: short walls placed by a strategy card. Each stops the enemy projectiles that cross
## it (from the other side's team) until it expires. Walls are battle-local (BattleManager.card_walls).

static func make(center: Vector2, along: Vector2, length: float, life: float, team: int) -> Dictionary:
	var d: Vector2 = along.normalized() * length * .5
	return {"a": center - d, "b": center + d, "center": center, "life": life, "max_life": life, "team": team, "length": length, "hits": 0}

static func advance(battle, dt: float) -> void:
	for w in battle.card_walls.duplicate():
		w.life = float(w.life) - dt
		if float(w.life) <= 0: battle.card_walls.erase(w)

## A projectile that moved from `from` to `to` through a wall of the other team stops on it.
static func blocks(p) -> bool:
	var battle = p.source.battle
	if battle.card_walls.is_empty() or p.source.team == 0 or p.kind in ["frogBody", "openingAwl"]: return false
	for w in battle.card_walls:
		if int(w.team) == p.source.team: continue
		if _crosses(p.previous_position, p.position, Vector2(w.a), Vector2(w.b), StrategyCardTuning.WALL_THICKNESS * .5 + p.hit_radius * .5):
			w.hits = int(w.hits) + 1
			p.live = false
			if p.attack_instance != null: p.attack_instance.life = 0
			battle.emit_combat_event(&"wall_block", p.position, {"angle": p.velocity.angle()})
			return true
	return false

## The segment p0→p1 passes within `pad` of the wall segment a→b.
static func _crosses(p0: Vector2, p1: Vector2, a: Vector2, b: Vector2, pad: float) -> bool:
	if Geometry2D.segment_intersects_segment(p0, p1, a, b) != null: return true
	var near: Vector2 = Geometry2D.get_closest_point_to_segment(p1, a, b)
	return near.distance_to(p1) <= pad
