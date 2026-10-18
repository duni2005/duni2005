# 터치·전투 전환 지연 수정

주요 원인은 메인 스레드의 전체 런 저장과 반복 검증, 입장 때의 숨은 UI 생성, 지도 복귀 시 120개 버튼 재생성이었다. APK 설치 자체로 이 병목이 없어지지는 않는다.

## 측정

Godot 4.6.3 Linux headless, seed 19/73, 같은 120방 런과 배치. 아래 수치는 실제 휴대폰 FPS/터치 지연이 아닌 해당 함수의 벽시계 실행 시간이다. `migration/latency-fix/{before,after}-profile.json`에 원자료가 있다. 반복 측정 항목은 중앙값이며 단일 전환 항목은 한 실행값이다.

| 구간 | 수정 전 ms | 수정 후 ms |
| --- | ---: | ---: |
| request_autosave | 68.724 | 15.542 |
| flush_autosave | 267.154 | 71.033 |
| deployment_build | 279.137 | 155.675 |
| deployment_build_warm | 191.031 | 93.008 |
| battle_start | 405.239 | 123.171 |
| settle_retreat | 75.326 | 19.804 |
| result_autosave | 268.537 | 81.995 |

Native 실전 메뉴는 비동기 저장을 사용한다. 캡처는 main thread에서 transaction 직후 pure Dictionary로 복사하고, validation/JSON/file/backup 처리는 한 개의 worker에서 수행한다. pending 문서는 최대 한 개로 최신 상태를 보존한다. worker는 Scene/UI/AI 객체를 받지 않는다. 결과 알림은 main thread에서만 발생한다. 동기 API는 command-line 도구와 명시적 flush barrier로 남아 있고, 테스트용 타입/캐릭터 분기는 없다.

싱글스레드 Web export는 Thread를 사용하지 않는다. Web에서도 중복 validation 제거, compact JSON, 이전 정상 파일의 exact-byte verification cache, UI 재사용은 적용된다. Web의 실제 파일 저장 경로는 여전히 동기이며 기기별 잔여 지연을 없앴다고 주장하지 않는다.

## 변경

- SaveSnapshotBuilder: capture와 strict validation 분리. public build/snapshot은 기존 전체 validation 계약을 유지한다.
- SaveManager: detached capture, coalesced background writer, compact v1 JSON, atomic temp reparse/byte verification, 검증된 이전 원문으로 backup 생성. 외부 read/load는 계속 전체 validation을 거친다. manual/close/CLI flush는 worker 완료를 기다리는 barrier다.
- TowerController / TowerBattleScreen: async checkpoint가 성공한 뒤 실제 전투 시작. 저장 실패 시 seed rollback, 전투 미시작. 준비 표시와 입력 잠금, 중복 launch 거부. 동기 start API는 유지한다.
- TowerBattleScreen: 정비 페이지를 처음 열 때 생성. 실제 시작을 알리는 presentation signal로 GUI smoke의 합성 마우스 이벤트 경쟁도 제거했다.
- TowerScreen: 같은 run의 map/floor/button Node 재사용. 상태·선택·숨김·해금은 domain으로부터 갱신한다. 새 런은 새 map controls를 만든다.
- WalletBar / deployment tools: 숨은/정적인 상태의 반복 redraw와 style override를 줄였다.
- MainMenu: 실제 플레이의 SaveManager를 background 모드로 생성한다.

## 안전성과 경계

전투 결과와 rewards는 기존 settlement 완료 후 캡처한다. 정산/구매/보상 재실행 없음. 체크포인트를 디스크에 commit하기 전에는 simulation이 시작되지 않는다. schema_version=1, save 경로/user-dir/ID/receipt/RNG 포맷은 그대로다. 카메라·TP·3.6초 종료 연출·AI·전투 수치·사운드는 변경하지 않았다. 종료 연출 자체의 대기와 처리 정지는 구별한다.

백업은 이전 정상 파일만 보존한다. 이미 검증한 정확히 같은 원문만 재검증을 생략하며 바이트가 다르면 다시 strict validation한다. tmp parse/byte verification 실패 시 교체하지 않는다. 메인 루프가 돌아가는 동안 worker completion을 poll하고 새 요청은 단일 pending 문서로 합친다.

## 검증

- Phase 1~12.5 통합: 120,324 checks / 0 failures (AI golden, save v1, paired presentation, 26종, tower/content 포함).
- 신규 latency: 29 checks / 0 failures. Worker 중 main-loop heartbeat, coalescing, detached snapshot, backup, invalid tmp/document, durable checkpoint, 중복 start, retry, result receipt, map Node reuse, lazy management, 실제 UI start.
- X11 실제 창에서도 초기 27개 latency 검사를 실행: 27 / 0. 추가 2개는 실패한 async checkpoint의 seed rollback/전투 차단을 headless에서 검증했다.
- Touch UI: headless 114 / 0, X11 114 / 0 (모바일 390×844 및 PC).
- Save GUI smoke: 31 / 0. 테스트의 start freeze는 synthesized mouse가 아니라 실제 launch signal을 관찰한다.
- 서로 다른 Godot process의 checkpoint write 3 / 0, read/retry 6 / 0.
- 실제 Chromium 모바일 WebGL: continue → 배치 → 전투 → IndexedDB checkpoint → reload → 같은 배치 복구, JS/console errors 없음.
- 실제 모바일 브라우저 APK 다운로드: SHA 일치, double tap 한 파일만, 손상 chunk 차단.
- APK: signature v2/v3, ARM64 release engine, 16KB alignment, CRC, manifest/API24, 권한/개인키 제외 확인. 실기기 Android 실행·FPS는 미확인.

수정 전후 source hash 비교는 migration/latency-fix/hash-verification.json. 원본 dist 19개, AI/이동/타겟/위험평가, combat manager/damage, 모든 UnitData, save schema codec/validator/migrator는 동일하다. 저장 실행 구현만 의도적으로 변경했다.

## 배포 / 업데이트

Android preview.2 / versionCode 2 / com.duniarena.preview. 기존 preview.1과 같은 서명이므로 삭제 없이 업데이트할 수 있다. 웹 저장과 Android 저장은 서로 다르다. 업데이트 APK SHA-256: 77a921e77d3b0a334aa7d2b8a9ead65b56be7dae9ff1ff206dd5753419eeb5ea.

## MIGRATION_NOTE / rollback

새 콘텐츠나 schema migration 없음. 수정한 8개 production script의 작업 전 사본은 migration/latency-fix/before에 있다. 해당 사본 복원 후 테스트/재빌드하면 이 수정만 되돌릴 수 있다. APK rollback도 기존 앱을 삭제하지 않고 같은 signing key와 더 높은 versionCode로 다시 빌드한다. 새 tests/latency_runner.gd와 latency_profile.gd는 검증 전용이다. Web transport/다운로드 전달 계층은 game rules와 독립이다.

남은 한계: 느린 모바일 GPU/CPU와 4x 다수 유닛의 전체 frame 비용, Android의 실제 터치-to-photon 시간은 실기기 profiler가 필요하다. 이 작업의 headless/X11/SwiftShader 결과를 Android 실측치로 보지 않는다.
