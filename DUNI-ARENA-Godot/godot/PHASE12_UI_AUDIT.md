# Phase 12 작업 전 UI 조사

2026-10-14. 기존 Scene 7개와 UI 생성 스크립트 전체를 읽은 뒤 작성. 아래는 변경 전 구조이며 런/전투 규칙을 변경하지 않는다.

| 화면 | Scene / Control hierarchy | 현재 문제 / 유지할 정보 / 버튼 우선순위 |
|---|---|---|
| Main menu / Continue | main_menu.tscn → MainMenuScreen → Margin16/VBox/title/new/continue/status/ConfirmationDialog | 상단에 모두 집중. metadata 시간 없음. 새 게임·이어하기와 덮어쓰기 확인 유지; 이어하기 요약 먼저 읽히도록 정리 |
| Tower map / Gameover | tower.tscn → TowerScreen → Margin10/VBox/wallet/actions/Scroll/VBox15floors/HScroll/120buttons | event_type이 미발견 방에도 출력됨. 잠김·방문·선택 구분 약함. 장방형 스크롤+탭 충돌 검사 필요. HP/재화/생존 인원/층 해금·정복 유지 |
| Guild / Equipment / Upgrade | GuildManagementPanel → Panel/VBox/HScroll roster/details/upgrade/status/Scroll inventory/ConfirmationDialog | ID 비중 큼, 사망 표식 없음. 강화 다음 스탯 없음. 장비 효과는 tap dialog 지원. 개별 roster/슬롯/장착·재각인 계약 유지 |
| Deployment | deployment.tscn / DeploymentScreen → Margin12/VBox/title/status/HFlowactions/Board/legend/HScroll roster | 영문 규칙·ID·게이지 정보 밀집. 최소 board240, 모바일 action 줄바꿈. X40..380,Y40..760,최소58 실제 구역 유지; 선택/이동/제거/복원 오류 설명 필요 |
| Battle / Result | room_battle.tscn / RoomBattleScreen 및 TowerBattleScreen(코드 생성) → DeploymentScreen + HUD/trans strip/TP/management dialog | 결과 raw enum, enemy ID/좌표/시도 수 노출, 모든 Unit에 raw timer. 전투 중 배치 버튼/roster가 공간 차지. 후퇴·초월·시간·생존 수를 우선; 결과 UI는 이미 정산된 값만 표시 |
| Turning Point / Cards | TurningPointPanel → Panel/VBox/HFlow heading+resume/HScroll allies/HFlow stances/planScroll/cardScroll/HBoxuse+cancel+result | 작은 11~12pt 텍스트, 적 내부 ID·forecast 노출. 카드·아군 선택 유지, 4성향/남은 시간/사용 이유/재개와 후퇴 우선 |
| Transcendence | RoomBattleScreen transScroll/HBox buttons + trans_cutin + BattleManager draw direction | hold .16초·deadzone·1.15초 cast 규칙 유지. 조작 안내/방향/취소/ready 피드백 부족 |
| Recruit | TowerContentScreen → Margin12/VBox/heading/status/actions/Scroll/contentBox/HScroll/3buttons/reroll | 역할 없음, 수평 후보185x170. 구매·재화·리롤200G·구매 상태 유지 |
| Shop | 같은 contentBox → wrapped productButtons | 효과 설명 tap 없이 이미 표시. sold/구매부족 disable 유지; 긴 텍스트/터치 높이 검사 |
| Rest / Event / Promotion | 같은 contentBox → choices/selection/buttons/results | 선택 결과는 domain once. promotion 유지 대상/소비 대상/반환 장비 안내 없음. 설명 wrap 필요 |
| Prediction | contentBox team/stake/watch → runtime DeploymentBoard | 실행 중 navigation 잠금 유지. 완료 결과 표시가 payout 재실행하면 안 됨 |
| Save / Continue / Backup | SaveManager metadata/status_changed → main status / tower save_label / content storage_status | 실패/backup 짧게 표시. v1/user://saves/autosave.json/DUNI_ARENA 유지. Continue 생성/RNG 없이 metadata 확인 |
| AI debug | RoomBattleScreen Board/Panel/11ptLabel; unit click → actor id | 기본 노출. 기본 OFF·명시적 개발 toggle 필요, 검증 API 보존 |

기본 논리 viewport900×1000, tower는 실제 창 크기로 content_scale_size 갱신. canvas_items stretch, 60Hz simulation. 목표 검사: 1280×720,1280×800,1000×1100,390×844. Dialog 최소폭300과 fixed scroll 높이가 모바일 제약. Safe area는 Margin 기반으로 보강하고 중요한 버튼 최소44px 확보. UI 변경 전 603개 파일/웹19개 SHA256과 rollback archive 생성.

## 현재 전환
main → new/continue → tower map → room → deployment/battle 또는 content → settled result → map. unfinished battle/prediction 중 domain navigation이 막는다. 저장 load는 phase별 기존 route_loaded를 사용하며 select_room/settlement 재호출 금지. shop/recruit/event action은 controller.content_action 단일 경로.

## 웹 presentation 조사
`dist/strategy.js:102` 실제 TP panel은 시간/재개/선택아군/stance/cards/message를 표시하고 enemy forecasts는 표시하지 않는다. Godot 최종 UI도 forecast는 debug 전용으로 둔다.
`dist/combat.js:61`, `dist/app.js:166` impactPause는35/55/80ms와 shake, 기존 웹 accumulator를 정지한다. Phase12에서는 gameplay simulation 계약을 바꾸지 않기 위해 gameplay hit-stop을 추가하지 않고 flash/ring/읽기 전용 camera shake로 표현한다.

## 보호 경계
AI·전투·Ability·Resource·Save codec/validator/manager·schema·RNG·정산은 그대로 둔다. 새 presentation은 existing events/state를 읽으며 combat RNG를 소비하지 않는다. 장면/카메라/VFX는 결과를 표시할 뿐 transaction을 다시 실행하지 않는다. 사운드 작업 없음.
