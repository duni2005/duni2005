# 전투 중 이동 정지 수정

## 원인

`CombatController`가 반격의 RECOVERY를 끝내며 IDLE로 전환할 때 target만 지웠다. `counter=true`와 반격 profile이 남았고, `MovementController.advance_common()`의 `if unit.combat.counter: return`이 이후 일반 이동을 계속 막았다. 적이 멀어지거나 죽으면 다음 일반 공격도 시작할 수 없어서, 적이 다시 가까이 오거나 기절 등 다른 취소가 발생하기까지 멈출 수 있었다.

원본 `dist/combat.js`의 `advanceAttack`은 recovery 종료 시 `u.attack=null`로 공격 전체를 해제한다. 실제 JS reference harness에서도 반격 windup→active→recovery→idle과 attack=null, 유한 좌표를 확인했다(`migration/unit-stall/web-reference.json`).

## 수정

수정한 실제 게임 파일은 **scripts/combat_controller.gd 한 개**다. `after_recovery()`가 다음 연타 WINDUP을 만들지 않았고 실제 IDLE이면 기존 `cancel(unit)`으로 공격을 완전히 정리한다. counter/profile/target/metadata가 해제되고 일반 이동/추적이 다시 가능해진다. cooldown, 공격 serial·횟수는 유지한다. 연타 중간에는 정리하지 않는다.

AI 관찰·망설임·commit, 기절, TP 정지, 공격 준비/회복 시간, 패링 수치와 캐릭터·장비·타워 스탯은 변경하지 않았다. 정상적인 대기까지 없애는 수정이 아니다. counter는 전투 transient라 저장 schema나 기존 저장을 변경할 필요가 없다.

## 재현과 결과

기존 코드: 신규 재현 363검사 중 26실패. 수정 후: 실제 패링 적중 경로까지 추가한 **367검사 / 0실패**.

| 자연 전투 seed | 수정 전 최장 잘못된 반격 잔류 | 수정 후 |
|---|---:|---:|
|17|18.07 simulation seconds|0|
|73|18.42|0|
|101|24.38|0|

기본 3vs3 구성을 40초까지 실제 simulation으로 계측했다. 값은 살아 있고 기절·특수행동 중이 아닌 IDLE 유닛에 반격 상태가 남아 일반 이동이 잠긴 연속 시간이다. 외부 넉백까지 전혀 없었다는 뜻은 아니다. 수정 후 세 전투 모두 정상 종료됐다. 같은 seed라도 정상 추적/공격이 복구되므로 이후 RNG 소비와 전투 결과는 달라질 수 있다.

신규 검사는 대상 도주/사망 후 재추적과 재공격, 30/60/120fps, 공통 모드, UFC/검객 3연타 중간 단계 보존, TP 동결, stun 취소, 실제 DamageResolver→패링→반격→일반 공격 복귀를 포함한다. 전체 로그와 before/after 계측은 `migration/unit-stall/`에 보관한다.

## 보호·배포

작업 전후 해시에서 기존 실제 소스 변경은 combat_controller.gd만 확인했다. 웹 원본19파일, AI 정책 파일, 정적 스탯, Save serializer/schema v1은 변경하지 않았다. 기존 URL과 브라우저 저장소를 유지해 Sites로 같은 audience에 업데이트한다. 사운드를 추가하지 않는다.

## MIGRATION_NOTE / 되돌리기

이 수정은 반격 중 이동 금지를 제거하지 않는다. 공격이 실제로 끝났을 때만 잠금을 해제한다. `after_recovery`가 다음 연타를 예약한 경우도 보존한다. 이전 코드는 `migration/unit-stall/combat_controller.before.txt`에 보관했으며, 이 파일만 되돌리고 웹을 다시 export하면 이번 동작 수정만 취소된다. 이전 Sites source commit은 `98fbc14f4418a683d0c75fd2330946f14e6dd87d`다. 사용자 save를 삭제하지 않는다.

## 최종 검증·배포 결과

- Godot 4.6.3 editor import / Web export 성공.
- 전체 Phase1~12.5: **120,324검사 / 0실패**.
- 신규 멈춤 회귀: **367검사 / 0실패** (`godot --headless --path godot --script res://tests/unit_stall_runner.gd`).
- 기존 공통 전투 UI 입력: **25검사 / 0실패**.
- 390×844 / DPR3 Chromium: Continue→배치→전투 시작→전투 관전 통과. console/page error 0. 이는 Web 부팅·입력 smoke이며 반격 lifecycle의 직접 검증은 신규 자동 검사와 실제 simulation seed 계측으로 구분한다.
- 12vs12 VFX ON/OFF paired 900tick: HP·위치·공격상태·RNG 일치, 누수/상한 검사 통과.
- 같은 미리보기 URL에 배포 성공. source commit `5e53d3734e2860a3914272700a6856c4911b3102`, PCK SHA-256 `c7c521f3f3a3aec6707ab7aac6f96193eb61a4510946a2c400212dfc70189128`.
- URL: https://duni-arena-godot-125.kanduni.chatgpt.site . 기존 owner-private audience / 브라우저 저장소 유지. deployment/version 원문은 `migration/unit-stall/deployment.json` 참조.
