class_name StanceMarks
extends RefCounted
## Small field marks around a unit's HP bar: the player stance as a fixed icon on the left, a
## ready counter (cautious) on the right, and a short popup when the situational mind tips
## into charging or caution. Read-only: it never calls into the simulation's decisions.
const RUSH_COLOR := Color("ff8a4c")
const CAUTIOUS_COLOR := Color("7fe0d0")
const COVER_COLOR := Color("8fb8ff")
const COUNTER_COLOR := Color("ffd76a")
const POPUP_LIFE: float = .9
## Situational thresholds as TacticalMind reads them (charging / cautious).
const CHARGE_AT: float = .45
const CAUTIOUS_AT: float = -.3
var moods: Dictionary = {}
var popups: Dictionary = {}

## Spots the moments a unit's situational mood flips into charging or caution.
func track(battle, age: float) -> void:
	if battle == null:return
	for u in battle.units:
		if not u.alive or not u.mind.active(u):continue
		var bias: float = u.mind.temper - TacticalMind.stance_lean(u)
		var mood: int = 1 if bias > CHARGE_AT else -1 if bias < CAUTIOUS_AT else 0
		if mood != int(moods.get(u.battle_id, 0)) and mood != 0:popups[u.battle_id] = {"start":age, "mood":mood}
		moods[u.battle_id] = mood

func draw(canvas: CanvasItem, u, bar: Rect2, px: float, age: float) -> void:
	var size: float = maxf(8, 9 * px);var mid: float = bar.position.y + bar.size.y * .5
	var left := Vector2(bar.position.x - size * .8, mid)
	match u.stance:
		CombatStance.RUSH:
			for i in range(2):
				var y: float = left.y + size * (.05 + i * .32)
				canvas.draw_polyline(PackedVector2Array([Vector2(left.x - size * .38, y + size * .2), Vector2(left.x, y - size * .2), Vector2(left.x + size * .38, y + size * .2)]), RUSH_COLOR, maxf(1.5, 1.6 * px), true)
		CombatStance.CAUTIOUS:
			var h: float = size * .5
			var shield := PackedVector2Array([left + Vector2(-h * .8, -h), left + Vector2(h * .8, -h), left + Vector2(h * .8, 0), left + Vector2(0, h), left + Vector2(-h * .8, 0)])
			canvas.draw_colored_polygon(shield, Color(CAUTIOUS_COLOR, .3))
			shield.append(shield[0]);canvas.draw_polyline(shield, CAUTIOUS_COLOR, maxf(1.2, 1.3 * px), true)
		CombatStance.COVER:
			canvas.draw_arc(left, size * .42, 0, TAU, 16, COVER_COLOR, maxf(1.2, 1.3 * px), true)
			canvas.draw_circle(left, size * .16, COVER_COLOR)
	if StanceRules.counter_ready(u):
		var right := Vector2(bar.end.x + size * .8, mid);var r: float = size * (.42 + .08 * sin(age * 9))
		canvas.draw_colored_polygon(PackedVector2Array([right + Vector2(0, -r), right + Vector2(r * .7, 0), right + Vector2(0, r), right + Vector2(-r * .7, 0)]), COUNTER_COLOR)
	var popup: Dictionary = popups.get(u.battle_id, {})
	if popup.is_empty():return
	var t: float = (age - float(popup.start)) / POPUP_LIFE
	if t >= 1:popups.erase(u.battle_id);return
	var charging: bool = int(popup.mood) > 0
	var font_size: int = roundi(maxf(10, 11 * px))
	var text: String = "돌격!" if charging else "신중"
	var at := Vector2(bar.position.x + bar.size.x * .5, bar.position.y - size * (.6 + t * 1.6))
	var width: float = ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	canvas.draw_string_outline(ThemeDB.fallback_font, at - Vector2(width * .5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(2, roundi(2 * px)), Color(0, 0, 0, .8 * (1 - t)))
	canvas.draw_string(ThemeDB.fallback_font, at - Vector2(width * .5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(RUSH_COLOR if charging else CAUTIOUS_COLOR, 1 - t * t))
