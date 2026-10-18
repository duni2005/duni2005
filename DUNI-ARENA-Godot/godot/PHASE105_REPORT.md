# Phase 10.5 — AI 움직임·전투 행동 일치도 개선

기준일 2026-10-14 UTC, **Godot 4.6.3.stable.official.7d41c59c4**. 기존 Phase1~10을 유지하며 원본 실행 순서·판단 수명·이동 정책을 수정했습니다. 웹 원본 19개와 기존 종류/공격/장비/카드 Resource는 그대로입니다. Phase11은 시작하지 않았고 온라인 미리보기도 재배포하지 않았습니다.

원본과 직접 실행한 Golden 정책은 일치합니다. 일반 RNG로 실행한 대표 전투에서는 평균 거리·첫 피격·공격/회피 빈도 등 일부 지표의 오차가 줄었지만, 첫 공격·총 이동 거리·전투 종료 시간은 모든 사례에서 개선되지 않았습니다. **전투 모습 전체가 원본과 동등해졌다고 주장하지 않습니다.** 아래 비교는 그 한계를 포함합니다.

## 1. 조사·비교 방법과 보호 기준

`dist/ai.js`, `combat.js`, `app.js`, `archetypes.js`, `novel.js`, `strategy.js`, `rear-galaxy.js`, `hero-tank.js`, `faith-lightning.js`, `frog.js`, `puppet.js`, `ultimate.js`, `physical.js`, `tower.js`의 실행 분기를 확인했습니다. 기존 `tests/arena-harness.cjs`로 실제 index의 17개 스크립트를 순서대로 평가했습니다. DOM/Canvas만 대체하고 게임 함수를 복제하거나 대체하지 않았습니다.

비교는 세 가지로 분리했습니다.

1. 정책 Golden: 양쪽의 입력 상태·brain 값 일치, 실제 JS 함수 결과를 Godot 결과와 비교. Vector2 오차 허용 0.003 논리 픽셀.
2. 초기 2초 전체 tick: 전사 1v1의 네 entry plan, 초기 속도/brain/방향을 일치시켜 실제 `step`과 `BattleManager.simulate` 비교.
3. 일반 전투: 같은 종류·배치·성향·seed 번호, 서로 다른 RNG를 그대로 사용. 25개 20초 표본과 13개 최대90초 표본. seed 번호가 같아도 random stream이 같다는 뜻은 아닙니다.

작업 시작 당시 Godot 452개 파일을 `migration/phase10-before-phase105.tar.gz`에 보관했습니다. 정확한 변경/추가 목록은 `migration/phase105-file-changes.json`, 웹 SHA-256은 `migration/phase105-web-sha256.json`에 있습니다.

## 2. 원본의 한 simulation tick

`dist/combat.js:139`의 `advanceCombat`, `dist/app.js:136–137`, `dist/ai.js:89` 기준입니다.

1. 초월 동결 확인 → elapsed 증가.
2. 조종·개구리 상태 → tick 시작 기절 기록/행동 중단 → 방어 timer.
3. 표현 timer·고유 timer·장비·패시브·장판·승부 상태.
4. 살아 있는 유닛을 배열 순서대로 처리. 사망/삼켜짐/개구리 action은 제외.
5. 성향 수치 → 궁극기 자동 충전/고유 timer → 일반 cooldown·heal·dash 등 감소.
6. 기절이면 행동 중단 + 외력 물리만 진행하고 다음 유닛.
7. 고유 tick/위성 burst → 첫 위협 대응. 승부·방어태세는 일반 행동 차단.
8. 인지 가능한 적/아군 수집 → target 선택.
9. 히어로 구조 → 폭탄 돌진 → 전략 대시 → 기관총 대시 → 회피 motion. 해당 분기가 처리했으면 물리 후 다음 유닛.
10. `advanceCombatExchange`: 거리 관찰 → 두 번째 위협 대응 → 공격 종료 인식 → initiative 판단.
11. 궁극기/counter가 아니면 긴급 폭탄 회피 → 일반 이동 dispatch. 행동 불가면 velocity/heading 0.
12. 공격/cast가 없을 때 target 방향으로 몸 회전 → 외력 물리.
13. 궁극기 사용 판단/cast → 기존 공격 진행 → 힐러 치유 시작 → 기본 공격 시작.
14. 물리 공격·파동·고유 앵커 → revision으로 기절 감소 → 종료 판정.

두 번째 위협 호출은 같은 준비동작을 다시 뽑는 확률 호출이 아닙니다. 이미 예약한 read/response를 처리합니다. 이 중복 호출을 없애거나 매 호출마다 반응을 다시 뽑으면 원본과 달라집니다.

## 3. Godot 변경 전·후 순서

| 지점 | 변경 전 | 변경 후 |
| --- | --- | --- |
| 일반 cooldown | 이동 이후 CombatController에서 감소 | full mode는 판단 이전 감소, 이중 감소 방지 |
| 궁극기 | 충전·사용·cast가 이동 전에 한 묶음 | 충전과 사용/cast를 분리, 이동·물리 뒤 사용/cast |
| 위협 | 공통 loop에서 한 번 | 공통 loop + exchange에서 read-idempotent 두 번째 호출 |
| 캐릭터 이동 | 여러 Ability가 일반 정책보다 먼저 반환 | 원본 dispatch의 명시적 예외 순서 |
| 후열 | 후보를 매 frame 다시 선정 | source의 rear timer·target/anchor invalidation |
| heading | 경로별 별도 heading·이동 시작 velocity 초기화 | 공유 heading, 이전 자발 velocity 유지, 분기별 source steering |
| 힐러 치유 | Ability tick과 같이 공격 전 시작 | 기존 공격 진행 후 치유 처리 |
| 공격 완료·intent | 후속 판단과 취소 조건이 일부 다름 | source의 wasAttacking/commit/disengage/next initiative |

Godot은 관계/고유 timer를 `CharacterLifecycle`, 장판을 `BattleZones`, 유닛별 능력을 Ability로 나눠 호출합니다. 모든 캐릭터의 global pass 순서까지 JS와 완전히 동일하게 재배열한 것은 아닙니다. 기존 구조를 유지하면서 이번에 확인한 일반 판단/이동/공격 순서를 맞췄습니다.

## 4. 주요 차이 원인과 수정 파일

| 파일 | 변경 |
| --- | --- |
| `battle_brain.gd` | source precommit·defensive·rear·stance·일반 이동, initiative/intent 수명, 공유 steering, debug snapshot |
| `movement_controller.gd` | 행동 불가·대시·폭탄·패링·반응·area·forced·일반 정책 순서, 이전 velocity 유지 |
| `target_selector.gd` | 엄호 anchor 확보 시점, 원본 target 우선순위 유지 |
| `area_evaluator.gd`, `battle_zones.gd` | prospective/route/support 평가, safe reference와 판단 유지 |
| `threat_response_controller.gd` | 치유 windup 제외, 시간 예약, hold/counter 동작, 공격별 impact delay, bomb 인지 cache 유지 |
| `combat_controller.gd`, `battle_manager.gd` | cooldown 호출 위치, 실제 profile의 공격 시작 gate, tick 순서 |
| `ultimate_controller.gd` | 충전과 사용/cast의 호출 책임 분리, 기존 수치 유지 |
| `status_controller.gd`, `parry_controller.gd`, `physical_attack_system.gd` | CC·패링·상쇄 시 원본 transient intent 재설정 |
| `strategy_movement_controller.gd`, `strategy_command_executor.gd`, `enemy_plan_executor.gd` | forced 명령·공유 heading·source cancel intent |
| `turning_point_manager.gd` | live 성향 변경 시 source brain 필드 재설정 |
| `character_ability.gd`, `unit.gd` | 이동 override·impact delay hook, 독립 unit phase, 불필요한 legacy RNG 소비 제거 |
| Ability 9개 | 광신도·기관총·샷건·위성 좌우 부호, 탱크 회전, 저격수 정지, 성기사 우회, 검 회수 속도, 챌런 sway |
| `deployment_board.gd`, `room_battle_screen.gd` | 선택 유닛 AI debug, 모바일 emulated mouse 중복 선택 방지 |

`Vector2.orthogonal()`은 `(y,-x)`이고 source의 일반 좌측 벡터는 `(-y,x)`였습니다. 해당 경로의 부호를 수정했습니다. 모든 perpendicular를 일괄 뒤집지 않았습니다. danger 우회 후보의 원본 `[-1,1]` 순서는 따로 보존했습니다.

## 5. decision cadence와 timer

전투 세계 시간이 기준입니다. UI real time이나 frame별 독립 확률을 사용하지 않습니다.

| 상태 | 실제 원본 규칙·갱신 조건 |
| --- | --- |
| 최초 think/hold | 0.2–0.65 / 0.7–1.6초 |
| reaction trait / tempo | 0.14–0.29 / 0.55–1.8 |
| 최초 initiative | 0.4–3.8초 × tempo |
| intent | initiative 0.18–0.95, pressure 0.06–0.55, counter/punish 0.06–0.42 × tempo; 신중함 ×1.15 |
| commit | 기본 진입 시간과 이동에 필요한 시간을 고려, 최대 접근 보정4.5초 |
| hesitation | 조건 충족 시 0.32×patience를 0.15–0.48 clamp, 최대2회; 재시도0.25–1.6 ×tempo |
| 공격 종료 인식 | next initiative = max(now,disengage) + 0.3–2.3 ×tempo, 신중함 ×1.25 |
| 공격 release 후 이탈 | 일반0.6–1.3, 대치/신중1.1–1.7초; 호위 return0.8–1.4 |
| 거리 closing 측정 | 최소0.08초가 누적될 때 갱신 |
| 상대 공격 소모 관찰 | opening1.25–1.9초, probe0.08–0.6 ×tempo |
| rear 재선정 | 적<210이면0.18–0.4, 그 외0.5–1초; target/anchor 변경 시 즉시 무효화 |
| area 최초 판단 | 0.12–0.6초 |
| area 반복 판단 | 0.45–0.95 ×patience, 선택한 계획의 만료/위험 감소/지원 소실에 따라 reset |
| windup read | 새 준비동작을 한 번 읽고 반응 시간을 예약; 반복 frame에서 같은 roll 재소비 안 함 |

`think`/`hold`는 일반 이동 branch가 호출될 때 감소합니다. 모든 유닛의 모든 frame에서 같은 일반 plan을 새로 선택하는 구조로 바꾸지 않았습니다. source에서 실제로 소비되지 않는 `targetClock`을 타겟 유지 timer로 새로 사용하지 않았습니다.

## 6. 초기 진입과 observe/circle/bait/flank

`entry_plan`과 현재 `mode`는 별개입니다. 최초 initiative 전에 무조건 중앙으로 접근하지 않습니다. 가까운 경우 거리를 벌리며, 먼 경우 observe는 작은 측면 이동, circle은 더 큰 측면 이동, feint는 시간에 따른 작은 전후 변위, flank는 더 큰 측면 진입을 사용합니다.

일반 mode의 feint는 hold가 0.65초를 넘는지에 따라 접근/이탈하고, flank는 target의 측면 후보 좌표를 향합니다. circle은 유지 거리의 radial 보정과 측면 벡터를 같이 씁니다. 이름만 넣은 상태가 아니라 실제 x/y·velocity·heading을 source와 대조했습니다.

네 entry plan을 같은 초기 brain/속도/방향으로 맞춘 **2초 전체 tick, 0.25초 간격** 검사: **320개, 실패0, 최대 좌표 오차0.000378픽셀**. 이는 정규화된 진입 비교이며 일반 전투의 stochastic 궤적 일치를 뜻하지 않습니다. 자료: `phase105-web-openings.json`, `phase105-godot-openings.json`, `phase105-openings.log`.

## 7. initiative / commit / hesitation

먼 적을 향한 commit은 이동 시간을 고려해 유지합니다. target 변경은 이미 예약된 intent의 대상 ID를 바꾸지만 **at 시간을 매 frame 새로 뽑지 않습니다**. 거리 밖으로 나갔다고 intent 시간을 다시 초기화하지 않습니다. 실제 공격 gate에서 사거리·CC·성향·현재 공격/cast·위협 등을 검사합니다.

최대2회의 hesitation, 공격 완료 후 wasAttacking 처리, post-attack disengage, 패링/기절/상쇄 시 취소 조건을 분리했습니다. rush/도발 압박과 perfect parry/패링 준비/회피에 따른 공격 차단도 원본 순서로 유지합니다. source의 `hold` 위협 반응은 멈춰 있는 동작이 아니라 circle 계획이며 유효한 commit을 무조건 차단하지 않습니다.

## 8. target 유지·재선정

이번 재조사에서 중요한 결과는 **현재 원본 full 경로도 매 tick target을 재선정한다**는 것입니다. 임의의 target commitment timer를 추가하지 않았습니다. policy 순서와 지각 가능한 후보를 그대로 사용하며, 살아 있는 같은 target을 반복 선택해도 공격 intent 예약은 유지합니다.

일반 forced 우선순위: 도발 → focus → 엄호/반격/빈틈 등 해당 분기 → 캐릭터 정책/일반 target. 위성과 개구리는 source에서 고유 target 분기를 먼저 반환하므로 모든 타입에 같은 forced 우선순위를 강제하지 않습니다. 사망/삼켜짐/은신 등의 유효성은 기존 perception 경로를 씁니다.

타겟 변경 수는 source의 실제 특성대로 기록했습니다. “변경이 적을수록 좋다”는 기준으로 정책을 바꾸지 않았습니다.

## 9. 이동 순서·회전·공격 단계

일반 dispatch는 긴급 폭탄 회피 후 개구리 → 포식자 bite 정지 → perfect parry → threat reaction → danger/safe → 성향/전략 → 성기사 합류 → 검객 연격 정지 → 광신도/탱크/위성/기관총 → rear → precommit → defensive → 검 회수/챌런 → archetype → general입니다.

heading은 normalize guard → steering vector clamp → `1-exp(-dt×rate)` 보간 → 속도/고유 배율/공격 단계 → 명시적 위치 이동 → 외력/충돌 → 경계의 책임으로 나눴습니다. 일반 facing은 target 방향으로 dt×8, 탱크 face 최대0.75rad/s와 차체 heading0.65rad/s를 구분합니다.

| 이동 경로 | windup | active/recovery |
| --- | ---: | ---: |
| 일반 / rear / area | 0.3배 | 0.55배 |
| 성향 strategy steering | 0.25배 | 0.5배 |
| 기관총 고유 이동 | 0.35배 | active0.55배, 나머지 원본 분기 |
| 저격수·탱크 공격 | 정지·heading0 | 정지·heading0 |
| 검객 연격 | 고유 공격 이동만 | 일반 steering 정지 |

일반 공격 state라고 모든 이동을 끄지 않습니다. 공격의 자체 대시/counter/cast는 기존 Ability/CombatController가 담당합니다. 공격 profile 숫자를 변경하지 않았습니다.

## 10. 거리 규칙

종류의 `range`, AI preferred distance, 실제 profile `reach`를 분리했습니다. source `canStartAttack`의 strict `< reach×scale×(range<100 ? 0.9 : 1)` 조건과 고유 추가 조건을 사용합니다. 현재 공격 중 변경된 profile을 다음 공격 시작 gate에 잘못 재사용하지 않도록 새 기본 profile을 확인합니다.

| 정책 | 원본 거리 |
| --- | --- |
| rear | range×0.86, 신중함×0.92; 가까운 적210; 거리 확보 후보55–745 |
| melee precommit | brain.standoff135–190 |
| ranged precommit | min(range×0.9,310) |
| defensive counter | 근접 reach×0.65, 원거리 min(range×0.78,230) |
| defensive spacing | 근접180, 원거리 clamp(range×0.94,190,310), 샷건 재장전320 |
| closing 추가 간격 | closing>22일 때 counter가 아니면 +45 |
| rush | 근접range×0.65, 원거리min(110,range×0.5) |
| 기관총 | 정상365 / 재장전440, 가까운 적220에서 추가 이탈 |
| 탱크 | 일반330 / disengage390 / rush220; 일반 성향 dispatch가 먼저 반환할 수 있음 |

정확한26종 스탯/공격 profile은 기존 Phase8 Resource와 보고서가 기준입니다. 이번 단계에서 이를 새 거리 수치로 덮어쓰지 않았습니다.

## 11. 후열 위치

rear 후보는 현재 자리, target 주변9개, 주변100픽셀8개, 의존형 아군 뒤 후보6개입니다. 가까운 적225의 압박·preferred 거리·range의96% 밖 패널티·이동 비용0.055·아군 점유40·실제 area risk100을 계산합니다. 힐러는 실제 dependency anchor 뒤쪽의 거리/각도도 평가합니다.

후열 goal·rethink deadline을 cache하여 frame마다 위치를 다시 뽑는 흔들림을 줄였습니다. timer 전에는 같은 goal과 RNG 상태가 유지되는 검사, 궁수·마법사·힐러·폭탄·번개마법사의 source 후보 좌표 검사를 추가했습니다. 전열 강제 슬롯이나 격자는 추가하지 않았습니다.

## 12. 호위·엄호

보호 대상과 위협 사이의 위치를 계산합니다. 엄호 anchor는 source 시점에 선택하며 보호 대상 근처만 도는 일반 pursuit로 대체하지 않았습니다. 다가오는 투사체의 선분을 고려하는 엄호 지점, 약한 아군 기준 guardian/paladin target, 성기사 궁극기 합류 중 장애 유닛 우회도 기존 전투 좌표에서 처리합니다.

수호자·성기사·엄호의 실제 source 좌표/target 규칙을 Golden에서 대조했습니다. 보호 대상이 사망/유효하지 않으면 다시 선택합니다.

## 13. 위험·안전 평가

source `collectBattleAreas`, `battleAreaRisk`, `battleSafeValue`, `battleAreaGoal`를 기준으로 연결했습니다. 별도의 가짜 화염/블랙홀은 만들지 않았습니다.

| 위험원 | 실제 weight·판정 |
| --- | --- |
| blackhole | 3, 원형 body25×scale 포함 거리 attenuation |
| tankFire | 2.5, 같은 원형 attenuation |
| ring | 줄 근처2.7, 내부0.35; square edge/body 판정 |
| bomb | fuse≤1.3, weight1.3+max(0,1-fuse)×2; 지각 가능한 적 폭탄 |
| ultimate telegraph | 원형1.8+max(0,1-remaining)×1.3, 검객 경로3 |
| enemy cluster | 적210 이내 최소3명; damage ratio0.5–1.7, 아군200의0.75와0.65 차감 |
| 보호 감쇠 | invincible>1이면0.1, shield>maxHP20%이면0.7 |

안전 영향: healing `deficit×4.5`, healer×2.3, totem×1.6, blessingReady×3.5+미보유0.8, armor `(0.25+deficit×0.9)×적 근접 유무`, pressure `0.35+deficit×0.6`, holy는 작은 치유/아군 밀집 영향입니다. 실제 여행 시간과 area 남은 수명도 검사합니다.

현재 위험과 heading×80의 prospective 위험 → route4점 평균 → 후보36개+safe 후보 → escape/refuge 점수 → fight/escape/support 가중 선택 순서입니다. 좋은 안전구역을 무조건 향하거나 적이 많다고 무조건 도망가는 정책으로 변경하지 않았습니다. safe ref·도착·효과 소실·건강 회복·만료 조건을 유지합니다. 위험 goal와 안전 refuge를 실제 JS 계산과 추가 대조했습니다.

## 14. separation·벽·충돌

| steering | separation | 벽 | heading rate |
| --- | --- | --- | --- |
| general | `<58`, `(58-d)/22` | 85, weight2 | 8 |
| archetype | `<56`, `(56-d)/25` | 55, weight1 | 8 |
| strategy | `<55`, `(55-d)/22` | 55, divisor30 | 9 |

0거리 겹침은 안정적인 actor 순서를 사용합니다. **배치 최소58과 전투 steering의56/55를 혼동하지 않습니다.** defensive edge는 벽 밖 후퇴 대신 열린 측면을 선택하며 rear/corner 후보는 source 범위로 clamp합니다.

AI desired/steered/heading과 실제 x/y·velocity·외력은 별개입니다. 기존 명시적 body collision/KnockbackController를 유지했습니다. 충돌 크기나 힘을 움직임 지표에 맞춰 조정하지 않았습니다. 아래 궤적의 큰 변위에는 공격 자체 이동과 넉백도 포함됩니다.

## 15. stance·위협 대응

stance의 기존 공격·방어·피해 수치를 바꾸지 않았습니다. 신중함의 rear/precommit/defensive·반응 예약, rush의 압박/인지 저하·disengage 해제, cover의 차단 위치를 source dispatch에 연결했습니다.

공격 준비는 인지·전방240도·숨김 발사·공격 형태·사거리/선분을 통과해야 합니다. heal windup은 공격 위협에서 제외합니다. 준비동작별 read timer와 확률 선택을 유지하고, 이미 읽은 준비동작을 frame마다 다시 뽑지 않습니다. 파링 timing의 조기/지연 가능성도 기존 source 조건을 사용합니다.

16,000번의 **실제 source/native 위협 반응**(성향당4,000, 만HP·패링 준비·동일 가시적 windup)을 비교했습니다. 각 비율의 사전 허용 차이는3.5%p이며 모두 통과했습니다.

| stance | HTML 패링/회피/맞공격/hold 횟수 | Godot 횟수 |
| --- | --- | --- |
| 기본 | 1426 / 464 / 1719 / 391 | 1458 / 477 / 1648 / 417 |
| 신중함 | 1778 / 669 / 1237 / 316 | 1799 / 710 / 1143 / 348 |
| 저돌적 | 955 / 178 / 2221 / 646 | 985 / 199 / 2131 / 685 |
| 엄호 | 1626 / 472 / 1709 / 193 | 1680 / 477 / 1639 / 204 |

이 통제된 반응 표본과 실제 전투에서의 패링/회피 발생 횟수는 다릅니다. 실제 전투에는 서로 다른 준비동작 기회와 HP·가시성·쿨타임이 존재합니다.

## 16. 고유 캐릭터 AI Golden

| 캐릭터 | 확인한 source 정책 |
| --- | --- |
| 암살자 | 낮은 **현재**HP → 후열 판정 → 거리 |
| 검객 | 고립된 적 우선 |
| UFC 선수 | 실제 근접 type 집합 우선 |
| 히어로 | 반경180의 적 군집 |
| 수호자·성기사 | 가장 약한 실제HP 아군 보호 기준 |
| 광신도 | 안정적인 saint actor 기준 |
| 소형 위성 | 실제 CC 잔여시간 높은 적 |
| 개구리 | 현재HP 높은 적 |

9개 실제 source target fixture를 통과했습니다. Ability는 target/지원 우선순위·고유 이동 요청을 제공하고, Brain은 일반 전략/거리, Movement는 적용을 담당합니다. 기존26종 passive/ultimate를 새로 만들지 않았습니다.

## 17. 실제 HTML/Godot 대표 전투 비교

전체25개 표는 [수치 비교](migration/phase105-comparison-tables.md), raw JSON은 `phase105-{web-comparison,godot-before,godot-after}.json`입니다. 모든 표에서 **HTML / Godot 전 / Godot 후** 순서입니다. 아래는 첫 공격 시간과 평균 가까운 적 거리입니다.

| 대표 구성 | 첫 공격초 H / 전 / 후 | 평균거리px H / 전 / 후 |
| --- | --- | --- |
| 전사1v1 | 6.20 / 5.03 / 4.18 | 256 / 239 / 258 |
| 전사-궁수 | 4.43 / 3.13 / 2.88 | 277 / 263 / 258 |
| 궁수1v1 | 2.77 / 3.13 / 2.40 | 353 / 342 / 364 |
| 암살자-힐러 | 9.78 / 5.05 / 5.03 | 301 / 243 / 246 |
| 수호자-암살자 | 3.85 / 3.82 / 3.17 | 173 / 161 / 207 |
| 저격수-전사 | 11.08 / 4.27 / 3.47 | 274 / 351 / 357 |
| 전사+궁수+힐러 동형 | 2.12 / 3.17 / 2.45 | 295 / 268 / 243 |
| 전열2+후열2 | 1.53 / 2.67 / 3.05 | 267 / 292 / 270 |
| 수호자+힐러 중심 | 1.90 / 2.65 / 1.68 | 280 / 269 / 267 |
| 혼합6v6 | 1.17 / 1.37 / 1.68 | 273 / 231 / 255 |
| 혼합12v12 | 1.97 / 1.23 / 1.87 | 293 / 245 / 253 |
| 기관총-전사 | 6.57 / 4.85 / 2.95 | 245 / 240 / 393 |
| 탱크-전사 | 6.37 / 4.85 / 2.95 | 231 / 206 / 254 |

단일 seed만으로 타입별 통계적 동등성을 입증할 수 없습니다. 예를 들어 기관총과 저격수의 이번 first attack 차이는 줄지 않았습니다. 이를 공격 간격·사거리·HP 조정으로 숨기지 않았습니다.

## 18. 총 이동·target·공격·회피 빈도

25개 paired case의 source 대비 평균 절대 오차입니다. 통계적 검정이나 일반화된 균형 판정이 아닙니다.

| 지표 | 변경 전 | 변경 후 |
| --- | ---: | ---: |
| 첫 공격초 | 1.269 | 1.357 |
| 첫 실제HP 손실초 | 1.267 | 1.121 |
| 평균 적 거리px | 39.728 | 31.632 |
| 총 이동px | 800.546 | 903.466 |
| target 변경 | 12.480 | 12.440 |
| 공격 시작 | 4.080 | 3.680 |
| HP 손실 tick | 8.440 | 5.880 |
| 패링 시작 | 1.040 | 1.000 |
| threat 회피 결정 | 2.800 | 2.280 |
| clash | 1.440 | 1.400 |
| idle unit-seconds | 7.988 | 6.475 |
| 위험 체류 unit-seconds | 4.035 | 1.937 |
| area escape 결정 | 0.720 | 0.440 |

웹의 `resolveDamage` 호출별 hit count는 한 tick에 여러 번 발생할 수 있어 Godot의 HP 관측 tick과 직접 같지 않습니다. 비교표의 hit는 양쪽 모두 **HP 감소가 관측된 유닛-tick**입니다. 실제 명중/방어 성공 이벤트 전체를 완전히 동일한 정의로 맞춘 값이라고 부르지 않습니다. idle은 공격/cast가 없는 생존 유닛 시간이며 이동 대기만 뜻하지 않습니다.

첫 HP 손실시간 오차는 양쪽에서 실제 손실이 관측된24쌍입니다. HTML 저격수-전사는20초 창에 HP 손실이 없어 null로 남겼습니다. 횟수 지표에서는 이 사례를0회로 포함합니다.

## 19. stance별 실제 전투 경향

동형3v3, 각 성향11/29/101 세 seed의 20초 평균. H / Godot 후입니다.

| 성향 | 첫 공격초 | 공격시작 | 패링 | 회피 | 평균거리px | 이동px | target변경 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 기본 | 1.76 / 2.23 | 26.0 / 22.0 | 5.0 / 5.0 | 4.33 / 2.33 | 279 / 278 | 7482 / 6811 | 54 / 52 |
| 신중함 | 1.71 / 2.42 | 25.0 / 22.33 | 7.0 / 5.33 | 6.33 / 8.67 | 296 / 291 | 8095 / 7521 | 61 / 52.67 |
| 저돌적 | 0.72 / 0.67 | 31.0 / 31.67 | 3.67 / 3.67 | 3.33 / 3.67 | 227 / 214 | 5871 / 5533 | 53 / 40.33 |
| 엄호 | 3.59 / 3.31 | 18.67 / 17.67 | 5.0 / 6.0 | 4.67 / 4.67 | 250 / 253 | 6523 / 5618 | 38.67 / 36.33 |

저돌적의 빠른 교전·좁은 거리, 신중함의 더 높은 회피·넓은 거리, 엄호의 늦은 교전이라는 경향은 두 구현에서 관측됐습니다. 모든 성향의 세부 빈도까지 동등하다는 증거는 아닙니다.

## 20. 궤적·최초 divergence

0.25초마다 각 actor의 x/y, target, plan, intent, 공격state, heading, 다음initiative와 movement를 기록했습니다. [그림](migration/phase105-trajectories.png), [SVG](migration/phase105-trajectories.svg), [CSV](migration/phase105-trajectories.csv), `phase105-comparison-summary.json`에 원자료가 있습니다. 그림은 actor0 궤적과 첫 상대 거리이며, 전체 평균거리 표와 정의가 다릅니다.

진단용 actor0 위치차≥80px의 첫 관측은 전사1v1 3.25초, 암살자-힐러2.50초, 저격수-전사2.00초, 동형3v3/전열후열1.00초입니다. 80px는 이탈 시점 표시 기준이며 수정 목표/통과 임계치가 아닙니다.

전사1v1 3.25초: HTML은 `유인·진입 판단`, 다음initiative5.3196이고 Godot은 이미 `general_approach`, 다음initiative8.4017입니다. 서로 다른 초기 initiative/tempo/entry random 때문에 commit 진입이 갈렸습니다. 이는 “initiative 예약을 매 frame 다시 뽑아서” 발생한 차이와 구분됩니다. 뒤의 넉백/피해/타겟 변화를 이 첫 원인으로 모두 단정하지 않았습니다.

전열후열 actor0 1초에는 source의 측면 entry와 Godot의 flank entry가 다릅니다. 같은 초기 plan/속도를 넣은 별도2초 비교는 좌표/heading이 일치하여 해당 일반 entry 함수의 계산 차이와 stochastic 초기화 차이를 분리했습니다.

## 21. 전투 종료 시간

20초는 첫 교전 분석 창이고 종료 시간 비교에는 최대90초를 별도로 실행했습니다. 전체13개 결과는 비교표에 있습니다. 전사1v1 H50.72/G28.15초, 궁수1v1 H30.18/G29.70초, 저격수-전사 H36.10/G37.62초, 기관총-전사 H17.33/G42.55초입니다.

동형3v3는 HTML38.67초 종료, Godot은90초까지 미종료였습니다. 수호자+힐러 중심은 HTML90초 미종료, Godot75.83초 종료였습니다. 미종료를 “90초에 전투 종료”로 기록하지 않았습니다. 실제 장기전 차이는 아직 남아 있습니다.

## 22. RNG와 FPS

source의 같은 decision/read/goal 수명 동안 random을 다시 뽑지 않는 부분을 유지했습니다. live bomb cache도 일반 projectile 검사에서 지워지지 않게 했습니다. Godot의 PCG와 reference의 seeded Math.random stream을 동일하게 만들지 않았습니다. 실제 웹 표현 효과도 RNG를 소비하므로 random 소비 순서까지 복제한 것이 아닙니다.

30/60/120의 고정 circle1초는 최대 약1.13px 통합 오차로 검사했습니다. 실제 full 전투도 전사1v1·전사-궁수·동형3v3를 양쪽3fps로 실행했습니다. Godot의 첫 공격은 각각4.20/4.18/4.19, 2.90/2.88/2.77, 2.37/2.45/2.44초로 FPS가 높을수록 일괄 빨라지는 패턴은 관측되지 않았습니다.

그러나 피해·회피·상쇄 이후20초 궤적은 FPS에 따라 달랐습니다. 전사-궁수120Hz의 생존/이동 시간도 달랐습니다. **full 전투의 FPS별 확률 결과가 완전히 독립적이라고 주장하지 않습니다.** fixed-step/RNG replay 전체 통일은 이번에 임의 도입하지 않았습니다.

## 23. TP·forced retreat·CC 복귀

TP hold 동안 brain·target·intent·movement/timer가 동결되는 검사를 유지했습니다. 성향 변경은 source처럼 hold/think/response/disengage/return/commit/punish/intent를 재설정하고 다음initiative를 예약합니다. 진행 중 일반 공격 자체를 무조건 취소하지는 않습니다.

명령 없는 TP 재개는 기존 brain을 유지합니다. 적forecast → 아군pending 순서와 source cancelIntent를 사용합니다. forced retreat 동안 일반commit이 접근으로 덮어쓰지 못하며, 명령 종료 후 일반 정책으로 돌아갑니다. 전체 전투 RETREAT는 이 유닛 이동 명령과 별도입니다.

기절은 공격/intent/heading 중단 → disengage를 기절 종료에 맞춤 → nextinitiative 재예약입니다. 이전 공격 의도를 그대로 즉시 재실행하지 않습니다. 상태 snapshot에 brain/target/UI 참조를 저장하지 않았습니다.

## 24. 신규 검사와 기존 Phase 결과

`phase105_tests.gd`에 direct Golden46행·고유 target9개·반응확률24개 입력, timer/intent/CC/stance/명령 계약, actual reaction16,000건, FPS steering을 추가했습니다. 각 반응 시행에서 read 생성/반복호출 RNG 불변/예약 시점 반응을 각각 검사하므로48,000개의 계약 검사가 포함됩니다.

| 검사 | checks | 실패 |
| --- | ---: | ---: |
| Phase1 | 9705 | 0 |
| Phase2 | 243 | 0 |
| Phase3 | 131 | 0 |
| Phase4 | 119 | 0 |
| Phase5 | 110 | 0 |
| Phase6 | 118 | 0 |
| Phase7 | 3702 | 0 |
| Phase8 | 8260 | 0 |
| Phase9 | 15755 | 0 |
| Phase10 | 10255 | 0 |
| Phase10.5 | 48418 | 0 |
| **test_runner 합계** | **96816** | **0** |
| 독립 초기2초 full-tick 비교 | 320 | 0 |
| headless GUI 9개 | 218 | 0 |
| X11 GUI 9개 | 218 | 0 |

기존 Phase1~10의 개별 검사 파일은 바이트 그대로입니다. `test_runner.gd`에 새 그룹을 연결했습니다. 전투 종료까지 매 tick 실행하는 검사 수는 전투 길이에 따라 달라지므로 과거 총검사 수와 같지 않습니다. 이를 맞추기 위해 기존 테스트를 삭제/스킵하지 않았습니다.

별도로 모든 비교 corpus의 기록된 x/y/HP에 대해 finite·전투장 내부·HP 비음수 검사280,384개를 수행했고 실패0입니다(`phase105-trace-validation.json`). 이는0.25초 기록 표본의 데이터 검사이며 매 simulation frame의 추가 테스트 수로 합산하지 않습니다. main runner와 초기 비교·양쪽 GUI를 합한 검사 실행은97,572개이며 전부 통과했습니다.

## 25. GUI와 실제 창

기존 deployment/room/turning/strategy/combat/character/tower/tower_content 8개 + 신규 `ai_ui_smoke.gd`를 headless와 X11에서 실행했습니다. 전부 exit0입니다. 실제 X11은 Mesa llvmpipe OpenGL 창에 `InputEventMouseButton`/`InputEventScreenTouch`를 넣는 자동 조작입니다. 사람이 수동으로 모든 전투를 관전했다고 주장하지 않습니다.

신규 AI UI는 desktop1000×1100와 mobile390×844에서 맵 → 방 → 배치 → 전투 → 유닛 선택 → debug read-only 확인 → TP hold 동결 → 성향 변경 → 재개 → 전체 후퇴/정산을 확인했습니다. screenshot 두 장을 열어 표시도 확인했습니다.

입력은 실제 엔진 이벤트를 사용하고, 긴 시간 대기 대신 일부 TP/후퇴 시간 경계와 정산은 simulation clock 설정·도메인 API로 검증합니다. 신규 AI smoke의 모든 단계가40초 real-time 관전이나 버튼 클릭만으로 진행된 것은 아닙니다. 기존 TP/카드/배치/콘텐츠 GUI 검사도 함께 실행했습니다.

선택 panel: Target, Plan/Entry, Intent/commit, desired distance/direction, danger/safe, heading, movement/ability override, reaction, stance. 다시 같은 유닛을 누르면 닫습니다. 모바일 debug overlay는 맵 일부를 덮는 개발용 표시이며 최종 전투 HUD 디자인은 아닙니다. 사진: `migration/phase105-ai-desktop.png`, `phase105-ai-mobile.png`.

## 26. 실행 파일·생성 산출물

신규 실행 검사/분석 파일:

- `tests/phase105_tests.gd`, `phase105_runner.gd`: 새 Golden·계약·통계 검사.
- `tests/ai_web_reference.cjs`, `ai_comparison_runner.gd`: 실제 full 전투 계측.
- `tests/ai_golden_reference.cjs`, `ai_reaction_reference.cjs`: 보호된 source 함수 fixture/분포 추출.
- `tests/ai_opening_reference.cjs`, `ai_opening_runner.gd`: 정규화2초 whole-tick 비교.
- `tests/ai_ui_smoke.gd`: 실제 mouse/touch GUI 경로.
- `tests/ai_compare_report.py`: 기존 계측 JSON으로 표/CSV/그림 작성. 전투 규칙 없음.
- `migration/phase105-*`: scenario/fixture/raw trace/요약/그림/실행로그/해시.
- `PHASE105_REPORT.md`: 이 보고서, `README.md`: 현재 단계 안내.

Scene·save 파일·새 AI 밸런스 시스템을 추가하지 않았습니다. `.gd.uid`는 엔진 생성 파일입니다.

## 27. 직접 실행·재현

저장소 루트에서 다음을 사용합니다. 환경에서는 XDG data/config/cache를 `/tmp/duni-godot`에 지정하여 읽기 전용 HOME 문제를 피했습니다.

```bash
godot --headless --path godot --editor --quit
godot --headless --path godot --script res://tests/test_runner.gd
node godot/tests/ai_golden_reference.cjs
node godot/tests/ai_reaction_reference.cjs
node godot/tests/ai_opening_reference.cjs
godot --headless --path godot --script res://tests/ai_opening_runner.gd
node godot/tests/ai_web_reference.cjs
godot --headless --path godot --script res://tests/ai_comparison_runner.gd -- res://migration/phase105-godot-after.json
python3 godot/tests/ai_compare_report.py
godot --headless --path godot --script res://tests/ai_ui_smoke.gd
godot --path godot
```

Godot 에디터에서 `godot/project.godot`를 열고 F5로 타워를 실행할 수도 있습니다. 90초/FPS corpus는 runner의 두 번째 user argument에 respective scenario JSON을 지정합니다. X11 검사에는 `DISPLAY=:97`, `--rendering-method gl_compatibility --audio-driver Dummy`를 사용했습니다.

## 28. 웹 무변경·수치 회귀

dist19개 SHA-256 모두 작업 전 값과 일치합니다. baseline은 작업 시작 시 보호한 목록과 Phase10 hash 문서이며 archive의 기존 Godot 파일452개도 대조했습니다. 모든 기존 `.tres`가 바이트 동일합니다. HP·damage·defense·attack profile·궁극기·카드·타워 성장 값을 맞추기 위해 변경하지 않았습니다. 이번 변경은 실행 위치·행동 정책·source의 이동/판단 값입니다.

`git diff`에서 기존 tracked 웹 변경은 없습니다. 저장소의 Godot 폴더가 작업 전부터 untracked인 상태였으므로 `git reset/clean`으로 복구하지 않았습니다.

## 29. 남은 차이 / MIGRATION_NOTE

1. PCG와 JS stream/표현 RNG 소비 순서 차이. 첫 initiative·entry·실제 이동속도 random의 차이가 초기 교전을 갈라놓을 수 있습니다. normalized opening 검사는 이 입력 차이를 별도로 제거합니다.
2. Vector2 float32와 JS Number float64, 후보 점수의 경계/tie·장기간 적분 차이.
3. Body collision/외력/공격 contact, 고유 lifecycle의 global pass는 Godot 구성요소 호출 구조를 유지합니다. 이번 정책 Golden이 모든 복합 캐릭터 전투 frame의 동일성을 입증하지는 않습니다.
4. 고유 dash/rescue 완료 frame에서 일반 판단 복귀와 모든 source early-continue가 완전히 같은지는 추가 세밀한 replay 대상입니다. 기존 full 능력/정산 계약은 유지했습니다.
5. 이전 Phase5의 사망 focus 대상 처리: Godot의 안전한 no-op 계약과 원본의 cancelIntent 후 무효 focus 설정에 남은 차이가 있습니다. 기존 테스트를 우회해 변경하지 않고 기록합니다.
6. 20초 표본은 첫 교전/리듬 진단이고 최대90초에서도 장기전 차이가 남았습니다. 첫 공격/총 이동 지표가 일부 악화됐습니다. 단일 seed의 승패나 이동거리를 목표로 balance를 조정하지 않았습니다.
7. 실제 full 전투의 FPS별 stochastic/충돌 결과는 완전히 같지 않습니다. frame별 재추첨 문제와 timer/heading의 FPS 안정성은 별도로 검사했습니다.
8. HP-loss tick은 완전한 물리 적중/방어 이벤트 수와 다릅니다. 동일 공격 ID까지 맞춘 contact replay가 후속 진단에 필요합니다.
9. 신규 debug panel은 읽기 전용 개발 도구이고 모바일 지도 일부를 덮습니다. 최종 UI·VFX·사운드를 작업하지 않았습니다.
10. 온라인 미리보기는 이전 Phase9 배포본입니다. 이번 native 소스를 배포했다고 주장하지 않습니다.

## 30. Phase10.5만 되돌리기

기존 Phase10 전체452파일의 정확한 archive가 있으므로 이 단계 이전으로 복구 가능합니다. archive를 먼저 별도로 복사하고 현재 Godot 폴더를 이동해 보존합니다. 저장소 루트에서:

```bash
cp godot/migration/phase10-before-phase105.tar.gz /tmp/phase10-before-phase105.tar.gz
mv godot godot-phase105-backup
tar -xzf /tmp/phase10-before-phase105.tar.gz -C .
```

archive 경로는 `godot/...`입니다. 현재 폴더 위에 단순 덮어쓰기만 하면 신규 검사/산출물이 남으므로 위처럼 폴더를 먼저 보존 이동합니다. 웹 폴더는 건드리지 않습니다. Godot `.godot` 캐시는 에디터가 재생성합니다.

## 31. 저장 단계 전에 남은 확인 사항

이번 보고의 stochastic 전투 차이를 “동일 전투 재생”으로 취급하지 않아야 합니다. 저장할 지속 상태와 저장하지 않는 transient brain/read/goal/attack 객체의 경계를 기존 계약대로 유지하세요. 향후 원본 contact·고유 완료 frame replay를 더 비교할 경우 저장 포맷 변경과 분리해 작업할 수 있습니다.

Phase11 SaveManager·파일 저장·불러오기는 생성하거나 시작하지 않았습니다.
