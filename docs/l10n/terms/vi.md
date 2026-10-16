# Overbright — Vietnamese (Tiếng Việt, `vi`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted, and examples and notes that named Cranny’s features (the notch, the Tray, widgets, Calendar, Notes,
Media, permissions) were replaced with Overbright’s or dropped. Overbright’s own names, its pane names among them,
were decided in WP15 (ARCHITECTURE.md §10.17, §8.8); the table shows them as the catalogs ship them.
`scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register and typography (as macOS writes Vietnamese):

- Neutral, polite register; "bạn" for "you", used sparingly as Apple does. No "quý khách", no particles (nhé, ạ).
- Sentence case everywhere. Apple's names and Overbright's own named features keep their initial capital
  mid-sentence, as Apple does with "Chuyển vào Thùng rác", "trong Trung tâm điều khiển".
- Buttons and menu items are bare imperative verbs ("Mở", "Hủy", "Kiểm tra bản cập nhật…");
  status words are adjectives/participles with "Đã" where Apple does ("Đã tạm dừng", "Đã sao chép").
- Apple's diacritic placement: hóa, khóa, hủy, thủy (not hoá, khoá, huỷ).
- Quotes “…” (secondary ‘…’), ellipsis … (U+2026), no straight quotes. Apple setting names and Overbright row names
  inside a sentence go in “…”; pane paths keep the arrow: "Cài đặt ▸ Cài đặt chung".
- Vietnamese has no grammatical plural: the single plural form "other" holds every count ("%lld mục", "%lld màn hình").
- Numbers, durations, dates arrive formatted (vi narrow duration: "4ph", "1g 5ph").
- "Overbright" is never translated or transliterated; it takes no inflection in Vietnamese.


## Apple names (`apple-terms.py vi` on macOS 27.0.1 — never paraphrased)

| English | vi |
|---|---|
| System Settings | Cài đặt hệ thống |
| Finder | Finder |
| Shortcuts | Phím tắt |
| Photos | Ảnh |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | Quyền riêng tư & Bảo mật |
| Accessibility | Trợ năng |
| General | Cài đặt chung |
| Appearance | Giao diện |
| Menu Bar | Thanh menu |
| Control Center | Trung tâm điều khiển |
| Focus | Tập trung |
| Displays | Màn hình |
| Keyboard | Bàn phím |
| Keyboard Shortcuts… | Phím tắt… |
| Lock Screen | Màn hình khóa |
| Battery | Pin |
| Energy | Năng lượng |
| Screen Saver | Trình bảo vệ màn hình |
| Login Items | Mục đăng nhập |
| Login Items & Extensions | Mục đăng nhập & Phần mở rộng |
| Brightness | Độ sáng |
| Automatically adjust brightness | Tự động điều chỉnh độ sáng |
| True Tone | True Tone |
| High Dynamic Range | Dải tần nhạy sáng cao |
| Preset | Đặt trước |
| Night Shift… | Night Shift… |
| Color profile | Cấu hình màu |
| Refresh rate | Tốc độ làm mới |
| Allow in the Menu Bar | Cho phép trong thanh menu |
| Low Power Mode | Chế độ nguồn điện thấp |
| Do Not Disturb | Không làm phiền |
| Camera | Camera |
| Open Anyway | Vẫn mở |
| Applications | Ứng dụng |
| Reduce motion | Giảm chuyển động |
| Reduce transparency | Giảm độ trong suốt |
| Increase contrast | Tăng độ tương phản |
| Differentiate without color | Tạo sự khác biệt mà không có màu |
| VoiceOver | VoiceOver |

## Overbright’s own names

| English | vi | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated |
| Settings panes: General · Displays · Automations · Shortcuts · Fill Light · Advanced · About | Cài đặt chung · Màn hình · Tự động hóa · Tổ hợp phím · Đèn phụ · Nâng cao · Giới thiệu | the sidebar and window titles |
| Standard (the brightness macOS shows) | Tiêu chuẩn | never “100 %” or “normal mode” |
| extra brightness (the boost half) | “Dùng độ sáng bổ sung” (Use extra brightness) | never “boost”, “HDR mode”, “EDR” |
| Dim below minimum (the setting) | “Bật hoặc tắt Làm tối dưới mức tối thiểu” (Dim Below Minimum On or Off) | the incumbent’s name for it is never used |
| Dimmed (the state) · Dim All Displays / Stop Dimming (actions) | Đã làm tối · Làm tối tất cả màn hình / Dừng làm tối | not “night mode” |
| Brighter · Less Bright (one step) | Sáng hơn · Bớt sáng | never “Dimmer”: it reads like Dim |
| Back to Standard (the instant off) | Trở về Tiêu chuẩn | not “panic”, not “reset brightness” |
| Indoor · Bright room · Sunlight · Max (presets) | Trong nhà · Phòng sáng · Ánh nắng · Tối đa | “Max” is a preset only |
| Safe · Peak (ceilings) | An toàn · Đỉnh | Peak, never “Max”, for a ceiling; one short word each (segments) |
| Compatibility mode · Color table (methods) | Chế độ tương thích · Bảng màu | never “fallback” or “overlay” |
| Fill Light (the edge light for video calls) | Đèn phụ | never “ring light” |
| extra range (headroom, in user copy) | Dải sáng bổ sung | “headroom” only in Advanced and diagnostics |
| Calibrate… · Run Self-Test… · Reset Display Colors… | Hiệu chỉnh… · Chạy tự kiểm tra… · Đặt lại màu màn hình… |  |
| Keep this level? · Go Back · Keep | Giữ mức này? · Quay lại · Giữ | the very-dark-level prompt |
| Pause · Paused · Resume | “Tạm dừng Overbright” (Pause Overbright) · Đã tạm dừng · Tiếp tục | a temporary stop; never “disabled” |

## Carried from Cranny (generic interface words)

| English | vi | Note |
|---|---|---|
| Settings | Cài đặt | Apple's term |
| Allow… / Grant… | Cho phép… | Apple's Allow = Cho phép |
| Reset to Default | Đặt lại về mặc định | Apple's term |
| Changed from the default | Đã thay đổi so với mặc định |  |
| App not installed | Ứng dụng chưa được cài đặt |  |
| Shortcuts (Apple's app) / a shortcut in it | Phím tắt / phím tắt | glossary; "ứng dụng Phím tắt" where ambiguous ("Ứng dụng Phím tắt không khả dụng…") |
| keyboard shortcut | tổ hợp phím | kept apart from the Shortcuts app, whose Vietnamese name is also "Phím tắt" |
| click / press (key) | bấm / nhấn | Apple: Click = Bấm |
| Never (timeout 0) | Không bao giờ |  |
| Preview (noun) | bản xem trước | "Xem trước" is also Apple's Preview app |
| Launch at login / Open at login | Mở khi đăng nhập | Apple's term |
| Login Items | Mục đăng nhập | glossary |
| update / check for updates | bản cập nhật / kiểm tra bản cập nhật |  |
