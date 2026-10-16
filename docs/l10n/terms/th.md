# Overbright — Thai (ไทย, `th`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted, and examples and notes that named Cranny’s features (the notch, the Tray, widgets, Calendar, Notes,
Media, permissions) were replaced with Overbright’s or dropped. Overbright’s own names, its pane names among them,
are decided in WP15 (ARCHITECTURE.md §10.17, §8.8); until then they read “—”.
`scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register and typography (as macOS writes Thai):

- Polite neutral register, คุณ for "you" (used sparingly, as Apple does); no polite particles (ครับ/ค่ะ).
- No full stop at the end of a sentence; sentences and clauses are separated by a space. Questions end in
  "…หรือไม่" without "?" (Apple: "ลบ “%@” หรือไม่").
- No spaces between Thai words; a space before and after Latin words, numbers and placeholders
  ("เปิด Overbright", "%lld รายการ"), as macOS does.
- Quotes “…” (secondary ‘…’), ellipsis … (U+2026), no straight quotes.
- Buttons and menu items are bare verbs ("เปิด", "ยกเลิก", "ตรวจหารายการอัปเดต…"); Thai has no letter case, so the
  English title case/sentence case split disappears.
- Number + classifier: "%lld รายการ", "%lld จอ", "%lld วัน". Thai has one plural form (other).
- Apple's names come from `apple-terms.py th` (System Settings panes, apps).
- "Overbright" is never translated or transliterated.

## Apple names (`apple-terms.py th` on macOS 27.0.1 — never paraphrased)

| English | th |
|---|---|
| System Settings | การตั้งค่าระบบ |
| Finder | Finder |
| Shortcuts | คำสั่งลัด |
| Photos | รูปภาพ |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | ความเป็นส่วนตัวและความปลอดภัย |
| Accessibility | การช่วยการเข้าถึง |
| General | ทั่วไป |
| Appearance | รูปแบบ |
| Menu Bar | แถบเมนู |
| Control Center | ศูนย์ควบคุม |
| Focus | โฟกัส |
| Displays | จอภาพ |
| Keyboard | แป้นพิมพ์ |
| Keyboard Shortcuts… | ปุ่มลัดแป้นพิมพ์… |
| Lock Screen | หน้าจอล็อค |
| Battery | แบตเตอรี่ |
| Energy | พลังงาน |
| Screen Saver | ภาพพักหน้าจอ |
| Login Items | รายการเข้าสู่ระบบ |
| Login Items & Extensions | รายการเข้าสู่ระบบและส่วนขยาย |
| Brightness | ความสว่าง |
| Automatically adjust brightness | ปรับความสว่างอัตโนมัติ |
| True Tone | True Tone |
| High Dynamic Range | ช่วงแสงกว้างขึ้น |
| Preset | ค่าที่ตั้งไว้ |
| Night Shift… | Night Shift… |
| Color profile | โปรไฟล์สี |
| Refresh rate | อัตรารีเฟรช |
| Allow in the Menu Bar | อนุญาตในแถบเมนู |
| Low Power Mode | โหมดประหยัดพลังงาน |
| Do Not Disturb | ห้ามรบกวน |
| Camera | กล้อง |
| Open Anyway | ยืนยันจะเปิด |
| Applications | แอปพลิเคชัน |
| Reduce motion | ลดการเคลื่อนไหว |
| Reduce transparency | ลดความโปร่งใส |
| Increase contrast | เพิ่มความต่างระดับสี |
| Differentiate without color | แสดงความแตกต่างโดยไม่ใช้สี |
| VoiceOver | VoiceOver |

## Overbright’s own names

| English | th | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated |
| Standard (the brightness macOS shows) | — | never “100 %” or “normal mode” |
| extra brightness (the boost half) | — | never “boost”, “HDR mode”, “EDR” |
| Dim below minimum (the setting) | — | the incumbent’s name for it is never used |
| Dimmed (the state) · Dim All Displays / Stop Dimming (actions) | — | not “night mode” |
| Brighter · Less Bright (one step) | — | never “Dimmer”: it reads like Dim |
| Back to Standard (the instant off) | — | not “panic”, not “reset brightness” |
| Indoor · Bright room · Sunlight · Max (presets) | — | “Max” is a preset only |
| Safe · Peak (ceilings) | — | Peak, never “Max”, for a ceiling; one short word each (segments) |
| Compatibility mode · Color table (methods) | — | never “fallback” or “overlay” |
| Fill Light (the edge light for video calls) | — | never “ring light” |
| extra range (headroom, in user copy) | — | “headroom” only in Advanced and diagnostics |
| Calibrate… · Run Self-Test… · Reset Display Colors… | — |  |
| Keep this level? · Go Back · Keep | — | the very-dark-level prompt |
| Pause · Paused · Resume | — | a temporary stop; never “disabled” |

## Carried from Cranny (generic interface words)

| English | th | Note |
|---|---|---|
| Settings | การตั้งค่า | Apple's term |
| Allow… / Grant… | อนุญาต… |  |
| Reset to Default | รีเซ็ตเป็นค่าเริ่มต้น | Apple's term |
| Changed from the default | เปลี่ยนจากค่าเริ่มต้นแล้ว |  |
| Remove (from a list) / Delete | เอาออก / ลบ | Apple: Remove = เอาออก; "ลบแอป" would read as uninstalling |
| App not installed | ไม่ได้ติดตั้งแอป |  |
| Shortcuts (Apple's app) / a shortcut in it | คำสั่งลัด | glossary |
| keyboard shortcut | ปุ่มลัด | Apple: Keyboard Shortcuts = ปุ่มลัดแป้นพิมพ์ |
| click / press (key) | คลิก / กด |  |
| Never (timeout 0) | ไม่เลย | Apple's term |
| Preview (noun) | ตัวอย่าง |  |
| Launch at login / Open at login | เปิดเมื่อเข้าสู่ระบบ | Apple's term |
| Login Items | รายการเข้าสู่ระบบ | glossary |
| update / check for updates | อัปเดต / ตรวจหารายการอัปเดต | Apple's term; Update Available = มีรายการอัปเดต; Version %@ is available = เวอร์ชัน %@ พร้อมให้ใช้งานแล้ว (not “มีเวอร์ชัน %@ แล้ว”, which reads “you already have”) |
