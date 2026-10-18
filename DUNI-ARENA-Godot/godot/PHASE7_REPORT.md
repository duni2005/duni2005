# DUNI ARENA — Godot Phase 7 완료 보고

2026-10-11 · Godot **4.6.3.stable.official.7d41c59c4** · 저장소 실행 코드 기준. Phase 8은 시작하지 않았습니다.

전사·궁수에 공통 패링, 전사 반격, 추가 방어, 기절, 무적, 넉백/충돌 피해, 근접/투사체 상쇄와 최소 인지 반응을 연결했습니다. 자유 배치 → TP/전략카드 → 후퇴/승패 → 단발 정산 → 동일 방 재도전이 유지됩니다. 웹 `dist/` 19개 파일은 SHA-256으로 **19/19 일치**합니다.

**실행 모드와 검증 범위:** F5의 `room_battle.tscn`은 `common_combat_enabled=true`로 새 공통 규칙을 사용합니다. `BattleManager`의 기본값은 `false`이며 Phase 1의 독립 씬/기존 수치 비교 API는 최소 규칙으로 보존했습니다. 새 Phase 7 검사와 F5 GUI는 새 규칙을 켭니다. 따라서 기존 Phase 1~6 수치 검사 통과를 새 피해 계산의 검증이라고 주장하지 않습니다. 새 계산은 별도 Phase 7 검사로 검증했습니다. 테스트에 따라 자동으로 모드를 바꾸는 숨은 분기는 없습니다.

## 1. 생성 파일

| 파일 | 역할 |
| --- | --- |
| `scripts/combat_rules.gd` | 스탯·성향·피로·추가 방어·JS 반올림 계산 |
| `scripts/attack_instance.gd` | 공격 ID·위력·피해·기하·수명·적중 집합의 순수 런타임 데이터 |
| `scripts/physical_attack_system.gd` | 근접/투사체 연속 판정, 접촉 시각 정렬, 상쇄 적용 |
| `scripts/clash_resolver.gd` | 위력 비교·돌파 확률·남은 피해/위력·파동 계수의 순수 계산 |
| `scripts/parry_controller.gd` | 공통 패링, 접촉별 성공 롤 캐시, 반격·파동 요청 |
| `scripts/combat_wave.gd` | 기절·넉백 파동의 simulation 수명과 단발 적중 |
| `scripts/status_controller.gd` | 기절·행동 중단·현재 지원하는 스킬 충전 차단 조건 |
| `scripts/knockback_controller.gd` | 누적 속도·질량·감쇠·벽/유닛 충돌 피해 |
| `scripts/combat_perception.gd` | 대상 인식과 240도 공격 경고 시야의 분리 |
| `scripts/dodge_controller.gd` | 94 거리 / 0.22초 이동 회피 |
| `scripts/threat_response_controller.gd` | 준비 동작/투사체 인식, 반응 확률·지연·오패링 |
| `scripts/area_evaluator.gd` | 현재 구현된 군집 위험의 평가와 제한된 위치 이탈 |
| `tests/phase7_tests.gd` | 새 규칙을 켠 11개 검사 그룹과 12판 자연 전투 |
| `tests/combat_ui_smoke.gd` | PC/390×844 터치 UI, 실제 패링/상쇄·TP·후퇴·재도전 |
| `migration/phase6-before-phase7.tar.gz` | 작업 직전 Phase 6 원본 147파일 복구 자료 |
| `migration/phase7-web-sha256.json` | 보호한 웹 파일 19개 SHA-256 |
| `migration/phase7-validation.txt` | workspace/캐시 없는 복사본/X11 실행 기록 |
| `migration/phase7-*.png` | GUI 검사 캡처 4개 |
| `migration/.gdignore` | 검증 자료를 게임 에셋으로 import하지 않도록 분리 |
| `PHASE7_REPORT.md` | 이 보고서 |

새 스크립트·검사에는 Godot 생성 `.gd.uid`도 포함합니다. 별도의 거대 Manager, 타워 지도, 캐릭터 26종을 만들지 않았습니다.

## 2. 수정 파일

- `data/archer.tres`
- `data/warrior.tres`
- `scripts/attack_data.gd`
- `scripts/battle_manager.gd`
- `scripts/combat_controller.gd`
- `scripts/damage_outcome.gd`
- `scripts/damage_resolver.gd`
- `scripts/enemy_plan_executor.gd`
- `scripts/movement_controller.gd`
- `scripts/parry_readiness.gd`
- `scripts/projectile.gd`
- `scripts/room_battle_screen.gd`
- `scripts/strategy_card_executor.gd`
- `scripts/strategy_effects.gd`
- `scripts/target_selector.gd`
- `scripts/unit.gd`
- `scripts/unit_data.gd`
- `scripts/unit_state_codec.gd`
- `tests/test_runner.gd`
- `README.md`: 현재 실행 모드와 최신 보고서 링크.

`UnitData`/전사·궁수 Resource에는 방어 위력만, `AttackData`에는 impulse만 추가했습니다. 기존 HP·ATK·이동·사거리·공격 시간·치명타 수치를 변경하지 않았습니다. `Unit`은 runtime 상태, `CombatController`는 공격/반격, `DamageResolver`는 처리 순서, `BattleManager`는 simulation 연결을 담당합니다. `StrategyEffects`는 whitelist, 카드/적 계획 실행기는 기절/인지 연결, `TargetSelector`는 우선순위와 인식 검사를 담당합니다. 기존 Phase 검사 파일들은 `test_runner.gd`의 Phase 7 호출 추가를 제외하고 바이트 단위로 보존했습니다.

## 3. DamageResolver 처리 순서

현재 두 종류에 필요한 웹 분기를 다음 순서로 옮겼습니다.

1. 전투/대상/진영/유한 입력 검사. 일반 공격의 치명타 1.5배와 공격자 피로 계수.
2. 공통 완전 패링 시도. 성공 시 즉시 차단하고 별도 반격 피해·기절·파동을 처리.
3. 무적 또는 **보이는 공격에 대한** evade 창 검사.
4. 받는 피해 성향/피로, 추가 방어 `100/(100+armor)`, 60초 이후 전투 피해 증가를 적용해 JS 방식 반올림.
5. 패링 후반부 60% 경감, 신중함/궁수의 피격 회피, 전사의 별도 고유 패링.
6. 보호막 흡수 → 실제 HP 손실. 넉백은 보호막 적용 **전** impact amount로 계산.
7. 살아 있는 대상에 impact momentum 적용 → 단발 사망 알림 → 살아 있는 전사의 반격 대시 예약.

`Unit.receive_damage(..., defer_death=true)`는 공통 경로에서 사망 알림을 impact 단계 뒤로 미룹니다. 기본 두 인자 API는 기존 즉시 사망 처리를 유지합니다. 죽은 대상은 넉백되지 않는 것도 웹의 `applyKnockback`과 같습니다.

충돌 피해는 별도 분기입니다. null/같은 팀 source도 허용하고, 치명타/전투 시간 배율/일반 패링 성공 롤/피격 회피를 사용하지 않습니다. 무적 → 공통 패링 창 factor → 받는 피해/추가 방어 → 보호막 → HP/사망 순서입니다. 반격/상쇄 recoil은 일반 패링·경감·회피를 재귀적으로 유발하지 않지만 무적·보호막·추가 방어의 영향을 받습니다.

`DamageOutcome`의 attempted/resolved/shield_absorbed/hp_damage를 보존하고 avoided/invulnerable/parried/damage_reduced를 추가했습니다. reflected_damage는 미래 반사용 0 초기값이며 반사 기능은 구현하지 않았습니다. Resolver가 VFX를 그리지 않습니다.

## 4. 방어력 실제 웹 규칙

`app.js:30–32`, `combat.js:41–45,108,130`을 기준으로 했습니다.

```text
전사 기본 defensePower = 26 / 궁수 = 18
unitDefense = max(1, (baseDefense + additionalDefense) × (엄호 ? 1.15 : 1))
combatArmor = max(0, unitDefense − baseDefense)
일반 피해 방어 계수 = 100 / (100 + combatArmor)
패링 성공률은 unitDefense 전체를 사용
```

따라서 기본 방어력 26/18을 곧바로 일반 피해 감소에 쓰지 않습니다. 엄호 전사는 추가 armor 3.9, 궁수는 2.7이 생깁니다. 수호자 방어 오라·성기사 배율은 해당 캐릭터가 없어 미구현이며 `additional_defense`가 확장 지점입니다.

저돌적 ATK ×1.25 / 받는 피해 ×1.20, 신중함 ATK ×0.80 / 추가 피격 회피 10%, 엄호 ATK ×0.85가 공통 계산에 반영됩니다. 기력에 따른 피해 계수도 실제 웹 순서대로 공격자 `1−missing×.05`, 피격자 `1+missing×.03`을 사용합니다. 게이지 충전 효율의 기력 계수는 실제 능력/충전 시스템 단계로 남겼습니다.

## 5. 공격 power 구조

`AttackInstance.damage`와 `.power`는 별개입니다. 웹 `spawnMeleeStrike`처럼 처음에는 같은 공격값으로 생성되지만, 상쇄 돌파 후 damage ×.45 / power ×.70으로 달라집니다. 치명타는 접촉 시 피해에 적용하며 물리 상쇄의 power를 치명타로 바꾸지 않습니다.

중요한 웹 동작: 일반 근접/화살은 `resolveDamage`에 별도의 `attackPower`를 넘기지 않습니다. 그러므로 기본 패링 성공 비교는 기본적으로 **치명타·공격자 피로 적용 후 incoming damage**를 사용합니다. `options.attack_power`를 명시한 경우 그 값을 사용합니다. 상쇄용 power를 모든 패링에 강제로 대입하지 않았습니다.

## 6. ParryController

availability / start / perfect / success_chance / try_block / reprisal을 분리했습니다. 성공 롤은 공격 token별로 캐시하고, 반격 피해/파동은 해당 창에서 공격자 ID별로 중복 방지합니다. `parry_counter_used`는 전사 반격 대시를 한 번으로 제한합니다. `parry_pulse_used`만으로 모든 후속 공격자의 파동을 막지는 않습니다. 웹은 공격자별 feedback 집합을 실제 중복 검사에 사용하기 때문입니다.

## 7. 패링 수치

| 항목 | 실제 코드 값 |
| --- | --- |
| 기본 cooldown | 12 simulation seconds |
| 전체 parryTime | 1.2초 |
| 성공 창 | `parryTime > .8 + 1e−8`, 시작 약 .4초 |
| 후반 경감 창 | 남은 약 .8초, 피해와 impulse ×.4 |
| 성공 확률 | `min(1, clamp((defense/max(1,power))^1.2,.08,1) × (신중함 ? 1.25 : 1))` |
| 반격 raw damage | `round(clamp(defender.dmg×.65 + incomingPower×.1,10,30) × strength)` |
| 반격 strength | 공통 성공 1 / 전사 고유 완전 1 / 전사 고유 부분 .75 |
| 공격자 기절/넉백 | 1.3초 / 640 force |
| 주변 파동 | 반경220, 주변 적 .7초 기절, force470 |
| 전사 고유 피격 패링 | 별도 readiness가 있을 때 완전 확률 `.2×successChance`, 아니면 피해 `ceil(amount×.5)` |

전사 고유 패링은 공격이 뒤에서 와도 시도되는 웹 분기를 보존했습니다. 뒤 공격에 대한 **인지/회피 금지**와 이미 활성화된 패링의 방어 범위를 혼동하지 않았습니다.

## 8. 철벽방어 연결

카드가 ironDefense 15초와 readiness 초기화를 부여합니다. 실제 ParryController가 그 동안 시작한 패링에 cooldown 3초를 적용합니다. 상태 종료 후 다음 패링의 기본 cooldown은 12초입니다. 기존에 시작한 cooldown을 종료 시 임의로 12초로 늘리지 않습니다. 기절 상태에서 카드로 readiness를 초기화해도 즉시 패링 행동은 불가능합니다.

## 9. stun 구현

simulation 시간, max(existing,duration), stunRevision을 사용합니다. 기절 부여 즉시 일반 공격/근접 판정, 패링 창, 이동 회피, 전략 대시, 자발적 이동과 반응 계획을 중단합니다. 살아 있는 기절 유닛의 일반 cooldown은 계속 감소합니다. 이미 발사된 투사체와 외부 넉백은 계속 진행합니다.

프레임 시작에 있던 stun만, 새 stunRevision이 없을 때 그 프레임 delta만큼 감소시킵니다. 새 패링/상쇄 파동에 걸린 유닛은 부여된 전체 시간을 받습니다. `skill_charge_blocked`는 현재 지원하는 기절에 대해 충전을 막고, 충전 카드/적 special의 게이지 증가에도 연결했습니다. 실제 궁극기/초월 능력은 여전히 미구현입니다.

## 10. invincible 구현

지속시간은 simulation timer입니다. 일반 HP 피해·보호막 소모·그 공격의 새 넉백을 차단합니다. 웹의 순서대로 공통 패링을 먼저 시도하므로 무적 유닛도 활성 패링으로 반격할 수 있습니다. 기존 momentum이나 파동에 의한 기절/밀림까지 무적이 제거하는 것으로 변경하지 않았습니다.

## 11. 근접 AttackInstance

공격 ID, source battle ID, 팀, 타입, shape, power, damage, impulse, 각도, reach/cone, 시작/종료 위치, 적중 ID 집합, age/duration/life를 담습니다. Node 참조는 없습니다.

전사 blade는 소유자의 **현재 위치**에서 25~reach 선분으로 생성하며 `angle−cone + 2×cone×age/active`로 휘두릅니다. 1/120 이하 slice에서 5개 시간 표본, 몸 접촉 반경27을 사용합니다. 일반 피해 active가 끝나도 상쇄 grace .12초 동안 판정이 남습니다. hit 집합은 접촉을 **실제 처리할 때** 갱신합니다. path shape의 선분/폭 공통 판정도 검사했지만 검객 궁극기 등 고유 기능을 생성하지 않았습니다.

## 12. 투사체 변경

화살 Node는 표현과 previous_position/현재 위치/속도를 보관하고 AttackInstance는 공격 위력/기하/중복 적중을 보관합니다. body hit은 이차식으로 프레임 구간을 검사합니다. 고속 화살이 프레임 사이를 통과하는 검사를 추가했습니다. 일반 화살은 한 번 적중하면 제거되고, 사망한 발사자의 이미 발사된 화살도 물리적으로 남습니다.

화살 body 반경26 / 상쇄 반경7, 수명2.4초, 전투 경계20~780을 유지합니다. Actor 이동 경계28~772와 별개입니다. 궁수 세 번째 부채 도탄은 구현하지 않았습니다.

## 13. ClashResolver

순수 compare/weakening 계산과 실제 물리 적용을 분리했습니다. 실제 제거/기절/넉백/recoil HP 피해/파동은 PhysicalAttackSystem이 담당하며 그림을 그리지 않습니다. 근접↔근접, 투사체↔투사체, 근접↔투사체를 같은 AttackInstance 비교 경로로 처리합니다.

## 14. 상쇄 계산

```text
high <= max(.01,low) × 1.3 → 양쪽 파괴
차이가 더 큼 → 돌파 확률 clamp(.6 + (high/max(.01,low)−1.3)×.16,.6,.95)
돌파 성공 → 약한 공격 파괴 / 강한 damage×.45, power×.70
돌파 실패 → 양쪽 파괴
```

상쇄의 위력 우세가 항상 확정 돌파가 되는 것으로 바꾸지 않았습니다. 양쪽 주인 recoil HP 피해는 상대 power를 기준으로 `max(2,round(clamp(power×.16,3,18)×(winner?.55:1)))`입니다. 근접 취소 기절 .3초(무승부)/.25초(패배), cooldown 최소 .8/.7초.

주변 파동 반경 `clamp(130+high×.55,140,270)`, 기절 `clamp(.12+sqrt(high)×.035,.15,.55)`, force `clamp(180+high×2.2,210,450)`입니다. 주인들은 파동에서 제외됩니다. 접촉 시간 동률이면 상쇄를 몸 적중보다 먼저 처리합니다.

## 15. KnockbackController

누적 momentum을 자발적 이동 velocity와 분리했습니다. 일반 force는 아래 실제 공식입니다.

```text
min(980, impulse × 2.1 × clamp(sqrt(impactDamage/max(1,source.dmg)),.5,2)
         / clamp(sqrt(target.maxHp/160),.85,1.5))
```

최대 누적 속도1080, 질량 `clamp(sqrt(maxHp/160),.8,1.6)`, 감쇠 `exp(−step×4.6)`을 사용합니다. 공격 발동의 자체 전진90/화살 반동60은 웹처럼 momentum에 더하며 다음 physics step에서 최대 속도를 적용합니다. knockback source/chain은 현재 전투에만 남습니다.

## 16. 유닛/벽 충돌

Node2D 명시적 계산을 유지했습니다. scale1인 두 종류의 접촉 거리48.5 미만, 닫히는 속도65 이상에서 impulse `closing×1.12/(inverseMassA+inverseMassB)`를 교환합니다. 같은 pair에 .2초 cooldown을 둡니다. closing160 이상이면 A는 .65×closing, B는 closing으로 충돌 피해를 계산합니다.

벽에서는 위치를28~772로 제한하고 부딪힌 momentum 성분을 −.24배로 반사합니다. force160 이상 충돌 피해 raw는 `max(1,round((force−100)×.055×sourceFatigue))`입니다. 정지 중 겹친 유닛을 좌표 강제 이동으로 순간이동시키지 않으며, 거리58 미만의 일반 steering으로 공간을 벌립니다. RigidBody2D를 사용하지 않았습니다.

## 17. 시야/인지

`canPerceive`는 타겟을 알 수 있는지, `inAttackView`는 공격을 볼 수 있는지를 구분합니다. 전사·궁수는 은신 능력이 없어 살아 있는 일반 적을 인식합니다. 공격 경고의 전방 총 시야는240도(좌우120도), float32 Vector2 경계 오차만 1e−6 rad 허용합니다. 뒤/hiddenLaunch/hidden source는 회피 경고를 주지 않습니다.

runtime hidden hook은 확장 지점이며 암살자의 160거리 발견/궁극기 은신/개구리 상태 전체를 구현했다고 주장하지 않습니다. 실제 해당 캐릭터 이전 때 `can_perceive`를 확장해야 합니다.

## 18. 공격 위험 대응

보이는 준비 동작을 거리 `reach+90` 및 대상/공격 각도 조건으로 읽습니다. 공격마다 한 번 반응 롤을 만들고 .09~.26초 관찰 지연(신중함×.72/저돌적×1.45)을 둡니다. 낮은 HP에서 패링/회피를 더 선호하며 패링, 측면 이동 회피, 맞공격, 대기를 구분합니다.

패링 lead .17~.31초, 잘못된 timing 확률 일반30%/신중함15%, 너무 이른 경우 .45~.95초 앞당김 또는 늦은 경우 .35~.75초 지연을 보존했습니다. 투사체는 상대 속도·.65초 예측·body miss 거리로 판단하고 notice 확률 일반.84/신중함.93/저돌적.50 및 horizon .46/.56/.28을 사용합니다. 피격 회피는94거리/.22초 이동입니다.

AreaEvaluator는 현재 두 종류에서 실제 존재하는 적 밀집 pressure만 계산합니다. 세 명 이상 적의 <210범위 pressure에서 <200범위 아군 support를 빼고, 무적/보호막 인지 계수를 적용합니다. 웹의 목표 후보 반경95/185/285 ×12방향과 경로4지점 평가를 사용합니다. 없는 블랙홀/화염/회복 장판을 만들지 않았습니다. full createBrain, 진입 계획, 공격 initiative/commit, 안전구역/전열·후열은 남아 있으므로 웹 AI 전체와 같은 전황을 주장하지 않습니다.

## 19. TargetSelector 우선순위

도발 → 집중 → 가까운 유효 적을 유지합니다. 도발/focus도 타겟 인식을 확인하며, 시야 방향 밖이란 이유만으로 일반 타겟을 잃게 하지는 않습니다. 도발 후보 선택은 적이 해당 아군을 인식할 수 있는지 확인합니다. 현재 두 종류에서는 둘 다 visible입니다.

## 20. 상태 persistence

| 값 | Phase 7 runtime/주입/회수 |
| --- | --- |
| defenseCooldown / parryCooldown / parryTime | 숫자 timer, 적용 및 복원 |
| parryCounterUsed / parryPulseUsed | bool, 별도 검증/복사 |
| shieldHp / shieldTime / ironDefenseTime | 실제 방어·패링에 연결 |
| stun / invincible | 실제 timer 및 제한에 연결 |
| face | 음수 각도도 유지 |
| HP / ultGauge / ally transGauge / stance | 기존 개별 상태 계약 유지 |
| test_counter 등 순수 고유 데이터 | deep-copy 왕복 유지, 고유 기능 자체는 미구현 |
| enemy normal cooldown / retreatRemaining / specialRemaining | 기존 Phase 4~6 계약 유지 |

공통 whitelist는 웹 `tower.js:193,669–671`에서 재확인했습니다. 캐시 롤/반격 대상 집합, 이동 velocity/momentum/chain, 일반 공격 객체, 투사체/파동, Target Node, UI Node는 저장하지 않습니다. 웹은 ally cooldown도 whitelist에 두지만 현재 ally 일반 공격 cooldown은 Phase 2 계약대로 재생성합니다. 적 cooldown과 공통 방어 cooldown은 실제 복원합니다.

## 21. TP와 상태 시간

기존 BattleClock을 변경하지 않고 simulation_delta 경로에 연결했습니다. hold에서는 이동/AI/공격 cooldown/active age, parry·stun·무적·보호막·철벽 timer, momentum·투사체·파동을 모두 동결합니다. 실제 전략 제한시간/UI 입력만 진행합니다. 새 TP 검사에서 모든 상태/공격/파동/투사체 스냅샷을 비교했습니다. 첫12·다음42/72, brake2real sec, hold40real sec 규칙이 유지됩니다.

## 22. 후퇴/재도전 연결

현재 전투 snapshot에 공통 방어·상태 timer를 덧씌웁니다. 후퇴/패배/승리 단발 정산과 member_id / enemy_id 소유권은 그대로입니다. 적은 HP/마지막 위치/whitelist, 아군은 HP/상태와 Formation의 **시작 위치**로 새 Unit을 생성합니다. 현재 프레임의 공격·투사체·파동은 복원하지 않습니다. 후퇴 시간20 simulation seconds, 사망 손실 cost×.05, 일반 패배 추가20, Player HP0/길드 생존자 없음 종료는 기존 검사를 보존했습니다.

## 23. 전사 검증 결과

거리 기반 즉발 피해를 새 blade 판정으로 연결했습니다. 공통 패링과 별도 전사 고유 패링, 반격 .19/.16/.25초·reach125·impulse300·damage×1.25, 반격 windup 대시, 기절/넉백/상쇄를 검사했습니다. 전사 궁극기는 구현하지 않았습니다.

## 24. 궁수 검증 결과

고속 body 구간 판정, 발사 후 owner 사망, 근접/화살/화살 상쇄, 공통 패링, 시야 경고, 피격 회피, momentum을 연결했습니다. 궁수 기본 공격 수치를 바꾸지 않았으며 세 번째 부채 도탄/궁극기는 남아 있습니다.

## 25. 신규 테스트

`Phase7Tests`의 11그룹은 패링 창/확률/중복 반격/철벽, 피해 순서/기본·추가 방어/치명타/죽음, 기절·이동 회피, 근접/path/고속 투사체, 상쇄 세 조합·돌파·감소·파동, 넉백 감쇠/벽/연쇄, 시야·공격 준비·반응·도발/focus, 실패 패링/뒤·은신 공격, hold 완전 동결/상태 왕복/단발 정산, 카드 자동 resolve/실제 철벽/동률 우선순위/군집 위험/기력/기절 중 special 충전, 자연 전투를 검사합니다.

자연 전투는 seed3/29/101의 전사↔전사, 전사↔궁수, 궁수↔궁수, 3↔3 총12판입니다. 새 common mode에서 모두 종료됐고 위치/velocity/momentum 유한성, 경계, HP 범위, 사망 단발성, 종료 후 동결을 검사했습니다. 전투 위력 차이의 stochastic branch는 고정 seed와 순수 계산 검사로 검증했습니다.

## 26. Phase 1 결과

**9,705 검사 / 14 완료 전투 / 실패0.** 최소 비교 모드. 원래 검사 본문을 수정하지 않았습니다.

## 27. Phase 2 결과

**243 검사 / 실패0.** 개별 ID·상태 독립·2연전 HP·기력·단발 정산 보존.

## 28. Phase 3 결과

**131 검사 / 실패0.** 자유 배치·58간격·영역·중복 방지·Formation 보존.

## 29. Phase 4 결과

**119 검사 / 실패0.** 후퇴·패배·적 상태·예비 길드원·Player HP·게임오버 보존.

## 30. Phase 5 결과

**110 검사 / 실패0.** TP 스케줄·감속/hold·성향·forecast·resume·후퇴 충돌 방지 보존.

## 31. Phase 6 결과

**118 검사 / 실패0.** 6종 카드·사용 제한·즉시/pending·정산/런 사용 기록 보존. 기존 raw 피해 수치 검사는 최소 비교 모드이며, 실제 새 패링/철벽/기절과 카드 연결은 Phase 7과 F5 GUI가 검증합니다.

## 32. Phase 7 결과

**11그룹 / 3,148 검사 / 실패0.** 새 공통 규칙 활성화. 자연 전투 12판 모두 종료.

## 33. 전체 검사 수 / 실패 수

단일 전체 검증 실행 기준 test_runner **13,574 / 실패0**, GUI **101 / 실패0**(기존76+신규25), 합계 **13,675 / 실패0**입니다. 반복 실행으로 숫자를 부풀리지 않았습니다. 같은 검사를 workspace와 `.godot/`가 없는 source 복사본에서 실행했고, GUI 5종을 X11에서 다시 실행했습니다. editor import·script parse·scene load 모두 성공했습니다.

## 34. GUI 검사

headless와 X11의 deployment18 / room17 / turning18 / strategy23 / common combat25 모두 실패0. X11은 Mesa llvmpipe의 실제 OpenGL 창입니다. 390×844에서 터치 대상·카드·재개/후퇴/재도전과 최소 240 표시 폭을 검사했습니다. HP/shield/stun/parry cooldown/active/iron/momentum 디버그 값을 표시합니다. 최종 UI나 전투 VFX는 구현하지 않았습니다.

캡처: [PC 패링](migration/phase7-desktop-parry.png), [모바일 hold](migration/phase7-mobile-hold.png), [모바일 상쇄](migration/phase7-mobile-clash.png), [모바일 재도전](migration/phase7-mobile-retry.png). 조밀한 유닛의 작은 디버그 문구는 겹칠 수 있으며 최종 레이아웃은 후속 작업입니다.

## 35. 실제 창 검증

별도 X11 창에 XTest 운영체제 마우스 입력을 보내 배치/시작 → 첫 TP → 망고40→85·신중함 → 자동 재개 → 전체 후퇴 → 동일 방 재도전 → 두 번째 시도의 실제 패링/상쇄/충돌 → 수동 재개를 관찰했습니다. 두 번째 hold에는 body_collision3 / clash4 / hit27 / parry_start2 / parry_success1 / warrior_parry2 / wave_stun3이 기록됐습니다.

첫 시도에는 입력 확인용 초기 HP/높은 공격 cooldown fixture를 사용했고, 재도전에서는 새 아군이 실제 공통 전투를 진행했습니다. 사람의 수동 테스트라고 표현하지 않으며 OS 입력 기반 자동 조작입니다. 최종 X11 smoke는 audio Dummy로 실행했고, 일반 창 probe의 ALSA 미지원 경고는 사운드 기능과 무관합니다.

## 36. 실제 HTML 규칙 조사 표

| 규칙 | 실행 코드 | 옮긴 값/동작 |
| --- | --- | --- |
| 종류 방어 | app.js CHARACTER_DEFENSE | 전사26 / 궁수18 |
| 기본 공격 | combat.js ATTACK_PROFILES | 전사 .38/.17/.25·108·1.45·245 / 궁수 .43/.14/.22·410·.35·135 |
| 공통 패링 | combat.js basicParry* | cd12, time1.2, perfect>.8+epsilon, late×.4 |
| 성공 확률 | combat.js parrySuccessChance | (defense/power)^1.2, .08~1, cautious×1.25 |
| 고유 전사 패링 | combat.js resolveDamage | readiness, 20%×chance 완전 / 나머지50% 피해 |
| reprisal | combat.js parryReprisal | dmg×.65+power×.1 clamp10~30, attacker1.3/640, wave220/.7/470 |
| 전사 반격 | combat.js queueParryCounter | .19/.16/.25, reach125, impulse300, dmg×1.25, windup dash |
| 보호막·무적 순서 | combat.js resolveDamage | parry→invincible/evade→reduction→shield→HP→impact→death |
| 추가 armor | combat.js combatArmor | unitDefense−baseDefense의 양수분만 |
| 전투 장기화 | combat.js resolveDamage | 1+max(elapsed−60,0)/70 |
| clash grace/arc | physical.js constants/clashBlades | .12 / [−.075,0,+.0375] |
| power/돌파 | physical.js resolveClash/weakenClashWinner | 1.3 draw, .60~.95 확률, power .70 / damage .45 |
| 상쇄 파동/피해 | physical.js clashWaveProfile/clashRecoilDamage | 본문14 공식 |
| motion/contact | combat.js advancePhysics/physicsCollision | max1080, decay4.6, wall−.24, scale1거리48.5/closing65 |
| collision HP | combat.js collisionDamage | force160+, (force−100)×.055, 별도 방어 경로 |
| 시야/감지 | ai.js inAttackView/canSeeAttack | 총240도, hidden/rear 회피 경고 없음 |
| 준비 반응 | ai.js threatResponseChances/planParryTiming | HP/성향/ready 확률 및 정상·early·late |
| 투사체 경고 | ai.js projectileThreat | relative sweep 예측 .65, notice/horizon 성향 계수 |
| 기절 유지 | combat.js advanceCombat | 기존 stun만 tick, 새 revision은 전체시간 유지 |
| persistence | tower.js TOWER_STATE_FIELDS/snapshot* | 본문20 whitelist; 공격 객체/물리·AI는 제외 |

`dist/strategy.js`의 forecast→아군 evade→taunt→재개 순서도 유지했습니다. 기절 special plan은 웹의 gainUltimate가 충전을 거부하되 readiness flag는 세우는 동작을 따릅니다. 위 값은 배포의 문구나 예전 요청 수치로 추측하지 않았습니다. 이번 Phase의 별도 배포 플레이 재검사는 하지 않았고 현재 저장소 실행 코드를 우선했습니다.

## 37. 웹과 Godot의 남은 차이

전사·궁수만 있으며 full AI/initiative/공격 중 일반 steering, 암살자 은신, 24종 고유 능력·패시브, 궁극기/초월/일반 게이지 충전, 장비 효과·오라, 저주/속박/피해 분담/반사/구조, 스케일별 몸체, 타워 지도/상점/모집/이벤트/성장·세이브는 미구현입니다. 이로 인해 동일 배치의 웹 결과를 완전히 재현한다고 주장하지 않습니다. 일반 pursuit는 기존 최소 AI를 유지하고 위협/군집 반응만 확장했습니다.

웹의 공통 피해 순서를 현재 두 종류가 사용하는 분기에 맞췄으며, 존재하지 않는 능력을 가짜로 만들지 않았습니다. ally 일반 cooldown 재생성과 적 transGauge 비저장은 기존 Phase 계약/웹 enemy snapshot 차이를 유지합니다. 첫 승리 생존자30% 회복은 이전 Phase 결정대로 여전히 제외합니다.

## 38. 웹 원본 해시

작업 시작/종료 dist의 JS17개·HTML1개·CSS1개 **19/19 SHA-256 일치 / 변경0**입니다. 개별 해시는 `migration/phase7-web-sha256.json`, 실행 기록은 `migration/phase7-validation.txt`에 있습니다. tracked `git diff`도 비어 있습니다. 기존에 전체 godot/이 untracked였으므로 Phase 7만 `git restore`로 되돌릴 수는 없습니다. 별도 commit이나 배포는 하지 않았습니다.

## 39. MIGRATION_NOTE

1. 기본 방어력과 추가 armor의 현재 웹 차이를 보존했습니다. 밸런스 수정과 이전을 섞지 않습니다.
2. 물리 power와 패링 incomingPower의 기본 입력은 동일하지 않을 수 있습니다. 일반 공격의 attackPower 미전달을 그대로 따릅니다.
3. 전사의 고유 피격 패링은 공통 인지 기반 패링과 별도입니다. 고유 분기를 삭제하면 피격/반격 수치가 달라집니다.
4. 무적은 이미 켜진 패링/외부 momentum/파동 전체의 무효화가 아닙니다.
5. 기절은 공격을 취소하지만 이미 발사된 화살/외부 momentum은 유지합니다. 새 stunRevision은 프레임 끝에 바로 감소하지 않습니다.
6. parry feedback 집합/성공 롤은 저장하지 않습니다. 재도전에서 캐시가 새로 생기는 현재 웹 범위를 보존합니다.
7. ally 일반 attack cooldown은 Phase 2 계약으로 재생성됩니다. 웹 whitelist의 양 진영 cooldown 유지와 차이가 남아 있습니다.
8. 근접/혼합 상쇄는 웹과 같은 5표본과 시간 여유 판정입니다. body/화살↔화살은 연속 이차식이지만 초고속 혼합 상쇄의 표본 누락 가능성은 웹에도 있어 임의 CCD 변경을 하지 않았습니다.
9. 두 타입 scale1만 옮겼습니다. 대형 유닛의 충돌/넉백 질량은 별도 이전이 필요합니다. 배치58 규칙을 신체 충돌48.5 규칙으로 바꾸지 않습니다.
10. 전체 createBrain/안전장판/고유 시야·은신은 남아 있습니다. 실제 없는 장판을 평가 대상으로 추가하지 않습니다.
11. 실제 능력 소비자는 StatusController의 기절 차단 및 parry/evade/attack 조건을 재검사해야 합니다. TP special hook은 준비 요청이며 능력 실행이 아닙니다.
12. 자동/피해 기반 궁극기·초월 충전과 피로의 충전 계수는 미구현입니다. 충전 카드/forecast의 현재 기절 제한만 연결했습니다.
13. 전투 simulation은 BattleClock만 따라갑니다. presentation time/Engine.time_scale/Scene 전체 저장을 새 규칙으로 만들지 않았습니다.
14. 새 생성 경로는 common_combat_enabled=true를 명시해야 합니다. 기존 비교 모드를 이후 실전 타워 호출부에 잘못 사용하지 않도록 확인해야 합니다.

## 40. Phase 7만 되돌리는 방법

현재 Phase 7 폴더를 먼저 보관한 뒤, 포함한 archive를 별도 위치로 복사하여 Phase 6을 복원합니다. 아래 명령은 **설명이며 실행하지 않았습니다.** 저장소 루트에서:

```bash
cp godot/migration/phase6-before-phase7.tar.gz /tmp/duni-phase6-rollback.tar.gz
mv godot godot-phase7-backup
mkdir godot
tar -xzf /tmp/duni-phase6-rollback.tar.gz -C godot
godot --headless --path godot --editor --quit
godot --headless --path godot --script res://tests/test_runner.gd
```

`godot-phase7-backup`이 이미 있으면 다른 미사용 이름을 선택합니다. archive 147파일 전부가 작업 전 manifest와 일치함을 확인했습니다. archive SHA-256:

`22f3f948189805b6e7301f0a4a56e20bcfc1918618d6935b2c8212eb26aa1e4d`

복원 후 Phase 6 기준은 test_runner10,426 / 기존 GUI76입니다. 웹 dist는 건드리지 않습니다.

## 41. Phase 8 전에 필요한 사항

- 실제 전투 호출 경로에서 공통 모드를 기본화할지, 비교 모드 설정을 별도 테스트 구성으로 옮길지 결정.
- full AI/성향 이동/initiative·엄호 위치 판단의 다음 이전 범위를 확정. 현재 minimal pursuit를 full AI라고 취급하지 않기.
- 실제 Ultimate/Transcendence 소비자의 기절·패링·회피 조건, 충전/소비 시점과 준비 hook 연결을 결정.
- ally 일반 cooldown 유지 차이를 별도 정책으로 정하기. 이번에 임의 변경하지 않음.
- guardian/paladin armor·축소/스케일·특수 투사체·반사/공유/구조를 각각 실제 코드 분기로 추가하고 golden 예제를 마련.
- 현재 방/개별 ID/Formation 책임과 순간 공격 객체 분리를 유지. 보상/지도/상점/이벤트를 이번 전투 계층에 끼워 넣지 않기.

직접 실행은 저장소 루트에서 `godot --path godot` 또는 Godot4.6.3에서 `project.godot`을 열고 F5입니다. 메인 씬은 자유 배치 디버그 방이며 TP/카드/20초 후퇴와 동일 방 재도전을 확인할 수 있습니다. 검증 명령:

```bash
godot --headless --path godot --editor --quit
godot --headless --path godot --script res://tests/test_runner.gd
godot --headless --path godot --script res://tests/combat_ui_smoke.gd
```

Phase 8은 시작하지 않았습니다.
