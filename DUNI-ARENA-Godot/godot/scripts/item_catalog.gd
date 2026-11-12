class_name ItemCatalog
extends RefCounted
## Unique items by grade (ItemTuning.GRADES): 일반 · 희귀 · 영웅 · 전설 · 고대. Every item is won as a
## reward (or bought in a shop); nothing combines. Numbers live in ItemTuning.
## Legacy items stay loadable for old saves but are no longer handed out.
const LEGACY = [&"vital",&"fang",&"boots",&"reengrave",&"greenNecklace",&"goldToken",&"vigorTotem",&"chargeTotem",&"predatorFang",&"thickAwl"]
## 일반: the nine former basics plus three new ones; 재각인 is a 일반 consumable.
const COMMON = [&"warmNecklace",&"woodSword",&"currentOrb",&"ether",&"leatherArmor",&"hawkFeather",&"staff",&"verdantStone",&"redThorn",&"magicCloak",&"sturdyShield",&"scopeLens"]
## 희귀: the five former combined items with abilities (their old kind ids are kept so saves keep
## them) plus three new ones.
const RARE = [&"warmNecklace+verdantStone",&"currentOrb+ether",&"woodSword+redThorn",&"woodSword+hawkFeather",&"leatherArmor+hawkFeather",&"duelistGlove",&"vanguardShield",&"elementTome"]
const EPIC = [&"enchantedBlade",&"overchargeCore",&"chainRing"]
## 전설: the three former ancient items plus three new ones. One of each per run.
const LEGENDARY = [&"phoenixFeather",&"hourglass",&"dragonHeart",&"sovereignSword",&"giantHeart",&"sanctuaryLamp"]
## 고대: custom battles only for now (no tower source).
const ANCIENT = [&"twoFacedMask",&"cursedCrown",&"gamblerDice"]
## Items of each grade that rewards and shops may hand out (재각인 counts as 일반).
const POOLS = {&"common":[&"warmNecklace",&"woodSword",&"currentOrb",&"ether",&"leatherArmor",&"hawkFeather",&"staff",&"verdantStone",&"redThorn",&"magicCloak",&"sturdyShield",&"scopeLens",&"reengrave"],&"rare":RARE,&"epic":EPIC,&"legendary":LEGENDARY,&"ancient":ANCIENT}
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
		for kind in COMMON:_definitions[kind]=_make(kind,BASIC_DEFS[kind][0],&"common",BASIC_DEFS[kind][1],ItemTuning.BASIC_PRICES[kind])
		for kind in RARE:
			var fields: Dictionary=RARE_DEFS[kind][1].duplicate()
			var parts: Array=RARE_DEFS[kind][2]
			for part in parts:
				var stats: Dictionary=BASIC_DEFS[part][1]
				for field in stats:
					if field in BONUS_FIELDS:fields[field]=float(fields.get(field,0))+float(stats[field])*ItemTuning.OLD_COMBINE_FACTOR
					else:fields[field]=float(fields.get(field,1))+(float(stats[field])-1)*ItemTuning.OLD_COMBINE_FACTOR
			_definitions[kind]=_make(kind,RARE_DEFS[kind][0],&"rare",fields,ItemTuning.GRADE_PRICES[&"rare"])
		for kind in EPIC:_definitions[kind]=_make(kind,EPIC_DEFS[kind][0],&"epic",EPIC_DEFS[kind][1],ItemTuning.GRADE_PRICES[&"epic"])
		for kind in LEGENDARY:_definitions[kind]=_make(kind,LEGENDARY_DEFS[kind][0],&"legendary",LEGENDARY_DEFS[kind][1],ItemTuning.GRADE_PRICES[&"legendary"])
		for kind in ANCIENT:_definitions[kind]=_make(kind,ANCIENT_DEFS[kind][0],&"ancient",ANCIENT_DEFS[kind][1],ItemTuning.GRADE_PRICES[&"ancient"])
	return _definitions.duplicate()
static func get_item(kind: StringName) -> ItemData:return all().get(kind)
## Items that can be equipped or offered (no legacy), lowest grade first.
static func current() -> Array:
	var out: Array=[]
	for grade in ItemTuning.GRADES:out.append_array(POOLS[grade])
	return out
## The item as owned: an enhanced item at +N has every stat it raises boosted by ENHANCE_BOOST[N]
## (abilities stay as they are) and "+N" after its name.
static func of(instance: ItemInstance) -> ItemData:return enhanced(instance.kind,instance.enhance)
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
	return " · ".join(lines)
## 15 -> "15", 12.5 -> "12.5".
static func _num(v: float) -> String:
	return str(roundi(v)) if absf(v-roundf(v))<.05 else String.num(v,1)
