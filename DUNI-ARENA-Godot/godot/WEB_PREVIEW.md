# Godot Phase9 브라우저 미리보기

https://duni-godot-preview.kanduni.chatgpt.site

2026-10-13 배포. Sites 본인 전용(계정 로그인 필요). 기존 duniarena.site와 분리된 실제 Godot4.6.3 Web export입니다. Phase10은 구현하지 않았으며 비전투 방은 진입 화면까지만 제공합니다.

내보내기 프로젝트: `/workspace/sites/duni-godot-preview` (hosting identity는 `.openai/hosting.json`). 원본 Godot의 scripts/scenes/data를 그대로 복사했습니다. Web 전용 한국어/이모지 글꼴, 모바일 viewport 대응, 단일 스레드 설정만 내보내기 복사본에 추가했습니다. WebAssembly는 호스팅 크기 제한 때문에 gzip 분할 전송하고 브라우저에서 동일 바이트로 복원합니다. 기존 웹19개와 원본 전투 스크립트는 수정하지 않았습니다.

로컬 Chromium에서 desktop/390×844 초기 실행, 한글/이모지, WASM 로딩 오류없음을 확인했습니다. 전투/전략카드/초월 등의 native 회귀 검사는 Phase9 보고서에 있습니다. 배포 성공은 Sites native 결과로 확인했습니다. 본인 인증이 필요한 배포본을 로그인 없이 테스트했다고 주장하지 않습니다.

사이트 ID: `appgprj_6acdf2e05d348191804d680d5f5231f7`
버전: `appgprj_6acdf2e05d348191804d680d5f5231f7~appgver_3994370908fc8191a23c1fc3ffd50765`
배포 ID: `appgdep_6acdf4d0597c8191843f95c636949b72`
Source commit: `a6bbddd3005e23e32765350396c630f45ff6b5c4`

현재 미리보기는 Phase9 스냅샷입니다. 이후 변경을 반영할 때는 이 사이트 ID를 재사용해 새로 export/publish해야 합니다. 도메인과 웹 원본 게임을 변경하지 않습니다.
