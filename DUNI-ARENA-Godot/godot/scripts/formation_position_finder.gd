class_name FormationPositionFinder
extends RefCounted
## Web towerFormationPosition: clamp, then nearest free 20-step candidate.
## The search lattice is for fallback only; normal placement is continuous.
const SEARCH_STEP: int = 20
const MAX_CANDIDATES: int = 18 * 37

static func find(preferred: Vector2, entries: Array[DeploymentEntry], blockers: Array[Vector2]) -> Dictionary:
	if not preferred.is_finite():
		return {"found": false}
	var point := Vector2(clampf(preferred.x, 40, 380), clampf(preferred.y, 40, 760))
	if DeploymentRules.position_error(point, entries, blockers) == DeploymentRules.Code.OK:
		return {"found": true, "position": point}
	var best := Vector2.ZERO
	var best_distance: float = INF
	# 666 finite candidates; ties preserve x-then-y web iteration order.
	for x in range(40, 381, SEARCH_STEP):
		for y in range(40, 761, SEARCH_STEP):
			var candidate := Vector2(x, y)
			if DeploymentRules.position_error(candidate, entries, blockers) != DeploymentRules.Code.OK:
				continue
			var distance: float = candidate.distance_squared_to(point)
			if distance < best_distance:
				best_distance = distance
				best = candidate
	return {"found": true, "position": best} if is_finite(best_distance) else {"found": false}
