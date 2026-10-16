# Overbright — Hindi (हिन्दी, `hi`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted. Overbright’s own names are decided in WP15 (ARCHITECTURE.md §10.17, §8.8); until then they
read “—”. `scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register and style, following macOS 27 in Hindi (checked against the system's own loctables on this Mac):

- Formal **आप**; buttons and menu commands in the polite imperative (**खोलें, दिखाएँ, हटाएँ, रद्द करें, जारी रखें**), the way
  macOS writes them. Toggles are imperative phrases too (macOS: “मेन्यू बार में दिखाएँ”).
- Apple's Hindi keeps many established English words in Devanagari (ऐक्सेस, सेटिंग, डिलीट करें, मूव करें, स्किप करें,
  ऑटोमैटिक, ब्राइटनेस, वॉल्यूम, फ़ुल स्क्रीन). Overbright follows that hybrid register instead of Sanskritised coinages.
- Full stop is the danda **।**; ? and ! as in English; ellipsis **…** (U+2026); quotes **“…”** (and ‘…’ inside).
  Nukta spellings as macOS: फ़ाइल, फ़ोल्डर, फ़ोकस, डिफ़ॉल्ट, ज़िप.
- Apple names a pane without quotes in running text (“सिस्टम सेटिंग में लॉगइन आइटम खोलें”) and an app as “<name> ऐप”
  (संगीत ऐप, शॉर्टकट ऐप) — also inside parentheses and lists (“Apple Events (संगीत ऐप, Spotify)”), because bare संगीत
  reads as the common noun “music”. A pane whose name is an ordinary word gets quotes and पेन, as Apple does
  (“… “सामान्य” पेन में …”, cf. Apple “… “डाउनटाइम” पेन …”). Settings paths keep Overbright's ▸.
- “never X or Y”: the correlative **न तो … न ही …** (“Overbright उन्हें न तो कभी बदलता है, न ही अपलोड करता है।”), never
  “कभी न X है, न Y है”.
- Postpositions after names stay separate words: “Overbright को”, “Overbright में”, “Overbright का”. Overbright is grammatically
  **masculine** (“Overbright खुलता है”, like ऐप). macOS: “macOS ने … नहीं जोड़ा”.
- Plurals: one/other. Loan nouns do not inflect (1 सेल / 3 सेल, 1 आइटम / 3 आइटम), so most forms are identical but every
  plural key still gets both.
- Abbreviated units as Foundation writes them for hi: घं॰, मि॰, से॰, मि॰से॰ (ms). Points: “%@ पॉइंट” (System Settings ▸
  Accessibility text size), pixels: पिक्सेल.
- Typed timer durations stay Latin (“25 या 90s”): `DurationParser` accepts English and Russian unit words only, so a
  Devanagari suffix (90से॰) would not parse.

## Apple names (`apple-terms.py hi` on macOS 27.0.1 — never paraphrased)

| English | hi |
|---|---|
| System Settings | सिस्टम सेटिंग |
| Finder | Finder |
| Shortcuts | शॉर्टकट |
| Photos | तस्वीर |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | गोपनीयता और सुरक्षा |
| Accessibility | ऐक्सेसिबिलिटी |
| General | सामान्य |
| Appearance | प्रकटन |
| Menu Bar | मेन्यू बार |
| Control Center | कंट्रोल सेंटर |
| Focus | फ़ोकस |
| Displays | डिस्प्ले |
| Keyboard | कीबोर्ड |
| Keyboard Shortcuts… | कीबोर्ड शॉर्टकट… |
| Lock Screen | लॉक स्क्रीन |
| Battery | बैटरी |
| Energy | ऊर्जा |
| Screen Saver | स्क्रीन सेवर |
| Login Items | लॉगइन आइटम |
| Login Items & Extensions | लॉगइन आइटम और एक्सटेंशन |
| Brightness | ब्राइटनेस |
| Automatically adjust brightness | ब्राइटनेस ऑटोमैटिकली ऐडजस्ट करें |
| True Tone | True Tone |
| High Dynamic Range | हाई डाइनैमिक रेंज |
| Preset | प्रीसेट |
| Night Shift… | Night Shift… |
| Color profile | रंग प्रोफ़ाइल |
| Refresh rate | रीफ़्रेश दर |
| Allow in the Menu Bar | मेन्यू बार में अनुमति दें |
| Low Power Mode | निम्न पावर मोड |
| Do Not Disturb | डू नॉट डिस्टर्ब |
| Camera | कैमरा |
| Open Anyway | फिर भी खोलें |
| Applications | ऐप्लिकेशन |
| Reduce motion | गति घटाएँ |
| Reduce transparency | पारदर्शिता घटाएँ |
| Increase contrast | कॉन्ट्रास्ट बढ़ाएँ |
| Differentiate without color | रंग के बिना अंतर करें |
| VoiceOver | VoiceOver |

## Overbright’s own names

| English | hi | Note |
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

| English | hi | Note |
|---|---|---|
| Overbright | Overbright | never translated/transliterated; masculine |
| welcome (window) | स्वागत | “Overbright में आपका स्वागत है” |
| keys / keyboard shortcut | कीज़ / कीबोर्ड शॉर्टकट | “Shortcuts” in Settings ▸ Keyboard = कीबोर्ड शॉर्टकट |
| Open / Close / Quit Overbright | खोलें / बंद करें / Overbright बंद करें |  |
| About / About Overbright | परिचय / Overbright परिचय |  |
| Add / Remove / Delete | जोड़ें / हटाएँ / डिलीट करें |  |
| Done | पूर्ण (flash words in the wings: हो गया; Done editing = संपादन समाप्त करें; All done = सब हो गया) |  |
| Cancel / Continue / Back / Skip | रद्द करें / जारी रखें / वापस / स्किप करें |  |
| Undo | पहले जैसा करें |  |
| Try again | फिर कोशिश करें |  |
| Reset to Default · Changed from the default | डिफ़ॉल्ट पर रीसेट करें · डिफ़ॉल्ट से बदला गया |  |
| Allow… / Grant… | अनुमति दें… |  |
| On / Off · Never · Automatic | चालू / बंद · कभी नहीं · ऑटोमैटिक |  |
| Preview | प्रीव्यू |  |
