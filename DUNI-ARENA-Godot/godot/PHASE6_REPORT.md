# Phase 6 완료 보고 — 전략카드

2026-10-11 · Godot **4.6.3.stable.official.7d41c59c4** · 저장소 웹 실행 코드 우선.

6종 카드의 데이터, 개별 보유/사용 기록, hold 중 즉시 효과, 재개 명령, 보호막 흡수, 지속 상태, 디버그 UI를 연결했습니다. Phase 1~5 테스트를 보존했고 **Phase 7은 시작하지 않았습니다**.

**철벽방어는 요청에서 허용한 제한 구현입니다.** 15초 상태, 즉시 준비, 3초 쿨타임 조회와 호출 계약까지 연결했습니다. 공격 감지 AI·방어력 확률·실제 패링 차단·반격·기절은 아직 작동하지 않습니다. 완전한 HTML 전투 시스템 이전 완료를 의미하지 않습니다.

## 1. 생성 파일

- `data/strategy/charge.tres`
- `data/strategy/evade.tres`
- `data/strategy/iron.tres`
- `data/strategy/mango.tres`
- `data/strategy/shield.tres`
- `data/strategy/taunt.tres`
- `migration/phase5-before-phase6.tar.gz`
- `migration/phase6-web-sha256.json`
- `scripts/parry_readiness.gd`
- `scripts/strategy_card_catalog.gd`
- `scripts/strategy_card_data.gd`
- `scripts/strategy_card_executor.gd`
- `scripts/strategy_card_instance.gd`
- `scripts/strategy_command.gd`
- `scripts/strategy_command_executor.gd`
- `scripts/strategy_effects.gd`
- `scripts/strategy_progress_context.gd`
- `tests/phase6_tests.gd`
- `tests/strategy_ui_smoke.gd`

이 보고서 `PHASE6_REPORT.md`도 추가했습니다. 신규 GDScript 11개(스크립트 9개, 테스트 2개)의 `.uid`도 Godot 에디터가 생성했습니다. 별도 카드 Scene, 타워/상점 Manager, 저장 파일은 만들지 않았습니다.

| 파일 | 역할 |
|---|---|
| `strategy_card_data.gd`, `data/strategy/*.tres` | 공유 카드 정의와 웹 6종 수치 |
| `strategy_card_catalog.gd` | kind로 정의 조회 |
| `strategy_card_instance.gd` | 런에 소속된 카드 한 장의 기록 |
| `strategy_progress_context.gd` | 현재 방문 층 / 최고 해금 층 공급 |
| `strategy_card_executor.gd` | 검증 → 효과/명령 → 사용 기록, 결과 코드 |
| `strategy_command.gd` | 참조 없는 지연 명령, 깊은 복사/순수 metadata |
| `strategy_command_executor.gd` | 아군 순서로 재개 명령 실행 |
| `strategy_effects.gd` | 전략 회복, 보호막 흡수/타이머/지속 필드 codec |
| `parry_readiness.gd` | 패링 준비/쿨타임 조회 계약; 실제 차단 없음 |
| `tests/phase6_tests.gd` | 7그룹 / 118개 도메인 검사 |
| `tests/strategy_ui_smoke.gd` | 마우스/터치 / 390×844 / 23개 GUI 검사 |
| `migration/phase5-before-phase6.tar.gz` | Phase 5 원상복원용 소스 116개 |
| `migration/phase6-web-sha256.json` | 작업 전후 일치한 웹 19개 SHA-256 |

## 2. 수정 파일

- `scripts/battle_manager.gd`
- `scripts/damage_outcome.gd`
- `scripts/damage_resolver.gd`
- `scripts/enemy_state_codec.gd`
- `scripts/room_battle_screen.gd`
- `scripts/run_state.gd`
- `scripts/strategy_movement_controller.gd`
- `scripts/target_selector.gd`
- `scripts/turning_point_manager.gd`
- `scripts/turning_point_panel.gd`
- `scripts/turning_point_state.gd`
- `scripts/unit.gd`
- `scripts/unit_state_codec.gd`
- `tests/test_runner.gd`

`README.md` 맨 위의 최신 보고서 안내도 Phase 6으로 바꿨습니다. Phase 1 본문, Phase 2~5 보고서, 기존 씬·종류 수치·웹 파일은 보존했습니다.

| 연결 위치 | 변경 |
|---|---|
| `RunState` | 카드 레지스트리/ID 카운터/진행 문맥/사용 영수증 |
| `TurningPointState`, `TurningPointManager` | 선택/취소/사용 및 적 계획 뒤 아군 명령 실행 |
| `Unit`, `BattleManager` | 런타임 보호막/철벽/도발 필드, simulation 타이머 |
| `DamageResolver`, `DamageOutcome` | 보호막 선소모, 흡수량 분리 |
| `UnitStateCodec`, `EnemyStateCodec` | 웹 whitelist 중 현재 구현한 지속 상태 |
| `TargetSelector` | 도발 → 집중 → 기존 가까운 적 |
| `StrategyMovementController` | 아군도 기존 탈출 대시/도주 재사용, duration 인수 기본 6 |
| `TurningPointPanel`, `RoomBattleScreen` | 카드 UI/고정 6장 지급/모바일 지도 공간 확보 |
| `test_runner.gd` | 기존 검사 뒤 Phase 6 실행·합계만 추가 |

## 3. StrategyCardData

Resource: `kind`, `display_name`, `targeting_type=living_ally`, `usage_rule=ONCE/FLOOR/COOLDOWN`, `description`, `amount`, `duration`. 공유 종류 정의에 사용 횟수/readyFloor/선택 상태를 넣지 않습니다. 상점 가격은 아래 조사 표에만 기록하고 경제 시스템을 구현하지 않았습니다.

## 4. StrategyCardInstance

RefCounted: `card_id`, `kind`, `used_depth=-1`, `used_floors:Array[int]`, `ready_floor=0`, `consumed=false`.

| HTML | Godot | 의미 |
|---|---|---|
| `id` | `card_id` | 런 카운터로 생성하는 개별 카드 ID |
| `usedDepth:null` | `used_depth:-1` | 아직 사용한 방문 층 없음 |
| `usedFloors` | `used_floors` | 사용한 층 이력; 재방문도 막음 |
| `readyFloor` | `ready_floor` | 재사용 가능한 최고 해금 층 기준 |
| 일회성 배열에서 삭제 | `consumed=true` | 효과/사용 불가 의미 동일; 디버그 감사 기록 유지 |

같은 종류 여러 장도 ID·사용 기록이 독립적입니다. card_id는 member_id/enemy_id와 섞지 않습니다.

## 5. StrategyCardExecutor

`availability()`가 카드/문맥 규칙을 검사하고 `apply(manager, card_id, member_id, request_id)`가 현재 hold·보유 카드·생존 참가 아군을 검사합니다. UI는 HP나 기록을 직접 수정하지 않습니다. 성공한 요청만 순수 데이터 영수증을 남깁니다. `OK / NOT_HOLD / INVALID_CARD / UNAVAILABLE / INVALID_TARGET / NO_EFFECT / DUPLICATE` 결과 코드에는 UI 문자열이나 Node가 없습니다.

회복/게이지는 이번 Unit에 적용하고 정산 시 길드원에 회수합니다. HP를 Unit와 길드원에 중복 적용하지 않습니다.

## 6. StrategyCommand

`command_id`, `card_id`, `member_id`, `command_type`, `duration`, `metadata`, `executed`. metadata는 순수 값 검증 및 입출력 깊은 복사로 Node 참조와 외부 변경을 거부합니다. 도발 metadata의 `target_enemy_ids`는 ID 배열입니다. 명령은 TP 로컬이며 Room/Guild 지속 데이터에 넣지 않습니다.

## 7. 실제 HTML 카드 6종

근거: `dist/strategy.js` 3~10, 72~73, 88~100; `dist/combat.js` 33~59, 79~81 및 `resolveDamage`; `dist/ultimate.js` 41~42; `dist/tower.js` 193, 667~670.

| kind / 이름 | 대상 | 실제 효과·수치 | 실행 | 사용 제한·가격 | 효과 없음 / 지속 키 |
|---|---|---|---|---|---|
| mango / 망고주스 | 생존 아군 | maxHP×0.30 회복, 최대 HP 제한 | hold 즉시 | once · 70G | 만 HP 거부. HP 회수 |
| evade / 전투회피 | 생존 아군 | pendingRetreat → 탈출 대시 → 6초 도주 | 재개 | floor · 140G | 같은 대상 pending 있으면 거부. 실제 실행 후 retreatRemaining |
| charge / 충전 | 생존 아군 | `gainUltimate(50)` → max100 | hold 즉시 | cooldown · 170G | 실제 gain≤0 거부. ultGauge |
| shield / 보호막 | 생존 아군 | `shieldHp=100`, `shieldTime=8`, 교체 | hold 즉시 | once · 120G | 기존 보호막 갱신도 소비. shieldHp/shieldTime |
| iron / 철벽방어 | 생존 아군 | ironDefenseTime15, parryCooldown0, 전사 defenseCooldown0; 패링 cd3 | hold 즉시 | cooldown · 220G | 같은 상태 갱신도 소비. ironDefenseTime/parryCooldown/parryTime/defenseCooldown |
| taunt / 도발 | 생존 아군 → 가까운 적 최대2 | 재개 시 tauntedBy / elapsed+8 | 재개 | floor · 160G | pending 또는 인식 가능한 적 없음 거부. taunt/pending 자체 미저장 |

cooldown 두 카드 모두 **`readyFloor = tower.unlockedFloor + 3`**, 사용 가능 **`unlockedFloor >= readyFloor`**입니다. 이 값은 현재 방문 층이 아닙니다. 층 인덱스는 웹처럼 0부터 시작하며 UI 해금 층 표시는 +1 합니다. “두 층 경과”라는 설명을 계산식으로 바꾸지 않았습니다.

## 8. 망고주스

hold 전용 전략 회복 경로 `StrategyEffects.heal()` 사용. 전사 max150이면 45 회복하고 만 HP에서는 미소비입니다. 웹 `restoreCombatHp(..., null)`은 대상의 healingPower가 반영되지만 현재 Godot에는 장비/치유 보너스가 없으므로 1배입니다. 이후 장비 이전에서 대상 치유 배율을 연결해야 합니다.

## 9. 전투회피

사용 시 순수 pending 명령만 등록합니다. hold 중 좌표가 바뀌지 않습니다. 재개 시 공격/기존 대시를 취소하고 Phase 5의 안전 위치 탐색·720 속도 탈출 대시·6초 도주를 재사용합니다. 화면에서 제거하거나 RoomBattleSession을 종료시키지 않습니다.

## 10. 충전

현재 전사/궁수의 `ultimate_gauge += 50`, 100 clamp. 이미 100이면 기록/쿨타임 모두 변경하지 않습니다. 실제 궁극기 발동은 추가하지 않았습니다. 웹의 CC·머금기·조종·궁극기 시전 중 gain 거부는 해당 전투 기능 이전 때 연결해야 합니다. 샷건에는 실제 ULTIMATES가 없지만 이번 프로젝트는 전사/궁수만 생성합니다.

## 11. 보호막

100 HP/8 simulation seconds. hold 중 타이머는 멈춥니다. 일반 공격 경로는 검증 → 치명타 → 반올림 → 보호막 흡수 → 실제 HP 손실 → 사망입니다. `DamageOutcome.shield_absorbed`를 추가했고 attempted/resolved/hp_damage 및 기존 numeric `apply()` 의미를 보존했습니다. 흡수 후 남은 피해만 HP에 들어갑니다. 시간 만료/소진 시 보호막이 사라집니다.

`Unit.receive_damage()`는 최종 HP 손실 단계입니다. 새 일반 공격은 반드시 DamageResolver를 사용해야 합니다. 웹에서 보호막 이전에 처리되는 반사/분담/치명적 구조 등 미구현 시스템을 임의로 넣지 않았습니다.

## 12. 철벽방어

즉시 ironDefenseRemaining15/parryCooldown0, 전사 defenseCooldown0. simulation 타이머로 만료되고 `ParryReadiness.cooldown_duration()`은 유지 중 3, 종료 후 12입니다. `parry_readiness_requested(member_id, 15, 3)` 호출 계약을 성공 영수증 기록 후 1회 발생시킵니다.

**실제 패링은 미연결입니다.** `startBasicParry`는 공격 취소/AI 위협 감지/방어 위력 확률/0.4초 완전 방어/0.8초 경감/반격/주변 기절과 결합됩니다. 일부를 새 규칙으로 축소하지 않았습니다. 현재 카드는 준비 상태와 지속 데이터까지 정상 처리되며 실제 피해 차단 능력이 없습니다. UI 설명은 카드 정의이고 전투 구현 완료를 보장하지 않습니다.

## 13. 도발

현재 적 team1 생존자 중 해당 아군에 가까운 순서 최대2, 거리 상한 없음. 재개 시 적 공격/기존 탈출 대시 취소, commandRetreatUntil0, 지정 member_id 우선 타겟 8초. TargetSelector 우선순위는 **도발 → 집중 → 가장 가까운 유효 적**입니다. 종료 시 원래 규칙으로 돌아갑니다.

웹은 `canPerceive(enemy, ally)`도 검사합니다. 현재 전사/궁수에는 은신/머금기/조종이 없어서 모든 유효 아군이 보입니다. 전체 캐릭터 이전 시 이 인식 검사를 추가해야 합니다.

## 14. 즉시 / 재개 효과

즉시: mango / charge / shield / iron. 재개: evade / taunt. 일반 DamageResolver의 hold 차단을 해제하지 않았습니다. 카드 회복만 별도 경로에서 적용합니다. 도발 대상 ID는 사용 시 고정하고 재개 시 죽거나 사라진 적은 안전하게 생략합니다.

## 15. 사용 제한

once: 사용 후 `consumed`, 재사용 금지. floor: `used_depth`와 `used_floors` 모두 검사하므로 예전 사용 층 재방문도 금지. cooldown: 최고 해금 층 문맥만 검사합니다. 일반 진행/감속/종료/죽은 대상/예비 길드원/알 수 없는 ID 사용은 모두 거부됩니다.

## 16. cooldown 처리

`StrategyProgressContext.current_depth ↔ tower.floor`, `unlocked_floor ↔ tower.unlockedFloor`. 예: 방문 인덱스1/최고 해금7에서 사용하면 ready10. 최고 해금9는 거부, 10은 허용. F5는 문맥 0/0이며 재도전이 해금 층을 늘리지 않습니다. 테스트가 문맥을 공급하고 UI에서 규칙을 하드코딩하지 않습니다.

## 17. 효과 없는 사용과 중복

회복/충전 효과 없음, 잘못된/죽은 대상, 없는 적, 이미 pending인 명령, 사용 제한 위반은 효과/영수증/쿨타임 모두 그대로입니다. **보호막·철벽은 실제 코드가 갱신 사용을 허용하는 예외**입니다. 사용자 일반 조건과 충돌하는 부분을 기록하고 코드 우선순위를 따랐습니다.

선택/선택 토글/취소도 사용 기록을 변경하지 않습니다. 같은 request_id는 런 영수증으로 중복 거부하고, 다른 request_id로 같은 카드 재클릭해도 once/floor/cooldown 제한으로 중복 적용을 막습니다. 같은 대상 pending도 한 종류당 1개입니다.

## 18. TP resolve 순서

Phase 5 단일 resolve 유지:

1. 유효한 hold 검사, resolved 먼저 표시(중복/재진입 차단).
2. 기존 enemy forecast 전체 실행.
3. 생존 아군을 기존 units 순서로 순회.
4. 각 아군의 evade 먼저, 그 아군의 taunt 다음.
5. 선택 종료, BattleClock NORMAL 복귀.

카드 클릭 순서가 이 실행 순서를 바꾸지 않습니다. 적 retreat 대시는 뒤에 실행되는 도발이 취소합니다. 적 focus 데이터가 남아도 도발 기간에는 선택 우선순위가 낮습니다. 수동/자동 재개 모두 이 경로를 사용합니다. 전체 전투 후퇴는 TP 명령 실행을 하지 않습니다.

## 19. 상태 지속

| 값 | GuildMember / EnemyRoom | 이번 Phase |
|---|---|---|
| shieldHp / shieldTime | 둘 다 웹 공통 whitelist | 런타임 값 회수·주입 및 simulation 만료 |
| ironDefenseTime | 둘 다 | 회수·주입·만료 |
| parryCooldown / parryTime / defenseCooldown | 둘 다 | 순수 수치 왕복/타이머; 실제 차단 미연결 |
| retreatRemaining | 둘 다 snapshot 파생 | 실제 남은 도주 시간; 새 전투 elapsed0에 상대 복원 |
| specialRemaining | 둘 다 snapshot 파생 | Phase 5 적 특수 계약 보존, 아군도 값 왕복 가능 |
| strategyUltimateReady | 둘 다 whitelist | 기존 opaque dictionary 왕복; 실제 궁극기 미구현 |
| ultimate_gauge | 아군/적 기본 상태 | 각 기존 codec 계약 유지 |
| pendingRetreat / pendingTauntIds | 웹 미저장 | TP 명령만, 재도전 생성 안 함 |
| tauntedBy / tauntedUntil / focusTargetId / focusUntil | 웹 미저장 | 전투 한정, 재도전 초기화 |
| strategyDash / target / attack / projectile / TP 객체 | 웹 전체 프레임 저장 안 함 | 저장 안 함 |

새 효과가 없던 길드원의 opaque dictionary에 불필요한 0 키를 추가하지 않아 Phase 2 기존 왕복 계약도 보존합니다. 실제 효과가 끝난 기존 키는 0으로 갱신해 오래된 보호막이 다시 살아나지 않게 합니다. 사망 시 shieldHp/shieldTime/ironDefenseTime/parryTime을 웹처럼 0으로 정리합니다.

## 20. RunState 카드 보유

`strategy_cards`, `next_strategy_card_number`, `strategy_progress`, `strategy_use_receipts`. 카드 객체는 Node/UI 참조 없이 런 동안 존재합니다. F5 디버그 화면이 새 방/런 생성 시 6종 각1장을 지급합니다. 재도전/다음 TP마다 지급하지 않습니다. 실제 카드 획득/상점/경제/파일 저장은 구현하지 않았습니다.

## 21. 재도전

RunState의 consumed/usedFloors/readyFloor/영수증은 유지합니다. Unit의 적용된 효과는 정산 codec으로 길드원/적에 회수합니다. 다음 전투는 새 Unit·새 TP 상태·첫12초 스케줄입니다. 선택과 pending은 복원하지 않습니다. hold 중 전체 후퇴하면 이미 소비한 카드는 반환하지 않고 아직 실행하지 않은 pending은 버립니다. 실제 실행된 도주 잔여 시간만 snapshot에 들어갑니다.

## 22. 신규 테스트

`phase6_tests.gd`: **7그룹 / 118개**.

- normal/brake/hold/종료, 잘못된 카드/대상, 사망자/예비 전력 대상 거부.
- 망고 45 회복 / 최대 HP / 만 HP 미소비 / once / 같은 request 중복.
- 충전 +50p / 최대100 / 최고 해금+3 / 경계/미소비.
- shield100/8 / hold 동결 / 치명타 뒤 흡수 / overflow HP / 소진·만료 / 갱신 소비.
- iron15 / cd0 / 전사 방어 cd0 / override3→12 / 재사용 경계 / 호출 계약 단발 / 실제 차단 미구현 안전성.
- pending 등록·동결·재개 대시6 / nearest2 / 죽은 대상 생략 / 도발8 / focus 우선순위 / 적 retreat 취소 / 적 없음 미소비.
- 선택 취소·토글·반복 사용 / 자동·수동 단일 resolve / 다음42초.
- hold 전체 후퇴·미실행 pending 버림 / 재도전 카드 기록·HP/게이지·효과 유지 / 새TP / 층 재방문.
- 양측 whitelist / 잔여 시간 / 참조 없는 metadata 깊은 복사·Node 거부 / 같은 종류 효과 독립 / 사망 효과 정리.

`strategy_ui_smoke.gd`: **23개**. 실제 Control 이벤트 라우팅으로 카드 스트립/선택/취소/타겟/사용/소모 상태/pending/마우스·터치/재개/효과/후퇴/재도전을 검증합니다.

## 23~28. Phase별 결과 및 전체 검사

| 검사 | 검사 수 | 실패 |
|---|---:|---:|
| Phase 1: 14 완료 전투 및 기타 검증 | 9,705 | 0 |
| Phase 2 | 243 | 0 |
| Phase 3 | 131 | 0 |
| Phase 4 | 119 | 0 |
| Phase 5 | 110 | 0 |
| Phase 6 | 118 | 0 |
| test_runner 합계 | **10,426** | **0** |
| 기존 배치 GUI | 18 | 0 |
| 기존 방 GUI | 17 | 0 |
| 기존 TP GUI | 18 | 0 |
| 신규 카드 GUI | 23 | 0 |
| 고유 검사 전체 | **10,502** | **0** |

같은 GUI를 headless/X11로 다시 실행한 횟수를 중복 합산하지 않았습니다. Phase 1 기존 함수 본문과 Phase 2~5/기존 GUI 테스트 파일은 바이트 그대로입니다. runner에 신규 실행만 추가했습니다. 기존 전투 수치와 3개 seed의 Phase 1 전투 결과도 유지됐습니다.

## 29. GUI 검사

네 GUI 스크립트를 headless와 실제 X11/llvmpipe에서 모두 실행했습니다. 390×844 터치 카드 스트립 가로 스크롤, 아군 선택, 사용/취소, 재개 버튼이 화면 안에 있고 지도도 최소240 이상 유지됩니다. 회복/보호막/게이지는 결과 필드로 확인합니다. 테스트는 전투 진행 시간을 고정하고 cooldown/HP를 조절하는 재현용 fixture이며 밸런스 테스트가 아닙니다.

## 30. 실제 창 검증

Xorg :93의 실제 Godot 창에 **OS XTest 마우스 입력**으로 배치 → 시작 → 자연12초 TP → 카드 선택/망고·전투회피 사용 → 자동 재개 → 자연42초 TP → 다른 아군 선택/보호막·충전 → 수동 재개 → 전체 후퇴 → 재도전 → 새 TP 스케줄/사용 기록 유지까지 확인했습니다. 첫 시도에 cooldown10000, 첫 아군HP40 fixture를 사용했고 시계는 실제 1×였습니다. 재도전 후에는 기존 HP85가 유지됐습니다.

이는 OS 입력 자동 검증이며 사람이 별도로 조작한 수동 검사를 수행했다고 주장하지 않습니다. X11 드라이버의 V-Sync 변경 불가 경고는 있으나 최종 Dummy 오디오 실행에서 script parse/runtime 오류나 검사 실패는 없습니다. 사운드는 범위 밖입니다.

화면 캡처는 `/tmp/duni-phase6-desktop-cards.png`, `/tmp/duni-phase6-mobile-cards.png`, 네 X11 로그는 `/tmp/phase6-*-x11-final.log`입니다. 임시 경로는 세션 종료 후 보존을 보장하지 않습니다.

## 31. 실제 실행 및 웹 코드 재조사

다음 두 명령을 Godot 4.6.3에서 실행하고 exit0 / script error0을 확인했습니다. `.godot` 캐시를 제외한 별도 복사에서도 editor import와 test_runner, 네 GUI를 전부 통과했습니다.

```bash
godot --headless --path godot --editor --quit
godot --headless --path godot --script res://tests/test_runner.gd
```

GUI:

```bash
godot --headless --path godot --script res://tests/strategy_ui_smoke.gd
godot --path godot
# 또는 에디터에서 godot/project.godot 열고 F5
```

F5: 길드원 선택 → 아군 영역 터치 → 배치 → 시작 → 12초+2초 감속 후 hold → 카드/아군/사용 → 재개. 방 정산 후 생존 길드원으로 같은 방을 다시 배치합니다. 일반 테스트 전투가 12초 전 끝나면 TP가 발생하지 않을 수 있어 GUI 테스트는 명시적인 긴 전투 fixture를 사용합니다.

이번 수치 조사와 판정은 현재 `dist/` 실행 코드를 직접 읽은 결과입니다. 배포 사이트를 수정·재배포·DNS 변경하지 않았습니다. 이번 Phase에서 배포 웹의 새 실플레이 대조를 수행했다고 주장하지 않습니다. 과거 UI 문구와 실제 계산식 차이는 위 표에 기록했습니다.

## 32. Godot과 웹의 남은 차이

- 실제 타워 층/획득/경제 대신 0/0 문맥과 고정6장. 웹 초기 지급 구성 전체를 옮기지 않음.
- 전사/궁수만 존재. 궁극기/장비/전체 AI/CC/은신/조종/머금기/치명적 구조 미이전.
- 철벽 실제 차단/반격/기절 및 threat AI는 미이전.
- 망고 healingPower와 충전 CC/궁극기 시전 거부, 도발 인식 조건의 나머지 경우는 후속 연결.
- UI는 카드 → 아군 → 사용 명시 버튼. 웹의 대상 터치 즉시 사용/드래그 조작은 미이전.
- once 카드는 배열 삭제 대신 consumed 감사 기록과 회색 비활성 표시.
- 최종 VFX/사운드/완성 UI 없음. 웹 첫 승리30% 회복 제외 계약 유지.

## 33. 웹 원본 SHA-256

작업 전후 `dist/` **19/19 일치, 변경0**. `migration/phase6-web-sha256.json`에 파일별 해시를 기록했습니다. tracked 파일 `git diff`도 비어 있습니다. 기존 전체 godot/가 작업 전부터 untracked이므로 git diff만으로 Godot 변경을 판정하지 않았습니다.

복원 archive의 소스116개가 Phase 5 작업 전 Godot 해시와 모두 일치합니다. archive SHA-256:

`a88e24ade1174ee812e21e7a452640a5493df3e539bd3419f1c26d7ef733dabd`

## 34. MIGRATION_NOTE

1. 실제 cooldown은 **최고 해금 인덱스+3**, 현재 층+2가 아님. UI 층 번호만 +1.
2. shield/iron은 동일 상태 갱신도 소비한다는 실제 코드 예외 보존.
3. 철벽은 정확한 준비/지속/쿨타임/호출 계약까지만. 실제 패링은 후속 전투 이전에서 구현.
4. 도발 인식 필터는 전체 캐릭터/CC·은신·머금기·조종 이전 때 확장.
5. 망고 target healingPower와 충전 gainUltimate의 모든 거부 조건은 후속 연결.
6. 보호막은 현재 일반 피해 pipeline에 선흡수. 반사/공유/치명적 구조 등 도입 시 웹 순서를 다시 유지해야 함.
7. taunt/focus/pending/대시 객체/TP 객체는 persistence whitelist 밖. 실제 retreatRemaining/specialRemaining만 상대 시간 복원.
8. full retreat와 전략카드 evade는 별개. hold 후퇴 시 이미 사용한 카드 환불 없음.
9. 같은 카드의 개별 ID/usedFloors/readyFloor는 런 소유. 재도전이 카드 쿨타임 진행이나 신규 획득으로 취급되지 않음.
10. Source member/enemy ID와 battle_id 분리, 단발 Settlement 계약 유지.
11. 기본 방어력이 일반 피해 감소에 직접 쓰이지 않는 기존 문제는 수정하지 않았음.
12. Formation은 아군 시작 위치, EnemyRoomState는 적 종료 위치; 전략 명령은 이 책임을 합치지 않음.

## 35. Phase 6만 되돌리기

기존 godot/가 untracked이므로 `git checkout godot`은 복구 방법이 아닙니다. 최신 결과를 보관한 뒤 정확한 Phase 5 archive를 복원합니다. 이 명령은 **이번 작업에서 실제 실행하지 않았습니다**. 백업 폴더가 이미 존재하면 새 이름을 사용하세요.

```bash
mv godot godot-phase6-backup
mkdir godot
tar -xzf godot-phase6-backup/migration/phase5-before-phase6.tar.gz -C godot
godot --headless --path godot --editor --quit
godot --headless --path godot --script res://tests/test_runner.gd
```

Phase 5 runner 기대값 10,308 검사/0실패, 기존 GUI를 합치면 10,361 고유 검사. 웹은 건드리지 않습니다. archive에는 생성 캐시가 없고 Phase 5 소스·문서·기존 복원 archive116개가 들어 있습니다.

## 36. Phase 7 전에 필요한 사항

1. 정확한 전체 패링 pipeline: 감지/선호/잘못된 타이밍/위력확률/창/차단·경감/반격·기절, iron hook과 cd override 연결.
2. 실제 궁극기 gain/발동 및 CC·시전 중 충전 불가, TP special의 현재 요청 계약 연결.
3. 피해→보호막→HP→구조/공유/반사 순서가 웹과 충돌하지 않도록 피해 단계별 검증 추가.
4. stealth/perception/puppet/frog 상태와 도발/focus의 유효 대상 검증 확장.
5. 장비 healingPower와 나머지 whitelist를 실제 각 기능과 연결; 단순 저장이 효과 구현을 의미하지 않음.
6. Tower 진행 도입 시 context를 실제 floor/unlockedFloor에서 공급하고 현재 고정 테스트 값을 제거.

## 37. 범위 종료

Phase 1~5 전투/배치/길드원/후퇴/패배/재도전/TP 계약을 유지했습니다. 카드에 필요한 최소 보호막만 추가했고 타워 지도/상점/이벤트/획득/저장/사운드/전체 방어·AI를 만들지 않았습니다. **Phase 7은 시작하지 않았습니다.**
