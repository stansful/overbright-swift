# Overbright — Korean (한국어, `ko`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted, and examples and notes that named Cranny’s features (the notch, the Tray, widgets, Calendar, Notes,
Media, permissions) were replaced with Overbright’s or dropped. Overbright’s own names, its pane names among them,
were decided in WP15 (ARCHITECTURE.md §10.17, §8.8); the table shows them as the catalogs ship them.
`scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register and style follow Korean macOS 27 (checked in the system's own loctables):

- **Sentences** in the formal polite style macOS uses: statements “-습니다”, requests “-십시오”
  (“나중에 다시 시도하십시오.”, “인터넷 연결을 확인하십시오.”). No “당신”; “you/your” is omitted or, where
  needed, “사용자의” as Apple does.
- **Buttons, menu items, toggles, picker options and titles** are noun phrases, as macOS writes them:
  “취소”, “완료”, “열기”, “Overbright 종료”, “업데이트 확인…”, “메뉴 막대 아이콘 보기”, “로그인 시 열기”.
  Show-toggles are “… 보기” (System Settings: “메뉴 막대에서 보기”, “배터리 잔량 보기”); hide-toggles “… 가리기”.
  States and confirmations end in “-됨” (“일시 정지됨”, “복사됨”).
- **Quotes**: ‘…’ around names and setting names (macOS: “‘%@’ 압축”, “‘세게 클릭 및 햅틱 피드백’ 업데이트”);
  “…” only inside them. Ellipsis … (one character). No straight quotes.
- **Particles** after a placeholder use both forms: ‘%@’을(를), 이(가), 은(는), 와(과), (으)로. After *Overbright*
  (read 오버브라이트, a vowel ending) always 는 / 가 / 를 / 와 / 의 / 에서 / 로. After any other Latin name, choose by how
  it is read: “macOS가”, “Finder를”, “HDR을”, “OLED를”, “GitHub로”.
- **Counts**: one plural form (`other`) with a counter: “%lld개 항목”, “%lld일”, “%lld분”, “%lld ms”.
- **Spacing**: 띄어쓰기 as Apple (“일시 정지”, “메뉴 막대”, “다시 시도”); Latin names keep their spelling.
- **Overbright** is never translated or transliterated (no “오버브라이트” in copy).

## Apple names (`apple-terms.py ko` on macOS 27.0.1 — never paraphrased)

| English | ko |
|---|---|
| System Settings | 시스템 설정 |
| Finder | Finder |
| Shortcuts | 단축어 |
| Photos | 사진 |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | 개인정보 보호 및 보안 |
| Accessibility | 손쉬운 사용 |
| General | 일반 |
| Appearance | 화면 모드 |
| Menu Bar | 메뉴 막대 |
| Control Center | 제어 센터 |
| Focus | 집중 모드 |
| Displays | 디스플레이 |
| Keyboard | 키보드 |
| Keyboard Shortcuts… | 키보드 단축키… |
| Lock Screen | 잠금 화면 |
| Battery | 배터리 |
| Energy | 에너지 |
| Screen Saver | 화면 보호기 |
| Login Items | 로그인 항목 |
| Login Items & Extensions | 로그인 항목 및 확장 프로그램 |
| Brightness | 밝기 |
| Automatically adjust brightness | 자동으로 밝기 조절 |
| True Tone | True Tone |
| High Dynamic Range | 고명암 대비 |
| Preset | 프리셋 |
| Night Shift… | Night Shift… |
| Color profile | 색상 프로필 |
| Refresh rate | 재생률 |
| Allow in the Menu Bar | 메뉴 막대에서 허용 |
| Low Power Mode | 저전력 모드 |
| Do Not Disturb | 방해금지 모드 |
| Camera | 카메라 |
| Open Anyway | 그래도 열기 |
| Applications | 응용 프로그램 |
| Reduce motion | 동작 줄이기 |
| Reduce transparency | 투명도 줄이기 |
| Increase contrast | 대비 증가 |
| Differentiate without color | 색상 제외하고 구별 |
| VoiceOver | VoiceOver |

## Overbright’s own names

| English | ko | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated |
| Settings panes: General · Displays · Automations · Shortcuts · Fill Light · Advanced · About | 일반 · 디스플레이 · 자동화 · 단축키 · 보조 조명 · 고급 · 정보 | the sidebar and window titles |
| Standard (the brightness macOS shows) | 표준 | never “100 %” or “normal mode” |
| extra brightness (the boost half) | “추가 밝기 사용” (Use extra brightness) | never “boost”, “HDR mode”, “EDR” |
| Dim below minimum (the setting) | “최소 밝기 이하로 어둡게 하기 켜기/끄기” (Dim Below Minimum On or Off) | the incumbent’s name for it is never used |
| Dimmed (the state) · Dim All Displays / Stop Dimming (actions) | 어둡게 설정됨 · 모든 디스플레이 어둡게 하기 / 어둡게 하기 중단 | not “night mode” |
| Brighter · Less Bright (one step) | 더 밝게 · 덜 밝게 | never “Dimmer”: it reads like Dim |
| Back to Standard (the instant off) | 표준으로 돌아가기 | not “panic”, not “reset brightness” |
| Indoor · Bright room · Sunlight · Max (presets) | 실내 · 밝은 방 · 햇빛 · 최대 | “Max” is a preset only |
| Safe · Peak (ceilings) | 안전 · 피크 | Peak, never “Max”, for a ceiling; one short word each (segments) |
| color table (in sentences: “macOS ignores color table changes”) | 색상 테이블 | never “gamma”; no “fallback” or “overlay” in copy |
| Fill Light (the edge light for video calls) | 보조 조명 | never “ring light” |
| extra range (headroom, in user copy) | 여유 밝기 | “headroom” only in Advanced and diagnostics |
| Calibrate… · Run Self-Test… · Reset Display Colors… | 보정… · 자체 테스트 실행… · 디스플레이 색상 재설정… |  |
| Keep this level? · Go Back · Keep | 이 레벨을 유지하겠습니까? · 되돌리기 · 유지 | the very-dark-level prompt |
| Pause · Paused · Resume | “Overbright 일시 정지” (Pause Overbright) · 일시 정지됨 · 재개 | a temporary stop; never “disabled” |

## Carried from Cranny (generic interface words)

| English | ko | Note |
|---|---|---|
| Overbright | Overbright | never translated; Overbright는 / Overbright가 / Overbright를; also the open panel (“Overbright 열기”) |
| Settings | 설정 | “설정 ▸ 일반” |
| Reset to Default | 기본값으로 재설정 |  |
| Changed from the default | 기본값에서 변경됨 |  |
| Allow… / Grant… | 허용… |  |
| Preview | 미리보기 |  |
| Never (timeout 0) | 안 함 | Apple’s value word |
| Off / On (values) | 끔 / 켬 | Apple’s value words |
| Shortcuts (Apple app) · a shortcut | 단축어 · 단축어 | “단축어 실행”; never “바로 가기” |
| keyboard shortcut | 단축키 | “키보드 단축키” |
| Remove (from a list) | 제거 | “목록에서 제거”; 삭제 only for deleting data |
| App not installed | 설치되지 않은 앱 |  |
| Welcome (window) | Overbright 시작하기 | Apple: “Mac 시작하기” |
| Space (the space bar in key caps) | 스페이스 | as AppKit writes it in menu key equivalents (FunctionKeyNames.loctable “Space”), so Settings and Welcome show the same key caps as the menu; AppKit’s name for the physical key is 스페이스 바 |
