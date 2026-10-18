# Phase 4 완료 보고 — 후퇴·패배·같은 방 재도전

Godot **4.6.3 stable official**에서 구현·검증했다. 범위는 전사·궁수와 하나의 메모리 내 테스트 방이다. Phase 5 터닝포인트는 시작하지 않았다. 웹 원본은 수정하지 않았다.

현재 F5 흐름은 **개별 길드원 선택 → 자유 배치 → 전투 → 후퇴/패배/승리 → 단발 정산 → 같은 방 재배치**다. 패배와 런 게임오버는 별도 결과다. 아군은 새로 배치하고, 적은 이전 시도의 종료 HP·위치·유지 대상 상태에서 새 전투 인스턴스로 생성된다.

## 1. 생성 파일

아래 경로는 `godot/` 기준이다.

| 파일 | 역할 |
| --- | --- |
| `scripts/battle_end_reason.gd` | 전투 종료 이유 enum |
| `scripts/room_state.gd` | 방 식별, 클리어, 시도 수, 적 명단, 활성 정산 ID |
| `scripts/enemy_room_state.gd` | 방 소유 개별 적의 순수 지속 데이터 |
| `scripts/enemy_state_codec.gd` | 적 상태 주입·스냅샷·회수, 좌표 보정 |
| `scripts/combat_persistence.gd` | 방 소유권·전체 적 배치/결과 검증, 상태 회수 |
| `scripts/retreat_controller.gd` | 전체 전투 후퇴 조건 및 단발 요청 |
| `scripts/room_battle_session.gd` | 길드·방·전투 연결, 사망 이벤트와 정산의 소유자 |
| `scripts/room_battle_screen.gd` | Phase 3 화면을 상속한 최소 재도전 디버그 화면 |
| `scenes/room_battle.tscn` | 현재 F5 시작 씬 |
| `tests/phase4_tests.gd` | Phase 4 도메인·씬 검사 119개 |
| `tests/room_ui_smoke.gd` | 실제 Control·마우스/터치 입력 GUI 검사 17개 |
| `migration/phase3-before-phase4.tar.gz` | 작업 직전 Phase 3 소스 75개 복구본 |
| `PHASE4_REPORT.md` | 현재 보고서 |

새 GDScript 10개에는 각각 Godot 생성 `.gd.uid`가 있다. 생성 파일은 UID 포함 **23개**다. `.godot/`는 재생성 가능한 캐시이며 이 집계에 포함하지 않는다. 복구 archive는 개발용이며 게임 세이브 기능이 아니다.

## 2. 수정 파일

| 파일 | 변경 역할 |
| --- | --- |
| `project.godot` | F5 시작 씬을 `room_battle.tscn`으로 변경 |
| `scripts/run_state.gd` | 플레이어 HP, 게임오버 이유, 사망 손실 영수증 |
| `scripts/unit_data.gd` | 사망 손실 계산용 불변 `base_gold_cost` 추가 |
| `data/warrior.tres`, `data/archer.tres` | 원본 기본 비용 100/120 추가 |
| `scripts/unit.gd` | `source_enemy_id`, `source_room_id` 추가 |
| `scripts/battle_unit_factory.gd` | 기존 길드원 생성과 분리된 적 주입 경로 및 일괄 검증 |
| `scripts/battle_manager.gd` | 종료 이유·방 ID·HP 게임오버 요청, 취소 전 스냅샷 |
| `scripts/battle_result.gd` | 방/적 결과와 종료 이유, 기존 명칭 호환 별칭 |
| `scripts/battle_settlement.gd` | 기존 길드 정산 보존, 방 정산 및 단발 사망 손실 |
| `scripts/deployment_board.gd` | 저장된 적 현재 HP 표시; 기존 데이터는 최대 HP로 표시 |
| `tests/test_runner.gd` | 기존 테스트 뒤에 Phase 4 검사 연결 |
| `README.md` | 최신 보고서와 F5 진입 씬 안내 |

기존 파일 **13개**를 수정했다. 공격·이동·타겟 선택·피해 계산의 수치와 실행 로직은 변경하지 않았다. 기존 `battle.tscn`, `deployment.tscn`은 계속 실행할 수 있다.

## 3. RoomState 구조

`RefCounted` 순수 데이터다. `source_run_id`, `room_id`, `cleared`, `enemy_state`, `battle_attempt_count`, `active_result_id`, `settled_result_ids`를 가진다. `enemy_state`는 `enemy_id → EnemyRoomState`이며 죽은 적도 남긴다. 새 적 추가는 전투 중·클리어 후·중복 ID에서 거부한다.

첫 세션에서 런 소유권을 연결한다. 다른 런에서 같은 방 객체를 사용하거나 활성 시도가 있는 방에 동시에 입장할 수 없다. 실제 전투 시작이 성공한 경우만 시도 수가 증가한다. 보상·타워 지도·방 생성기는 없다.

## 4. EnemyRoomState 구조

`enemy_id`, `unit_type_id`, `current_hp`, `position`, `ultimate_gauge`, `stance`, `persistent_state`를 가진다. `alive`는 유한한 `current_hp > 0`에서 계산한다. 궁극기 게이지는 0~100이다.

`persistent_state`는 순수 값만 허용하고 읽기·쓰기 시 깊은 복사한다. Node·Resource/Scene 참조 등 객체를 넣는 대입을 거부한다. 테스트용 중첩 사전도 별개 상태로 왕복한다. 실제 웹의 적 스냅샷에 초월 게이지가 없으므로 적 지속 데이터에는 이를 추가하지 않았다.

## 5. enemy_id / battle_id 관계

아군은 `GuildMemberState.member_id → Unit.source_member_id`, 적은 `EnemyRoomState.enemy_id → Unit.source_enemy_id`다. 적에게 member ID를 쓰지 않는다.

`battle_id`는 한 BattleManager 내부의 생성 순서 정수다. 재도전에서 바뀔 수 있고 같은 정수가 다른 시도에서 다시 사용될 수도 있다. 전투 인스턴스의 전역 식별은 **`battle_result_id + battle_id`**이며 방 적의 지속 식별은 **방 소유권 + enemy_id**다. `battle_result_id`는 전투마다 새 무작위 ID이고 전투 RNG와 독립적이다.

## 6. 적 상태 주입 방식

`RoomBattleSession.start → CombatPersistence.placements → EnemyStateCodec.placement → BattleUnitFactory → EnemyStateCodec.inject` 순서다. 먼저 방의 모든 적 데이터를 검증한다. 잘못된 적이 있으면 일부만 생성하지 않고 시작을 거부한다.

생존 적만 새 Unit으로 생성하며 enemy ID·방 ID·HP·위치·궁극기 게이지·성향·고유 상태 사본을 주입한다. 저장된 일반 공격 `cooldown`도 복원한다. 일반 공격 단계와 타겟은 새로 시작한다. 죽은 적을 새로 생성하지 않는다.

## 7. 적 상태 회수 방식

BattleManager가 종료 시 최종 결과를 분리된 값으로 캡처한다. **일반 공격 취소 전에** 적 cooldown을 읽는다. 이후 공격 취소, 이동 정지, 투사체 제거, 방 전투 타겟 해제를 수행한다.

`BattleSettlement.apply_room`이 런·방·활성 시도·적 ID·HP·좌표·생존/사망 목록 전체를 검증한 뒤 `CombatPersistence.restore`로 기존 적 객체에 반영한다. 후퇴·패배·승리·DRAW·HP 게임오버 모두 같은 스냅샷 경로를 사용한다. Scene 전체를 저장하지 않는다.

## 8. 현재 웹 적 지속 상태 조사

최우선 근거는 `dist/tower.js`의 `TOWER_STATE_FIELDS`(193행), `applyTowerStats`(667행), `snapshotTowerCombatState`(670행), `snapshotTowerEnemies`(671행), `cloneTowerCast`(672행), `restoreTowerEnemyCasts`(673행), `dist/puppet.js`의 조종 스냅샷/복원 함수다.

| 실제 웹 저장 값 | 분류 | Phase 4 처리 |
| --- | --- | --- |
| `hp`, `x`, `y`, `ultGauge`, `stance` | 현재 구현 | HP·위치·게이지·성향 왕복; 게이지/성향의 실제 능력은 없음 |
| `combatId` | 현재 개념 구현 | 옛 battle ID를 지속 ID로 사용하지 않고 안정적인 `enemy_id`로 적 재연결 |
| `state.cooldown` | 현재 구현 | 실제 CombatController cooldown 주입·회수 |
| `heal`, `totemClock`, `chargeTotemClock` | 후속 구현 | 치유·장비 타이머 미구현 |
| `dash`, `defenseCooldown`, `parryCooldown`, `parryTime`, `parryCounterUsed`, `parryPulseUsed` | 후속 구현 | 대시·방어·패링 미구현 |
| `shieldHp`, `shieldTime`, `ironDefenseTime`, `stun`, `invincible` | 후속 구현 | 보호막·상태이상·무적 미구현 |
| `shadowTime`, `guardianUltTime`, `mirrorReflectTime`, `revealTime`, `curseTime` | 후속 구현 | 캐릭터 효과 유지시간 미구현 |
| `guardRemaining`, `guardStacks`, `guardReady` | 후속 구현 | 수비 태세 미구현; 웹은 재생성 위치에서 guardAnchor를 재구성 |
| `damageTakenTotal`, `dolphinStacks`, `predatorStacks` | 후속 구현 | 누적 피해·고유 성장 미구현 |
| `shotsFired`, `duelRounds`, `ammo`, `reloadRemaining`, `sniperBurstReady` | 후속 구현 | 공격 카운터·가위바위보·장전·연발 미구현; 궁수 3타 패시브도 아직 없음 |
| `ultReadyAge`, `ultUses`, `pickupTime` | 후속 구현 | 궁극기 판단·사용 횟수·검 회수 미구현 |
| `bomberRush`, `bomberRushTime`, `bomberFuse`, `transferUsed`, `strategyUltimateReady` | 후속 구현 | 자폭·전이·전략 효과 미구현 |
| `satelliteBursts`, `paladinSwings`, `paladinBlessingTime`, `tankFlameReady`, `tankHeadingAngle`, `shockStacks`, `face` | 후속 구현 | 해당 캐릭터 고유 상태·시야 방향 미구현 |
| `retreatRemaining`, `specialRemaining` | 후속 구현 | 웹은 절대 종료시각 대신 남은 시간 저장; 개별 명령·전략 상태 미구현 |
| `lostSword`의 나머지 값과 `dx`, `dy` | 후속 구현 | 웹은 유닛 위치 상대 좌표로 저장하고 복원 시 35~765로 보정; 두비두밤 미구현 |
| `puppetControl` | 후속 구현 | 웹은 남은 시간, 팀/진영, 주인 guild/room-enemy ID, 방 ID 등을 저장·복원 |
| `ultCast` 및 내부 `targetId`, `targets`, `dashHits` | 후속 구현 | 웹은 cast 복제 후 옛 적 combat ID를 새 ID로 연결; 검객 대시 중 strikeId는 제거 |
| 적 `transGauge` | 웹에서도 유지하지 않음 | `snapshotTowerEnemies`에 없음; 아군은 별도로 저장 |
| 일반 AI/타겟/일반 공격 단계·판정/투사체/장판 | 웹에서도 유지하지 않음 | 9항 참고 |

이 표는 **46개 TOWER_STATE_FIELDS 전체**와 추가 스냅샷 항목을 포함한다. 후속 항목은 `persistent_state`에 이미 들어 있는 순수 값의 왕복을 지원하지만, 해당 전투 시스템이 없으므로 자동 생성·시간 경과·실제 효과를 구현한 것은 아니다. `ultCast` 전용 복원과 타겟 ID 재연결도 이번 범위에 없다.

## 9. 유지하지 않는 전투 상태

웹 스냅샷의 화이트리스트에 일반 AI의 brain/진입 계획/현재 타겟, 일반 공격 windup/active/recovery 객체·근접 판정, 발사된 투사체, 장판·VFX는 없다. 웹도 전투 Scene 전체를 일시정지했다 이어가는 방식이 아니다. 적 궁극기 cast는 위 표처럼 예외적으로 일부 유지한다.

Godot도 일반 타겟, 공격 단계, 속도, 투사체, 순간 판단을 적 방 데이터에 넣지 않는다. UI Node, Unit Node, Controller, Tween, Timer, Scene 경로를 저장하지 않는다. 아군 전투 종료 위치는 FormationState에 넣지 않는다.

## 10. 후퇴 조건

근거: `dist/tower.js:4`, `canRetreatTower`(682행).

**simulation time ≥ 20.0초**이며 시작된 미종료 방 전투, Player HP > 0, 게임오버 아님, HP 종료 요청 없음, 살아 있는 출전 아군과 적이 각각 하나 이상, 중복 후퇴 처리 아님을 요구한다. **19.999초 거부 / 정확히 20초 허용**을 검사했다.

웹의 초월 정지·후퇴 연출·HP 게임오버 연출 잠금은 해당 시스템을 이전할 때 추가해야 한다. 현재 Phase에 없는 시스템용 가짜 상태는 만들지 않았다. 배치 취소는 후퇴가 아니다.

## 11. 후퇴 처리 순서

조건 확인 → 처리 잠금 → `finish_with_reason(RETREAT)` → clock 정지 → 아군/적 스냅샷 → 순간 공격·투사체 정리 → finished 이벤트 1회 → 방 정산 → 참가 기력 -1/미참가 +1 → 적 상태 반영 → 게임오버 확인 → 결과 표시.

살아 있는 참가자는 남은 HP로 생존한다. 사망 참가자는 HP 0이다. 이미 발생한 사망 HP 손실은 유지하고 추가 패배 20 손실은 없다. 방은 미클리어다. 웹은 `settleTowerBattle(false,false,true)`를 먼저 실행한 뒤 1.9초 후퇴 연출을 한다. 현재는 전투를 즉시 멈추며 최종 연출을 구현하지 않는다.

## 12. 패배 처리 순서

실제 사망 이벤트에서 Player HP 손실 → 물리 틱의 공격 처리 완료 후 출전 생존 진영 판정 → DEFEAT 스냅샷/종료 → 아군 지속 상태·기력 정산 → 적 상태 회수 → HP가 남아 있으면 추가 20 손실 → 방 클리어 여부 → 전체 길드 생존/Player HP 게임오버 판정.

방은 적 생존자가 남아 있으므로 미클리어다. 미참가 생존 길드원과 Player HP가 남아 있으면 재도전 가능하다. 이번 출전부대 전멸을 런 전체 전멸과 혼동하지 않는다.

## 13. 승리 처리 순서

적 전멸/아군 생존 → VICTORY 스냅샷/종료 → 아군 상태·기력 회수 → 죽은 적 상태 반영 → 추가 패배 손실 없음 → Player HP > 0이면 방 클리어 → 게임오버 확인 → 결과.

클리어 방은 재입장·재도전할 수 없다. 보상·첫 승리 회복은 이번 단계에서 제외했다. 웹의 **양측 전멸도 정산 후 Player HP가 남아 있으면 방 클리어**, HP 0이면 적 전멸이어도 클리어하지 않는 조건을 보존했다.

## 14. Player HP 초기값과 근거

`dist/tower.js:196`의 `newTowerState()`는 `hp:100,maxHp:100`이다. RunState도 **100/100**으로 시작한다. 개별 길드원 HP와 별개이며 유한값만 받고 0~최대 HP로 제한한다. HP 0은 런 종료 요청으로 전투 종료 경계에서 처리한다. 웹 `combat.js`도 물리 처리 후 HP 게임오버를 일반 승패보다 우선 확인한다.

## 15. 길드원 사망 HP 손실

`TOWER_DEATH_HP_RATE=.05`와 `towerUnitDied()`의 **`TYPES[u.type].cost × 0.05`**를 그대로 사용한다. `dist/app.js`의 실제 기본 비용은 전사 100, 궁수 120이므로 각각 **5 HP / 6 HP**다. 반올림하지 않는다. combat Resource의 기존 스탯은 바꾸지 않았다.

**사망 순간 `unit_died → RoomBattleSession → BattleSettlement.record_member_death` 한 경로만 HP를 차감한다.** 최종 정산은 사망 영수증과 dead 목록을 대조하고 재차 차감하지 않는다. 영수증은 result ID/member ID 기준이다.

## 16. 패배 추가 손실

`settleTowerBattle()`의 `penalty=won||retreat||tower.hp<=0?0:20`을 보존했다. 일반 패배는 **20**, 후퇴·승리는 **0**, 사망 손실로 이미 HP가 0이면 추가 차감하지 않는다. DRAW도 비승리/비후퇴이므로 HP가 남아 있으면 20이다. 사망 손실과 일반 패배 손실은 함께 발생할 수 있다.

## 17. 게임오버 판정

`player_hp <= 0` 또는 **전체 보유 길드원에서 HP > 0인 인원이 없음**이다. 예비 길드원도 포함한다. `RunState.GameOverReason`은 `NONE`, `PLAYER_HP`, `NO_LIVING_MEMBERS`다. HP 0 이유를 우선한다.

HP 사망 손실이 전투 중 0을 만들면 `run_end_requested`를 설정하고 같은 물리 처리의 종료 판정에서 스냅샷을 먼저 캡처한다. 이후 공격·피해·AI가 진행되지 않는다. 정산 후 모든 길드원 사망 판정도 한다. 부활/새 런 기능은 없다.

## 18. 재도전 흐름

결과 → 같은 RoomState 재입장 검사 → 생존 길드원만 이전 시작 진형 복원 또는 새 배치 → 저장된 생존 적과 새 BattleManager 생성 → 아군 UnitStateCodec·적 EnemyStateCodec 주입 → 새 result ID로 전투 시작.

다른 생존 길드원을 선택할 수 있고 아군 좌표는 새 DeploymentEntry를 따른다. HP·기력·게이지·성향·고유 상태는 기존 Phase 2 계약을 따른다. RNG/AI를 저장하지 않아 같은 적 상태에서 다른 전투 결과가 나올 수 있다. 타워 지도 없이 동일 테스트 방으로 연결했다.

## 19. 죽은 적 처리

방 명단에서 삭제하지 않고 `current_hp=0`, `alive=false`로 남긴다. 후퇴·패배 후에도 새 Unit을 만들지 않는다. 이전 시도의 죽은 적을 뒤늦은 결과로 부활시키는 정산을 거부한다. 적처치 보상은 없다.

## 20. 적 위치 유지

유효한 적 종료 위치를 그대로 다음 시도의 시작 위치로 사용한다. 최초 배치 위치로 리셋하지 않는다. 웹 복원 경계 **28~772**를 양 축에 적용한다. 범위 밖 유한값만 clamp하며 NaN/Infinity에는 안전 기준 위치 `(640,400)`를 사용한다. 이 fallback은 손상 데이터 처리 선택이며 웹의 비유한 좌표 처리보다 명시적이다.

정상 좌표를 충돌 방지용으로 임의 이동시키지 않는다. 적이 아군 구역 안에 남아 있으면 해당 적 위치가 Phase 3 아군 배치의 blocker로 사용된다. 아군은 진형 복원/새 배치의 규칙으로 가까운 빈 위치를 찾는다.

## 21. BattleEndReason / BattleResult

전투 이유는 `VICTORY`, `DEFEAT`, `RETREAT`, `DRAW`, `RUN_ENDED`다. RUN_ENDED는 HP 종료 요청으로 전투가 끝났다는 의미이며 런 종료 이유는 RunState에 별도로 있다.

기존 `winner_team`, `battle_result_id`, `elapsed`를 유지하고 읽기 별칭 `winning_team`, `result_id`, `battle_time`을 제공한다. `room_id`, 참가/생존/사망 member ID, 생존/사망 enemy ID, 양측 순수 상태 스냅샷이 있다. UI 문자열을 결과에 넣지 않는다. 후퇴·RUN_ENDED winner는 -1이며 draw bool은 DRAW에서만 true다.

## 22. 중복 정산 방지

런의 `settled_battle_ids`, 방의 `active_result_id`/`settled_result_ids`, 사망 영수증을 분리한다. 동일 결과 재적용은 ALREADY_SETTLED이며 기력·HP·방 상태가 변하지 않는다. 다른 런·다른 방·다른 활성 시도·손상 스냅샷·불일치 종료 이유는 거부한다.

기존 길드 전용 `BattleSettlement.apply`로 방 결과 ID를 소비할 수 없도록 방 결과는 거부하고 전용 `apply_room`만 사용한다. 결과 전체 검증을 마친 뒤 아군·적 상태를 반영하며 동기 commit 중 await/외부 신호가 없다. 유효하지 않은 최종 정산은 방을 새 시도로 넘기지 않는다. 이미 전투 중 발생한 실제 사망 손실은 무효 스냅샷 때문에 되돌리지 않는다.

## 23. 신규 테스트 목록

`tests/phase4_tests.gd`의 6개 그룹에서 요청한 Phase 4 사례를 검사한다.

| 그룹 | 주요 검사 |
| --- | --- |
| `test_retreat_and_retry` | 미시작/19.999/20초/반복 후퇴, 살아 있는·죽은 아군 HP, 기력, 사망 손실, 추가 패배 손실 제외, 적 HP·좌표·궁극기·성향·cooldown·중첩 상태, 죽은 적 제외, 동일 enemy ID/새 battle ID, 새 아군 배치, 첫 승리 자동 회복 제외, 클리어·중복 정산 |
| 패배 그룹 | 방 미클리어, 적 HP·위치 유지, 추가 20 HP, 예비 생존자 재도전, 실제 자동전투로 후속 승리, 과거 결과 재적용 거부 |
| 게임오버 그룹 | 전원 전투불능, 예비 생존자와 HP 0, RUN_ENDED 우선 처리/적 스냅샷, 사망+패배 손실, 궁수 6 HP 사망 손실 |
| 조건/DRAW 그룹 | 아군/적 생존자 없는 후퇴 거부, 양측 마지막 사망, DRAW의 추가 손실·클리어, 정상 VICTORY |
| Codec/일괄 검증 그룹 | HP 초기값, 영역 밖/NaN/Infinity 보정, 게이지 범위, 순수 데이터·복사·Node 거부, 손상 방 시작 거부, 다른 런 거부, 손상 결과 무변경, 방 결과의 legacy apply 차단, 유효 정산·중복 방지 |
| F5 씬 그룹 | 길드·적 초기화, 미시작 배치, 전투·후퇴·결과, 다음 진형/적 상태 복원 |

`room_ui_smoke.gd`는 선택·배치·시작·20초 활성화·후퇴·상태 표시·같은 방 복원·새 예비 길드원 패배·재도전·HP 게임오버·모바일 크기에서 17개 UI 검사를 추가한다. 기존 Phase 1~3 및 Phase 3 GUI 검사를 함께 실행했다.

## 24. Phase 1 결과

**14개 완료 전투, 9,705 검사, 0 실패.** 전사/궁수 조합, 3대3, 단독 생존, 근접 동시 사망, 타겟 교체, 경계, 적 없음, 피해/치명타/공격 단계/종료 불변성 검사가 유지됐다. 기존 Phase 1 테스트 함수는 작업 전과 동일하다.

## 25. Phase 2 결과

**6개 그룹, 243 검사, 0 실패.** 동일 종류 길드원의 독립 상태, 주입·회수, 두 전투 HP 유지, 기력 경계, 사망 명단, 단발 정산이 유지됐다. 테스트 파일은 작업 전과 바이트 동일하다.

## 26. Phase 3 결과

**6개 그룹, 131 검사, 0 실패.** 배치 영역/58 간격/개별 member ID/사망·기력0/이동·해제/상태 불변/진형 복원이 유지됐다. 테스트 파일은 작업 전과 바이트 동일하다. 기존 별도 배치 UI 테스트도 **18 검사, 0 실패**이며 파일을 변경하지 않았다.

## 27. Phase 4 결과

**6개 그룹, 119 검사, 0 실패.** 신규 도메인 테스트는 자동 테스트 runner에 연결했다. 새 GUI 테스트는 별도 실행한다. 모든 검사는 실제 Godot 씬·Resource·도메인 경로를 사용하며 복잡한 경계 사례에는 제어된 HP/시각/피해 fixture를 사용했다.

## 28. 전체 검사 수 / 실패 수

| 검사 | 수 | 실패 |
| --- | ---: | ---: |
| Phase 1 | 9,705 | 0 |
| Phase 2 | 243 | 0 |
| Phase 3 | 131 | 0 |
| Phase 4 | 119 | 0 |
| 메인 runner 합계 | **10,198** | **0** |
| 기존 배치 UI | 18 | 0 |
| 신규 방 전투 UI | 17 | 0 |
| 중복 실행을 제외한 전체 검사 | **10,233** | **0** |

같은 GUI 검사를 headless와 X11에서 반복 실행한 횟수를 합계에 중복 가산하지 않았다.

## 29. Godot 및 GUI 실행 결과

Godot 버전은 `4.6.3.stable.official.7d41c59c4`다. 프로젝트 editor import, 스크립트/씬 로드, 메인 테스트, 기존/신규 GUI headless 검사를 수행했다. `.godot/`를 복사하지 않은 별도 새 캐시 프로젝트에서도 동일 검사를 실행했다.

실제 X11 창에서도 `tests/room_ui_smoke.gd` **17 검사 / 0 실패**를 확인했다. 소프트웨어 OpenGL 환경에서 V-Sync 설정 미지원 경고만 있었으며 스크립트 오류는 없었다. 390×844 화면 크기를 검사했지만 실제 휴대폰에서 테스트한 것은 아니다.

직접 실행:

```sh
godot --version
godot --headless --path godot --editor --quit
godot --headless --path godot --script res://tests/test_runner.gd
godot --headless --path godot --script res://tests/deployment_ui_smoke.gd
godot --headless --path godot --script res://tests/room_ui_smoke.gd
godot --path godot
```

Godot 에디터에서 `godot/project.godot`를 열고 F5를 눌러도 된다. 창 테스트는 `godot --path godot --script res://tests/room_ui_smoke.gd`로 실행한다. 버튼 UI에는 ID·HP·기력·게이지·배치 여부가 표시된다. 선택 후 맵 클릭/터치로 배치·재지정하고, 제거/초기화 버튼으로 배치를 해제한다. 후퇴 버튼은 20초 이전 비활성이다. 결과의 재도전 버튼은 생존 예비 길드원/Player HP/미클리어 조건에서 활성이다.

## 30. 실제 창 조작 확인

X11 창에 도구로 **실제 OS 마우스 클릭**을 보내 다음 흐름을 별도로 확인했다.

- 길드원 두 명 선택·배치·전투 시작.
- 실제 1× simulation time이 20초를 지난 뒤 후퇴 버튼 클릭(확인된 종료시각 33.633초).
- 사망 아군 1명의 손실로 Player HP 95; 후퇴 추가 손실 없음. 생존 아군 HP 43 유지.
- 같은 방 재입장: 죽은 적 1명 미등장, 손상 적 HP 77과 후퇴 직전 위치 유지.
- 새 예비 길드원을 새 위치에 배치해 같은 방 재도전. 해당 출전부대 패배 후 Player HP 70, 다른 생존 길드원이 있어 게임오버 아님.
- 다시 재배치·재도전 후 Player HP 0 시 RUN_ENDED, 상태 스냅샷, 재도전 잠금.
- 별도 런에서 전체 보유 길드원이 사망한 경우 Player HP 75가 남아도 NO_LIVING_MEMBERS로 종료.

희귀 조건을 확실히 재현하기 위해 `/tmp`의 외부 검사 harness에서 HP·사망·cooldown을 제어했다. production Godot 프로젝트에는 강제 사망/시간 건너뛰기 버튼을 넣지 않았다. 첫 후퇴의 20초는 실제 simulation clock으로 기다렸고 입력은 OS 마우스였다. 전체 자연 전투 밸런스나 사람이 직접 터치한 실기기 검사라고 주장하지 않는다. 자연 자동전투 종료는 별도 도메인 테스트에서 확인했다.

## 31. 웹 원본 보호 및 배포 기준

작업 전후 `dist/` 원본 **19개 파일 SHA-256이 모두 동일**하다. 웹 파일 추가·삭제도 없다. Git 추적 파일 diff는 없고 기존과 같이 `godot/`가 untracked다. Godot 밖에 프로젝트 변경을 만들지 않았다.

이번에 HTTPS 인증서 검증을 유지해 읽은 배포 `https://duniarena.site/tower.js?v=83`는 현재 저장소 `dist/tower.js`와 바이트 동일했다. SHA-256은 `13240c2c38e4e7985ad76c76c948323b1c069e1cd971f925da2070f46e6fd410`이다. 배포 사이트의 전체 플레이를 이번 Phase에서 다시 수행하지는 않았으며 실행 코드와 기존 플레이 조사 결과를 우선했다. 배포·도메인·공개 설정은 바꾸지 않았다.

Phase 3 복구 archive의 75개 파일도 작업 전 해시와 일치한다. Phase 2/3 전체 테스트 파일, 기존 배치 UI 검사, Phase 1 테스트 함수의 바이트 보존을 확인했다.

## 32. 웹과 현재 Godot의 차이

현재 실행 코드 조사와 이전 요구/구현 사이에서 확인한 차이는 다음과 같다. 웹 규칙을 임의로 수정하지 않았다.

| 항목 | 현재 웹 | 현재 Godot / 이유 |
| --- | --- | --- |
| 첫 승리 생존자 회복 | 미클리어 방 승리 시 최대 HP 30% | 사용자 지시대로 제외; 33항 |
| 적 초월 게이지 저장 | `snapshotTowerEnemies`에 없음 | 적 지속 데이터에 넣지 않음; 아군 기존 게이지 유지 |
| 일반 cooldown | 아군/적 공통 state whitelist에 있음 | 적 cooldown 이전; 아군은 기존 Phase 2 whitelist 유지로 아직 제외 |
| 게임오버 성향 | `resetTowerStances`가 길드 성향 초기화 | 기존 성향 유지 계약 보존; reset은 후속 런 수명주기/성향 도입 시 결정 |
| 양측 전멸 | 비승리 추가 20, HP가 남고 적 전멸이면 방 클리어 | 단순 “승리만 클리어” 설명보다 실제 코드 우선으로 보존 |
| HP 0과 적 전멸 동시 | HP 종료 우선, 방 미클리어 | RUN_ENDED 우선으로 보존 |
| 적 타워 스탯/레벨/보스 | towerEnemyStats의 보정·성장·종류 규칙 | 기존 기본 스탯의 고정 테스트 적만 사용; 실제 Encounter 이전 안 함 |
| 종료/후퇴 | 감속·시각 연출 후 화면 전환 | 즉시 시뮬레이션 정지와 디버그 결과; 최종 연출 제외 |
| 특수 전투 상태 | 표의 46개 필드/궁극기 cast 등 | 순수 상태 운반 구조와 cooldown만; 실제 특수 메커니즘 제외 |

26종 전체, 전체 AI, 패링·상쇄·넉백·방어·상태이상·궁극기/초월 능력, 기력 피로, 보상/골드/토큰, 모집/장비/성장/부활, 타워 지도/실제 방 생성기, 전략카드/터닝포인트, 세이브 파일, 사운드, 최종 UI/VFX는 구현하지 않았다. 웹 기본 방어력이 일반 피해 감소에 직접 적용되지 않는 현재 동작도 수정하지 않았다.

## 33. 첫 승리 30% 회복 조사

`settleTowerBattle()`는 개구리 cargo 해제 → 적 스냅샷 → 누락 사망 처리 → Player HP 0이면 won=false → `healSurvivors=won&&!towerFloor().cleared` 순서다. 이 조건에서 **HP > 0인 실제 출전 아군**에게 `restoreCombatHp(u,u.maxHp*.3,null)`을 적용한 다음 아군 스냅샷을 만든다. 예비 길드원, 후퇴, 패배에는 이 회복을 하지 않는다.

기본량이 최대 HP 30%이며 `restoreCombatHp`의 실제 치유 보정은 치유/아이템 이전 때 함께 확인해야 한다. 이번 Phase는 사용자가 별도 확정을 요구했으므로 이 회복을 넣지 않았고, 승리 직후 손상 HP 유지 검사를 남겼다.

## 34. MIGRATION_NOTE

1. 방 상태는 Scene 직렬화가 아니다. 순수 유지 데이터와 일시 실행 상태를 분리한다.
2. enemy ID는 방 소유, member ID는 길드 소유, battle ID는 시도 소유다. 추후 cast 연결은 명시적인 ID 매핑이 필요하다.
3. 적 일반 cooldown은 유지하지만 일반 공격 단계는 초기화한다. 아군 cooldown과 다른 웹 whitelist 필드는 아직 후속 과제다.
4. 특수 상태를 사전에 넣어 왕복할 수 있다는 것과 해당 능력의 실제 이전을 구분한다.
5. 적 초월 게이지는 현재 웹 적 스냅샷에 없다. 아군 게이지와 혼용하지 않는다.
6. 처음 이기는 미클리어 방의 생존 참가자 30% 회복은 조사 완료/미반영이다. 치유 보정과 함께 정산 규칙을 별도로 확정한다.
7. DRAW의 패배 손실·클리어 조건, HP 0의 승리보다 높은 우선순위는 실제 실행 코드 동작을 보존했다.
8. 사망 손실은 live unit_died 경로 한 곳에서 처리한다. 최종 정산은 영수증 검증만 하며 두 번 차감하지 않는다.
9. 후퇴는 전체 전투 종료다. 전략카드 개별 퇴각은 이후 별도 시스템이다.
10. BattleClock simulation time으로 >=20초를 판단한다. UI 시간/감속 연출과 분리한다.
11. 정상 적 위치는 보존한다. 유한 영역 밖 좌표만 28~772 보정, 비유한 좌표의 `(640,400)` fallback은 손상 데이터 대응이다.
12. FormationState는 아군 **전투 시작 위치**, EnemyRoomState는 적 **전투 종료 위치**다. 역할을 섞지 않는다.
13. 기력 참가 -1/미참가 +1은 후퇴도 동일하며 죽은 길드원도 참전 사실대로 정산한다. 실제 피로 효과는 미구현이다.
14. 기본 방어력이 일반 피해 감소에 직접 사용되지 않는 웹 동작은 수정하지 않았다. 방어 이전 단계에서 보존 여부를 결정한다.
15. 실제 타워 EnemyStats, 방 보상, 적처치 재화, 맵은 연결하지 않았다. 현재 테스트 적 수치가 타워 난이도 재현을 의미하지 않는다.
16. 게임오버 시 웹 성향 reset은 아직 제외했다. Phase 2 상태 계약과 실제 런 수명주기를 함께 정해야 한다.
17. Phase 3의 58 간격은 캐릭터 크기를 고려하지 않고 타워는 커스텀의 24명 제한을 사용하지 않는다. 기존 자유 배치를 그대로 유지한다.
18. 멀티 시도 상태·정산 ledger는 런 메모리에 있다. 저장 파일/전체 프레임 재개/결정론적 RNG 복원은 없다.

## 35. Phase 4만 되돌리는 방법

아래는 **복구 방법이며 현재 프로젝트에 실행하지 않았다**. 먼저 충돌하지 않는 백업 디렉터리명을 사용한다. 웹 파일을 건드리지 않고 Phase 3 직전 상태로 되돌린다.

```sh
mv godot godot-phase4-backup
mkdir godot
tar -xzf godot-phase4-backup/migration/phase3-before-phase4.tar.gz -C godot
godot --headless --path godot --editor --quit
godot --headless --path godot --script res://tests/test_runner.gd
```

archive는 Phase 3의 F5 설정·소스·테스트·보고서·이전 Phase 복구본을 포함한다. 캐시를 제외해 import로 재생성한다. 되돌린 뒤 메인 runner 예상값은 **10,079 검사 / 0 실패**다. 단순 `git checkout`/`git clean`으로 되돌리면 안 된다. 이 작업 전부터 `godot/`가 untracked였기 때문이다.

## 36. Phase 5 전에 결정할 사항

- 첫 승리 30% 치유와 게임오버 성향 reset을 어느 단계에서 실제 웹 동작으로 반영할지 확정한다.
- 현재 EnemyRoomState whitelist와 향후 상태이상/궁극기 cast의 남은 시간·ID 재연결 규약을 확장한다. 타겟 Node를 직접 보관하지 않는다.
- 아군 common cooldown 등 웹 지속 필드의 추가 이전 범위를 정한다.
- 실제 타워 Encounter 도입 시 EnemyStats·레벨·보스 보정과 RoomState 최초 생성 책임을 연결한다.
- 터닝포인트 정지/초월 정지/종료 연출 잠금이 생기면 BattleClock과 RetreatController에 명시적인 진행 상태를 연결한다. `Engine.time_scale`을 흩어 쓰지 않는다.
- 방 결과는 반드시 `apply_room` 경로로 정산하고 사망 이벤트는 RoomBattleSession의 단일 소유를 유지한다.

현재 완료 조건을 막는 확인된 테스트 실패는 없다. 위 항목은 후속 시스템의 규칙·통합 결정이며 **Phase 5 구현은 시작하지 않았다**.
