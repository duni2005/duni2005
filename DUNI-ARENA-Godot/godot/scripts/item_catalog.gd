class_name ItemCatalog
extends RefCounted
## Unique items by grade (ItemTuning.GRADES): 일반 · 희귀 · 영웅 · 전설 · 고대. Every item is won as a
## reward (or bought in a shop); nothing combines. Numbers live in ItemTuning.
## Legacy items stay loadable for old saves but are no longer handed out.
const LEGACY = [&"vital",&"fang",&"boots",&"reengrave",&"greenNecklace",&"goldToken",&"vigorTotem",&"chargeTotem",&"predatorFang",&"thickAwl"]
## 일반: the nine former basics plus three new ones; 재각인 is a 일반 consumable.
const COMMON = [&"warmNecklace",&"woodSword",&"currentOrb",&"ether",&"leatherArmor",&"hawkFeather",&"staff",&"verdantStone",&"redThorn",&"magicCloak",&"sturdyShield",&"scopeLens",&"finisherCharm",&"quillHead",&"steelKnuckle",&"powderPouch",&"broadBlade",&"rustyNail",&"whetstone",&"ironHelm",&"windBoots",&"prismShard"]
## 희귀: the five former combined items with abilities (their old kind ids are kept so saves keep
## them) plus three new ones.
const RARE = [&"warmNecklace+verdantStone",&"currentOrb+ether",&"woodSword+redThorn",&"woodSword+hawkFeather",&"leatherArmor+hawkFeather",&"duelistGlove",&"vanguardShield",&"elementTome",&"berserkerHelm",&"sniperScope",&"vampireFang",&"hunterShuriken",&"thornArmor",&"firstStrikeRing",&"salvationFeather",&"bleedBlade",&"lifeChalice",&"sporeMoss"]
const EPIC = [&"enchantedBlade",&"overchargeCore",&"chainRing",&"hexRing",&"echoStaff",&"executionScythe",&"counterShield",&"rageHorn",&"oathChain",&"markBadge",&"steelGreatsword",&"elementStone",&"windTrail"]
## 전설: the three former ancient items plus three new ones. One of each per run.
const LEGENDARY = [&"phoenixFeather",&"hourglass",&"dragonHeart",&"sovereignSword",&"giantHeart",&"sanctuaryLamp",&"stormCrown",&"infinityEdge",&"skyBowstring",&"oblivionVeil",&"elderHeart",&"regenCore",&"lifeResonance",&"eternalArmor",&"bloodChalice",&"frostCrown"]
## 고대: custom battles only for now (no tower source).
const ANCIENT = [&"twoFacedMask",&"cursedCrown",&"gamblerDice",&"twinMirror",&"mangoSeed",&"emptyFrame",&"rewindClock",&"invertedHourglass",&"voidHeart",&"greedPouch",&"overdriveEngine",&"magnetCompass",&"shadowDoll"]
## 0.95: ten more of each grade (NEW_DEFS; effects run by ItemEffects).
const NEW_COMMON = [&"finisherCharm",&"quillHead",&"steelKnuckle",&"powderPouch",&"broadBlade",&"rustyNail",&"whetstone",&"ironHelm",&"windBoots",&"prismShard"]
const NEW_RARE = [&"berserkerHelm",&"sniperScope",&"vampireFang",&"hunterShuriken",&"thornArmor",&"firstStrikeRing",&"salvationFeather",&"bleedBlade",&"lifeChalice",&"sporeMoss"]
const NEW_EPIC = [&"hexRing",&"echoStaff",&"executionScythe",&"counterShield",&"rageHorn",&"oathChain",&"markBadge",&"steelGreatsword",&"elementStone",&"windTrail"]
const NEW_LEGENDARY = [&"stormCrown",&"infinityEdge",&"skyBowstring",&"oblivionVeil",&"elderHeart",&"regenCore",&"lifeResonance",&"eternalArmor",&"bloodChalice",&"frostCrown"]
const NEW_ANCIENT = [&"twinMirror",&"mangoSeed",&"emptyFrame",&"rewindClock",&"invertedHourglass",&"voidHeart",&"greedPouch",&"overdriveEngine",&"magnetCompass",&"shadowDoll"]
## kind -> [name, fields]; the effect key is the kind itself for the items with an effect.
const NEW_DEFS = {
	&"finisherCharm":["필살의 부적",{"ult_damage_bonus":ItemTuning.FINISHER_ULT}],
	&"quillHead":["깃 화살촉",{"tag_bonuses":{&"projectile":ItemTuning.QUILL_PROJECTILE}}],
	&"steelKnuckle":["강철 너클",{"tag_bonuses":{&"melee":ItemTuning.KNUCKLE_MELEE}}],
	&"powderPouch":["화약 주머니",{"tag_bonuses":{&"explosion":ItemTuning.POWDER_EXPLOSION}}],
	&"broadBlade":["넓은 날",{"tag_bonuses":{&"area":ItemTuning.BROAD_AREA}}],
	&"rustyNail":["녹슨 못",{"tag_bonuses":{&"dot":ItemTuning.NAIL_DOT}}],
	&"whetstone":["숫돌",{"crit_damage_bonus":ItemTuning.WHETSTONE_CRIT}],
	&"ironHelm":["철 투구",{"max_hp_multiplier":1+ItemTuning.IRON_HELM_HP,"armor_bonus":ItemTuning.IRON_HELM_ARMOR}],
	&"windBoots":["바람 신발",{"speed_multiplier":1+ItemTuning.WIND_BOOTS_SPEED}],
	&"prismShard":["프리즘 조각",{}],
	&"berserkerHelm":["광전사의 투구",{"effect":&"berserkerHelm"}],
	&"sniperScope":["저격수의 조준경",{"effect":&"sniperScope"}],
	&"vampireFang":["흡혈 송곳니",{"effect":&"vampireFang"}],
	&"hunterShuriken":["사냥꾼의 표창",{"effect":&"hunterShuriken"}],
	&"thornArmor":["가시 갑옷",{"effect":&"thornArmor"}],
	&"firstStrikeRing":["첫 일격의 반지",{"effect":&"firstStrikeRing"}],
	&"salvationFeather":["구원의 깃털",{"effect":&"salvationFeather"}],
	&"bleedBlade":["출혈의 칼날",{"effect":&"bleedBlade"}],
	&"lifeChalice":["생명의 성배",{"effect":&"lifeChalice"}],
	&"sporeMoss":["독포자 이끼",{"effect":&"sporeMoss"}],
	&"hexRing":["주술 반지",{"effect":&"hexRing"}],
	&"echoStaff":["메아리 지팡이",{"effect":&"echoStaff"}],
	&"executionScythe":["처형의 낫",{"effect":&"executionScythe"}],
	&"counterShield":["반격의 방패",{"effect":&"counterShield"}],
	&"rageHorn":["광폭의 뿔",{"effect":&"rageHorn"}],
	&"oathChain":["맹세의 사슬",{"effect":&"oathChain"}],
	&"markBadge":["표식 사냥꾼의 휘장",{"effect":&"markBadge"}],
	&"steelGreatsword":["강철 대검",{"effect":&"steelGreatsword"}],
	&"elementStone":["원소 폭발석",{"effect":&"elementStone"}],
	&"windTrail":["바람의 궤적",{"effect":&"windTrail"}],
	&"stormCrown":["폭풍의 왕관",{"effect":&"stormCrown"}],
	&"infinityEdge":["무한의 칼날",{"crit_bonus":ItemTuning.INFINITY_CRIT,"crit_damage_bonus":ItemTuning.INFINITY_CRIT_DAMAGE,"effect":&"infinityEdge"}],
	&"skyBowstring":["천공의 활시위",{"effect":&"skyBowstring"}],
	&"oblivionVeil":["망각의 장막",{"effect":&"oblivionVeil"}],
	&"elderHeart":["거목의 심장",{"effect":&"elderHeart"}],
	&"regenCore":["재생 코어",{"effect":&"regenCore"}],
	&"lifeResonance":["생명의 공명",{"effect":&"lifeResonance"}],
	&"eternalArmor":["영겁의 갑주",{"effect":&"eternalArmor"}],
	&"bloodChalice":["피의 성배",{"effect":&"bloodChalice"}],
	&"frostCrown":["서리 왕관",{"effect":&"frostCrown"}],
	&"twinMirror":["쌍둥이의 거울",{"effect":&"twinMirror"}],
	&"mangoSeed":["망고 씨앗",{"effect":&"mangoSeed"}],
	&"emptyFrame":["빈 액자",{"effect":&"emptyFrame"}],
	&"rewindClock":["역행의 시계",{"effect":&"rewindClock"}],
	&"invertedHourglass":["거꾸로 된 모래시계",{"effect":&"invertedHourglass"}],
	&"voidHeart":["공허의 심장",{"effect":&"voidHeart"}],
	&"greedPouch":["탐욕의 주머니",{"effect":&"greedPouch"}],
	&"overdriveEngine":["폭주 기관",{"effect":&"overdriveEngine"}],
	&"magnetCompass":["자석 나침반",{"effect":&"magnetCompass"}],
	&"shadowDoll":["그림자 인형",{"effect":&"shadowDoll"}],
}
## Items of each grade that rewards and shops may hand out (재각인 counts as 일반).
const POOLS = {&"common":[&"warmNecklace",&"woodSword",&"currentOrb",&"ether",&"leatherArmor",&"hawkFeather",&"staff",&"verdantStone",&"redThorn",&"magicCloak",&"sturdyShield",&"scopeLens",&"reengrave",&"finisherCharm",&"quillHead",&"steelKnuckle",&"powderPouch",&"broadBlade",&"rustyNail",&"whetstone",&"ironHelm",&"windBoots",&"prismShard"],&"rare":RARE,&"epic":EPIC,&"legendary":LEGENDARY,&"ancient":ANCIENT}
## The nine basics of 0.93 and earlier (combined items were made of two of these).
const BASIC = [&"warmNecklace",&"woodSword",&"currentOrb",&"ether",&"leatherArmor",&"hawkFeather",&"staff",&"verdantStone",&"redThorn"]
const MAX_ENHANCE: int = ItemTuning.MAX_ENHANCE
const ENHANCE_COSTS = ItemTuning.ENHANCE_COSTS
const ENHANCE_BOOST = ItemTuning.ENHANCE_BOOST
const GRADE_NAMES = ItemTuning.GRADE_NAMES
const GRADE_COLORS = ItemTuning.GRADE_COLORS
const BASIC_DEFS = {
	&"warmNecklace":["온기의 목걸이",{"healing_multiplier":1.12}],
	&"woodSword":["목검",{"physical_bonus":.12}],
	&"currentOrb":["전류 오브",{"ultimate_bonus":.15}],
	&"ether":["에테르",{"element_bonus":.2}],
	&"leatherArmor":["가죽 갑옷",{"armor_bonus":12.0}],
	&"hawkFeather":["매의 깃",{"speed_multiplier":1.06,"attack_speed_bonus":.08}],
	&"staff":["지팡이",{"magic_bonus":.12}],
	&"verdantStone":["신록석",{"max_hp_multiplier":1.15}],
	&"redThorn":["붉은 가시",{"crit_bonus":.1}],
	&"magicCloak":["마법 망토",{"magic_defense_bonus":ItemTuning.MAGIC_CLOAK_DEFENSE}],
	&"sturdyShield":["튼튼한 방패",{"physical_defense_bonus":ItemTuning.STURDY_SHIELD_DEFENSE}],
	&"scopeLens":["망원 렌즈",{"range_multiplier":1+ItemTuning.SCOPE_RANGE}],
}
## The five rare items with abilities, exactly as they were as combined items: both former
## components' stats x OLD_COMBINE_FACTOR plus the ability.
const RARE_DEFS = {
	&"warmNecklace+verdantStone":["원기 토템",{"vigor_totem":true,"ability_power":1.35},[&"warmNecklace",&"verdantStone"]],
	&"currentOrb+ether":["충전 토템",{"charge_totem":true,"ability_power":1.25},[&"currentOrb",&"ether"]],
	&"woodSword+redThorn":["포식자의 엄니",{"kill_growth":true,"ability_power":1.34},[&"woodSword",&"redThorn"]],
	&"woodSword+hawkFeather":["굵은 송곳",{"opening_awl":true,"ability_power":1.25},[&"woodSword",&"hawkFeather"]],
	&"leatherArmor+hawkFeather":["황금 토큰",{"victory_gold":55},[&"leatherArmor",&"hawkFeather"]],
	&"duelistGlove":["결투가의 장갑",{"duelist":true},[]],
	&"vanguardShield":["선봉의 방패",{"vanguard":true},[]],
	&"elementTome":["원소술사의 서",{"elementalist":true},[]],
}
const EPIC_DEFS = {
	&"enchantedBlade":["마법 부여 검",{"enchant":true}],
	&"overchargeCore":["과충전 코어",{"overcharge":true}],
	&"chainRing":["연쇄의 고리",{"chain_ring":true}],
}
const LEGENDARY_DEFS = {
	&"phoenixFeather":["불사조의 깃털",{"max_hp_multiplier":1.1,"phoenix":true}],
	&"hourglass":["시간의 모래시계",{"ultimate_bonus":.25,"hourglass":true}],
	&"dragonHeart":["용의 심장",{"max_hp_multiplier":1.15,"dragon_heart":true}],
	&"sovereignSword":["군주의 검",{"attack_multiplier":1+ItemTuning.SOVEREIGN_ATTACK,"sovereign":true}],
	&"giantHeart":["거인의 심장",{"max_hp_multiplier":1+ItemTuning.GIANT_HP,"scale_multiplier":ItemTuning.GIANT_SCALE,"speed_multiplier":1+ItemTuning.GIANT_SPEED,"immovable":true}],
	&"sanctuaryLamp":["성역의 등불",{"sanctuary":true}],
}
const ANCIENT_DEFS = {
	&"twoFacedMask":["두 얼굴의 가면",{"kind_swap":true}],
	&"cursedCrown":["저주받은 왕관",{"crown":true}],
	&"gamblerDice":["도박사의 주사위",{"dice":true}],
}
const BONUS_FIELDS = ["physical_bonus","magic_bonus","element_bonus","ultimate_bonus","armor_bonus","attack_speed_bonus","crit_bonus","physical_defense_bonus","magic_defense_bonus"]
const MULTIPLIER_FIELDS = ["max_hp_multiplier","attack_multiplier","speed_multiplier","healing_multiplier","range_multiplier"]
static var _definitions: Dictionary = {}
static var _enhanced: Dictionary = {}

static func all() -> Dictionary:
	if _definitions.is_empty():
		for kind in LEGACY:_definitions[kind]=load("res://data/items/%s.tres"%kind)
		# 재각인 is a 일반 consumable now (0.93 and earlier: legacy grade).
		_definitions[&"reengrave"]=_definitions[&"reengrave"].duplicate();_definitions[&"reengrave"].grade=&"common"
		for kind in COMMON:
			if BASIC_DEFS.has(kind):_definitions[kind]=_make(kind,BASIC_DEFS[kind][0],&"common",BASIC_DEFS[kind][1],ItemTuning.BASIC_PRICES[kind])
		for kind in RARE:
			if not RARE_DEFS.has(kind):continue
			var fields: Dictionary=RARE_DEFS[kind][1].duplicate()
			var parts: Array=RARE_DEFS[kind][2]
			for part in parts:
				var stats: Dictionary=BASIC_DEFS[part][1]
				for field in stats:
					if field in BONUS_FIELDS:fields[field]=float(fields.get(field,0))+float(stats[field])*ItemTuning.OLD_COMBINE_FACTOR
					else:fields[field]=float(fields.get(field,1))+(float(stats[field])-1)*ItemTuning.OLD_COMBINE_FACTOR
			_definitions[kind]=_make(kind,RARE_DEFS[kind][0],&"rare",fields,ItemTuning.GRADE_PRICES[&"rare"])
		for kind in EPIC:
			if EPIC_DEFS.has(kind):_definitions[kind]=_make(kind,EPIC_DEFS[kind][0],&"epic",EPIC_DEFS[kind][1],ItemTuning.GRADE_PRICES[&"epic"])
		for kind in LEGENDARY:
			if LEGENDARY_DEFS.has(kind):_definitions[kind]=_make(kind,LEGENDARY_DEFS[kind][0],&"legendary",LEGENDARY_DEFS[kind][1],ItemTuning.GRADE_PRICES[&"legendary"])
		for kind in ANCIENT:
			if ANCIENT_DEFS.has(kind):_definitions[kind]=_make(kind,ANCIENT_DEFS[kind][0],&"ancient",ANCIENT_DEFS[kind][1],ItemTuning.GRADE_PRICES[&"ancient"])
		for pair in [[NEW_COMMON,&"common"],[NEW_RARE,&"rare"],[NEW_EPIC,&"epic"],[NEW_LEGENDARY,&"legendary"],[NEW_ANCIENT,&"ancient"]]:
			for kind in pair[0]:
				var gold: int=ItemTuning.NEW_COMMON_PRICES[kind] if pair[1]==&"common" else ItemTuning.GRADE_PRICES[pair[1]]
				_definitions[kind]=_make(kind,NEW_DEFS[kind][0],pair[1],NEW_DEFS[kind][1],gold)
	return _definitions.duplicate()
static func get_item(kind: StringName) -> ItemData:return all().get(kind)
## Items that can be equipped or offered (no legacy), lowest grade first.
static func current() -> Array:
	var out: Array=[]
	for grade in ItemTuning.GRADES:out.append_array(POOLS[grade])
	return out
## The item as owned: an enhanced item at +N has every stat it raises boosted by ENHANCE_BOOST[N]
## (abilities stay as they are) and "+N" after its name.
static func of(instance: ItemInstance) -> ItemData:
	if instance.kind==&"prismShard":return prism(instance.variant)
	return enhanced(instance.kind,instance.enhance)
## 프리즘 조각 with its element: that element's damage +PRISM_BONUS, the element after its name.
static func prism(element: StringName) -> ItemData:
	var base: ItemData=get_item(&"prismShard")
	if not element in ItemTuning.PRISM_ELEMENTS:return base
	var key: String="prism@%s"%element
	if not _enhanced.has(key):
		var item: ItemData=base.duplicate();item.element_choice=element;item.tag_bonuses={element:ItemTuning.PRISM_BONUS}
		item.display_name="%s · %s"%[base.display_name,UnitStatTable.TAG_NAMES[element]];item.description=describe(item);_enhanced[key]=item
	return _enhanced[key]
## The element a newly won 프리즘 조각 gets (seeded by the run).
static func roll_prism(rng: RandomNumberGenerator) -> StringName:
	return ItemTuning.PRISM_ELEMENTS[rng.randi_range(0,ItemTuning.PRISM_ELEMENTS.size()-1)]
## Custom battles: a 프리즘 조각's element comes from the entry and slot (no rng, no saving).
static func custom_prism(entry_id: int,slot: int) -> StringName:
	return ItemTuning.PRISM_ELEMENTS[posmod(entry_id*7+slot*3,ItemTuning.PRISM_ELEMENTS.size())]
static func enhanced(kind: StringName,level: int) -> ItemData:
	var base: ItemData=get_item(kind)
	if base==null or level<=0:return base
	var key: String="%s@%d"%[kind,level]
	if not _enhanced.has(key):
		var item: ItemData=base.duplicate();var boost: float=1+ENHANCE_BOOST[clampi(level,0,MAX_ENHANCE)]
		for field in BONUS_FIELDS:item.set(field,float(base.get(field))*boost)
		for field in MULTIPLIER_FIELDS:item.set(field,1+(float(base.get(field))-1)*boost)
		item.display_name="%s +%d"%[base.display_name,level];item.description=describe(item);_enhanced[key]=item
	return _enhanced[key]
static func can_enhance(instance: ItemInstance) -> bool:
	var item: ItemData=get_item(instance.kind) if instance!=null else null
	return item!=null and item.grade in ItemTuning.ENHANCE_GRADES and not item.consumable and instance.enhance<MAX_ENHANCE
## Grade colour of an owned item; an item at +MAX_ENHANCE shows gold.
static func instance_color(instance: ItemInstance) -> Color:
	return Color("ffd54a") if instance.enhance>=MAX_ENHANCE else grade_color(instance.kind)
## Shop price of an item (일반 keeps its own price).
static func price(kind: StringName) -> int:
	var item: ItemData=get_item(kind);return item.gold_price if item!=null else 0
## Blacksmith 판매: 일반 · 희귀 items for half their shop price.
static func sell_price(kind: StringName) -> int:
	var item: ItemData=get_item(kind)
	return int(item.gold_price*ItemTuning.SELL_RATE) if item!=null and item.grade in ItemTuning.SELL_GRADES else 0
static func grade_of(kind: StringName) -> StringName:
	var item: ItemData=get_item(kind);return item.grade if item!=null else &""
## 0 (일반) .. 4 (고대); legacy -1.
static func grade_rank(kind: StringName) -> int:return ItemTuning.GRADES.find(grade_of(kind))
static func grade_name(kind: StringName) -> String:
	var item: ItemData=get_item(kind);return GRADE_NAMES.get(item.grade,"") if item!=null else ""
static func grade_color(kind: StringName) -> Color:
	var item: ItemData=get_item(kind);return GRADE_COLORS.get(item.grade,Color.WHITE) if item!=null else Color.WHITE
## 0.93 combined items that no longer exist: kind "a+b" of two basics, not one of the kept rares.
static func removed_combination(kind: String) -> bool:
	if not "+" in kind or StringName(kind) in RARE:return false
	return StringName(kind.get_slice("+",0)) in BASIC and StringName(kind.get_slice("+",1)) in BASIC
## Names of the 0.93 combined items, for the save conversion notice.
const REMOVED_NAMES = {
	"warmNecklace+warmNecklace":"성스러운 성배","woodSword+woodSword":"강철 대검","currentOrb+currentOrb":"뇌운 코어","ether+ether":"순수 원소석","leatherArmor+leatherArmor":"강철 흉갑","hawkFeather+hawkFeather":"질풍의 날개","staff+staff":"대마법사의 지팡이","verdantStone+verdantStone":"거목의 심장","redThorn+redThorn":"핏빛 장미",
	"warmNecklace+woodSword":"성기사의 검","warmNecklace+currentOrb":"생명 전류석","warmNecklace+ether":"치유의 정수","warmNecklace+leatherArmor":"수도사의 법의","warmNecklace+hawkFeather":"순례자의 깃","warmNecklace+staff":"치유사의 홀","warmNecklace+redThorn":"가시 덩굴 목걸이",
	"woodSword+currentOrb":"번개 칼날","woodSword+ether":"원소 검","woodSword+leatherArmor":"기사의 방패검","woodSword+staff":"마검","woodSword+verdantStone":"거인의 곤봉",
	"currentOrb+leatherArmor":"축전 갑주","currentOrb+hawkFeather":"폭풍 깃털","currentOrb+staff":"뇌전의 홀","currentOrb+verdantStone":"생명 축전지","currentOrb+redThorn":"번개 가시",
	"ether+leatherArmor":"원소 결계 갑옷","ether+hawkFeather":"정령의 깃","ether+staff":"원소술사의 지팡이","ether+verdantStone":"대지 정수","ether+redThorn":"화염 가시",
	"leatherArmor+staff":"마법 방어구","leatherArmor+verdantStone":"거북 등껍질","leatherArmor+redThorn":"가시 갑옷",
	"hawkFeather+staff":"바람의 지팡이","hawkFeather+verdantStone":"숲의 날개","hawkFeather+redThorn":"사냥꾼의 깃",
	"staff+verdantStone":"생명의 홀","staff+redThorn":"저주받은 지팡이",
	"verdantStone+redThorn":"붉은 신록석",
}
static func removed_name(kind: String) -> String:return REMOVED_NAMES.get(kind,kind)
## Gold returned for a removed combined item: what its two materials cost in a shop.
static func refund(kind: String) -> int:
	return int(ItemTuning.BASIC_PRICES.get(StringName(kind.get_slice("+",0)),0))+int(ItemTuning.BASIC_PRICES.get(StringName(kind.get_slice("+",1)),0))

static func _make(kind: StringName,title: String,grade: StringName,fields: Dictionary,gold: int) -> ItemData:
	var item:=ItemData.new();item.kind=kind;item.display_name=title;item.grade=grade;item.gold_price=gold
	for field in fields:item.set(field,fields[field])
	item.description=describe(item)
	return item

## One line per effect, generated from the numbers so text and rules never drift apart.
static func describe(item: ItemData) -> String:
	var lines: Array[String]=[]
	var pct:=func(v: float) -> String:return "+%s%%"%_num(v*100)
	if item.physical_bonus>0:lines.append("물리 피해 "+pct.call(item.physical_bonus))
	if item.magic_bonus>0:lines.append("마법 피해 "+pct.call(item.magic_bonus))
	if item.element_bonus>0:lines.append("속성 피해 "+pct.call(item.element_bonus))
	if item.attack_multiplier>1:lines.append("공격력 "+pct.call(item.attack_multiplier-1))
	if item.max_hp_multiplier>1:lines.append("최대 HP "+pct.call(item.max_hp_multiplier-1))
	if item.armor_bonus>0:lines.append("방어력 +%s"%_num(item.armor_bonus))
	if item.physical_defense_bonus>0:lines.append("물리 방어력 +%s"%_num(item.physical_defense_bonus))
	if item.magic_defense_bonus>0:lines.append("마법 방어력 +%s"%_num(item.magic_defense_bonus))
	if item.attack_speed_bonus>0:lines.append("공격속도 "+pct.call(item.attack_speed_bonus))
	if item.speed_multiplier>1:lines.append("이동속도 "+pct.call(item.speed_multiplier-1))
	elif item.speed_multiplier<1:lines.append("이동속도 -%s%%"%_num((1-item.speed_multiplier)*100))
	if item.range_multiplier>1:lines.append("사거리 "+pct.call(item.range_multiplier-1))
	if item.crit_bonus>0:lines.append("치명타 확률 +%s%%p"%_num(item.crit_bonus*100))
	if item.ultimate_bonus>0:lines.append("궁극기 충전 "+pct.call(item.ultimate_bonus))
	if item.healing_multiplier>1:lines.append("주는 · 받는 치유 "+pct.call(item.healing_multiplier-1))
	if item.vigor_totem:lines.append("5초마다 주변 아군 HP %d 회복"%roundi(6*item.ability_power))
	if item.charge_totem:lines.append("4초마다 주변 아군 궁극기 +%d%%"%roundi(4*item.ability_power))
	if item.kill_growth:lines.append("처치마다 공격력 영구 +%s%%"%String.num(1.5*item.ability_power,1))
	if item.opening_awl:lines.append("전투 시작 시 송곳 투척 · 적중한 적 %s초 기절"%String.num(4*item.ability_power,1))
	if item.victory_gold>0:lines.append("생존 승리 시 %d G"%item.victory_gold)
	if item.duelist:lines.append("같은 대상을 연속 공격할수록 피해 +%s%% 누적(최대 +%s%%) · 대상이 바뀌면 초기화"%[_num(ItemTuning.DUELIST_STEP*100),_num(ItemTuning.DUELIST_MAX*100)])
	if item.vanguard:lines.append("전투 시작 후 %d초간 받는 피해 -%s%%"%[int(ItemTuning.VANGUARD_TIME),_num((1-ItemTuning.VANGUARD_TAKEN)*100)])
	if item.elementalist:lines.append("화상 · 맹독 · 빙결 · 감전 · 침식에 걸린 적에게 주는 피해 +%s%%"%_num((ItemTuning.ELEMENTALIST_DEALT-1)*100))
	if item.enchant:lines.append("기본공격에 자신의 속성 부여(없으면 화염)")
	if item.overcharge:lines.append("궁극기 사용 직후 게이지 %d%% 회복"%int(ItemTuning.OVERCHARGE_REFUND))
	if item.chain_ring:lines.append("기본공격 %d번째마다 %d 거리 안의 가장 가까운 다른 적에게 같은 피해"%[ItemTuning.CHAIN_EVERY,int(ItemTuning.CHAIN_RANGE)])
	if item.sovereign:lines.append("처치마다 반경 %d 안 아군 공격력 +%s%% (%d초, 최대 %d중첩)"%[int(ItemTuning.SOVEREIGN_RADIUS),_num(ItemTuning.SOVEREIGN_BUFF*100),int(ItemTuning.SOVEREIGN_TIME),ItemTuning.SOVEREIGN_STACKS])
	if item.scale_multiplier>1:lines.append("몸집 %s배"%String.num(item.scale_multiplier,1))
	if item.immovable:lines.append("넉백 · 끌림 면역")
	if item.sanctuary:lines.append("반경 %d 안 아군(자신 포함) 받는 피해 -%s%%"%[int(ItemTuning.SANCTUARY_RADIUS),_num((1-ItemTuning.SANCTUARY_TAKEN)*100)])
	if item.kind_swap:lines.append("모든 피해의 물리 · 마법 유형과 물리 · 마법 피해 스탯이 서로 뒤바뀐다")
	if item.crown:lines.append("모든 스탯 +%s%% · 탑에서 전투가 끝날 때마다 최대 HP 영구 -%s%%"%[_num(ItemTuning.CROWN_STATS*100),_num(ItemTuning.CROWN_DECAY*100)])
	if item.dice:lines.append("전투 시작마다 무작위 스탯 하나 +%s%%, 다른 하나 -%s%%"%[_num(ItemTuning.DICE_UP*100),_num(-ItemTuning.DICE_DOWN*100)])
	if item.phoenix:lines.append("전투당 1회, 쓰러지면 HP 40%로 부활 · 2초 무적")
	if item.hourglass:lines.append("궁극기 사용 직후 게이지 35% 회복")
	if item.dragon_heart:lines.append("4초마다 주변 적에게 공격력 60% 화염 피해")
	if item.ult_damage_bonus>0:lines.append("궁극기 피해량 "+pct.call(item.ult_damage_bonus))
	for tag in item.tag_bonuses:lines.append("%s 피해 %s"%[UnitStatTable.TAG_NAMES.get(tag,String(tag)),pct.call(float(item.tag_bonuses[tag]))])
	if item.kind==&"prismShard" and item.element_choice==&"":lines.append("얻을 때 7속성 중 하나가 정해지고 그 속성 피해 "+pct.call(ItemTuning.PRISM_BONUS))
	if item.crit_damage_bonus>0:lines.append("치명타 피해량 "+pct.call(item.crit_damage_bonus))
	if item.effect!=&"":lines.append(effect_text(item.effect))
	return " · ".join(lines)
## The special effect of a 0.95 item, from the numbers in ItemTuning.
static func effect_text(effect: StringName) -> String:
	var p:=func(v: float) -> String:return _num(v*100)+"%"
	match effect:
		&"berserkerHelm":return "HP %s 이하일 때 공격속도 +%s"%[p.call(ItemTuning.BERSERK_HP),p.call(ItemTuning.BERSERK_ATTACK_SPEED)]
		&"sniperScope":return "대상과 %d 이상 떨어져 있으면 주는 피해 +%s"%[int(ItemTuning.SCOPE_DISTANCE),p.call(ItemTuning.SCOPE_DEALT)]
		&"vampireFang":return "직접 공격으로 준 피해의 %s 회복"%p.call(ItemTuning.VAMPIRE_LEECH)
		&"hunterShuriken":return "처치 시 %d초간 공격속도 +%s"%[int(ItemTuning.HUNTER_TIME),p.call(ItemTuning.HUNTER_ATTACK_SPEED)]
		&"thornArmor":return "근접공격 피해를 받으면 받은 피해의 %s를 공격자에게 물리 피해로 반사"%p.call(ItemTuning.THORN_REFLECT)
		&"firstStrikeRing":return "전투마다 첫 기본공격 피해 +%s"%p.call(ItemTuning.FIRST_STRIKE)
		&"salvationFeather":return "HP %s 이하 아군에게 다가갈 때 이동속도 +%s, 닿으면 그 아군에게 최대 HP %s 보호막(전투당 %d회)"%[p.call(ItemTuning.SALVATION_HP),p.call(ItemTuning.SALVATION_SPEED),p.call(ItemTuning.SALVATION_SHIELD),ItemTuning.SALVATION_USES]
		&"bleedBlade":return "치명타 시 %d초 출혈: %s초마다 물리 지속 피해(그 치명타 피해의 %s를 나눠서)"%[int(ItemTuning.BLEED_TIME),String.num(ItemTuning.BLEED_EVERY,1),p.call(ItemTuning.BLEED_SHARE)]
		&"lifeChalice":return "주는 치유 중 최대 HP를 넘는 양은 대상의 보호막으로(대상 최대 HP %s까지)"%p.call(ItemTuning.CHALICE_SHIELD_CAP)
		&"sporeMoss":return "직접 공격에 맞으면 %s 확률로 반경 %d 안 적에게 맹독 1스택"%[p.call(ItemTuning.SPORE_CHANCE),int(ItemTuning.SPORE_RADIUS)]
		&"hexRing":return "기본공격의 피해 유형이 대상의 방어가 더 낮은 쪽(물리 · 마법)으로 바뀐다"
		&"echoStaff":return "마법 직접 공격 시 %s 확률로 %s초 뒤 같은 피해의 %s가 한 번 더"%[p.call(ItemTuning.ECHO_CHANCE),String.num(ItemTuning.ECHO_DELAY,2),p.call(ItemTuning.ECHO_SHARE)]
		&"executionScythe":return "치명타가 HP %s 이하 적에게 들어가면 즉시 처치(엘리트 · 보스 제외)"%p.call(ItemTuning.SCYTHE_HP)
		&"counterShield":return "패링 · 회피 성공 시 %d초 안의 다음 공격이 확정 치명타"%int(ItemTuning.COUNTER_SHIELD_TIME)
		&"rageHorn":return "저돌적일 때 받는 피해 증가 무효 · 처치 시 최대 HP %s 회복"%p.call(ItemTuning.HORN_HEAL)
		&"oathChain":return "엄호 중 지키는 아군 곁에서 받은 피해의 %s를 자신의 보호막으로(최대 HP %s까지)"%[p.call(ItemTuning.OATH_SHARE),p.call(ItemTuning.OATH_CAP)]
		&"markBadge":return "광휘 · 암흑 표식을 터뜨리면 효과 2배(회복 %s, 피해 +%s)"%[p.call(ItemTuning.BADGE_LIGHT_HEAL),p.call(ItemTuning.BADGE_DARK_POP-1)]
		&"steelGreatsword":return "기본공격 %d번째마다 피해 %s 강타 + 넉백"%[ItemTuning.GREATSWORD_EVERY,p.call(ItemTuning.GREATSWORD_DEALT)]
		&"elementStone":return "치명타 시 대상의 화상 · 맹독 · 빙결 · 감전 스택 절반을 반경 %d 안 다른 적에게 옮기고 마법 폭발(10 + 마법 피해 50%%)"%int(ItemTuning.STONE_RADIUS)
		&"windTrail":return "지나간 자리에 %d초간 기류 흔적 · 그 위를 지나는 적은 역풍"%int(ItemTuning.WIND_TRAIL_TIME)
		&"stormCrown":return "궁극기마다 반경 %d 안 모든 적에게 낙뢰(15 + 마법 피해 80%%) + 감전 %d스택"%[int(ItemTuning.STORM_RADIUS),ItemTuning.STORM_SHOCK]
		&"infinityEdge":return "치명타가 금빛 칼날로 번뜩인다"
		&"skyBowstring":return "투사체가 적을 최대 %d명 관통 · 관통마다 피해 +%s"%[ItemTuning.BOWSTRING_PIERCE,p.call(ItemTuning.BOWSTRING_STEP)]
		&"oblivionVeil":return "전투 시작 시 %d초 은신 · 은신 중 첫 공격 피해 ×%d · 공격하면 드러난다"%[int(ItemTuning.VEIL_TIME),int(ItemTuning.VEIL_STRIKE)]
		&"elderHeart":return "%d초마다 최대 HP %s 회복 · %d초마다 최대 HP +%s(전투 동안, 최대 %d스택)"%[int(ItemTuning.ELDER_HEAL_EVERY),p.call(ItemTuning.ELDER_HEAL),int(ItemTuning.ELDER_GROW_EVERY),p.call(ItemTuning.ELDER_GROW),ItemTuning.ELDER_STACKS]
		&"regenCore":return "궁극기 사용 시 HP %s 회복 + %d초간 받는 피해 -%s"%[p.call(ItemTuning.REGEN_HEAL),int(ItemTuning.REGEN_TIME),p.call(1-ItemTuning.REGEN_TAKEN)]
		&"lifeResonance":return "궁극기 사용 시 반경 %d 안 아군 HP %s 회복"%[int(ItemTuning.RESONANCE_RADIUS),p.call(ItemTuning.RESONANCE_HEAL)]
		&"eternalArmor":return "한 번에 받는 피해가 최대 HP의 %s를 넘지 않는다(상태 이상 피해 제외)"%p.call(ItemTuning.ETERNAL_CAP)
		&"bloodChalice":return "출정한 아군 전원이 직접 공격으로 준 피해의 %s 회복"%p.call(ItemTuning.BLOOD_LEECH)
		&"frostCrown":return "얼음 공격의 빙결 스택 확률 100%% · 빙결된 적을 처치하면 반경 %d 안 적에게 빙결 %d스택"%[int(ItemTuning.FROST_CROWN_RADIUS),ItemTuning.FROST_CROWN_STACKS]
		&"twinMirror":return "전투 시작 시 분신 소환(HP · 피해 %s, 아이템 효과 · 궁극기 없음, 쓰러져도 손실 없음)"%p.call(ItemTuning.MIRROR_HP)
		&"mangoSeed":return "탑 전투 승리마다 1단계(최대 %d) · %d단계부터 %d초마다 아군 전원 HP %s 회복(커스텀 전투는 %d단계)"%[ItemTuning.MANGO_STAGES,ItemTuning.MANGO_STAGES,int(ItemTuning.MANGO_EVERY),p.call(ItemTuning.MANGO_HEAL),ItemTuning.MANGO_STAGES]
		&"emptyFrame":return "전투 시작 시 가장 가까운 아군의 아이템 하나(고대 제외)를 그 전투 동안 복사"
		&"rewindClock":return "전투 시작 %d초 후 HP와 위치를 전투 시작 때로 한 번 되돌린다"%int(ItemTuning.REWIND_AT)
		&"invertedHourglass":return "터닝포인트마다 궁극기 게이지가 가득 찬다(터닝포인트가 없는 전투는 %d초, 이후 %d초마다) · 초월 게이지는 차지 않는다"%[int(ItemTuning.HOURGLASS_FIRST),int(ItemTuning.HOURGLASS_EVERY)]
		&"voidHeart":return "회복하지 못한다 · 받을 치유 %d마다 공격력 +%s(최대 +%s)"%[int(ItemTuning.VOID_PER),p.call(ItemTuning.VOID_STEP),p.call(ItemTuning.VOID_MAX)]
		&"greedPouch":return "직접 공격이 맞을 때마다 %d G(전투당 최대 %d G, 탑에서만 지급) · 받는 피해 +%s"%[ItemTuning.GREED_GOLD,ItemTuning.GREED_MAX,p.call(ItemTuning.GREED_TAKEN-1)]
		&"overdriveEngine":return "매초 공격속도 +%s 누적 · %d초가 되면 %d초 과열(행동 불가) 후 초기화"%[p.call(ItemTuning.OVERDRIVE_STEP),int(ItemTuning.OVERDRIVE_TIME),int(ItemTuning.OVERHEAT_TIME)]
		&"magnetCompass":return "반경 %d 안 모든 투사체가 자신 쪽으로 휜다 · 적 투사체는 자신이 맞고, 아군 투사체는 통과하며 피해 +%s"%[int(ItemTuning.COMPASS_RADIUS),p.call(ItemTuning.COMPASS_BOOST)]
		&"shadowDoll":return "받는 피해의 %s를 가장 가까운 적에게 떠넘긴다 · 주는 피해 -%s"%[p.call(ItemTuning.DOLL_SHARE),p.call(1-ItemTuning.DOLL_DEALT)]
	return ""
## 15 -> "15", 12.5 -> "12.5".
static func _num(v: float) -> String:
	return str(roundi(v)) if absf(v-roundf(v))<.05 else String.num(v,1)
