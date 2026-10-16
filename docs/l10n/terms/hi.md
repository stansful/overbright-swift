# Overbright — Hindi (हिन्दी, `hi`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted, and examples and notes that named Cranny’s features (the notch, the Tray, widgets, Calendar, Notes,
Media, permissions) were replaced with Overbright’s or dropped. Overbright’s own names, its pane names among them,
were decided in WP15 (ARCHITECTURE.md §10.17, §8.8); the table shows them as the catalogs ship them.
`scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register and style, following macOS 27 in Hindi (checked against the system's own loctables on this Mac):

- Formal **आप**; buttons and menu commands in the polite imperative (**खोलें, दिखाएँ, हटाएँ, रद्द करें, जारी रखें**), the way
  macOS writes them. Toggles are imperative phrases too (macOS: “मेन्यू बार में दिखाएँ”).
- Apple's Hindi keeps many established English words in Devanagari (ऐक्सेस, सेटिंग, डिलीट करें, मूव करें, स्किप करें,
  ऑटोमैटिक, ब्राइटनेस, फ़ुल स्क्रीन). Overbright follows that hybrid register instead of Sanskritised coinages.
- Full stop is the danda **।**; ? and ! as in English; ellipsis **…** (U+2026); quotes **“…”** (and ‘…’ inside).
  Nukta spellings as macOS: फ़ाइल, फ़ोल्डर, फ़ोकस, डिफ़ॉल्ट.
- Apple names a pane without quotes in running text (“सिस्टम सेटिंग में लॉगइन आइटम खोलें”) and an app as “<name> ऐप”
  (शॉर्टकट ऐप, फ़ोटो ऐप) — also inside parentheses and lists (“(फ़ोटो ऐप, QuickTime Player)”), because bare फ़ोटो
  reads as the common noun “photos”. A pane whose name is an ordinary word gets quotes and पेन, as Apple does
  (“… “सामान्य” पेन में …”, cf. Apple “… “डाउनटाइम” पेन …”). Settings paths keep Overbright's ▸.
- “never X or Y”: the correlative **न तो … न ही …** (“Overbright उन्हें न तो कभी बदलता है, न ही अपलोड करता है।”), never
  “कभी न X है, न Y है”.
- Postpositions after names stay separate words: “Overbright को”, “Overbright में”, “Overbright का”. Overbright is grammatically
  **masculine** (“Overbright खुलता है”, like ऐप). macOS: “macOS ने … नहीं जोड़ा”.
- Plurals: one/other. Loan nouns do not inflect (1 डिस्प्ले / 3 डिस्प्ले, 1 आइटम / 3 आइटम), so most forms are identical but every
  plural key still gets both.
- Abbreviated units as Foundation writes them for hi: घं॰, मि॰, से॰, मि॰से॰ (ms). Points: “%@ पॉइंट” (System Settings ▸
  Accessibility text size), pixels: पिक्सेल.

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
| Settings panes: General · Displays · Automations · Shortcuts · Fill Light · Advanced · About | सामान्य · डिस्प्ले · ऑटोमेशन · कीबोर्ड शॉर्टकट · फ़िल लाइट · एडवांस · परिचय | the sidebar and window titles |
| Standard (the brightness macOS shows) | मानक | never “100 %” or “normal mode” |
| extra brightness (the boost half) | “अतिरिक्त ब्राइटनेस इस्तेमाल करें” (Use extra brightness) | never “boost”, “HDR mode”, “EDR” |
| Dim below minimum (the setting) | “न्यूनतम से नीचे डिम करना चालू या बंद करें” (Dim Below Minimum On or Off) | the incumbent’s name for it is never used |
| Dimmed (the state) · Dim All Displays / Stop Dimming (actions) | डिम किया गया · सभी डिस्प्ले डिम करें / डिम करना बंद करें | not “night mode” |
| Brighter · Less Bright (one step) | ज़्यादा ब्राइट · कम ब्राइट | never “Dimmer”: it reads like Dim |
| Back to Standard (the instant off) | मानक पर वापस जाएँ | not “panic”, not “reset brightness” |
| Indoor · Bright room · Sunlight · Max (presets) | घर के अंदर · रोशन कमरा · धूप · अधिकतम | “Max” is a preset only |
| Safe · Peak (ceilings) | सुरक्षित · पीक | Peak, never “Max”, for a ceiling; one short word each (segments) |
| Compatibility mode · Color table (methods) | संगतता मोड · रंग टेबल | never “fallback” or “overlay” |
| Fill Light (the edge light for video calls) | फ़िल लाइट | never “ring light” |
| extra range (headroom, in user copy) | अतिरिक्त रेंज | “headroom” only in Advanced and diagnostics |
| Calibrate… · Run Self-Test… · Reset Display Colors… | कैलिब्रेट करें… · सेल्फ़-टेस्ट चलाएँ… · डिस्प्ले के रंग रीसेट करें… |  |
| Keep this level? · Go Back · Keep | यह स्तर रखें? · वापस जाएँ · रखें | the very-dark-level prompt |
| Pause · Paused · Resume | “Overbright पॉज़ करें” (Pause Overbright) · पॉज़ किया गया · जारी रखें | a temporary stop; never “disabled” |

## Carried from Cranny (generic interface words)

| English | hi | Note |
|---|---|---|
| Overbright | Overbright | never translated/transliterated; masculine |
| welcome (window) | स्वागत | “Overbright में आपका स्वागत है” |
| keys / keyboard shortcut | कीज़ / कीबोर्ड शॉर्टकट | Overbright's Shortcuts pane (key bindings) = कीबोर्ड शॉर्टकट |
| Open / Close / Quit Overbright | खोलें / बंद करें / Overbright बंद करें |  |
| About / About Overbright | परिचय / Overbright परिचय |  |
| Add / Remove / Delete | जोड़ें / हटाएँ / डिलीट करें |  |
| Done | पूर्ण |  |
| Cancel / Continue / Back / Skip | रद्द करें / जारी रखें / वापस / स्किप करें |  |
| Undo | पहले जैसा करें |  |
| Try again | फिर कोशिश करें |  |
| Reset to Default · Changed from the default | डिफ़ॉल्ट पर रीसेट करें · डिफ़ॉल्ट से बदला गया |  |
| Allow… / Grant… | अनुमति दें… |  |
| On / Off · Never · Automatic | चालू / बंद · कभी नहीं · ऑटोमैटिक |  |
| Preview | प्रीव्यू |  |
