# Overbright — Turkish (Türkçe, `tr`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted, and examples and notes that named Cranny’s features (the notch, the Tray, widgets, Calendar, Notes,
Media, permissions) were replaced with Overbright’s or dropped. Overbright’s own names, its pane names among them,
were decided in WP15 (ARCHITECTURE.md §10.17, §8.8); the table shows them as the catalogs ship them.
`scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register: formal *siz* (instructions end in -in/-ın/-un/-ün: “Tıklayın”, “Seçin”, “Deneyin”), as macOS does.
Buttons and menu commands are bare imperatives (“Aç”, “Sil”, “Yeniden dene”). Where English uses Title Case for
standard macOS chrome (menu bar items, “Reset to Default”, “Check Now”), Turkish uses Title Case as
macOS Türkçe does (“Güncellemeleri Denetle…”, “Saptanmışa Dön”); everything else is sentence case. Toggles are
imperatives in sentence case like System Settings (“Menü çubuğunda göster”). Errors are passive: “… okunamadı”,
“… kaydedilemedi”. Yes/no confirmation titles use the passive question with a no-break space before the particle,
as macOS writes it: “Silinsin mi?”, “Sıfırlansın mı?”.

Typography: quotes “…” (inner ‘…’), apostrophe ’ before suffixes on names (Overbright’ı, Finder’da,
Sistem Ayarları’nda), one-character ellipsis …, no suffix directly on a placeholder: “%@ uygulaması”, “%@ adlı…”,
or the Apple pattern “Sil: “%@””. Dotted/dotless i: İ/i, I/ı. Turkish nouns stay singular after a number
(“3 öğe”), so plural forms one/other are usually identical.

### The brand

“Overbright” is never translated; suffixes go after an apostrophe and follow the pronunciation (“overbrayt”): Overbright’ı · Overbright’a · Overbright’ta · Overbright’tan · Overbright’ın — confirmed in WP15 (ARCHITECTURE.md §10.17): the shipped strings use Overbright’ı, Overbright’ın, Overbright’tan and Overbright’a.

## Apple names (`apple-terms.py tr` on macOS 27.0.1 — never paraphrased)

| English | tr |
|---|---|
| System Settings | Sistem Ayarları |
| Finder | Finder |
| Shortcuts | Kestirmeler |
| Photos | Fotoğraflar |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | Gizlilik ve Güvenlik |
| Accessibility | Erişilebilirlik |
| General | Genel |
| Appearance | Görünüş |
| Menu Bar | Menü Çubuğu |
| Control Center | Denetim Merkezi |
| Focus | Odak |
| Displays | Ekranlar |
| Keyboard | Klavye |
| Keyboard Shortcuts… | Klavye Kestirmeleri… |
| Lock Screen | Kilitli Ekran |
| Battery | Pil |
| Energy | Enerji |
| Screen Saver | Ekran Koruyucu |
| Login Items | Oturum Açma Öğeleri |
| Login Items & Extensions | Oturum Açma Öğeleri ve Genişletmeler |
| Brightness | Parlaklık |
| Automatically adjust brightness | Parlaklığı otomatik olarak ayarla |
| True Tone | True Tone |
| High Dynamic Range | Yüksek Dinamik Aralık |
| Preset | Ön Ayar |
| Night Shift… | Night Shift… |
| Color profile | Renk profili |
| Refresh rate | Yenileme hızı |
| Allow in the Menu Bar | Menü Çubuğunda İzin Ver |
| Low Power Mode | Düşük Güç Modu |
| Do Not Disturb | Rahatsız Etme |
| Camera | Kamera |
| Open Anyway | Yine de Aç |
| Applications | Uygulamalar |
| Reduce motion | Hareketi azalt |
| Reduce transparency | Saydamlığı azalt |
| Increase contrast | Kontrastı artır |
| Differentiate without color | Renk olmadan farklılaştır |
| VoiceOver | VoiceOver |

## Overbright’s own names

| English | tr | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated |
| Settings panes: General · Displays · Automations · Shortcuts · Fill Light · Advanced · About | Genel · Ekranlar · Otomasyonlar · Klavye Kestirmeleri · Yüz Işığı · İleri Düzey · Hakkında | the sidebar and window titles |
| Standard (the brightness macOS shows) | Standart | never “100 %” or “normal mode” |
| extra brightness (the boost half) | “Ek parlaklığı kullan” (Use extra brightness) | never “boost”, “HDR mode”, “EDR” |
| Dim below minimum (the setting) | “Minimumun Altına Karartmayı Aç veya Kapat” (Dim Below Minimum On or Off) | the incumbent’s name for it is never used |
| Dimmed (the state) · Dim All Displays / Stop Dimming (actions) | Karartıldı · Tüm Ekranları Karart / Karartmayı Durdur | not “night mode” |
| Brighter · Less Bright (one step) | Daha Parlak · Daha Az Parlak | never “Dimmer”: it reads like Dim |
| Back to Standard (the instant off) | Standart’a Dön | not “panic”, not “reset brightness” |
| Indoor · Bright room · Sunlight · Max (presets) | İç mekân · Aydınlık oda · Güneş ışığı · Maksimum | “Max” is a preset only |
| Safe · Peak (ceilings) | Güvenli · Tepe | Peak, never “Max”, for a ceiling; one short word each (segments) |
| color table (in sentences: “macOS ignores color table changes”) | renk tablosu | never “gamma”; no “fallback” or “overlay” in copy |
| Fill Light (the edge light for video calls) | Yüz Işığı | never “ring light” |
| extra range (headroom, in user copy) | Parlaklık payı | “headroom” only in Advanced and diagnostics |
| Calibrate… · Run Self-Test… · Reset Display Colors… | Kalibre Et… · Öz Testi Çalıştır… · Ekran Renklerini Sıfırla… |  |
| Keep this level? · Go Back · Keep | Bu düzey korunsun mu? · Geri Dön · Koru | the very-dark-level prompt |
| Pause · Paused · Resume | “Overbright’ı Duraklat” (Pause Overbright) · Duraklatıldı · Sürdür | a temporary stop; never “disabled” |

Fit (WP15): the footer’s default row (Battery, Auto-pause, Timer) must fit its 304 pt in full in every language (`FooterFitTests`), so the Auto-pause chip reads “Duraklatma” (off: “Duraklatma yok”) and the Timer chip “Süresiz” for No timer.

## Carried from Cranny (generic interface words)

| English | tr | Note |
|---|---|---|
| keyboard shortcut | klavye kestirmesi | Apple: “Klavye Kestirmeleri”; “kestirme” alone only when the keyboard is obvious |
| Settings | Ayarlar | “Ayarlar ▸ Genel” |
| Allow… / Grant… | İzin Ver… | as the system prompt’s button |
| Done (button) | Bitti | Apple’s Done |
| Reset to Default | Saptanmışa Dön | Apple’s phrase; default = saptanmış |
| Changed from the default | Saptanmış değerden farklı |  |
| Remove (from a list) · Delete | Kaldır · Sil | “Listeden kaldır” where “kaldır” could read as uninstall |
| Cancel | Vazgeç | Apple’s Cancel |
| Try again / Retry | Yeniden dene |  |
| Record Shortcut · Type shortcut | Kestirme Kaydet · Tuşlara basın | indefinite: “Kestirmeyi Kaydet” reads as “Save the shortcut” |
| click | tıklama · tıklayın |  |
| Off · On | Kapalı · Açık | VoiceOver values lowercase: kapalı · açık |
| Never · Automatic · None | Hiçbir zaman · Otomatik · Yok |  |
| Login Items · Launch at login | Oturum Açma Öğeleri · Oturum açıldığında aç | “Sistem Ayarları’ndaki Oturum Açma Öğeleri bölümünde” (one locative chain, not “Ayarları’nda … bölümünde”) |
| Undo | Geri al |  |
| Check for Updates | Güncellemeleri Denetle | update check = güncelleme denetimi |
| Step X of Y (VoiceOver) | Adım %1$lld / %2$lld | a spaced slash, as Apple’s VoiceOver (Sayfa %1$d / %2$d); “3/5” is read as a fraction |
| Space (the space bar in key caps) | Boşluk | as AppKit writes it in menu key equivalents (FunctionKeyNames.loctable “Space”), so Settings and Welcome show the same key caps as the menu; AppKit’s name for the physical key is Boşluk çubuğu |
