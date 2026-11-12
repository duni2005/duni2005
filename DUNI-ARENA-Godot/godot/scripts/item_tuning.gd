class_name ItemTuning
extends RefCounted
## Every item probability, price and number in one place. ItemCatalog builds the items from
## these, ItemRewards rolls them, ItemEffects runs them in battle.

# ---- Grades ----
## Grade order, lowest first. legacy = old saves only, never handed out.
const GRADES: Array[StringName] = [&"common", &"rare", &"epic", &"legendary", &"ancient"]
const GRADE_NAMES = {&"common":"일반", &"rare":"희귀", &"epic":"영웅", &"legendary":"전설", &"ancient":"고대", &"legacy":"구형"}
const GRADE_COLORS = {&"common":Color("aab4c8"), &"rare":Color("5fb0ff"), &"epic":Color("b884ff"), &"legendary":Color("ffc34a"), &"ancient":Color("ff4f6d"), &"legacy":Color("8a8fa8")}
## Card frame per grade, like the unit rarity frame: border alpha, wash alpha, a thick border
## from 영웅 up, and a light running round the border (gold for 전설, crimson for 고대).
const FRAME = {
	&"common":{"border":.55, "wash":.05, "thick":false, "glint":Color(0, 0, 0, 0)},
	&"rare":{"border":.7, "wash":.09, "thick":false, "glint":Color(0, 0, 0, 0)},
	&"epic":{"border":.85, "wash":.13, "thick":true, "glint":Color(0, 0, 0, 0)},
	&"legendary":{"border":.95, "wash":.16, "thick":true, "glint":Color(1, .92, .6)},
	&"ancient":{"border":.95, "wash":.17, "thick":true, "glint":Color(1, .55, .6)},
	&"legacy":{"border":.4, "wash":0.0, "thick":false, "glint":Color(0, 0, 0, 0)},
}

# ---- Prices (shop) and selling ----
## 일반 keeps its own price (BASIC_PRICES / NEW_COMMON); higher grades share one price.
const GRADE_PRICES = {&"rare":300, &"epic":550, &"legendary":900, &"ancient":1500}
const BASIC_PRICES = {&"leatherArmor":120, &"verdantStone":120, &"warmNecklace":120, &"woodSword":130, &"staff":130, &"ether":140, &"redThorn":140, &"currentOrb":160, &"hawkFeather":160, &"magicCloak":120, &"sturdyShield":120, &"scopeLens":150}
## Blacksmith 판매: unequipped 일반 · 희귀 items, this share of the shop price.
const SELL_GRADES: Array[StringName] = [&"common", &"rare"]
const SELL_RATE: float = .5

# ---- Blacksmith 강화 ----
const ENHANCE_GRADES: Array[StringName] = [&"rare", &"epic", &"legendary"]
const ENHANCE_COSTS = [200, 330, 530, 800, 1200]
const ENHANCE_BOOST = [0.0, .1, .2, .3, .4, .6]
const MAX_ENHANCE: int = 5

# ---- Drop table by floor (1-based floors, inclusive) ----
## Grade odds (%) by tower progress; a grade is rolled first, then an item of it, evenly.
const FLOOR_ODDS = [
	{"floors":[1, 3], "common":70, "rare":25, "epic":5, "legendary":0},
	{"floors":[4, 6], "common":55, "rare":32, "epic":11, "legendary":2},
	{"floors":[7, 9], "common":42, "rare":35, "epic":18, "legendary":5},
	{"floors":[10, 12], "common":32, "rare":36, "epic":24, "legendary":8},
	{"floors":[13, 15], "common":25, "rare":35, "epic":28, "legendary":12},
]
## Gambler's roulette "아이템" slot: its own odds, not by floor.
const ROULETTE_ODDS = {&"common":80, &"rare":17, &"epic":2, &"legendary":1}

# ---- Rewards ----
## Items offered after a win (pick one), and the lowest grade by room (higher-grade odds keep
## their ratio when lower grades are cut).
const REWARD_CHOICES: int = 3
const REWARD_MIN_GRADE = {&"battle":&"common", &"miniboss":&"rare", &"boss":&"epic"}
## 건너뛰기 pays this instead.
const SKIP_GOLD: int = 50
## Floor conquest "아이템" bonus: one item of at least this grade.
const CONQUEST_MIN_GRADE: StringName = &"epic"
## Shop shelf: this many items (inclusive range), rolled once per room.
const SHOP_ITEMS: Vector2i = Vector2i(3, 5)

# ---- Equipping ----
## 고대: at most this many on one unit.
const ANCIENT_PER_UNIT: int = 1
## Promotion moves the materials' gear onto the lead in this grade order (highest first).
const GEAR_PRIORITY = {&"ancient":5, &"legendary":4, &"epic":3, &"rare":2, &"common":1}

# ---- Item numbers ----
## Combined items before 0.94 got both components' bonuses this much stronger; the five rare
## items with abilities keep those numbers.
const OLD_COMBINE_FACTOR: float = 1.25
## New 일반.
const MAGIC_CLOAK_DEFENSE: float = 20
const STURDY_SHIELD_DEFENSE: float = 20
const SCOPE_RANGE: float = .1
## 결투가의 장갑: +5% per consecutive hit on the same target, up to +30%.
const DUELIST_STEP: float = .05
const DUELIST_MAX: float = .3
## 선봉의 방패: -30% damage taken for the first 10 s of a battle.
const VANGUARD_TIME: float = 10
const VANGUARD_TAKEN: float = .7
## 원소술사의 서: +20% damage to a target with burn, poison, frost, shock or erosion.
const ELEMENTALIST_DEALT: float = 1.2
## 마법 부여 검: basic hits gain the bearer's element (fire when it has none).
const ENCHANT_DEFAULT_ELEMENT: StringName = &"fire"
## 과충전 코어: gauge refund right after an ultimate.
const OVERCHARGE_REFUND: float = 25
## 연쇄의 고리: every Nth basic hit jumps once to the nearest other enemy within range.
const CHAIN_EVERY: int = 3
const CHAIN_RANGE: float = 200
## 군주의 검: attack +40%; each kill gives allies within the radius +10% attack (stacks, timer).
const SOVEREIGN_ATTACK: float = .4
const SOVEREIGN_RADIUS: float = 200
const SOVEREIGN_BUFF: float = .1
const SOVEREIGN_TIME: float = 8
const SOVEREIGN_STACKS: int = 3
## 거인의 심장.
const GIANT_HP: float = .4
const GIANT_SCALE: float = 1.2
const GIANT_SPEED: float = -.1
## 성역의 등불: allies (the bearer too) within the radius take -20%.
const SANCTUARY_RADIUS: float = 150
const SANCTUARY_TAKEN: float = .8
## 저주받은 왕관: every stat +50%; in the tower the bearer's max HP drops 5% for good after each battle.
const CROWN_STATS: float = .5
const CROWN_DECAY: float = .05
## 도박사의 주사위: one random stat +100%, another -30%, rolled each battle.
const DICE_UP: float = 1.0
const DICE_DOWN: float = -.3
const DICE_STATS: Array[String] = ["max_hp", "physical_damage", "magic_damage", "defense", "speed", "attack_speed"]
const DICE_STAT_NAMES = {"max_hp":"최대 HP", "physical_damage":"물리 피해", "magic_damage":"마법 피해", "defense":"방어력", "speed":"이동속도", "attack_speed":"공격속도"}
