# 터닝포인트 · 이벤트 · 전투 결과 원본 흐름 수정

HTML 원본 `dist/`를 직접 실행하고 390×844 / 1280×720에서 휴식, 부활, 온천, 온천 결과, 보물상자, 승급, 전투 예측, 승리, 패배, 후퇴를 캡처했다. 근거는 `migration/event-parity/html/`, 변경 후 Godot 캡처/로그는 같은 상위 폴더에 있다. 이번 수정은 UI/presentation만 다루며 이벤트 지급·성장·전투 정산 규칙을 바꾸지 않는다.

## 원본과 확인한 차이 및 수정

| 항목 | 기존 Godot 차이 | 변경 |
|---|---|---|
| TP 카메라 | 감속 진입 시 전체 구도로 즉시 전환 | 원래 2 real seconds 감속 동안 현재 확대 구도에서 800×800 전체로 smoothstep 축소. hold에서는 identity camera |
| TP 제목 | 영어 제목과 보조 설명, hold 안내를 겹쳐 표시 | 시계 그림 + `터닝포인트` 한 줄. 보조 문구 삭제. 패널에는 시계와 남은 초만 표시 |
| 이벤트 기본 구조 | 제목 아래 세로 행동 목록 | 녹색 방 패널 + 길드원 수평 strip + 2열 선택 카드 |
| 길드 휴식소 | 4개의 긴 세로 버튼 | 플레이어 회복 / 자원 획득 / 생존 유닛 회복 / 사망 유닛 부활 2×2 |
| 부활 | 같은 화면을 사망자 목록으로 치환 | 별도 모달, 사망한 개별 길드원만 표시, 선택 수·회복 HP·확정 버튼. 최대 2명, 확정 전 지급 없음 |
| 온천 | 배경/상호작용이 일반 버튼과 동일, 결과는 한 줄 | 온천 입장 / 복권 구매를 나란히 표시. 선택 전 지도 버튼 숨김. 선택 후 같은 방의 결과 카드와 지도 버튼 |
| 보물상자 | 내부 choice ID와 효과를 한 줄로 나열 | 플레이어 회복 / 생존 유닛 회복 / 자원 / 실제 생성된 아이템·카드 branch를 2×2로 표시. 선택 시 기존 도메인 완료→지도 |
| 승급 | 전원 세로 목록과 별도 완료 버튼 | 선택 슬롯 3개 → 승급 결과 미리보기, 3열 길드원 카드, 선택 수·승급 버튼. 유지/소비 역할, 장비 반환 안내. 상단 완료→지도 |
| 전투 예측 | 보상/패배/무승부 반환 조건 누락, 결과 internal enum | 원본 배팅 조건 표시, 올바른 선택 스타일 유지, 한국어 성공/실패/반환 결과 |
| 승리·패배 | 전투장 위 거대한 crest와 긴 결과 팝업 | 타워 결과 페이지: 기존 제목·wallet, 녹색 방 패널, ROOM CLEAR/TRY AGAIN, 손실 블록, 실제 보상, 지도 CTA |
| 후퇴 | 즉시 결과 팝업과 지도 클릭 요구 | 원본 `advanceTowerRetreat`의 1.9 real seconds 페이드, 중앙 붉은 `후 퇴`, 완료 후 자동 지도 복귀 |

## 실제 원본 흐름

- `renderTower` / `renderTowerHotSpring`: 휴식·일반 이벤트 2열, 온천 결과는 같은 방에 남는다. 온천 결과가 있을 때에만 지도 CTA가 나타난다.
- `renderTowerRevival`: 사망자 선택 모달에서 HP 20% 미리보기, 최대 2명 선택, 별도 확정.
- `renderTowerPromotion`: 3개 슬롯/결과/길드 카드/선택 수/승급 버튼, 상단 완료.
- `renderTowerPredictionEvent` / `settleTowerPrediction`: 성공 배팅액×2 + 토큰1, 패배 배팅액 소모, 무승부 반환을 표시한다. 계산은 기존 도메인을 사용한다.
- `towerResultMarkup`: 유닛 손실·Player HP 손실을 먼저, 승리 보상을 다음에 표시한다. 기존 결과 데이터만 표시한다.
- `retreatTowerBattle`: 수락 시 정산을 먼저 하고, 새 판정 없이 시각적 후퇴를 보여준다. `advanceTowerRetreat`의 배경 fade 1.25초, 글자 시작 .25초/등장 .5초, 전체 1.9초를 따른다.

## 구조

- `ArenaCameraController.advance_overview`: 순수 카메라 보간. `CombatPresentation`이 TP slowdown일 때 호출하며 기존 `BattleClock`의 시간을 수정하지 않는다.
- `BattleCueOverlay`: 시계와 한국어 제목 한 줄. 결과 페이지 위에 그리지 않는다.
- `TowerContentScreen`: 방 패널/선택 카드/부활 모달/승급 미리보기. ID 기반 기존 content_action만 호출한다.
- `ArenaCard`: event_option, revival_member, promotion_member, promotion_slot 렌더러. 이전 팀·금액 선택 상태와 일반 카드 렌더러 유지.
- `TowerBattleScreen`: 이미 정산된 결과의 별도 타워 페이지. 지급·HP 손실·기력 계산을 재실행하지 않는다. 장비 승리 골드도 실제 BattleResult 값으로 표시한다.
- 신규 `RetreatPresentation`: 입력을 막는 한정 시간 visual overlay. `_finish_retreat_presentation`은 기존 controller.return_map만 호출한다. Session 정산과 autosave는 fade 시작 전에 끝난 상태다.
- `TowerScreen`: 결과 페이지의 wallet을 재화 도착 위치로 사용한다. 기존 재화 flight/count/spark를 유지한다.

## 검증 근거

`event_parity_runner.gd`는 동일 도메인 트랜잭션과 실제 touch event로 PC/모바일을 검사한다. 이벤트 선택/부활 확인/승급/온천 결과 단발/배팅 표시, TP 2초 전체 구도/시계 불변, 승리·패배 페이지, 후퇴 중 상태 불변·입력 잠금·1.9초 경계·지도 복귀를 포함한다. X11 실행은 같은 fixture의 화면을 저장한다. 전투 승패 캡처는 명시적 HP fixture이며 자연 전투 승패 재현이라고 주장하지 않는다.

기존 UI smoke는 새 카드 계층에 맞춰 안정적인 이름 검색을 사용한다. 기존 모바일 결과 배치 테스트의 직접 생성 결과 fixture는 실제 후퇴의 자동 라우팅과 분리한다. 원래 검사 항목은 제거하지 않았으며 자동 후퇴 경계는 신규 테스트에서 별도 확인한다.

최종 결과:

- Godot 4.6.3 editor / Web release export 성공.
- 전체 Phase1~12.5: **120,324 검사 / 0 실패**. 12vs12 VFX ON/OFF 900 paired ticks도 기존 결과 유지.
- 신규 이벤트/TP/후퇴: **96 / 0** headless 및 **96 / 0** X11(동일 항목, 합산하지 않음).
- 기존 모바일 layout **100 / 0**, 콘텐츠 UI **46 / 0**, 화면/카메라 **150 / 0**, 직전 UI/재화 **32 / 0**, counter-stall **367 / 0**. 최종 실행 script error 없음.
- 브라우저 390×844, 입력/캡처 DPR3: Continue → 배치 → 전투 → TP → 재개 → 후퇴 fade → 자동 지도 → 가로/짧은 화면 resize 성공. console/page error 0. 실제 정산 저장 phase가 route로 전환됐음을 확인. 소프트웨어 WebGL 대기 구간 DPR1이며 물리 휴대전화 FPS 결과를 주장하지 않는다.
- 마지막 영문 corner label 제거 및 timer 아이콘 여백은 presentation draw/text만 수정했으며 `event_tp_capture.gd`에서 PC/모바일 마지막 화면을 다시 확인했다(**2 / 0**). 브라우저 검사는 이 마지막 글자 정리 전 빌드이며 주요 상호작용/카메라/후퇴 코드는 동일하다.
- 웹 원본 **19/19** 불변. 보호 대상 AI/전투 controller/Save/Resource 등을 포함한 **76개 파일** 해시 불변.

근거는 `new-tests.log`, `x11-tests-final.log`, `tp-capture-final.log`, `final-ui-results.json`, `full-regression.log`, 브라우저 결과 JSON 및 `hash-check.json`/`protected-hashes.json`에 있다. 원본/수정 후 비교 갤러리는 `migration/event-parity/comparison.html`이다. 초기 시도 중 발견한 부활 confirm visibility 문제는 최종 모달에서 명시적 하단 confirm 버튼으로 수정했다.

## 보호 및 MIGRATION_NOTE

웹 19개 원본, 전투/AI, UnitData/성장/장비 수치, Phase11 저장 codec/schema/ID/receipt 파일은 변경하지 않는다. TP 12/42/72 simulation schedule, 2초 slowdown, 40초 hold, 20초 전체 후퇴 조건도 동일하다. 후퇴 정산/적 HP/위치 snapshot은 기존 Session이 한 번 처리하며 화면 연출은 actor 위치를 쓰지 않는다. 사운드 기능·설정·파일을 추가하지 않았다.

저장 스키마 변경/마이그레이션은 필요 없다. 후퇴 페이드 도중 종료하면 이미 저장된 정산 결과가 남고 기존 Continue 라우팅으로 복구된다. 중간 프레임을 저장하지 않는다.

## 남은 시각적 차이

- 원본 emoji/Canvas portrait와 Godot 캐릭터 픽셀 초상은 기존 표현을 유지하며 픽셀 단위 동일성을 주장하지 않는다.
- 원본 후퇴는 마지막 속도로 actor/projectile의 시각적 이동도 계속한다. Godot은 정산된 전투 그림 위에 같은 fade/title을 표시한다. 지속 좌표나 공격 객체를 다시 움직이지 않는다.
- 전투 예측의 결과는 Godot의 기존 이벤트 결과 영역에 남는다. 원본 관전 battle winner 영역과 장면 구조까지 동일하다고 주장하지 않는다.
- 저장된 result를 Continue하는 기존 Phase11 라우팅은 유지한다. 결과 화면 애니메이션을 복원하거나 정산을 재실행하지 않는다.

## 이번 수정만 되돌리기

직전 Site source commit `be544dcd6644ca8ef630c3c531e7ce64be7ff0ca` 버전을 재배포하면 이번 TP/이벤트/결과 수정만 되돌아간다. 직전 선택 버튼·재화 연출·카메라 확대·전투 멈춤 수정은 그 버전에 포함돼 있다. 로컬은 `migration/event-parity/before/`에서 변경한 9개 스크립트를 복원하고 신규 `retreat_presentation.gd/.uid`를 제거한 뒤 Web export를 다시 만든다. 사용자 save는 삭제하지 않는다.

## 배포

- URL: https://duni-arena-godot-125.kanduni.chatgpt.site
- Source: `cbfa15d5482afd83ac0b7c71f54899e57030e741`
- Deployment: `appgdep_6ad303e344648191ac1443c9b83d5b3a`, succeeded.
- Version: `appgver_dfe25fd92b90819189144ac478d71df1`.
- 기존 owner-private 접근 범위 유지. 배포 runtime이 검사한 source와 동일함을 확인했다.
