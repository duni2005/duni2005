# 공격 모션·VFX 원본 비교 및 보강

## 변경 근거와 범위

원본 dist 19개 파일을 실행하여 `renderWeapon`, `renderMeleeStrikes`, `renderProjectileShape`, `renderFrogTongue/Actions/Body`, 각 캐릭터 renderer를 확인했다. 원본과 같은 픽셀 좌표의 개구리 4단계와 26종 무기의 준비·발동·회수 화면을 캡처했다. 기존 일반 플레이 UI·카메라·정산·AI·판정 시간은 수정하지 않았다. 사운드 없음.

기존 문제: 13개 공통 셀만 사용하여 UFC는 normal kind로 구워져 펀치가 뻗지 않았고, 검객 slash=0, 성기사는 항상 방패 포즈였다. 궁극기는 기본 공격 windup 셀을 재사용했다. 무기는 현재 facing을 참조하고 실제 공격은 committed aim을 참조해 방향이 어긋날 수 있었다. 모든 근접 공격을 같은 얇은 검호로 그리고, frogTongue는 녹색 짧은 이동 선이었으며 포획된 대상은 pull 단계부터 숨겨졌다.

## 구현

- `WeaponMotion`: 실제 combat phase/phase_time/profile, combo, paladinSwings, guard/reload/ultimate를 읽는 표현 전용 adapter. 단계별 12 표본, idle 포함 기본 37포즈와 특수 bank. 궁극기와 공격 방향을 각각 실제 aim에 연결. 안정 ID/저장 포맷 변경 없음.
- 원본 `renderWeapon`에서 캡처한 총 1,573포즈. 투명 영역을 잘라 2048² RGBA 두 장(32MiB, mipmap 제외)에 pack. 기본/콤보/방어/장전/궁극기 이미지를 런타임에 Canvas로 재생한다. 예전 아틀라스는 호환 검사용으로 유지하지만 실제 유닛과 정적 배치는 새 renderer를 사용한다. 런타임 이미지 생성·JS 실행 없음.
- `AttackVisuals`: 실제 AttackInstance blade/path/shield_bash/headbutt/grapple와 Projectile을 읽어 서로 다른 궤적. 판정을 새로 만들지 않는다. 펀치/물기/박치기에 칼베기를 그리지 않는다.
- 개구리: 원본 분홍색 외부/내부 tapered beam, 혀 끝, source→tip 및 source→당겨오는 victim 연결. pull 대상은 보이며 hold에서만 숨김. 발사 중 실제 cargo type을 회전시켜 그려 중복 본체를 제거. 실제 frogHop.t/duration으로 sin(πp)×30 높이.
- 발사 때 실제 attacks_released 변화로 섬광과 입자 1회. 피해 시 source 캐릭터의 잉크색. 강한 판정의 기존 파티클·패링·상쇄/폭발 효과 유지.
- 투사체: 화살/거대 화살, 저격탄/산탄/기관총, 포탄/미사일, 마법/빛, 거울/별/검기, 실/혀/발사 유닛을 구분. 폭탄 포물선과 지상 blast_radius/fuse는 실제 metadata에서 읽음.
- trail은 simulation elapsed가 바뀔 때만 갱신하고 10점 제한. 소멸 projectile ID의 trail/origin 즉시 정리. TP 중 길어지지 않는다. 사망/정산 뒤 새 gameplay 상태를 생성하지 않는다. 기존 효과 96/숫자 40/입자 640 cap 유지.

## 26종 결과

| ID | 캐릭터 | 반영 | 궁극기 |
|---|---|---|---|
| 0 | 전사 | 검 준비/회수와 고정 공격각, 이중 참격/초승달 검기 | 기존 cast에 연결 |
| 1 | 궁수 | 당긴 활시위/화살, 세 번째 도탄 색, 거대 관통 화살 | 기존 cast에 연결 |
| 2 | 마법사 | 지팡이 충전, 발광 마법탄, 기존 폭발/블랙홀 | 기존 cast에 연결 |
| 3 | 암살자 | 서로 다른 두 단검과 겹친 짧은 참격 | 기존 cast에 연결 |
| 4 | 수호자 | 방패 휘두르기와 보호 효과 | 기존 cast에 연결 |
| 5 | 힐러 | 빛 지팡이 충전/빛탄, 치유 연결과 회복 입자 | 기존 cast에 연결 |
| 6 | 대구경 저격수 | 5초 준비 포즈, 2초 이후 조준선, 발사 섬광/긴 탄흔 | 기존 cast에 연결 |
| 7 | 샷건 | 산탄 발사 포즈/짧은 펠릿, 장전 동작/진행 링 | 없음 |
| 8 | 가위바위보 마스터 | 붙잡는 손 동작, 잘못된 칼 궤적 제거 | 기존 cast에 연결 |
| 9 | UFC 선수 | 좌우 펀치와 세 번째 큰 주먹, 직선 타격 궤적 | 기존 cast에 연결 |
| 10 | 두비두밤 | 특대검 크기의 두꺼운 검호, 방어 포즈/분실 시 무기 숨김 | 기존 cast에 연결 |
| 11 | 챌런 | 무기 없는 박치기와 냉색 직선 돌진 궤적 | 기존 cast에 연결 |
| 12 | 포식자 | 열렸다 닫히는 이빨/턱, 물기 압력선 | 기존 cast에 연결 |
| 13 | 폭탄 | 던지기/손에서 폭탄 사라짐, 포물선/지상 도화선 범위 | 기존 cast에 연결 |
| 14 | 검객 | 3연격 포즈, 세 번째 회전베기/긴 검, 경로 참격 | 기존 cast에 연결 |
| 15 | 소형 위성 | 충전 패널/발사구, 날개 달린 미사일과 배기 | 기존 cast에 연결 |
| 16 | 성기사 | 방패 강타/검 베기 교대, 폭 넓은 방패 전면파 | 기존 cast에 연결 |
| 17 | 히어로 | 준비/발동 주먹, 큰 펀치 궤적/구조 보호 | 기존 cast에 연결 |
| 18 | 탱크 | 궤도/포신 후퇴, 실제 포탄 실루엣/포구 섬광/기존 화염 | 기존 cast에 연결 |
| 19 | 광신도 | 단검 포즈와 연보라 타격색, 성자 관계 표시 유지 | 기존 cast에 연결 |
| 20 | 번개 마법사 | 충전 지팡이, 연쇄마다 독립 시작점을 갖는 분절 번개/감전 표식 | 기존 cast에 연결 |
| 21 | 금간 거울 | 충전 거울, 거울빛/반사탄 실루엣, 반사 파편 유지 | 기존 cast에 연결 |
| 22 | 은하 | 회전 별 무기/부채 별탄/영역 별 효과 | 기존 cast에 연결 |
| 23 | 기관총 | 기관총 반동/장전, 긴 가는 연속 탄흔/탄 수 표시 | 기존 cast에 연결 |
| 24 | 개구리 | 분홍 혀 발사·연결·당김·삼킴·회전 유닛 발사, 30px 점프 높이 | 치명적 아군 구조(반응형) |
| 25 | 인형술사 | 실타래 충전, 가는 공격 실/굵은 조종 실 구분, 조종 십자대 | 기존 cast에 연결 |

## 캡처 및 검증

`migration/attack-motion/`: HTML 원본 무기 contact sheet, HTML/Godot 개구리 extension/pull/hold/spit, 수정 전/후 26종 포즈 3단계, 20종 projectile coverage, 390×844 실제 Web UI 스크린샷. 원본 캡처는 dist 파일을 수정하지 않고 브라우저에서 고정 fixture를 실행했다. 시각 fixture의 HP/phase 설정은 테스트에만 존재한다.

- 전체 Phase1–12.5: **120,324 checks / 0 failures**. Phase10.5 AI Golden 48,418 및 Phase11 643 포함.
- 신규 모션/26종 ON/OFF 900 paired ticks: **25,967 / 0**. 각 actor HP/position/combat state/character state, RNG/time 일치. 입자 peak503/640.
- 기본 합계: **146,291 / 0**. 중복 재실행은 이 합계에 더하지 않음.
- 추가 Phase12 UI/24명 900 paired ticks: 22,692/0. effects peak56, numbers36, projectile14, zone8. 16:9·16:10·1000×1100·390×844.
- 추가 Phase12.5: 173/0; 실제 X11 navigation/touch 218/0.
- 실제 두 프로세스 save 재시작: 일반 run 및 battle-start checkpoint, 총14/0.
- Chromium mobile: Continue→배치→유닛→X복귀→전투→reload→checkpoint 복구. JS/console 오류0.
- APK preview.4/code4: 기존 package와 signing key 유지. ARM64 native. signature v2/v3, CRC,16KB alignment, private files 제외 통과. 실제 브라우저 다운로드 파일 SHA 일치, 중복 터치 1파일, 손상 chunk 차단. 실제 Android 기기 설치/프레임 성능 검증은 불가.

## 보호 및 MIGRATION_NOTE

`hash-verification.json`에 dist 19개 SHA-256과 변경 파일 목록을 보존했다. 기존 변경은 presentation의 character_painter / character_visuals / combat_presentation / ability_motifs 네 파일뿐이다. 새 파일은 weapon_motion, weapon_motion_data, attack_visuals, motion textures, 테스트/증거다. 모든 AI·Combat·Ability·Save·기존 UnitData/Resource SHA 불변. schema_version=1/user://saves/autosave.json/DUNI_ARENA/stable IDs/receipts 그대로. 새 dictionary는 전투 종료 연출의 메모리상 primitive pose이며 save domain에 추가하지 않았다.

APK: 31,769,906 bytes; SHA-256 `3f2efde0da7c758cda171137ddd33866f816d15d7c956ccc3ed21b44ae48350f`. Web PCK:6,831,552 bytes, SHA-256 `c763bf4fc81ce085101fe6cbae4f3585ab165f0b97d7619b97b269f2c23d8616`. 두 build의 모든 source hash와 staging source가 최종 root와 일치한다.

## 남은 차이

원본 Canvas의 연속 벡터 무기는 12표본/phase의 프레임으로 표시하므로 무한한 중간 각도까지 동일하지 않다. 원본의 일부 시간 기반 궤도/무기 내부 입자는 샘플에 포함된 상태이며 완전한 실시간 Canvas 복제는 아니다. 궁극기 motif와 일부 보조 파티클은 Godot 고유 표현을 유지한다. 가위바위보 결과 sign은 현재 domain에 남지 않아 원본의 승리 hand sign까지 새로 추측해 그리지 않았다. 이번 작업을 모든 원본 연출의 픽셀 단위 일치로 주장하지 않는다. Impact pause는 기존처럼 presentation-only이므로 실제 simulation 타이밍을 변경하지 않는다.

## 이번 변경만 되돌리기

`migration/attack-motion/before/<name>.gd.txt`의 위 네 presentation 파일을 복원하고 새 `weapon_motion*.gd`, `attack_visuals.gd`, `assets/motion/`을 제거한 뒤 Web/APK를 재빌드한다. 원본 dist, AI, 저장 데이터는 되돌릴 필요가 없다. Android는 앱 삭제 없이 동일 key·package와 더 높은 versionCode로 rollback 빌드하여 저장을 유지한다. 이후 실기기에서 포즈/가독성/성능을 추가 검토할 수 있다.
