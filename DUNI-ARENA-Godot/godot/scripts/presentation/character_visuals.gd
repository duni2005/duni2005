class_name CharacterVisuals
extends RefCounted
## Visual vocabulary only; every cue reads an existing live state/attack.
const ABILITIES=["검격 · 반격","화살 · 도탄","마법탄 · 블랙홀","단검 · 은신","방패 · 보호","빛 · 치유","조준 · 관통탄","산탄 · 장전","붙잡기 · 승부","연속 펀치 · 링","특대검 · 방어태세","박치기 · 축소","처형 · 성장","폭탄 · 도화선","연격 · 일섬","미사일 · CC 추적","교대 강타 · 축복","펀치 · 구조","포탄 · 화염","성자 · 광분","연쇄번개 · 감전","반사광 · 거울","별 · 은하 영역","연사 · 반동","포획 · 유닛 발사","실 · 조종","망치 · 말뚝","기관차 · 관통","광선 · 위치 교환","택배 · 배달","전류 · 자기 결속","얼음 수정 · 빙결 폭풍"]
const PROJECTILE_COLORS={"lightning":Color("b8d3ff"),"bomb":Color("ffb361"),"tankShell":Color("eab465"),"mirrorLight":Color("f6b5ec"),"mirrorReflection":Color("ff94d7"),"star":Color("a8a7ff"),"missile":Color("ffa2a2"),"controlThread":Color("dcb0ff"),"sharpThread":Color("d4c7ff"),"frogTongue":Color("ffc4c3"),"swordWave":Color("fff2bd")}
static func active_badge(u: BattleUnit) -> String:
	if u.state_value("bomberFuse",-1)>=0:return "도화선"
	if u.state_value("guardRemaining")>0:return "방어태세"
	if u.state_value("mirrorReflectTime")>0:return "반사"
	if u.state_value("paladinBlessingTime")>0:return "축복"
	if u.state_value("shockStacks")>0:return "감전"
	if not u.frog_action.is_empty():return "포획"
	if not u.hero_rescue.is_empty():return "구조"
	if u.data.type_id==6 and u.combat_state==CombatController.State.WINDUP:return "조준"
	return ""
