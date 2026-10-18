# Phase 5 완료 보고 — 터닝포인트

Godot **4.6.3.stable.official.7d41c59c4**에서 전사·궁수 최소 전투와 Phase 4 테스트 방에 터닝포인트를 연결했다. 기존 전투/배치/길드원/방 상태/정산 계약을 유지했다. **Phase 6 전략카드는 시작하지 않았다.**

F5 흐름: 개별 길드원 배치 → 자동전투 → 감속 → 터닝포인트 정지·성향 선택·적 계획 확인 → 수동/자동 재개 → 승리/패배/전체 후퇴 → 단발 정산 → 같은 방 재배치/재도전.

## 1. 생성 파일

경로는 `godot/` 기준이다.

| 파일 | 역할 |
| --- | --- |
| `scripts/turning_point_manager.gd` | 전투별 TP 예약·발생·제한시간·계획·단발 재개·취소 |
| `scripts/turning_point_state.gd` | 한 번의 TP 순수 상태 |
| `scripts/enemy_turning_plan.gd` | 안정적인 ID를 참조하는 적 계획 데이터 |
| `scripts/enemy_plan_executor.gd` | 계획 실행과 미래 궁극기 연결 요청 |
| `scripts/strategy_movement_controller.gd` | 웹 안전 위치 탐색·탈출 대시·6초 도주 이동 |
| `scripts/turning_point_panel.gd` | 최소 TP 표시·생존 아군 선택·성향·적 계획·재개 UI |
| `tests/phase5_tests.gd` | 신규 도메인 검사 110개 |
| `tests/turning_ui_smoke.gd` | 신규 GUI 검사 18개 |
| `migration/phase4-before-phase5.tar.gz` | 작업 직전 Phase 4 파일 98개 복구본 |
| `PHASE5_REPORT.md` | 이 보고서 |

새 스크립트 8개에 각각 `.gd.uid`가 있다. UID 포함 생성 파일 **18개**다. 캐시 `.godot/`는 소스 집계에 포함하지 않는다. 새 타워 지도나 전략카드 데이터는 만들지 않았다.

## 2. 수정 파일

| 파일 | 변경 |
| --- | --- |
| `scripts/battle_clock.gd` | NORMAL/SLOWDOWN/PAUSED/STOPPED, real/simulation 시간 분리 |
| `scripts/battle_manager.gd` | 룸 TP 연결, simulation 진입 전 시간/종료 처리, 종료 시 TP 취소 |
| `scripts/room_battle_session.gd` | 실제 방 전투 시작 성공 뒤 새 TP 생성 |
| `scripts/unit.gd` | 전투 한정 집중/도주/대시 필드, 정지 중 피해 방어 |
| `scripts/target_selector.gd` | 유효한 집중 대상의 우선권 |
| `scripts/movement_controller.gd` | 명시적인 도주 이동 연결, 정지 가드 |
| `scripts/combat_controller.gd` | 도주 중 공격 개시 금지, 정지 가드 |
| `scripts/damage_resolver.gd` | TP 완전 정지 중 전투 피해 적용 금지 |
| `scripts/enemy_state_codec.gd` | 웹의 도주/특수 효과 남은 시간 숫자 왕복 |
| `scripts/retreat_controller.gd` | TP/Clock 상태 명시 조회, 전체 후퇴 계약 유지 |
| `scripts/room_battle_screen.gd` | TP 패널, 모바일 정지 화면 표시 조정 |
| `tests/test_runner.gd` | 기존 검사 뒤에 Phase 5 연결 |
| `README.md` | 최신 보고서 안내 |

기존 파일 **13개**를 수정했다. 종류 Resource/공격 수치/배치 규칙/일반 공격 계산/Phase 4 HP 정산식을 바꾸지 않았다. F5는 기존 `room_battle.tscn`을 계속 사용한다.

## 3. TurningPointManager 구조

전투 한 시도에 속하는 `RefCounted`다. runtime 연결용 BattleManager/GuildManager 참조와 `next_at`, `serial`, `current`, `enabled`, `resolve_count`를 가진다. RoomState나 RunState가 보관하지 않는다.

`can_trigger → advance → build_plans → change_stance/resolve` 경로를 사용한다. `cancel`은 완료 전 TP를 취소하고 다음 예약을 제거한다. 승패 판정과 정산은 호출하지 않는다. 미래 궁극기 시스템 연결용 `ultimate_requested(source_enemy_id, request)` 신호를 제공한다.

BattleManager는 일반 전투와 TP 존재를 구분한다. Phase 1 독립 자동전투/Phase 3 옛 씬에는 TP가 없다. RoomBattleSession의 실제 시작 성공 뒤에만 TP가 활성화된다.

## 4. TurningPointState 구조

`turning_point_id`, `phase`, `trigger_simulation_time`, `remaining_real_time`, `enemy_plans`, `selected_member_id`, `resolved`를 가진다. phase는 `SLOWDOWN`, `PAUSED`, `RESOLVED`, `CANCELLED`다.

ID는 전투 result ID와 해당 시도의 순번으로 구성한다. UI/Scene/Unit 참조를 넣지 않는다. 과거 TP의 선택·계획은 다음 전투나 RoomState에 저장하지 않는다.

## 5. EnemyTurningPlan 구조

`plan_id`, `source_enemy_id`, `plan_type`, `target_member_id`, `metadata`, `executed`다. 종류는 `special`, `focus`, `retreat`다.

metadata는 순수 데이터만 허용하며 대입/조회 시 깊은 복사한다. Node를 넣는 대입을 거부한다. 실제 적/대상 Unit은 실행할 때 ID로 조회한다. battle_id를 지속 ID로 쓰지 않는다. 계획에는 UI 표시 문자열을 저장하지 않는다.

## 6. BattleClock 변경

| 상태 | simulation | TP/UI 제한시간 |
| --- | --- | --- |
| NORMAL | 기본 1× 진행 | TP 예약 감시 |
| TURNING_SLOWDOWN | 현재 brake 비율만큼 진행 | brake real 시간 진행 |
| TURNING_PAUSED | delta 0 | hold real 시간 계속 진행 |
| STOPPED | delta 0 | TP 취소, 재개 없음 |

`elapsed`는 simulation 시간, `real_elapsed`는 전달받은 실제 진행 시간, `simulation_delta`는 전투에 줄 delta다. Engine.time_scale을 쓰지 않는다. 1/2/4× 선택 API는 Clock 한 곳에 있으며 slowdown/hold 중 변경을 거부하고 기존 속도를 재개 후 유지한다.

현재 UI에는 배속 버튼을 추가하지 않았다. 2/4×의 값 분리는 검사했지만 웹의 accumulator 다중 고정 틱과 모든 배속 전투 결과를 이전한 단계는 아니다. 현재 실제 화면 검증은 1×다.

## 7. 실제 HTML TP 시간 규칙

근거는 현재 `dist/strategy.js`의 `TURNING_*`, `resetTurningPoint`, `startTurningPoint`, `advanceTurningPoint`, `turningPointScale`, `resumeTurningPoint`와 `dist/app.js`의 `frame`, 배속 handler, `dist/spectator.js`의 `beginSpectacle`다.

| 항목 | 현재 웹 실행 코드 | Godot |
| --- | --- | --- |
| 최초 예약 | simulation 12초 | 12초 |
| 이후 예약 | TP **시작 때** `nextAt += 30` | 동일 |
| 감속 | 2 real seconds | 동일 |
| hold 제한시간 | 40 real seconds | 동일 |
| 감속 비율 | `max(.035, 1-brake/2)` | 동일 |
| hold delta | 0 | 동일 |
| hold 종료 | 수동 버튼 또는 remaining 0 | 같은 resolve |
| speed 변경 | brake/hold 중 버튼 잠금 | Clock API 잠금 |
| timer speed | wallDt; 배속과 무관 | real_delta; 배속과 무관 |

**스케줄 차이 기록:** 요청의 예시는 “재개부터 30 simulation seconds 뒤”지만 실제 웹은 예약 시각 **12·42·72·102…**를 사용한다. 감속 동안 약 1초 simulation이 지나므로 첫 재개 이후 다음 TP까지는 약 29초가 남는다. 현재 실행 코드를 우선해 고정 예약 시각을 보존했다. 정지 40초를 simulation에 더하지 않는다.

웹 발생 조건은 tower의 interactive 전투, idle, running, !paused, intro 종료, 예약 도달, 두 생존 faction 이상이다. Godot은 그에 대응하는 시작된 미종료 방 전투·양측 생존·런 유효·Clock NORMAL을 검사한다. 아직 없는 intro/초월 정지의 잠금은 후속 연결 대상이다.

## 8. 감속 구현

예약에 도달한 틱에서 새 TP를 만들고 clock을 SLOWDOWN으로 바꾼다. 실제 brake 시간에 따라 비율을 줄이고 0.035 하한을 적용한다. 정확히 2초가 되면 hold로 전환한다. 넘어온 real 시간은 hold 제한시간에서 뺀다.

웹과 같이 해당 프레임의 갱신된 brake 비율을 사용한다. 감속 중에는 실제 전투가 계속 진행되므로 공격/사망/승패가 발생할 수 있다. 이때 전투 종료가 우선한다. 최종 카메라/VFX는 추가하지 않았다.

## 9. 정지 구현

hold에서 BattleClock delta는 0이다. BattleManager가 유닛 루프와 물리 공격 처리를 실행하지 않아 이동·AI·windup/active/recovery·cooldown·투사체·피해·simulation 시간이 유지된다. 제한시간과 UI 선택만 진행된다. 직접 피해 API에도 hold 가드를 넣었다.

timer가 자동 재개를 만드는 프레임에는 웹의 `dt=min(wallDt,.1)` 관계를 따라 전투에 최대 0.1초만 넘긴다. 긴 hold wall delta 전체가 전투에 들어가지 않는다. Godot의 렌더/physics 틱 구조는 Canvas requestAnimationFrame accumulator와 같지 않으므로 세부 프레임 단위 완전 일치는 목표로 주장하지 않는다.

## 10. 성향 변경 구현

hold에서 살아 있는 출전 아군 member ID를 선택하고 `normal`, `cautious`, `rush`, `cover`를 변경한다. Unit과 해당 GuildMemberState에 동시에 반영한다. 미참가 예비 길드원, 죽은 유닛, 잘못된 성향, 재개 이후 변경은 거부한다. 정산 후에도 개별 성향이 유지된다.

웹 `setLiveStance`는 추가로 실제 스탯과 AI intent/기회 판단/엄호 대상도 갱신한다. 현재 Godot은 성향의 **선택·저장·Unit 반영**을 연결했으며 실제 성향별 공격/회피/엄호 AI 효과를 아직 넣지 않았다. 기존 수치나 일반 AI를 임의로 수정하지 않았다.

## 11. 실제 HTML 적 계획 종류

`buildEnemyForecasts()`는 team:1 생존 적마다 **special/focus/retreat 중 균등 무작위**로 하나 생성한다. 선택된 아군 대상은 모든 계획에 기록될 수 있지만 focus에서만 사용한다. focus에 대상이 없으면 retreat로 바꾼다.

Godot도 정지 진입 시 생존 적마다 한 번 생성하고 재개 전까지 계획과 대상이 고정된다. 생성 RNG는 현재 전투 RNG를 사용한다. JS Math.random과 동일한 난수 스트림을 재현하지는 않는다.

## 12. 집중 계획 구현

웹은 살아 있는 team:0 중 **처음 발견한 type 5 힐러**를 우선하고, 없으면 **HP/최대 HP 비율이 가장 낮은 아군**을 선택한다. 같은 비율은 기존 유닛 순서를 따른다. 절대 HP 최솟값이 아니다.

실행 시 기존 공격 intent를 취소하고 해당 member ID의 우선권을 **10 simulation seconds** 부여한다. TargetSelector가 아직 유효한 집중 대상을 가장 가까운 적보다 먼저 선택한다. 대상 사망/부재/아군이 아님이면 안전하게 끝내거나 일반 최근접 탐색으로 돌아간다.

현재 두 종류 외의 실제 힐러는 추가하지 않았다. 선택 규칙은 테스트용 Resource 사본의 type ID로 검증했다. 웹의 `canPerceive` 등 은신/시야는 아직 없는 시스템이므로 후속 AI 단계에서 연결해야 한다.

## 13. 적 후퇴 계획 구현

웹 `orderStrategyRetreat → startStrategyEscapeDash → moveStrategy` 흐름을 옮겼다.

- 현재 공격을 취소하고 **6 simulation seconds** 도주 명령.
- 안전 위치: 85~715의 90 간격 후보에 ±15 난수, 적과 최소 거리 − 근처 점유 90 + 이동거리 보너스.
- 탈출 대시: 16방향, 최대 260 거리, 35~765 후보 보정. 적 거리·경로의 다른 유닛 수·안전 위치와 거리를 점수화.
- 선택 방향으로 **720 속도**의 명시적 이동. 순간이동하지 않으며 실제 이동 경계는 28~772.
- 대시 이후 안전 위치로 **이동속도 1.25배**, heading rate 9의 보간, 근처 유닛 분리/벽 회피.
- 목표가 50 이내이거나 적이 안전 목표 130 이내로 접근하면 재탐색. 명령 동안 일반 공격 개시 금지.

안전 탐색의 후보 배열은 AI 계산용이며 플레이어 자유 배치를 격자로 변경하지 않는다. 일반 전투 전체 후퇴와 달리 방/전투를 종료시키지 않는다. 26종의 크기·상태이상 movementRate/VFX는 아직 연결하지 않았다. 현재 전사·궁수 기본 크기에서 웹 계산을 사용한다.

## 14. 특수 능력 계획 처리

실제 웹 `applyEnemyForecasts()`는 공격 intent를 취소하고 ULTIMATES가 있으면 `gainUltimate(100)`, `ultThink=0`, `ultReadyAge=5`, `strategyUltimateReady=true`로 준비한다. 바로 임의 피해를 주는 기능이 아니다.

Godot은 궁극기 게이지 +100(상한100), 지속 준비 데이터와 **ultimate_requested 신호**를 연결했다. 준비 요청에는 원본 ultThink/ultReadyAge 등이 포함된다. ultThink는 웹 스냅샷 whitelist가 아니므로 지속 사전에 추가하지 않는다. 실제 궁극기 시전/효과는 구현하지 않았다. 준비 신호는 같은 계획에서 한 번만 발생한다.

## 15. 샷건 예외 처리

현재 `dist/ultimate.js`의 26개 ULTIMATES 항목 중 **type 7 샷건만 null**이다. 웹은 이때 `strategySpecialUntil=elapsed+8`, cooldown 0, 공격 스탯 1.25배를 준비한다. 샷건은 추가로 **ammo=2, reloadRemaining=0**이다.

계획 metadata에 이 정확한 예외 값이 있고 executor에 준비 경로가 있다. 샷건 UnitData/실제 공격·장전/피해 버프 계산을 새로 이전하지 않았다. 현재 지원 캐릭터는 여전히 전사·궁수다. 미래 샷건 연결을 위한 준비 데이터이며 샷건이 플레이 가능하다고 주장하지 않는다.

## 16. 수동 재개

패널의 “전투 재개”가 `TurningPointManager.resolve`를 호출한다. 유효한 hold인지 확인 → resolved 먼저 표시 → 계획 executed 처리 → 적 계획 실행/궁극기 요청 → NORMAL 복귀다. next_at은 이미 TP 시작 때 예약되어 있다.

중복 버튼이나 신호 재진입으로 계획이 두 번 실행되지 않는다. 전투가 중간에 종료되면 나머지 계획과 clock resume를 수행하지 않는다.

## 17. 자동 재개

remaining_real_time이 0이면 같은 `resolve`를 호출한다. 별도 계획 실행/정산 함수를 만들지 않았다. 수동/자동은 같은 resolve_count와 executed를 사용한다. brake 초과 real 시간도 hold에서 차감하며 정확한 0 경계를 검사했다.

## 18. 전체 후퇴와 연결

웹 `canRetreatTower()`는 초월 정지/후퇴 연출/HP 종료 연출은 막지만 **TP brake/hold를 막지 않는다.** elapsed >=20이고 양측 생존 등 기존 조건을 만족하면 TP 중에도 전체 후퇴가 가능하다.

RetreatController가 manager의 `permits_full_retreat()`와 clock STOPPED 상태를 명시적으로 확인한다. 첫 TP hold는 약13초라 아직 후퇴 불가이고, 이후 TP hold에서는 후퇴 가능하다. 정지 패널에도 전체 후퇴 버튼을 제공한다. 전체 후퇴는 TP를 취소하고 계획을 실행하지 않은 채 기존 단발 정산 경로로 끝낸다. 적 계획 retreat와 결과 RETREAT는 별개다.

## 19. 승패/게임오버와 연결

BattleManager는 TP advance보다 종료 조건을 먼저 확인한다. 감속 중 실제 사망이 발생하면 기존 물리 처리 후 종료한다. HP 0 요청은 기존 RUN_ENDED 우선순위를 유지한다.

종료 시 clock STOPPED, TP enabled=false, 다음 예약 INF, 미해결 state CANCELLED, remaining 0이다. UI 재개 버튼은 비활성이며 남은 계획을 실행하지 않는다. 후퇴/패배/승리/게임오버의 기존 Room 정산과 Player HP 손실을 중복 실행하지 않는다.

## 20. 재도전 초기화

실제 웹 `beginSpectacle → resetTurningPoint`는 매 시도 `nextAt=12`, serial0, forecasts/선택 초기화다. Godot도 새 BattleManager/TurningPointManager를 만들어 **12초부터 새 예약**한다.

RoomState/EnemyRoomState에 TP 객체나 계획을 저장하지 않는다. 단 웹에 실제 존재하는 전투 명령의 **retreatRemaining/specialRemaining 숫자**는 적 상태에 유지한다. 이전 대시·focus 타겟·TP 선택은 저장하지 않는다. 재도전 시 남은 도주는 안전 목표를 새로 찾아 움직인다. 아군은 계속 DeploymentEntry/FormationState 시작 위치를 사용한다.

## 21. 신규 테스트

도메인 6개 그룹 **110 검사**다.

| 그룹 | 주요 내용 |
| --- | --- |
| Clock/스케줄 | 최초12/직전 미발생/42·72 예약, 2초 감속, 비율 감소/.035 하한, 40초 hold, real/simulation 분리, 배속 잠금, 수동 중복 방지 |
| 정지/성향 | 모든 위치·HP·타겟·RNG·windup/active/recovery·cooldown·투사체·simulation 시간 불변, real timer, 직접 피해 거부, 개별 stance·잘못된 값·예비 제외·정산 후 유지 |
| 계획/집중/특수 | 생존 적별 순수 계획, Node metadata 거부, 힐러/낮은 HP 비율, 집중10초·대상 사망/부재, 준비 요청1회, 샷건 예외 데이터 |
| 적 도주/자동 재개 | 같은 resolve, 탈출 대시/6초/경계/공격 차단, 전투 종료와 구분, 남은 도주 저장, 같은 방 재도전·TP 초기화·plan 비저장 |
| 종료/후퇴 | 감속 중 승리/패배/RUN_ENDED 우선, 이후 계획·예약 금지, 중복 정산 유지, brake/hold 전체 후퇴, 첫 TP 후퇴 거부, hold 중 HP 런 종료 |
| 초과 시간/생존 조건 | brake 초과분 hold 차감, 정확한 자동0경계, 적 전멸이면 TP보다 종료 우선 |

GUI 신규 18 검사는 F5 배치→감속→정지→개별 성향→계획 표시→마우스 재개→390×844 터치 선택/재개→자동 재개→후퇴 정산→같은 방 새 TP 예약을 검사한다. 희귀 조건과 빠른 경계 검증은 통제된 HP/cooldown/시각 fixture를 사용한다.

## 22. Phase 1 결과

**14개 완료 전투 / 9,705 검사 / 0 실패.** 기존 함수 바이트와 시드별 승패·시간을 보존했다. 독립 최소 자동전투의 일반 수치·RNG 경로는 바꾸지 않았다.

## 23. Phase 2 결과

**6개 그룹 / 243 검사 / 0 실패.** 개별 member ID·독립 상태·주입/회수·HP/기력/게이지·사망 명단·단발 정산을 유지했다. 테스트 파일 바이트 동일.

## 24. Phase 3 결과

**6개 그룹 / 131 검사 / 0 실패.** 자유 배치·영역·58 간격·member 중복·기력0·상태 불변·진형 복원 유지. 별도 기존 GUI **18 검사 / 0 실패**. 두 테스트 파일 바이트 동일.

## 25. Phase 4 결과

**6개 그룹 / 119 검사 / 0 실패.** 후퇴 경계·적 상태 유지·예비 병력 재도전·Player HP·게임오버·중복 정산이 유지됐다. 별도 기존 방 GUI **17 검사 / 0 실패**. 두 테스트 파일 바이트 동일. 테스트 방 전투에는 TP가 연결되어도 기존 natural retry 검사가 통과했다.

## 26. Phase 5 결과

**6개 그룹 / 110 검사 / 0 실패.** 신규 GUI **18 검사 / 0 실패**. 실제 씬/Resource/기존 RoomSession 및 정산을 사용했다.

## 27. 전체 검사 수

| 검사 | 수 | 실패 |
| --- | ---: | ---: |
| Phase 1 | 9,705 | 0 |
| Phase 2 | 243 | 0 |
| Phase 3 | 131 | 0 |
| Phase 4 | 119 | 0 |
| Phase 5 | 110 | 0 |
| 메인 runner 합계 | **10,308** | **0** |
| 배치 UI / 방 UI / TP UI | 18 / 17 / 18 | 0 |
| 중복 실행 제외 전체 | **10,361** | **0** |

캐시를 제외한 새 프로젝트 복사에서 import·runner·GUI 세 종류·메인 씬 실행을 모두 확인했다. 같은 GUI를 X11에서 반복 실행한 검사 수를 이 합계에 중복 가산하지 않았다.

## 28. GUI 검사 결과 및 실행 방법

기존 배치/방 GUI와 새 TP GUI를 headless 및 **실제 X11 창**에서 실행했다. 모두 실패0이다. 390×844에서 아군 목록 좌우 스크롤, 네 성향, 적 계획, 재개/전체 후퇴가 들어가며 맵도 최소240 이상 유지된다. 실제 휴대폰을 사용한 검사는 아니다.

```sh
godot --version
godot --headless --path godot --editor --quit
godot --headless --path godot --script res://tests/test_runner.gd
godot --headless --path godot --script res://tests/deployment_ui_smoke.gd
godot --headless --path godot --script res://tests/room_ui_smoke.gd
godot --headless --path godot --script res://tests/turning_ui_smoke.gd
godot --path godot
```

`godot/project.godot`를 열고 F5로도 실행한다. 실제 창 smoke는 `godot --path godot --script res://tests/turning_ui_smoke.gd`다. 이 환경의 창은 소프트웨어 OpenGL이며 V-Sync 변경 미지원 경고가 있다. 최종 실행 로그에 스크립트 오류는 없다.

## 29. 실제 창 조작 검증

별도 X11 창에 실제 **OS 마우스 클릭**을 보내 길드원 두 명 배치/시작을 확인했다. native probe는 일반 공격 cooldown만 길게 두어 자연스럽게 양측이 생존하도록 했다. production에 시간 건너뛰기나 강제 피해 UI를 넣지 않았다.

전투를 실제 1×로 기다려 12초에서 감속·정지 진입을 확인했다. 정지 simulation 시간은 **12.993194초**였으며 hold 실제 제한시간만 감소했다. 적 집중/특수 계획이 표시됐다. 두 번째 길드원 선택→신중함 클릭→전투 재개를 OS 입력으로 확인했고 해당 길드원의 stance만 변경됐다. 재개 후 simulation 시간이 다시 증가했다.

이후 전체 후퇴→같은 방 재도전→새 시작을 클릭했다. 직후 시도2/serial0/NORMAL을 확인했고, 같은 시도에서 다시 실제 12초 TP에 들어간 것을 확인했다. 성향은 계속 유지됐다. 자동 재개와 모바일 터치 경로는 GUI smoke에서 별도로 검사했다. 전체 자연 전투 밸런스/사람의 실기기 조작 검사라고 주장하지 않는다.

## 30. 웹과 Godot의 차이

| 항목 | 차이 및 처리 |
| --- | --- |
| 다음 예약 설명 | 요청 예시의 재개+30과 달리 실행 코드는 12·42·72; 코드 우선 적용 |
| 표시 UI | 웹 최신 `renderTurningPanel`은 성향/전략카드 중심이며 enemy forecasts 목록을 표시하지 않음. 이번 요청대로 **디버그 적 계획 목록**을 표시 |
| 성향 효과 | 웹의 실제 스탯·AI 갱신은 아직 제외, 값 선택·Unit/Guild 저장만 연결 |
| 특수 능력 | 실제 궁극기는 미구현; 게이지/준비 데이터/호출 지점만 |
| 샷건 | 예외 metadata·준비 경로만, 캐릭터/공격/장전/1.25 피해 효과 미구현 |
| 도주 | 기본 크기·기본 이동속도에 해당하는 웹 계산; 군중제어·다른 캐릭터 크기·최종 VFX 연결 전 |
| 집중 | 기본 타겟 우선권10초; 은신 canPerceive/도발/엄호 우선순위 전체는 후속 |
| 프레임 진행 | Godot 기존 physics 구조에 slowdown delta 연결; 웹 Canvas accumulator의 프레임별 완전 재현은 아님 |
| 배속 | Clock API/잠금/real timer 관계 확보, 최종 배속 UI와 모든 2/4× 전투 재현 검증은 제외 |
| intro/초월 잠금 | 아직 없는 시스템이므로 TP trigger/resume/후퇴 잠금 연결은 후속 |

Phase 4에서 기록한 첫 승리30% 회복, 게임오버 성향 reset, 실제 Encounter/EnemyStats, 전체26종/AI/패링/상쇄/넉백/상태이상/스킬/장비/피로/보상/맵/저장/사운드/최종 VFX 등의 차이도 남아 있다. 이 Phase에서 균형이나 웹의 이상 동작을 수정하지 않았다.

## 31. 웹 원본 해시 확인

작업 전후 `dist/` **19개 원본 SHA-256이 전부 일치**한다. 파일 추가·삭제도 없다. Git 추적 파일 diff는 없고 이전처럼 `godot/`가 untracked다.

HTTPS 검증을 유지해 받은 배포 `https://duniarena.site/strategy.js?v=83`도 현재 저장소와 바이트 동일했다. SHA-256: `32298e87af96ecc718002a3e1362b0377714141c437eab9ef45d88d0e1ddf08d`.

복구 archive 98개 파일은 작업 전 Godot 해시와 정확히 일치한다. Phase 2/3/4 테스트, 기존 GUI 두 개, Phase 1 테스트 함수도 바이트 동일함을 확인했다. 사이트 전체 플레이나 재배포를 이번 Phase에서 새로 수행하지 않았다.

## 32. MIGRATION_NOTE

1. TP 스케줄은 실제 웹의 12·42·72 절대 simulation 예약이다. 정지 real time을 포함하지 않고 감속 simulation은 포함한다.
2. Clock state가 진행/감속/정지/종료를 소유한다. Engine.time_scale을 개별 시스템에서 쓰지 않는다.
3. 수동/자동 재개는 하나의 resolve이며 resolved를 효과/신호보다 먼저 표시한다.
4. 계획은 전투 시도 한정, enemy/member ID 참조다. RoomState에는 TP/Node/plan 객체를 저장하지 않는다.
5. 후퇴는 TP 중에도 elapsed>=20이면 가능하다. 적 계획 도주는 전투 종료 RETREAT가 아니다.
6. 웹에 실제 존재하는 retreatRemaining/specialRemaining 숫자만 상태에 유지한다. focus/대시/TP 선택은 새로 만든다.
7. 궁극기는 준비 요청 hook만 구현했다. 실제 cast/효과/자동 충전/충전 방해는 다음 기술 이전에서 연결해야 한다.
8. 샷건8초·1.25배·ammo2·즉시 장전 해제는 정확한 미래 연결 데이터다. 현재 두 종류 외 캐릭터를 추가하지 않았다.
9. 성향의 실제 AI·스탯은 미구현이다. AI reset과 엄호 bind는 향후 원본 AI 이전 때 연결한다.
10. 집중의 힐러 type5/HP비율 우선권을 preserve하되 시야·은신·도발 우선순위는 후속이다.
11. 적 도주 이동은 기본 크기의 54 경로 판정/웹 후보·heading을 사용한다. 미래 크기·movementRate·기절 interrupt를 연결할 때 소스 규칙을 재확인한다.
12. 정지 중 직접 전투 피해도 차단한다. 향후 전략카드 회복/보호막 부여는 전투 공격 피해와 다른 명시 경로를 사용해야 한다.
13. 자동 재개 프레임에 hold 전체 real_delta를 simulation으로 넘기지 않는다. 웹의 .1 cap 관계를 보존했다.
14. 현재 1× UI 검증만 수행했다. 배속의 고정 틱 분할·히트스톱·초월·종료 연출 시간 중첩은 후속이다.
15. 최신 웹은 적 forecasts를 생성하지만 패널에 목록은 표시하지 않는다. 이번 요청의 디버그 목록은 의도적인 표시 차이다.
16. 기존 Phase 4의 단발 사망 손실/Room 정산 책임은 변경하지 않았다. TP manager가 정산하지 않는다.
17. 세이브 파일/타워 지도/전략카드/추가 캐릭터/최종 VFX는 없다. 순수 데이터 경로와 런 메모리 상태만 사용한다.

## 33. Phase 5만 되돌리기

아래 복구 명령은 현재 프로젝트에 실행하지 않았다. 백업 디렉터리명이 이미 존재하면 다른 이름을 사용한다. 웹은 건드리지 않고 Phase 4를 복원한다.

```sh
mv godot godot-phase5-backup
mkdir godot
tar -xzf godot-phase5-backup/migration/phase4-before-phase5.tar.gz -C godot
godot --headless --path godot --editor --quit
godot --headless --path godot --script res://tests/test_runner.gd
```

archive는 Phase 4 소스/UID/테스트/보고서/이전 archive 98개를 포함하며 캐시를 제외한다. 복구 후 메인 runner는 **10,198 검사 / 0 실패**가 기대값이다. 기존부터 godot이 untracked이므로 `git clean`으로 복구하지 않는다.

## 34. Phase 6 전에 필요한 사항

- 실제 `STRATEGY_CARDS`의 6종, once/floor/cooldown 소모 규칙·선택/드래그·타겟 유효성·원본 상태 whitelist를 다시 확인한다.
- 카드 명령은 hold에서 선택하고 재개 시 pending 명령을 실행하는 웹 순서를 유지한다. 적 계획→아군 pending retreat/taunt 순서를 별도로 연결한다.
- 보호막/치유/궁극기 충전 등 미구현 능력과 데이터만 가능한 범위를 먼저 정한다. 없는 효과를 임의 생성하지 않는다.
- TP hold에서도 카드 회복/상태 부여는 허용해야 하므로 일반 전투 피해 가드를 우회하는 만능 호출 대신 전용 효과 경로를 설계한다.
- 궁극기/상태이상/초월/intro/후퇴 연출 잠금이 도입되면 clock/manager의 시작·재개·전체 후퇴 조건에 연결한다.
- 아군 pending 명령과 적 남은 명령을 상태 회수 규칙에 맞춰 저장하되 TP 객체를 방 상태에 넣지 않는다.
- 최초 승리 치유와 게임오버 stance reset 등 이전 Phase 미확정 사항은 별도 게임 규칙 결정으로 유지한다.

현재 검사에서 확인된 실패는 없다. **Phase 6은 시작하지 않았다.**
