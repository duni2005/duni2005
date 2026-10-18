# Phase12.5 원본 실화면 조사 / 변경 전 비교

2026-10-15. UI 변경 전 저장소 `dist/`를 localhost8125에서 Chromium으로 실제 실행했다. HTML/CSS를 다시 만들어 찍지 않았다. 기존 public UI 함수에 테스트 상태를 공급해 입장/배치/TP/초월/결과를 만들었다. 실제 타워 자연 플레이 전체를 수행한 영상으로 주장하지 않는다.

HTML: 1280×720와390×844, 50PNG, pageerror0. `migration/phase125/html/manifest.json`에 screenshot과 실제 computed style/rect 기록. Godot Phase12: 같은 viewport의46개 새 캡처, `before/manifest.json`. 각 capture script와 실행 로그를 함께 보관. baseline 전체 파일 SHA와 기존 source backup도 이 시점에 생성했다. 정적 숫자/AI/저장/웹은 보호 대상.

## 직접 관찰한 디자인 언어

- background #101619, 기본 글자 #edf1ef. Phase12의 남색 #0c1421과 다르다.
- header 높이48PC/44mobile, 얇은 하단선, DUNI 흰색/ARENA 주황.
- wallet은 #222b24 panel, #5a6550 1px border, radius8. desktop(x24,y133,w1232,h63), padding12×18. gold/token 큰26px 숫자, Player HP 막대.
- content의 dark forest panel, olive room cards와 gold 제목, orange #ffab66 primary CTA, 눌림/선택은 amber field. popup은 teal/forest와 밝은 border, 뒷배경 dim/blur.
- 카드 내부에 portrait→name/ID·level→HP bar→ultimate→energy pips→상태 순서. Phase12의 한 Button 문자열과 다르다.
- 일반 room은 `?` motif, room number/미탐험/진입 가능. 층 divider, reward button, locked floor 전체 opacity.
- TP는 desktop side panel / mobile 아래 compact panel. mobile panel(x6,y570.8,w378,h149), background #1d2d22, border #acb178, radius7, padding7×8. 적 forecast는 숨긴다.
- 원본 캐릭터 얼굴은 `renderEmoji` raster이나, renderUnit의 squash/recoil/weapon pose와26종 procedural weapon renderer, pixels.js tapered slash/particle/beam이 표현의 큰 부분이다. 원본이 별도 full-body pixel sprite를 쓰는 것으로 잘못 보고하지 않는다. Godot에서는 원본 weapon pose를 보존하면서 별도 pixel avatar silhouette로 문자 emoji 의존을 제거할 계획이다.

## 화면별 변경 전 차이 / 작업 기준

| 화면 | 원본 레이아웃·panel·계층 | Godot Phase12 실제 차이 | 이번 작업 기준 |
|---|---|---|---|
| 메인 | header, orange brand, 큰2행 headline, 3개 mode entry와 작은 설명 | 중앙 title와 너비600 plain button2개, 설명 계층 부족 | 실제 지원하는 새 게임/이어하기를 원본 depth/brand/tower-card 언어로 구성; 없는 모드는 만들지 않음 |
| Tower | wallet63px, forest map panel, 층 divider와6~10 olive room tiles, 숨김 motif ? | text button120개, navy, wallet가 Label | wallet·map frame·floor divider·room pictogram/status overlay, 진행 구조 유지 |
| Guild | 760px modal,3tabs, portrait/card grid4cols, HP·ult bar/energy pips | 가로 text strip+모든 detail이 동시 노출 | portrait/card, 탭/선택·스탯·장비 hierarchy, 같은 member 개체 유지 |
| Character selection | portrait deck과 배치 상태, canvas와 분리된 footer CTA | ID/HP 문자열 버튼 strip | portrait/member card와 선택 frame, 배치 상태·기력 pips |
| Deployment | wallet→arena(좌우 tint)→tools→character cards→orange start footer | navy grid, 작은 emoji/선, 많은 상단 buttons | 원본 arena 색·card hierarchy·orange start, 실제X380/58 unchanged |
| Battle | wallet, centered arena, 시간, compact trans avatars, 무기와body pose | 큰 label·emoji token, generic line/ring, 무기 없음 | character silhouette+원본 weapon phase, tile arena, readable compact HUD |
| TP | title/time/resume, 선택 유닛,4stance,card frames, mobile149px panel | 큰 ally strip·button stack로 정보 밀도 차이 | title/CTA/stance/card hierarchy, tactical overlay, real timer unchanged |
| Strategy card | 아이콘·이름·제한·selected state, 선택시 짧은 설명 | generic button에 두 줄 | 카드 pictogram/frame와 사용 이유, once/floor/cooldown 유지 |
| Transcendence | purple wave/directional energy, cut-in, joystick·deadzone | purple rectangle+line | caster isolation/energy/trail/impact·방향 선택 강화 |
| Shop | item portrait tile, effect/price/selection, tab inventory/upgrade | 긴 text button세로 | item/card thumbnail+effect/price/sold 구조 |
| Recruit | 캐릭터별 portrait/cost 카드, purchase·reroll | text candidates 가로 | 정식 portrait card와 가격·역할·purchased |
| Rest | 길드 strip와 휴식 choice card, HP/재화 상황 | text choice buttons | recovery/resource/revival pictogram·선택 hierarchy |
| Event | title/상황·choices·selected result | text button+Label | event card/choice/result frame; 콘텐츠 추가 없음 |
| Promotion | eligible guild grid, 기준/소비 대상, 승급 scene | text member list | portrait/level/star/기준·소비 표식, 결과 silhouette/반환 안내 |
| Upgrade | selected portrait+level/price/stat change | compact text preview | before→after stat rows와 primary CTA, stat 계산 그대로 |
| Equipment | 선택 portrait, slot/장비 thumbnail와 설명 popup | text inventory list | gear pictograms/slot cards/owner, 기존 재각인 정책 |
| Victory | center title+loss/reward와 생존/next | 하단 plain Panel/Label | victory banner/reward/survivors·진행 CTA |
| Defeat | 손실과Player HP·예비전력·return | 다른 텍스트만 있는 같은Panel | red/amber 결과 hierarchy, retry 설명 |
| Retreat | 별도1.9초 scene와title, 적 상태 유지 | 같은결과Panel | distinct teal retreat accent·보존 안내 |
| GameOver | dim→큰gameover/HP scene→종료 | map wallet에text | saved reason기반 종료 banner, 재정산 금지 |

수치 비교의 전체 raw rect/font/padding/background/border/shadow는 원본 manifest와 전후 PNG를 기준으로 한다. 스크린샷의 fixture 재화·ID·적 구성 차이는 UI가 같다는 근거로 사용하지 않는다. 원본 animation의 매 프레임/RNG 동일성은 이번 목표가 아니다.

## Gameplay/presentation 경계와 hit-stop 검토 계획

원본 `combat.js impactPause`: force>2 →80ms,>1.3 →55ms, 나머지35ms; cooldown160ms. `app.js`는 real dt에서 hitStop 감소 후 accumulator를 비우므로 world time에도 영향. 이를 Clock에 넣으면 같은 input의 RNG/HP/position과TP 예약 호출 횟수가 바뀔 수 있다. 이번에는 source값을 실제 probe로 기록하고, 동일 판정 paired 기준을 지키는 presentation freeze/impulse를 우선 검증한다. AI와 기존 BattleClock 파일은 보호하고, 차이를 숨기지 않는다.
