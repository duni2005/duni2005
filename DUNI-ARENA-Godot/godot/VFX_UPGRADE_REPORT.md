# 게임 VFX 고도화

## 방향

원본 복제 제약을 벗어나, 실제 판정과 능력 범위는 유지하면서 빛·질감·움직임·충격의 강약을 새로 디자인했다. UI 배치, AI, HP/공격/방어/사거리/시전 시간, 저장 schema, 재화·정산·카메라 gameplay 좌표는 수정하지 않았다. 사운드 추가 없음.

## 표현 변경

| 종류 | 변경 |
|---|---|
| 일반 타격/치명타 | 방향성 광선, 흰 중심과 캐릭터 색 가장자리, 빠르게 흩어지는 스파크, 치명타의 금빛 강도 |
| 패링 | 청백색 접점 섬광, 세 겹의 곡면 압력파, 반짝이는 파편, 지면 타원 충격파 |
| 상쇄 | 따뜻한 색/차가운 색 교차광, 분절 충격 고리와 짧은 방사 스파크 |
| 폭발 | 뜨거운 중심→불씨/파편→넓어지는 충격파/연기. 불투명 단색 원을 대체 |
| 보호막 | 투명한 육각 구조, 내부 셀 무늬/흐르는 가장자리, 피격 광원, 깨지는 조각 |
| 치유/토템 | 위로 흐르는 빛 입자, 반짝이는 별, 지면 파동과 부드러운 녹색/푸른 광원 |
| 반사 | 다이아몬드형 조각과 흰 균열, 자주/청록 광선 |
| 기절/무적 | 머리 위 회전 별, 금빛 룬/오라 |
| 검격/고속 이동 | 그라데이션 검호, 칼끝 빛, 짧게 남는 유닛 잔상 |
| 투사체 | 마법/빛/별/거울의 광원·빛 꼬리, 미사일 배기, 번개 접점 발광. 개구리의 실제 혀/포획 연결은 유지 |
| 블랙홀 | 검은 중심, 광자 고리, 회전하며 중심으로 감기는 에너지 흐름/빛 입자 |
| 화염 | 노이즈 셰이더의 상승 흐름, 불꽃 질감, 위로 솟는 불씨 |
| 은하 | 보라·청색 에너지 나선, 밝기가 바뀌는 별, 흐르는 별무리 |
| 궁극기/초월 | 시전자 광원과 룬, 에너지 집결 입자/별빛/방향성 광선. 기존 26종 motif/판정/시전 시간 유지 |
| 사망/마지막 타격 | 원래 캐릭터 소멸에 빛 조각과 잔광 추가. 보상/정산을 다시 호출하지 않음 |

## 구조

- `VfxArt`: 공용 마스크 4개(glow/flare/glint/smoke), 부드러운 리본/룬/장판/충격 모양. 1개 재사용 noise texture. 가장 큰 마스크 256px, 런타임 이미지 생성 없음.
- `MagicFieldLayer`: `magic_flow.gdshader`로 4종 흐름. 최대16개 Surface Node를 pool로 재사용. 실제 범위선은 원래 영역 radius에 그대로 남김. 셰이더 자체는 피해/이동/CC를 만들지 않는다.
- `CombatGlowLayer`: 하나의 additive CanvasItem으로 빛 표현. 최대112 light sprites, 강한 실제 궁극기/패링/폭발 우선, projectile light 최대48. shadow light/particle별 Node 없음.
- `VisualParticles`: 최대640(일반420) 유지. 질감 있는 smoke/mote/ember와 회전 shard. 전투 RNG 대신 전용 deterministic noise 사용.
- `CombatPresentation`: 실제 damage/event/release/state만 읽어서 위 layer를 호출. 잔상 최대48, 수명0.16초. TP에서 gameplay state를 진행시키지 않음. 장판 shader와 arena/actor가 같은 draw-frame camera transform을 사용하여 zoom/shake 중 좌표 어긋남을 막음. 모든 layer는 mouse filter IGNORE.

## 검증

- 전체 Phase1~12.5 회귀: **120,324 checks / 0 failures**. Phase10.5 AI Golden/Phase11 save/Phase12 paired 포함.
- 기존 26종 모션 ON/OFF: **25,967 / 0**. HP/위치/공격/character state/전투 RNG/time 동일.
- 신규 VFX/bounded pooling/카메라/TP/12vs12 ON/OFF: **23,418 / 0**.
- 위 세 suite 합계 **169,709 / 0**. 중복 재실행은 합계에 더하지 않음.
- 신규 ON/OFF peak: particles593/640, echo20/48. 과부하 field fixture16/16 및 재사용/우선순위/cleanup 검사.
- 실제 X11 렌더: 24명/360 simulation ticks/120 rendered samples. script/shader/triangulation 오류0. 실제 scene peak: particles555, light sprites72, fields7, echoes13. 종료 cleanup 통과.
- 소프트웨어 Mesa llvmpipe + 다른 검사/build가 함께 실행된 frame wait 진단값은 `render-stress.json`에 원문 보존. 이 값은 Android/실기기 FPS 측정값이 아니다. 물리 Android 기기의 FPS/발열/배터리는 미검증.
- 390×844 Web 실제 터치/Continue/배치/유닛/전투/초기 궁극기/재로드 checkpoint 복구 검사와 실제 APK 다운로드 검증은 별도 결과 JSON에 기록.
- 프로세스 재시작 save 일반 런/전투 시작 checkpoint 검사 재실행.

## 전후 캡처

`migration/vfx-upgrade/before-impacts-00..08.png`, `after-impacts-00..08.png`, `before-fields-00..08.png`, `after-fields-00..08.png`. `compare-impacts.gif`, `compare-fields.gif`는 같은 위치·같은 VFX 시점의 전후 비교. `stress-60/120/180/240/300.png`와 mixed-battle.gif는 실제 혼합 전투. 비교 fixture만 VFX를 나란히 배치하며 실제 게임에 테스트 화면/보상을 추가하지 않았다.

## 보호 / MIGRATION_NOTE

원본 dist 19개 SHA-256 동일. AI·Combat·Ability·Save·기존 Data/Resource SHA 동일. 기존 변경은 presentation 다섯 파일(ability_motifs/attack_visuals/visual_particles/visual_shapes/combat_presentation)이다. 추가는 VfxArt/CombatGlowLayer/MagicFieldLayer, 마스크·shader, 검증/보고서다. 새 shader clock은 presentation 시간이며 전투 시간/TP/초월 시전 시간을 바꾸지 않는다. 효과 Node/pool/shader/잔상/입자는 런 저장에 포함하지 않는다. user data DUNI_ARENA, schema_version1, stable IDs/receipts 보존.

공용 효과가 적용되는 26종 모두 기존 기본공격/능력/궁극기 모션과 연결했다. 이번 작업에서 26종 sprite 자체를 새로 그리거나 새로운 공격/판정/밸런스를 만들지는 않았다.

## Rollback

`migration/vfx-upgrade/before/*.gd.txt`에서 위 다섯 presentation 파일을 복원하고 새 vfx_art/combat_glow_layer/magic_field_layer 스크립트와 assets/vfx를 제거한 뒤 재빌드한다. 웹 원본/AI/전투/저장 데이터는 되돌릴 필요가 없다. Android는 동일 package/signing key와 더 높은 versionCode로 rollback 빌드하여 앱 저장을 유지한다.

## 배포 파일

APK 0.12.5-preview.5 / code5 / 31,812,502 bytes / SHA-256 `bcbe58a3c40ae832fc18e03c1a2d7308dd99603e76c226cd4f21c3f729d2621d`.

Web PCK 6872636 bytes / SHA-256 `c14de3fd52bef29c276a3309c423b20f62c2276d28831b8bf840c8da32bbd9ab`.

## 웹 원본 SHA-256

| 파일 | SHA-256 |
|---|---|
| dist/frog.js | `da604aa76c79ee0b4ad1bbc52fc729a29cb9bbc595685177b7ec141a5f8407f4` |
| dist/hero-tank.js | `5e4697f2700e127ac270d3a26ba7139d90bc180a0110e76645ebceeb5c91af78` |
| dist/pixels.js | `626a40fdfd732f69e0fa66c792acaf6cfd2f1be2d9f12a392c136316bded6f4c` |
| dist/spectator.js | `efadba5bea7018f711827e3c4a42be0297fdaa026a79999f613c15681d8fc199` |
| dist/puppet.js | `a255edca3610d704c58957a035f382af34f17702aee4cbddc7fcb9707feb230a` |
| dist/ultimate.js | `617b426fae98b3b93e35cdab10747c5e79572fd51ee911a43ba31f5558b19b13` |
| dist/novel.js | `ee404cab9ef2f883a8b098b9c4ead0f33c242a1ef239b743d1e37933e23db04a` |
| dist/transcendence.js | `d8c5070685b02f74397dba4a1404a6a047dd37c0820e53dc28ef75497aa266f5` |
| dist/archetypes.js | `8b1e8aae38e45172c9818a6bb002644f5dadc355387fd407fcc617b82a52aae7` |
| dist/ai.js | `7dda3a31c38fd97149dc31edc70802e7daec03a5aa02443368baa0fc5a76e650` |
| dist/app.js | `bc5ae16d3f78a5f4cd783508dd2271d0e3478eeabfbb0922b3d0dfe577d6d7fb` |
| dist/strategy.js | `32298e87af96ecc718002a3e1362b0377714141c437eab9ef45d88d0e1ddf08d` |
| dist/style.css | `c1aff15fbedb3672388f2825460b1307765b379ff3bb102d98d0041640779d15` |
| dist/faith-lightning.js | `407ae915b2790ea792583c53e0d1e59ee7587e83d0832fb90b967539205d1328` |
| dist/index.html | `3332a7f922f36d45e49619a0377b11ae686ffd168d65e721d4e8b7823e7d333e` |
| dist/rear-galaxy.js | `b4cd8e29769544d0906458d41ad28fea55789e379f53c73c9a4cb3432690bf0c` |
| dist/tower.js | `13240c2c38e4e7985ad76c76c948323b1c069e1cd971f925da2070f46e6fd410` |
| dist/combat.js | `39e61fc01d486cc5f5113910a7cf5df4b0d208ad4ce26475beb22f2bbb00cf69` |
| dist/physical.js | `369ac5a14b4b3cb199a9585ef7f6a2d98a6e7977fb57f367380841ab3fa7a7fb` |
