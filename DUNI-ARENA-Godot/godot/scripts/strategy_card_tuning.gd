class_name StrategyCardTuning
extends RefCounted
## Every number of the strategy card system (rules, selection, hand and swipe). Card effect numbers
## (amount, duration, extra) live in the card definitions under data/strategy.

# ---- Rules ----
## Cards taken into one battle (the loadout / hand).
const LOADOUT_SIZE: int = 5
## Order of the enemy strategy grades a disruption card can reach (일반 < 위험 < 고위험).
const TIER_ORDER: Array[StringName] = [&"normal", &"danger", &"high"]
## Unit conditions.
const LOW_HP: float = .3
## A unit counts as 근접형 when its attack reach is below this.
const MELEE_RANGE: float = 100

# ---- Card effects not held by the definitions ----
## 방벽 설치: thickness of the wall and how close a shot must come to it to be stopped.
const WALL_THICKNESS: float = 14

# ---- Hand and swipe (pixels and seconds) ----
## Cards in the fan: size, overlap, spread and lift.
const HAND_CARD := Vector2(66, 94)
const HAND_FAN_DEG: float = 5.0
const HAND_ARC: float = 2.5
const HAND_LIFT: float = 18.0
const HAND_GRAB_SCALE: float = 1.12
## A press becomes a lift once it moves this far up and mostly vertically.
const LIFT_START: float = 14.0
const LIFT_VERTICAL: float = 1.25
## The use line: this far above the top of the hand.
const USE_LINE: float = 70.0
## A quick upward flick (pixels per second) also plays the card.
const FLICK_SPEED: float = 900.0
## Follow lag (fraction per frame at 60 fps) and tilt per pixel of motion.
const FOLLOW: float = .35
const TILT: float = .004
const TILT_MAX: float = .3
## The card held over the field shrinks to this.
const FIELD_SCALE: float = .55
## Play and return animation times.
const PLAY_TIME: float = .42
const RETURN_TIME: float = .26
## Haptic tick when the card crosses the use line.
const HAPTIC_MS: int = 18
