class_name DamageOutcome
extends RefCounted
## Detached numeric damage stages; no target/source Node references.
## attempted = valid pre-critical input; resolved = rounded post-critical damage;
## hp_damage = actual HP loss (capped by remaining HP); shield_absorbed records absorption.
## Common mode also reports blocked/avoided/invulnerable/reduced outcomes.

var attempted_damage: float = 0.0
var resolved_damage: float = 0.0
var shield_absorbed: float = 0.0
var hp_damage: float = 0.0
var critical: bool = false
var accepted: bool = false

var avoided: bool = false
var invulnerable: bool = false
var parried: bool = false
var damage_reduced: bool = false
# Reserved stages for later mirror/share/rescue; no invented effects here.
var reflected_damage: float = 0
