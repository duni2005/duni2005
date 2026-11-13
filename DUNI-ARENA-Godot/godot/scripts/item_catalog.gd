class_name ItemCatalog
extends RefCounted
## Unique items by grade (ItemTuning.GRADES): 일반 · 희귀 · 영웅 · 전설 · 고대. Every item is won as a
## reward (or bought in a shop); nothing combines. Numbers live in ItemTuning.
## Legacy items stay loadable for old saves but are no longer handed out.
const LEGACY = [&"vital",&"fang",&"boots",&"reengrave",&"greenNecklace",&"goldToken",&"vigorTotem",&"chargeTotem",&"predatorFang",&"thickAwl"]
## 일반: the nine former basics, three 0.94 and ten 0.95 stat items; 재각인 is a 일반 consumable.
const COMMON = [&"warmNecklace",&"woodSword",&"currentOrb",&"ether",&"leatherArmor",&"hawkFeather",&"staff",&"verdantStone",&"redThorn",&"magicCloak",&"sturdyShield",&"scopeLens",&"finisherCharm",&"quillHead",&"steelKnuckle",&"powderPouch",&"broadBlade",&"rustyNail",&"whetstone",&"ironHelm",&"windBoots",&"prismShard"]
const NEW_COMMON = [&"finisherCharm",&"quillHead",&"steelKnuckle",&"powderPouch",&"broadBlade",&"rustyNail",&"whetstone",&"ironHelm",&"windBoots",&"prismShard"]
## 희귀 ~ 고대 (0.96 아이템 재점검): every item has stat lines plus one effect and no penalty. The
## five old ability items keep their kind ids ("a+b") so saves keep them.
const RARE = [&"warmNecklace+verdantStone",&"currentOrb+ether",&"woodSword+redThorn",&"woodSword+hawkFeather",&"leatherArmor+hawkFeather",&"duelistGlove",&"vanguardShield",&"elementTome",&"berserkerHelm",&"sniperScope",&"vampireFang",&"hunterShuriken",&"thornArmor",&"bleedBlade",&"lifeChalice",&"firstStrikeRing",&"guardFeather",&"poisonDagger"]
const EPIC = [&"enchantedBlade",&"overchargeCore",&"chainRing",&"echoStaff",&"steelGreatsword",&"counterShield",&"executionScythe",&"rageHorn",&"piercingAwl",&"guardChain",&"weakEye",&"elementStone",&"swiftCloak"]
## 전설: one of each per run.
const LEGENDARY = [&"phoenixFeather",&"hourglass",&"dragonHeart",&"sovereignSword",&"giantHeart",&"sanctuaryLamp",&"stormCrown",&"infinityEdge",&"skyBowstring",&"eternalArmor",&"oblivionVeil",&"elderHeart",&"lifeResonance",&"warDrum",&"bloodChalice",&"frostCrown"]
## 고대: custom battles only for now (no tower source).
const ANCIENT = [&"twinMirror",&"mangoSeed",&"cursedCrown",&"rewindClock",&"invertedHourglass",&"greedPouch",&"overdriveEngine",&"gamblerDice",&"commanderScepter",&"mimicMask",&"soulReaper",&"starShard",&"shadowDoll"]
## 0.96: items that were replaced, and what a save gets instead.
const REPLACED = {&"salvationFeather":&"guardFeather",&"sporeMoss":&"poisonDagger",&"hexRing":&"piercingAwl",&"oathChain":&"guardChain",&"markBadge":&"weakEye",&"windTrail":&"swiftCloak",&"regenCore":&"lifeResonance",&"emptyFrame":&"commanderScepter",&"twoFacedMask":&"mimicMask",&"voidHeart":&"soulReaper",&"magnetCompass":&"starShard"}
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
const NEW_COMMON_DEFS = {
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
}
## kind -> [name, stat lines and effect]. Items with "effect" run in ItemEffects; the old ability
## flags (totems, fang, awl, gold, phoenix, hourglass, dragon heart...) stay as they were.
const RARE_DEFS = {
	&"warmNecklace+verdantStone":["원기 토템",{"max_hp_multiplier":1.1,"vigor_totem":true,"ability_power":1.35}],
	&"currentOrb+ether":["충전 토템",{"ultimate_bonus":.1,"charge_totem":true,"ability_power":1.25}],
	&"woodSword+redThorn":["포식자의 엄니",{"physical_bonus":.1,"kill_growth":true,"ability_power":1.34}],
	&"woodSword+hawkFeather":["굵은 송곳",{"attack_speed_bonus":.08,"opening_awl":true,"ability_power":1.25}],
	&"leatherArmor+hawkFeather":["황금 토큰",{"max_hp_multiplier":1.1,"victory_gold":55}],
	&"duelistGlove":["결투가의 장갑",{"attack_speed_bonus":.1,"duelist":true}],
	&"vanguardShield":["선봉의 방패",{"armor_bonus":12.0,"vanguard":true}],
	&"elementTome":["원소술사의 서",{"element_bonus":.15,"elementalist":true}],
	&"berserkerHelm":["광전사의 투구",{"physical_bonus":.1,"effect":&"berserkerHelm"}],
	&"sniperScope":["저격수의 조준경",{"range_multiplier":1.1,"effect":&"sniperScope"}],
	&"vampireFang":["흡혈 송곳니",{"physical_bonus":.1,"effect":&"vampireFang"}],
	&"hunterShuriken":["사냥꾼의 표창",{"crit_bonus":.08,"effect":&"hunterShuriken"}],
	&"thornArmor":["가시 갑옷",{"armor_bonus":15.0,"effect":&"thornArmor"}],
	&"bleedBlade":["출혈의 칼날",{"crit_bonus":.08,"effect":&"bleedBlade"}],
	&"lifeChalice":["생명의 성배",{"heal_power_bonus":.15,"effect":&"lifeChalice"}],
	&"firstStrikeRing":["첫 일격의 반지",{"crit_damage_bonus":.2,"effect":&"firstStrikeRing"}],
	&"guardFeather":["수호의 깃털",{"max_hp_multiplier":1.1,"effect":&"guardFeather"}],
	&"poisonDagger":["독 바른 단검",{"attack_speed_bonus":.08,"effect":&"poisonDagger"}],
}
const EPIC_DEFS = {
	&"enchantedBlade":["마법 부여 검",{"physical_bonus":.15,"element_bonus":.15,"enchant":true}],
	&"overchargeCore":["과충전 코어",{"ultimate_bonus":.2,"overcharge":true}],
	&"chainRing":["연쇄의 고리",{"attack_speed_bonus":.12,"chain_ring":true}],
	&"echoStaff":["메아리 지팡이",{"magic_bonus":.18,"effect":&"echoStaff"}],
	&"steelGreatsword":["강철 대검",{"physical_bonus":.18,"effect":&"steelGreatsword"}],
	&"counterShield":["반격의 방패",{"armor_bonus":15.0,"crit_damage_bonus":.2,"effect":&"counterShield"}],
	&"executionScythe":["처형의 낫",{"crit_bonus":.12,"effect":&"executionScythe"}],
	&"rageHorn":["광폭의 뿔",{"physical_bonus":.15,"effect":&"rageHorn"}],
	&"piercingAwl":["관통의 송곳",{"physical_bonus":.15,"effect":&"piercingAwl"}],
	&"guardChain":["수호의 사슬",{"armor_bonus":20.0,"max_hp_multiplier":1.1,"effect":&"guardChain"}],
	&"weakEye":["약점 간파의 눈",{"crit_bonus":.1,"effect":&"weakEye"}],
	&"elementStone":["원소 폭발석",{"element_bonus":.2,"effect":&"elementStone"}],
	&"swiftCloak":["신속의 망토",{"speed_multiplier":1.12,"attack_speed_bonus":.12,"effect":&"swiftCloak"}],
}
const LEGENDARY_DEFS = {
	&"phoenixFeather":["불사조의 깃털",{"max_hp_multiplier":1.15,"phoenix":true}],
	&"hourglass":["시간의 모래시계",{"ultimate_bonus":.25,"hourglass":true}],
	&"dragonHeart":["용의 심장",{"max_hp_multiplier":1.15,"armor_bonus":10.0,"dragon_heart":true}],
	&"sovereignSword":["군주의 검",{"physical_bonus":.25,"magic_bonus":.25,"sovereign":true}],
	&"giantHeart":["거인의 심장",{"max_hp_multiplier":1+ItemTuning.GIANT_HP,"scale_multiplier":ItemTuning.GIANT_SCALE,"immovable":true}],
	&"sanctuaryLamp":["성역의 등불",{"max_hp_multiplier":1.15,"armor_bonus":10.0,"sanctuary":true}],
	&"stormCrown":["폭풍의 왕관",{"magic_bonus":.2,"ultimate_bonus":.15,"effect":&"stormCrown"}],
	&"infinityEdge":["무한의 칼날",{"physical_bonus":.15,"crit_bonus":ItemTuning.INFINITY_CRIT,"crit_damage_bonus":ItemTuning.INFINITY_CRIT_DAMAGE,"effect":&"infinityEdge"}],
	&"skyBowstring":["천공의 활시위",{"attack_speed_bonus":.15,"tag_bonuses":{&"projectile":.2},"effect":&"skyBowstring"}],
	&"eternalArmor":["영겁의 갑주",{"max_hp_multiplier":1.15,"armor_bonus":25.0,"effect":&"eternalArmor"}],
	&"oblivionVeil":["암살자의 장막",{"physical_bonus":.15,"crit_bonus":.15,"effect":&"oblivionVeil"}],
	&"elderHeart":["거목의 심장",{"max_hp_multiplier":1.25,"effect":&"elderHeart"}],
	&"lifeResonance":["생명의 공명",{"max_hp_multiplier":1.15,"ultimate_bonus":.15,"effect":&"lifeResonance"}],
	&"warDrum":["전쟁의 북",{"attack_speed_bonus":.15,"effect":&"warDrum"}],
	&"bloodChalice":["피의 성배",{"max_hp_multiplier":1.15,"effect":&"bloodChalice"}],
	&"frostCrown":["원소 왕관",{"magic_bonus":.15,"element_bonus":.3,"effect":&"frostCrown"}],
}
const ANCIENT_DEFS = {
	&"twinMirror":["쌍둥이의 거울",{"all_stats":ItemTuning.ALL_STATS_SMALL,"effect":&"twinMirror"}],
	&"mangoSeed":["황금 망고",{"max_hp_multiplier":1.2,"effect":&"mangoSeed"}],
	&"cursedCrown":["왕의 왕관",{"all_stats":ItemTuning.CROWN_STATS,"effect":&"cursedCrown"}],
	&"rewindClock":["시간술사의 시계",{"attack_speed_bonus":.15,"ultimate_bonus":.2,"effect":&"rewindClock"}],
	&"invertedHourglass":["끝없는 모래시계",{"ultimate_bonus":.3,"effect":&"invertedHourglass"}],
	&"greedPouch":["탐욕의 황금손",{"physical_bonus":.15,"magic_bonus":.15,"effect":&"greedPouch"}],
	&"overdriveEngine":["폭주 기관",{"attack_speed_bonus":.15,"effect":&"overdriveEngine"}],
	&"gamblerDice":["행운의 주사위",{"all_stats":ItemTuning.ALL_STATS_SMALL,"effect":&"gamblerDice"}],
	&"commanderScepter":["지휘관의 홀",{"max_hp_multiplier":1.15,"armor_bonus":10.0,"effect":&"commanderScepter"}],
	&"mimicMask":["흉내쟁이의 가면",{"physical_bonus":.2,"magic_bonus":.2,"effect":&"mimicMask"}],
	&"soulReaper":["영혼 수확자",{"max_hp_multiplier":1.15,"physical_bonus":.15,"magic_bonus":.15,"effect":&"soulReaper"}],
	&"starShard":["별의 파편",{"magic_bonus":.25,"element_bonus":.2,"effect":&"starShard"}],
	&"shadowDoll":["저주 인형",{"max_hp_multiplier":1.2,"armor_bonus":15.0,"effect":&"shadowDoll"}],
}
const BONUS_FIELDS = ["physical_bonus","magic_bonus","element_bonus","ultimate_bonus","armor_bonus","attack_speed_bonus","crit_bonus","physical_defense_bonus","magic_defense_bonus","crit_damage_bonus","heal_power_bonus","all_stats"]
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
			else:_definitions[kind]=_make(kind,NEW_COMMON_DEFS[kind][0],&"common",NEW_COMMON_DEFS[kind][1],ItemTuning.NEW_COMMON_PRICES[kind])
		for pair in [[RARE_DEFS,&"rare"],[EPIC_DEFS,&"epic"],[LEGENDARY_DEFS,&"legendary"],[ANCIENT_DEFS,&"ancient"]]:
			for kind in pair[0]:_definitions[kind]=_make(kind,pair[0][kind][0],pair[1],pair[0][kind][1],ItemTuning.GRADE_PRICES[pair[1]])
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
		var tags: Dictionary={}
		for tag in base.tag_bonuses:tags[tag]=float(base.tag_bonuses[tag])*boost
		item.tag_bonuses=tags
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

## Stat lines, then the effect in one sentence, generated from the numbers so text and rules never
## drift apart.
static func describe(item: ItemData) -> String:
	var lines: Array[String]=[]
	var pct:=func(v: float) -> String:return "+%s%%"%_num(v*100)
	if item.all_stats>0:lines.append("모든 스탯 "+pct.call(item.all_stats))
	if item.max_hp_multiplier>1:lines.append("최대 HP "+pct.call(item.max_hp_multiplier-1))
	if item.physical_bonus>0 and is_equal_approx(item.physical_bonus,item.magic_bonus):lines.append("물리·마법 피해 "+pct.call(item.physical_bonus))
	else:
		if item.physical_bonus>0:lines.append("물리 피해 "+pct.call(item.physical_bonus))
		if item.magic_bonus>0:lines.append("마법 피해 "+pct.call(item.magic_bonus))
	if item.element_bonus>0:lines.append("속성 피해 "+pct.call(item.element_bonus))
	if item.attack_multiplier>1:lines.append("공격력 "+pct.call(item.attack_multiplier-1))
	if item.armor_bonus>0:lines.append("방어력 +%s"%_num(item.armor_bonus))
	if item.physical_defense_bonus>0:lines.append("물리 방어력 +%s"%_num(item.physical_defense_bonus))
	if item.magic_defense_bonus>0:lines.append("마법 방어력 +%s"%_num(item.magic_defense_bonus))
	if item.speed_multiplier>1:lines.append("이동속도 "+pct.call(item.speed_multiplier-1))
	elif item.speed_multiplier<1:lines.append("이동속도 -%s%%"%_num((1-item.speed_multiplier)*100))
	if item.attack_speed_bonus>0:lines.append("공격속도 "+pct.call(item.attack_speed_bonus))
	if item.range_multiplier>1:lines.append("사거리 "+pct.call(item.range_multiplier-1))
	if item.crit_bonus>0:lines.append("치명타 확률 +%s%%p"%_num(item.crit_bonus*100))
	if item.crit_damage_bonus>0:lines.append("치명타 피해량 "+pct.call(item.crit_damage_bonus))
	if item.ultimate_bonus>0:lines.append("궁극기 충전 "+pct.call(item.ultimate_bonus))
	if item.ult_damage_bonus>0:lines.append("궁극기 피해량 "+pct.call(item.ult_damage_bonus))
	if item.healing_multiplier>1:lines.append("주는 · 받는 치유 "+pct.call(item.healing_multiplier-1))
	if item.heal_power_bonus>0:lines.append("주는 치유 "+pct.call(item.heal_power_bonus))
	for tag in item.tag_bonuses:lines.append("%s 피해 %s"%[UnitStatTable.TAG_NAMES.get(tag,String(tag)),pct.call(float(item.tag_bonuses[tag]))])
	if item.kind==&"prismShard" and item.element_choice==&"":lines.append("얻을 때 7속성 중 하나가 정해지고 그 속성 피해 "+pct.call(ItemTuning.PRISM_BONUS))
	# Effects (one sentence each).
	if item.vigor_totem:lines.append("5초마다 주변 아군 HP %d 회복"%roundi(6*item.ability_power))
	if item.charge_totem:lines.append("4초마다 주변 아군 궁극기 +%d%%"%roundi(4*item.ability_power))
	if item.kill_growth:lines.append("처치할 때마다 공격력 +%s%% (런 동안 유지)"%_num(1.5*item.ability_power))
	if item.opening_awl:lines.append("전투 시작 시 송곳을 던져 맞은 적 %s초 기절"%_num(4*item.ability_power))
	if item.victory_gold>0:lines.append("살아서 이기면 %d G"%item.victory_gold)
	if item.duelist:lines.append("같은 적을 계속 때릴수록 피해 +%s%% (최대 +%s%%)"%[_num(ItemTuning.DUELIST_STEP*100),_num(ItemTuning.DUELIST_MAX*100)])
	if item.vanguard:lines.append("전투 시작 후 %d초간 받는 피해 -%s%%"%[int(ItemTuning.VANGUARD_TIME),_num((1-ItemTuning.VANGUARD_TAKEN)*100)])
	if item.elementalist:lines.append("화상·맹독·빙결·감전·침식 중인 적에게 피해 +%s%%"%_num((ItemTuning.ELEMENTALIST_DEALT-1)*100))
	if item.enchant:lines.append("기본공격에 장착자의 속성이 붙음(속성이 없으면 화염)")
	if item.overcharge:lines.append("궁극기를 쓴 직후 게이지 %d%% 회복"%int(ItemTuning.OVERCHARGE_REFUND))
	if item.chain_ring:lines.append("기본공격 %d번째마다 가까운 다른 적도 같은 피해를 받음"%ItemTuning.CHAIN_EVERY)
	if item.sovereign:lines.append("처치할 때마다 주변 아군 공격력 +%s%% (%d초, 최대 %d번 겹침)"%[_num(ItemTuning.SOVEREIGN_BUFF*100),int(ItemTuning.SOVEREIGN_TIME),ItemTuning.SOVEREIGN_STACKS])
	if item.immovable:lines.append("몸집이 커지고 넉백·끌림에 면역")
	if item.sanctuary:lines.append("주변 아군(자신 포함)이 받는 피해 -%s%%"%_num((1-ItemTuning.SANCTUARY_TAKEN)*100))
	if item.phoenix:lines.append("전투당 1회, 쓰러지면 HP 40%로 부활하고 2초 무적")
	if item.hourglass:lines.append("궁극기를 쓴 직후 게이지 35% 회복")
	if item.dragon_heart:lines.append("4초마다 주변 적에게 화염 피해")
	if item.effect!=&"":lines.append(effect_text(item.effect))
	return " · ".join(lines)
## The special effect of a 0.95/0.96 item in one sentence, from the numbers in ItemTuning.
static func effect_text(effect: StringName) -> String:
	var p:=func(v: float) -> String:return _num(v*100)+"%"
	match effect:
		&"berserkerHelm":return "HP %s 이하일 때 공격속도 +%s"%[p.call(ItemTuning.BERSERK_HP),p.call(ItemTuning.BERSERK_ATTACK_SPEED)]
		&"sniperScope":return "멀리 있는 적(%d 이상)에게 피해 +%s"%[int(ItemTuning.SCOPE_DISTANCE),p.call(ItemTuning.SCOPE_DEALT)]
		&"vampireFang":return "준 피해의 %s만큼 회복"%p.call(ItemTuning.VAMPIRE_LEECH)
		&"hunterShuriken":return "처치하면 %d초간 공격속도 +%s"%[int(ItemTuning.HUNTER_TIME),p.call(ItemTuning.HUNTER_ATTACK_SPEED)]
		&"thornArmor":return "근접 공격을 받으면 피해의 %s를 되돌려 줌"%p.call(ItemTuning.THORN_REFLECT)
		&"bleedBlade":return "치명타를 맞은 적은 %d초간 출혈(그 피해의 %s 추가)"%[int(ItemTuning.BLEED_TIME),p.call(ItemTuning.BLEED_SHARE)]
		&"lifeChalice":return "넘치는 치유는 대상의 보호막이 됨(최대 HP %s까지)"%p.call(ItemTuning.CHALICE_SHIELD_CAP)
		&"firstStrikeRing":return "%d초마다 다음 기본공격 피해 +%s"%[int(ItemTuning.FIRST_STRIKE_EVERY),p.call(ItemTuning.FIRST_STRIKE)]
		&"guardFeather":return "HP가 %s 아래로 떨어지면 보호막(최대 HP %s), 전투당 1회"%[p.call(ItemTuning.GUARD_FEATHER_HP),p.call(ItemTuning.GUARD_FEATHER_SHIELD)]
		&"poisonDagger":return "기본공격 시 %s 확률로 맹독 1스택"%p.call(ItemTuning.POISON_DAGGER_CHANCE)
		&"echoStaff":return "마법 공격 시 %s 확률로 절반 피해가 한 번 더"%p.call(ItemTuning.ECHO_CHANCE)
		&"steelGreatsword":return "기본공격 %d번째마다 %s 강타 + 넉백"%[ItemTuning.GREATSWORD_EVERY,p.call(ItemTuning.GREATSWORD_DEALT)]
		&"counterShield":return "패링·회피에 성공하면 다음 공격이 반드시 치명타"
		&"executionScythe":return "HP %s 이하인 적을 공격하면 즉시 처치. 엘리트·보스에게는 대신 피해 +%s"%[p.call(ItemTuning.SCYTHE_HP),p.call(ItemTuning.SCYTHE_ELITE)]
		&"rageHorn":return "처치하면 HP %s 회복. 저돌적 성향이면 받는 피해 증가가 사라짐"%p.call(ItemTuning.HORN_HEAL)
		&"piercingAwl":return "장착자의 공격은 적 방어의 %s를 무시"%p.call(ItemTuning.PIERCE_DEFENSE)
		&"guardChain":return "가장 가까운 아군이 받는 피해의 %s를 대신 받고, 그 피해는 절반으로 줄어듦"%p.call(ItemTuning.GUARD_CHAIN_SHARE)
		&"weakEye":return "장착자가 공격한 적은 %d초간 받는 피해 +%s (아군 전체가 이득)"%[int(ItemTuning.WEAK_TIME),p.call(ItemTuning.WEAK_TAKEN-1)]
		&"elementStone":return "화상·맹독·빙결·감전 중인 적을 처치하면 폭발해 주변 적에게 피해 + 같은 속성 %d스택"%ItemTuning.STONE_STACKS
		&"swiftCloak":return "받는 투사체 피해 -%s"%p.call(1-ItemTuning.SWIFT_PROJECTILE_TAKEN)
		&"stormCrown":return "궁극기를 쓸 때마다 주변 모든 적에게 낙뢰 + 감전 %d스택"%ItemTuning.STORM_SHOCK
		&"infinityEdge":return "치명타는 적 방어의 %s를 무시"%p.call(ItemTuning.PIERCE_DEFENSE)
		&"skyBowstring":return "투사체가 적을 %d명까지 꿰뚫고, 꿰뚫을 때마다 피해 +%s"%[ItemTuning.BOWSTRING_PIERCE,p.call(ItemTuning.BOWSTRING_STEP)]
		&"eternalArmor":return "한 번에 최대 HP의 %s 넘는 피해를 받지 않음"%p.call(ItemTuning.ETERNAL_CAP)
		&"oblivionVeil":return "전투 시작 시와 처치할 때마다 %d초 은신, 은신 중 공격은 피해 %d배"%[int(ItemTuning.VEIL_TIME),int(ItemTuning.VEIL_STRIKE)]
		&"elderHeart":return "매초 최대 HP의 %s%% 회복"%_num(ItemTuning.ELDER_REGEN*100)
		&"lifeResonance":return "궁극기를 쓰면 자신과 주변 아군 HP %s 회복 + %d초간 받는 피해 -%s"%[p.call(ItemTuning.RESONANCE_HEAL),int(ItemTuning.REGEN_TIME),p.call(1-ItemTuning.REGEN_TAKEN)]
		&"warDrum":return "출정한 아군 전원 공격속도 +%s, 전투 시작 후 %d초간은 +%s"%[p.call(ItemTuning.DRUM_SPEED),int(ItemTuning.DRUM_OPENING_TIME),p.call(ItemTuning.DRUM_OPENING)]
		&"bloodChalice":return "아군 전원이 준 피해의 %s만큼 회복(장착자는 %s)"%[p.call(ItemTuning.BLOOD_LEECH),p.call(ItemTuning.BLOOD_LEECH_SELF)]
		&"frostCrown":return "장착자의 속성 스택은 확률 없이 항상 걸리고 %d스택 더 붙음"%ItemTuning.ELEMENT_CROWN_EXTRA
		&"twinMirror":return "전투 시작 시 분신이 함께 싸움(HP·피해 %s). 분신이 쓰러져도 손실 없음"%p.call(ItemTuning.MIRROR_HP)
		&"mangoSeed":return "전투 시작 시 아군 전원 보호막(최대 HP %s), %d초마다 아군 전원 HP %s 회복"%[p.call(ItemTuning.MANGO_SHIELD),int(ItemTuning.MANGO_EVERY),p.call(ItemTuning.MANGO_HEAL)]
		&"cursedCrown":return "장착자가 살아 있는 동안 아군 전원 모든 스탯 +%s"%p.call(ItemTuning.KING_AURA)
		&"rewindClock":return "쓰러질 피해를 받으면 %d초 전의 HP와 위치로 되돌아감(전투당 1회)"%int(ItemTuning.REWIND_BACK)
		&"invertedHourglass":return "터닝포인트마다 궁극기가 가득 참"
		&"greedPouch":return "처치할 때마다 %d G. 가진 골드 %d당 공격력 +%s (최대 +%s)"%[ItemTuning.GREED_KILL_GOLD,ItemTuning.GREED_PER,p.call(ItemTuning.GREED_STEP),p.call(ItemTuning.GREED_MAX)]
		&"overdriveEngine":return "전투 중 매초 공격속도 +%s (최대 +%s)"%[p.call(ItemTuning.OVERDRIVE_STEP),p.call(ItemTuning.OVERDRIVE_MAX)]
		&"gamblerDice":return "전투가 시작될 때마다 주사위를 굴려 스탯 하나가 +%s~%s"%[_num(ItemTuning.DICE_MIN*100),p.call(ItemTuning.DICE_MAX)]
		&"commanderScepter":return "장착자는 출정 인원에 세지 않음(한 명 더 출정)"
		&"mimicMask":return "궁극기를 쓰면 같은 궁극기가 절반 위력으로 한 번 더 나감"
		&"soulReaper":return "전장에서 누군가 쓰러질 때마다 HP %s 회복, 최대 HP와 공격력 +%s (전투 동안)"%[p.call(ItemTuning.SOUL_HEAL),p.call(ItemTuning.SOUL_GROW)]
		&"starShard":return "%d초마다 무작위 적 %d명에게 유성이 떨어져 범위 피해"%[int(ItemTuning.STAR_EVERY),ItemTuning.STAR_TARGETS]
		&"shadowDoll":return "받는 모든 피해의 %s를 공격한 적에게 되돌려 줌"%p.call(ItemTuning.DOLL_REFLECT)
	return ""
## 15 -> "15", 12.5 -> "12.5".
static func _num(v: float) -> String:
	return str(roundi(v)) if absf(v-roundf(v))<.05 else String.num(v,1)
