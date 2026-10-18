class_name CombatStance
extends RefCounted
## Canonical web IDs. Phase 2 stores these; it does not apply their AI/stat effects.

const NORMAL: StringName = &"normal"
const CAUTIOUS: StringName = &"cautious"
const RUSH: StringName = &"rush"
const COVER: StringName = &"cover"
const VALUES: Array[StringName] = [NORMAL, CAUTIOUS, RUSH, COVER]

static func normalize(value: Variant) -> StringName:
	if value is String or value is StringName:
		var candidate := StringName(value)
		if VALUES.has(candidate):
			return candidate
	return NORMAL
