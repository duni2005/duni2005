# DUNI ARENA — Godot Phase 8 완료 보고

2026-10-12 · Godot 4.6.3 · 기준: 저장소의 dist 실행 코드. Phase9 타워 지도/진행을 시작하지 않았습니다.

**실전 모드:** BattleManager 기본값은 common=true / full_characters=true. full 모드는 start_battle에서도 common을 켭니다. RoomBattleSession·F5 room_battle 및 기본 DeploymentScreen은 실전 공통 규칙입니다. Phase1~6 수치·상태 비교 검사는 생성 헬퍼에서 두 flag를 false로 명시합니다. Phase7 검사는 common=true/full=false로 당시 공통 규칙을 검증합니다. 기존 Phase3 GUI는 debug_comparison_minimal=true, 기존 room/TP/card/combat GUI는 full_character_debug=false를 명시합니다. 신규 Phase8 검사·GUI는 두 flag=true입니다. 타입별 숨은 테스트 분기는 없습니다.

## 1. 최종 캐릭터 수

실행 코드 TYPES와 ATTACK_PROFILES, ULTIMATES는 모두26개입니다. 샷건만 ULTIMATES가 null입니다. 캐릭터마다 Ability script 하나이며 공통 물리·피해·패링을 복제하지 않습니다.

## 2. type ID / 이름

0전사 · 1궁수 · 2마법사 · 3암살자 · 4수호자 · 5힐러 · 6대구경 저격수 · 7샷건 · 8가위바위보 마스터 · 9UFC 선수 · 10두비두밤 · 11챌런 · 12포식자 · 13폭탄 · 14검객 · 15소형 위성 · 16성기사 · 17히어로 · 18탱크 · 19광신도 · 20번개 마법사 · 21금간 거울 · 22은하 · 23기관총 · 24개구리 · 25인형술사.

## 3. 전체 UnitData

app.js TYPES/CHARACTER_COSTS/CHARACTER_DEFENSE와 towerRecruitCost를 사용했습니다. 종류의 기본 scale은1이며 전투중 영구스택/저주/외부 body_scale을 별도 계산합니다. HP/게이지/탄창/타겟을 Resource에 저장하지 않습니다.

| ID | 이름 | 태그 | HP | ATK | DEF | 속도 | range | interval | crit | 비용 | 기본scale | 궁극기 |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: | --- |
| 0 | 전사 | 일반 / 돌격형 | 150 | 16 | 26 | 96 | 62 | 1 | 22% | 100G / 2토큰 | 1 | 천공참 |
| 1 | 궁수 | 일반 / 후열 / 대치형 / 회피형 | 105 | 15 | 18 | 92 | 380 | 0.75 | 20% | 120G / 2토큰 | 1 | 일점 관통 |
| 2 | 마법사 | 일반 / 후열 / 대치형 / 신중형 | 110 | 25 | 20 | 77 | 360 | 1.65 | 18% | 150G / 2토큰 | 1 | 사건의 지평선 |
| 3 | 암살자 | 일반 / 약자멸시 / 기습형 | 145 | 25 | 20 | 132 | 59 | 0.65 | 24% | 140G / 3토큰 | 1 | 그림자 지배 |
| 4 | 수호자 | 일반 / 호위형 | 190 | 16 | 40 | 86 | 70 | 1.1 | 16% | 130G / 2토큰 | 1 | 절대 수호 |
| 5 | 힐러 | 일반 / 후열 / 대치형 / 의존형 | 105 | 10 | 18 | 84 | 360 | 1.1 | 20% | 110G / 2토큰 | 1 | 생명의 성역 |
| 6 | 대구경 저격수 | 일반 / 은둔형 | 125 | 95 | 22 | 102 | 1100 | 1.2 | 20% | 200G / 3토큰 | 1 | 삼연발 |
| 7 | 샷건 | 일반 / 돌격형 | 170 | 9 | 24 | 112 | 190 | 0.55 | 20% | 160G / 3토큰 | 1 | 없음 |
| 8 | 가위바위보 마스터 | 일반 / 대치형 | 150 | 30 | 24 | 104 | 220 | 2.2 | 20% | 180G / 3토큰 | 1 | 최후의 승부 |
| 9 | UFC 선수 | 일반 / 돌격형 | 185 | 11 | 28 | 118 | 66 | 0.75 | 20% | 170G / 3토큰 | 1 | 링 |
| 10 | 두비두밤 | 일반 / 돌격형 | 240 | 40 | 38 | 78 | 80 | 1.65 | 20% | 190G / 3토큰 | 1 | 특대검! |
| 11 | 챌런 | 일반 / 방황 | 155 | 22 | 20 | 128 | 75 | 1.6 | 20% | 210G / 3토큰 | 1 | 멀티 축소저주 |
| 12 | 포식자 | 일반 / 돌격형 | 315 | 48 | 44 | 70 | 95 | 3.3 | 20% | 250G / 5토큰 | 1 | 부셔먹기 |
| 13 | 폭탄 | 일반 / 후열 / 대치형 | 145 | 36 | 22 | 96 | 400 | 1.8 | 20% | 180G / 4토큰 | 1 | 왕폭탄 |
| 14 | 검객 | 일반 / 돌격형 | 175 | 16 | 26 | 115 | 78 | 1.2 | 22% | 200G / 3토큰 | 1 | 일섬 |
| 15 | 소형 위성 | 일반 / 방황 | 95 | 14 | 20 | 91 | 480 | 0.9 | 20% | 220G / 3토큰 | 1 | 지원포격 |
| 16 | 성기사 | 일반 / 호위형 | 205 | 18 | 34 | 90 | 78 | 1.15 | 20% | 210G / 3토큰 | 1 | 수호신 |
| 17 | 히어로 | 일반 / 대치형 | 210 | 23 | 30 | 112 | 72 | 1.05 | 20% | 230G / 4토큰 | 1 | 악당처단 |
| 18 | 탱크 | 일반 / 대치형 | 300 | 52 | 46 | 48 | 430 | 2.2 | 20% | 270G / 4토큰 | 1 | 화염포 |
| 19 | 광신도 | 일반 / 의존형 | 155 | 17 | 22 | 108 | 64 | 0.85 | 20% | 150G / 3토큰 | 1 | 신앙심 |
| 20 | 번개 마법사 | 일반 / 후열 / 대치형 | 120 | 18 | 21 | 86 | 400 | 1.6 | 20% | 240G / 3토큰 | 1 | 방출 |
| 21 | 금간 거울 | 일반 / 대치형 | 145 | 18 | 24 | 88 | 300 | 1.3 | 20% | 220G / 3토큰 | 1 | 반사 |
| 22 | 은하 | 일반 / 대치형 | 125 | 12 | 21 | 82 | 350 | 1.7 | 20% | 240G / 3토큰 | 1 | 지평선 |
| 23 | 기관총 | 일반 / 대치형 | 145 | 9 | 22 | 88 | 430 | 0.8 | 20% | 200G / 3토큰 | 1 | 빠른 장전 |
| 24 | 개구리 | 일반 / 방황 / 폴짝 | 190 | 30 | 25 | 105 | 340 | 3.8 | 20% | 220G / 3토큰 | 1 | 낼름 퉤 |
| 25 | 인형술사 | 일반 / 대치형 | 150 | 12 | 22 | 92 | 350 | 1.5 | 20% | 230G / 3토큰 | 1 | 조종 |

TYPES.range/interval은 공격 프로필의 reach/전체 준비·활성·회복 시간과 다릅니다.

| ID / 이름 | windup / active / recovery | reach | cone rad | impulse |
| --- | --- | ---: | ---: | ---: |
| 0 전사 | 0.38 / 0.17 / 0.25 | 108 | 1.45 | 245 |
| 1 궁수 | 0.43 / 0.14 / 0.22 | 410 | 0.35 | 135 |
| 2 마법사 | 0.68 / 0.2 / 0.32 | 390 | 0.4 | 260 |
| 3 암살자 | 0.27 / 0.18 / 0.22 | 112 | 1.2 | 185 |
| 4 수호자 | 0.48 / 0.2 / 0.32 | 116 | 1.65 | 340 |
| 5 힐러 | 0.48 / 0.16 / 0.25 | 390 | 0.4 | 120 |
| 6 대구경 저격수 | 5 / 0.12 / 0.45 | 1150 | 0.04 | 350 |
| 7 샷건 | 0.36 / 0.12 / 0.18 | 190 | 0.38 | 115 |
| 8 가위바위보 마스터 | 0.4 / 1.2 / 0.5 | 230 | 1 | 0 |
| 9 UFC 선수 | 0.22 / 0.11 / 0.09 | 103 | 0.22 | 95 |
| 10 두비두밤 | 2 / 0.12 / 0.8 | 180 | 1.7 | 420 |
| 11 챌런 | 0.34 / 0.32 / 0.32 | 190 | 0.2 | 350 |
| 12 포식자 | 1.65 / 0.12 / 1.18 | 160 | 1.05 | 270 |
| 13 폭탄 | 0.6 / 0.16 / 0.3 | 430 | 0.4 | 290 |
| 14 검객 | 0.32 / 0.22 / 0.1 | 122 | 1.4 | 110 |
| 15 소형 위성 | 0.14 / 0.1 / 0.12 | 480 | 0.5 | 150 |
| 16 성기사 | 0.48 / 0.23 / 0.3 | 138 | 1.1 | 620 |
| 17 히어로 | 0.38 / 0.18 / 0.28 | 120 | 0.45 | 310 |
| 18 탱크 | 1.8 / 0.15 / 0.55 | 470 | 0.16 | 440 |
| 19 광신도 | 0.3 / 0.17 / 0.22 | 112 | 1.15 | 185 |
| 20 번개 마법사 | 0.56 / 0.13 / 0.3 | 430 | 0.32 | 140 |
| 21 금간 거울 | 0.5 / 0.14 / 0.3 | 330 | 0.35 | 145 |
| 22 은하 | 0.65 / 0.15 / 0.35 | 385 | 0.7 | 155 |
| 23 기관총 | 0.22 / 2.2 / 0.15 | 460 | 0.72 | 115 |
| 24 개구리 | 0.8 / 0.15 / 0.4 | 370 | 0.25 | 290 |
| 25 인형술사 | 0.55 / 0.15 / 0.3 | 385 | 0.2 | 145 |

검증용 원본 추출 데이터: [phase8-web-catalog.json](migration/phase8-web-catalog.json).

## 4. Full AI 구현 범위

BattleBrain은 createBrain의 대담함·신중도·기회포착·인내·템포·반응·측면·최초 진입 계획과 개별 initiative 시계를 갖습니다. observe/circle/feint/flank/approach/retreat/shadow/guard, 독립 공격 의도, 주저함 최대2회, 공격 후 이탈, 준비 동작 감지, 공격 소모 후 짧은 반격, 거리 증가 관찰을 연결했습니다. Rear station은 안전한 사격 위치/전열 아군 뒤를 점수화하고 전열 호위와 이동 정책은 Ability에 위임합니다.

AreaEvaluator/BattleZones는 실제 블랙홀·화염·링 로프·폭탄·궁극기 준비 구역, 군집 압력, 치유·성역·힐러·오라·토템을 평가합니다. 가짜 장판을 만들지 않습니다. 위협 반응은 Phase7의 확률·오패링과 공유합니다. Godot의 호출/좌표 체계로 정책을 포팅했으며 JS RNG 소비 순서·float64 이동과 같은 궤적/동일 시드 승률을 보장하는 이식은 아닙니다.

## 5. stance AI 효과

신중함: 공격0.8, 추가 회피10%p, 패링확률1.25 상한1, 반응지연0.72, 투사체 인지0.93/예측0.56초, 더 넓은 거리와 공격 소모 반격. 저돌적: 공격1.25, 받는 피해1.2, 피격회피0.5, 투사체 인지0.50/예측0.28초, 공격 의도 우선. 엄호: 공격0.85, DEF1.15, 처음 배치 좌표 기준 가까운 아군을 묶고 아군/투사체 앞을 지킵니다. 성향은 계속 개별 길드원에 저장됩니다.

## 6. CharacterAbility 구조 / 파일

CharacterAbility는 생성·타겟·이동·공격 허용·프로필·발동·피격·처치·사망·궁극기·투사체 접촉 등의 정책 훅입니다. AbilityRegistry가 type_id→파일을 선택합니다. ComboAbility만 두 연격의 공통 단계 진행을 공유합니다. CharacterCombat/Lifecycle/Persistence는 피해 확장 순서와 순수 ID 관계를 담당하고 공통 DamageResolver/PhysicalAttackSystem/ParryController를 재사용합니다.

**생성 파일(UID 제외):**

- `data/assassin.tres`
- `data/bomber.tres`
- `data/dolphin.tres`
- `data/fanatic.tres`
- `data/frog.tres`
- `data/galaxy.tres`
- `data/greatsword.tres`
- `data/guardian.tres`
- `data/healer.tres`
- `data/hero.tres`
- `data/lightning.tres`
- `data/machine_gun.tres`
- `data/mage.tres`
- `data/mirror.tres`
- `data/paladin.tres`
- `data/predator.tres`
- `data/puppet.tres`
- `data/rps.tres`
- `data/satellite.tres`
- `data/shotgun.tres`
- `data/sniper.tres`
- `data/swordsman.tres`
- `data/tank.tres`
- `data/ufc.tres`
- `migration/phase7-before-phase8.tar.gz`
- `migration/phase8-web-catalog.json`
- `migration/phase8-web-sha256.json`
- `scripts/abilities/archer_ability.gd`
- `scripts/abilities/assassin_ability.gd`
- `scripts/abilities/bomber_ability.gd`
- `scripts/abilities/dolphin_ability.gd`
- `scripts/abilities/fanatic_ability.gd`
- `scripts/abilities/frog_ability.gd`
- `scripts/abilities/galaxy_ability.gd`
- `scripts/abilities/greatsword_ability.gd`
- `scripts/abilities/guardian_ability.gd`
- `scripts/abilities/healer_ability.gd`
- `scripts/abilities/hero_ability.gd`
- `scripts/abilities/lightning_ability.gd`
- `scripts/abilities/machine_gun_ability.gd`
- `scripts/abilities/mage_ability.gd`
- `scripts/abilities/mirror_ability.gd`
- `scripts/abilities/paladin_ability.gd`
- `scripts/abilities/predator_ability.gd`
- `scripts/abilities/puppet_ability.gd`
- `scripts/abilities/rps_ability.gd`
- `scripts/abilities/satellite_ability.gd`
- `scripts/abilities/shotgun_ability.gd`
- `scripts/abilities/sniper_ability.gd`
- `scripts/abilities/swordsman_ability.gd`
- `scripts/abilities/tank_ability.gd`
- `scripts/abilities/ufc_ability.gd`
- `scripts/abilities/warrior_ability.gd`
- `scripts/ability_registry.gd`
- `scripts/battle_brain.gd`
- `scripts/battle_zones.gd`
- `scripts/character_ability.gd`
- `scripts/character_catalog.gd`
- `scripts/character_combat.gd`
- `scripts/character_lifecycle.gd`
- `scripts/character_persistence.gd`
- `scripts/combo_ability.gd`
- `scripts/equipment_combat_effects.gd`
- `scripts/projectile_rules.gd`
- `scripts/transcendence_controller.gd`
- `scripts/ultimate_controller.gd`
- `tests/character_ui_smoke.gd`
- `tests/phase8_batch_runner.gd`
- `tests/phase8_runner.gd`
- `tests/phase8_tests.gd`

**수정 파일:**

- `data/archer.tres`
- `data/warrior.tres`
- `project.godot`
- `scripts/area_evaluator.gd`
- `scripts/attack_data.gd`
- `scripts/attack_instance.gd`
- `scripts/battle_clock.gd`
- `scripts/battle_manager.gd`
- `scripts/battle_unit_factory.gd`
- `scripts/combat_controller.gd`
- `scripts/combat_perception.gd`
- `scripts/combat_rules.gd`
- `scripts/damage_resolver.gd`
- `scripts/deployment_screen.gd`
- `scripts/dodge_controller.gd`
- `scripts/enemy_plan_executor.gd`
- `scripts/enemy_state_codec.gd`
- `scripts/guild_manager.gd`
- `scripts/knockback_controller.gd`
- `scripts/movement_controller.gd`
- `scripts/parry_controller.gd`
- `scripts/physical_attack_system.gd`
- `scripts/projectile.gd`
- `scripts/retreat_controller.gd`
- `scripts/room_battle_screen.gd`
- `scripts/status_controller.gd`
- `scripts/strategy_card_executor.gd`
- `scripts/strategy_effects.gd`
- `scripts/target_selector.gd`
- `scripts/threat_response_controller.gd`
- `scripts/turning_point_manager.gd`
- `scripts/unit.gd`
- `scripts/unit_data.gd`
- `scripts/unit_state_codec.gd`
- `tests/combat_ui_smoke.gd`
- `tests/deployment_ui_smoke.gd`
- `tests/phase2_tests.gd`
- `tests/phase3_tests.gd`
- `tests/phase4_tests.gd`
- `tests/phase5_tests.gd`
- `tests/phase6_tests.gd`
- `tests/phase7_tests.gd`
- `tests/room_ui_smoke.gd`
- `tests/strategy_ui_smoke.gd`
- `tests/test_runner.gd`
- `tests/turning_ui_smoke.gd`

## 7. 캐릭터별 기본공격

아래 표는 실제 실행에 연결된 훅 기준입니다. 단순 Dictionary 운반만으로 능력을 완료 처리하지 않았습니다.

| 종류 | 기본공격 / 궁극기 | 패시브·수비 | AI 정책 | 주요 상태 |
| --- | --- | --- | --- | --- |
| 0 전사 | 검격 / 천공참 | 공통·고유 패링과 반격 대시 | 돌격 | parry 관련 공통 필드 |
| 1 궁수 | 화살 / 거대 관통 화살 | 매 3번째 부채 3발·벽 2회 도탄 | 후열·대치 | shotsFired |
| 2 마법사 | 마법탄·주변 폭발 / 블랙홀6초 | HP≤50% 공속1.3·이속1.35, 치명적 전이 | 후열·신중 | transferUsed |
| 3 암살자 | 단검 / 완전 은신10초 | 가득 찬 HP 치명+10%p, 궁극기 치명+15%p·피해0.8·공속0.75 | 낮은 현재HP→후열→거리 | revealTime / shadowTime |
| 4 수호자 | 방패 / 최저HP 아군 무적10초 | 비중첩 오라+22 DEF, 자신0.8 피해·방벽0.45 | 최저HP 아군 호위 | guardianUltTime |
| 5 힐러 | 빛탄·치유 / 치유 장판10초 | 상처입은 아군 / 혼자 자신 치유 | 전열 아군 뒤 지원 | heal |
| 6 대구경 저격수 | 5초 조준 관통탄 / 다음 삼연발 | 4700 탄속·좁은 퍼짐·근접 밀쳐내기30% | 안전한 구석 | sniperBurstReady |
| 7 샷건 | 산탄7발·거리 감쇠 / 궁극기 없음 | 탄창2·장전4초·강한 반동 | 돌격 / 장전시 후퇴 | ammo / reloadRemaining |
| 8 가위바위보 마스터 | 붙잡기·가위바위보 / 패자50% 승부 | 매3판 승리 보정·외부피해0.2/0.35 | 대치·무작위 가까운 승부 상대 | duelRounds; duel 자체는 재생성 |
| 9 UFC 선수 | 3연펀치 / 링 돌진·10초 로프 | 마무리1.35배·강한 넉백 | 근접 종류 우선 | 일반 공격 combo는 비지속 |
| 10 두비두밤 | 특대검 / 관통 충격 | 4초 방어·스택6%·이속15%·검 놓침15%·회수 | 검 회수 / 돌격 | guardRemaining / guardStacks / guardReady / pickupTime / lostSword |
| 11 챌런 | 박치기·축소 / 다중 박치기 | 누적손실10%마다0.94 크기·이속4%, 저주6초 | 방황 | damageTakenTotal / dolphinStacks / curseTime |
| 12 포식자 | 전방 최대3명·13% 처형 / 20% 처형 | 처치시 크기4%·HP10%·최대2.4배 | 돌격·짧은 전진 | predatorStacks |
| 13 폭탄 | 지연 폭탄 / 왕폭탄 | HP20% 자폭 돌진·퓨즈·사망 후 폭발 | 후열·대치 / 최후 돌진 | bomberRush / bomberRushTime / bomberFuse |
| 14 검객 | 전진3연격·마지막 회전3배 / 2200 대시 후 경로참격3.6배 | 고립 공격1.3·피격 연격 중단 | 고립 적 우선 | 적 ultCast; 일반 연격은 비지속 |
| 15 소형 위성 | CC 적 미사일 / 3+아군수 강화 미사일 | 피격0.16초 후4발·공격20% | 방황·CC 남은 시간 우선 | satelliteBursts |
| 16 성기사 | 강타0.65·참격1.25 / 범위회복20%·공격1.3 10초 | 주변 아군당 공격·DEF5% | 호위 / 궁극기 아군 집결 | paladinSwings / paladinBlessingTime |
| 17 히어로 | 펀치 / 최고 누적 피해 적 돌진·4.2배 펀치 | 치명피해 무효·1050 돌진·보호막60/10초·충격2초 기절 | 군집 적 우선; 궁극기는 damageDealt 우선 | heroRescueUsed / damageDealt는 전투당 초기화 |
| 18 탱크 | 포탄·폭발 / 강화 화염포·장판5초 | 후방피해1.75·느린 차체/포신 회전 | 거리 유지 | tankFlameReady / tankHeadingAngle / face |
| 19 광신도 | 단검 / 성자 게이지20%p | 성자 피해10%·사망 후 피해/공속1.3·받는피해1.2 | 성자 의존 / 사망후 돌격 | 성자 관계·광분은 재설정 |
| 20 번개 마법사 | 최대5회 전이 번개 / 원형 방출2.6배·감전2 | 최근2명 제외·전이피해0.9·감전4개 기절2.5초 | 후열·대치 | shockStacks; 전이 큐 비지속 |
| 21 금간 거울 | 4회 도탄 빛 / 반사3초 | 도탄마다1.2·실제HP손실10% 파편 | 대치 | mirrorReflectTime |
| 22 은하 | 넓은 부채 별5개 / 추적 지평선7초 | 첫 생성때 가장 먼 적 피해0.7·범위270 아군탄 흡인 | 대치 | cosmicMarked는 재설정; 장판은 비지속 |
| 23 기관총 | 중앙 가중 난사 / 안전방향850 대시·장전 | 20발·4초 장전·탄속4200·반동30·시전중 추적4rad/s | 대치 / 장전중 이속0.4 | ammo / reloadRemaining / shotsFired |
| 24 개구리 | 혀·당기기·머금기·유닛 발사 / 치명피해 아군 구출 | 현재HP 높은 적 우선·삼킨 최대HP60당10% 피해 | 휴식 후 점프 | cargo/hop은 정산 전에 해제; 게이지 지속 |
| 25 인형술사 | 실3발 / 조종의 실7초 | 실제HP 피해30%를 연결2명 분담 | 대치 | puppetControl; 링크는 새로 선정 |

## 8. 캐릭터별 패시브

7번 표의 패시브·수비 열과 해당 abilities script의 피격/처치/발동 훅을 사용합니다. 공통 패링과 특수 구조/분담 순서는 중앙 처리기와 연결합니다.

## 9. 캐릭터별 고유 AI

7번 표의 AI 정책 열이 일반 Brain의 타겟·이동·공격/궁극기 허용 정책을 바꿉니다. 파생 코드가 공통 공격 물리를 다시 구현하지 않습니다.

## 10. 캐릭터별 persistence

7번 표의 상태 열과 CharacterPersistence.FIELDS를 사용합니다. 시계/스택은 실제 runtime에 연결되며, lostSword/puppetControl/적 ultCast는 별도 순수 ID 변환을 사용합니다. 투사체·영역·승부/cargo/AI는 재생성됩니다.

## 11. UltimateController

충전, 자동충전, 생각 시계, ready age, uses, 캐스트와 준비 상태 요청을 분리했습니다. gauge100 즉시 사용으로 바꾸지 않았습니다. 각 Ability의 상황/거리/대상 판정을 거칩니다. 샷건은 궁극기 없고 개구리는 치명적 구조에서만 소비합니다.

## 12. 궁극기 충전 공식

```text
자동 = 1.5%p × simulation_delta × efficiency
피해 = 실제HP손실 또는 보호막 흡수 / 자신의 maxHP
       × (가한 피해65 / 받은 피해90)
       × (암살자1.3 / 전사1.2 / 나머지1) × efficiency
효율 = (암살자 은신 또는 수호 유지 중0.2, 그외1)
       × (길드원 기력 결손당 −7%)
카드/성자/토템 = 각 경로의 실제 gainUltimate 값
```

stun·조종·root/bind/snare 조건·포획/비행·승부·blackhole CC/taunt 등 crowdControlRemaining 조건은 충전을 막습니다. **충전 금지와 이미 찬 궁극기 사용 금지는 같은 조건이 아닙니다.** 예를 들어 도발/조종은 충전을 막지만 기존 gauge100의 사용 자체를 일괄 금지하지 않습니다. 장비 인벤토리는 아직 없으며 치유/충전 토템과 healingPower 입력 훅만 연결했습니다.

## 13. 궁극기 AI

ultThink0.35~0.95초, ultReadyAge>4의 긴급 판단, 실제 거리·HP·군집·부상 아군·탄창·성자 조건을 사용합니다. 수호자/힐러/성기사 등 지원 궁극기와 공격 궁극기의 위험 이탈 처리가 다릅니다. 철벽/패링·공격중·도주·포획·가위바위보·특대검 상태를 확인합니다. 성기사 집결, 탱크 이미 강화탄 준비, 기관총 장전 필요 조건은 특수 계획이 있어도 유지합니다.

## 14. 궁극기 cast 구조

순수 t/duration/angle/point/target actor ID와 고유 phase·remaining·targets·origin·hits를 갖습니다. 검객은2200 속도로 적을 관통한 뒤 경로 전체에 독립 참격을 생성합니다. 히어로는900 추격 후0.25초 펀치 준비. 궁극기 준비 중 stun은 시간을 멈추며 검객/히어로의 진행중 대시는 중단됩니다.

## 15. ultCast persistence

EnemyRoomState.persistent_state.ultCast에 순수 데이터로 저장합니다. member:/enemy:room_id:enemy_id를 참조하므로 새 battle_id로 복원해도 재연결됩니다. 없어진 대상은 안전하게 처리합니다. 아군 일반 시전 단계/AI/투사체/장판은 유지하지 않고 적 시전만 복원하는 기존 웹 철학을 유지했습니다.

## 16. 초월 HTML 조사

| 항목 | 실행 코드 |
| --- | --- |
| 보유 | 타워 아군. 커스텀은 모든 팀 시험 가능 |
| 증가 | 실제 피해/maxHP × 가한12·받은16 × 기력 충전효율; 자동 없음 |
| 제한 | CC/조종/포획·궁극기 시전·구조·방어태세·종료 중 불가 |
| 입력 | hold0.16초, deadzone32, 방향 끌기·중앙 취소 |
| 시간 | aim/cast 중 세계 정지, cast1.15 real seconds |
| 검격 | windup0.38·active0.2, 이동34, reach310·cone1.08 |
| 피해 | 공격력5배+60, impulse380, transcendent 경로 |
| TP | ready는 TP hold를 배제하지 않음; 초월중 TP real timer도 정지 |
| 유지 | 아군 transGauge 유지. aim/cast는 재생성 |

## 17. 구현한 초월

BattleClock에 TRANSCENDENCE_AIM/CAST를 추가했습니다. 길게 누르기→방향 지정→취소/발동을 연결하고 다른 모든 유닛과 simulation time을 동결합니다. 종료시 이전 NORMAL/TP hold로 복귀합니다. 자신의 초월 피해로 자신의 초월 게이지를 다시 채우지 않습니다. 임시 보라 방향선·시전 cut-in/타 UI 숨김을 표시하며 정식 픽셀 VFX는 복제하지 않았습니다. 커스텀 전투 전체 UI/모든 팀 연습 리필은 아직 별도 모드가 없어 추가하지 않았습니다.

## 18. 캐릭터 구현 결과

26종은 생성·기본공격·궁극기(샷건 없음/개구리 반응형 예외)·상태 운반·TP 동결·보호막 상호작용·종료 동결을 검사했습니다. 복잡한 순서와 각 패시브는 별도 golden/상호작용 검사로 보강했습니다. 모든 프레임의 DOM 연출 또는 모든 조합의 승률을 검증한 것은 아닙니다.

## 19. scale / 대형 유닛

챌런 max(0.4,0.94^손실스택), 포식자 min(2.4,1+0.04×처치스택), 저주0.65를 곱합니다. 몸 충돌24×양측scale합, 근접27×target scale, 탄환 radius+27×(target scale−1), 몸 질량×max(0.7,scale)와 공격 reach/판정을 연결했습니다. 배치 최소 간격58은 유지하며 크기별 새 배치 규칙을 만들지 않았습니다.

## 20. stealth / perception

일반 암살자는 공격/피격 노출3초, 근처160 이내 인식, 궁극기 은신은 거리와 관계없이 적 인식 차단. 공격 경고는 전방240도이며 hidden launch/현재 은신 공격자는 경고·회피를 허용하지 않습니다. 도발→focus→고유 일반 정책 순서, 개구리/위성의 웹 특수 선행 선택 예외를 유지합니다.

## 21. damage sharing

인형술사의 보호막 적용 후 잠재HP 피해30%를 반올림해 연결된 생존 아군 최대2명에 분배합니다. 나머지 피해에 구조/처형 검사를 하고 원본 HP·사망을 처리한 뒤 분담을 적용합니다. 분담 피해는 보호막·무적·구조와 상호작용하고 재분담/반사 재귀를 유발하지 않습니다.

## 22. reflect

반사 유지중 차단은 공통 패링/무적/보호막보다 먼저 실행되고 같은 위력의 실제 피할 수 있는 반사탄을 생성합니다. 일반 파편은 실제HP손실10%만 반환하고 mirror_shard가 추가 파편을 만들지 않습니다. reflected_damage는 반사 차단에서 예약된 투사체 위력이며 추후 탄환이 적중했다는 보장은 아닙니다.

## 23. rescue

HP0 확정·사망 이벤트보다 먼저 히어로→개구리 순서로 검사합니다. 히어로는 행동/CC를 정리하고1회 사용표시, 대상 보호→돌진→충격/기절→보호막60/10초. heroRescueUsed는 웹처럼 전투당 재설정되고 TOWER whitelist에 넣지 않았습니다.

## 24. swallow / cargo

삼킨 유닛의 HP·원래 소유·현재 팀은 유지됩니다. 포획/hold/비행 동안 일반 타겟·이동·공격·충전을 차단합니다. 혀/몸체는 실제 연속 충돌·반사·패링/상쇄를 사용합니다. 사망·stun·전체 종료/후퇴 정산 전에 cargo를 해제하며 새 방에 Node/Projectile을 저장하지 않습니다.

## 25. puppet control

source_member_id/source_enemy_id와 original_team은 바꾸지 않고 current team만7초 변경합니다. 승패는 원래 진영, 적 상태 저장은 원래 enemy_id를 사용합니다. 복원은 원래 진영의 성자/코스믹/실 연결을 만든 뒤 조종을 적용해 웹의 setup→restore 순서를 보존합니다.

## 26. lostSword

실제 비행0.6초, 속도480, 좌표35~765, 근처34에서0.25초 회수. 방 상태에는 x/y 대신 dx/dy를 저장하고 재배치 위치에 상대 복원합니다. guardReady/스택 소비와 공격/궁극기 불가 상태를 연결했습니다.

## 27. self-destruct

HP20%→돌진→근처78 또는3.5초 경과시0.6초 퓨즈. 자신의 사망을 먼저 단발 기록한 후165 범위·공격2.5배 폭발을 적용합니다. Player HP가 사망 손실로0이 된 경우 기존 Run 종료 우선 규칙이 추가 피해를 차단합니다. 히어로 구조와 승패 순서 golden을 검사했습니다.

## 28. Phase5 plan 통합

special은 실제 gain/AI readiness로 연결됩니다. stun으로 gain이 거부돼도 ready 플래그·age5 요청은 유지. 샷건은8초 special·cooldown0·ammo2·reload0. focus와 retreat는 기존 ID/우선순위/도주 계약을 사용하고 현재 인식 가능한 유효 적을 선택합니다.

## 29. Phase6 카드 통합

망고주스는 수신 healingPower; 충전은 gainUltimate의 실제 차단; 보호막/철벽은 공통 방어; 전투회피/도발은 hold 중 pending, 재개시 적 계획→아군 evade→taunt 순서. 26종 모두 여섯 카드의 사용/예외와 TP special을 검사했습니다. TP와 조종/포획 관계가 소유권을 바꾸지 않습니다.

## 30. 재도전 복원

후퇴/패배→단발 정산→살아있는 길드원 재배치→적 HP/위치/상태/시전 복원. 아군은 Formation 시작 위치, 적은 종료 위치. 조종·lostSword·cast ID 골든을 추가했습니다. AI 계획과 일반 공격 단계/장판은 새로 생성됩니다.

## 31. ally cooldown 정책

실전 full mode에서 아군도 cooldown을 snapshot/restore하도록 변경했습니다. 웹 TOWER_STATE_FIELDS에 양측 cooldown이 있으므로 Phase2의 당시 제외 계약을 확장한 것입니다. Phase2 역사적 비교 검사는 명시적 minimal mode로 유지하고 Phase8 full room 두 시도 검사에서3.7초가 그대로 이어짐을 확인합니다.

## 32. 신규 테스트

phase8_tests: catalog, Batch별 characters, golden_damage, golden_states, golden_relationships, targets_and_charging, transcendence, projectile_goldens, room_persistence_and_cards, extra_interactions, persistence_whitelist, all_character_cards_and_plans, control_retry_golden, mixed_performance, projectile_stress. phase8_batch_runner는 독립 단계 확인, character_ui_smoke는 실제 Control/input 경로입니다.

## 33. 캐릭터별 검사

공통 캐릭터 루프는 각10개 전투 검사(샷건/개구리9개 예외), 생성 fixture 검사를 포함합니다. 별도 26종 카드/plan 루프와 아래 골든으로 고유 규칙을 검사합니다. 종류 데이터/프로필 전체도 추출 JSON과 비교합니다.

## 34. 상호작용 검사

오라 방어, 분담과 보호막, 반사와 보호막/무적, 치명 구조와 폭탄, cargo 정산, 조종/원래 진영/재도전, lostSword 상대 복원, 감전 전이, 도탄, 부채/산탄/탄창/반동, MG 시전중 추적, 궁극기 시전중 후퇴, 특대검/축소/처형, 도발 충전 차단과 기존 게이지 사용, 초월 자신 게이지 재충전 금지, item 입력 훅, TP/card 재개 순서.

## 35. Phase1~7 결과

| 단계 | 검사 | 실패 |
| --- | ---: | ---: |
| Phase1 | 9705 (14판) | 0 |
| Phase2 | 243 | 0 |
| Phase3 | 131 | 0 |
| Phase4 | 119 | 0 |
| Phase5 | 110 | 0 |
| Phase6 | 118 | 0 |
| Phase7 | 3148 | 0 |

## 36. Phase8 결과

최종 실행 로그 기준: 15개 그룹 / 9776개 검사 / 실패0. 단계별 독립 Batch smoke는 별도152개 검사입니다.

## 37. 전체 검사 수 / 실패

test_runner 총 23350 / 실패0. GUI는 기존101 + 신규19 =120 / 실패0. 독립 Batch152, workspace/clean/X11 재실행은 총검사에 중복 합산하지 않습니다. 로그는 [phase8-validation.txt](migration/phase8-validation.txt)에 보관합니다.

## 38. GUI 검사

기존 deployment18/room17/turning18/strategy23/combat25를 유지했습니다. 신규 character19는26종 선택·길드원/적 생성·실전 모드·모바일 TP/초월 입력·전체 후퇴·살아있는 진형 복원을 검사합니다. [PC](migration/phase8-desktop.png) / [모바일](migration/phase8-mobile.png).

## 39. 실제 창 검사

X11 + Mesa llvmpipe + Dummy audio로 실제 창을 열고 자동 입력을 검사했습니다. 사람이 직접 플레이했다고 주장하지 않습니다. 모바일390×844에서 재개/초월 아이콘이 화면 안에 있으며 터치 hold·방향·발동·TP 복귀를 확인했습니다. V-Sync 미지원 드라이버 경고는 게임 script error와 구분합니다.

## 40. 성능 검사

12vs12 혼합3판, MG6·번개3·마법사2·힐러1씩의 투사체/장판 전투를 추가했습니다. finite 좌표/HP, 활성 Node/공격 객체 상한, 종료 cleanup·freeze를 검사합니다. Godot queue_free의 프레임말 지연 삭제는 실제 활성 Node와 구분했습니다. 새 FPS 목표나 통계 기반 밸런스 변경은 없습니다.

- PHASE8 MIXED seed=101 simulation=67.4666666666641 wall_ms=22291 peak_projectiles=10 peak_strikes=3 reason=0
- PHASE8 MIXED seed=205 simulation=35.2666666666659 wall_ms=16957 peak_projectiles=9 peak_strikes=1 reason=1
- PHASE8 MIXED seed=307 simulation=67.1333333333308 wall_ms=28028 peak_projectiles=10 peak_strikes=2 reason=1
- PHASE8 PROJECTILE STRESS sim=15.566666666667 wall_ms=9761 peak_projectiles=10 peak_zones=7 shots=295

## 41. 웹과 Godot의 남은 차이

- 정식 웹 UI/픽셀 연출·사운드·카메라·킬로그·마지막 타격 시네마는 복제하지 않았습니다. 임시 도형/이모지/상태/방향선/cut-in입니다.
- 커스텀 전체 화면·모든 팀 초월 리필 UI는 현재 단일 room 디버그 흐름과 별개이며 아직 없습니다.
- 타워 방 생성·층·성장/장비 획득/경제를 만들지 않았습니다. 토템/healingPower는 입력 계약만 있고, 방/보스 레벨 stats assembler는 Phase9 범위입니다.
- 좌표는 Godot Vector2 float32, RNG와 AI 함수 호출 배열은 JS와 다릅니다. 동일 프레임 궤적/동일 시드 승률이나 모든 조합의 완전 일치를 주장하지 않습니다.
- 웹 문구와 실행 차이를 보존: 개구리 타겟은 최대HP가 아니라 **현재HP**, 번개는 최초1+최대5회 전이, 챌런 축소는 크기/판정과 받는피해를 바꾸며 기본 ATK Resource 자체를 낮추지 않음, hero passive는 전투당 재설정.
- Phase4의 첫 승리30% 회복·전체 타워 보상/Player HP 연출은 이번 범위에서 추가하지 않았습니다.

## 42. 웹 SHA-256

작업 전후 dist19파일 일치. JS17/HTML1/CSS1. [phase8-web-sha256.json](migration/phase8-web-sha256.json). Godot 외 추적 파일 git diff도 없습니다. 배포 사이트를 변경/재배포하지 않았습니다.

## 43. MIGRATION_NOTE

1. 공유 UnitData/개별 GuildMemberState/전투 Unit/RoomEnemy identity를 계속 분리합니다.
2. current team과 original team/소유는 다릅니다. 조종은 소유권을 이동하지 않습니다.
3. battle_id는 cast/관계 저장키가 아닙니다. 적 actor ID는 room 범위를 포함합니다.
4. 일반 AI·공격·투사체·장판·cargo는 scene 전체 저장으로 만들지 않습니다.
5. 아군 일반 cooldown을 full contract에 추가했으며 옛 minimal 비교는 명시적으로 유지합니다.
6. 기본DEF는 일반 피해를 그대로 줄이지 않습니다. 추가 오라/배율 차이만 armor입니다.
7. scale 충돌은 동적이지만 배치 최소58은 유지합니다.
8. 충전 차단과 사용 차단은 별개이며 초월은 수동 개입입니다.
9. 토템/치유 입력 계약은 장비 인벤토리/획득 구현 완료를 의미하지 않습니다.
10. full 모드 기본값을 실전에서 끄지 않습니다. 테스트 helper만 비교 모드를 요청합니다.
11. 기존 UI/debug 보호를 위한 flag는 제작 모드 선택이며 타입 감지/테스트 탐지 분기가 아닙니다.
12. 노드 지연삭제와 누수, 실제시각 UI 시간과 simulation 시간을 구분합니다.
13. Godot의 확률 정책 포팅을 JS와 동일한 RNG 시드/이동 결과라고 주장하지 않습니다.
14. 최종 VFX/사운드와 Phase9 타워 진행은 시작하지 않았습니다.

## 44. Phase8만 되돌리기

작업 시작 전에184파일을 묶었습니다. archive SHA-256: `3d869b75a0bcce789aeb98a097a83dccdc27d549b88cf24f3f9d0a29144f7bf0`.

```bash
cp godot/migration/phase7-before-phase8.tar.gz /tmp/duni-phase7-restore.tar.gz
mv godot godot-phase8-backup
mkdir godot
tar -xzf /tmp/duni-phase7-restore.tar.gz -C godot
godot --headless --path godot --editor --quit
godot --headless --path godot --script res://tests/test_runner.gd
```

복구 명령은 실행하지 않았습니다. 기존 웹은 복구 대상이 아닙니다. 변경 목록은 [phase8-file-audit.json](migration/phase8-file-audit.json).

## 45. Phase9 전에 필요한 사항

- 실제 타워 Encounter 레벨/보스/body_scale·성장 stats를 종류 Resource와 분리해서 주입할 계약.
- 장비 보유/장착에서 healingPower·토템 수·고유 성장 입력을 공급할 계약.
- 모든 상점/이벤트/보상 정책을 현재 tower.js 실행 코드로 다시 조사할 것.
- 실전 common/full 모드를 고정하고 비교 모드를 테스트에만 명시할 것.
- 세이브/로드가 없으므로 RunState/EnemyRoomState/actor ID를 순수 데이터로 보존하는 저장 설계를 별도 단계에서 결정할 것.

실행: Godot에서 `godot/project.godot`을 열고 F5. 명령 검증:

```bash
godot --headless --path godot --editor --quit
godot --headless --path godot --script res://tests/test_runner.gd
godot --path godot
```
