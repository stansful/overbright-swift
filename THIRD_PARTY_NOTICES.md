# Third-party notices

Overbright has zero dependencies: no Swift packages, no vendored libraries, no fonts, sounds, images or animations
made by others. It uses Apple's system frameworks and SF Symbols at runtime, under Apple's terms, and bundles no
Apple fonts or artwork.

Overbright does include code derived from one other project, Cranny, under the MIT License reproduced below.

## Cranny

Portions of the scaffold, build scripts, localization tooling, settings store, hot-key center and update checker
are derived from Cranny, an MIT-licensed macOS app by the same owner.

```
MIT License

Copyright (c) 2026 Cranny contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Acknowledgements

These projects were studied for *ideas* only. No code, assets or text were copied from them, so no license
obligations apply; we credit them as a courtesy (Settings ▸ About lists them too).

| Project | License | What we learned |
|---|---|---|
| [levelsio/xdr-boost](https://github.com/levelsio/xdr-boost) | MIT | Studied for a full-screen EDR overlay with multiply compositing, which Overbright tried and removed. No code was copied. |
| [lichengzhe/xdr-light](https://github.com/lichengzhe/xdr-light) | MIT | Pairing a small EDR trigger with transfer-table scaling, and keeping the trigger alive. |
| [noahlincke/displaytint](https://github.com/noahlincke/displaytint) | MIT | Its report that macOS reverts a process's transfer tables when that process dies. |
| [MonitorControl/MonitorControl](https://github.com/MonitorControl/MonitorControl) | MIT | How transfer-table changes behave in screenshots. |
