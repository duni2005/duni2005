# DUNI ARENA — Godot 이전 프로젝트

현재 단계는 **Phase12.5 비주얼 비교·표현 계층 재작업**입니다. F5는 새 게임/이어하기에서 시작합니다. 지도·길드·상점·모집·배치·TP를 카드 UI로 정리하고, 26종 픽셀 초상·원본 무기 pose·particle·카메라 표현을 연결했습니다. 개발 정보는 기본 OFF입니다. Phase10.5 AI와 Phase11 저장 v1 계약을 유지하며, **사운드는 추가하지 않았습니다.** 원본의 모든 특수 pose/particle을1:1로 복제한 단계는 아니며 남은 차이를 보고서에 기록했습니다.

[Phase12.5 보고서](PHASE125_REPORT.md) · [HTML / Godot 이전 / 이후 화면 비교](migration/phase125/comparisons/index.html) · [실제 전투 event 비교](migration/phase125/comparisons/duel-index.html).

[Phase12 완료 보고](PHASE12_REPORT.md) · [변경 전 UI 조사](PHASE12_UI_AUDIT.md). 신규 UI 검사는 `godot --path godot --script res://tests/phase12_ui_smoke.gd`로 실행할 수 있습니다. 기존 전체 검사는 `godot --headless --path godot --script res://tests/test_runner.gd`입니다.

전체 타워 런은 `user://saves/autosave.json`에 저장하며, 전투 중 종료하면 마지막 전투 시작 전 배치 checkpoint로 돌아갑니다. 전투 중 수동 저장은 허용하지 않습니다.

[Phase11 완료 보고](PHASE11_REPORT.md) · [고정 v1 저장 예시](tests/fixtures/save_v1.json). 기존 `scenes/tower.tscn`과 독립 전투 검사 씬도 유지됩니다. 정식 단일 저장과 테스트 저장 경로는 분리되어 있습니다.

[Phase10.5 보고](PHASE105_REPORT.md) · [실제 HTML/Godot 수치 비교](migration/phase105-comparison-tables.md) · [이동 궤적](migration/phase105-trajectories.png). RNG가 다른 일반 전투의 모든 지표가 개선된 것은 아니며, 남은 차이를 보고서에 기록했습니다.

[Phase10 완료 보고](PHASE10_REPORT.md) · [Phase9 완료 보고](PHASE9_REPORT.md) · [Phase8 완료 보고](PHASE8_REPORT.md) · [Phase7 보고](PHASE7_REPORT.md). 아래 과거 설명은 당시 단계 기록입니다.

# DUNI ARENA — Godot 이전 프로젝트

> 현재 F5 시작 화면은 Phase 7의 공통 전투·터닝포인트·전략카드·지속 전투 테스트 방입니다. 최신 구조·규칙·검증·복구 방법은 [Phase 7 완료 보고](PHASE7_REPORT.md)를 확인하세요. F5는 새 공통 전투 모드, Phase 1 독립 씬과 기존 수치 검사는 최소 비교 모드입니다. [Phase 6](PHASE6_REPORT.md)과 이전 보고서/검사도 보존했습니다. 아래 본문은 Phase 1의 역사 기록입니다.

이 폴더는 웹 원본과 독립적인 Godot 4.x 프로젝트입니다. 구현 범위는 **전사·궁수 최소 자동전투**입니다. 다음 Phase는 시작하지 않았습니다. 검증 엔진은 **Godot 4.6.3 stable**이며 다른 4.x 버전에서 실행했다고 주장하지 않습니다.

## 기준과 조사

- 저장소 기준: `bb9b22d`의 `dist/` 실행 코드, v83. 기존 웹 파일을 수정하지 않았습니다.
- `https://duniarena.site/#tower`의 타워 입장, 지도와 3 대 3 전투 화면을 Playwright로 확인했습니다. 브라우저의 프록시 CA 문제 때문에, HTTPS 검증을 유지한 `curl`로 받은 배포 응답을 브라우저 요청에 공급했습니다. 로그인이나 배포 설정은 변경하지 않았습니다.
- 배포된 `app.js?v=83`, `combat.js?v=83`는 현재 저장소 파일과 바이트 단위로 일치했습니다. 전사·궁수 런타임 데이터와 공격 프로필도 일치했습니다.
- 정적 화면에는 **13종 캐릭터**가 남아 있지만 실제 `TYPES`는 **26종**입니다. 표시 문구를 규칙으로 사용하거나 원본을 수정하지 않았습니다.
- 아래 사거리 차이는 원본 자체의 동작입니다. 하나의 값으로 통합하지 않았습니다.

## 생성 파일과 역할

| 파일 | 역할 |
| --- | --- |
| `project.godot` | 독립 프로젝트, 메인 씬, 60 Hz, 화면 스케일 설정 |
| `.gitignore` | 재생성 가능한 `.godot/` 캐시 제외 |
| `scenes/battle.tscn` | 800×800 전투장과 최소 디버그 HUD |
| `scenes/unit.tscn` | Node2D 유닛 인스턴스 |
| `scenes/projectile.tscn` | 명시적으로 이동·충돌 판정하는 화살 |
| `data/warrior.tres`, `data/archer.tres` | 원본 수치와 기본 공격 프로필 Resource |
| `scripts/unit_data.gd` | 공유하는 종류별 불변 데이터 정의 |
| `scripts/attack_data.gd` | 공격 방식, 단계 시간, 실제 도달 거리와 화살 데이터 |
| `scripts/unit.gd` | `BattleUnit`: 고유 battle_id, 팀, HP, 위치, 속도, 타겟, 생존·공격 상태 연결 |
| `scripts/target_selector.gd` | 살아 있는 가장 가까운 적 선택; 이동과 분리된 정책 |
| `scripts/movement_controller.gd` | 접근 판단, 명시적 위치 계산, 경계 제한 |
| `scripts/combat_controller.gd` | IDLE/WINDUP/ACTIVE/RECOVERY, 조준, 공격 개시와 근접 참격 |
| `scripts/damage_resolver.gd` | 유효성 검사 → 치명타 → 반올림 → HP 감소 → 사망 |
| `scripts/projectile.gd` | 유한 수명, 비유도 화살, 연속 경로의 최초 적중 시각 계산 |
| `scripts/battle_clock.gd` | simulation_delta와 경과 시간 제공; 현재 1× |
| `scripts/battle_manager.gd` | 배치 데이터에서 생성, 틱 진행, 공격 판정, 진영 판정, 단 한 번 종료 |
| `scripts/battle_result.gd` | 런과 분리된 최종 전투 결과와 유닛 스냅샷 |
| `scripts/battle_view.gd` | 전투 규칙을 변경하지 않는 HUD 표시 |
| `tests/test_runner.gd` | 실제 씬·Resource·규칙을 사용하는 headless 자동 테스트 |
| `README.md` | 이 완료 보고, MIGRATION_NOTE, 실행 및 되돌리기 방법 |

각 GDScript의 `.gd.uid` 13개는 Godot가 생성한 식별 파일입니다. 소스와 함께 유지합니다. `.godot/`는 프로젝트 소스가 아니며 Git에서 제외됩니다. 웹 파일은 생성·수정하지 않았습니다.

## 참조한 실제 수치

출처: `dist/app.js`의 `TYPES[0]`, `TYPES[1]`, `setupUnits()`; `dist/combat.js`의 `ATTACK_PROFILES`, `startAttack()`, `canStartAttack()`, `advanceAttack()`, `aimDirection()`, `spawnProjectile()`.

| 종류 | ID | 최대 HP | 공격력 | 기본 이동속도 | TYPES.range | TYPES.cd | 치명타 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 전사 | 0 | 150 | 16 | 96 | 62 | 1.0초 | 22% |
| 궁수 | 1 | 105 | 15 | 92 | 380 | 0.75초 | 20% |

| 종류 | WINDUP | ACTIVE | RECOVERY | 실제 reach | 공격 개시 거리 | cone |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 전사 | 0.38초 | 0.17초 | 0.25초 | 108 | **97.2 미만** (=108×0.9) | 1.45 rad |
| 궁수 | 0.43초 | 0.14초 | 0.22초 | 410 | **410 미만** | 0.35 rad |

`UnitData.attack_range`에는 원본 TYPES 값을 저장하고, 실제 공격 개시와 접근 종료에는 `AttackData.start_distance()`를 사용합니다. **62/380을 넘었다는 이유로 원본 공격 개시를 막으면 원본의 동작이 바뀝니다.** 자동 테스트의 사거리 검사는 원본의 실제 개시 기준을 확인합니다. 근접 공격 적중에는 추가로 원본 몸체 반경 27을 사용하는 칼날-몸체 거리 판정이 있습니다. 이미 발사된 화살은 개시 거리 밖에서도 적중할 수 있습니다.

보존한 추가 계산:

- 생성 시 개별 이동속도: 기본 속도 × `random(0.93, 1.07)`.
- 최초 쿨타임: `random(0.2, 1.0)`초.
- 공격 개시 시 쿨타임: `windup + active + recovery + TYPES.cd × random(0.3, 0.55)`. 준비 단계부터 감소하므로 `cd`를 전체 공격 주기로 해석하지 않았습니다.
- 단계 전환 시 이전 단계의 초과 시간을 버리는 현재 `advanceAttack()` 동작을 유지했습니다.
- WINDUP 시간의 앞 65% 동안 타겟을 재조준하고, `min(1, dt×5)`로 각도를 보간합니다.
- 궁수 조준 예측: 현재 타겟 속도 × 비행 예상시간 × 0.55.
- 화살: 속도 470, 발사 위치 오프셋 32, 탄퍼짐 ±0.025 rad, 수명 2.4초. 기본 적중 반경은 26입니다. 몸체 반경 27을 더해 53으로 바꾸지 않았습니다.
- 치명타 **1.5배**: `dist/ultimate.js`의 `criticalChance()`와 `attackHit()`에서 재확인. 일반 피해는 양의 수를 반올림하며, 예를 들어 궁수 치명타는 `15×1.5=22.5 → 23`입니다.
- 일반 이동 경계 28~772, 화살 소멸 경계 20~780. Godot 배치 입력은 이번 단계의 안전한 논리 경계 28~772로 제한합니다.

## 구현한 전투 흐름

기본 배치는 블루 전사 2·궁수 1, 레드 전사 2·궁수 1입니다. 초기 위치는 테스트용 배치이며 원본 규칙 수치를 새로 정한 것이 아닙니다.

1. 배치 목록의 Resource 참조·팀·좌표로 고유 battle_id를 가진 유닛을 생성합니다.
2. 살아 있는 가장 가까운 적을 탐색합니다. 타겟 사망 시 다음 틱에 재탐색합니다.
3. 개시 거리 밖이면 접근하고, 범위 안이며 쿨타임과 공격 상태가 허용하면 WINDUP에 들어갑니다.
4. 준비가 끝나면 전사는 회전하는 칼날, 궁수는 비유도 화살을 발동합니다.
5. 접촉 시각순으로 피해를 적용하고 RECOVERY를 거쳐 다시 판단합니다.
6. HP 0은 사망이며 화면에서 사라집니다. 사망한 개체는 결과 확인을 위해 목록에 남지만 AI·이동·공격은 진행하지 않습니다.
7. 한 틱의 모든 피해 처리 후 생존 팀이 하나면 승리, 없으면 무승부입니다.
8. 종료 시 공격·화살을 한 번 정리하고 `BattleResult`와 `battle_finished`를 한 번 생성합니다. 이후 공격·피해·AI·전투 시간은 진행하지 않습니다.

`UnitData`와 `AttackData`는 런타임에서 수정하지 않습니다. 각 유닛의 HP, 이동속도 무작위 보정, 타겟, 공격 상태, 쿨타임, 참격 적중 기록은 개별 인스턴스에만 있습니다. 테스트도 같은 Resource를 쓰는 전사들의 상태가 독립적인지 확인합니다. Resource의 에디터 편집 기능 자체를 잠그는 시스템은 만들지 않았습니다.

## MIGRATION_NOTE — 의도적인 범위 차이와 주의점

- **AI:** 이번 단계는 가장 가까운 적 접근·공격만 구현했습니다. 웹 `createBrain()`의 대치, 기회 포착, 후열 유지, 측면 이동, 위험/안전 구역과 회피는 제외했습니다. 궁수는 적을 피해 거리를 다시 벌리지 않습니다. 현재 결과를 웹 전체 밸런스나 승률과 동일하다고 볼 수 없습니다.
- **이동:** Node2D의 좌표를 직접 갱신합니다. 공격 도중 일반 이동은 정지합니다. 웹은 공격 중에도 축소된 이동, 관성 및 넉백을 사용할 수 있습니다. 웹 최초 유효 배치의 40~760 제한, 무작위 배치 생성과 초기 겹침 해소도 복제하지 않았습니다.
- **패시브:** 전사의 패링 반격, 궁수 3번째 부채 사격·벽 2회 도탄은 이번 최소 기본 공격에서 제외했습니다. 원본 수치 변경이나 패시브 삭제가 아닙니다.
- **방어:** “웹 버전에서는 기본 방어력이 일반 피해 감소에 직접 사용되지 않는 현재 동작이 존재한다. 방어 시스템 이전 단계에서 실제 기존 동작 보존 여부를 별도로 결정한다.” 원본 `combatArmor()`는 기본 방어력을 차감한 추가분을 사용합니다. 방어력 26/18을 임의로 피해 감소에 적용하지 않았습니다.
- **피해:** 패링·보호막·반사·피해 분담·구조·무적·수비 성향·피로·오라·상태이상·넉백·상쇄를 제외했습니다. 원본의 60초 이후 피해 증가 `1 + max(0, elapsed-60)/70`도 이번 일반 피해 파이프라인에는 넣지 않았습니다. 향후 이전 시 명시적으로 다시 검토해야 합니다. 현재 DamageResolver의 반환값과 signal amount는 실제 HP 손실량으로, 웹의 오버킬을 포함하는 `damage: amount` 반환과 다릅니다. 궁극기 충전·통계 이전 시 두 값의 구분이 필요합니다.
- **물리 공격:** 원본 칼날은 25→108 길이의 선분이 cone에 따라 회전하며 한 적에 한 번 적중합니다. 1/120초 이하 공격 슬라이스와 5개 접촉 표본을 사용했습니다. 궁수는 정해진 타겟에게 확정 피해를 주지 않으며 경로에서 먼저 만난 적을 맞힙니다.
- **빠른 투사체:** 프레임 양 끝 위치만 검사하면 통과 문제가 생깁니다. 현재는 이동 구간의 원-선분 접촉 시각을 계산합니다. 향후 관통·도탄·투사체 상쇄·근접 상쇄를 추가할 때도 공동 접촉 시각 정렬을 유지해야 합니다. Godot 물리 signal만으로 교체하지 않습니다. 이번 슬라이스 안의 적 위치는 원본처럼 이동 처리 후의 고정 위치로 검사합니다.
- **사망과 동시 판정:** 발사된 화살은 발사자가 죽어도 적중할 수 있습니다. 사망한 시전자의 근접 공격은 피해를 주지 않습니다. 같은 틱의 투사체로 양쪽 마지막 유닛이 죽으면 무승부가 가능합니다. 순차 접촉 처리의 근접 동시 타격 결과를 임의로 바꾸지 않았습니다.
- **타겟:** 웹처럼 준비 중 타겟 사망이 공격 자체를 무조건 취소하지는 않습니다. 기존 조준 방향으로 발동해 빗나갈 수 있고, 유닛의 현재 탐색 타겟은 별도로 갱신됩니다.
- **시간:** 현재는 1× 고정 60 Hz입니다. 배속·히트스톱·터닝포인트·초월·종료 감속은 제외했습니다. `BattleClock.simulation_delta`를 사용하며 `Engine.time_scale`을 변경하지 않습니다. 향후 UI 시간과 전투 시간을 분리할 지점이 마련돼 있습니다.
- **종료와 런:** `BattleResult`는 전투 결과일 뿐 런 게임오버가 아닙니다. player HP나 길드 생존 여부를 판단하는 코드가 없습니다. 다음 단계는 외부 길드원 ID와 battle_id 매핑, 초기 상태 주입 및 결과 상태 회수를 추가할 수 있습니다. 후퇴·적 상태 유지도 현재 UnitData 공유 상태에 의존하지 않습니다.
- **팀:** 이번 테스트는 정수 팀을 사용합니다. 웹의 개인전 `solo:id` 진영 규칙과 별도 배치 UI는 아직 이전하지 않았습니다.
- **난수:** 실제 무작위 범위는 유지하지만 Godot RNG는 JavaScript Math.random과 같은 난수열이 아닙니다. Godot 내부에서는 시드 테스트가 재현됩니다. 두 버전의 승자를 같은 시드로 직접 비교하지 않습니다.
- **화면:** 원, W/A, 팀색 HP 바, 상태 텍스트와 간단한 칼날·화살 디버그 표시만 있습니다. DOM/Canvas/CSS UI를 복제하지 않았습니다. 자동 카메라, 최종 UI, 파티클·사운드·전투 시작/종료 연출은 미구현입니다.

타워·길드원·영입·플레이어 HP·부활·후퇴·재도전·전투 후 상태 유지·기력·장비·성장·전략카드·터닝포인트·궁극기·초월·로그라이크 지도·상점·이벤트·저장 시스템도 만들지 않았습니다. 향후 Manager나 빈 시스템 파일을 선행 생성하지 않았습니다.

## 검증 결과

검증 환경: Godot 4.6.3 stable / Linux. 사용한 웹 원본 파일의 작업 전후 SHA-256을 비교합니다. Git 변경 범위는 `godot/`만입니다.

- headless 에디터 프로젝트 import·GDScript 파싱·Resource와 씬 로드: 통과.
- 메인 프로젝트 headless 실행 180 프레임: 오류 없이 종료.
- 실제 X11 가상 디스플레이에서 OpenGL Compatibility 창 실행 및 화면 확인: 팀 구분·종류·HP·상태·결과 표시 확인. llvmpipe의 V-Sync 미지원 경고는 해당 테스트 디스플레이의 제한이며 스크립트 오류가 아닙니다.
- 자동 테스트: 전사 vs 전사, 전사 vs 궁수, 궁수 vs 궁수, 3 vs 3을 시드 3·29·101로 반복했습니다. 추가로 한 진영만 존재, 유닛 없음, 경계 이동, 타겟 사망 후 변경, 동시 마지막 사망, 화살 프레임 통과 및 이동 회피를 검사했습니다.
- 검사 항목: 유한 좌표/속도, 경계와 HP 범위, 사망 후 활동 중단, 사망/result 단발성, 실제 공격 개시 범위, WINDUP 즉발 피해 금지, 모든 공격 상태 방문, 공유 데이터 독립성, 일반/치명타 피해, 적 없음, 종료 후 전체 상태 고정.
- 무효 피해(NaN/Infinity), 잘못된 좌표 입력과 종료 후 직접 HP/공격 진입점도 검사합니다.
- 캐시를 제외한 새 프로젝트 복사본에서도 import와 테스트를 실행했습니다. 최종 결과는 **14개 완주 전투, 9,705개 검사, 실패 0개**입니다. 동시 사망·타겟 변경·경계·피해 등 별도 시나리오 검사도 이 검사 수에 포함됩니다. 원본 웹 19개 파일의 SHA-256은 모두 작업 전과 동일했습니다.

테스트의 180초 제한은 테스트 실패 감지용입니다. 전투에 새 제한시간이나 밸런스 규칙을 추가한 것이 아닙니다. 아래 명령이 출력하는 최종 검사 수와 실패 수가 기준입니다.

## 직접 실행

Godot 4.x에서 `godot/project.godot`을 **Import**한 뒤 **F6 또는 F5**로 실행합니다. 시작 시 바로 양 팀 3 대 3 전투가 진행됩니다. 에디터에서 `Battle` 노드의 `random_seed`를 -1로 두면 매번 난수화하고, 0 이상의 값이면 Godot 테스트용 고정 시드를 사용합니다.

저장소 루트에서 CLI 실행:

```sh
godot --editor --path godot
```

headless 검증은 새 checkout의 클래스·Resource import를 먼저 수행합니다:

```sh
godot --headless --path godot --editor --quit
godot --headless --path godot --script res://tests/test_runner.gd
godot --headless --path godot --quit-after 180
```

이미 import된 프로젝트를 창으로 직접 실행:

```sh
godot --path godot
```

현재 sandbox에서는 기본 홈 디렉터리에 Godot 캐시를 쓸 수 없어, 명령 앞에 다음 환경 설정을 붙였습니다. 일반 로컬 PC에서는 필요하지 않습니다. HOME을 변경하지 않습니다.

```sh
env XDG_DATA_HOME=/tmp/duni-godot/data \
    XDG_CONFIG_HOME=/tmp/duni-godot/config \
    XDG_CACHE_HOME=/tmp/duni-godot/cache \
    godot --headless --path godot --script res://tests/test_runner.gd
```

## 이번 Phase 되돌리기

현재 변경은 새 `godot/` 폴더뿐이며 웹에는 Godot를 연결한 코드도 없습니다. Godot 실행을 닫고 저장소의 **`godot/` 폴더만 삭제**하면 이번 Phase를 되돌릴 수 있습니다. 이 방법은 이후 작업을 하기 전의 이번 변경에 대한 것입니다. 원본 `dist/`를 되돌리거나 `git reset --hard`, `git clean -fd`를 실행할 필요가 없습니다. 작업은 커밋하지 않았습니다.

## 다음 Phase 전 확인할 사항

1. 향후 AI 이전 시 TYPES.range·프로필 reach·preferred range를 구분하고, 이번 직선 접근을 원본 전체 AI로 오해하지 않아야 합니다.
2. 방어 시스템 단계에서 기본 방어력의 기존 동작, 피해 파이프라인 순서와 장기전 피해 증가를 결정해야 합니다. 이번 단계는 그 동작을 수정하지 않았습니다.
3. 피해 이벤트의 계산 피해/실제 HP 손실/오버킬을 구분한 뒤 궁극기 충전·집계에 연결해야 합니다.
4. 길드원 상태 유지 단계는 battle_id와 guild ID 매핑, 시작 HP 및 상태 주입, 전투 후 회수와 분리된 런 승패 판정이 필요합니다.
5. 관통·상쇄 단계는 시간순 공격 접촉 처리에 통합하고, 캐릭터 패시브 단계에서 궁수 3번째 사격을 복원해야 합니다.
6. 전체 전투 감각과 웹 승률 비교는 AI·방어·충돌·넉백·패시브를 옮긴 뒤에 의미가 있습니다. 이번 검증은 최소 루프의 안정성 검증입니다.

현재 최소 전투 실행을 막는 미해결 오류는 확인되지 않았습니다. 위 항목은 후속 이전 단계의 결정 사항이며 이번 작업에서 구현하지 않습니다.


## Phase 12.5 visual reference

원본 HTML·Godot 변경 전·변경 후 같은 viewport의 비교는 [PHASE125_REPORT.md](PHASE125_REPORT.md)와 [비교 갤러리](migration/phase125/comparisons/index.html)를 참조하세요. 26종 pixel avatar + 원본 procedural weapon13pose, portrait/item/room 카드, CPU particle/trail/ability motif와 presentation-only camera를 사용합니다. F3 개발 overlay는 기본 OFF입니다. AI/전투 수치/save v1/웹 원본은 그대로이며 사운드는 추가하지 않았습니다. 전체 원본 animation parity와 남은 차이는 보고서에 구분했습니다.
