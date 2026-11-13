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
## 0.96 (아이템 재점검): every item of 희귀 and up has stat lines plus one effect, no penalties.
## Stat lines per item (ItemData fields) are in ItemCatalog; the effect numbers are here.
## 일반 (0.94).
const MAGIC_CLOAK_DEFENSE: float = 20
const STURDY_SHIELD_DEFENSE: float = 20
const SCOPE_RANGE: float = .1
## 일반 (0.95).
const NEW_COMMON_PRICES = {&"finisherCharm":150, &"quillHead":140, &"steelKnuckle":140, &"powderPouch":140, &"broadBlade":140, &"rustyNail":130, &"whetstone":150, &"ironHelm":130, &"windBoots":130, &"prismShard":150}
const FINISHER_ULT: float = .15
const QUILL_PROJECTILE: float = .15
const KNUCKLE_MELEE: float = .15
const POWDER_EXPLOSION: float = .2
const BROAD_AREA: float = .15
const NAIL_DOT: float = .2
const WHETSTONE_CRIT: float = .25
const IRON_HELM_HP: float = .08
const IRON_HELM_ARMOR: float = 6
const WIND_BOOTS_SPEED: float = .12
## 프리즘 조각: one of these elements, fixed when the item is won (seeded), +PRISM_BONUS to it.
const PRISM_ELEMENTS: Array[StringName] = [&"fire", &"ice", &"poison", &"lightning", &"wind", &"light", &"dark"]
const PRISM_BONUS: float = .3

## Item-icon pop over a unit's head when a special effect fires: life, and the gap before the
## same item may pop again on the same unit.
const PROC_ICON_TIME: float = .8
const PROC_ICON_GAP: float = 1.0

# ---- 희귀 ----
const DUELIST_STEP: float = .05
const DUELIST_MAX: float = .3
const VANGUARD_TIME: float = 10
const VANGUARD_TAKEN: float = .7
const ELEMENTALIST_DEALT: float = 1.2
const BERSERK_HP: float = .5
const BERSERK_ATTACK_SPEED: float = .35
const SCOPE_DISTANCE: float = 250
const SCOPE_DEALT: float = .2
const VAMPIRE_LEECH: float = .1
const HUNTER_TIME: float = 3
const HUNTER_ATTACK_SPEED: float = .5
const THORN_REFLECT: float = .25
const BLEED_TIME: float = 3
const BLEED_EVERY: float = .5
const BLEED_SHARE: float = .3
const CHALICE_SHIELD_CAP: float = .2
const CHALICE_SHIELD_TIME: float = 5
## 첫 일격의 반지: every FIRST_STRIKE_EVERY s the next basic attack +FIRST_STRIKE.
const FIRST_STRIKE: float = 1.0
const FIRST_STRIKE_EVERY: float = 8
## 수호의 깃털: dropping under GUARD_FEATHER_HP shields GUARD_FEATHER_SHIELD of max HP, once a battle.
const GUARD_FEATHER_HP: float = .3
const GUARD_FEATHER_SHIELD: float = .25
const GUARD_FEATHER_TIME: float = 8
## 독 바른 단검: a basic attack poisons (1 stack) at this chance.
const POISON_DAGGER_CHANCE: float = .25

# ---- 영웅 ----
const ENCHANT_DEFAULT_ELEMENT: StringName = &"fire"
const OVERCHARGE_REFUND: float = 25
const CHAIN_EVERY: int = 3
const CHAIN_RANGE: float = 200
const ECHO_CHANCE: float = .25
const ECHO_SHARE: float = .5
const ECHO_DELAY: float = .15
const GREATSWORD_EVERY: int = 3
const GREATSWORD_DEALT: float = 1.5
const GREATSWORD_PUSH: float = 420
const COUNTER_SHIELD_TIME: float = 3
## 처형의 낫: an attack on an enemy at SCYTHE_HP or less kills it; elites and bosses take +SCYTHE_ELITE instead.
const SCYTHE_HP: float = .15
const SCYTHE_ELITE: float = .3
const HORN_HEAL: float = .15
## 관통의 송곳 / 무한의 칼날 (critical hits): this share of the target's defense is ignored.
const PIERCE_DEFENSE: float = .3
## 수호의 사슬: the bearer takes GUARD_CHAIN_SHARE of what its nearest ally takes, at half (GUARD_CHAIN_CUT).
const GUARD_CHAIN_SHARE: float = .2
const GUARD_CHAIN_CUT: float = .5
## 약점 간파의 눈: a target the bearer hits takes +WEAK_TAKEN damage from everyone for WEAK_TIME.
const WEAK_TAKEN: float = 1.12
const WEAK_TIME: float = 4
## 원소 폭발석: killing an enemy with element stacks bursts around it and passes 2 stacks of each.
const STONE_RADIUS: float = 100
const STONE_STACKS: int = 2
## 신속의 망토: projectile damage taken.
const SWIFT_PROJECTILE_TAKEN: float = .75

# ---- 전설 ----
const SOVEREIGN_RADIUS: float = 200
const SOVEREIGN_BUFF: float = .1
const SOVEREIGN_TIME: float = 8
const SOVEREIGN_STACKS: int = 3
const GIANT_HP: float = .4
const GIANT_SCALE: float = 1.2
const SANCTUARY_RADIUS: float = 150
const SANCTUARY_TAKEN: float = .8
const STORM_RADIUS: float = 300
const STORM_SHOCK: int = 2
const INFINITY_CRIT: float = .2
const INFINITY_CRIT_DAMAGE: float = .6
const BOWSTRING_PIERCE: int = 4
const BOWSTRING_STEP: float = .15
const ETERNAL_CAP: float = .15
## 암살자의 장막: VEIL_TIME s hidden at the start and after every kill; attacks while hidden x VEIL_STRIKE.
const VEIL_TIME: float = 3
const VEIL_STRIKE: float = 2
## 거목의 심장: heals this share of max HP every second.
const ELDER_REGEN: float = .015
## 생명의 공명: an ultimate heals the bearer and allies around by RESONANCE_HEAL, taking -30% for REGEN_TIME.
const RESONANCE_RADIUS: float = 150
const RESONANCE_HEAL: float = .2
const REGEN_TIME: float = 3
const REGEN_TAKEN: float = .7
## 전쟁의 북: every ally attack speed +DRUM_SPEED, +DRUM_OPENING for the first DRUM_OPENING_TIME s.
const DRUM_SPEED: float = .15
const DRUM_OPENING: float = .3
const DRUM_OPENING_TIME: float = 10
## 피의 성배: allies heal BLOOD_LEECH of their direct damage, the bearer BLOOD_LEECH_SELF.
const BLOOD_LEECH: float = .12
const BLOOD_LEECH_SELF: float = .2
## 원소 왕관: the bearer's element stacks always land, with this many more.
const ELEMENT_CROWN_EXTRA: int = 1

# ---- 고대 ----
## 쌍둥이의 거울: the copy's HP and damage.
const MIRROR_HP: float = .7
const MIRROR_DAMAGE: float = .7
## 모든 스탯 +N% (쌍둥이의 거울, 행운의 주사위 10%; 왕의 왕관 30%): max HP, damage, defenses, speeds.
const ALL_STATS_SMALL: float = .1
const CROWN_STATS: float = .3
## 왕의 왕관: while the bearer lives every ally gets all stats +KING_AURA.
const KING_AURA: float = .08
## 황금 망고: a shield for every ally at the start, healing every MANGO_EVERY s.
const MANGO_SHIELD: float = .15
const MANGO_SHIELD_TIME: float = 10
const MANGO_EVERY: float = 10
const MANGO_HEAL: float = .05
## 시간술사의 시계: a lethal blow sends the bearer back to its HP and place REWIND_BACK s earlier (once).
const REWIND_BACK: float = 5
## 끝없는 모래시계: battles without turning points fill the gauge at the same times.
const HOURGLASS_FIRST: float = 12
const HOURGLASS_EVERY: float = 30
## 탐욕의 황금손: GREED_KILL_GOLD per kill (tower only); attack +GREED_STEP per GREED_PER gold owned.
const GREED_KILL_GOLD: int = 15
const GREED_PER: int = 100
const GREED_STEP: float = .01
const GREED_MAX: float = .5
## 폭주 기관: attack speed +OVERDRIVE_STEP a second, up to OVERDRIVE_MAX.
const OVERDRIVE_STEP: float = .03
const OVERDRIVE_MAX: float = .9
## 행운의 주사위: one stat rolled each battle, +DICE_MIN..DICE_MAX.
const DICE_MIN: float = .6
const DICE_MAX: float = 1.2
const DICE_STATS: Array[String] = ["max_hp", "physical_damage", "magic_damage", "defense", "speed", "attack_speed"]
const DICE_STAT_NAMES = {"max_hp":"최대 HP", "physical_damage":"물리 피해", "magic_damage":"마법 피해", "defense":"방어력", "speed":"이동속도", "attack_speed":"공격속도"}
## 영혼 수확자: every death on the field heals SOUL_HEAL and adds SOUL_GROW max HP and attack.
const SOUL_HEAL: float = .1
const SOUL_GROW: float = .05
## 별의 파편: every STAR_EVERY s meteors fall on STAR_TARGETS random enemies (area STAR_RADIUS).
const STAR_EVERY: float = 8
const STAR_TARGETS: int = 3
const STAR_RADIUS: float = 70
## 저주 인형: reflects this share of all damage taken to the attacker.
const DOLL_REFLECT: float = .3
