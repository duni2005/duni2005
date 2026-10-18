# 선택 UI · 재화 이동 · 전투 연출 · 카메라 수정

## 적용 범위

- 승부예측 팀/배팅 금액 선택을 전용 카드로 표시한다. 선택한 팀은 초상·이름·선택 배지를, 선택한 금액은 금색 프레임과 밑줄을 사용한다. 기본 Button의 불투명 focus가 내용을 가리던 문제를 제거했다. focus는 투명한 외곽선이다.
- 재화 획득은 실제 행동 위치에서 보유 재화 아이콘으로, 사용은 반대로 이동한다. 마우스/터치/키보드가 같은 action origin 경로를 사용한다. 임베디드 창의 좌표도 반영한다.
- 도착 불꽃·보유 재화 pulse·증감 수치·카운트 애니메이션을 추가했다. 유료 복권처럼 한 거래에서 비용과 보상이 모두 있는 경우 순차 감소/증가와 양방향 비행을 표시한다.
- 전투 시작, TP 감속/정지/재개 배너와 전술 스캔, 승리 왕관/패배/후퇴 결과 문장을 보강했다. 마우스 입력을 막지 않으며, 전투장 강조는 결과 창 아래에서 그린다.
- 관전 카메라 목표 배율에 1.12를 곱한다. 최대 목표 2.5, 기존 body/HP bounds guard·보간·입력 역변환·TP/초월 overview/reset은 유지한다. 넓게 퍼진 전투에서는 전체 유닛 가시성을 우선해 확대가 제한된다.

## 웹 조사 및 표현 계약

`dist/tower.js`의 spendTowerResources/awardTowerResources와 resource feedback을 재확인했다. 원본은 골드 입자 수 ceil(sqrt(amount)/3)을 3~9로 제한하고, 토큰은 1~5개, 0.035초 지연, 약 0.72~0.82초 quadratic Bezier 비행, 도착 8개 spark와 0.32초 pulse를 사용한다. Godot은 같은 범위·순서를 사용하며 목표 wallet 위치 변경에도 획득 입자가 따라간다. 숫자는 사용자 요청대로 첫 입자 도착 후 0.32초 동안 증가한다. 지출 숫자는 즉시 감소 애니메이션을 시작한다.

재화·거래·정산은 기존 도메인에서 이미 확정된 값을 읽는다. 연출은 보상/구매/정산을 다시 실행하지 않는다. 실제 잔액이 변하지 않은 중복 feedback은 입자를 추가하지 않는다. 비용+보상이 함께 있는 경우 결과의 지급액과 잔액 차이로 총 지출을 표시한다. presentation의 난수는 게임 RNG를 소비하지 않는다.

비행 최대 96개, spark 최대 180개, 증감 문구 최대 8개이며 만료/장면 변경 시 정리한다. UI용 실시간 애니메이션이며 simulation time·AI·공격·TP 12/42/72초, 감속 2초, hold 40초를 변경하지 않는다. 사운드는 추가하지 않았다.

## 변경 파일

신규 런타임:

- scripts/presentation/battle_cue_overlay.gd
- scripts/presentation/battle_result_banner.gd

수정 런타임:

- scripts/presentation/ui_style.gd
- scripts/presentation/arena_card.gd
- scripts/presentation/wallet_bar.gd
- scripts/presentation/tower_scene_director.gd
- scripts/presentation/tower_scene_surface.gd
- scripts/presentation/camera_controller.gd
- scripts/tower_content_screen.gd
- scripts/tower_screen.gd
- scripts/tower_battle_screen.gd
- scripts/guild_management_panel.gd
- scripts/room_battle_screen.gd

검증: tests/impact_ui_runner.gd, impact_ui_capture.gd, impact_result_capture.gd, screen_presentation_runner.gd, migration/screen-presentation/camera_reference.cjs 및 camera-reference.json. 기존 JS 카메라의 baseline 계산은 그대로 비교하고 요청된 확대 target만 별도 closer 기준으로 검사한다.

## 검증

- Godot 4.6.3 editor import / Web export 성공.
- 전체 Phase 1~12.5 회귀: **120,324 검사 / 0 실패**.
- 새 선택/재화/거래·RNG 불변/카메라 검사: **32 / 0**.
- 모바일 레이아웃: **100 / 0**.
- 비전투 콘텐츠 UI: **46 / 0**, 최종 실행 script error 없음.
- 카메라/화면 연출: **150 / 0**.
- 직전 전투 중 멈춤 수정: **367 / 0**.
- X11 390×844, 1280×720: 선택 상태, 획득/사용 비행, 시작/카메라/TP/승리/패배 캡처. 상태별 검증은 도메인/시계 fixture를 사용한 화면 검사이며 자연 전투 영상 전체 재현을 주장하지 않는다.
- 브라우저 실제 touch 검증 **성공**: 이어하기 → 배치 → 전투 → TP 재개 → 후퇴 → 결과 → 지도 → 가로/짧은 창 resize. console/page error 0, 결과 버튼의 색상 영역 46 CSS px, 정산 저장 phase=result 확인. `migration/impact-ui/impact-dpr3-browser-results.json`에 기록했다. 캡처/입력 DPR3, 소프트웨어 WebGL 대기 구간 DPR1이며 물리 휴대전화 성능 검사와 구분한다.
- 마지막 결과 창 겹침 수정은 overlay z-order만 바꿨으며 새 32개 검사에서 결과 창보다 낮은 z-index를 확인했다. 전체 회귀 후 변경한 이 presentation 순서에 대해 브라우저 결과 버튼 입력도 다시 확인한다.

숫자는 독립 suite 결과이며 중복 실행 횟수를 합산한 총계가 아니다. 로그/캡처/해시는 `migration/impact-ui/`에 있다. 초기 테스트 시도 중 발견된 freed prediction battle 참조와 결과 강조 겹침은 수정했고 최종 검사 결과와 구분한다.

## 보호 결과 및 MIGRATION_NOTE

`migration/impact-ui/before-hashes.json` → `hash-check.json` 비교에서 웹 dist **19/19 불변**. 변경된 기존 runtime은 위 UI/presentation 11파일뿐이다. Phase10.5 AI, 전투 스탯/Resource, Save schema 및 직전 combat_controller counter 정리 코드는 동일하다. 저장 데이터/ID/receipt/보상 계산은 변경하지 않았다.

플레이어가 기존 저장으로 이어가도 동일 도메인을 사용한다. 새 효과 상태는 transient이며 저장하지 않는다. 기존 URL의 Web export를 교체하며 공개 범위는 유지한다. 원본의 전체 연출과 픽셀 단위 동일성을 주장하지 않으며 이번 범위는 요청한 선택/재화/전투 전환/확대 구도다.

## 되돌리기

Site source의 직전 commit `5e53d3734e2860a3914272700a6856c4911b3102` 버전을 다시 배포하면 이번 수정만 되돌아가며 직전 counter-stall 수정은 유지된다. 로컬은 `migration/impact-ui/before/`의 원본 11파일을 복원하고 신규 두 presentation 클래스/uid를 제거한다. 수정된 camera reference/test는 직전 버전으로 함께 복원하고 Web export를 다시 만든다. 사용자 저장 파일은 삭제하지 않는다.

## 미리보기 배포

- URL: https://duni-arena-godot-125.kanduni.chatgpt.site
- Source: `be544dcd6644ca8ef630c3c531e7ce64be7ff0ca`
- Deployment: `appgdep_6ad2f72e983081919a18fcbb8a4184f1`, succeeded.
- Version: `appgver_3bc61e8414508191a8a4536a6f567c4a`. 기존 owner-private 범위 유지.
