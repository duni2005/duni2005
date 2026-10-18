# Phase 12 완료 보고 — UI·전투 가독성·사용성

2026-10-14~15. Phase1~11의 게임 규칙을 유지한 presentation 작업. **사운드 기능은 추가하지 않았다.** 실행 환경 Godot 4.6.3 / X11 dummy display / Mesa llvmpipe. 실제 Android 기기나 사람의 수동 플레이 검사와 구분하여 아래 결과를 기록한다.

## 1. 생성 파일

| 파일 | 역할 |
|---|---|
| scripts/presentation/ui_style.gd | 공유 Theme, 숫자/성향/개체 표시, safe margin, scroll/tap·같은 frame 중복 입력 guard |
| scripts/presentation/camera_controller.gd | 읽기 전용 canvas shake, focus 강조, 종료 reset |
| scripts/presentation/combat_presentation.gd | 실제 피해 signal/events/state를 읽는 arena·유닛·공격·영역·VFX renderer |
| scripts/presentation/character_visuals.gd | 26종 능력 표시 어휘, 실제 projectile 종류별 색/형태와 active state badge |
| scripts/presentation/transcendence_overlay.gd | screen-space hold/deadzone/방향/취소 안내와 cast 강조 |
| scripts/presentation/save_menu_preview.gd | domain 생성 없는 JSON header/metadata 미리보기. 기존 전체 검증과 분리 |
| tests/phase12_tests.gd | 4해상도 UI, 실제 입력, save/backup, bounded VFX, paired 12vs12 판정/누수 검사 |
| tests/phase12_runner.gd, phase12_ui_smoke.gd | 단독 검사 / GUI CI 진입점 |
| PHASE12_UI_AUDIT.md | 코드 변경 전 18개 화면/영역 구조와 문제 기록 |
| migration/phase12-* | 해시, 검사 로그, 화면 PNG, 변경 manifest, rollback helper |

Godot이 새 스크립트의 `.uid`도 생성한다. 정확한 최종 목록은 `migration/phase12-file-changes.json` 참조.

## 2. 수정 파일

UI 9개: `main_menu_screen.gd`, `tower_screen.gd`, `tower_content_screen.gd`, `guild_management_panel.gd`, `deployment_screen.gd`, `deployment_board.gd`, `room_battle_screen.gd`, `tower_battle_screen.gd`, `turning_point_panel.gd`.
`project.godot`은 표시 이름만 Phase12로 갱신. `README.md`와 `test_runner.gd`에 이번 단계/검사를 연결. 기존 `ai_ui_smoke.gd`, `character_ui_smoke.gd`는 개발 정보 toggle을 명시적으로 켜도록 했고, `save_ui_smoke.gd`는 새 저장 문구를 확인한다. 검사 삭제·게임 수치 변경 없음.

## 3. 공통 Theme/UI 구조

공유 Theme 하나로 panel, normal/hover/selected/disabled/focus button을 제공한다. 어두운 전장과 밝은 문자, 선택 상태의 금색 border. 일반 텍스트16, 주요 touch action 최소44px. HP는 `85 / 150`, gauge는 `%`, 가격은 정수, 세부 stat은 필요할 때 소수1자리로 정리한다. 모바일 description은 wrap/scroll, 설명 확인은 기존 tap dialog와 선택 상태를 사용한다. 중요한 버튼에 margin을 둔다. Fullscreen 기기 safe-area는 DisplayServer 정보로 top/bottom을 보정한다.

## 4. Main Menu

새 게임/이어하기를 유지하고 중앙 메뉴 폭을 제한한다. 실제 창 크기에 UI logical scale을 맞춰 좁은 창의 글자가 작아지는 문제를 예방한다. 새 런 덮어쓰기 confirmation과 중복 진입 guard를 유지한다.

## 5. Continue

챕터·층·상태·HP·골드·토큰·길드/생존 인원·마지막 저장 UTC 시각·정복 상태를 표시한다. `SaveMenuPreview`는 primitive JSON metadata를 먼저 읽으며 RunState/Map/Controller를 만들거나 RNG를 소비하지 않는다. **이어하기 활성화는 다음 deferred 단계에서 기존 SaveManager 전체 validation을 통과한 뒤** 이루어진다. 이 기존 검증에는 임시 순수 domain decode가 포함된다. 실제 런 복구는 Continue를 눌렀을 때 기존 loader가 한다.

## 6. Tower Map

15층/120방, 세로 층·가로 방 구조 유지. 잠김/미발견/발견/방문/클리어/소비·선택을 텍스트와 버튼 상태로 구분한다. 미발견 방의 `event_type` 노출을 제거했다. 챕터/최고 해금층, 새로운 층 해금, 층 정복, 최근 이미 계산된 콘텐츠 결과를 표시한다. 타입 선택·보상·progression을 UI에서 다시 계산하지 않는다.

## 7. Guild UI

개별 길드원 이름+짧은 번호, level/stars, HP, 기력, stance, 장비 슬롯을 보여준다. 동일 타입도 각 Button의 member_id binding을 유지한다. 사망 길드원은 roster에 남고 `사망 · 배치 불가` 표시.

## 8. Equipment UI

각 item instance의 기존 ID를 유지한다. 목록의 이름을 tap하면 effect/장착·재각인 confirmation을 표시한다. 기존 domain 장착·슬롯·회수 API 그대로 사용한다. 일반 자유 해제를 새로 추가하지 않았다.

## 9. Upgrade UI

현재 → 다음 level의 HP/공격/방어/이동과 가격을 보여준다. 임시 member 값과 기존 stat assembler를 사용한 **읽기 전용 preview**이며 실제 member를 강화하거나 HP를 변경하지 않는다. 성공은 기존 transaction 한 번.

## 10. Promotion UI

3명 선택에서 첫 member가 유지·장비 유지, 나머지 member가 소비·장비 반환되는 점을 표시한다. 현재 level/stars/종류·승급 가능 여부와 남은 횟수, level reset 등 기존 정책 유지. 선택 UI가 transaction을 대신 수행하지 않는다.

## 11. Recruit UI

3개 유지되는 후보의 캐릭터/태그 역할/토큰 가격/영입 상태와 리롤 비용을 표시한다. 가로 스크롤, 큰 후보 카드, 구매된 후보 disabled. ID와 개별 영입 정책·content RNG 변경 없음.

## 12. Shop UI

상품 이름/효과/가격/판매 상태를 wrapped button에 표시한다. 이미 판매된 상품/재화 부족은 disabled. stock 재생성 없음. 동일 종류 아이템 instance를 합치지 않는다.

## 13. Event UI

실제 휴식/온천/보급/예측/승급 choices와 결과를 기존 content 화면에서 제공한다. 결과 숫자 표시를 통일하고 지도에 최근 결과를 짧게 보여준다. resolved event/result는 기존 저장 결과를 읽는다. 예측 전투 동안 navigation 잠금 유지.

## 14. Deployment UI

실제 X40..380/Y40..760 영역을 강조하고 최소58 규칙을 표시한다. 자유 위치·drag 이동·해제·초기화·진형 복원 유지. HP/성향·짧은 개체 번호만 board에 표시한다. 사망/중복/너무 가까움/영역 밖 실패 이유를 한국어로 알려준다. 배치로 상태를 소모하지 않는다.

## 15. Battle HUD

Player HP, simulation 시간/배속, 양측 생존 수, 후퇴 가능 시간, 초월 상태를 우선한다. 시작 뒤 배치 버튼/roster/정비 버튼을 숨긴다. 타워의 raw room/enemy ID·좌표·시도 수를 일반 HUD에서 제거했다.

## 16. Unit HP/상태

원래 Unit/BattleManager의 debug draw를 가시성만 숨기고 별도 renderer가 그린다. 몸체/진영 outline+▲▼, 작은 HP bar, shield bar/ring, 무적 gold ring, 기절/철벽/은신/장전/포획/조종 등의 badge. 터치 선택 시 이름·stance·HP·shield·궁극기/초월 %·능력 어휘를 상세 표시한다. 타이머 숫자는 일반 전장에 쌓지 않는다.

## 17. TP UI

감속 notice → 40초 전략 화면, 생존 아군 가로 strip, 4stance, 카드, 사용/취소/재개와 조건 충족 후퇴. 12/42/72 simulation 예약·2real초 감속·40real초 hold는 그대로. 웹 `strategy.js:102`도 적 forecasts를 panel에 표시하지 않으므로 일반 UI에서는 숨겼다.

## 18. Strategy Card UI

6종 이름, 선택, 대상, once/floor/cooldown, 불가 이유와 pending 명령을 표시한다. `해금 +3` 내부 표현을 사용자용 쿨타임 표기로 정리했다. TP의 executor/receipt/resolve 순서는 바꾸지 않았다. mobile tap→설명/대상→사용/취소 유지.

## 19. Transcendence UI

준비 여부/%·hold 안내. 아이콘 strip을 board 위로 옮겨 하단에서도 아래 방향 drag 공간을 확보한다. .16초 hold, 32px deadzone과 release/cancel 규칙 그대로. 진행 arc, 방향선, deadzone 안 취소 안내를 screen-space overlay로 그린다.

## 20. CameraController

`ArenaCameraController`는 RefCounted pure presentation 상태만 가진다. arena 전체800×800 유지. camera offset/focus highlight를 별도 draw transform에서만 적용한다. 실제 actor 위치/AI/physics/Clock을 변경하지 않는다.

## 21. Camera shake

critical·clash·ultimate에 작은 bounded shake, 최대6logicalpx. 실제 freeze/전투 종료에는 offset0. 일반 타격마다 큰 shake를 넣지 않는다. 별도 RNG 소비 없음.

## 22. Camera focus

궁극기/적 처치의 짧은 focus outline으로 강조한다. viewport 줌·강제 추적/팬은 넣지 않아 전장 전체와 조작 좌표를 유지한다.

## 23. Hit presentation

DamageResolver의 `damage_resolved` 신호를 읽는 flash/spark/ring과 실제 HP 손실 숫자. UI가 피해를 다시 계산/적용하지 않는다. 웹은 `impactPause` 35/55/80ms와 accumulator stop을 사용한다. 이번 단계는 게임 판정 보존을 위해 **새 gameplay hit-stop을 넣지 않았다**. SceneTree.paused/Engine.time_scale 사용 없음.

## 24. Critical

실제 DamageOutcome.critical만 사용해 금색·큰 숫자/강한 spark를 표시한다. 추측 critical·새 치명타 계산 없음.

## 25. Parry

parry_success/warrior_parry 기존 이벤트로 cyan flash·패링/반격 문구. 현재 성공 구간의 방어 arc와 실제 CombatWave radius impulse를 표시한다.

## 26. Clash

실제 접점 이벤트로 gold ring·상쇄 문구·작은 shake. 실제 남은 공격/투사체를 계속 그리므로 돌파 공격이 계속 진행하는 것을 확인할 수 있다.

## 27. Shield

blue ring/bar로 활성, 별도 absorb 숫자/impact, shield HP가0이 된 경우 break burst. 무적의 gold ring과 구분한다.

## 28. Stun/Invincible

기절 badge/짧은 cue, 무적 gold ring/발생 cue. 지속 표시가 runtime state를 읽는다. gameplay timer는 수정하지 않는다.

## 29. Projectile VFX

실제 velocity·이전/현재 위치를 읽는 짧은 trail. giantArrow/sniper는 긴 방향형, pellet/machineBullet은 작은 연속 입자, lightning/thread/tongue는 선형, star는 십자. collision shape/속도/수명 그대로.

## 30. AoE telegraph

기존 `zones.entries`의 실제 point/radius/shape와 `ability.cast_area`만 읽는다. blackhole/fire/healing/holy/cosmic과 사각 ring 구분. 없는 공격 예고/추가 회피 시간을 만들지 않는다. 종료된 전투의 영역·cast는 다시 그리지 않는다.

## 31. Character-specific VFX

| 타입 | 최소 구분 cue |
|---|---|
| 전사/궁수 | 검격/반격, 화살·거대 화살·도탄 실제 경로 |
| 마법사/암살자 | 회전 blackhole 영역, 은신 opacity/badge |
| 수호자/힐러 | 보호 연결선, green heal/치유 영역 |
| 저격수/샷건 | 조준 badge·관통 trail, 실제 pellet fan·장전 |
| 가위바위보/UFC | 승부 badge, 실제 ring 사각 영역 |
| 두비두밤/챌런 | lostSword 위치/연결·방어태세, 실제 combat_scale 몸체 크기 |
| 포식자/폭탄 | 캐릭터/처형 능력 표시와 실제 hit, fuse badge·orange impact |
| 검객/위성 | 실제 경로 참격/cast_area, missile 색/trail |
| 성기사/히어로 | 축복 badge/holy 영역, hero_rescue cue |
| 탱크/광신도 | 포탄·orange fire 영역, saint 관계선 |
| 번개/거울 | lightning 연속 선형·감전, pink reflection/반사 badge |
| 은하/기관총 | star/cosmic 영역, 연속 bullet trail/장전 |
| 개구리/인형술사 | tongue/포획 badge·포획된 몸체 숨김, thread/control badge/현재 team outline |

26종은 모두 기본 emoji/능력 어휘와 현재 runtime shape로 구분한다. 웹의 모든 개별 sprite pose/particles를 픽셀 단위로 복제한 작업은 아니다. 남은 차이는58항 참조.

## 32. Ultimate

실제 ultimate 이벤트의 ring/강조와 실제 cast_area 예고·영역·projectile을 표시한다. 게이지/AI/cast/interruption/persistence 변경 없음.

## 33. Transcendence presentation

기존1.15real초 cast 동안 purple dim·caster outline·방향선·짧은 cut-in·실제 release 시점에 따른 flash. 관련 UI 상세를 숨겨 cut-in 겹침을 막는다. attack/charge 시점 그대로.

## 34. Death

unit_died에서 색 fading burst와 짧은 사망 feed. 죽은 Unit을 살아있는 body처럼 계속 그리지 않는다. revive/roster/Player HP 처리는 기존 domain만 수행한다.

## 35. Kill/Player HP

최근 사망 최대3줄. 현재 런의 이미 생성된 death-loss receipts와 이름/값을 읽어 Player HP 손실을 표시한다. 비용 계산·HP 차감이나 재정산은 UI에 없다.

## 36. Victory

승리/시간/HP/생존 길드원, 방 clear, 정산 완료·첫 승리 회복, 저장된 방 보상 gold/token을 보여준다. result를 표시하는 함수는 settlement를 호출하지 않는다.

## 37. Defeat

패배와 추가 손실/예비 생존 길드원·재배치 가능성을 알려준다. 기존 패배와 gameover 분리를 유지한다.

## 38. Retreat

후퇴를 패배와 다른 제목으로 표시하고 생존 참가자 귀환, 적 HP/위치 유지·재도전을 안내한다.

## 39. Game Over

타워 HUD/결과에서 Player HP 소진, 생존 길드원 없음, abandon을 구분한다. 저장된 종료 런 Continue는 기존 종료 routing을 사용한다. 보상/정산 재실행 없음.

## 40. Boss

공개된 boss/miniboss 방 표식·층·배치 전 경고 강조. gameplay 시간을 소비하는 intro/새 Clock state를 추가하지 않았다.

## 41. Autosave

비차단 `✓ 저장됨`. 실패/BUSY는 기존 SaveLoadResult를 한국어 상태로 표시한다. gameplay가 멈추는 save popup 없음.

## 42. Backup recovery

metadata 단계에서 backup 가능 표시. 실제 loader.from_backup일 때 `이전 정상 저장에서 복구했습니다.` notice. 파일 구조를 HUD에 노출하지 않는다.

## 43. Transition/input lock

중복 scene 생성 guard, scroll drag 취소, 같은 frame 동일 버튼 실행 guard. confirmation/기존 navigation 정책·도메인 receipt를 유지한다. fade animation은 필수 정보/조작을 지연시키지 않도록 이번 단계에서는 넣지 않았다.

## 44. 모바일/해상도

1280×720,1280×800,1000×1100,390×844 모두 실제 UI layout assertions. X11 mouse와 ScreenTouch 입력 검사, 가로 roster/cards/offers와 세로 map/content scroll. 최종 desktop/mobile PNG는 `migration/phase12-*.png`. 물리 Android safe area/다중 손가락/기기별 성능은 아직 검사하지 않았다.

## 45. Debug mode

기본 OFF. 명시적 개발 정보 toggle을 켜면 기존 AI Target/Plan/Intent/danger/safe/heading/movement/reaction 상태를 볼 수 있다. 개발 캐릭터 생성 controls도 이 모드에서만 보인다. 일반 HUD의 raw timers/actor IDs/attack IDs/RNG 노출 제거. Phase10.5 GUI 검사 자체 보존.

## 46. VFX architecture

UI Board 아래 CombatPresentation, 별도 CameraController/TransOverlay. DamageResolver signals, BattleManager.unit_died와 bounded combat_events, 실제 상태를 읽는다. renderer는 원래 Node의 visibility만 숨긴다. static resources/AI/전투 tick/정산/Save 객체에 presentation 상태를 넣지 않는다.

## 47. Cleanup/pooling

VFX96개, 숫자40개 bounded pure Dictionary buffer. 같은 actor/kind의 가까운 숫자를 병합. effect/number별 Scene Node를 만들지 않아 별도 Node pool을 만들 필요가 없다. 종료1.2real초 뒤 효과/숫자/camera reset, 새 battle attach 시 cleanup, 종료 zone/cast render 중단. 원래 공격/투사체 객체를 snapshot/save하지 않는다.

## 48. 12vs12 stress

전사/궁수/마법사/수호자/힐러/폭탄/성기사/번개/거울/은하/기관총/인형술사 각 진영12명. 동일 seed731, 최초 궁극기 준비 fixture. **연출 사용 전투와 독립 비교 전투를900tick 병행**하여 매 tick RNG/clock, 24명 위치/HP/공격 상태/finite를 비교했다. 최종 orphan Node 증가 없음. peak projectile26, 영역8, VFX96, 숫자35. X11 sample26,417.797ms는 UI frame yield와 비교 전투를 함께 포함한 검사 벽시계 시간이며 FPS/실기기 성능 목표가 아니다. 실제 이벤트: 궁극기29, hit263, 패링 성공6, 상쇄38, stun wave46 등.

## 49. 신규 검사

4해상도 메뉴/지도/배치/전투/TP/초월/결과, 실제 선택/stance/resume/retreat, hidden event 보호, debug ON/OFF, invalid placement 설명, metadata/backup/Continue 이벤트 routing, guild/dead/upgrade/recruit/shop, scroll/중복 click,20 VFX vocabulary, camera reset/bounded buffers/노드 cleanup, 900tick 동일 gameplay 비교. `phase12_ui_smoke.gd`가 동일 suite를 X11에서 실행한다.

## 50. Phase1~11 회귀

| Phase | 검사 | 실패 |
|---|---:|---:|
|1|9,705|0|
|2|243|0|
|3|131|0|
|4|119|0|
|5|110|0|
|6|118|0|
|7|3,702|0|
|8|8,260|0|
|9|15,755|0|
|10|10,255|0|
|10.5|48,418|0|
|11|643|0|

기존 합97,459/0. 새 검사로 기존 gameplay tests를 대체하지 않았다.

## 51. Phase12

22,691 / 0. 동일 suite의 최종 X11 검사도22,691 / 0. 자세한 개별 실패 확인과 실행 결과는 `phase12-regression-final.log`, `phase12-x11-verified.log`.

## 52. 전체 검사

`godot --headless --path godot --script res://tests/test_runner.gd` **120,150 / 0**. `godot --headless --path godot --editor --quit` 최종 import 성공. 최종 로그에 Script Error/ERROR 없음. 기존 GUI smoke10개 총249/0씩 headless/X11. 별도 재시작14/0. 중복 실행된 검사들을 합산하여 유일한 검사 수처럼 표시하지 않는다.

## 53. GUI/X11

기존 deployment/room/TP/cards/commoncombat/characters/tower/content/AI/save smoke와 신규 phase12 suite. 실제 X11 창의 입력 이벤트를 주입했고 screenshot을 시각 검토했다. 사람이 조작한 수동 검증이라고 주장하지 않는다. driver의 VSync 미지원 경고는 존재하며 script/검사 실패와 구분한다.

## 54. 실제 Save/Load UI

별도 테스트 경로에서 recruit→shop→장비/강화→manual save→뷰 폐기→Continue→배치→죽은 적 미생성/손상 HP·위치→TP 새12초→진행 전 checkpoint 복귀. 기존31체크 mouse/touch 흐름을 실행. 신규 GUI에서는 손상 primary의 backup 복구 notice와 미완료 온천 이벤트 routing도 확인. 기존 production save를 테스트에 사용하지 않는다.

## 55. AI/게임 파일 hash

작업 전603파일 snapshot. AI·전투·Ability·정산·저장·정적 Resource **173개 전부 SHA-256 동일**. BattleBrain/Movement/ThreatResponse/Target/Area/AI timers를 바꾸지 않았다. 새 renderer가 BattleManager.rng를 소비하지 않는 것도 paired test로 확인.

## 56. Save schema

기존 SaveManager/codec/validator/loader/migrator 파일 동일. schema_version1, user dir DUNI_ARENA, user://saves/autosave.json, stable IDs/receipts/safe checkpoint 유지. 고정 v1 save fixture 동일. UI metadata preview는 v1 헤더를 읽는 추가 display 계층이며 serializer가 아니다.

## 57. 웹 SHA-256

`dist/`19개 원본 전후 SHA-256 전부 동일. HTML/JS/CSS 수정 없음. 상세 before/after 값은 `migration/phase12-web-sha256.json`. Godot 외 프로젝트 파일 변경 없음.

## 58. 남은 UI/VFX 차이

최종 authored pixel sprite/캐릭터별 전체 애니메이션·웹의 모든 particle/pose/cut-in을 복제한 단계는 아니다. 최소 outline/emoji/실제 영역/궤적/상태 기반 표현이다. focus는 강조이며 viewport zoom/pan이 없다. source gameplay hit-stop은 이번 단계에 추가하지 않았다. safe-area는 API/margin 구조로 지원하지만 물리 모바일/노치 기기 검사는 필요하다. 접근성 설정(효과 감소), 정식 장비/상태 아이콘 art와 터치 장기 사용성 검토는 출시 전 작업. 사운드 완전히 별도 단계.

## 59. MIGRATION_NOTE

- MN12-01: 실제 웹 TP panel에 없는 enemy forecasts는 일반 UI에서 숨기고 debug에만 둔다.
- MN12-02: 기존 hitStop은 source accumulator에 영향을 준다. 판정 보존 때문에 Phase12에서는 presentation shake/flash만 추가.
- MN12-03: ArenaCameraController의 offset은 draw/input adapter에서만 사용, actor 좌표/AI에 쓰지 않는다.
- MN12-04: 진영 표시는 현재 전투 team, 소유권/정산은 기존 original faction/ID 계약 유지.
- MN12-05: UI/VFX/선택/카메라 상태는 save v1에 넣지 않는다. metadata 미리보기와 전체 validation을 분리.
- MN12-06: 실제 cast/zone radius와 시간을 읽는다. 새로운 telegraph 시간/능력/회피 기회를 만들지 않는다.
- MN12-07: 그래픽 buffer cap/병합은 표현만 줄인다. 피해/공격 객체를 삭제하여 성능을 맞추지 않는다.
- MN12-08: audio manager/stream/bus/settings/asset 추가 없음.
- MN12-09: source-only art·particle·hit-stop parity와 real-device usability는 별도 출시 준비 항목.

## 60. Phase12만 되돌리기

`migration/phase11-before-phase12.tar.gz`와 `phase12-before-hashes.json`은 변경 전 상태다. 변경 manifest에 기록된 수정 파일을 archive 버전으로 복원하고 이번 UI/presentation/test 스크립트만 제거한다. `migration/rollback_phase12.py` 기본 실행은 dry-run이며 `--apply`가 있어야 적용한다. 이후 파일을 더 수정했다면 hash guard가 거부한다. 보고/검사 증거/backup은 남긴다. 웹/production user data는 건드리지 않는다. 복원 후 Godot editor import와 Phase1~11 tests를 실행하면97,459검사 구성으로 돌아간다. 프로젝트 전체 git reset/clean은 사용하지 않는다.

## 61. 정식 출시 전

실제 Android/iOS touch·safe area·gesture 취소·스크롤 장기 사용성, OS별 CJK/emoji fallback, 효과 감소 옵션, 해상도/저사양 GPU 성능, 아트·원본 연출 일치도, export에서 테스트/로그/backup 제외, 실제 배포 preview 갱신·플랫폼 패키징, production save 권한/업데이트 호환 검토가 필요하다. **이번 단계에서 사운드 또는 다음 게임 기능을 시작하지 않았다.**
