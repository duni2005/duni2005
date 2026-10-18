class_name ClashResolver
extends RefCounted
## Pure numeric clash decision. Side effects belong to PhysicalAttackSystem.
const DRAW_RATIO: float = 1.3
static func win_chance(high: float, low: float) -> float:
	return clampf(.6 + (high / maxf(.01, low) - DRAW_RATIO) * .16, .6, .95)
static func compare(a: AttackInstance, b: AttackInstance, roll: float) -> Dictionary:
	var high: float = maxf(a.power, b.power)
	var low: float = minf(a.power, b.power)
	var similar: bool = high <= maxf(.01, low) * DRAW_RATIO
	var breakthrough: bool = not similar and roll < win_chance(high, low)
	return {"breakthrough": breakthrough, "winner_id": (a.attack_id if a.power >= b.power else b.attack_id) if breakthrough else 0, "high": high, "wave_radius": clampf(130 + high*.55, 140, 270), "wave_stun": clampf(.12+sqrt(maxf(0, high))*.035, .15, .55), "wave_force": clampf(180+high*2.2, 210, 450)}
static func weaken(attack: AttackInstance) -> void:
	attack.damage *= .45
	attack.power *= .7
	attack.clash_count += 1
