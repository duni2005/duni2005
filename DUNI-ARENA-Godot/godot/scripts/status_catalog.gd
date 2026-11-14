class_name StatusCatalog
extends RefCounted
## 상태이상: every lasting effect a unit can carry — control, debuffs, buffs, marks, growth,
## unit-specific resources and item effects. ENTRIES describes each one (for the unit sheet's
## status tab and the codex); collect() lists the ones a unit carries right now, with a value.
## Works on a live BattleUnit, a guild member (between battles) or a room enemy (before battle).

## kind -> [label, colour]
const KINDS = {
	&"control":["제어", Color("ffb05e")],
	&"debuff":["약화", Color("ff7f8a")],
	&"mark":["표식", Color("c49dff")],
	&"buff":["강화", Color("7fe0a0")],
	&"growth":["성장", Color("ffd36b")],
	&"unique":["고유", Color("8fd0ff")],
	&"item":["아이템", Color("7fe8e0")],
}
const KIND_ORDER = [&"control", &"debuff", &"mark", &"buff", &"growth", &"unique", &"item"]
## key -> [name, kind, icon, description]
const ENTRIES = {
	&"stun":["기절", &"control", "star", "아무 행동도 할 수 없다. 감전 5스택, 송곳, 특수 전략 등으로 걸린다."],
	&"frozen":["빙결", &"control", "ether", "얼음에 갇혀 움직일 수 없다(기절). 풀리면 동상이 남는다."],
	&"tether":["말뚝 속박", &"control", "anvil", "말뚝 주변 작은 원 밖으로 나갈 수 없다."],
	&"magnet":["자석 결속", &"control", "charge", "다른 적과 자석으로 묶여 함께 끌려가고, 받는 피해의 일부가 짝에게도 간다."],
	&"rooted":["속박", &"control", "iron", "제자리에 묶여 이동할 수 없다."],
	&"puppet":["조종", &"control", "guild", "인형술사에게 조종당해 원래 편을 공격하고, 조종 실에 0.5초마다 피해를 입는다."],
	&"taunt":["도발", &"control", "taunt", "도발한 유닛만 노린다."],
	&"charm":["매혹", &"control", "heart", "속삭이는 자에게 매혹되어 그쪽으로 천천히 걸어가며 공격 · 궁극기를 쓸 수 없다."],
	&"duel":["결투", &"control", "battle", "가위바위보 승부 중이다. 다른 유닛의 공격은 크게 줄어든다."],
	&"swallowed":["삼켜짐", &"control", "event", "개구리에게 삼켜져 있다."],
	&"retreat":["후퇴 명령", &"control", "flag", "전략 명령에 따라 물러나는 중이다."],
	&"burn":["화상", &"debuff", "phoenixFeather", "0.5초마다 1스택이 타며 지속 피해를 받고, 곁의 아군도 그을린다."],
	&"poison":["맹독", &"debuff", "verdantStone", "스택은 전투 내내 남고 매초 스택당 피해를 받는다. 주는·받는 치유 -40%."],
	&"frost":["빙결 스택", &"debuff", "ether", "10스택이 되면 4초 빙결. 4초간 새로 쌓이지 않으면 녹는다."],
	&"frostbite":["동상", &"debuff", "ether", "받는 피해 +10%. 빙결 스택 대신 추가 피해 5를 받는다."],
	&"shock":["감전", &"debuff", "charge", "5스택이 되면 2초 기절한다."],
	&"headwind":["역풍", &"debuff", "hawkFeather", "이동속도 -30%, 공격속도 -20%."],
	&"slow":["둔화", &"debuff", "boots", "이동속도 -30%. 슬라임의 몸통 박치기에 맞으면 2초간 걸린다."],
	&"erosion":["침식", &"debuff", "skull", "이동 외 행동마다 피해를 받고, 받는 치명타 피해 +25%."],
	&"curse":["축소 저주", &"debuff", "dice", "챌런에게 맞아 몸이 작아졌다. 받는 피해 +15%."],
	&"cosmic":["우주 표식", &"debuff", "star", "은하에게 찍혀 주는 피해 -30%."],
	&"gift_weak":["선물: 취약", &"debuff", "event", "산타의 선물. 받는 피해 +50%."],
	&"whisper":["속삭임", &"debuff", "skull", "속삭이는 자의 바늘 스택. 3스택이 되면 터지며 최대 HP의 5% 추가 피해(마법 · 어둠)."],
	&"targeted":["목표", &"debuff", "event", "석궁의 목표지정 탄에 맞았다. 받는 피해 +10%, 받는 바람 피해 +15%."],
	&"light_mark":["광휘 표식", &"mark", "star", "다른 유닛이 직접 공격으로 터뜨리면 터뜨린 유닛이 최대 HP 5% 회복."],
	&"dark_mark":["암흑 표식", &"mark", "skull", "다른 유닛이 직접 공격으로 터뜨리면 그 공격 피해 +20%."],
	&"saint":["성자", &"mark", "crown", "광신도가 따르는 성자. 따르는 광신도마다 주는 피해 +10%."],
	&"gift_power":["선물: 힘", &"buff", "event", "산타의 선물. 공격력 +50%."],
	&"bounty":["현상금", &"mark", "gold", "바운티 헌터가 건 현상금. 받는 피해 +5%, 처치되면 헌터가 100 G를 받는다."],
	&"top_boost":["폭주 회전", &"buff", "event", "팽이가 더 빠르고 강하게 회전한다."],
	&"drug_frenzy":["광란", &"control", "skull", "금단의 약물로 이성을 잃었다. 저돌적으로 가장 가까운 아군부터 공격한다(아군이 없으면 적). 주는 피해 +5%, 받는 피해 +15%."],
	&"suppress":["억제 약물", &"debuff", "event", "억제 약물에 맞았다. 공격 속도 -30%, 이동 속도 감소."],
	&"disarmed":["놓침", &"control", "battle", "무기를 놓쳤다. 무기를 다시 주울 때까지 기본공격과 궁극기를 쓸 수 없고, 무기를 주우러 가는 것을 가장 먼저 한다."],
	&"shield":["보호막", &"buff", "shield", "피해를 먼저 흡수한다."],
	&"iron":["철벽", &"buff", "iron", "받는 피해가 크게 줄어든다."],
	&"invincible":["무적", &"buff", "heart", "어떤 피해도 받지 않는다."],
	&"rescued":["구조 보호", &"buff", "shield", "히어로가 구하러 오는 중이라 피해를 받지 않는다."],
	&"gust":["기류", &"buff", "hawkFeather", "스택당 공격속도 +5%, 바람 피해 +3%. 직접 공격에 맞으면 사라진다."],
	&"counter":["반격 강화", &"buff", "redo", "공격을 피하거나 막은 직후, 다음 공격이 강해진다."],
	&"blessing":["성기사의 축복", &"buff", "warmNecklace", "주는 피해 +30%."],
	&"guard":["수호 자세", &"buff", "defense", "두비두밤이 버티며 막는 중이다. 막을 때마다 수호 스택이 쌓인다."],
	&"guard_stacks":["수호 스택", &"buff", "defense", "다음 공격의 범위·이동속도가 스택만큼 커진다."],
	&"guardian_ult":["수호자 결의", &"buff", "shield", "수호자 궁극기가 지속되는 중이다."],
	&"reflect":["반사", &"buff", "evade", "금간 거울이 공격을 되돌려 보낸다."],
	&"shadow":["은신", &"buff", "evade", "적에게 보이지 않는다. 공격하면 드러난다."],
	&"frenzy":["광분", &"buff", "fang", "성자를 잃은 광신도. 공격력·공격속도 +30%."],
	&"rescue_ready":["구조 대기", &"buff", "heart", "아군이 치명상을 입으면 한 번 구하러 날아간다."],
	&"predator":["포식 성장", &"growth", "predatorFang", "처치할 때마다 몸집과 힘이 커진다(스택당 크기 +4%)."],
	&"shrink":["축소 · 가속", &"growth", "boots", "챌런이 피해를 받을수록 작아지고 빨라진다(스택당 이동속도 +4%)."],
	&"split":["분열", &"growth", "heart", "슬라임이 쓰러질 때마다 HP 25% · 피해량 30%인 두 마리로 나뉜다(최대 2번). 마지막 분열체는 궁극기를 쓸 수 없다."],
	&"mimic":["흉내", &"unique", "star", "앵무새가 적의 궁극기를 흉내 내는 중이다. 그 궁극기의 피해는 원래 주인의 표를 따른다."],
	&"plague_fog":["역병 안개", &"unique", "skull", "역병이 맵 전체를 안개로 덮고 있다. 0.5초마다 모든 적이 피해를 받는다."],
	&"golem_charge":["증기 차징", &"unique", "ether", "빙하 골렘이 증기를 모으는 중이다. 다 모이면 폭발해 주변 적을 빙결시킨다."],
	&"ammo":["탄약", &"unique", "supply", "기관총의 남은 탄약. 다 쓰면 4초 재장전."],
	&"bolts":["화살 탄창", &"unique", "supply", "석궁의 남은 화살. 한 발이 기본공격 1회이며, 다 쓰면 1.4초 재장전."],
	&"reload":["재장전", &"unique", "supply", "탄약을 다시 채우는 중이다(기관총은 이동속도 -60%, 석궁은 -20%)."],
	&"oil":["기름", &"unique", "phoenixFeather", "화염방사기의 기름. 6 이상이어야 분사를 시작한다."],
	&"sniper_burst":["연속 저격 준비", &"unique", "redThorn", "다음 저격이 연속 3발이 된다."],
	&"tank_flame":["화염 포탄 준비", &"unique", "dragonHeart", "다음 포탄이 화염 포탄이 된다."],
	&"vigor_totem":["활력 토템", &"item", "vigorTotem", "5초마다 주변 아군 HP를 회복시킨다."],
	&"charge_totem":["충전 토템", &"item", "chargeTotem", "4초마다 주변 아군의 궁극기를 충전한다."],
	&"kill_growth":["처치 성장", &"item", "fang", "처치할 때마다 공격력이 영구히 오른다."],
	&"opening_awl":["개전 송곳", &"item", "thickAwl", "전투 시작 시 송곳을 던져 맞은 적을 기절시킨다."],
	&"phoenix":["불사조의 깃털", &"item", "phoenixFeather", "전투당 1회, 쓰러지면 HP 40%로 부활하고 2초 무적."],
	&"hourglass":["시간의 모래시계", &"item", "hourglass", "궁극기를 쓴 직후 게이지 35%를 되찾는다."],
	&"dragon_heart":["용의 심장", &"item", "dragonHeart", "주기적으로 주변에 화염 폭발을 일으킨다."],
	&"victory_gold":["황금 토큰", &"item", "goldToken", "살아서 승리하면 골드를 얻는다."],
	# Item statuses (ItemEffects; 0.96 아이템 재점검; numbers in ItemTuning).
	&"bleed":["출혈", &"debuff", "bleedBlade", "출혈의 칼날 치명타에 베였다. 0.5초마다 물리 지속 피해를 받는다. 다시 걸리면 시간이 갱신된다."],
	&"weak_exposed":["약점 노출", &"debuff", "weakEye", "약점 간파의 눈에 약점을 들켰다. 모든 공격에 받는 피해 +12%."],
	&"berserk":["광전", &"buff", "berserkerHelm", "광전사의 투구. HP가 절반 이하인 동안 공격속도가 크게 오른다."],
	&"hunt":["사냥 본능", &"buff", "hunterShuriken", "사냥꾼의 표창. 처치 직후 잠시 공격속도가 크게 오른다."],
	&"first_strike":["첫 일격", &"buff", "firstStrikeRing", "첫 일격의 반지. 다음 기본공격의 피해가 크게 오른다(8초마다 다시 준비)."],
	&"counter_crit":["치명 반격", &"buff", "counterShield", "반격의 방패. 막거나 피한 직후라 다음 공격이 반드시 치명타다."],
	&"veil_strike":["암살 일격", &"buff", "oblivionVeil", "암살자의 장막. 은신 중이라 공격 피해가 2배다. 공격하면 드러난다."],
	&"regen_barrier":["재생 장벽", &"buff", "lifeResonance", "생명의 공명. 궁극기 직후 잠시 받는 피해가 줄어든다."],
	&"soul_harvest":["영혼 수확", &"growth", "soulReaper", "영혼 수확자. 전장에서 누군가 쓰러질 때마다 최대 HP와 공격력이 오른다."],
	&"overdrive":["폭주", &"growth", "overdriveEngine", "폭주 기관. 전투 동안 매초 공격속도가 쌓인다."],
	&"smash_ready":["강타 준비", &"unique", "steelGreatsword", "강철 대검. 기본공격 세 번째마다 강타가 나간다."],
	&"mirror_clone":["거울 분신", &"unique", "twinMirror", "쌍둥이의 거울이 만든 분신. 아이템 효과와 궁극기가 없고, 쓰러져도 손실이 없다."],
	&"rewind_ready":["되감기 준비", &"unique", "rewindClock", "시간술사의 시계. 쓰러질 피해를 받으면 5초 전의 HP와 위치로 되돌아간다(전투당 1회)."],
	&"blood_blessing":["피의 가호", &"item", "bloodChalice", "피의 성배. 직접 공격으로 준 피해의 일부를 회복한다(아군 전원)."],
	&"war_drum":["전쟁의 북", &"item", "warDrum", "전쟁의 북. 아군 전원의 공격속도가 오른다(전투 초반에는 더 크게)."],
	&"king_aura":["왕의 가호", &"item", "cursedCrown", "왕의 왕관. 왕관을 쓴 아군이 살아 있는 동안 모든 스탯이 오른다."],
	&"greed":["탐욕", &"item", "greedPouch", "탐욕의 황금손. 처치할 때마다 골드를 모은다(탑에서만 지급)."],
	# 0.97 빌드 지원 아이템
	&"beast_form":["야수 변신", &"buff", "beastHide", "야수의 가죽. 몸집 · 공격속도 · 이동속도가 크게 오르고 준 피해의 일부를 회복한다."],
	&"spirit":["영혼", &"unique", "soulLantern", "영혼의 등불이 불러낸 쓰러진 아군의 영혼. 잠시 더 싸우다 사라지고, 사라져도 손실이 없다."],
	&"time_stop":["시간 정지", &"control", "thiefWatch", "시간 도둑의 회중시계. 시간이 멈춰 아무것도 할 수 없다."],
	&"banner_aura":["깃발 범위", &"buff", "legionBanner", "군단장의 깃발 근처. 공격력이 오르고 받는 피해가 줄어든다."],
	&"dragon_stage":["용 성장 단계", &"growth", "dragonEgg", "새끼 용의 알. 전투에 이길 때마다 새끼 용이 자라 불길이 세진다."],
	&"cape_dodge":["결투가의 몸놀림", &"buff", "duelCape", "결투가의 망토. 회피할 때마다 공격속도가 올라간다."],
	&"vengeance":["복수심", &"growth", "vengeanceMask", "복수의 가면. 쓰러진 아군마다 공격력 · 공격속도가 오른다."],
	&"crest_taunt":["기사의 도전", &"control", "knightCrest", "수호 기사의 문장. 문장을 낀 유닛만 공격한다."],
	&"deep_freeze":["영구 동토", &"debuff", "permafrostScepter", "영구 동토의 왕홀로 얼어붙어 받는 피해가 크게 늘어난다."],
	&"charge_ready":["돌격 준비", &"buff", "chargeHorn", "돌격 나팔. 다음 공격이 대상을 기절시킨다."],
	&"pact_off":["계약 중단", &"debuff", "pactSeal", "계약의 인장. 골드가 모자라 이번 전투는 스탯 보너스가 꺼졌다."],
	&"lonely_king":["고독한 왕", &"buff", "lonelyKingSword", "고독한 왕의 검. 비어 있는 출정 칸만큼 모든 스탯이 오른다."],
	&"item_growth":["아이템 성장", &"growth", "conquerorCrown", "런 동안 자라는 아이템(정복 층 · 연승 · 대기 · 신앙)."],
}

static func entry(key: StringName) -> Array:return ENTRIES.get(key, ["", &"buff", "star", ""])
static func kind_label(key: StringName) -> String:return KINDS[entry(key)[1]][0]
static func kind_color(key: StringName) -> Color:return KINDS[entry(key)[1]][1]

static func _secs(t: float) -> String:return "%.1f초" % t
static func _stacks(n: float) -> String:return "%d스택" % int(n)

## The unit's state as one dictionary of the persisted keys (character state plus the shield /
## iron / stun / invincible fields of a live unit).
static func _state(subject) -> Dictionary:
	if subject is BattleUnit:
		var s: Dictionary = subject.character_specific_state.duplicate()
		for key in StrategyEffects.FIELDS:s[key] = float(subject.get(StrategyEffects.FIELDS[key]))
		return s
	if subject is GuildMemberState:return subject.character_specific_state
	if subject is EnemyRoomState:return subject.persistent_state
	return {}
static func _num(s: Dictionary, key: String) -> float:
	var v = s.get(key, 0)
	return float(v) if v is int or v is float else 0.0

## Statuses the unit carries now, in KIND_ORDER: [{key, value}] where value is a short text such as
## "3스택" or "2.4초" (may be empty). `stats` adds the item effects of its equipment.
static func collect(subject, stats: UnitCombatStats = null, type_id: int = -1) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var add := func(key: StringName, value: String = ""):rows.append({"key": key, "value": value})
	var s: Dictionary = _state(subject)
	var u: BattleUnit = subject if subject is BattleUnit else null
	if u != null:
		stats = u.combat_stats if u.combat_stats != null else stats;type_id = u.data.type_id
	elif subject is GuildMemberState:type_id = subject.unit_type_id
	elif subject is EnemyRoomState:type_id = subject.unit_type_id;stats = subject.combat_stats if stats == null else stats
	var now: float = u.battle.clock.elapsed if u != null else 0.0
	# 제어
	if _num(s, "stun") > 0:add.call(&"frozen" if _num(s, "frozenTime") > 0 else &"stun", _secs(_num(s, "stun")))
	if _num(s, "tetherTime") > 0:add.call(&"tether", _secs(_num(s, "tetherTime")))
	if _num(s, "magnetTime") > 0:add.call(&"magnet", _secs(_num(s, "magnetTime")))
	if u != null:
		if _num(s, "rootedUntil") > now:add.call(&"rooted", _secs(_num(s, "rootedUntil") - now))
		if not u.puppet_control.is_empty():add.call(&"puppet")
		if u.taunted_until > now:add.call(&"taunt", _secs(u.taunted_until - now))
		if not u.duel.is_empty():add.call(&"duel")
		if not u.lost_sword.is_empty():add.call(&"disarmed")
		if not u.frog_carrier.is_empty():add.call(&"swallowed")
		if u.command_retreat_until > now:add.call(&"retreat", _secs(u.command_retreat_until - now))
	if _num(s, "charmTime") > 0:add.call(&"charm", _secs(_num(s, "charmTime")))
	# 약화
	if _num(s, "burnStacks") > 0:add.call(&"burn", _stacks(_num(s, "burnStacks")))
	if _num(s, "poisonStacks") > 0:add.call(&"poison", _stacks(_num(s, "poisonStacks")))
	if _num(s, "frostStacks") > 0:add.call(&"frost", "%d/%d" % [int(_num(s, "frostStacks")), ElementEffects.FREEZE_STACKS])
	if _num(s, "frostbiteTime") > 0:add.call(&"frostbite", _secs(_num(s, "frostbiteTime")))
	if _num(s, "shockStacks") > 0:add.call(&"shock", "%d/%d" % [int(_num(s, "shockStacks")), ElementEffects.SHOCK_STACKS])
	if _num(s, "headwindTime") > 0:add.call(&"headwind", _secs(_num(s, "headwindTime")))
	if _num(s, "slowTime") > 0:add.call(&"slow", _secs(_num(s, "slowTime")))
	if _num(s, "erosionTime") > 0:add.call(&"erosion", _secs(_num(s, "erosionTime")))
	if _num(s, "curseTime") > 0:add.call(&"curse", _secs(_num(s, "curseTime")))
	if u != null and u.cosmic_marked:add.call(&"cosmic")
	if _num(s, "targetedTime") > 0:add.call(&"targeted", _secs(_num(s, "targetedTime")))
	if _num(s, "giftWeakTime") > 0:add.call(&"gift_weak", _secs(_num(s, "giftWeakTime")))
	if _num(s, "giftPowerTime") > 0:add.call(&"gift_power", _secs(_num(s, "giftPowerTime")))
	if s.has("bountyBy"):add.call(&"bounty")
	if _num(s, "topBoost") > 0:add.call(&"top_boost", _secs(_num(s, "topBoost")))
	if _num(s, "frenzyTime") > 0:add.call(&"drug_frenzy", _secs(_num(s, "frenzyTime")))
	if _num(s, "suppressTime") > 0:add.call(&"suppress", _secs(_num(s, "suppressTime")))
	if _num(s, "whisperStacks") > 0:add.call(&"whisper", "%d/3" % int(_num(s, "whisperStacks")))
	if _num(s, "bleedTime") > 0:add.call(&"bleed", _secs(_num(s, "bleedTime")))
	if _num(s, "weakTime") > 0:add.call(&"weak_exposed", _secs(_num(s, "weakTime")))
	# 표식
	if not str(s.get("lightMark", "")).is_empty():add.call(&"light_mark")
	if not str(s.get("darkMark", "")).is_empty():add.call(&"dark_mark")
	if u != null:
		var devotees: int = u.battle.units.filter(func(v):return v.alive and v.team == u.team and v.saint_actor == u.actor_id() and not v.character_specific_state.get("saintFallen", false)).size()
		if devotees > 0:add.call(&"saint", "+%d%%" % (devotees * 10))
	# 강화
	if _num(s, "shieldHp") > 0 and _num(s, "shieldTime") > 0:add.call(&"shield", "%d · %s" % [roundi(_num(s, "shieldHp")), _secs(_num(s, "shieldTime"))])
	if _num(s, "ironDefenseTime") > 0:add.call(&"iron", _secs(_num(s, "ironDefenseTime")))
	if _num(s, "invincible") > 0:add.call(&"invincible", _secs(_num(s, "invincible")))
	if u != null and not u.hero_rescue_owner.is_empty():add.call(&"rescued")
	if _num(s, "windStacks") > 0:add.call(&"gust", _stacks(_num(s, "windStacks")))
	if u != null and StanceRules.counter_ready(u):add.call(&"counter", _secs(_num(s, "counterBoostUntil") - now))
	if _num(s, "paladinBlessingTime") > 0:add.call(&"blessing", _secs(_num(s, "paladinBlessingTime")))
	if _num(s, "guardRemaining") > 0:add.call(&"guard", _secs(_num(s, "guardRemaining")))
	if _num(s, "guardStacks") > 0:add.call(&"guard_stacks", _stacks(_num(s, "guardStacks")))
	if _num(s, "guardianUltTime") > 0:add.call(&"guardian_ult", _secs(_num(s, "guardianUltTime")))
	if _num(s, "mirrorReflectTime") > 0:add.call(&"reflect", _secs(_num(s, "mirrorReflectTime")))
	if _num(s, "shadowTime") > 0:add.call(&"shadow", _secs(_num(s, "shadowTime")))
	if s.get("saintFallen", false) == true:add.call(&"frenzy")
	if type_id == 17 and not (u != null and u.hero_rescue_used):add.call(&"rescue_ready")
	if u != null and stats != null and stats.has(&"berserkerHelm") and ItemEffects.berserk(u):add.call(&"berserk")
	if _num(s, "hunterTime") > 0:add.call(&"hunt", _secs(_num(s, "hunterTime")))
	if _num(s, "firstStrike") > 0:add.call(&"first_strike")
	if u != null and _num(s, "counterCritUntil") > now:add.call(&"counter_crit", _secs(_num(s, "counterCritUntil") - now))
	if stats != null and stats.has(&"oblivionVeil") and (_num(s, "veilStrike") > 0 or _num(s, "veilHidden") > 0 and _num(s, "shadowTime") > 0):add.call(&"veil_strike")
	if _num(s, "regenTime") > 0:add.call(&"regen_barrier", _secs(_num(s, "regenTime")))
	# 성장
	if _num(s, "predatorStacks") > 0:add.call(&"predator", _stacks(_num(s, "predatorStacks")))
	if _num(s, "dolphinStacks") > 0:add.call(&"shrink", _stacks(_num(s, "dolphinStacks")))
	if type_id == 35:add.call(&"split", "%d/2" % int(_num(s, "slimeSplits")))
	if _num(s, "fogTime") > 0:add.call(&"plague_fog", _secs(_num(s, "fogTime")))
	if _num(s, "golemCharge") > 0:add.call(&"golem_charge", "%d%%" % roundi(_num(s, "golemCharge") * 100))
	if s.has("mimicType"):add.call(&"mimic", CharacterCatalog.all()[int(s.mimicType)].display_name)
	if _num(s, "soulStacks") > 0:add.call(&"soul_harvest", "+%d%%" % roundi(_num(s, "soulStacks") * ItemTuning.SOUL_GROW * 100))
	if u != null and stats != null and stats.has(&"overdriveEngine"):add.call(&"overdrive", "+%d%%" % roundi(minf(ItemTuning.OVERDRIVE_MAX, floorf(_num(s, "overdrive")) * ItemTuning.OVERDRIVE_STEP) * 100))
	# 고유
	if type_id == 23 and s.has("ammo"):add.call(&"ammo", "%d/20" % int(_num(s, "ammo")))
	if type_id == 34 and s.has("bolts"):add.call(&"bolts", "%d/7" % int(_num(s, "bolts")))
	if _num(s, "reloadRemaining") > 0:add.call(&"reload", _secs(_num(s, "reloadRemaining")))
	if type_id == 32 and s.has("oil"):add.call(&"oil", "%d/%d" % [int(_num(s, "oil")), 30])
	if s.get("sniperBurstReady", false) == true:add.call(&"sniper_burst")
	if s.get("tankFlameReady", false) == true:add.call(&"tank_flame")
	if stats != null and stats.has(&"steelGreatsword") and u != null:add.call(&"smash_ready", "%d/%d" % [int(_num(s, "smashCount")) + 1, ItemTuning.GREATSWORD_EVERY])
	if s.has("mirrorOf") and not s.has("spiritOf"):add.call(&"mirror_clone")
	if _num(s, "rewindReady") > 0:add.call(&"rewind_ready")
	# 아이템
	if stats != null:
		if stats.vigor_totem_count > 0:add.call(&"vigor_totem", "×%d" % stats.vigor_totem_count)
		if stats.charge_totem_count > 0:add.call(&"charge_totem", "×%d" % stats.charge_totem_count)
		if stats.fang_count > 0:
			var kills: int = u.equipment_fang_kills if u != null else subject.fang_kills if subject is GuildMemberState else 0
			add.call(&"kill_growth", "처치 %d" % kills)
		if stats.opening_awl_count > 0:add.call(&"opening_awl", "×%d" % stats.opening_awl_count)
		if stats.phoenix_count > 0:add.call(&"phoenix", "사용함" if u != null and u.phoenix_used else "준비")
		if stats.hourglass_count > 0:add.call(&"hourglass", "×%d" % stats.hourglass_count)
		if stats.dragon_heart_count > 0:add.call(&"dragon_heart", "×%d" % stats.dragon_heart_count)
		if stats.victory_gold > 0:add.call(&"victory_gold", "%d G" % stats.victory_gold)
		if stats.has(&"greedPouch") and u != null:add.call(&"greed", "+%d G" % int(_num(s, "greedGold")))
	if u != null and u.alive and ItemEffects.blood_blessed(u):add.call(&"blood_blessing")
	if u != null and u.alive and ItemEffects.drummed(u):add.call(&"war_drum")
	if u != null and u.alive and ItemEffects.king_blessed(u):add.call(&"king_aura")
	# 0.97 빌드 지원 아이템
	if _num(s, "beastTime") > 0:add.call(&"beast_form", _secs(_num(s, "beastTime")))
	if s.has("spiritOf"):add.call(&"spirit", _secs(_num(s, "spiritTime")))
	if _num(s, "timeStopTime") > 0:add.call(&"time_stop", _secs(_num(s, "timeStopTime")))
	if u != null and u.alive and BuildItems.bannered(u):add.call(&"banner_aura")
	if _num(s, "capeTime") > 0:add.call(&"cape_dodge", "+%d%%" % roundi(_num(s, "capeStacks") * ItemTuning.CAPE_ATTACK_SPEED * 100))
	if _num(s, "vengeance") > 0:add.call(&"vengeance", "+%d%%" % roundi(_num(s, "vengeance") * ItemTuning.VENGEANCE_STEP * 100))
	if _num(s, "crestTaunt") > 0 and u != null and u.taunted_until > now:add.call(&"crest_taunt", _secs(u.taunted_until - now))
	if _num(s, "frozenTime") > 0 and _num(s, "deepFreeze") > 0:add.call(&"deep_freeze", _secs(_num(s, "frozenTime")))
	if _num(s, "hornStun") > 0:add.call(&"charge_ready")
	if _num(s, "pactOff") > 0:add.call(&"pact_off")
	if _num(s, "lonelyEmpty") > 0:add.call(&"lonely_king", "+%d%%" % roundi(_num(s, "lonelyEmpty") * ItemTuning.LONELY_STEP * 100))
	if stats != null:
		if stats.has(&"dragonEgg"):add.call(&"dragon_stage", "%d/%d단계" % [BuildItems.dragon_stage(stats), ItemTuning.DRAGON_STAGES])
		var grown: Array = []
		for pair in [[&"conquerorCrown", "정복 %d층"], [&"streakBelt", "연승 %d"], [&"reserveBadge", "대기 %d"], [&"mangoRosary", "승리 %d/5"]]:
			if stats.has(pair[0]):grown.append(pair[1] % int(stats.growth.get(pair[0], 0)))
		if not grown.is_empty():add.call(&"item_growth", " · ".join(grown))
	return rows
