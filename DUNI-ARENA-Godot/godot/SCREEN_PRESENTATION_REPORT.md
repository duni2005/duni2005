# 원본 UI·화면 연출 보완

이번 변경은 표시 계층만 수정한다. 전투/AI/타워 운영 규칙, 저장 schema v1, user:// 경로와 기존 브라우저 저장소를 유지한다. 사운드를 추가하지 않는다.

## 원본 조사와 화면 비교

`dist/tower.js`, `strategy.js`, `spectator.js` 실제 실행 코드와 원본 게임을 실행해 확인했다. `migration/screen-presentation/html/`의 390×844 / 1280×720 캡처 12장은 원본 지도, 최초 방 발견, 실제 영입, 승급 연출 fixture, 층/챕터 정복이다. Godot 동일 크기 캡처와 비교 이미지는 같은 디렉터리에 보관한다. 승급 자격·층 클리어·전투 구도/사망은 명시적 fixture이며 자연 전투 발생 장면으로 주장하지 않는다.

| 요소 | 변경 전 | 이번 반영 |
|---|---|---|
| 헤더 | 일반 텍스트 | 원본 계열 주황 링과 DUNI / ARENA 브랜드, 구분선 |
| 메뉴 | 두 컨트롤 유지 | 둥근 메뉴/유닛 버튼의 중복 사각 테두리 제거 |
| 아이콘 | 단색 공통 벡터 중심 | 원본 의미/색을 따른 로컬 SVG 38종, 디바이스 emoji 글꼴 의존 없음 |
| 모집 | 기본 카드/구매 표시 | 캐릭터·HP/ATK·역할·토큰 가격 프레임, 구매 후 영입 강조 |
| 상점 | 단색 상품명/아이콘 | 장비별 컬러 심볼·흰 제목·분리된 금색 가격 영역 |
| 방 | 일반 이벤트 제목 | 발견 후 이벤트 세부 종류 표시, 숨긴 방 종류 유지, 잠김 대비 조절 |
| TP/배치 | 텍스트 버튼 중심 | 성향 아이콘, 주 행동에 재개/시작 방향 아이콘 |
| 결과 | 즉시 패널 | 실제 결과별 엠블럼·짧은 fade-in·정산된 보상 피드백 |
| 카메라 | 작은 impact 확대 | 생존 유닛 bounds/속도 기반 구도, 마지막 적 처치 focus |

## 연출 순서와 실제 원본 시간

| 연출 | 원본 / Godot 시간(실제 초) | 제어 |
|---|---:|---|
| 최초 방 발견 | 2.1 | 최초 발견만 표시, 전투 시작/방 변경 시 오래된 연출 제거 |
| 길드원 영입 | 2.5 | 재화 이동 후 0.5초 지연, 터치/Enter/Space/Escape로 건너뛰기 |
| 승급 | 3.0 | 선택한 기준 캐릭터와 합쳐지는 실루엣, 별/장비 칸 표시 |
| 층 정복 | 2.8 | 실제 conquered 변경을 관찰, 정산된 보상 설명 |
| 챕터 정복 | 3.6 | 실제 chapter_progress 변경 관찰 |

원본 fade-in 0.2 / fade-out 0.8초를 따른다. 토스트 최대 3개, 재화 비행 최대 24개, 연출 대기열 최대 8개다. 재화·길드원·보상은 연출이 적용하지 않는다. 기존 거래가 성공한 뒤의 결과만 표시하고, 연출 취소/스킵/시간 만료/재입장/이어하기에서 재정산하지 않는다. 로드된 정복 상태를 기준값으로 삼아 지난 정복 연출을 재생하지 않는다.

## 카메라

원본 spectator 함수 4개를 실제 JS에서 추출한 `camera_reference.cjs`와 직접 비교했다. 이동 예측은 속도×0.25, 축별 ±55 제한. 몸 bounds는 scale에 따라 좌우32/위52/아래36, 구도 여백48, 기본 최대 확대2.2다. 중심 보간 rate2.7, 확대1.5 / 축소5, 실제 몸/HP bounds 여백12로 잘림을 막는다. 마지막 처치 강조는 1.55초, 목표 zoom2.8/rate8이다.

카메라는 렌더 transform만 변경한다. 터치 위치는 역변환한다. 실제 Unit 위치, 충돌, AI, Clock, RNG를 쓰지 않는다. TP/초월 조준 중에는 기존 Godot 계약대로 전체 전장 구도로 돌아온다. 원본의 gameplay cinema intro/anticipation/추가 simulation hit-stop을 새로 넣지 않는다. 기존 presentation-only impact freeze를 유지하므로 전투/TP 시간 결과는 바뀌지 않는다.

## 구조·파일

신규: `presentation/arena_brand_bar.gd`, `tower_scene_director.gd`, `tower_scene_surface.gd`, `assets/ui/symbols/*.svg`, `tests/screen_presentation_runner.gd`, `tests/screen_presentation_capture.gd`.

수정: `tower_screen.gd`, `tower_content_screen.gd`, `tower_battle_screen.gd`, `room_battle_screen.gd`, `deployment_screen.gd`, `turning_point_panel.gd`, presentation의 `ui_style`, `arena_icon`, `arena_card`, `wallet_bar`, `camera_controller`, `combat_presentation`.

기존 입력 smoke의 영입/승급 단계는 새 연출을 실제 입력으로 넘기거나 순수 연출 시간만 진행한 뒤 다음 버튼을 누르게 보완했다. 기존 결과 단언을 제거하지 않았다.

## 검증과 증거

신규 138검사: 원본 JS 카메라 12조합(30/60/120fps), 확대/좌표 역변환, 실제 방 발견/영입 거래·터치 스킵, 정확한 연출 수명, 중복/오래된 연출 방지, 큐/버퍼 상한, 로드/게임오버 cleanup, 저장 데이터에 표시 객체 없음.

전체 결과는 `migration/screen-presentation/regression-results.json`, `full-regression.log`, `content-rerun.log`, `browser.log`, `protected-hashes.json`에 기록한다. 최초 content smoke는 새 승급 연출 중 다음 버튼을 눌러 실패했으며, 연출을 마친 뒤 진행하는 입력으로 재검증한다. 이 실패 로그도 보존한다.

X11 렌더러와 Chromium 모바일 CSS 390×844/DPR3를 검사한다. 공유 VM의 software WebGL 때문에 simulation 대기 동안 DPR1을 사용하고 실제 조작/화면 캡처는 DPR3로 복귀한다. 실제 휴대폰 FPS 또는 수동 실기기 검증으로 주장하지 않는다.

## MIGRATION_NOTE / 남은 차이

원본 emoji의 기기별 픽셀 모양을 복제하는 대신 같은 의미와 색을 가진 안정된 SVG를 사용한다. Canvas 캐릭터/파티클은 기존 Phase12.5 렌더러를 유지한다. 이번 작업으로 원본의 모든 픽셀/모든 궁극기 cut-in까지 일치했다고 주장하지 않는다. 카메라의 전투 인트로·anticipation처럼 simulation을 바꿀 수 있는 부분은 기존 계약을 우선한다. Continue에서 연출 큐/카메라/입력 중간 상태를 저장하거나 복원하지 않는다.

## 이번 변경만 되돌리기

이전 미리보기 소스 commit `deca5729bc842368eb9e23614cd107a4da41d9d7`의 `game/scripts`, `game/assets`, `game/scenes`, `game/data`를 기준으로 표시 파일만 복구하고 웹을 다시 export한다. 신규 연출/심볼/테스트를 함께 제거한다. AI/domain/save 파일이나 사용자 저장 파일을 삭제·복원할 필요가 없다. 이전 Sites 버전으로 배포를 되돌려도 같은 URL·저장소를 유지한다.

## 최종 검사 결과

- Godot 4.6.3 editor import / Web release export 성공.
- Phase1~12.5 전체 runner: **120,324 checks / 0 failures**.
- 신규 표시·원본 카메라 비교: **138 checks / 0 failures**.
- 별도 UI/AI/save 검사 17종 모두 통과(`verified-suites.json`; 전체 runner와 중복 검사 포함).
- 모집/상점/장비/강화/전투/휴식/이벤트/승급/예측 UI 실제 입력: **46 / 0**.
- 최종 변경 후 모바일 layout **100 / 0**, TP 입력 **18 / 0**, save UI 입력 **31 / 0**.
- 12vs12: 900 paired ticks, projectile peak26 / zone8 / effect≤85 / number≤35, HP·좌표·공격 상태·RNG 일치. 공유 VM 경과 74,862ms는 실기기 FPS 목표로 해석하지 않는다.
- 보호 해시: 웹19 / AI9 / save8 / 도메인·수치173 파일 **변경 0**.
- 기존 URL에 같은 owner-private audience로 배포 성공. source commit `98fbc14f4418a683d0c75fd2330946f14e6dd87d`, exported PCK SHA-256 `7fcae9abc6b2ee3eace5ba0bd046600fe5489babd057bf007572f4d3d3629af2`. 정확한 deployment/version은 `deployment.json`에 기록했다.
- Web Chromium 390×844 / DPR3 실제 touch: **Continue → 배치 → 전투 → TP → 재개 → 전체 후퇴 → 정산된 결과 → 지도 복귀 → 가로/짧은 화면 resize 통과**. console/page error 0. 재개 컬러 영역42px(컨트롤44px), 결과 CTA 컬러 영역46px(컨트롤48px). `compact-dpr3-browser-results.json` success=true.
- 새 브랜드 높이와 짧아진 재개 버튼 때문에 기존 브라우저 픽셀 probe의 고정 좌표를 갱신했다. HUD는 상단 세 지점에서 전폭을 검사하며, 재개 버튼은 실제 금색 영역을 찾아 터치한다. 이전 잘못된 좌표 probe 기록도 별도로 보존했다. gameplay 수정은 없다.
