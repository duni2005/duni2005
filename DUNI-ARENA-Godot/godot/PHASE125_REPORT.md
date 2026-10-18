# Phase 12.5 — HTML 비주얼 비교 및 표현 계층 재작업

2026-10-15–16 · Godot 4.6.3.stable.official.7d41c59c4. 사운드 작업 없음.

## 검증 자료와 판단 범위

원본 실행 화면을 먼저 확보한 뒤 변경했다. `PHASE125_VISUAL_AUDIT.md`가 작업 전 조사이며, `migration/phase125/html/manifest.json`에는 원본 50장과 실제 CSS rect/font/padding/border/shadow가 있다. 원본은 저장소의 **수정하지 않은 dist/**를 localhost에서 Chromium으로 실행했다. Godot 변경 전 46장, 변경 후 46장을 PC1280×720와 모바일390×844에서 촬영했다.

- [화면별 HTML / Godot 이전 / Godot 이후 비교](migration/phase125/comparisons/index.html)
- [PC 주요 화면 비교](migration/phase125/comparisons/desktop-overview.png)
- [모바일 주요 화면 비교](migration/phase125/comparisons/mobile-overview.png)
- [26종 캐릭터/무기 시트](migration/phase125/after/characters-idle.png)
- `before/manifest.json`, `after/manifest.json`: 해상도·파일·변경 후 Control bounds. 변경 후 궁극기·초월 캡처에는 실제 cast/aim/Clock 상태도 기록했다.
- `capture_html.py`, `tests/phase125_capture.gd`: 재현 가능한 실제 게임 화면 fixture.

캡처는 실제 UI·도메인 함수를 호출한 통제된 fixture다. 자연 플레이를 모두 사람이 수행한 영상으로 주장하지 않는다. HTML과 Godot은 서로 다른 RNG/전투 궤적을 사용하므로 적 구성·프레임·배치 이후 위치가 완전히 같지 않다. 동일 viewport의 레이아웃·정보 계층·캐릭터·표현을 비교했다. 기능 검사 통과 자체를 시각적 동등성 점수로 사용하지 않았다.

## 원본 디자인 규칙과 Theme

| 요소 | 실제 HTML | 이번 Godot 반영 |
|---|---|---|
| 바탕/본문 | #101619 / #edf1ef | 남색 배경을 forest/charcoal로 교체 |
| Wallet | #222b24, #5a6550 1px, radius8, PC63px 높이 | custom WalletBar, 64px panel, 숫자·HP bar 3열 |
| Panel | forest/olive, 밝은 얇은 경계 | #1a2a25, radius7, olive border, 카드 그림자 |
| 주요 버튼 | #ffab66, 어두운 글씨 | 새 게임·전투 시작·재개 orange CTA |
| 선택/hover | amber / 밝은 olive | 선택 frame·배경과 hover 구분 |
| 카드 | portrait/name/level/HP/gauge/energy | 픽셀 초상·HP bar·5개 기력 pip·개별 번호·stance/장비 |
| 지도 | 가로 방 + 세로 층, 잠김/미발견/완료 구분 | pictogram/frame/status, 층 separator, 120방 유지 |
| TP | PC 측면 / 모바일 하단, 적 내부 계획 비공개 | PC 전장+측면 패널 / 모바일 하단 조작, 내부 forecast debug만 |

`ArenaUI` Theme와 `ArenaCard`, `ArenaIcon`, `WalletBar`를 재사용한다. 버튼마다 게임 로직을 만들지 않았다. 카드의 기존 Button text/name/API는 테스트·접근성용 의미 정보로 남기되 native 글자 레이어를 투명하게 하고 카드 계층을 직접 그린다. 최종 사용자 카드에서 emoji font 렌더링을 사용하지 않는다.

## 화면별 변경과 비교

| 화면 | 변경 전 관찰 | 변경 후 | 원본과 남은 차이 |
|---|---|---|---|
| Main | 기능 목록처럼 보이는 제목/두 버튼 | 원본 2행 headline·orange brand/CTA·Continue metadata | 원본의 별도 custom mode 등 이번 런 외 메뉴는 추가하지 않음 |
| Tower | 120개 텍스트 버튼/긴 wallet Label | 숫자 Wallet, 층 구분, 방 pictogram/frame/선택·잠금·완료 | 원본 tower 배경 장식/모든 hover animation은 동일 복제 아님 |
| Guild | 동일 type을 text로 구분 | 26종 초상 카드, 개인 HP/기력/성급/stance·장비 수 | 원본 3tab/다행 grid 대신 가로 roster+상세·인벤토리 구조 유지 |
| Equipment | 단순 문자열 목록 | 장비별 vector icon·이름·효과 카드, 확인 popup | 정식 개별 item art 대신 로컬 vector pictogram |
| Upgrade | 레벨·가격 문자열 | 선택 초상과 현재→다음 stat preview/가격 | stat 표는 기존 상세 텍스트를 유지 |
| Promotion | raw ID 텍스트 목록 | portrait/이름/개인 번호/Lv/성급과 선택 강조 | 기준/소비/장비 반환 안내는 기존 도메인 결과를 표시 |
| Recruit | 긴 문자 후보 버튼 | portrait·역할·가격·구매 상태 카드 | 원본 상세 카드 animation 전부는 미복제 |
| Shop | 효과·가격을 한 문자열에 나열 | item/card pictogram, 이름/효과/가격/sold 계층 | 별도 3D/아트 상품 없음 |
| Rest/Event | 기본 choice buttons | olive choice card·설명·자원/회복 결과 | 원본 장식 scene 전체를 다시 만들지는 않음 |
| Deployment | emoji 토큰·남색 debug board | 실제 판정 영역 tint, pixel body+원본 무기, HP·개인 식별, portrait roster | 배치 도구는 기능 우선의 버튼 strip 유지 |
| Battle | 작은 emoji/선/원 | forest arena, pixel silhouette/무기13pose, HP/상태·실제 공격 궤적 | 원본 모든 renderUnit 특수 pose를 프레임별로 동일 복제한 것은 아님 |
| TP | 많은 텍스트 버튼과 작은 전장 | title/time·portrait ally·stance·strategy card·orange resume | 모바일 panel은 원본149px보다 큼. 44px 조작과 설명 가독성을 우선 |
| Transcendence | purple dim+direction line | caster energy gathering·큰 directional streak/arc·cut-in·release flash | 원본 full screen typography/cut-in art와 동일하지 않음 |
| Victory | 하단 일반 Label | VICTORY title·색 frame·생존/보상·진행 | 보상/치유를 재계산하지 않고 정산된 결과만 표시 |
| Defeat | 승리와 같은 일반 panel | DEFEAT / GAME OVER 제목·손실·예비·재도전 안내 | 원본 결과 scene 전체의 animation은 미복제 |
| Retreat | 같은 결과창의 문구만 변경 | RETREAT title·별도 색·적 HP/위치 유지 안내 | 원본1.9초 후퇴 scene animation은 이식하지 않음 |
| Game Over | 긴 wallet 문자열 | 종료 원인 notice와 결과 제목, 저장 결과 유지 | 별도 원본 full-screen gameover montage 없음 |

전투 PC는 넓은 전장과 폭286 측면 조작부를 사용한다. 1280×720에서 arena logical800이688px 정사각형으로 표시된다. 모바일은 세로 배치로 전환한다. camera 변환의 역행렬을 입력 좌표에 적용해 zoom/focus가 actor 선택을 어긋나게 하지 않는다. 개발용 생성/AI overlay는 기본 숨김이며 F3 또는 기존 명시적 toggle로 연다.

## 캐릭터 visual / pose

원본 얼굴은 emoji raster이며 무기·몸 squash/recoil·특수 pose는 Canvas procedural renderer다. 존재하지 않는 원본 full-body pixel sprite를 복원했다고 주장하지 않는다.

1. 26개128×128 SVG pixel avatar를 작성했다. OS emoji font 대신 체형·의상·역할 색·전용 장비가 있는 실루엣이다. 탱크·위성·거울·폭탄·개구리·챌런·포식자는 몸 자체가 다르다.
2. 변경하지 않은 원본 `renderWeapon` 및 캐릭터 무기 renderer를 Chromium Canvas에서 실행해 캐릭터별13frame atlas를 만들었다. idle1 + windup4 + active4 + recovery4. 특대검은512px cell로 잘림을 피했다. 나머지는256px cell이다.
3. runtime `CharacterPainter`가 실제 attack phase/progress/facing/scale과 이동·기절·패링·궁극기 상태를 읽어 pose를 고른다. squash/recoil/bob/stealth alpha와 진영 marker를 조합한다.
4. dead는 즉시 사라지는 대신 남은 초상·밝은 band·scatter를 fade한다. retained death visual은 gameplay actor를 되살리거나 이동시키지 않는다.

`after/characters-{idle,windup,attack,recovery,stun,parry,ultimate}.png`의7개 sheet가 있다. 이는 pose와 motif의 시각 contact sheet이며26개 궁극기 자연 발동을 모두 수동 촬영했다는 뜻은 아니다. 실제 궁극기/캐릭터 기능 회귀는 기존 Phase8 검사로 유지한다.

## VFX / particle architecture

`CombatPresentation`은 기존 damage_resolved, unit_died, combat_events를 읽는다. `VisualParticles`는 독립 visual noise를 쓰는 bounded CPU particle simulation이며 source combat RNG를 호출하지 않는다. custom draw로 spark streak/shard/upward heal/smoke를 표현한다. 단순 ring event buffer만 추가한 형태가 아니다.

- ambient420 / 전체640 particle. 중요 burst는 남은 reserve를 사용할 수 있다.
- impact effect96 / damage number40. 같은 actor의 가까운 시간 숫자는 병합한다.
- 실제 cast/zone/공격/projectile telegraph는 transient particle queue와 **별도** live renderer로 그린다. particle cap 때문에 궁극기 범위가 삭제되지 않는다.
- 종료1.2초 뒤 effect/number/particle/camera를 지우며 cleanup에서 cache/flash/freeze 상태도 해제한다.
- 별도 object pool은 도입하지 않았다. 수명과 상한이 있는 Dictionary 배열을 사용하며, Particle/Timer/Tween Node를 매 hit 생성하지 않는다.

| 표현 | 실제 구현 |
|---|---|
| normal/critical hit | target band flash, 흰 core/radial spark·방향성 streak·damage number·작은 impulse. critical은 gold/더 큰 burst |
| slash | 실제 AttackInstance blade 방향/거리와 tapered filled arc, 무기별 atlas와 특대검 넓은 궤적 |
| projectile | arrow/giant arrow, sniper 긴 streak, shotgun 짧은 pellet, machine tracer, magic glow, missile·별·실/혀 색·형태 |
| explosion | bright core/expanding thick ring + shard/debris + smoke. 마법/폭탄/미사일/포탄 피해에서 연결 |
| blackhole | 실제 radius, dark core·회전 inward streak·외곽 ring |
| lightning | 분절 bolt·branch·밝은 core, 실제 discharge 영역의 방사 bolt |
| reflection | mirror barrier·reflected projectile 색, diamond/shard burst |
| healing | upward cross particle·soft pulse·heal number·실제 치유 영역 boundary |
| shield | 반투명 hex barrier·회전 edge·hit ripple·break shard burst |
| parry | white/cyan core·cross spark·radial wave·defender pose·impulse·presentation freeze |
| clash | crossed streak·gold core·shock ring·shards·strong impulse. 돌파 공격은 남은 실제 공격을 계속 렌더 |
| stun/invincible | 머리 위 회전 pixel stars / gold aura, shield와 구분 |
| ultimate | 실제 ultimate event/cast, caster별 motif·telegraph·무기 pose·focus. 샷건은 special 표시이며 가짜 궁극기 없음 |
| transcendence | dim/caster energy gather·directional blade/streak·screen accent·release flash, 기존1.15초 고정 |
| death/final kill | retained body flash/fade/scatter, 마지막 적은 별도 gold accent/focus. 추가 simulation slowdown 없음 |

## Camera / hit-stop 조사 및 반영

`ArenaCameraController`는 draw transform만 소유한다. 작은 일반 hit < critical < parry/clash < 큰 impact 순으로 bounded impulse를 준다. cap12 logical px, focus zoom 최대1.028, 작은 pan을 사용한다. TP/초월 aim/cast/종료에서는 transform을 정상화한다. gameplay position/AI/collider/타겟/배치 규칙에는 사용하지 않는다.

실제 `dist/combat.js:61`의 `impactPause`를 브라우저에서 실행해 경계를 조사했다. `hitstop-reference.json`에 force1/1.3/1.3001/2/2.0001/3 결과가 있다.

| 원본 force | hitStop | cooldown |
|---|---:|---:|
| ≤1.3 | 35ms |160ms|
| >1.3, ≤2 |55ms|160ms|
| >2 |80ms|160ms|

원본 cameraShake는 min(12,3+force×2.5). 원본 app.js166–168은 hitStop 동안 accumulator를 비워 gameplay step도 멈춘다. 이 동작을 그대로 넣으면 기존 simulation/TP·재현 검사 결과를 바꾸므로 이번에는 **presentation-only impact freeze**를 선택했다. 배우 표시 위치와 particle motion을 잠깐 유지하며 HP/공격/Clock은 계속 기존 계약대로 진행한다. 따라서 원본의 gameplay hit-stop과 동일하다고 주장하지 않는다. Engine.time_scale/SceneTree.paused/Clock 변경 없음. 35/55/80ms·160ms debounce·simulation/RNG 불변을 검사했다.

## 실제 전투 event frame 대조

[전사1v1 event 비교](migration/phase125/comparisons/duel-index.html)는 전사 두 명을 logical(280,400)/(520,400)에 배치해 실제 전투가 만든0초/첫공격/첫피격/패링/상쇄/사망을 촬영한다. Godot 변경 전은 작업 전 backup을 별도 /tmp 프로젝트로 실행한 동일 fixture다. 원본 RNG는 Godot과 다르며 다음 값은 통계적 AI 동등성 주장이 아니다.

| event | HTML sim seconds | Godot sim seconds |
|---|---:|---:|
| 첫 공격 준비 |2.2833|2.2167|
| 첫 피격 |2.6833|2.6500|
| 패링 |6.5500|2.6500|
| 상쇄 |2.6833|33.3000|
| 사망 |50.3167|56.0833|

처음 만든 Godot 패링은 이 비교에서 원본보다 접점 섬광이 작았다. 실제 pixels.js의 hitGlyph/parrySuccess/clash silhouette를 읽고 **parry r135, cyan24px/white8px tapered arc와 큰 교차 glyph**, clash r150의 gold/white contact glyph로 수정해 다시 캡처했다. 이는 피해/패링 판정 값을 바꾼 작업이 아니다. 폭발은 projectile의 실제 detonated/point/blast_radius를 읽고 victim 수와 무관하게 projectile당 한 번 표시한다. 마법탄 main hit도 실제 hit ID를 확인하며, 블랙홀의 매 피해를 가짜 폭발로 표현하지 않는다.

## 26종 VFX coverage

모든 행은 새 pixel body + 원본 basic weapon13pose + 공통 death scatter를 사용한다. 아래 passive/state/ult motif는 실제 runtime 상태가 있을 때만 표시한다. motif는 실제 hitbox를 새로 만들지 않으며 정확한 범위는 별도 cast/zone renderer가 표시한다.

| type | 캐릭터 | passive/state 및 projectile/area | ultimate motif | death |
|---:|---|---|---|---|
|0|전사|반격/패링 cyan wave|blade|flash/scatter|
|1|궁수|shotsFired/도탄/거대화살|arrow|flash/scatter|
|2|마법사|저HP/blackhole swirl|vortex|flash/scatter|
|3|암살자|stealth alpha/veil|veil|flash/scatter|
|4|수호자|cover link/aegis|aegis|flash/scatter|
|5|힐러|heal cross/치유장판|lotus|flash/scatter|
|6|대구경 저격수|조준 reticle/관통 streak|reticle|flash/scatter|
|7|샷건|ammo/장전/pellet|없음 / special pellet|flash/scatter|
|8|가위바위보 마스터|duel/3 motif|duel|flash/scatter|
|9|UFC 선수|연속 punch/ring square|fists|flash/scatter|
|10|두비두밤|guard/lostSword blade|greatsword|flash/scatter|
|11|챌런|scale/파동|ripples|flash/scatter|
|12|포식자|stacks/이빨 jaw|jaws|flash/scatter|
|13|폭탄|fuse/폭발 debris|fuse|flash/scatter|
|14|검객|연격/issen slash|issen|flash/scatter|
|15|소형 위성|missile/orbit|orbit|flash/scatter|
|16|성기사|축복 cross/holy|cross|flash/scatter|
|17|히어로|rescue barrier/comet|comet|flash/scatter|
|18|탱크|tankHeading/fire licks|tracks|flash/scatter|
|19|광신도|saint link/halo|halo|flash/scatter|
|20|번개 마법사|shock/branch bolt/discharge|storm|flash/scatter|
|21|금간 거울|mirror barrier/shards|shards|flash/scatter|
|22|은하|star/galaxy spiral|spiral|flash/scatter|
|23|기관총|ammo/tracer/recoil|tracers|flash/scatter|
|24|개구리|cargo/swallow tongue|tongue|flash/scatter|
|25|인형술사|control threads/link|threads|flash/scatter|

## 임시 표현 audit와 잔존 항목

- normal character/card visual에서 emoji 의존 제거. source icon과 별개로 로컬 pixel/vector asset 사용.
- raw actor IDs/brain/intent/AI timer/seed는 일반 화면 기본 OFF. member는 동일 종류 개별 구분용 #번호만 사용.
- 테스트 fixture 문구는 test/capture script에 한정. production에 고정 fixture 상태를 주입하지 않는다.
- semantic Button.text에는 이전 테스트/접근성 문자열(일부 emoji/ID)이 남지만 보이는 draw는 카드 계층이며 해당 native 글자는 숨긴다.
- 장비/stance/방 icon은 완성 일러스트 대신 authored vector pictogram. theme와 게임 역할을 가진 표시이지만 향후 art 교체 가능.
- debug legacy 비교 Scene의 개발 문자열/원시 도형은 의도적으로 유지한다. 실전 Tower full/common 경로가 사용하는 최종 표현과 구분한다.
- 선택 상세·성장 preview 일부는 텍스트 형식이다. 원본 Guild tabs/grid와의 구조 차이는 위 표에 남겼다.
- 모든 source particle/effect 종류를1:1로 복제하거나 모든 궁극기의 full animation을 프레임별 대조한 상태가 아니다. **전체 비주얼 parity 달성을 기능 검사만으로 완료 인증하지 않는다.**

## 검증

Godot **4.6.3**에서 다음 필수 명령을 실행했다. 최종 import 로그는 `migration/phase125/import-release-verified.log`, 전체 회귀 로그는 `regression-verified.log`다. 마지막 아이콘/시각 분류 수정 뒤에도 신규173개 검사를 재실행했다(`phase125-release-check.log`).

```sh
godot --headless --path godot --editor --quit
godot --headless --path godot --script res://tests/test_runner.gd
godot --headless --path godot --script res://tests/phase125_runner.gd
godot --headless --path godot --script res://tests/phase125_room_pair.gd
```

| 검사 | 검사 수 | 실패 |
|---|---:|---:|
|Phase1|9,705|0|
|Phase2|243|0|
|Phase3|131|0|
|Phase4|119|0|
|Phase5|110|0|
|Phase6|118|0|
|Phase7|3,702|0|
|Phase8 / 26종|8,260|0|
|Phase9|15,755|0|
|Phase10|10,255|0|
|Phase10.5 AI golden|48,418|0|
|Phase11 / 저장|643|0|
|Phase12 / UI·paired stress|22,691|0|
|Phase12.5 신규|173|0|
|**전체 test_runner**|**120,323**|**0**|

추가 실행은 전체 합계에 중복 가산하지 않았다. 집계·캡처 상태·계약 해시를 묶은 기계 판독용 결과는 `migration/phase125/validation-results.json`이다.

| 별도 검사 | 결과 / 근거 |
|---|---|
|기존10개 GUI smoke|headless와 X11 각각249개 / 실패0|
|Phase12 GUI|각각22,691개 / 실패0, 1280×720·1280×800·1000×1100·390×844|
|Phase12.5 GUI/표현 검사|각각173개 / 실패0|
|**GUI backend별 합계**|**각각23,113개 / 실패0**, `headless-final-results.json`, `X11-gui-results.json`|
|실제 Tower room VFX ON/OFF|headless/X11 각각13개 / 실패0, `room-pair-headless.log`, `room-pair-X11.log`|
|실제 저장 프로세스 재시작|서로 다른4개 프로세스,14개 / 실패0, `restart-results.json`|
|작업 전 backup vs 변경 후 duel|동일 seed의 첫 공격·피격·패링·상쇄·사망 시각 모두 동일, `duel-before-after-validation.json`|

신규173개는26개 portrait/weapon atlas·pose/motif, particle 상한/중요도/만료, camera 역변환/reset, 4개 화면 비율의 카드, presentation freeze35/55/80ms·중복 억제, 실제 폭발 위치/범위/단발, parry/clash 표현 범위와 cleanup을 검사한다. 별도 room paired13개는 실제 TowerController의 같은 방 두 개를 생성해3,509tick 동안 RNG/Clock/각 actor HP·position·attack state를 비교했다. TP12초 진입·자동 재개·17.4765 simulation초의 자연 승리·단발 정산을 통과했다. guild HP/energy/gauges/persistent state, enemy 상태, Player HP, gold/token, room clear/reward receipt, floor progression까지 같았다. UI를 위해 결과 정산을 다시 실행하지 않았다.

12vs12 paired stress900tick에서 실제 궁극기29회·hit263회·패링 성공6회·상쇄38회를 처리했다. peak projectile26 / zone8 / effect85 / number35였고, 신규 particle 검사 peak620은 전체640 상한 이내였다. 종료 후 effect/number/particle/camera를 정리했다. 공유 VM에서 이 paired stress는 headless28.89초, X11 51.67초였다. 게임 FPS나 실제 모바일 성능 수치로 해석하지 않는다.

X11에서는 실제 Godot 창과 mouse/touch InputEvent 경로로 GUI를 검사하고 화면을 저장했다. 사람이 실물 모바일 기기로 장시간 조작한 검사와 구분한다. 원본50장·Godot 변경 전46장·변경 후46장으로 **46개 화면 3열 비교**, 실제 전사 전투의6개 event로 **6개 추가 3열 비교**, 26종 pose7장을 제공한다. 최종 비교는 `comparisons/index.html`, `duel-index.html`이며 HTML/Godot 모두 실제 궁극기와 초월 상태를 확인했다. 소스 무기 atlas bake26개도 오류 없이 완료했다.

최종 해시 근거는 `protected-sha256.json`(173개), `ai-sha256.json`(9개), `save-sha256.json`(8개), `web-sha256.json`(dist19개)다. 모두 작업 전후 동일하다. `project.godot` 및 고정 `save_v1.json`도 동일하며 schema_version=1·DUNI_ARENA·autosave 경로를 유지했다. 사운드 파일·기능·설정 추가 없음. 초기 시도 로그의 UI hierarchy 오류/동시 실행 timeout은 보존하되, 표에는 수정·재실행을 완료한 final 결과를 사용했다. 기존 tower smoke의 child index 탐색만 타입 탐색으로 바꾸었고 검사30개를 삭제하지 않았다.

## UI 생성 비용 확인

초기 카드마다6개 font override를 ready에서 설정하면 native Button text가 반복 재계산되었다. 동일한 shared Theme variation을 생성 전에 지정하도록 통합했다. visible 카드 글자는 custom renderer가 그리고 native text는 의미 정보로 유지한다. Wallet의 숨은 semantic Label도 실제 패널 높이를 늘리지 않게 분리했다. `profile.log` / `profile-after.log` / `profile-font.log`의 지도 UI 생성 측정은 공유 CPU 부하에서17.96초→4.21/7.16초였고, frame 준비도2.33초→0.09/0.23초로 줄었다. 통제된 FPS 벤치마크로 주장하지 않는다. 실제 모바일 최종 map scroll은342×555, wallet은366×64였으며 불필요한 blank gap을 제거했다.

## 보호 경계 / MIGRATION_NOTE

- MN12.5-01: 원본 character face는 emoji, 무기/포즈는 procedural. 새 픽셀 body와 실제 source weapon atlas를 결합했으며 원본 pixel sprite 복원이라고 부르지 않는다.
- MN12.5-02: baked atlas는 현재 source 기준이다. 원본 renderWeapon/profile을 바꾸면 bake를 다시 실행하고13frame을 확인해야 한다. atlas는 presentation asset이며 UnitData를 복제하는 save 데이터가 아니다.
- MN12.5-03: 모든 VFX/particle/flash/camera/freeze/선택 데이터는 transient. save schema1에 추가하지 않는다.
- MN12.5-04: impact freeze는 presentation-only다. source accumulator hit-stop의 real/simulation 진행 차이는 남는다. AI/TP/초월의 gameplay 시간은 유지했다.
- MN12.5-05: zoom/pan은 draw/input adapter에서만 사용. touch 역변환을 테스트했다. 실제 actor position을 보정해 화면을 맞추지 않는다.
- MN12.5-06: telegraph는 actual cast/radius를 읽으며 particle budget과 별도다. 새로운 회피 시간/판정/공격을 만들지 않는다.
- MN12.5-07: UI 결과를 위해 settlement/reward/purchase/recruit/conquest를 재호출하지 않는다. 기존 단발 receipt/안전 checkpoint 유지.
- MN12.5-08: 모바일은44px 조작과 가독성을 우선해 원본보다 TP panel이 크다. 원본과 다른 레이아웃을 원본 복제로 주장하지 않는다.
- MN12.5-09: source/after screenshot은 통제 fixture. 전체 자연 플레이·동일 RNG/궤적·동일 프레임으로 주장하지 않는다.
- MN12.5-10: sound asset/AudioStream/AudioBus/manager/volume setting 추가 없음.

## 생성·수정 파일 / rollback

전체 source 변경 목록은 `migration/phase125/file-changes.json`이다. 기존15개 수정·새 source139개(보고서·asset import/UID 포함)이며, 캡처·로그·비교/보호 manifest는 별도로 `migration/phase125/`에 있다. 새 핵심 파일은 CharacterPainter/ArenaCard/ArenaIcon/WalletBar/VisualParticles/VisualShapes/AbilityMotifs, 캐릭터 SVG26개/원본 weapon PNG26개와 atlas manifest, Phase125 검사/캡처/갤러리 도구다. 게임 규칙/AI/Resource/save codec은 수정하지 않았다.

수정한 기존 파일:

- UI: `main_menu_screen.gd`, `tower_screen.gd`, `tower_content_screen.gd`, `guild_management_panel.gd`, `deployment_screen.gd`, `deployment_board.gd`, `room_battle_screen.gd`, `turning_point_panel.gd`.
- Presentation: `ui_style.gd`, `camera_controller.gd`, `combat_presentation.gd`.
- 검사/문서: `test_runner.gd`, `tower_ui_smoke.gd`(hierarchy 탐색), `phase12_tests.gd`(진행 로그만), `README.md`.

`migration/phase125/phase12-source-backup.tar.gz`가 작업 전 source다. `python3 godot/migration/phase125/rollback_phase125.py`는 dry-run으로 manifest만 보여준다. `--apply`를 명시하면 이번 새 source를 제거하고 기존 source를 복원한다. 이후 수정이 있다면 먼저 별도 보관한다. 증거/backup/user:// save는 삭제하지 않는다. 전체 git reset/clean을 사용하지 않는다. 복원 후 import와 Phase1~12 tests를 실행한다.

## 남은 시각적 차이와 출시 전 작업

위 화면별 차이, 원본 모든 effect/특수 pose의 개별 프레임 parity, 전체26 궁극기 자연 발동 영상 대조, 원본 retreat/gameover 장면 전환, 실제 모바일 하드웨어 safe-area/장시간 조작, 최종 아트 디렉션 검토가 남는다. 이번 작업은 Phase12의 임시 emoji/outline·ring-only 표현을 실질적인 portrait/무기 pose/particle UI로 바꾸었지만, 이 잔여 항목까지 원본 이상이라고 일괄 선언하지 않는다. 이후 다른 게임 Phase나 사운드는 시작하지 않았다.
