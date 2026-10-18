# Phase9 타워 진행 이전 완료 보고

2026-10-13 · Godot 4.6.3 stable · 기준: 현재 dist/tower.js 실행 코드

3챕터·15층·120방을 기존 전체 캐릭터 전투와 연결했습니다. 상점·모집·이벤트는 진입 상태까지만 구현했습니다. 요청서의 층 정복 maxHP 증가와 현재 실행 코드의 플레이어 HP 회복 차이는 32절에 기록했습니다.

## 1. 생성 파일

| 파일 | 역할 |
| --- | --- |
| `scripts/unit_combat_stats.gd` | 이번 전투의 계산된 HP·공격·방어·속도·크기, Resource 원본과 분리 |
| `scripts/tower_enemy_stats_assembler.gd` | 실행 코드의 0.8/레벨/normal·elite·boss 공식 |
| `scripts/enemy_spawn_entry.gd` | 한 번 생성한 적 ID·종류·레벨·최초 위치·rank 배율 |
| `scripts/encounter_state.gd` | 방 생성 시 확정된 적 구성·형성·depth |
| `scripts/room_type.gd` | 실제 7개 kind 및 표시 이름 |
| `scripts/floor_state.gd` | 층 소속·해금·방 ID·클리어 수·정복/추가 보상 |
| `scripts/tower_map_state.gd` | 15층 및 안정적 room_id 조회 |
| `scripts/reward_request.gd` | Phase10이 처리할 정확한 item 지급 요청 |
| `scripts/tower_run_state.gd` | 진행·방문·정복·선택·결과·스크롤·단발 결과 영수증 |
| `scripts/tower_navigation_policy.gd` | locked/unfinished/event-active/gameover/잘못된 ID 진입 정책 |
| `scripts/tower_map_generator.gd` | 실제 quotas·milestone·적 pool/레벨/배치 생성 |
| `scripts/tower_controller.gd` | 새 런·방 발견·실전 session 연결·진행·정복·포기 |
| `scripts/tower_battle_screen.gd` | 기존 전투 UI에 실제 guild/room/controller 주입 |
| `scripts/tower_screen.gd` | 세로 층/가로 방 지도·방 선택·보상 안내·확인창 |

`scenes/tower.tscn`은 F5 메인. `tests/phase9_tests.gd`, `phase9_runner.gd`, `tower_ui_smoke.gd`는 자동/독립/GUI 검사입니다. 새 스크립트 UID도 포함합니다. `tests/web_phase9_reference.cjs`는 저장소 루트에서 Node로 다시 실행할 수 있는 기준값 생성기입니다. `migration/phase9-web-rules.json`은 실제 JS 함수 234개 계산 샘플, SHA·검사 로그·스크린샷·변경 목록도 보관했습니다. `migration/phase8-before-phase9.tar.gz`는 시작 전 Godot 파일 302개의 복구본입니다.

## 2. 수정 파일

기존 변경 파일 41개. 공유 종류값을 읽던 **실행 시 스탯 접근만** `unit.max_hp/attack_power/defense_power/base_body_scale`로 바꿨습니다. 기존 공격·AI·패링 수치와 로직을 새로 만들지 않았습니다.

- `README.md`
- `scripts/battle_manager.gd` — 종료 시 스냅샷 이전 단발 finalizing 신호
- `project.godot`
- `scripts/unit_state_codec.gd`
- `scripts/character_lifecycle.gd`
- `scripts/ultimate_controller.gd`
- `scripts/knockback_controller.gd`
- `scripts/battle_zones.gd`
- `scripts/area_evaluator.gd`
- `scripts/combat_rules.gd`
- `scripts/strategy_effects.gd`
- `scripts/damage_resolver.gd`
- `scripts/enemy_room_state.gd`
- `scripts/deployment_board.gd`
- `scripts/combat_controller.gd`
- `scripts/battle_unit_factory.gd`
- `scripts/threat_response_controller.gd`
- `scripts/strategy_card_executor.gd`
- `scripts/room_battle_session.gd`
- `scripts/projectile.gd`
- `scripts/room_state.gd`
- `scripts/battle_brain.gd`
- `scripts/turning_point_manager.gd`
- `scripts/enemy_state_codec.gd`
- `scripts/unit.gd`
- `scripts/battle_settlement.gd`
- `scripts/character_ability.gd`
- `scripts/run_state.gd`
- `tests/test_runner.gd`
- `scripts/abilities/frog_ability.gd`
- `scripts/abilities/bomber_ability.gd`
- `scripts/abilities/mage_ability.gd`
- `scripts/abilities/dolphin_ability.gd`
- `scripts/abilities/guardian_ability.gd`
- `scripts/abilities/mirror_ability.gd`
- `scripts/abilities/assassin_ability.gd`
- `scripts/abilities/archer_ability.gd`
- `scripts/abilities/predator_ability.gd`
- `scripts/abilities/paladin_ability.gd`
- `scripts/abilities/lightning_ability.gd`
- `scripts/abilities/healer_ability.gd`

## 3. TowerRunState

`RunState.tower`가 순수 `TowerRunState`를 소유합니다. map, current_chapter(1기준), unlocked_floor(0기준), selected_room_id, phase, visited_rooms, cleared_rooms, floor_conquest, chapter_progress, reward_requests, result, conquered, processed_results, map_scroll_y를 보유합니다. player HP·guild·cards는 기존 RunState에 남습니다. 정복 이후에도 지도를 탐험할 수 있고 게임오버와 구분됩니다.

## 4. TowerMapState

`floors: Array[FloorState]`, `rooms: Dictionary[room_id,RoomState]`. 전체 120개 방을 런 생성 때 확정합니다. 도메인에는 Node/Scene/Tween/Timer 참조가 없습니다. 맵 데이터 생성으로 Scene Node가 증가하지 않습니다.

## 5. FloorState

floor_index(0~14), chapter_index(1~3), unlocked, room_ids, cleared_count, required_clear_count, conquered, bonus, bonus_item_kind. 클리어 수는 room.cleared를 재평가하고 해금과 정복 단발 영수증을 따로 유지합니다.

## 6. RoomState 확장

기존 room_id/source_run_id/enemy_state/attempt/active_result/settled_result 계약에 floor_index, chapter_index, lane, room_type, discovered, visited, consumed, publicly_visible, event_type, encounter, gold_reward, token_reward, kill_rewards, reward_claimed를 추가했습니다. 기존 Phase4 독립 방은 floor_index=-1로 두고 타워 보상/치유를 적용하지 않습니다.

## 7. RoomType

실행 코드와 대응하는 StringName: battle, miniboss, boss, shop, recruit, rest, event. 이벤트 하위 종류는 prediction/promotion/hotSpring/supply. battle 계열만 실제 전투, 나머지는 미사용·미클리어 진입 화면입니다.

## 8. 전체 map generation

`TowerMapGenerator.generate(seed,run_id)`에서 floor kinds → Encounter → EnemySpawnEntry → 계산된 EnemyRoomState를 한 번 생성합니다. JS Math.round의 양수 경계는 floor(x+0.5)로 맞췄고, shuffle은 명시적인 RNG를 사용합니다. 최초 층 슬롯은 recruit/shop/rest/battle/event/battle로 특례를 보존했습니다.

## 9. 층별 방 개수

`6 + floor(max(0,depth)/3)`; depth는 0기준.

| 실제 층 | 방 수 |
| --- | --- |
| 1~3 | 6 |
| 4~6 | 7 |
| 7~9 | 8 |
| 10~12 | 9 |
| 13~15 | 10 |

총 120방입니다.

## 10. room type 비율

우선순위대로 battle=min(count,round(count×.4)); rest=min(count-battle,max(1,round(count×.15))); services=min(잔여,clamp(round(count×.25),1,4)); event=잔여입니다. services 첫째 recruit/둘째 shop, 이후 50:50.

| 방 수 | battle | rest | services | event |
| --- | --- | --- | --- | --- |
| 6 | 2 | 1 | 2 | 1 |
| 7 | 3 | 1 | 2 | 1 |
| 8 | 3 | 1 | 2 | 2 |
| 9 | 4 | 1 | 2 | 2 |
| 10 | 4 | 2 | 3 | 1 |

보스 층은 이 표의 일반 구성과 다릅니다.

## 11. boss/miniboss 생성

챕터 3번째 층(3·8·13층)은 battle 1개를 miniboss로 바꾸고 중앙 인덱스 floor(count/2)에 넣습니다. 5·10·15층은 중앙 boss 1개, quota.rest개 휴식소, 나머지 event입니다. 보스 층 각각 boss/rest/event=1/1/5,1/1/7,1/2/7. 모든 milestone은 첫 방문 전에도 공개됩니다. **챕터별 고정 보스 조합은 실행 코드에 없습니다.** 제한 후보군 랜덤 boss + 다른 타입 elite + 역할별 normal입니다.

## 12. hidden/discovery

일반 방은 발견 전 정확한 종류를 숨기고 milestone만 public 표시합니다. discovered와 visited는 최초 진입 때 true, cleared는 콘텐츠 완료, consumed는 재사용 불가 콘텐츠 완료 상태입니다. 웹 revealed와 Godot discovered가 대응합니다. 웹 visited 배열은 clearTowerRoom에서 갱신되지만, 요구된 의미 분리를 위해 Godot 방문 기록은 진입 기록이며 완료는 cleared_rooms에 따로 저장합니다.

## 13. room 최초 발견 보상

chooseTowerNode 실행 규칙과 동일하게 !discovered일 때 gold+=50. 공개 보스도 최초 발견 보상은 별개입니다. 재방문/클리어 방 확인에는 중복 지급하지 않습니다. 이벤트는 첫 발견 때 미조우 종류 가중치4, 조우 종류1로 종류만 정합니다. 이벤트 내용/보상은 미구현입니다.

## 14. gold/token 초기값과 근거

dist/tower.js:newTowerState (196행): gold=1200,tokens=5,hp=maxHp=100. 초기 guild=[0,0,1,5](전사2·궁수1·힐러1), level/stars=0,energy=5. 카드=mango,evade,shield,shield. 디버그 단일 방의 6장 지급/6명 길드를 실전 타워 초기값에 혼입하지 않았습니다.

## 15. EncounterState

room_kind,depth,formation,enemies[]. 초기구성은 순수 데이터로 RoomState.encounter에 보관하고 재도전 시 생성 함수를 다시 호출하지 않습니다. EnemyRoomState는 이 설정에서 만든 런 중 현재 HP·위치·게이지·지속 상태입니다.

## 16. EnemySpawnEntry

enemy_id=`depth:lane/enemy_NNN`,unit_type_id,level,initial_position,rank,body_scale,hp/damage/defense/speed_multiplier. 원본 종류 Resource에 레벨/보스 값을 기록하지 않습니다. enemy IDs는 방별 고유하며 run 소유는 RoomState.source_run_id로 확인합니다.

## 17. enemy level 공식

평균=max(0,round(depth×1.6)); 실제 1~15층 평균은 0,2,3,5,6,8,10,11,13,14,16,18,19,21,22입니다. 평균>0이면 인접 쌍에 -1/+1 편차: 첫 쌍 항상, 이후 65% 확률. 섞은 뒤 배정해서 방 평균을 보존합니다. 레벨은 재방문마다 다시 뽑지 않습니다.

## 18. normal scaling

base=.8, growth(stat)=1+level×TOWER_GROWTH[stat].

| 최종 값 | 실제 공식 |
| --- | --- |
| HP | round(type.hp×.8×(1+level×.12)×hpMultiplier) |
| attack | type.dmg×.8×(1+level×.08)×damageMultiplier |
| defense | type.defensePower×.8×(1+level×.08)×defenseMultiplier |
| speed | type.speed×.8×(1+level×.02)×speedMultiplier |
| scale | towerBodyScale, 종류 body_scale와 별도로 곱함 |

normal multiplier는 전부1. 치명타·공격 간격·사거리는 종류 데이터를 유지합니다.

## 19. miniboss scaling

elite: HP×2.5,attack×1.65,defense×1.5,speed×1.08,body_scale1.5. 첫 적은 FRONT pool elite, 나머지 normal. 적 수=min(6,2+floor(depth/6)+floor(random×2)); 3·8·13층에서 각각2~3,3~4,4~5명. 별도의 새 boss 레벨 보너스는 없습니다.

## 20. boss scaling

boss: HP×3.6,attack×2.15,defense×2,speed×1.12,body_scale1.85; 두 번째 적 elite. 후보군[0,2,4,7,9,10,11,12,13]. 적 수=min(7,4+floor(depth/5)+floor(random×2)); 5·10·15층에서4~5,5~6,6~7명. normal은 min(12,3+floor(depth×.7)+floor(random×2)).

## 21. TowerEnemyStatsAssembler

UnitData+EnemySpawnEntry→UnitCombatStats. 플레이어 레벨/장비 성장 함수와 합치지 않았습니다. 26종×레벨0/3/22×rank3의 234개 실제 JavaScript 계산값을 따로 실행해 얻고, Godot 결과와 5개 필드를 대조했습니다.

## 22. UnitData와 Tower stats 분리

UnitData는 공유 종류 정의, UnitCombatStats는 이번 적의 계산값, BattleUnit은 상태/런타임입니다. optional combat_stats가 없으면 기존 base getter가 동작해 Phase1~8 fixtures를 보존합니다. 팩토리는 계산값의 유한성/양수 조건을 확인하고 HP 주입 전에 stats를 설정합니다. 이동속도는 기존 개별 random 속도×(계산속도/종류속도), body_scale는 종류크기×타워크기로 계산합니다.

## 23. room→deployment→battle 흐름

TowerController.select_room → TowerBattleScreen(실제 guild/room 주입) → DeploymentPlan/FormationState → TowerController.start_battle → 기존 RoomBattleSession → BattleUnitFactory. common=true/full_characters=true를 이 경로에서 강제합니다. Phase1~6 최소 비교 fixtures만 explicit legacy; Phase7 비교 fixtures는 common=true/full=false. 타워는 이를 사용하지 않습니다. 적 현재 위치를 배치 blocker로 전달하고 기존 가까운 빈 위치 복원 규칙을 재사용합니다.

## 24. 승리 처리

기존 cargo 해제 → 전투 stopped → RoomBattleSession의 최초 승리 생존 참전자 치유 → 아군·적 snapshot 생성 → 방 정산 검증/상태 회수·기력 → 추가 손실 판정 → room clear → 타워 보상/진행 → 지도 복귀. VICTORY 첫 정산이면 일반350+depth×50G/+1토큰,miniboss700G/+2,boss1000G/+3. miniboss 첫 승리는 현재6종 중 무작위 전략카드1도 지급합니다. killRewards/reward_claimed/processed_results로 중복 방지합니다. 적 처치 보상은 사망 순간 별도 단발: round((10+floor(random×31))×(recruitTokens/2)×(1+level×.12))G, token 확률=min(.25,.03×factor).

## 25. 패배 처리

이번 참가자의 HP/게이지/지속 상태·기력 정산, 적 현재 상태 저장, 기존 사망 비용×.05 손실 + 일반 패배20HP 유지. room 미클리어이며 예비 생존 길드원이 있으면 런 유지, 결과 확인 후 지도 복귀와 다른 편성 재진입 가능. 추가 승리 치유/방 보상은 없습니다.

## 26. 후퇴 처리

기존 RetreatController 조건 그대로:20 simulation seconds 이상, 유효한 진행 전투, 양측 생존, HP>0, 초월 freeze 없음. TP hold에서도 조건 충족 시 가능. 생존 아군 상태·참전기력 정산, 적 상태 저장, room 미클리어. 사망 손실은 남고20HP 패배 추가 손실은 없습니다.

## 27. 재도전

동일 map.room_id를 선택해 EnemyRoomState의 살아남은 적만 생성합니다. stable enemy_id는 유지하고 battle_id는 새로 만듭니다. 적 HP/마지막 유효 위치/gauge/캐릭터 whitelist가 복원됩니다. 아군은 새 자유 배치와 마지막 **시작** 진형을 사용합니다. TP는12초부터 새로 시작, 카드 런 사용 기록은 유지됩니다.

## 28. 첫 승리30% 회복

settleTowerBattle(677행)의 won&&!room.cleared && u.hp>0 조건을 타워 방에서만 적용했습니다. source 없는 최대 HP×.3 치유, recipient healing_power 배율·maxHP clamp. 실제 참전자만, 예비/사망자/후퇴/패배/재클리어는 제외. BattleManager.battle_finalizing 단발 신호에서 RoomBattleSession이 기존 StrategyEffects.heal을 호출하므로 **회복된 HP가 runtime Unit·BattleResult·GuildMemberState 모두에 일치**합니다. 전투는 이미 STOPPED이고 공격·피해 재개는 없습니다. 회복 배율 자체를 개별 지속 상태로 복사하지 않습니다. 이전 Phase4 standalone 룸 회귀는 변경하지 않았습니다. 아이템으로 healing_power를 계산하는 인벤토리 경로는 Phase10입니다.

## 29. floor unlock

ceil(room_count/2) 클리어 경계, while로 이미 조건 충족한 층을 연쇄 해금합니다. unlocked_floor는 가장 높은 해금 depth, 각 floor.unlocked와 전략카드 progress.unlocked_floor를 동시에 갱신합니다. 새 연결 노드·격자·강제 경로를 만들지 않았습니다.

## 30. chapter unlock

chapter 마지막 층은 절반 클리어와 boss clear를 함께 요구합니다. boss clear만으로 chapter_progress(정복 표시)는 기록할 수 있지만 다음 층 해금은 절반 조건도 필요합니다. 마지막15층도 절반+boss면 tower.conquered이고 남은 방을 자유 탐험합니다.

## 31. conquest

해당 floor.cleared_count==전체 room 수일 때만 단발. floor.conquered와 floor_conquest 영수증을 사용합니다. 보상 버튼을 먼저 열면 추가 보상을 그때 확정하며 보상 지급까지 유지합니다. 전체 지도 정복과 챕터 보스 정복은 각각 다른 상태입니다.

## 32. conquest 보상

**요청서와 실행 코드의 충돌:** 길드 전체 maxHP+10%는 현재 실행 코드에 없습니다. rewardTowerFloorConquest(111~118행)는 플레이어 현재 HP+=playerMaxHP×.1, cap(playerMaxHP)이며 최대 HP는 그대로입니다. 전체 길드원(사망 포함) 기력+1,최대5. 추가보상 heal/item/tokens를 각1/3로 선택: heal은 전체 HP20% 회복(사망자도 회복하여 부활, 그때 bomber 상태 초기화), item은 실제10종 중 무작위 itemKind RewardRequest, tokens는+2. 길드 장비/레벨 효과는 Phase10에 연결합니다. 웹의 clear→conquest→gameover 순서를 보존해 draw 후 conquest heal이 마지막 길드원을 살릴 수 있는 시나리오도 검사했습니다.

## 33. navigation policy

TowerNavigationPolicy에서 잘못된 room ID/gameover/locked floor/unfinished deployment·battle/event_active를 거부합니다. chapter 잠금은 floor 해금 gate에 포함됩니다. 클리어 전투방은 안내 화면만 열고 battle start를 거부합니다. prepare/deploy 이후 임의 지도 이동은 불가, 후퇴/패배의 완료 정산 후 result→route는 허용합니다. Phase10 placeholder에는 아직 실제 이벤트가 시작되지 않아 지도 복귀를 허용하고 완료를 처리하지 않습니다.

## 34. gameover

player_hp<=0 또는 전체 길드 생존0, 예비 포함. 기존 Unit 사망 이벤트 손실/단발 receipt 책임을 유지합니다. HP0이면 적 전멸도 room clear보다 RUN_ENDED 우선. map 버튼 잠금과 게임오버 제목, 새 런 버튼. 런 종료 시 stance를 normal로 초기화합니다. 최종 감속/VFX 연출은 이번 범위에 포함하지 않습니다.

## 35. abandon

지도/실제 전투가 시작되지 않은 비전투 진입 화면에서 확인창을 띄우고 확인할 때만 종료합니다. deploy/battle/event_active와 이미gameover는 domain에서도 거부합니다. result=abandon, GameOverReason.ABANDON, stance 초기화. 현재 run 상태는 게임오버 안내용으로 남고 새 런 시 완전히 교체합니다. 웹도 tower 데이터를 즉시 null로 지우지 않습니다.

## 36. new run

TowerController.new_run(map_seed,combat_seed)로 별도 RunState/GuildManager/TowerRunState/map을 생성합니다. 100HP/1200G/5tokens/전사2궁수1힐러1/카드4장은 실행 코드와 같습니다. 진행 중 배치·전투·이벤트의 새 런 요청은 UI와 domain 양쪽에서 거부합니다. 기존 디버그 room_battle.tscn은 별도 씬으로 유지합니다.

## 37. RNG 분리

generator.rng는 맵 생성/발견 이벤트 종류/정복 reward/전략카드 reward,combat_rng는 시도별 battle seed 공급. AI·공격·처치 보상은 각 BattleManager.rng 사용. 맵 추가 보상 확인이 전투 RNG를 소모하지 않고 전투 랜덤이 생성기 RNG를 소모하지 않습니다. JS Math.random과 Godot seed에 대한 동일 결과는 보장하지 않습니다.

## 38. 신규 테스트

Phase9 6그룹: map/Encounter/실행 JS golden/navigation/progression/실제 room-session integration. 15층/120방/초기자원·길드·카드/쿼터·공개/중앙 milestone/stable IDs/고정seed/26종 pools/레벨 및모든배율/유닛 크기 간격/UnitData 불변/잘못된stats/RNG 독립/단발 발견/placeholder 미소비/잠금/포기/새 런/half경계·boss gate/정복단발·토큰·item hook·dead heal/실전 modes/승리치유·예비제외/중복결과/후퇴·새아군배치·손상적·죽은적/패배예비/Draw·RUN_ENDED/정복부활 순서. `tower_ui_smoke`는 마우스/터치 실제 Control 이벤트를 사용하고 전투 종료/비전투완료 일부는 명시적 fixture입니다.

## 39. Phase1~8 결과

| Phase | 검사 | 실패 |
| --- | --- | --- |
| 1 | 9,705 | 0 |
| 2 | 243 | 0 |
| 3 | 131 | 0 |
| 4 | 119 | 0 |
| 5 | 110 | 0 |
| 6 | 118 | 0 |
| 7 | 3,148 | 0 |
| 8 | 9,776 | 0 |
| 기존 합계 | 23,350 | 0 |

## 40. Phase9 결과

신규 자동검사 **15,755개 / 실패0**, 6그룹. Node 없이 전체 맵 생성 확인 포함. 실전 경로·일반/elite/boss 스탯 및 JS golden 비교를 포함합니다. 로그는 migration/phase9-validation.txt에 모았습니다.

## 41. 전체 검사 수/실패

자동전투/도메인 전체 **39,105개 / 실패0**. GUI는 별도 집계: 기존6개 합120개+신규 tower30개=150개/실패0, headless와 X11 각각 실행했습니다. 같은 GUI 검사의 두 실행 횟수를 도메인 검사 합계에 중복 합산하지 않았습니다. 에디터 로드/스크립트 parse 검사도 포함합니다.

## 42. GUI 검사

기존 deployment18,room17,turning18,strategy23,combat25,character19,신규tower30. 새 런→지도→마우스 방 선택→길드원 선택/자유 배치→실전 시작→승리 fixture→클리어 dim→지도→half기준 해금표시→다른방/진형복원→20초후 후퇴버튼→지도→같은방→손상적HP17/위치450,550 유지·죽은적 제외. 390×844에서는 가로/세로스크롤·touch배치·battle·TP·망고주스85HP·초월꾹누르기/방향/시전/hold복귀·TP재개·맵복귀를 검사했습니다.

## 43. 실제 창 검사

Godot4.6.3 + X11 dummy display :97,GL compatibility(Mesa software) 창에서 7개 GUI smoke 실행. 실제 Input.parse_input_event를 사용하는 마우스·터치 검사와 스크린샷을 확인했습니다. 사람이 별도로 수동 플레이한 검증이라고 주장하지 않습니다. 전투결과/20초경계는 시간·HP fixture로 만들었으며 자연 전투/전 캐릭터 상호작용은 기존 Phase8 자동검사가 담당합니다. desktop-map/deployment,mobile-map/tp 이미지가 migration에 있습니다.

## 44. 성능 검사

세 개 전체 map 생성+Encounter 검사 63.561ms(환경/부하에 따라 변함), Scene Node 증가0. 타워 UI는120방 모두 버튼으로 표시하고 총 UI Node 수221개(600 미만),3회 지도 rebuild 후 개수 불변. 정확한 Node 수·시간은 검증 로그 참고. 기존 Phase8 12vs12 혼합·기관총/번개/블랙홀·다수 투사체 stress도 다시 실행해 error/NaN/누수/종료 후 상태 변경 검사 통과. FPS 성능 목표나 웹과 동등성은 주장하지 않습니다.

## 45. 웹과 Godot의 남은 차이

비전투 방 콘텐츠/상점/모집/이벤트/휴식소/장비/강화/승급은 Phase10 미구현입니다. 따라서 실제 사용자 입력만으로 첫 층의 절반을 완료할 수 없는 현재 제한이 있고, 자동/GUI 진행 검사는 비전투 완료를 fixture로 공급합니다. 가짜 완료 버튼/보상을 만들지 않았습니다. recruitOffers/shopStock 같은 Phase10 상세 상품은 생성하지 않으므로 RNG 소비 순서는 웹과 다릅니다. item 정복 보상은 요청 상태로 남습니다. 신규 정식아트/VFX/사운드/저장파일은 없습니다. 플레이어 레벨/장비 성장 계산은 Phase10에서 별도 적용하며 새 런 level0에서는 현재 스탯과 일치합니다. 최신 배포 사이트를 이번 단계에서 새 브라우저로 조작했다고 주장하지 않으며 저장소 실행코드를 기준으로 했습니다.

## 46. 웹 SHA-256

작업 직전 dist19개 파일을 해시하고 완료 시 다시 비교했습니다. **19/19 일치, 변경0**. 전체값은 migration/phase9-web-sha256.json. 저장소 tracked 파일 diff도 비어 있고 모든 작업은 godot/ 내부입니다. godot/가 기존부터 untracked였으므로 git reset/clean을 복구 명령으로 사용하지 않습니다.

## 47. MIGRATION_NOTE

1. 층 정복은 현재 **플레이어 HP10% 회복**, guild maxHP 증가가 아닙니다.
2. 정복 heal 추가 보상은 사망 길드원도 회복시킵니다. 실제 실행 규칙을 보존했습니다.
3. JS visited의 clear 기록과 Godot visited의 진입 기록을 분리했고 완료 기록은 cleared_rooms입니다.
4. Phase10이 아닌 placeholder 진입은 콘텐츠를 시작하거나 소비하지 않습니다. event_active 정책은 실제 이벤트가 연결될 때 사용합니다.
5. UnitData는 불변, TowerEnemyStats만 인스턴스 수치. 플레이어 성장과 합치지 않았습니다.
6. map/combat RNG는 분리하며 웹 seed 동일 결과를 보장하지 않습니다.
7. 최종 적 위치·cast·whitelist만 보존하고 scene/투사체/장판은 저장하지 않습니다. 아군은 Formation 시작 위치.
8. 배치 간격58은 실제크기를 고려하지 않고 타워에 custom24 제한 없음.
9. RewardRequest(itemKind/receipt)를 Phase10에서 정확히1회 인벤토리로 지급해야 합니다.
10. 단일 방 옛 테스트의 floor_index=-1은 타워 진행 보상을 받지 않습니다.
11. map 생성 때 구성을 확정하고 재도전에서 RNG를 재소모하지 않습니다.
12. 성장/장비의 healingPower는 Phase10 소유; 현재 첫 승리 치유는 실제 Unit healing_power를 전달합니다.

## 48. Phase9만 되돌리는 방법

프로젝트를 종료한 뒤 저장소 루트에서 아래처럼 현재 폴더를 보관하고 시작 전 archive를 복원합니다. Phase1~8과 원본 웹을 유지합니다.

```bash
mv godot godot-phase9-backup
tar -xzf godot-phase9-backup/migration/phase8-before-phase9.tar.gz -C .
godot --headless --path godot --editor --quit
```

302개 시작 전 파일을 복원하고 Phase9 추가 파일/변경을 현재 프로젝트에서 제거하는 방식입니다. 백업 폴더는 별도로 남습니다. `git clean godot`은 이전8개 Phase까지 지우므로 사용하지 마세요.

## 49. Phase10 전에 필요한 사항

실제 RoomType 콘텐츠가 clear/consumed를 갱신할 한 번의 도메인 완료 API, 재입장 가능한 shop/recruit/promotion 소모 규칙, finite stock/recruit offers 실제 생성, reward_requests 단발 인벤토리 지급, 플레이어 level/stars/장비 stats 계산 계층, guild 치유 수치 제공, event_active 진입/종료 및 미완료 navigation 잠금, 실제 상점/영입 재화 차감, 이벤트/휴식소 완료 후 floor 평가를 연결해야 합니다. 기존 TowerController.refresh_progress와 정책은 준비돼 있으나 미구현 콘텐츠를 자동으로 완료하지 않습니다. **Phase10은 시작하지 않았습니다.**

직접 실행: Godot4.6.3에서 godot/project.godot 열고 F5, 또는 저장소 루트에서 `godot --path godot`. 검사: `godot --headless --path godot --editor --quit`, `godot --headless --path godot --script res://tests/test_runner.gd`, `godot --headless --path godot --script res://tests/tower_ui_smoke.gd`.
