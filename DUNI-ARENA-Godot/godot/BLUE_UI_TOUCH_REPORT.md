# 저채도 블루 UI·모바일 입력·배치 도구 정리

## 요청 반영

- 터닝포인트: 기존 2초 카메라 축소와 동시에 시계판·한 줄 제목이 페이드 인한다. 정지까지 제목을 기다리지 않는다. **전투 재개 시 배너/설명 문구는 표시하지 않는다.** TP 버튼과 2초 감속/40초 대기 규칙은 유지한다.
- 공통 Theme/카드/지갑/상점/이벤트/결과/전장 배경을 저채도 블루·슬레이트로 정리했다. 재화는 절제한 금색, 위험 상태는 붉은색으로 구분한다.
- 구매 불가·사망·사용 불가·후퇴는 붉은 테두리/배경/텍스트로 표현한다. 선택된 사망 카드도 별도 밝은 테두리로 구분한다.
- 버튼은 아래쪽 테두리·그림자·눌림 색을 공유한다. 전투 시작은 화면 중앙의 넓은 CTA로 배치한다.
- 배치 도구 팝업 대신 **실행 취소 / 다시 실행 / 지우개 / 모두 지우기** 네 개의 44×44 버튼을 제공한다. 지우개는 배치된 유닛을 눌러 해제하는 모드다. 드래그 한 번을 한 변경으로 기록하며 취소/재실행 기록은 최대 64개다.
- 배치 카드는 116×146에서 **88×122**로 축소했다. 390px 화면에서 기본 4명이 한 줄에 보인다.
- 정비는 지도와 동일한 원형 유닛 버튼이며, 유닛 탭으로 열린다.
- 길드·인벤토리·배치·TP·전투 파티·승급·부활 카드에 개별 HP/기력/장착 아이템 정보를 표시한다. 같은 type도 member ID로 각각 읽는다. TP 회복 직후 카드 HP도 갱신한다.

## 터치 수정

`ArenaUI.bind`가 각 터치의 소유권을 관리한다. 손가락을 떼는 입력에서 직접 한 번 실행하고, Godot이 함께 만드는 합성 마우스 입력은 재실행하지 않는다. 긴 터치나 느린 프레임에서도 중복 방지가 풀리지 않도록 시간 제한 대신 제스처 소유 상태를 사용한다. 실제 마우스·키보드 입력은 별도로 처리한다.

손가락 흔들림은 18 논리 픽셀까지 허용한다. 버튼이 있는 ScrollContainer도 같은 기준의 deadzone을 사용한다. 실제 스크롤 이동·큰 드래그·취소·다른 손가락의 release는 버튼 실행으로 처리하지 않는다. 같은 느린 프레임에 도착한 별개의 탭은 각각 인정한다. 배치 목록은 선택·드래그마다 삭제/재생성하지 않고 기존 카드를 갱신하여 터치 대상을 유지한다.

웹 export는 Godot 4.6.3의 공통 화면 배율 함수에 **최대 2× backing buffer**를 적용한다. DPR 3 기기의 픽셀 렌더링 양은 기존 대비 4/9이며, CSS 화면 크기와 입력 위치는 그대로다. `window.devicePixelRatio`를 속이거나 터치 좌표를 따로 곱하지 않는다. 다음 엔진 버전에서 적용 위치가 바뀌면 build가 명시적으로 실패하도록 검사한다. 실제 기기 FPS가 55.6% 개선된다는 주장은 하지 않는다.

## 주요 파일

- `presentation/ui_style.gd`: 색/버튼 스타일, 공통 터치/스크롤 처리.
- `presentation/arena_card.gd`: 개별 길드원 정보와 장비 슬롯 표현.
- `deployment_screen.gd`, `deployment_board.gd`: 작은 도구·카드와 순수 UI draft history.
- `room_battle_screen.gd`, `tower_battle_screen.gd`: CTA·정비·후퇴/파티 표시.
- `turning_point_panel.gd`, `presentation/battle_cue_overlay.gd`, `presentation/cinematic_artwork.gd`: TP 입력·HP 갱신·동시 연출·재개 문구 제거.
- `guild_management_panel.gd`, `tower_content_screen.gd`: 유닛/인벤토리/승급/부활 표시.
- `presentation/wallet_bar.gd`, `visual_shapes.gd`, `tower_scene_surface.gd`, `main_menu_screen.gd`, `tower_screen.gd`: 블루 계열 화면 통일.
- 신규 도구 SVG 4종, HP 하트 아이콘 색 수정.
- `firebase/build_web.py`: export 화면 배율 상한. 원본 `dist/`는 수정하지 않는다.

## 검증 자료

`migration/blue-touch/`에 로그와 PC/모바일 캡처를 기록했다.

- 전체 회귀: **120,324 검사 / 실패 0**. AI Golden, 저장 round-trip, 전투 presentation ON/OFF 비교 포함.
- 최종 X11 입력·레이아웃 검사: **114 검사 / 실패 0**. 390×844 및 1000×1100. 작은 흔들림, 긴 누름, 빠른 별개 탭, 합성 마우스, 다른 손가락, 취소, 스크롤, 배치 undo/redo/지우개/전체 초기화, 인벤토리 정보, TP 중 회복과 재개를 검사했다.
- 마지막 입력 보완 후 Phase 12 재검사: **22,692 검사 / 실패 0**. 추가 UI 회귀 묶음은 **1,029 검사 / 실패 0**. `phase12-final.log`, `final-ui-results.json` 참고.
- 최종 웹 경로: **성공, console/page 오류 0**. CSS 390×844 / 실제 DPR 3에서 backing buffer 780×1688, 입력 위치와 지도 복귀를 확인했다. `browser-verified.log`, `blue-dpr3-browser-results.json` 참고.
- 원본 웹 **19개 SHA-256 일치**, AI·전투 규칙·타워 진행·저장·정적 전투 데이터 등 보호 대상 **62개 파일 해시 일치**. `hash-check.json` 참고.
- 배포 PCK SHA-256: `5d6cf01c121cd293a8ce542913c9787d41355a9adef26a2be72f3a5734ad6fd5`.

X11과 Chromium의 소프트웨어 렌더러에서 검사했다. 물리적인 Android/iPhone을 조작한 결과는 아니다. 웹 검사는 CSS 390×844/DPR 3에서 입력·캡처하고, VM의 전투 대기는 DPR 1로 진행하므로 실제 휴대전화 성능 벤치마크로 사용하지 않는다.

## MIGRATION_NOTE / 되돌리기

AI/전투 수치, 저장 schema v1, `DUNI_ARENA` 저장 경로, 영수증, 전투 checkpoint/정산 순서는 바꾸지 않았다. undo/redo·입력 상태·카메라/연출 상태는 저장 대상이 아니다. 장착 아이템의 소유권이나 UnitData도 수정하지 않는다. 사운드 작업은 없다.

이번 변경 이전 배포 소스는 `32bc23beb96d16d6184c20778d3ec3ba64737da8`이다. 해당 버전으로 배포를 되돌리거나 `migration/blue-touch/before/`의 UI 스크립트를 복원하고 신규 도구 SVG와 export 배율 hook을 제거한 뒤 다시 build한다. 이전 종료 연출과 이벤트/전투 수정은 유지한다.

기존 미리보기 `https://duni-arena-godot-125.kanduni.chatgpt.site`에 배포 완료했다. 소스 commit `a61774557407ece35907707a9426ab6b331a38fb`, 배포 ID `appgdep_6ad3487f839c81918ed0b458fac8779c`. 기존 owner-private 접근 범위를 유지했다. 상세는 `migration/blue-touch/deployment.json`.
