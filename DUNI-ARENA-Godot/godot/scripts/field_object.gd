class_name FieldObject
extends RefCounted
## A thing standing on the battlefield (구조물 시련): where it is, how big, whether units and
## projectiles get through, whether it can be destroyed, the aura it gives off and how it reacts
## to a hit. KINDS holds each kind's numbers; FieldObjects places them and runs them in battle.
## In a room's layout `position` is in board space (ArenaMap.BOARD); in battle, map space.

## 온기의 동상: in the middle of the field; heals every unit within STATUE_AURA by STATUE_HEAL of
## its max HP each STATUE_EVERY s.
const STATUE: StringName = &"statue"
const STATUE_RADIUS: float = 40.0
const STATUE_AURA: float = 150.0
const STATUE_HEAL: float = .02
const STATUE_EVERY: float = 1.0
## 화약통: KEG_COUNT of them in the middle strip, KEG_SPACING apart. A hit lights the fuse; after
## KEG_FUSE s (KEG_CHAIN_FUSE when another keg set it off) it blasts everyone within KEG_BLAST for
## 시련 피해 KEG_BASE + KEG_PER_FLOOR × floor, KEG_BURN 화염 stacks and a KEG_PUSH knockback.
const KEG: StringName = &"keg"
const KEG_RADIUS: float = 18.0
const KEG_COUNT: int = 5
const KEG_SPACING: float = 120.0
const KEG_FUSE: float = .4
const KEG_CHAIN_FUSE: float = .15
const KEG_BLAST: float = 110.0
const KEG_BASE: float = 25.0
const KEG_PER_FLOOR: float = 12.0
const KEG_BURN: int = 2
const KEG_PUSH: float = 300.0

## Kind → [radius, units pass, projectiles pass, destructible, aura {radius, heal, every}, on_hit].
const KINDS = {
	STATUE: {"radius": STATUE_RADIUS, "units_pass": false, "projectiles_pass": true, "destructible": false, "aura": {"radius": STATUE_AURA, "heal": STATUE_HEAL, "every": STATUE_EVERY}, "on_hit": &""},
	KEG: {"radius": KEG_RADIUS, "units_pass": false, "projectiles_pass": false, "destructible": true, "aura": {}, "on_hit": &"fuse"},
}

var kind: StringName
var position: Vector2
var radius: float
var units_pass: bool
var projectiles_pass: bool
var destructible: bool
var aura: Dictionary
var on_hit: StringName
## Seconds left on a lit fuse (-1: not lit).
var fuse: float = -1
var alive: bool = true
var aura_clock: float = 0
## Battle-local serial (events and drawing find it by this).
var object_id: int = 0

static func make(object_kind: StringName, at: Vector2, scale: float = 1.0) -> FieldObject:
	var o := FieldObject.new();var def: Dictionary = KINDS[object_kind]
	o.kind = object_kind;o.position = at;o.radius = float(def.radius) * scale
	o.units_pass = def.units_pass;o.projectiles_pass = def.projectiles_pass;o.destructible = def.destructible
	o.aura = def.aura.duplicate();o.on_hit = def.on_hit
	if o.aura.has("radius"):o.aura.radius = float(o.aura.radius) * scale
	return o
