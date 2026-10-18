# Phase 2 — 개별 길드원 및 전투 상태 유지 완료 보고

구현 범위는 종류 데이터 / 개별 길드원 / 전투 인스턴스의 분리와 전투 전후 상태 전달입니다. **Phase 3은 시작하지 않았습니다.** 기존 기본 3대3 화면과 Phase 1 전투 규칙은 유지하며, 실제 모집·경제·성장·배치 UI·타워·스킬·저장 시스템은 추가하지 않았습니다.

## 1–3. 생성·수정 파일과 역할

새 파일:

| 파일 | 역할 |
| --- | --- |
| `scripts/guild_member_state.gd` | RefCounted 개별 길드원 데이터와 생존 판정, 기력·게이지 범위, 안정적인 ID |
| `scripts/guild_manager.gd` | 생성·등록·ID 조회·전체/생존 목록, 같은 종류 여러 길드원 관리 |
| `scripts/run_state.gd` | 길드 명단, ID 카운터, 런 ID와 정산 중복 기록만 보유 |
| `scripts/combat_stance.gd` | normal/cautious/rush/cover ID의 단일 정의와 잘못된 값 처리 |
| `scripts/battle_unit_factory.gd` | 전투 입력 검증·길드원 조회 어댑터·Unit 생성 |
| `scripts/unit_state_codec.gd` | 지속 필드 주입·스냅샷·회수, 순수 데이터 검증과 깊은 복사 |
| `scripts/battle_settlement.gd` | 완료된 전투 결과를 런에 한 번만 반영하는 정산 |
| `scripts/damage_outcome.gd` | attempted/resolved/hp_damage를 구분하는 숫자 결과 |
| `tests/phase2_tests.gd` | 개별 상태, 2연전, 기력, 사망, 중복/오류 정산 및 피해 단계 테스트 |
| `PHASE2_REPORT.md` | 이 보고와 MIGRATION_NOTE, 실행·롤백 안내 |
| `migration/phase1-before-phase2.tar.gz` | 작업 직전 Phase 1 소스 34개 파일의 개발용 복구 아카이브 |

신규 GDScript의 `.gd.uid` 9개는 Godot가 생성한 식별 파일입니다. 아카이브는 **게임 세이브 파일이 아니며**, 게임 코드에서 읽지 않습니다.

수정한 기존 Godot 파일:

| 파일 | 변경 |
| --- | --- |
| `scripts/unit.gd` | source_member_id/run_id, 기력·게이지·성향·고유 상태 보관 필드 추가 |
| `scripts/battle_manager.gd` | 기존 생성 부분을 Factory로 위임, 선택 길드원 시작 API 및 결과 캡처 연결 |
| `scripts/battle_result.gd` | 정산 ID, 참가/생존/사망 member ID, 최종 HP와 지속 상태 스냅샷 추가 |
| `scripts/damage_resolver.gd` | 기존 `apply()`·signal 계약을 보존하고 `resolve()`·DamageOutcome 추가 |
| `tests/test_runner.gd` | 기존 테스트 실행 후 Phase 2 suite 호출·검사 수 합산·종료 코드 통합 |
| `README.md` | 기존 Phase 1 기록 위에 최신 보고 링크 추가 |

**UnitData, AttackData, 전사·궁수 .tres, 공격/이동/타겟 로직, BattleClock, 씬과 화면 코드는 변경하지 않았습니다.** Phase 1의 기존 테스트 함수들도 작업 전과 바이트 단위로 동일합니다. 캐시 `.godot/`는 소스가 아니며 Git 제외 상태를 유지합니다. 커밋이나 배포는 하지 않았습니다.

## 4. GuildMemberState 구조

| 필드 | 형식·규칙 |
| --- | --- |
| member_id | String, `member_000001` 등; 최초 한 번만 지정 |
| unit_type_id | int, 이번 종류는 전사 0 / 궁수 1 |
| level / stars | int, 생성 시 0 / 0; 저장용 메타데이터만 보유 |
| current_hp | float, 종류 데이터와 분리된 개별 HP |
| energy | int, 직접 대입과 정산 모두 0~5로 clamp |
| ultimate_gauge / transcendence_gauge | float, 0~100으로 clamp; 자동 초기화·충전 없음 |
| stance | StringName, CombatStance에서 정의; 잘못된 값은 normal |
| character_specific_state | Dictionary, 대입과 주입/회수에서 깊은 복사 |

`is_alive()`는 유한한 `current_hp > 0`으로 판단합니다. 별도 alive 저장 필드는 없습니다. UI/Scene/Unit을 참조하는 필드는 없습니다. 고유 상태 payload의 허용 범위는 nil·bool·유한 숫자·문자열·배열·Dictionary이며, 검증 시 Node·Resource·Callable을 거부합니다. 비정상 순환/과도한 중첩을 막기 위해 검증 깊이는 32까지입니다. 직접 Dictionary를 잘못 변경한 경우에도 Factory와 정산 경계의 검증을 통과할 수 없습니다.

## 5. GuildManager 및 RunState 구조

`GuildManager`는 Node가 아닌 RefCounted입니다. `create_member(type_id)`, `register_member(member)`, `get_member(id)`, `all_members()`, `living_members()`, `definition(type_id)`를 제공합니다. 전체/생존 목록은 새 배열이며 각 원소는 실제 개별 길드원 상태입니다.

`RunState`가 `guild_members: member_id → GuildMemberState`와 `next_member_number`를 소유합니다. 같은 RunState로 GuildManager를 새로 만들어도 명단과 ID 생성 순서는 유지됩니다. 중복 등록과 모르는 종류는 거부합니다. member_id는 런 안에서 고유하며, 서로 다른 런은 별도 run_id로 구분합니다. ID 생성은 Node instance ID를 사용하지 않습니다.

RunState에 추가한 최소 보조 데이터는 `run_id`와 `settled_battle_ids`입니다. 런 구분과 중복 정산에만 사용하며 지도·재화·플레이어 HP·진행 상태는 없습니다. 런 ID와 전투 정산 ID는 Crypto의 16바이트 난수로 생성하는 순수 문자열입니다. 전투용 RNG를 소비하지 않으므로 Phase 1 시드별 전투 결과를 바꾸지 않습니다. 저장/로드는 아직 구현하지 않았습니다.

## 6. 세 계층 관계

| 계층 | 수명·소유 | 공유 여부 |
| --- | --- | --- |
| UnitData | 캐릭터 종류 정의, GuildManager의 종류 조회 | 같은 종류가 같은 Resource 공유 |
| GuildMemberState | 런에 속하는 실제 영입 개체 | HP·기력·게이지·성향·성장 메타데이터가 개별 |
| Unit / BattleUnit | 이번 전투의 Node2D | controller·타겟·위치·공격 상태가 전투 인스턴스별 |

Unit은 `source_member_id`와 `source_run_id`를 보유하며 **GuildMemberState 객체를 참조하지 않습니다.** battle_id는 전투 내 정수 ID이고 member_id와 별개입니다. 다음 전투에서 battle_id가 다시 1부터 시작해도 길드원 ID는 유지됩니다. UI 없는 테스트 적은 source_member_id가 빈 문자열이며 정산 대상이 아닙니다.

## 7. 상태 주입

`BattleManager.start_guild_battle(guild, deployments, enemies, seed)`에서 deployment는 member_id·시작 좌표·선택적 팀만 전달합니다. 종류 데이터와 길드원 조회는 Factory로 넘기며, manager가 HP·게이지·고유 상태를 직접 풀어 복사하지 않습니다.

Factory가 살아 있는 해당 길드원을 조회한 뒤 기존 Unit 초기화 로직을 사용하고, Codec이 다음을 주입합니다:

- source_member_id/run_id
- current_hp, energy
- ultimate_gauge, transcendence_gauge
- stance, character_specific_state의 깊은 복사

HP는 이번 단계의 기본 UnitData 최대 HP 범위로 제한하고 이전 유효 HP를 그대로 사용합니다. 사망한 멤버·없는 ID·같은 개인의 중복 슬롯·잘못된 좌표·고유 상태에 포함된 객체 참조는 거부합니다. 전체 입력 검증을 먼저 하므로 거부 시 유닛 일부만 생성되지 않습니다. **기력 0은 거부 조건이 아닙니다.**

## 8. 상태 회수와 BattleResult

BattleManager가 종료할 때 Codec으로 Unit의 지속 상태를 복사해 BattleResult에 넣습니다. 기존 Phase 1 결과와 승패 판정은 유지합니다. 확장 결과:

- `completed`, `battle_result_id`, `source_run_id`
- `participating_member_ids`, `surviving_member_ids`, `dead_member_ids`
- `final_hp_by_member_id`
- `member_states`: member ID별 분리된 지속 상태 스냅샷

스냅샷은 HP·두 게이지·성향·고유 상태와 식별 정보만 포함합니다. 타겟·위치·공격 단계·combat_state·movement state·쿨타임·단기 AI 판단은 회수하지 않습니다. 결과는 UI 문자열이나 Unit/Scene 참조가 없는 데이터입니다. 씬과 Unit을 해제한 뒤에도 정산이 가능하며 실제 테스트로 확인했습니다.

정산은 자동으로 숨겨 수행하지 않습니다. 호출자는 완료 signal을 먼저 연결한 뒤 `BattleSettlement.apply(result, guild)`를 한 번 호출합니다. 전투 중 길드원 HP는 바뀌지 않으며 정상 종료 후 정산 시에만 반영됩니다. 승리해도 최대 HP로 초기화하거나 추가 회복하지 않습니다.

## 9–11. 기력·사망·중복 정산

참가는 결과에 실제로 포함된 member_id로 판정합니다. 참가자 −1, 모든 비참가자 +1이며 모두 0~5로 제한합니다. 출전 후 사망한 멤버도 참가자이므로 −1입니다. 원본 `settleTowerBattle()`처럼 **비참가 사망 멤버도 기력은 +1**이지만 HP는 0이며 부활하지 않습니다.

사망 멤버는 명단에서 삭제하지 않고 HP 0으로 회수합니다. 생존 목록에서 제외하며 기본 Factory는 다음 전투에 생성하지 않습니다. 부활, 전멸 게임오버, 플레이어 HP 감소는 이번 범위에 없습니다. 전투 패배는 길드/런 종료로 변환되지 않습니다.

중복 방지는 RunState의 `settled_battle_ids[battle_result_id]`로 처리합니다. 새 BattleSettlement/GuildManager 객체로 같은 결과를 다시 적용해도 `ALREADY_SETTLED`입니다. 같은 ID의 다른 결과 객체도 반복 적용하지 않습니다. 이전 전투 결과를 뒤늦게 다시 호출해 다음 전투의 HP를 덮어쓰는 것도 차단합니다.

모든 참가 ID·스냅샷·생존/사망 목록·HP 대응과 런을 먼저 검사한 뒤, 정산 기록과 상태를 한 번 갱신합니다. 검증 실패 시 HP·기력·중복 기록 모두 그대로입니다. 상태 반환은 `APPLIED`, `ALREADY_SETTLED`, `INVALID_RESULT`, `FOREIGN_RUN`, `INVALID_STATE`입니다. 아직 완료되지 않은 결과나 길드 참가자가 없는 Phase 1 결과는 길드 기력을 정산하지 않습니다.

## 12–13. 추가 테스트 목록과 결과

요청한 검증 항목은 다음 테스트에서 확인합니다:

| 요청 항목 | 테스트 |
| --- | --- |
| 1. 모든 길드원의 member_id 고유성 | registry, 같은 런 manager 재생성, ID 변경 거부 |
| 2–3. 같은 종류 HP·게이지 독립성 | registry 및 두 전사 주입 테스트 |
| 4–5. 상태 주입·회수 | injection_snapshot_and_settlement |
| 6–7. 다음 전투 HP·비참가자 HP 유지 | 실제 two_battles |
| 8–11. 참가/비참가 기력과 0~5 제한 | 두 전투 및 death_energy_and_refusals |
| 12. 기력 0 출전 | 2차 전투의 기력 0 궁수 |
| 13–16. 궁극기·초월·성향·고유 상태 왕복 | injection_snapshot 및 two_battles |
| 17–20. 사망자 유지·생존 제외·HP 0·생성 거부 | death_energy_and_refusals |
| 21. 중복 정산 금지 | 새 정산 객체, 새 manager, 결과 객체 재생성, 오래된 결과 재적용 |
| 22. 참가/생존/사망 member ID 정확성 | 생존 결과 및 사망 포함 결과 |
| 23. 기존 Phase 1 전체 통과 | 기존 test_runner 함수 전부 실행 |

추가로 Dictionary 대입/주입/결과/회수 경계의 깊은 복사, 전투 한정 필드 제외, 해제된 씬 이후 정산, 잘못된 결과의 원자적 거부, 다른 런 정산 거부, 게이지/성향 정규화, 중복 배치·없는 ID·NaN 좌표 거부와 피해 단계 분리를 검사합니다.

**Godot 4.6.3 stable 최종 결과:**

- Phase 1: 14개 완주 전투, **9,705개 검사 / 실패 0**. 작업 전과 시드별 승자·전투 시간이 일치합니다.
- Phase 2: 6개 테스트 그룹, **243개 검사 / 실패 0**.
- 합계: **9,948개 검사 / 실패 0**.
- 2연전에서 전사 A의 1차 종료 HP는 **54**, 2차 시작 HP도 **54**입니다. 다른 전사 B는 기존 HP **91**, 미참가 궁수 B는 **67**을 유지합니다.

검사 수는 반복 불변 조건 검사까지 포함한 assertion 수이며 9,948개의 서로 다른 시나리오라는 뜻은 아닙니다. 신규 suite는 상태 전달 검증에 필요한 6개 그룹이며, 기존 Phase 1 함수는 수정하지 않았습니다.

## 14–15. 실행·원본 보호 확인

실행한 명령:

```sh
godot --headless --path godot --editor --quit
godot --headless --path godot --script res://tests/test_runner.gd
godot --headless --path godot --quit-after 180
```

캐시를 제외한 새 프로젝트 복사본에서도 import·테스트·메인 씬 실행을 각각 수행해 종료 코드 0, 스크립트/런타임 오류 0을 확인했습니다. 현재 sandbox에서는 HOME을 바꾸지 않고 `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, `XDG_CACHE_HOME`을 `/tmp/duni-godot/` 아래로 지정했습니다.

실제 X11 가상 디스플레이와 OpenGL Compatibility 창도 실행했습니다. 기본 3대3 화면의 팀·종류·HP·공격 상태를 확인했습니다. Phase 2 정식 길드 UI는 만들지 않았으며 신규 길드 API는 headless suite의 실제 전투로 검증합니다. 테스트 디스플레이의 llvmpipe V-Sync 미지원 경고는 렌더 드라이버의 제한입니다.

작업 전후 **`dist/`의 19개 파일 SHA-256이 모두 동일**했습니다. 기존 추적 파일에 Git 변경은 없고 작업 범위는 godot/ 내부입니다. 배포된 `tower.js?v=83`, `strategy.js?v=83`도 현재 저장소와 바이트 단위로 일치했습니다. 실제 웹 코드를 Node harness에서 로드해 새 멤버 기본값과 성향 ID도 확인했습니다. 사이트나 원본을 변경하지 않았습니다.

직접 실행은 Godot에서 `project.godot`을 Import한 뒤 F5입니다. 신규 API의 최소 사용 형태:

```gdscript
var guild := GuildManager.new()
var warrior := guild.create_member(0)
var archer := guild.create_member(1)
warrior.current_hp = 43
warrior.ultimate_gauge = 37

var battle := BattleManager.new()
battle.auto_start = false
add_child(battle)
battle.battle_finished.connect(func(final: BattleResult):
    print(BattleSettlement.new().apply(final, guild))
)
battle.start_guild_battle(guild, [
    {"member_id": warrior.member_id, "position": Vector2(160, 260)},
    {"member_id": archer.member_id, "position": Vector2(80, 400)},
], [
    {"data": BattleManager.WARRIOR, "team": 1, "position": Vector2(640, 400)},
], 29)
```

이는 API 사용 예이며, 추가 모집 UI나 다음 Phase를 구현한 코드는 아닙니다.

## 16–17. 원본과의 차이 및 MIGRATION_NOTE

1. **승리 회복:** 현재 웹 `settleTowerBattle()`는 전투방 첫 클리어 승리 시 생존 유닛을 30% 회복한 뒤 상태를 저장합니다. 이번에는 명시된 HP 유지 목표에 따라 승리 회복을 넣지 않았습니다. 원본은 수정하지 않았습니다.
2. **기력 피로:** 원본은 부족 1칸마다 피해량 −5%, 받는 피해 +3%, 충전 효율 −7%를 적용합니다. 이 효과는 미구현이며 기력 0 출전 허용과 정산만 이전했습니다.
3. **성장:** level/stars는 데이터 보유·유지에만 사용합니다. 원본 `towerMemberStats()`의 강화/성급 파생 스탯과 장비의 최대 HP 변화는 미구현입니다. 현재는 기본 UnitData 최대 HP로 주입·회수를 검증합니다. 성장 단계에서는 별도 스탯 계산 책임을 추가해야 하며 공유 UnitData를 수정하면 안 됩니다.
4. **게이지:** 원본의 0~100 범위를 유지합니다. 실제 자동 충전·피해 충전·사용과 기술 효과는 구현하지 않았습니다. 이번에는 입력값만 유지합니다.
5. **성향:** 웹과 같은 normal/cautious/rush/cover를 보관하지만 스탯 보정과 AI는 Phase 1 그대로입니다. 잘못된 값은 normal로 처리합니다.
6. **전투 지속 상태:** 웹 `TOWER_STATE_FIELDS`에는 공격 쿨타임·방어 타이머·상태이상·캐릭터 카운터 등이 있습니다. 이번에는 이들의 실제 동작을 이전하지 않았습니다. character_specific_state의 순수 데이터 왕복만 지원하고 현재 타겟이나 공격 단계를 자동으로 영구 저장하지 않습니다.
7. **ID:** 웹은 공통 nextId의 숫자 ID를 사용합니다. Godot는 종류 ID·런 내 member 문자열 ID·전투 내 정수 ID·결과 문자열 ID를 분리합니다. 향후 웹 저장 데이터 가져오기가 필요하면 ID 변환 규칙을 명시해야 합니다.
8. **정산:** RunState에 결과 ID를 기록하고 다른 런·진행 중 결과·잘못된 데이터를 거부합니다. 이는 이전 구조의 명확화입니다. 후퇴·재도전·적 상태 저장·보상·방 클리어는 미구현입니다.
9. **피해:** attempted_damage는 유효한 치명타 적용 전 입력, resolved_damage는 치명타·반올림 후 값, hp_damage는 남은 HP로 제한한 실제 손실입니다. 예: 입력 15 → 치명타 23 → 남은 HP가 3이면 HP 손실 3. 기존 apply의 float 반환값과 damage_applied의 실제 HP 손실 계약은 유지했습니다.
10. **방어:** 웹에서는 기본 방어력이 일반 피해 감소에 직접 사용되지 않는 기존 동작이 있습니다. 이번에 이를 수정하지 않았습니다. 방어는 계속 미구현입니다.
11. **종료의 의미:** BattleResult는 전투 종료 결과이며 런 종료가 아닙니다. 패배 후 예비 전력이 남는 규칙을 막는 게임오버 판정은 추가하지 않았습니다. 플레이어 HP와 전멸에 따른 런 종료는 후속 단계입니다.
12. **미구현 범위:** 모집·경제·플레이어 HP·부활·장비/성장 효과·배치 UI/위치 저장·후퇴/재도전/적 상태 유지·타워/방/상점/이벤트·터닝포인트/카드·실제 스킬·전체 AI·방어/상쇄/넉백/상태이상·세이브·사운드·최종 VFX는 추가하지 않았습니다. Phase 1 보고서의 의도적인 차이도 유지합니다.

## 18. Phase 2만 되돌리기

현재 godot/는 Phase 1부터 커밋되지 않은 상태이므로 Git에서 전체 폴더를 지우거나 reset하면 Phase 1도 사라질 수 있습니다. 대신 작업 직전 소스를 담은 개발용 아카이브를 사용합니다. Godot 실행을 닫고 저장소 루트에서 아래를 실행하면 Phase 2 폴더를 백업한 채 Phase 1만 복원합니다:

```sh
mv godot godot-phase2-backup
mkdir godot
tar -xzf godot-phase2-backup/migration/phase1-before-phase2.tar.gz -C godot
godot --headless --path godot --editor --quit
godot --headless --path godot --script res://tests/test_runner.gd
```

이미 `godot-phase2-backup`이 있으면 다른 백업 이름을 사용하세요. 웹 dist/는 건드리지 않습니다. 아카이브에는 Phase 2 신규 파일과 캐시가 들어 있지 않습니다. 보관된 34개 파일의 해시가 작업 전 Phase 1과 정확히 일치함을 검증했습니다. 현재 작업을 실제로 되돌리지는 않았습니다.

## 19. Phase 3 전 결정·유지할 사항

- 배치 입력의 단위는 type_id가 아니라 **member_id**여야 합니다. 같은 종류 여러 명은 가능하고 동일 개인을 두 슬롯에 넣는 것은 거부해야 합니다.
- 선택/미리보기에서 HP나 기력을 소모하지 않아야 합니다. 기력은 실제 종료 후 참여 ID에 따라 한 번 정산합니다. 기력0은 선택 가능한 상태를 유지합니다.
- 사망자는 목록 표시와 배치 가능 목록을 구분하고, Factory의 사망 생성 거부를 UI에서도 일관되게 적용해야 합니다.
- 위치는 전투 입력에만 전달하며 이번 상태 Codec에 보관하지 않습니다. 진형 저장/복원은 별도 허가된 단계까지 추가하지 않아야 합니다.
- 완료 signal 연결과 정산 호출 책임은 외부 흐름이 가져야 합니다. 다음 전투 시작 전에 정산을 완료하고, 동일 결과 재호출을 런 ledger가 차단하는 계약을 유지해야 합니다.
- 성장/장비 또는 전투 후 회복을 추가하는 단계에서 유효 최대HP와 회복 정책을 결정해야 합니다. 이번 승리 회복 제외를 전체 웹 규칙으로 오해하지 않아야 합니다.
- 후퇴 및 재도전 단계는 새로운 전투 결과 ID와 상태 회수 시점을 명시해야 합니다. 전투 패배와 런 게임오버를 합치지 않습니다.

현재 Phase 2 실행을 막는 미해결 오류는 확인되지 않았습니다. Phase 3 작업은 수행하지 않았습니다.
