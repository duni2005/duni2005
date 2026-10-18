# Godot Phase 3 완료 보고

개별 길드원 자유 배치, 시작 진형 저장·복원, 실제 전투와 단발 정산 연결을 구현했습니다. Phase 4는 시작하지 않았습니다. 웹 게임과 전사·궁수 전투 수치, 이동·공격·피해·AI 로직은 변경하지 않았습니다.

## 확인한 기준

현재 저장소 `dist/app.js`, `dist/tower.js` v83 실행 코드가 최우선입니다. 배포 사이트의 `app.js?v=83`, `tower.js?v=83`도 HTTPS 인증서 검증을 유지한 다운로드로 비교했고 저장소와 바이트 단위로 같았습니다. 이번 단계에서는 배포 게임을 직접 조작하여 전체 타워 흐름을 다시 검사하지 않았습니다. 이전 Phase의 플레이 흐름 확인 기록은 보존했습니다.

| 코드 | 실제 동작 |
| --- | --- |
| `tower.js:654` `addTowerParticipant` | 살아 있는 개별 guild ID 선택, 중복 개인 거부, 비용·기력 소모 없음 |
| `tower.js:658` | 아군 X > 380 거부 |
| `tower.js:659` | 모든 roster 개체와 중심 거리 < 58 거부. 정확히 58 허용 |
| `tower.js:637` `towerFormationPosition` | 복원 좌표를 X 40..380, Y 40..760으로 clamp |
| `tower.js:639` | 충돌 시 X 40..380, Y 40..760을 20 간격으로 탐색, 원래 보정 좌표에 가장 가까운 후보 선택 |
| `tower.js:641` `restoreTowerFormation` | 사망·없는 ID·반복 ID·비유한 좌표 제외 |
| `tower.js:666` `launchTowerBattle` | 실제 시작 성공 시에만 마지막 진형 저장 |
| `app.js:84` `placementMovePoint` | 타워 이동 좌표도 X 40..380, Y 40..760으로 보정 |
| `app.js:85` `placementMoveError` | 거리 검사에서 이동 중인 자신 제외 |
| `app.js:40,75` | 커스텀 모드 24명 제한. 타워 추가 함수는 이 제한을 사용하지 않음 |

**발견한 차이:** 웹 입력 경로는 바깥 좌표를 clamp합니다. 이번 요청은 바깥 좌표 검사를 거부하는 테스트까지 명시했으므로 Godot의 직접 배치·이동은 거부 코드를 반환하고, 진형 복원에서만 clamp합니다. 이 차이를 숨기거나 웹 원본을 수정하지 않았습니다.

## 1. 생성 파일

경로는 모두 `godot/` 기준입니다.

| 파일 | 역할 |
| --- | --- |
| `scripts/deployment_entry.gd` | 개별 길드원 ID·팀·시작 위치 순수 데이터 |
| `scripts/formation_state.gd` | 성공한 마지막 시작 배치를 독립 복사 |
| `scripts/deployment_rules.gd` | 생존·ID·영역·거리·좌표 검증과 코드 반환 |
| `scripts/formation_position_finder.gd` | 유한 횟수의 가까운 빈 위치 탐색 |
| `scripts/deployment_plan.gd` | 작성 중인 배치, 이동·제거·초기화·복원·전투 요청 |
| `scripts/deployment_board.gd` | 맵 표시, 화면↔800×800 좌표 변환, 마우스·터치 입력 |
| `scripts/deployment_screen.gd` | 최소 길드 준비→배치→전투→결과→정산→다음 배치 화면 |
| `scenes/deployment.tscn` | 새 F5 진입 장면 |
| `tests/phase3_tests.gd` | 신규 규칙·상태 불변·전투 연결·복원 테스트 |
| `tests/deployment_ui_smoke.gd` | 실제 GUI 이벤트 경로와 창·모바일 크기 검증 |
| `PHASE3_REPORT.md` | 이 보고서 |
| `migration/phase2-before-phase3.tar.gz` | Phase 2 작업 전 소스 54개를 그대로 보관한 개발용 복구 아카이브 |

새 GDScript의 `.gd.uid` 9개도 Godot가 생성합니다. `.godot/` 캐시는 소스가 아닙니다. 아카이브는 게임에서 읽거나 쓰는 세이브 파일이 아닙니다.

## 2. 수정 파일

| 파일 | 변경 |
| --- | --- |
| `project.godot` | 메인 장면을 배치 화면으로 변경, 모바일 버튼용 터치→마우스 입력 변환 명시 |
| `scripts/run_state.gd` | 런에 `last_formation: FormationState` 한 필드 추가 |
| `tests/test_runner.gd` | 기존 테스트 실행 후 Phase 3 실행, 통합 실패·검사 수 합산 |
| `README.md` | 최신 보고·새 F5 진입 안내 추가. 기존 Phase 1 보고 본문 보존 |

`BattleManager`, `BattleUnitFactory`, `UnitStateCodec`, `UnitData`, `AttackData`, `Unit`, AI·이동·공격·피해·Clock·Result·Settlement 및 기존 세 장면은 수정하지 않았습니다. Phase 1 테스트 함수 본문과 Phase 2 테스트 파일은 작업 전 바이트와 같습니다.

## 3. DeploymentEntry 구조

`RefCounted` 순수 데이터: `member_id: String`, `team: int`, `position: Vector2`. `copy()`는 별도 Entry를 만들고 `battle_payload()`는 기존 Phase 2 입력 계약의 Dictionary를 만듭니다. Unit·UI Node·GuildMemberState 참조는 저장하지 않습니다. 종류 ID로 개인 배치를 식별하지 않습니다.

## 4. FormationState 구조

`entries: Array[DeploymentEntry]`, `capture()`, `snapshot()`입니다. 입력·출력 모두 Entry를 독립 복사합니다. `RunState.last_formation`이 런 동안 소유합니다. 전투 성공 직전 준비한 배치만 저장하며 전투 진행·종료 좌표를 읽지 않습니다. 성향은 진형에 중복 저장하지 않고 현재 길드원 상태를 따릅니다.

## 5. DeploymentRules 구조

읽기 전용 `RefCounted` 규칙 계층입니다. `position_error()`, `validate()`, `validate_all()`이 정수 enum `Code`를 반환합니다. `OK`, `UNKNOWN_MEMBER`, `DEAD_MEMBER`, `ALREADY_DEPLOYED`, `NOT_DEPLOYED`, `OUTSIDE_DEPLOYMENT_ZONE`, `TOO_CLOSE`, `INVALID_POSITION`, `INVALID_TEAM`, `EMPTY_DEPLOYMENT` 등을 사용합니다. 규칙 레이어에 화면 문구나 상태 소모 로직은 없습니다.

`DeploymentPlan`은 내부 Entry를 보관하고 `entries()`·`get_entry()`로 복사본만 제공합니다. 실패한 배치·이동은 기존 배치를 바꾸지 않습니다. 전투 요청 시 실제 적 배치 좌표와 현재 길드 상태를 다시 검사하므로 화면의 오래된 유효성 표시만 신뢰하지 않습니다.

## 6. 배치 가능 영역

전투 논리 공간 800×800 중 **40 ≤ X ≤ 380, 40 ≤ Y ≤ 760**, 경계 포함입니다. NaN/Infinity는 영역 검사 전에 거부합니다. 자유 좌표를 그대로 저장하며 직접 배치에 격자 스냅을 적용하지 않습니다. 테스트에서 `(120.5, 300.25)`가 Unit에 정확히 전달되는 것도 확인했습니다.

## 7. 최소 간격

모든 배치 아군과 테스트 적 시작 좌표에 대해 중심 거리 **58 이상**이 필요합니다. `<58`이면 거부하고 `==58`은 허용합니다. 웹처럼 적 좌표도 간격 검사에 포함하며 복원 시 차단 좌표로 사용합니다. 캐릭터 몸 크기나 종류별 반지름은 사용하지 않습니다.

## 8. member_id 중복 방지

작성 중인 Entry 목록의 `member_id`와 비교합니다. 같은 종류의 서로 다른 길드원은 모두 배치할 수 있고 같은 개인 두 번은 거부합니다. 전투 요청에서 전체 목록을 순차 재검증하고 기존 Factory도 다시 개인 ID 중복을 검사합니다. 이동은 같은 Entry의 좌표만 변경하며 자신을 간격 비교에서 제외합니다.

## 9. 사망·기력 0 처리

HP ≤ 0이면 배치·복원·전투 생성 불가입니다. 사망 개인은 길드 명단과 마지막 진형 데이터에는 남습니다. 기력 0은 배치·전투 모두 가능합니다. 피로 효과는 이전 Phase와 같이 미구현입니다. 배치 해제는 이번 참가 Entry만 제거하며 길드원 삭제·사망·HP·기력 변화가 없습니다.

## 10. 배치 → Unit 생성

`DeploymentPlan.launch()` → 전체 규칙 검증 → Entry를 기존 Dictionary 계약으로 변환 → `BattleManager.start_guild_battle()` → `GuildManager`의 ID 조회 → `BattleUnitFactory.guild_placement/create()` → `UnitStateCodec.inject()` → 실제 Unit 등록입니다.

Factory와 Codec의 기존 HP·기력·게이지·성향·고유 상태 주입을 그대로 사용합니다. 배치 화면의 Node를 전투 Unit으로 바꾸거나 재사용하지 않습니다. 적은 별도 테스트 Dictionary 목록이며 길드원 Entry가 아닙니다. 적 아이콘은 선택·드래그·삭제 대상이 아닙니다.

## 11. 마지막 진형 저장

`launch()`가 현재 배치의 독립 스냅샷을 준비하고 실제 `start_guild_battle()`이 성공한 경우에만 `RunState.last_formation`을 교체합니다. 빈 배치, 사망·없는 개인, 실제 적과 충돌, 잘못된 좌표, 이미 시작한 전투 등의 실패는 기존 진형을 유지합니다. 작성·취소·초기화·임시 이동만으로 마지막 시작 진형을 덮어쓰지 않습니다.

## 12. 진형 복원

새 배치 화면의 `begin_deployment()`에서 `last_formation`을 자동 복원합니다. 현재 작성 중인 배치는 별도 객체입니다. 살아 있고 여전히 길드에 존재하는 개인만 차례로 복원하며 같은 ID 반복은 무시합니다. 사망·없는 ID는 건너뜁니다. 수동 `Restore formation`도 같은 로직입니다. 복원은 HP·기력·게이지·레벨·성급·성향·고유 상태를 변경하지 않습니다.

## 13. 위치 보정

`FormationPositionFinder.find()`:

1. 비유한 저장 좌표는 생략합니다.
2. 원래 좌표를 아군 영역으로 clamp하고 유효하면 그대로 사용합니다.
3. 충돌 시 X 40..380 / Y 40..760의 20 간격 후보 **최대 666개**를 검사합니다.
4. 원래 보정 좌표에 가장 가까운 유효 후보를 선택합니다. 동거리면 웹 반복 순서처럼 X, 다음 Y 순서를 유지합니다.
5. 찾지 못하면 `found: false`를 반환하고 해당 개인 복원을 생략합니다.

다른 유닛을 밀거나 겹쳐 강제 배치하지 않습니다. 20 간격은 복원 fallback에만 쓰며 일반 자유 배치를 격자로 바꾸지 않습니다. 모든 실제 후보 검사는 동일 영역·거리 규칙을 통과해야 합니다.

## 14. 신규 테스트 목록

요청의 29항목을 다음 그룹으로 검증했습니다.

| 요청 항목 | 검증 위치 |
| --- | --- |
| 1~5 생존·사망·기력0·같은종류·같은개인 중복 | `test_rules` |
| 6~10 영역·전투장 밖·NaN/Infinity·58 경계 | `test_rules` |
| 11~13 이동·자신 제외·ID 유지 | `test_rules`, `test_debug_screen` |
| 14~16 제거·전체 초기화·배치 취소의 상태 불변 | `test_invariant_and_capacity`, `test_debug_screen` |
| 17 정산 이후만 기력 감소 | `test_battle_bridge`, `test_debug_screen` |
| 18~19 정확한 시작 좌표·같은종류 다른개인 생성 | `test_battle_bridge` |
| 20 실제 시작 진형 저장·실패 시 미저장 | `test_battle_bridge`, `test_failed_start` |
| 21~23 생존 복원·사망 및 없는 ID 제외 | `test_restore`, `test_battle_bridge` |
| 24~25 가까운 빈 곳·빈 곳 없음의 안전 종료 | `test_restore` |
| 26 진형 변경의 길드 상태 불변 | `test_invariant_and_capacity` |
| 27 한 번만 정산 | `test_battle_bridge`, 기존 Phase 2 정산 테스트 |
| 28~29 기존 Phase 1·2 회귀 | 기존 테스트 함수·파일 전체 그대로 실행 |

추가로 30명 배치(24명 제한 없음), 적 시작 위치 차단, 정수 아닌 자유 좌표, 호출자가 받은 Entry 복사본 변경, 무효 시작의 원자성, 전투 종료 위치와 시작 진형 차이, 마우스/터치 이벤트 중복 방지, 실제 GUI 버튼 경로, 모바일 화면 좌표를 검사합니다.

## 15. Phase 1 결과

기존 14개 완료 전투·**9,705 검사 / 실패 0**. seed 3/29/101의 전사·궁수·3대3 결과와 시간이 기존 결과와 같습니다. 근접·화살·치명타·사망·동시 최후 사망·타겟 재탐색·경계·적 없음·종료 후 정지·기존 장면 검증을 유지했습니다.

## 16. Phase 2 결과

기존 6그룹·**243 검사 / 실패 0**. 개별 HP·게이지·성향·순수 고유 상태·사망 보존·기력·원자 정산·중복 정산·실제 2연전 모두 통과했습니다. 테스트 파일은 바이트 단위 무변경입니다.

## 17. Phase 3 결과

신규 6그룹·**131 검사 / 실패 0**. 별도 실제 GUI 입력 smoke는 **18 검사 / 실패 0**이며 headless와 실제 X11 창에서 각각 실행했습니다. 창 smoke는 생존 진형 복원이 보이도록 테스트 적 전사 1명을 사용하고, 일반 F5 화면은 전사 2+궁수 1 고정 적을 사용합니다.

## 18. 전체 검사 수·실행

`test_runner.gd` 결과:

```text
RESULT: 14 completed battles; 9705 checks; 0 failures
PHASE 2 RESULT: 6 test groups; 243 checks; 0 failures
PHASE 3 RESULT: 6 test groups; 131 checks; 0 failures
TOTAL: 10079 checks; 0 failures
```

별도 GUI 입력 18개를 더하면 서로 다른 검증은 **10,097개 / 실패 0**입니다. 같은 18개를 headless·X11에서 반복한 것을 다른 테스트 개수로 부풀리지 않았습니다.

Godot **4.6.3 stable**에서 editor import/parse/scene load, 통합 테스트, GUI smoke, 새 main scene headless 실행을 검증했습니다. `.godot/`가 없는 임시 복사본에서도 import와 테스트를 검사했습니다.

저장소 루트에서 실행:

```sh
godot --headless --path godot --editor --quit
godot --headless --path godot --script res://tests/test_runner.gd
godot --headless --path godot --script res://tests/deployment_ui_smoke.gd
godot --path godot
```

기존 Phase 1 3대3 장면을 따로 실행:

```sh
godot --path godot res://scenes/battle.tscn
```

이 환경에서는 기본 사용자 데이터 폴더 쓰기 권한 때문에 명령 앞에 아래 변수를 붙였습니다. 게임 코드 변경이 아닙니다.

```sh
env XDG_DATA_HOME=/tmp/duni-godot/data XDG_CONFIG_HOME=/tmp/duni-godot/config XDG_CACHE_HOME=/tmp/duni-godot/cache godot --headless --path godot --editor --quit
```

## 19. 실제 창 실행 결과

X11 dummy display + Mesa llvmpipe OpenGL 환경에서 실제 Godot 창을 생성했습니다. `deployment_ui_smoke.gd`가 확대·축소 좌표를 반영한 마우스/터치 이벤트를 GUI 입력 경로에 주입하여 카드 선택, 배치, 마우스 및 터치 드래그, 제거, 시작 버튼, 자동전투, 결과 정산, 다음 배치 버튼, 생존 개인의 시작 위치 복원을 검증했습니다.

기본 720×800 창과 390×844 뷰포트를 확인했습니다. 모바일 크기에서는 버튼 줄바꿈·가로 길드원 스크롤·800×800 맵 좌표 변환이 유지됩니다. 물리 휴대폰에서 손가락으로 테스트하지는 않았습니다. 정식 모바일 제품 UI나 최종 폰트는 범위 밖입니다.

최종 창 로그에 script/runtime ERROR는 없으며 dummy 그래픽 드라이버의 V-Sync 미지원 경고만 있습니다. 테스트 캡처는 `/tmp/duni-phase3-placed.png`, `battle.png`, `result.png`, `restored.png`, `mobile.png`입니다(각 파일에는 동일 `duni-phase3-` 접두사가 붙습니다). GUI 테스트는 캡처를 `/tmp`에만 저장합니다.

조작: 하단 개별 길드원 카드 선택 → 파란 영역 클릭/터치. 배치된 아군은 드래그하거나 선택 후 빈 목적지를 눌러 이동합니다. `Remove selected`는 선택 개인만, `Clear draft`는 전부 제거합니다. `Start battle` 이후 배치 조작은 잠기고, 완료 시 화면의 결과 핸들러가 기존 Settlement를 한 번 호출합니다. `Next deployment`는 완료 후에만 가능하며 생존 개인을 복원합니다. 활동 중 전투를 나가는 기능은 없습니다.

## 20. 웹 원본 해시

작업 전후 `dist/` 원본 **19개 전부 SHA-256 일치**, 추가·삭제·수정 없음. `git diff --exit-code -- dist`도 성공했습니다. 작업 전 스냅샷은 `/tmp/duni-phase3-baseline/dist-hashes.json`에 있습니다.

배포와 일치한 관련 실행 파일 해시:

```text
app.js   bc5ae16d3f78a5f4cd783508dd2271d0e3478eeabfbb0922b3d0dfe577d6d7fb
tower.js 13240c2c38e4e7985ad76c76c948323b1c069e1cd971f925da2070f46e6fd410
```

모든 새 소스·문서·복구 파일은 `godot/` 내부입니다. 이 폴더는 작업 시작 때부터 Git에서 untracked였으므로 Git 커밋 기반으로 Phase 3만 되돌릴 수 있다고 가정하지 않았습니다.

## 21. 현재 웹과 아직 다른 부분

- 웹 입력은 범위를 보정하지만 Godot 직접 배치·이동은 명시적으로 거부합니다. 복원 보정은 웹 규칙을 사용합니다.
- 전사·궁수만 있고, 기본 최근접 자동전투만 있습니다. 전체 AI·상쇄·패링·넉백·상태이상은 미구현입니다.
- 웹의 승리 후 생존 유닛 HP30% 회복은 Phase 2의 HP 지속 계약대로 계속 제외했습니다. 배치 화면은 회복시키지 않습니다.
- 기력·게이지·성향은 개인 상태를 그대로 전달하며 실제 피로·성향 AI·궁극기·초월 기술 효과는 없습니다.
- 성향 변경 UI는 **보류**했습니다. 항상 현재 `GuildMemberState.stance`를 Unit으로 주입하고 기존 정산으로 회수합니다.
- 웹의 방별 배치 초안, 이전 적 상태, 타워 지도·경제·성장·플레이어 HP는 없습니다. 다음 화면은 새로운 테스트 전투 준비이며 같은 방 재도전이 아닙니다.
- 실제 길드원 모집 대신 독립된 ID를 가진 전사3·궁수3 테스트 명단을 생성합니다. 적은 새로운 고정 테스트 배치입니다.
- 웹의 사망/비용/게임오버/보상/UI/연출을 흉내내지 않았습니다. 전투에서 출전자가 전멸해도 예비 길드원은 남아 다음 배치를 할 수 있습니다. 런 종료 조건은 아직 구현하지 않습니다.

## 22. MIGRATION_NOTE

1. 중심 거리 58은 실제 캐릭터 크기를 고려하지 않습니다. 크기별 제한 추가는 별도 디자인 변경입니다.
2. 타워에는 커스텀 모드의 24명 제한이 적용되지 않습니다. 기하학적 공간이 있어야 할 뿐입니다.
3. 적 Encounter와 실제 타워 방 배치는 아직 연결하지 않았습니다. 고정 적 Dictionary는 길드 Entry와 분리됩니다.
4. FormationState는 전투 시작 위치만 기록하며 종료 위치를 기록하지 않습니다.
5. 후퇴/재도전 단계에서 FormationState(아군 시작 진형)와 EnemyRoomState(방의 적 지속 상태)는 서로 다른 책임을 가져야 합니다.
6. 직접 입력 밖 좌표 거부와 웹의 clamp 차이는 위에 기록했습니다. 나중에 UX 보정을 적용하더라도 규칙 검증 자체를 우회하지 않아야 합니다.
7. 가까운 후보의 20 간격 탐색은 웹과 같은 복원 수단이며 수동 배치의 격자 제한이 아닙니다.
8. 배치의 성향 사본은 만들지 않았습니다. 성향 UI는 보류하고 현재 개인 성향을 전달합니다.
9. 마지막 진형은 런 메모리에만 존재합니다. 파일 저장/로드는 없습니다.
10. 배치 객체는 정산을 호출하지 않습니다. 화면의 완료 핸들러→기존 Settlement 경로를 유지합니다. 취소·초기화·실패는 참가/정산이 아닙니다.
11. 기본 방어력이 일반 피해 감소에 직접 사용되지 않는 웹 동작은 수정하지 않았으며 방어는 여전히 미구현입니다.
12. 기력0 출전 가능, 피로 미구현·게이지 충전 미구현·성장 스탯 미구현 등 이전 Phase 계약을 그대로 유지합니다.

## 23. Phase 3만 되돌리기

Godot를 닫고 저장소 루트에서 실행합니다. `godot-phase3-backup`이 이미 있으면 다른 새 이름을 사용하세요.

```sh
mv godot godot-phase3-backup
mkdir godot
tar -xzf godot-phase3-backup/migration/phase2-before-phase3.tar.gz -C godot
godot --headless --path godot --editor --quit
godot --headless --path godot --script res://tests/test_runner.gd
```

아카이브의 54개 소스를 작업 전 SHA-256과 전부 비교했습니다. 이 방법은 정확한 Phase 2 프로젝트·기존 테스트·당시 README와 F5 3대3 화면으로 복원하며 Phase 3 전체도 백업 폴더에 남깁니다. 웹 파일은 건드리지 않습니다. 실제 작업 폴더에 복구 명령을 실행하지는 않았습니다. 복구 아카이브는 `.godot/` 캐시를 담지 않습니다.

## 24. Phase 4 전에 결정·수정할 사항

- 후퇴·패배·새 전투의 완료/중단 결과 계약을 정의해야 합니다. 배치 취소나 장면 종료를 정산으로 오인하면 안 됩니다.
- 같은 방 재도전은 새로운 battle result ID로 만들되 EnemyRoomState와 별도 연결해야 합니다. 현재 테스트 적은 매번 신규입니다.
- EnemyRoomState의 이전 위치를 복원 후보 차단 좌표로 전달해야 합니다. 지금의 bounded finder와 blocker 입력을 재사용할 수 있습니다.
- 후퇴 시 HP·게이지·고유 상태·기력 정산 시점과 재진입 조건을 실제 웹 코드로 다시 확인해야 합니다.
- 완료/정산 후 장면을 해제하는 흐름을 유지하고, 후퇴 요청에 따른 감속·정지 시간은 BattleClock에서 처리해야 합니다.
- 실제 출전자 전멸과 전체 생존 길드원 전멸을 구분해야 합니다. 전투 패배를 즉시 런 게임오버로 연결하면 안 됩니다.
- 직접 드래그 경계 입력을 웹처럼 보정하는 UX를 원하면 별도 입력 어댑터 변경으로 결정해야 합니다. 현재는 요청한 거부 계약입니다.

이 항목들은 다음 단계의 결정 사항이며 이번 작업에서 구현하지 않았습니다.
