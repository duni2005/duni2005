class_name Motion
extends RefCounted
## Motion tokens shared by every screen: durations, curves, stagger and direction.
## Speed comes from short, exact timing; nothing here holds input for more than INPUT_LOCK.

# Durations (seconds).
## Button press-in and the smallest reactions.
const TAP: float = .12
## Button release, toggles, hover and other small reactions.
const REACT: float = .2
## Elements appearing.
const ENTER: float = .42
## Elements leaving.
const EXIT: float = .3
## Screen transitions.
const SCREEN: float = .8
## The battle-start transition, the strongest one.
const SCREEN_BATTLE: float = 1.0
## Typography cinematics (room entry banner) last this long; a tap skips the ones that block.
const CINEMATIC: float = 2.0
## Gap between items that appear one after another.
const STAGGER: float = .06
## Gap between the letters of a title.
const LETTER: float = .05
## The longest any motion may keep input from the player.
const INPUT_LOCK: float = .5
## Strength of the soft overshoot used only on emphasised elements (Godot's TRANS_BACK uses 1.70158).
const OVERSHOOT: float = .6
## Primary buttons: a light streak crosses the face every SHINE_EVERY seconds, taking SHINE seconds.
const SHINE_EVERY: float = 3.2
const SHINE: float = .5

## Direction language: going forward travels right and up, going back travels left and down.
static func sign_of(back: bool) -> float:return -1.0 if back else 1.0

# Curves on 0..1.
## Entrances: fast start, soft stop.
static func out_expo(x: float) -> float:
	x = clampf(x, 0, 1);return 1.0 if x >= 1 else 1.0 - pow(2.0, -10.0 * x)
static func out_quint(x: float) -> float:
	x = clampf(x, 0, 1);return 1.0 - pow(1.0 - x, 5)
## Exits: slow start, fast leave.
static func in_cubic(x: float) -> float:
	x = clampf(x, 0, 1);return x * x * x
## Emphasis: out-cubic with a very light overshoot.
static func emphasis(x: float) -> float:
	x = clampf(x, 0, 1);var c3: float = OVERSHOOT + 1
	return 1 + c3 * pow(x - 1, 3) + OVERSHOOT * pow(x - 1, 2)
## Progress of a phase that starts at `start` and lasts `length`.
static func phase(time: float, start: float, length: float) -> float:
	return clampf((time - start) / maxf(length, .0001), 0, 1)

# Tween helpers, so tweened controls follow the same curves as drawn effects.
static func enter_curve(tweener: PropertyTweener) -> PropertyTweener:
	return tweener.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
static func exit_curve(tweener: PropertyTweener) -> PropertyTweener:
	return tweener.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
## Tweens `property` from `from` to `to` along the emphasis curve.
static func emphasize(tween: Tween, object: Object, property: NodePath, from: Variant, to: Variant, time: float, delay: float = 0) -> MethodTweener:
	return tween.tween_method(func(k: float):if is_instance_valid(object):object.set_indexed(property, lerp(from, to, emphasis(k))), 0.0, 1.0, time).set_delay(delay)

## Point at fraction `u` (0..1, clockwise from the top-left corner's end) along a rounded rectangle.
static func perimeter_point(rect: Rect2, radius: float, u: float) -> Vector2:
	var r: float = minf(radius, minf(rect.size.x, rect.size.y) * .5)
	var w: float = rect.size.x - 2 * r;var h: float = rect.size.y - 2 * r;var arc: float = PI * r * .5
	var d: float = fposmod(u, 1.0) * (2 * w + 2 * h + 4 * arc)
	var corners: Array = [rect.position + Vector2(rect.size.x - r, r), rect.end - Vector2(r, r), rect.position + Vector2(r, rect.size.y - r), rect.position + Vector2(r, r)]
	var starts: Array = [rect.position + Vector2(r, 0), rect.position + Vector2(rect.size.x, r), rect.end - Vector2(r, 0), rect.position + Vector2(0, rect.size.y - r)]
	var dirs: Array = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	var edges: Array = [w, h, w, h]
	for i in range(4):
		if d <= edges[i]:return starts[i] + dirs[i] * d
		d -= edges[i]
		if d <= arc:return corners[i] + Vector2.from_angle(-PI * .5 + i * PI * .5 + d / maxf(r, .001)) * r
		d -= arc
	return rect.position + Vector2(r, 0)
