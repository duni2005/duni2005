# Phase 11 — 저장·불러오기 완료 보고

2026-10-14 UTC, Godot **4.6.3.stable.official.7d41c59c4**. F5 시작 화면을 새 게임/이어하기로 연결했습니다. 실제 JSON 파일의 단일 런 저장과 이전 정상본 백업을 구현했습니다. Phase10.5의 AI/전투 코드·Resource를 유지했고, Phase12와 웹 재배포는 시작하지 않았습니다.

## 1. 생성 파일

| 파일 | 역할 |
| --- | --- |
| `scripts/save_manager.gd` | 안전 저장 검사, autosave/manual/checkpoint, 실제 파일 I/O·atomic/backup |
| `save_load_result.gd` | 명시적 상태 코드와 호출 결과 |
| `save_value_codec.gd` | JSON primitive 변환, int64·정수 dictionary key 보존 |
| `save_domain_codec.gd` | 실제21개 domain 타입의 명시적 v1 필드 registry/생성 |
| `save_validator.gd` | 구조·타입·범위·관계·진행·복합 캐릭터 상태 검사 |
| `save_migrator.gd` | schema 지원/migration 진입, 현재 v1만 지원 |
| `save_snapshot_builder.gd` | 지속 런/RNG/metadata/checkpoint → detached Dictionary |
| `save_snapshot_loader.gd` | 검증된 Dictionary → domain/컨트롤러 재생성 |
| `main_menu_screen.gd`, `scenes/main_menu.tscn` | 새 게임/이어하기·metadata·기존 런 교체 확인 |
| `tests/phase11_fixture.gd`, `phase11_tests.gd`, `phase11_runtime_tests.gd`, `phase11_runner.gd` | 복합 런·오류·실제 트랜잭션·전투/재도전/종료 검사 |
| `tests/fixtures/save_v1.json`, `phase11_fixture_writer.gd` | 개발 중 확정한 고정 v1 예시와 의도적 생성기; 일반 검사는 예시를 읽기만 함 |
| `tests/phase11_restart.gd` | 별도 프로세스 생산/소비 검사 |
| `tests/save_ui_smoke.gd` | desktop mouse·390×844 touch 이어하기 |
| `migration/phase11-*`, `PHASE11_REPORT.md` | 보호 hash·526파일 복구본·검사 로그·화면·보고 |

`.gd.uid`는 Godot 생성 식별자입니다. 전체 경로는 `migration/phase11-file-changes.json`에 기록합니다.

## 2. 수정 파일

`project.godot`의 메인 씬/이름/고정 user-data 폴더, `tower_controller.gd`의 저장 경계·예약 seed·런 교체/뷰 폐기 시 연결 해제, `tower_screen.gd`의 저장/메인/로드 라우팅, `tower_content_screen.gd`의 저장 상태 표시, `tower_battle_screen.gd`의 checkpoint 실패 표시, `test_runner.gd`의 신규 검사 연결, `README.md`의 현재 단계 안내입니다.

`BattleBrain`, AI/이동/인지/위협/Ability, BattleManager, DamageResolver, 공격·캐릭터·장비·카드 Resource와 기존 개별 Phase 검사 파일은 수정하지 않았습니다. 세션의 RefCounted signal 연결 해제는 폐기용이며 전투 종료·정산을 실행하지 않습니다.

## 3. SaveManager 구조

`MainMenuScreen`이 하나의 `SaveManager`를 유지하고 실제 `TowerController`에 연결합니다. 거대한 전역 런 객체나 Save Autoload를 만들지 않았습니다. 독립 domain/기존 회귀 검사의 컨트롤러는 저장 책임을 연결하지 않으므로 production 파일에 쓰지 않습니다.

`snapshot` → Builder → Validator, `request_autosave` → 같은 frame의 마지막 detached snapshot → `flush_autosave`, `manual_save`/`checkpoint` → 동기 atomic write, `load_controller` → read/migrate/validate/Loader 구조입니다. 상태 표시만 유지하며 로드 결과의 Controller를 SaveManager 내부에 보관하지 않습니다. 상호 참조 cycle을 막습니다.

## 4. 경로

정식 경로는 **`user://saves/autosave.json`**입니다. 이전 정상본은 `autosave.json.backup`, 임시본은 `.tmp`, 백업 임시본은 `.backup.tmp`입니다. 절대 OS 경로를 코드에 고정하지 않았습니다.

`config/use_custom_user_dir=true`, 이름 **`DUNI_ARENA`**로 고정하여 향후 프로젝트 표시 이름이 바뀌어도 저장 위치가 함께 바뀌지 않게 했습니다. Android도 엔진의 내부 `user://`를 사용합니다. APK/실제 Android 장치 검증은 하지 않았습니다.

## 5. format

UTF-8 JSON, 두 칸 들여쓰기. Resource·RefCounted·Node·Callable을 직접 JSON으로 저장하지 않습니다. vector는 `{x,y}`, StringName은 문자열, domain enum은 해당 실제 정수 또는 안정적인 kind 문자열입니다.

JSON 정수도 parser에서 float가 되므로 구조의 int 필드는 정수 여부 검사 후 재구성합니다. generic 데이터의 정수 키 dictionary는 `$pairs`, 2^53 밖 generic int는 `$int64` 문자열 tag로 보존합니다. 정상 generic 숫자의 integral float/int 표현은 의미적으로 동일한 숫자로 복원될 수 있습니다. 타입 표현 차이를 값 손실로 취급하지 않지만 bool/string을 숫자로 추측하지 않습니다.

## 6–7. schema와 최상위

현재 **schema_version=1**, `migration_version="phase11-v1"`입니다. 최상위9필드:

```text
schema_version, save_id, created_at, updated_at, migration_version,
run, rng, metadata, recovery
```

`created_at/updated_at`은 Unix seconds, save_id/run_id는 별개입니다. 필수 필드 누락·알 수 없는 schema/구조를 조용히 보정하지 않습니다. 전투 checkpoint도 동일한 schema이며 `recovery`가 예약된 attempt 정보를 표현합니다.

## 8. metadata

`save_id`, timestamp, current chapter, 선택 방의 floor(없으면 해금 층), 별도 unlocked_floor, player_hp, gold, tokens, guild_count, living_guild_count, phase, tower_conquered를 저장합니다. UI에는 phase의 한국어 이름을 표시합니다.

metadata 조회는 파일 전체 유효성도 검사하지만 Scene·전투·맵 생성·보상을 실행하지 않습니다. 저장 본문에서 계산한 값과 metadata가 다른 파일은 거부합니다.

## 9–10. atomic와 backup

1. 안전 snapshot 전체 검증.
2. `.tmp` 작성 → flush/close.
3. `.tmp` JSON 재파싱·전체 재검증.
4. 현재 primary가 정상일 때만 그 내용을 `.backup.tmp`에 작성/검증 → backup 교체.
5. 임시본을 primary로 rename.

기존 primary를 먼저 비우거나 제거하지 않습니다. 손상된 primary가 정상 backup을 덮지 않습니다. 잘못된 tmp, 경로 쓰기 실패, 교체 실패는 결과 코드로 반환합니다. primary 손상 시 정상 backup을 검증하여 사용하고 메뉴에 복구 여부를 표시합니다. future schema에는 자동으로 예전 backup을 대신 적용하지 않습니다.

Godot flush/파일 rename을 사용한 앱 종료 대비입니다. 모든 OS의 전원 차단/디렉터리 fsync까지 보장하는 별도 파일시스템 구현은 아닙니다.

## 11–22. domain 저장·복원

| 대상 | 실제 저장 필드/복원 정책 |
| --- | --- |
| RunState | run_id, player HP/maxHP, game_over/reason, gold/tokens, 개인 길드·아이템·카드와 next counters, strategy_progress, last_formation, tower, settled/death-loss/strategy/inventory/transaction/content receipts |
| GuildMemberState | member_id, type, level, stars, HP, energy, 두 gauge, stance, character_specific_state, fang_kills; 죽은 개체도 유지 |
| Inventory | item_id/kind/equipped_to_member_id/consumed; 개별 동일 kind 복사본과 tombstone 유지 |
| 장비 관계 | 현재 구현의 소유 기준은 아이템의 member_id. 길드원에 두 번째 장비 배열을 만들어 중복 소유권을 저장하지 않음 |
| StrategyCardInstance | card_id/kind/used_depth/used_floors/ready_floor/consumed; 카드 counter/사용 receipts도 유지 |
| TowerRunState | 실제 map, chapter/unlocked/selected room/phase, 방문·완료·정복·chapter history, requests, result/conquered, processed_results, map_scroll_y, last_content_outcome |
| TowerMapState | 실제15 Floor와120 Room 자체. seed로 다시 생성하지 않음 |
| FloorState | index/chapter/unlocked, 실제 room_ids, cleared/required count, conquered, bonus/bonus item |
| RoomState | identity/source run/depth/lane/kind, discovered/visited/consumed/cleared/publicly_visible, event_type, encounter/enemies, attempts/settled IDs/active ID(안전 저장에서 빈 값), gold/token/kill/reward 상태, 콘텐츠와 방문 수 |
| EncounterState | room_kind/depth/formation와 실제 EnemySpawnEntry[] |
| EnemySpawnEntry | stable enemy_id/type/level/initial_position/rank/body_scale·HP/damage/defense/speed multipliers |
| EnemyRoomState | stable enemy_id/type/current_hp/position/ultimate_gauge/stance/persistent_state. 죽은 적도 저장 |
| 적 spawn/stats | Encounter와 동일 ID로 spawn을 다시 연결하고 기존 TowerEnemyStatsAssembler로 최종 stats 계산. UnitData/UnitCombatStats 사본을 저장하지 않음 |
| Formation | member_id/team/실제 전투 **시작** 위치. 종료 위치 아님; 기존 Phase3 restore/fallback 사용 |
| Recruit | revision, 각 offer_id/type/gold/token price/purchased |
| Shop | 각 offer_id/category/kind/gold_price/purchased. stock을 다시 생성하지 않음 |
| Event | 실제 type/choices/선택 결과/resolved/reward receipt/outcome, promotion limit/used, treasure branch/kind, PredictionState |
| Prediction | teams/picked_team/stake/status/result/payout/tokens. 진행 중 프레임 대신 ready checkpoint |
| RewardRequest | reward_id/kind/item_kind/fulfilled와 실제 inventory receipt |

21개 타입의 명시적 registry를 `SaveDomainCodec`에 분리했습니다. domain 클래스마다 저장 버전 메서드를 추가하지 않았습니다. next member/item/card counter는 저장값을 유지하며 최고 기존 ID보다 작거나 같은 값은 거부합니다. Load 시 ID를 새로 발급하지 않습니다.

## 23. actor 관계

기존 stable `member:<member_id>`와 `enemy:<room_id>:<enemy_id>`를 보존합니다. battle ID/NodePath로 다시 연결하지 않습니다. cast·puppet·burst의 잘못된 runtime 참조 문자열과 구조를 검사합니다. 실제 Unit 생성 후 기존 `find_actor`/CharacterPersistence가 관계를 연결합니다.

승급 등으로 이미 없어진 optional target actor는 새 개체로 대체하지 않습니다. 기존 runtime의 유효성/중단 경로를 사용합니다. 장비의 잘못된 member 관계는 optional이 아니므로 load 실패입니다. 이전 진형의 사망/없어진 member는 Phase3 계약대로 배치에서 제외합니다.

## 24. RNG

현재 컨트롤러의 `generator.rng`(map), `content_rng`, `combat_rng` 각각의 **seed와 현재 state**를 signed int64 문자열로 저장합니다. 처음 seed부터 소비 횟수를 재생하지 않습니다. 로드 후 세 종류의 다음 `randi()`가 원본 다음 값과 동일한지 검사했습니다.

BattleManager 내부 RNG/current frame은 저장하지 않습니다. 시작 전에 예약된 attempt seed와 그 값을 소비한 뒤의 persistent combat source state를 저장합니다. checkpoint 재시작은 그 seed를 재사용하며 source RNG를 두 번 소비하지 않습니다.

## 25–28. 저장 경계

안전 phase: route, deploy, shop/recruit/rest, 안정적인 event_active, content_result/result/cleared, gameover. 미완료 동기 transaction, 실제 진행 중 BattleManager/PredictionBattle, TP/초월은 저장 불가입니다.

자동 저장:

- 새 런 성공, 방 발견/진입·지도 복귀, 처음 결정한 정복 bonus.
- 모집/리롤/구매/장착/재각인/강화/승급 성공.
- 휴식소/이벤트/방 완료와 reward request 처리 이후.
- 전체 전투 결과 정산 끝, 예측 payout 끝, abandon 확정.

`_defer_save`로 nested 콘텐츠 완료·progression·정복·reward 처리가 끝날 때까지 저장을 미룹니다. 같은 frame의 연속 요청은 마지막 detached snapshot으로 합쳐 한 번 씁니다. 실패 transaction과 승급 UI 선택만 바뀐 경우에는 autosave하지 않습니다.

### 전투 checkpoint

실제 배치를 먼저 검증한 뒤 seed 예약 → **전투 시작 전** 동기 checkpoint 성공 → 기존 RoomBattleSession 시작입니다. file의 phase는 deploy이며 새 배치를 last_formation에 반영한 detached snapshot을 씁니다. 아직 전투 인스턴스/active result ID/참전 기력 소모를 저장하지 않습니다. checkpoint I/O가 실패하면 전투를 시작하지 않습니다.

강제 종료 시 그 시작 전 상태로 돌아갑니다. 미정산 시도의 피해·처치 재화·TP 카드 소비도 되돌아갑니다. 중간 frame을 이어가는 기능이 아닙니다. 예측은 wager 차감 전 ready checkpoint로 복구합니다.

### 결과 checkpoint 교체

기존 사망 손실·HP/기력/gauge·적 상태·방 완료·보상·첫 승리30% 치유·progression/conquest·카드 상태 처리가 끝나고 `phase=result/gameover`가 된 다음 저장합니다. 회수/보상을 SaveManager에서 다시 계산하지 않습니다. 완료한 recovery marker는 제거합니다.

## 29–33. Continue와 라우팅

메뉴는 정상 save 또는 정상 backup이 있어야 이어하기를 활성화합니다. 새 게임은 기존 slot이 있으면 게임 안 확인창으로 교체 여부를 확인합니다. 정상 런 생성·저장 후 새 slot으로 교체하며 gameover/abandon save를 임의 삭제하지 않습니다.

| 저장 phase | 로드 UI |
| --- | --- |
| route | 기존 세로 층·가로 방 지도/스크롤 |
| deploy / battle checkpoint | 저장 방의 기존 배치 화면 + 마지막 시작 진형 |
| shop/recruit/rest/event_active | **재진입 API를 호출하지 않고** 저장 방 콘텐츠 화면; 발견 보상/RNG 재소비 없음 |
| content_result/cleared | 저장된 콘텐츠 결과/완료 방 화면 |
| result | 이미 정산된 지도·‘정산 완료 · 지도로 계속’; BattleResult/정산 함수를 다시 실행하지 않음 |
| gameover/abandon | 종료된 런의 잠긴 지도·새 런 선택 |
| conquered | 정복 flag와 기존 자유 탐험 규칙 유지; slot 삭제하지 않음 |

과거 전투의 transient 결과 그래픽/정확한 BattleResult 화면을 다시 만들지는 않습니다. 실제 정산된 domain 값·영수증을 보존하여 지도에서 계속합니다.

## 34–36. 손상 처리·validation·migration

LoadResult: `OK`, `FILE_NOT_FOUND`, `PARSE_ERROR`, `UNSUPPORTED_VERSION`, `VALIDATION_ERROR`, `IO_ERROR`, `BUSY`. 잘못된 save를 실행하지 않으며 현재 런 객체에 부분 적용하지 않습니다. 완전히 새 domain을 검사한 뒤 컨트롤러를 반환합니다.

검사 내용: 필수/미지원 필드·타입, finite·숫자 범위, IDs/중복/counters, type/kind Catalog 존재, 슬롯/장비 소유, 15층/120방·index/lane/room/floor/source run, Encounter/Enemy 일치, 좌표·dead state, 현재 phase/선택 방·해금 threshold/보스 조건·정복 flag/history, receipts/reward 관계, RNG precision, 복합 cast/lostSword/puppet/burst 필수 구조, metadata 일치입니다.

중요 오류는 실패입니다. type0 대체, 잘못된 장비를 임의 대상에게 연결, 누락된 map 재생성, negative gauge의 silent clamp를 하지 않습니다. setter가 clamp하기 **전에** 원본 저장 값 범위를 확인합니다. 직접 Node/Resource/Callable을 포함한 snapshot도 거부합니다.

SaveMigrator는 현재 v1만 받습니다. v2가 생길 때 변환을 여기에 순차 추가해야 하며 현재 지원하지 않는 미래 버전을 이전 slot처럼 읽지 않습니다. depth32, file8MiB 제한이 있습니다.

## 37–40. 제외 대상

등록된 domain 필드만 저장합니다. Scene/Unit/UI/Timer/Tween/Callable/signal, current target, AttackInstance/melee/CombatWave/projectile/장판, BattleBrain, entry runtime plan/commit/hesitation/read/response/rear/area/safe/steering, TP timer/forecast/선택 카드/pending command, 초월 aim/hold/cut-in/cast는 포함하지 않습니다.

Guild의 ultimate/transcendence gauge와 실제 실행된 whitelist 효과는 유지합니다. AI와 TP는 새로운 전투 인스턴스에서 새로 생성합니다. 파일의 진형은 battle 종료 좌표가 아닙니다. CharacterPersistence.FIELDS 및 실제 lostSword/ultCast/puppetControl/retreatRemaining/specialRemaining을 전달하고, Phase2부터 허용한 pure 추가 고유 데이터도 유지하되 알려진 transient 키·객체를 거부합니다.

## 41–47. 주요 검사 결과

- 복합 런: 15층/120방, 손상/사망 적, 죽은 길드원, 동일 전사 개별 HP/gauge/성향, level/stars/장비, 구매 offer·sold stock, 미완료 이벤트, fulfilled item request, 정복/정산·사용 receipts를 JSON 왕복 후 비교.
- ID/counter: 기존 ID 유지·다음 개인 생성 충돌 없음·개별 같은 kind inventory/card.
- 재도전: 실제 후퇴 정산 → 파일 → 새로운 Controller → 같은 방 → 죽은 적 제외·HP/좌표/gauge/상태 유지·아군 시작 진형·새 TP12초.
- complex 캐릭터: 샷건 장전, 두비두밤 상대 위치 lostSword, 포식자/챌런 stack, 성기사 blessing/swings, lightning shock, tank face, 위성 burst, 인형 control, 적 cast. 실제 새 Unit에 주입하여 상대 검 위치·안정 ID target·현재team/원래team·timer 진행까지 확인.
- 기존 control 복원은 intent/cast를 취소하는 Phase8 계약입니다. cast와 control runtime 검사는 각각 다른 actor로 구성했으며 이를 저장 단계에서 수정하지 않았습니다.
- 신규 보상/구매/예측의 receipt 재조회로 지급을 반복하지 않음. 결과 load가 Settlement를 호출하지 않음.
- RNG 세 종류의 현재 state·다음 값 동일, stock/후보를 load에서 재생성하지 않음.
- 실제 프로세스: 독립 user data dir에서 `write_complex`→종료→`read_complex`, `write_checkpoint`→종료→`read_checkpoint`. **4프로세스14검사, 실패0**. 입력 파일은 실제 disk slot, read 과정의 맵/진형/HP/seed/적 제외/새 TP를 검사.

## 48–50. 크기·시간

고정 복합 fixture는 **약451KB(약441KiB)**입니다. 120방과 전체 Encounter/콘텐츠를 포함하고 Resource·전투 로그/프레임은 제외합니다. 검사 로그에 실제 UTF-8 bytes와 microseconds를 기록합니다.

최종 로그의 `PHASE11 PERFORMANCE`는 snapshot+검증 시간과 JSON parse+검증+복원 시간을 각각 측정합니다. 이 환경에서 독립 검사에서는 약0.1초 전후였으며 여러 GUI/회귀 프로세스를 같이 실행할 때 더 길어졌습니다. 절대 FPS/성능 보장 수치를 새로 만들지 않았습니다. atomic file 작업은 재검증도 수행하므로 이 두 측정만으로 전체 file-write latency를 뜻하지 않습니다.

최종 전체 회귀 실행의 실제 표본: **451,322bytes, snapshot+검증70.948ms, JSON parse+검증+복원82.110ms**. 고정 예시 파일은 고정 header 시간이므로 byte 수가 조금 다릅니다.

## 51–56. 검사·실제 GUI

신규 Phase11 검사와 전체 회귀의 정확한 결과는 아래 최종 검증표에 기록합니다. 로그: `phase11-tests.log`, `phase11-regression-final.log`, `phase11-import-final.log`. 기존 개별 Phase 검사 파일과 Phase10.5 Golden/FPS/반응 분포 코드는 보존했습니다.

| Phase / 검사 | checks | 실패 |
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
| Phase11 (통합runtime79개 포함) | 643 | 0 |
| **test_runner 전체** | **97459** | **0** |
| 별도 프로세스 4회 | 14 | 0 |
| headless GUI 10개 | 249 | 0 |
| X11 GUI 10개 | 249 | 0 |

주 검사·별도 프로세스·양쪽 GUI 검사 실행 합계97,971개, 실패0입니다. 독립 Phase11 runner 재실행은 같은643개 검사이므로 이 합계에 중복 가산하지 않았습니다. editor headless load/parse/scene import도 exit0이며 최종 로그에 script error가 없습니다.

기존9 GUI + 신규 save GUI를 headless/X11에서 각각 실행했습니다. 새 GUI는 입력으로 새 런 → 모집 → 상점 → 설명/장착 → 강화 → 저장 → 뷰/런 연결 폐기 → 이어하기 → 상태 확인 → 손상 방 배치/전투 → 미완료 전투 checkpoint 이어하기를 진행합니다. **각 표시 환경249검사, 실패0**, 신규 save는31개입니다.

X11은 실제 Godot OpenGL 창(Mesa llvmpipe)의 mouse/touch input입니다. 사람이 모든 화면을 수동 플레이했다고 주장하지 않습니다. desktop1000×1100와 mobile390×844 사진을 직접 열어 표시를 확인했습니다. 방의 손상 상태는 명시적인 GUI fixture이며 후퇴/패배 실제 정산·손상 유지/부활 없음은 domain 통합 검사에서 별도로 확인했습니다.

실제 모바일 Android build 검증은 이번에 수행하지 않았습니다. 실행 비교용 XDG/test 저장 폴더는 정식 autosave와 별도입니다.

## 57. 보호 확인

`dist/`19개 SHA-256, 기존 `.tres` 전체와 Phase10.5 전투/AI/Ability 파일 hash를 작업 전후 대조했습니다. 결과는 `migration/phase11-web-sha256.json`, `phase11-file-changes.json`에 있습니다. 저장을 위해 공격/이동/HP/방어/profile/카드/성장 수치를 수정하지 않았습니다.

보호한 AI/전투/Ability/Resource106파일 모두 byte 동일, 기존 개별 테스트도 동일입니다. 기존 tracked 웹 파일의 git diff는 비어 있습니다.

## 58. MIGRATION_NOTE

1. single autosave+이전 정상 backup 구조. 여러 슬롯/클라우드 동기화/암호화는 구현하지 않음.
2. 안전 snapshot만 저장. 강제 종료 시 마지막 committed 파일/checkpoint로 복귀하며 미정산 시도에서 얻거나 쓴 자원도 rollback됨.
3. same-frame debounce는 transaction 완료 snapshot을 합칩니다. 앱이 그 frame의 deferred write보다 먼저 강제 종료되면 마지막 committed snapshot까지 복구됩니다. 전투 시작 checkpoint는 예외로 반드시 동기 완료 후 시작합니다.
4. backup은 직전 정상 snapshot이므로 primary 손상 시 더 이전 상태일 수 있습니다. healthy gameover/abandon은 해당 종료 상태를 복원합니다. future schema에는 backup으로 조용히 downgrade하지 않습니다.
5. atomic rename/flush의 세부 전원 차단 내구성과 플랫폼별 파일시스템 동작은 별도 장치 검증 대상입니다.
6. v1은 현재15층/120방·26종/kind Catalog 계약을 검증합니다. 미래 schema/콘텐츠/밸런스 정의가 변경되면 SaveMigrator/compatibility 정책을 먼저 결정해야 합니다.
7. 정적 Resource 정의는 현재 Catalog에서 조회합니다. 과거 정의 사본을 save가 들고 있지 않습니다.
8. normalized JSON numeric 표현과 int64/정수 key를 구분합니다. IDs/counters/RNG는 precision을 검사하며 gameplay float 값은 finite를 검사합니다.
9. 저장된 result는 이미 정산된 지도 진행 상태로 라우팅합니다. transient BattleResult 연출을 복원하지 않습니다.
10. 승급 선택/초월 조준/TP 선택/AI intent는 제외. actual whitelist 효과와 stable actor 관계만 runtime에 복원합니다.
11. user data 폴더 이름 `DUNI_ARENA`는 향후 표시 이름과 분리해 유지해야 합니다.
12. 웹 원본/기존 온라인 preview를 변경하거나 재배포하지 않았습니다.

## 59. Phase11만 되돌리기

작업 전 Godot526파일을 `migration/phase105-before-phase11.tar.gz`로 보존했습니다. 저장소 루트에서 현재 작업을 먼저 보관하고 정확한 Phase10.5를 복원합니다.

```bash
cp godot/migration/phase105-before-phase11.tar.gz /tmp/phase105-before-phase11.tar.gz
mv godot godot-phase11-backup
tar -xzf /tmp/phase105-before-phase11.tar.gz -C .
```

웹 파일과 user data를 삭제하지 않습니다. 기존 파일 위 덮어쓰기만 하면 신규 코드가 남으므로 폴더 보관 이동 후 복원합니다. Phase10.5는 v1 save를 사용하지 않지만 생성한 파일은 user data에 그대로 남습니다.

## 60. Phase12 전에

기존 `user://` 폴더·v1 fixture·stable IDs·transaction/settlement 경계를 유지해야 합니다. 앱별 종료·파일시스템 테스트, 향후 schema/Resource 변경 시 migration 정책을 결정하세요. 최종 UI가 로드된 결과를 표시하더라도 정산/보상을 다시 실행하지 않아야 합니다.

Phase12 최종 UI/VFX/사운드는 시작하지 않았습니다.

## 실행

저장소 루트:

```bash
godot --headless --path godot --editor --quit
godot --headless --path godot --script res://tests/test_runner.gd
godot --headless --path godot --script res://tests/phase11_runner.gd
godot --headless --path godot --script res://tests/save_ui_smoke.gd
godot --path godot
```

에디터에서 `godot/project.godot`를 열고 F5를 사용해도 됩니다. 테스트는 `user://phase11-tests`, `phase11-ui`, 별도 XDG의 `phase11-process` 경로를 사용합니다. 정식 `user://saves/autosave.json`에 검사 fixture를 쓰지 않습니다.
