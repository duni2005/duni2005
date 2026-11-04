class_name CharacterCatalog
extends RefCounted
const NAMES = ["warrior", "archer", "mage", "assassin", "guardian", "healer", "sniper", "shotgun", "rps", "ufc", "greatsword", "dolphin", "predator", "bomber", "swordsman", "satellite", "paladin", "hero", "tank", "fanatic", "lightning", "mirror", "galaxy", "machine_gun", "frog", "puppet","stake", "conductor", "refraction", "courier", "magnet", "frost", "flamethrower", "griffin", "crossbow", "slime", "parrot", "whisperer", "plague", "golem", "flame_blade", "snowman", "santa"]
static var _data: Dictionary = {}
static func all() -> Dictionary:
	if _data.is_empty():
		for name in NAMES:
			var data: UnitData = load("res://data/%s.tres" % name)
			_data[data.type_id] = data
	return _data.duplicate()
## Every hit a character deals is physical or magic, optionally with an element. Items scale
## these: 목검 physical, 지팡이 magic, 에테르 any elemental hit.
const DAMAGE = {
	"warrior":[&"physical",&""],"archer":[&"physical",&"wind"],"mage":[&"magic",&""],"assassin":[&"physical",&""],
	"guardian":[&"physical",&""],"healer":[&"magic",&"light"],"sniper":[&"physical",&""],"shotgun":[&"physical",&""],
	"rps":[&"physical",&""],"ufc":[&"physical",&""],"greatsword":[&"physical",&""],"dolphin":[&"physical",&"ice"],
	"predator":[&"physical",&""],"bomber":[&"physical",&"fire"],"swordsman":[&"physical",&""],"satellite":[&"physical",&"lightning"],
	"paladin":[&"physical",&"light"],"hero":[&"physical",&"lightning"],"tank":[&"physical",&"fire"],"fanatic":[&"physical",&"dark"],
	"lightning":[&"magic",&"lightning"],"mirror":[&"magic",&"light"],"galaxy":[&"magic",&"dark"],"machine_gun":[&"physical",&""],
	"frog":[&"physical",&"poison"],"puppet":[&"magic",&""],"stake":[&"physical",&""],"conductor":[&"physical",&""],
	"refraction":[&"magic",&"light"],"courier":[&"physical",&""],"magnet":[&"magic",&"lightning"],"frost":[&"magic",&"ice"],"flamethrower":[&"magic",&"fire"],"griffin":[&"magic",&"wind"],"crossbow":[&"physical",&"wind"],"slime":[&"physical",&"poison"],"parrot":[&"physical",&"wind"],"whisperer":[&"physical",&"dark"],"plague":[&"physical",&"poison"],"golem":[&"physical",&"ice"],"flame_blade":[&"physical",&"fire"],"snowman":[&"magic",&"ice"],"santa":[&"physical",&""],
}
const ELEMENT_NAMES = {&"fire":"화염",&"ice":"얼음",&"lightning":"번개",&"light":"빛",&"dark":"어둠",&"poison":"맹독",&"wind":"바람"}
static func damage_kind(type_id: int) -> StringName:
	return DAMAGE[NAMES[type_id]][0] if type_id>=0 and type_id<NAMES.size() else &"physical"
static func element(type_id: int) -> StringName:
	return DAMAGE[NAMES[type_id]][1] if type_id>=0 and type_id<NAMES.size() else &""
## "물리", "마법 · 얼음" ...
static func damage_label(type_id: int) -> String:
	var label: String="물리" if damage_kind(type_id)==&"physical" else "마법"
	var e: StringName=element(type_id)
	return label+(" · "+ELEMENT_NAMES[e] if e!=&"" else "")
