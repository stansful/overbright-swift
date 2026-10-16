# Research summaries

Public-safe summaries of the research done before Overbright's code was written. They state behaviour, public-API facts, published specifications and read-only measurements on the project owner's Mac. They contain no disassembly, no addresses and nothing about any competitor beyond what that competitor publishes or what users publicly report. The full reports stay outside the repository.

| File | What it covers |
|---|---|
| [`edr-mechanism.md`](edr-mechanism.md) | How EDR headroom and the transfer table combine into extra brightness, trigger options, the linear-vs-encoded question, what resets tables, what macOS does when a process dies, the overlay technique, known OS bugs, Swift 6 pitfalls, sources and licences |
| [`display-facts.md`](display-facts.md) | What `NSScreen` reports per display and preset, SDR white, peaks and grants, IORegistry keys, presets, what is still to measure |
| [`ux-landscape.md`](ux-landscape.md) | The incumbent and competitors from public sources, user complaints and praise, platform design notes, the improvement list and where each item landed in DESIGN.md and ARCHITECTURE.md |

This folder is exempt from the docs denylist rule (ARCHITECTURE.md D3), because comparing products needs their names. Everything else in the repository names competitors only on lines marked `denylist-ok`.
