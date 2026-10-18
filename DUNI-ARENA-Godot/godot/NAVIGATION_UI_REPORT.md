# 배치·유닛·방 공통 탐색 UI 수정

## 요청 반영

1. 배치: 왼쪽에 방 이름, 오른쪽에 유닛/메뉴 44×44 원형 버튼. 지도와 같은 x/y/크기/스타일. 수동 좌표와 두 줄 공백 Label로 만든 제목 배치를 없애고 HBox 행으로 정렬했다.
2. 배치의 유닛 버튼으로 연 정비 페이지: 같은 위치에 X 닫기, 그 오른쪽에 별도 메뉴. X는 Window.hide만 호출하며 기존 배치/선택/진형을 재생성하지 않는다. 정비 페이지는 전체 viewport 크기로 열어 헤더 위치를 유지한다.
3. 모집/상점/휴식/이벤트/승급: 지도 복귀 버튼은 내용 스크롤과 별개인 하단 고정 중앙 footer. 높이 48, 모바일 너비 viewport-32, PC 최대 520. 미완료 이벤트 잠금과 보물상자/휴식 등의 기존 자동 복귀 정책을 변경하지 않았다.
4. 모든 방의 오른쪽에 지도와 동일한 유닛/메뉴 버튼. 메뉴의 중복 유닛·인벤토리 항목을 제거했다. 유닛 창에서 장착/강화가 가능한지는 기존 domain 정책을 따른다. 승부예측 관전/종료 연출 중에는 탐색 버튼이 잠긴다.

## 변경 파일

- scripts/presentation/ui_style.gd: 공유 원형 nav button factory, room title formatter.
- scripts/tower_battle_screen.gd: 한 줄 헤더, 배치 메뉴, 정비 화면 라우팅. 실제 전투 중에는 기존 참가자/기록 버튼을 유지한다.
- scripts/guild_management_panel.gd: X와 메뉴 분리, 공통 헤더, 동일 viewport 슬롯. 기존 정비/장비/강화 기능 유지.
- scripts/tower_content_screen.gd: 공통 헤더와 하단 복귀, 메뉴 중복 제거.
- scripts/tower_screen.gd: 동일 factory 사용 및 메인 라우팅 연결.

## 검증

- navigation_ui_runner: 390×844 및 1000×1100, 지도/배치/정비/모집/상점/휴식/온천/보물상자/승급/승부예측 헤더 좌표 비교, 실제 터치, X 닫기, domain/RNG/배치 보존, 메뉴 항목, 하단 footer, 이벤트 잠금: 218 checks / 0 failures.
- 같은 검사를 실제 X11 창에서 실행: 218 / 0. mobile/desktop PNG는 migration/navigation-ui/.
- 기존 touch: 114 / 0; layout parity: 72 / 0 (새 X/별도 메뉴 계약에 맞게 GUI 기대값 수정).
- Phase12 UI/paired/stress: 22,692 / 0.
- save UI: 31 / 0; content UI: 46 / 0; 이전 latency: 29 / 0; Phase11 save: 643 / 0.
- 실제 Chromium mobile: 이어하기 → 배치 → 유닛 → 같은 X로 배치 복귀 → 전투 → reload/checkpoint 재개, JS/console 오류 없음.
- APK preview.3/versionCode 3: 이전과 동일한 package/signing key, ARM64 native release. signature/CRC/16KB alignment 검증 및 브라우저 실제 다운로드 SHA 비교 통과. 실제 Android 기기 설치/실행은 미확인.

## 보호 / MIGRATION_NOTE

AI, combat, UnitData, save schema/구현, 이전 background save 개선, 웹 원본 dist 19개 SHA-256 동일. 새 사운드 없음. 새 게임 규칙이나 room 보상을 만들지 않았다. UI의 Node/Window 상태는 저장하지 않는다. 소유/거래/정산은 기존 domain 경로만 사용한다.

수정 전 5개 UI script는 migration/navigation-ui/before/*.gd.txt에 보존했다. 이 사본 복원과 앱/웹 재빌드로 이번 UI 수정만 되돌릴 수 있다. Android rollback 시 삭제하지 않고 같은 key와 더 높은 versionCode로 빌드하여 저장을 유지한다.
