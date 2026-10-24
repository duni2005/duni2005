class_name ItemCatalog
extends RefCounted
## Basic (common) items combine in pairs into rare items; ancient items are special finds.
## Legacy items stay loadable for old saves but are no longer handed out.
const LEGACY = [&"vital",&"fang",&"boots",&"reengrave",&"greenNecklace",&"goldToken",&"vigorTotem",&"chargeTotem",&"predatorFang",&"thickAwl"]
const BASIC = [&"warmNecklace",&"woodSword",&"currentOrb",&"ether",&"leatherArmor",&"hawkFeather",&"staff",&"verdantStone",&"redThorn"]
const ANCIENT = [&"phoenixFeather",&"hourglass",&"dragonHeart"]
## Shop / treasure / lottery / floor bonus pool: the nine basics plus the reengrave consumable.
const KINDS = [&"warmNecklace",&"woodSword",&"currentOrb",&"ether",&"leatherArmor",&"hawkFeather",&"staff",&"verdantStone",&"redThorn",&"reengrave"]
## A combined item gets both components' bonuses, each this much stronger.
const COMBINE_FACTOR: float = 1.25
const GRADE_NAMES = {&"common":"일반",&"rare":"희귀",&"ancient":"고대",&"legacy":"구형"}
const GRADE_COLORS = {&"common":Color("c9d0e6"),&"rare":Color("6fb6ff"),&"ancient":Color("ffb347"),&"legacy":Color("b48cf0")}
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
}
const RARE_NAMES = {
	"warmNecklace+warmNecklace":"성스러운 성배","woodSword+woodSword":"강철 대검","currentOrb+currentOrb":"뇌운 코어","ether+ether":"순수 원소석","leatherArmor+leatherArmor":"강철 흉갑","hawkFeather+hawkFeather":"질풍의 날개","staff+staff":"대마법사의 지팡이","verdantStone+verdantStone":"거목의 심장","redThorn+redThorn":"핏빛 장미",
	"warmNecklace+woodSword":"성기사의 검","warmNecklace+currentOrb":"생명 전류석","warmNecklace+ether":"치유의 정수","warmNecklace+leatherArmor":"수도사의 법의","warmNecklace+hawkFeather":"순례자의 깃","warmNecklace+staff":"치유사의 홀","warmNecklace+verdantStone":"원기 토템","warmNecklace+redThorn":"가시 덩굴 목걸이",
	"woodSword+currentOrb":"번개 칼날","woodSword+ether":"원소 검","woodSword+leatherArmor":"기사의 방패검","woodSword+hawkFeather":"굵은 송곳","woodSword+staff":"마검","woodSword+verdantStone":"거인의 곤봉","woodSword+redThorn":"포식자의 엄니",
	"currentOrb+ether":"충전 토템","currentOrb+leatherArmor":"축전 갑주","currentOrb+hawkFeather":"폭풍 깃털","currentOrb+staff":"뇌전의 홀","currentOrb+verdantStone":"생명 축전지","currentOrb+redThorn":"번개 가시",
	"ether+leatherArmor":"원소 결계 갑옷","ether+hawkFeather":"정령의 깃","ether+staff":"원소술사의 지팡이","ether+verdantStone":"대지 정수","ether+redThorn":"화염 가시",
	"leatherArmor+hawkFeather":"황금 토큰","leatherArmor+staff":"마법 방어구","leatherArmor+verdantStone":"거북 등껍질","leatherArmor+redThorn":"가시 갑옷",
	"hawkFeather+staff":"바람의 지팡이","hawkFeather+verdantStone":"숲의 날개","hawkFeather+redThorn":"사냥꾼의 깃",
	"staff+verdantStone":"생명의 홀","staff+redThorn":"저주받은 지팡이",
	"verdantStone+redThorn":"붉은 신록석",
}
## Former special items, a little stronger, now living on combined items.
const RARE_ABILITIES = {
	"warmNecklace+verdantStone":{"vigor_totem":true,"ability_power":1.35},
	"currentOrb+ether":{"charge_totem":true,"ability_power":1.25},
	"woodSword+redThorn":{"kill_growth":true,"ability_power":1.34},
	"woodSword+hawkFeather":{"opening_awl":true,"ability_power":1.25},
	"leatherArmor+hawkFeather":{"victory_gold":55},
}
const ANCIENT_DEFS = {
	&"phoenixFeather":["불사조의 깃털",{"max_hp_multiplier":1.1,"phoenix":true}],
	&"hourglass":["시간의 모래시계",{"ultimate_bonus":.25,"hourglass":true}],
	&"dragonHeart":["용의 심장",{"max_hp_multiplier":1.15,"dragon_heart":true}],
}
const BONUS_FIELDS = ["physical_bonus","magic_bonus","element_bonus","ultimate_bonus","armor_bonus","attack_speed_bonus","crit_bonus"]
const MULTIPLIER_FIELDS = ["max_hp_multiplier","attack_multiplier","speed_multiplier","healing_multiplier"]
static var _definitions: Dictionary = {}

static func all() -> Dictionary:
	if _definitions.is_empty():
		for kind in LEGACY:_definitions[kind]=load("res://data/items/%s.tres"%kind)
		for kind in BASIC:_definitions[kind]=_make(kind,BASIC_DEFS[kind][0],&"common",BASIC_DEFS[kind][1],90)
		for i in range(BASIC.size()):
			for j in range(i,BASIC.size()):
				var kind: StringName=combined_kind(BASIC[i],BASIC[j]);var fields: Dictionary=RARE_ABILITIES.get(String(kind),{}).duplicate()
				var a: Dictionary=BASIC_DEFS[BASIC[i]][1];var b: Dictionary=BASIC_DEFS[BASIC[j]][1]
				for field in BONUS_FIELDS:
					if a.has(field) or b.has(field):fields[field]=(float(a.get(field,0))+float(b.get(field,0)))*COMBINE_FACTOR
				for field in MULTIPLIER_FIELDS:
					if a.has(field) or b.has(field):fields[field]=1+(float(a.get(field,1))-1+float(b.get(field,1))-1)*COMBINE_FACTOR
				var item: ItemData=_make(kind,RARE_NAMES[String(kind)],&"rare",fields,240);item.components.assign([BASIC[i],BASIC[j]])
				_definitions[kind]=item
		for kind in ANCIENT:_definitions[kind]=_make(kind,ANCIENT_DEFS[kind][0],&"ancient",ANCIENT_DEFS[kind][1],600)
	return _definitions.duplicate()
static func get_item(kind: StringName) -> ItemData:return all().get(kind)

## Canonical kind of the item made from two basics, in BASIC order ("woodSword+staff").
static func combined_kind(a: StringName,b: StringName) -> StringName:
	return StringName("%s+%s"%([a,b] if BASIC.find(a)<=BASIC.find(b) else [b,a]))
static func grade_name(kind: StringName) -> String:
	var item: ItemData=get_item(kind);return GRADE_NAMES.get(item.grade,"") if item!=null else ""
static func grade_color(kind: StringName) -> Color:
	var item: ItemData=get_item(kind);return GRADE_COLORS.get(item.grade,Color.WHITE) if item!=null else Color.WHITE

static func _make(kind: StringName,title: String,grade: StringName,fields: Dictionary,price: int) -> ItemData:
	var item:=ItemData.new();item.kind=kind;item.display_name=title;item.grade=grade;item.gold_price=price
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
	if item.max_hp_multiplier>1:lines.append("최대 HP "+pct.call(item.max_hp_multiplier-1))
	if item.armor_bonus>0:lines.append("방어력 +%s"%_num(item.armor_bonus))
	if item.attack_speed_bonus>0:lines.append("공격속도 "+pct.call(item.attack_speed_bonus))
	if item.speed_multiplier>1:lines.append("이동속도 "+pct.call(item.speed_multiplier-1))
	if item.crit_bonus>0:lines.append("치명타 확률 +%s%%p"%_num(item.crit_bonus*100))
	if item.ultimate_bonus>0:lines.append("궁극기 충전 "+pct.call(item.ultimate_bonus))
	if item.healing_multiplier>1:lines.append("주는 · 받는 치유 "+pct.call(item.healing_multiplier-1))
	if item.vigor_totem:lines.append("5초마다 주변 아군 HP %d 회복"%roundi(6*item.ability_power))
	if item.charge_totem:lines.append("4초마다 주변 아군 궁극기 +%d%%"%roundi(4*item.ability_power))
	if item.kill_growth:lines.append("처치마다 공격력 영구 +%s%%"%String.num(1.5*item.ability_power,1))
	if item.opening_awl:lines.append("전투 시작 시 송곳 투척 · 적중한 적 %s초 기절"%String.num(4*item.ability_power,1))
	if item.victory_gold>0:lines.append("생존 승리 시 %d G"%item.victory_gold)
	if item.phoenix:lines.append("전투당 1회, 쓰러지면 HP 40%로 부활 · 2초 무적")
	if item.hourglass:lines.append("궁극기 사용 직후 게이지 35% 회복")
	if item.dragon_heart:lines.append("4초마다 주변 적에게 공격력 60% 화염 피해")
	return " · ".join(lines)
## 15 -> "15", 12.5 -> "12.5".
static func _num(v: float) -> String:
	return str(roundi(v)) if absf(v-roundf(v))<.05 else String.num(v,1)
