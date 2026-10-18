# Phase 10 완료 보고 — 타워 비전투 콘텐츠

기준일: 2026-10-13 UTC. 엔진: **Godot 4.6.3.stable.official.7d41c59c4**. 현재 저장소의 `dist/` 실행 코드를 읽고 실제 함수를 Node VM에서 평가했습니다. 웹 원본은 수정하지 않았습니다. Phase11 저장/불러오기, 최종 아트·사운드·VFX는 시작하지 않았습니다.

F5는 기존 Phase1~9 전투를 포함한 타워 지도에서 시작합니다. 신규 콘텐츠는 그 런과 같은 길드·재화·방을 사용합니다. 이전에 제공한 온라인 미리보기는 **Phase9 배포본**이며, 이번 작업에서는 재배포하지 않았습니다.

## 1. 생성 파일

| 파일 | 역할 |
| --- | --- |
| `scripts/item_data.gd`, `item_catalog.gd` | 공유 불변 장비 정의·10종 카탈로그 |
| `data/items/*.tres` 10개 | 실제 웹 장비 수치·가격·설명 |
| `scripts/item_instance.gd`, `inventory_service.gd` | 개별 아이템 ID·장착 소유·소비·보상 영수증 |
| `scripts/guild_member_combat_stats.gd` | 플레이어 성장·장비·영구 엄니 성장 계산, 비전투 치유 |
| `scripts/resource_transaction.gd` | 원자적 금화/토큰 차감·영수증 |
| `scripts/recruit_offer.gd`, `recruit_state.gd` | 방별 모집 후보와 리롤 revision |
| `scripts/shop_offer.gd`, `shop_state.gd` | 개별 판매 복사본과 판매 여부 |
| `scripts/event_state.gd`, `room_content_result.gd` | 순수 이벤트 상태·서비스가 발행한 완료 제안 |
| `scripts/prediction_state.gd`, `prediction_rules.gd` | 예측 구성·배팅·결과, 실제 59개 조합 |
| `scripts/tower_content_service.gd` | 모집·구매·장착·강화·승급·휴식소·이벤트 규칙 |
| `scripts/guild_management_panel.gd` | 길드/인벤토리·아이템 설명과 명시적 장착 버튼 |
| `scripts/tower_content_screen.gd` | 모집/상점/휴식소/이벤트/예측 기능 화면 |
| `tests/phase10_tests.gd`, `phase10_runner.gd` | 신규 도메인·전투 통합 검사와 독립 실행기 |
| `tests/tower_content_ui_smoke.gd` | 데스크톱 마우스·390×844 터치 입력 검사 |
| `tests/web_phase10_reference.cjs` | 실제 웹 함수를 평가하여 golden fixture 생성 |
| `migration/phase10-web-rules.json` | 10장비·6카드·26가격·59예측풀·936 성장/장비 표본 |
| `migration/phase9-before-phase10.tar.gz` | 작업 전 기존 Godot 파일 367개 정확한 복구본 |
| `PHASE10_REPORT.md`, `migration/phase10-*` | 보고·변경 목록·실행 로그·해시·화면 증거 |

신규 GDScript의 `.gd.uid`는 엔진 생성 식별자입니다. `.godot/` 캐시는 소스/복구 기준에서 제외합니다. 정확한 전체 경로는 `migration/phase10-file-changes.json`에 기록합니다.

## 2. 수정 파일

| 파일 | 변경 목적 |
| --- | --- |
| `project.godot`, `README.md` | Phase10 진입 설명·실행 안내 |
| `scripts/run_state.gd`, `guild_member_state.gd`, `room_state.gd`, `tower_run_state.gd` | 인벤토리·영수증·엄니 성장·방별 콘텐츠 상태 |
| `scripts/tower_controller.gd` | 실제 콘텐츠 라우팅·완료 API·보상 소비·독립 예측 전투·게임오버 |
| `scripts/tower_screen.gd`, `tower_battle_screen.gd`, `deployment_screen.gd`, `deployment_board.gd` | 콘텐츠/관리 화면 연결·성장 HP 표시·실제 창 크기 대응 |
| `scripts/guild_manager.gd`, `unit_combat_stats.gd`, `battle_unit_factory.gd` | 성장/장비 스탯과 runtime 효과 주입 |
| `scripts/unit.gd`, `unit_state_codec.gd`, `battle_settlement.gd` | 영구 엄니 성장 회수·성장 최대 HP 검증 |
| `scripts/battle_manager.gd`, `battle_result.gd` | 처치 시 장비 성장·생존자의 황금 토큰 보상 자료 |
| `scripts/equipment_combat_effects.gd`, `projectile_rules.gd`, `room_battle_session.gd` | 실제 장비 효과·굵은 송곳 판정·첫 시도 발동 |
| `scripts/strategy_card_data.gd`, `data/strategy/*.tres` 6개 | 실제 카드 상점 가격 |
| `tests/test_runner.gd`, `phase9_tests.gd` | 모든 Phase 동시 실행·Phase9의 보류 아이템 보상 계약 갱신 |

기존 Phase1~8 검사 파일은 수정하지 않았습니다. Phase9에서는 새로 구현된 아이템 보상을 더 이상 “미지급”으로 검사하지 않고 실제 한 개 지급·fulfilled로 검사합니다. 기존 검사 수·그룹은 유지합니다.

## 3. 비전투 room 완료 API

`TowerController.content_action(action, options)` → `TowerContentService` 검증/효과 → 서비스가 발행한 `RoomContentResult` → `complete_room_content(room_id, result)`입니다. 완료 API는 현재 방·비전투 유형·동일 발행 객체·미처리 receipt를 검증하고 `cleared/consumed`·보상 영수증·progression/conquest·결과 화면 상태를 단발로 처리합니다. UI는 방 상태나 재화를 직접 변경하지 않습니다.

보상 선택/구매 효과와 완료 제안은 동일한 동기 호출에서 실행됩니다. 완료 제안을 임의로 만드는 UI 호출은 거부합니다. 구매/리롤은 방 완료와 별도 트랜잭션입니다.

## 4. RecruitOffer 구조

`offer_id`, `unit_type_id`, `token_price`, `purchased`. `RecruitState`는 `revision`과 `offers`를 소유합니다. ID는 방 ID/revision/slot 기반이며 Node 이름에 의존하지 않습니다.

## 5. 모집 규칙

`dist/tower.js:194–208,548` 기준 전체 26종을 셔플한 첫 3종으로 **서로 다른 후보 3명**을 만듭니다. 각 후보는 한 번 영입합니다. 비용은 토큰만 사용합니다. 전사2, 암살자3, 히어로4, 폭탄4, 성기사4, 포식자5, 나머지 초기6종2/추가종3 규칙을 기존 26종 Resource와 검사했습니다.

영입은 새 `member_id`를 생성합니다. 같은 종류를 이미 보유해도 별개 길드원입니다. 초기 Lv0/0성/기력5/기본 HP/두 게이지0/기본 성향/빈 고유 상태/엄니 처치 수0을 사용합니다. 기존 후보가 첫 맵 생성 때 확정되며 재방문에 유지됩니다.

## 6. reroll 규칙

200G, 횟수 제한 없음. 성공 시 revision 증가·새 후보/구매 상태 생성. 실패는 금화·후보·receipt·content RNG를 변경하지 않습니다. UI에 실제 비용과 사용 가능 여부를 표시합니다.

## 7. ShopState 구조

`offers: ShopOffer[]`. 한 복사본은 `offer_id`, `category(equipment/card)`, `kind`, `gold_price`, `purchased`를 가집니다. 같은 종류 재고 두 개도 각각 별도 행/상태입니다.

## 8. 실제 stock 규칙

`ensureTowerShopStock`, `towerShopCopies` 기준 첫 진입 때 장비 2~3종·카드 2~3종을 각 풀에서 중복 없이 선정합니다. 각 종류는 20% 확률 2개, 나머지 1개. 4~12개의 개별 판매 행을 생성합니다. sold 복사본 재구매 불가, 재방문/렌더에 동일 재고 유지, 상점 리롤은 웹에 없으므로 구현하지 않았습니다.

카드 가격: 망고주스70G, 전투회피140G, 충전170G, 보호막120G, 철벽방어220G, 도발160G.

## 9. ItemData 전체 목록

웹 `TOWER_ITEMS`, `dist/tower.js:11–22`의 정확한 이름/ID/설명을 사용했습니다. 사용자 예시의 “활력 토템”, “포식자의 송곳니”와 다른 실제 명칭을 보존합니다.

| kind | 실제 이름 | 가격 | 웹 설명 |
| --- | --- | ---: | --- |
| `vital` | 생명의 부적 | 90G | 최대 HP +20% |
| `fang` | 날카로운 송곳니 | 100G | 공격력 +15% |
| `boots` | 바람 장화 | 80G | 이동속도 +10% |
| `reengrave` | 재각인 | 120G | 선택한 유닛의 장비를 모두 회수 · 일회성 |
| `greenNecklace` | 초록 목걸이 | 110G | 주는 치유 · 받는 치유 +10% |
| `goldToken` | 황금 토큰 | 120G | 참전 후 생존하여 승리하면 🪙 +40G |
| `vigorTotem` | 원기 토템 | 160G | 5초마다 주변 아군 HP 6 회복 · 자신은 3.6 회복 |
| `chargeTotem` | 충전 토템 | 180G | 4초마다 주변 아군 궁극기 +4% · 자신은 +2.4% |
| `predatorFang` | 포식자의 엄니 | 200G | 처치마다 이 유닛의 공격력 영구 +1.5% |
| `thickAwl` | 굵은 송곳 | 180G | 새 전투 시작 시 오른쪽으로 송곳 투척 · 적중한 적 1명 4초 기절. 후퇴한 방 재전투에서는 발동하지 않습니다. |

## 10. ItemInstance

런 단위 증가 정수 `item_id`, `kind`, `equipped_to_member_id`(미장착은 빈 문자열), `consumed`. 소유권은 RunState 인벤토리에 있고 Unit에는 runtime 파생 효과만 전달합니다.

## 11. Inventory

`RunState.inventory`, `next_item_number`, `inventory_receipts`. 동일 kind 여러 개를 허용합니다. 표시 목록은 미장착·미소비만 반환합니다. 장착품은 인벤토리 소유를 유지하며 해당 길드원의 장비 목록으로 표시합니다. 소비된 재각인은 감사용 tombstone으로 남지만 소유/효과/표시 목록에서 제외합니다. 웹은 해당 복사본을 배열에서 제거합니다.

## 12. 장착 규칙

지도 길드 관리/전투 전 정비/상점에서 가능. member/item 존재·미소비·미장착·인벤토리 무결성·슬롯을 검사합니다. **죽은 길드원에도 장착 가능**한 웹 동작을 보존합니다. 장착으로 최대 HP가 증가해도 현재 HP는 자동 회복하지 않습니다. 아이템 터치 → 설명창 → 장착/사용 확인 순서입니다.

## 13. 슬롯 규칙

`2 + clamp(stars,0,2)` → 기본2/1성3/2성4. 같은 종류 장비도 중복 장착할 수 있으며 개별 복사본은 동시에 둘에게 장착할 수 없습니다.

## 14. 재각인

120G 소비품. 선택한 길드원의 장비가 있어야 사용 가능. 전체 장비의 기존 item ID를 유지한 채 미장착으로 반환하고 재각인을 소비합니다. 감소한 최대 HP에 현재 HP를 clamp합니다. 일반 자유 해제/장비 이동은 허용하지 않습니다.

## 15. 생명부적

정확한 이름은 **생명의 부적**. 각 복사본 최대 HP×1.2. 성장 배율 적용 후 곱하고 마지막에 JS식 반올림. UnitData는 그대로입니다.

## 16. 송곳니

정확한 이름은 **날카로운 송곳니**. 각 복사본 공격×1.15. 영구 엄니 처치 성장과 별개의 장비 배율입니다.

## 17. 바람장화

각 복사본 속도×1.1. 전투 생성 시 기존 random movement speed에 `계산 speed / UnitData.move_speed`를 적용합니다.

## 18. 초록목걸이

복사본별 healingPower×1.1. outgoing와 incoming 각각 적용합니다. 자기 치유는 source와 target가 같아 두 배율이 적용되어 한 개 장착 시1.21. 망고주스/첫 승리/비전투 회복처럼 시전자가 없는 치유는 incoming만 적용합니다.

## 19. 활력토템

웹 명칭 **원기 토템**. 5 simulation seconds, 반경165×현재 scale, 한 복사본 기준 아군6/자신3.6. 효과를 부여/받는 각각의 healingPower를 적용합니다. 웹 `alive()`/현재 faction 조건에 맞춰 살아 있는 포획된 아군도 범위 안이면 받습니다. 원기 토템의 실제 남은 타이머는 whitelist로 회수합니다.

## 20. 충전토템

4 simulation seconds, 반경165×현재 scale, 한 개 기준 아군+4%p/자신+2.4%p. 실제 `UltimateController.gain`과 효율 경로를 사용하므로 CC/시전 등 Phase8 차단 규칙을 우회하지 않습니다. chargeTotemClock도 whitelist 대상입니다.

## 21. 포식자송곳니

웹 명칭 **포식자의 엄니**. 적 처치마다 장착 개수만큼 `fang_kills` 증가. 공격 배율은 `1 + fang_kills×0.015`로 선형 누적합니다. runtime 공격을 즉시 갱신하고 정산 때 개별 member에 회수합니다. 장비를 회수해도 런 동안 누적 성장 유지. 이미 죽은 적 중복 사망은 성장을 재발동하지 않습니다.

## 22. 굵은송곳

첫 전투 준비 완료 후 우측 `(1050,0)` 방향으로 발사. x+30, damage0, power45, 적중 반경28, 시각 scale1, life1.1. 첫 대상 접촉 시 사라집니다. 무적 → 거울 반사 → 공통 패링을 확인하고 통과하면 stun4초. 공통 swept Projectile/Clash/Status 사용.

**중요 차이:** 웹 `launchOpeningEquipment()`는 `room.combatStarted` 또는 저장 enemyState가 있으면 발사하지 않습니다. 따라서 같은 방 후퇴/패배 재도전에는 재발사하지 않습니다. 이번 Godot도 첫 시도만 발사합니다. “재도전마다 발동”이라는 일반 설명으로 이 예외를 바꾸지 않았습니다.

## 23. 기타 실제 item

누락되기 쉬운 열 번째는 **황금 토큰**. 실제 참전·생존·미클리어 방 첫 승리 때 장착 개수당40G. 예비/사망/후퇴/패배/이미 지급된 결과에는 지급하지 않습니다. 기존 전투 gold/token 보상과 같은 controller 단발 정산에 더하며 재지급하지 않습니다.

## 24. 장비 중첩

HP/attack/speed/healing은 곱셈, 황금 보상은 합계, 토템/송곳/엄니는 개수. 동일 kind unique 제한 없음. 두 장화1.21, 두 목걸이 healingPower1.21, 두 엄니 처치당3% 등이 검사됩니다.

## 25. GuildMemberCombatStats

`UnitData + member(level/stars/fang_kills) + InventoryService` → 새 `UnitCombatStats`. `TowerEnemyStatsAssembler`와 별도입니다. 실제 타워 길드원 생성 경로가 사용합니다. Phase2의 초기 비교용 standalone RunState(tower 없음)는 기존 기본 스탯 계약을 보존합니다.

## 26. level 성장

유효 레벨 `clamp(level,0,10)+clamp(stars,0,2)×40`.

| 스탯 | 실제 식 |
| --- | --- |
| maxHP | `round(baseHP × (1 + effectiveLevel×0.12) × gearHP)` |
| attack | `baseATK × (1 + effectiveLevel×0.08) × gearATK × (1 + fangKills×0.015)` |
| defense | `baseDEF × (1 + effectiveLevel×0.08)` |
| speed | `baseSPD × (1 + effectiveLevel×0.02) × gearSPD` |

선형 성장입니다. 기본 방어력이 일반 피해 감소에 직접 쓰이지 않는 공통 전투 동작은 바꾸지 않습니다.

## 27. 강화 비용

Lv0~10, 다음 비용 `80 + 현재 level×20`. 0→10 합계1700G. 최대에서 강화 거부. 지도 관리·전투 전 정비만 가능하며 상점의 장비 관리 창에서도 강화는 비활성입니다.

## 28. 죽은 member 강화 처리

웹은 다른 생존 길드원이 있어 런이 진행 중이면 죽은 member 강화도 허용합니다. 최대 HP 증가량을 `healTowerMemberHp(...,revive=true)`로 회복하여 **incoming healingPower까지 적용**합니다. 따라서 사실상 부활할 수 있습니다. 모두 사망해 게임오버이면 강화로 되돌릴 수 없습니다. 폭탄의 사망 자폭 상태도 초기화합니다.

## 29. stars 성장

별 하나당 유효40레벨. 기본 UnitData를 바꾸지 않으며 별0~2와 일반level0~10을 따로 계산합니다. 별1/Lv0의 HP는 기본×5.8, attack/defense×4.2, speed×1.8입니다.

## 30. 승급 조건

살아 있는 서로 다른 member3명, 동일 type·stars, 각각 Lv10, stars<2. 선택 순서를 유지합니다. 실패는 member·장비·성급·HP·방 사용 횟수를 변경하지 않습니다.

## 31. 승급 결과

첫 member ID와 해당 장비 유지, stars+1/Lv0. 다른 둘은 길드에서 제거. 첫 member HP는 새 최대 HP 증가량만큼 **raw 증가**(강화와 달리 healing bonus 없음), 최대치 clamp. 기력/게이지 등 기준 개체의 나머지 상태 유지.

## 32. equipment 반환

소모된 두 member의 장비를 기존 ID 그대로 미장착 인벤토리로 반환합니다. 마지막 FormationState에서도 제거된 member ID를 삭제합니다. 새 member ID나 장비를 복제하지 않습니다.

## 33. Rest

| 선택 | 실제 효과 |
| --- | --- |
| 플레이어 회복 | HP+15, 최대 clamp |
| 자원 | 350G/토큰1 |
| 길드 회복 | 생존 member HP35%, incoming healingPower, 기력 변화 없음 |
| 부활 | 선택한 사망 member1~2명 HP20%, incoming healingPower, 기력 변화 없음 |

선택 성공 시 clear/consume. 선택 없이 지도 복귀하면 미클리어. 부활 대상 중복/살아 있는 대상 거부, 사망 폭탄 상태 초기화.

## 34. Promotion room

첫 진입 random limit1~3, used/limit 재방문 유지. 완료 버튼은 승급0회라도 clear. 남은 횟수 있으면 다시 방문 가능, 전부 사용하고 완료하면 consumed. 재입장 시 선택 목록만 초기화합니다.

## 35. HotSpring

온천욕은 생존 HP10%/기력+2, incoming healingPower, 사망 제외. 복권200G 후 9개 균등 pool: item1/item2/250G/token3/500G/card/unit/100G/300G. 각각 실제 인벤/카드/member/재화 지급. 유닛은 새 member. 중복 아이템 허용. 완료는 한 번이고 결과 화면에 머문 뒤 지도로 갑니다. 실패 복권은 RNG도 미소비.

## 36. Supply

표시 명칭 **보물상자**. 플레이어 HP10 / 생존 HP10%·기력1 / 300G·token1 / item 또는 card 중 처음에 결정한 한 보상. loot kind는50:50, 해당 전체 pool에서 하나 선정. 선택 성공 clear/consume·지도 복귀. 다시 그 방을 열어도 추가 지급하지 않습니다.

## 37. Prediction

`spectator.js` 실제 59개 조합 사용. 55% 2팀/나머지3팀, 70% 2명/나머지3명. 세 번째 구성원은 26종에서 무작위. 배팅50/100/200G(기본100), 선택 팀과 금액을 따로 조작.

실제 full/common 자동전투를 별도로 생성하고 길드 세션·플레이어 사망 손실·기력 정산·TP/전략 개입과 격리합니다. 승리예측 성공은 stake×2와token1, 무승부stake반환, 실패0. 첫 실행 때 차감, 결과 receipt 한 번 clear/consume. 이벤트 전투를 끝낼 때까지 지도/포기 이동 잠금. Node를 이벤트 state에 저장하지 않으며 controller/UI에만 현재 watch battle 참조가 있습니다.

## 38. 일반 Event

실행 코드의 이벤트는 prediction/promotion/hotSpring/supply **4종**입니다. 없는 “일반 랜덤 이벤트”를 추가하지 않았습니다. 기존 미조우 이벤트 가중치4/조우1 선정과 방 진입 때 한 번 확정하는 규칙을 유지합니다.

## 39. EventState

`event_type`, `choices`, `selected_choice`, `resolved`, `reward_receipt`, `outcome`, 승급limit/used/selected_members, 보물kind/reward, `PredictionState`. 모든 효과/대상 ID/결과는 데이터로 보관하고 Scene Node/Timer/Tween은 넣지 않습니다.

## 40. event_active

미완료 이벤트 중 지도/다른 방/새 런 거부. 완료 후 content_result/route로 전환하여 지도 복귀 허용. 웹처럼 예측 전투 시작 전 이벤트 화면에서 탐험 포기는 가능하지만 watch battle 진행 중에는 금지. 기존 Phase9의 전투 배치/전투 중 new-run/abandon 차단도 보존합니다.

## 41. 전략카드 보상

상점/온천/보물상자와 기존 미니보스 보상이 `RunState.give_strategy_card`를 사용합니다. 같은 kind도 각기 새로운 card_id/사용 기록을 가집니다. 초기 망고/회피/보호막2장과 기존 Phase6 제한 규칙을 유지합니다. 인벤토리에도 미소비 카드 목록 표시.

## 42. RewardRequest 처리

Phase9 `reward_requests` item branch를 `InventoryService.consume_reward`로 실제 지급합니다. `reward:<reward_id>` receipt/itemID 기록과 fulfilled로 중복 차단. 화면 재렌더나 같은 request 재호출은 아이템을 추가 생성하지 않습니다. 손상된 인벤토리/잘못된 kind는 fulfilled하지 않고 유지합니다.

## 43. ResourceTransaction

가격 비음수·현재 재화·런 유효·receipt 미사용을 검사하고 금화/토큰을 한 번에 차감한 뒤 영수증을 기록합니다. 일련의 콘텐츠 동기 호출이므로 UI 차감 → 뒤늦은 상품 생성 구조가 아닙니다. 후보/재고/member/inventory 검증은 차감 전에 합니다.

## 44. 실패 트랜잭션

부족 재화/purchased/sold/잘못된 member/item/슬롯초과/잘못된 인벤토리/잘못된 예측 구성은 거부합니다. 실패 시 금화·토큰·RNG·receipt·방 진행 유지. 리롤·복권 RNG는 실패 검증 이후에만 소비하고 예측 생성 실패 시 combat RNG도 복원합니다. 의도적으로 런 종료가 확인된 경우에는 gameover 상태로 전환합니다.

## 45. Room clear/consumed

| 콘텐츠 | clear 시점 | consumed | 재방문 |
| --- | --- | --- | --- |
| 모집/상점 | 완료/지도 버튼 | false | 가능, 후보/재고 유지 |
| 휴식소 | 선택 성공 | true | 완료 표시만 |
| 온천/보물상자/예측 | 선택/경기 결과 | true | 완료 표시만 |
| 승급 | 완료 버튼 | 잔여 횟수 없을 때 | 남은 횟수 있으면 가능 |

발견(discovered)·진입(visited)·완료(cleared)·소비(consumed)를 구분합니다. 이미 완료한 방은 기존 지도처럼 어둡게 표시합니다.

## 46. progression 연결

완료 API → Phase9 `refresh_progress` → cleared_count/ceil(total/2)·보스 조건 → 층/챕터 해금 → 정복 단발. 새 progression 계산을 UI에 만들지 않았습니다. 실제 모집/상점/전투 완료 조합으로 다음 층이 해금되는 GUI 경로도 검사합니다.

## 47. 장비→전투 연결

GuildManager.member_stats → BattleUnitFactory.guild_placement의 별도 combat_stats → Unit 생성/기존 상태 주입. HP/공격/방어/속도/healingPower/보상/장비 개수가 들어갑니다. maxHP 증가 후 snapshot은 UnitData 기본HP가 아닌 실제 길드 계산 최대HP로 검증하여 정산이 거부되지 않습니다. UnitData는 불변.

## 48. 치유 배율 연결

Runtime `CharacterAbility.restore_hp`(source×target), `StrategyEffects.heal`(target), 정산 첫 승리 healing(target), 비전투 `GuildMemberCombatStats.heal`(target)로 의미를 맞춥니다. 실제 힐러 준비→발동의22 회복량×1.21, 망고, 토템, 첫 승리, 강화/부활/정복을 검사합니다. 부활 허용은 각각의 호출 경로로 명시하며 일반 치유로 죽은 유닛을 살리지 않습니다.

## 49. 토템 연결

기존 Phase8 lifecycle simulation hook을 사용합니다. delta가0인 TP hold/초월 정지에서는 감소·효과 없음. 여러 개는 한 timer에서 개수만큼 효과. 장비를 처음 장착할 때만 clock5/4를 설정하고 회수/재장착·후퇴 snapshot 범위는 웹 조건을 따릅니다. 디버그 combat event에 pulse 발동을 기록하지만 웹 픽셀 VFX는 복제하지 않습니다.

## 50. 전투 시작 장비 효과

RoomBattleSession이 BattleManager 시작에 성공한 후 첫 시도 굵은 송곳을 한 번 등록합니다. 재도전은 웹 예외 때문에 송곳을 재등록하지 않습니다. runtime totem은 생성/주입 후 기존 sim loop에서 진행합니다. BattleManager가 종료되면 projectile/timer는 진행되지 않습니다.

## 51. persistence

아이템 소유/장착은 RunState. totemClock/chargeTotemClock은 CharacterPersistence whitelist. 엄니 성장은 member.fang_kills ↔ Unit.equipment_fang_kills ↔ result snapshot. HP·기력·게이지·성향 및 Phase4~8 상태 유지 계약 보존. 장비 투사체/일시적 Node는 RoomState에 저장하지 않습니다. Shop/Recruit/Event는 순수 RefCounted 데이터이고 파일 저장 기능은 없습니다.

## 52. 신규 테스트

9그룹: 웹 evaluated golden / 모집·상점 / 장비·성장 / 승급 / 휴식소·4이벤트 / 보상·거래 / 예측 / 전투 통합 / 잘못된 작업. 936 표본×10 스탯 필드에 실제 값 비교, 59개 pool 개별 type 비교. 100 고정 lottery seed에서 9가지 결과 모두 검사. 강화0→10/사망 강화·2성·회수 ID·영수증·실패 RNG·도메인 게임오버·HP 상한을 포함합니다.

전투 검사에는 힐러, 토템/포획, CC 차단, TP/초월 동결, 첫 승리 healing, 황금 토큰, 송곳 수치·stun·재도전 미발동, 엄니 영구 성장·재도전을 포함합니다. 기존 공통 패링/보호막/궁극기/캐릭터·맵 검사도 모두 실행합니다.

## 53. Phase1~9 결과

| Phase | 검사 수 | 실패 |
| --- | ---: | ---: |
| 1 | 9,705 | 0 |
| 2 | 243 | 0 |
| 3 | 131 | 0 |
| 4 | 119 | 0 |
| 5 | 110 | 0 |
| 6 | 118 | 0 |
| 7 | 3,148 | 0 |
| 8 | 9,776 | 0 |
| 9 | 15,755 | 0 |

## 54. Phase10 결과

9그룹 **10,255개 검사 / 실패0**. 독립 Phase10 runner와 전체 runner 모두 통과했습니다.

## 55. 전체 검사 수/실패

도메인/전투 **49,360 / 0**. GUI는 기존150 + 신규46 = **196개 독립 검사**를 headless와 X11 각각 실행했습니다. 이는196을 두 환경에서 검사한 것이며 도메인 검사 수와 합산해 성능을 과장하지 않습니다. 로그는 `migration/phase10-tests.log`, `phase10-*-*.log`.

엔진 import/parse/scene load 및 전체 검사가 통과했습니다. XDG 디렉터리를 /tmp에 지정해 샌드박스 밖 홈 폴더에 쓰지 않았습니다.

```bash
env XDG_DATA_HOME=/tmp/duni-godot/data \
  XDG_CONFIG_HOME=/tmp/duni-godot/config XDG_CACHE_HOME=/tmp/duni-godot/cache \
  godot --headless --path godot --editor --quit

env XDG_DATA_HOME=/tmp/duni-godot/data \
  XDG_CONFIG_HOME=/tmp/duni-godot/config XDG_CACHE_HOME=/tmp/duni-godot/cache \
  godot --headless --path godot --script res://tests/test_runner.gd
```

## 56. GUI 검사

기존 deployment18/room17/turning18/strategy23/combat25/character19/tower30, 신규 tower_content46 모두 통과. 신규 검사에서는 실제 버튼/터치 입력으로 영입·리롤·구매·설명→장착·강화·배치·전투·정산·지도·층 해금·휴식소·온천·승급·예측 선택/관전/결과를 확인합니다.

stock/승급 eligible member/방 종류 및 전투 종료 일부는 **명시적 테스트 fixture**를 사용합니다. UI에서 클리어를 가짜로 설정하지 않고 실제 콘텐츠 API와 BattleResult 경로를 거칩니다. 랜덤 stock·실제 전투·보상 계산은 도메인 테스트에서 별도로 검사합니다.

## 57. 실제 창 검사

X11 + Mesa llvmpipe + GL Compatibility에서 실제 Godot 창을 렌더하고 프로그램이 넣은 InputEventMouseButton/InputEventScreenTouch로 위 흐름을 검사했습니다. 데스크톱1000×1100, 모바일390×844. 화면 캡처를 직접 확인했고 길드창 과대 높이/아이템 설명 줄바꿈을 수정했습니다. 타워의 UI 논리 크기는 실제 창 크기를 따르고 전투장800 논리 좌표는 유지합니다.

**사람이 수동으로 플레이한 검증으로 주장하지 않습니다.** 자동 입력 기반 실제 창 검증입니다. V-Sync 미지원 경고만 있으며 사운드는 범위 밖이므로 Dummy driver 사용. 스크립트 오류/Node 누수 경고는 없습니다.

## 58. 웹과 Godot의 남은 차이

- 최종 웹 디자인·픽셀 효과·영입/승급 컷신·재화 이동 연출·사운드는 이전하지 않았습니다. 기능 디버그 UI입니다.
- Source web는 전역 Math.random 한 스트림, Godot는 map/combat/content RNG 분리. 동일 seed 동일 웹 결과를 주장하지 않습니다.
- 재각인 소비 복사본은 Godot에 tombstone 유지, 웹은 제거. 사용자에게 보이는 소유/장착/소비 결과는 동일.
- 강화/장비의 실제 플레이 경로는 타워 member stats를 사용하고 옛 standalone 비교 모드는 Phase1~2 테스트 계약대로 기본 stats를 유지합니다.
- Phase1~9 보고의 기존 공통 전투·AI·UI 근사/미이전 사항은 여전히 해당 보고서에서 유효합니다. 이번 단계에서 전체 전투를 다시 작성하지 않았습니다.
- 이전 미리보기 링크는 Phase9입니다. 현재 작업 내용은 저장소의 독립 Godot 프로젝트에서 실행하며 아직 웹 재배포하지 않았습니다.
- 저장/로드, 정식 인벤토리 아이콘 바/최종 화면 연출은 Phase11 및 후속 작업입니다.

## 59. 웹 SHA-256

작업 전후 `dist/` **19개 모두 SHA-256 일치**. `migration/phase10-web-sha256.json`은 각 before/after·일치 결과를 기록합니다. 기존 추적 웹 파일 변경 없음(`git diff` 확인). 작업 전 Godot367파일 hash와 최종 변경 경로도 보관합니다.

## 60. MIGRATION_NOTE

1. 굵은 송곳은 신규 battle instance마다가 아닌 **방 첫 전투 시도만** 발동하는 실제 웹 예외를 보존합니다.
2. 죽은 member 강화는 revive 허용·incoming healingPower 적용. 모두 사망한 런은 강화로 부활 불가.
3. 승급 HP 증가는 raw delta, 강화/휴식소/정복 치유와 혼용 금지.
4. floor conquest는 guild maxHP 증가가 아닌 **player HP10% 회복/전체기력1/추가보상**. dead member도 extraheal20%에서 부활 가능. Phase9 실제 규칙 보존.
5. 재각인 tombstone과 영수증은 저장 버전에서 직렬화/정리 정책을 정의해야 합니다.
6. 최초 stats는 UnitData 불변·플레이어 성장/타워 적 성장 분리. settlement HP 검증도 파생 maxHP를 사용해야 합니다.
7. 원기/충전 토템 clock은 whitelist 지속 상태. Scene/timer/awl projectile 저장 금지.
8. 예측은 독립 관전 전투이며 tower guild 비용/사망/에너지/TP를 적용하지 않습니다.
9. shop/recruit clear와 consumed는 다르며 같은 방 재방문 시 RNG 재소비 금지.
10. Phase9 보류 RewardRequest가 이제 바로 실제 아이템으로 fulfill됩니다. 보상 버튼은 진행/보상 설명이며 재지급 버튼이 아닙니다.
11. 실제 아이템 명칭은 “생명의 부적/날카로운 송곳니/원기 토템/포식자의 엄니/황금 토큰”입니다. 오래된 표기보다 실행 정의 사용.
12. UI 표시는 순수 규칙층과 분리. 창 크기 대응은 전투 논리 좌표나 배치 규칙을 바꾸지 않습니다.

## 61. Phase10만 되돌리는 방법

Git의 Godot 폴더는 작업 전부터 untracked였으므로 `git reset/clean`을 사용하지 마세요. 다음은 Phase10 폴더를 보존한 뒤 작업 직전367파일로 정확히 복구합니다. 저장소 루트에서 실행합니다.

```bash
cp godot/migration/phase9-before-phase10.tar.gz /tmp/duni-phase9-restore.tar.gz
mv godot godot-phase10-backup
tar -xzf /tmp/duni-phase9-restore.tar.gz -C .
```

archive 항목은 `godot/project.godot` 등 저장소-relative 경로입니다. 백업367개 모두 작업 전 SHA-256과 일치하는지도 검증했습니다. `godot-phase10-backup`은 나중에 필요할 때 다시 사용할 수 있습니다. 기존 웹에는 영향 없습니다. 재생성되는 `.godot/`는 다시 import합니다.

## 62. Phase11 저장 시스템 전에 필요한 사항

- Run/Tower/Room/Enemy/Guild/Formation/Card/Inventory/Event/Shop/Recruit의 schema/version과 ID·counter 직렬화 정의.
- receipt·fulfilled·purchased·consumed·승급 제거 ID·tombstone을 로드해도 중복 지급되지 않도록 검증.
- RNG 분리 스트림 state와 미완료 콘텐츠/예측 경기 저장 허용 시점 정의. Scene 전체 저장과 도메인 snapshot을 혼동하지 않기.
- CombatStats는 파생 데이터로 재계산하고 UnitData Resource를 저장 런 수치로 덮어쓰지 않기.
- 실제 runtime 시전/포획/조종 whitelist와 장비 timer의 저장 시점/ID 재연결 테스트 설계.
- 손상된 inventory ownership/없는 member/불일치 stars/잘못된 receipt/가격 데이터를 로드 경계에서 거부/보정할 정책 결정.
- 온라인 미리보기 갱신은 이번 작업과 별도 배포입니다.

**Phase11은 시작하지 않았습니다.**
