# 카메라와 그리드 좌표 동기화

원인은 직전 수정에서 빈 배경을 막기 위해 `VisualShapes.arena()` 전체를 화면 좌표로 그린 것이었다. 캐릭터에는 카메라가 적용됐지만 그리드/벽/중앙 표식에는 확대·이동이 적용되지 않았다. HTML `drawCombat()`은 카메라 적용 후 배경·그리드·유닛을 같은 좌표에서 그린다.

이번에는 화면 좌표에 단색 바탕만 채우고, 실제 전장 전체는 캐릭터·공격·장판과 같은 `parent_transform`으로 그린다. 확대, pan, shake, TP와 종료 시 overview에서 모두 같은 변환을 사용한다. 카메라가 전장 가장자리를 넘어 비추면 단색 바탕이 빈 부분을 채운다. 카메라 확대 배율/추적 수치, 입력 역변환, AI, 전투 좌표, 타이머와 저장 규칙은 변경하지 않았다.

변경된 production 파일은 `scripts/presentation/combat_presentation.gd` 하나다. `migration/camera-grid/before-hashes.json`, `after-hashes.json`, `hash-verification.json`에 웹 원본 19개 및 AI/스탯/save/input/카메라 상수의 무변경을 기록했다.

검증:

- X11 실제 framebuffer: **18 검사 / 실패 0**. 그리드 선의 실제 픽셀 위치를 zoom 1.0/1.6/2.2 및 pan/shake에서 검사했다. TP/종료 overview 중 그리드 위치, 전장 밖 바탕, 확대 후 실제 유닛 터치 선택, 390×844 좌표 변환을 포함한다.
- 표현 ON/OFF paired simulation 및 12vs12/정리: **22,865 검사 / 실패 0**.
- 기존 touch/스크롤/첫 탭/중복 입력 검사: **114 검사 / 실패 0**.
- TP·승리·패배·후퇴 연출 회귀: **140 검사 / 실패 0**.
- Web export는 동일 소스의 Godot 4.6.3 빌드다. 모바일 브라우저 smoke는 `browser.log`, `grid-dpr3-browser-results.json`에 기록한다. VM의 에뮬레이션이며 실물 휴대폰 성능 검증은 아니다.

## 터치 지연과 APK

현재 버튼 경로는 유효한 touch release에서 즉시 action을 호출한다. 고정된 대기 timer, 300ms 지연 또는 비동기 네트워크 응답을 기다리는 처리는 없다. Web shell은 이미 `touch-action:none`을 사용한다. 이것으로 실기기에서 발생한 지연의 원인을 확정할 수는 없다. 메인 루프가 느려지면 입력을 처리하고 결과를 표시하는 시점도 늦어질 수 있다.

Godot 네이티브 Android APK는 브라우저/WASM 경유 부담이 줄어 개선될 가능성이 있다. WebView로 웹판을 감싼 APK나 단순 홈 화면 설치는 같은 의미가 아니다. 공통 GDScript 연산·UI 갱신·VFX/렌더링 부하는 네이티브 APK에도 남는다. 같은 휴대폰에서 네이티브 release APK와 Web의 frame time·입력 지연을 비교하기 전에는 해결을 보장하지 않는다. 이번 작업에서 Android 실기기나 APK 성능을 측정했다고 주장하지 않는다.

## MIGRATION_NOTE / 되돌리기

save schema v1과 모든 지속 데이터는 그대로다. 이번 renderer 수정만 되돌리려면 `migration/camera-grid/combat_presentation-before.gd.txt`를 해당 스크립트로 복원하고 Web export한다. 직전 Site commit은 `12e90e174c04de44f4d20ad403e6e674af9b368d`다. 테스트/캡처는 게임 export에 포함되지 않는다. 사운드 작업은 없다.
