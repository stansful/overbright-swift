// OverbrightCore/OverbrightCore.swift — module overview. ARCHITECTURE.md §2.1, §3.
//
// The L0 contracts every other module codes against (nonisolated by default; UI-facing classes are @MainActor):
//   Platform/   ported from Cranny: logging, paths, JSON files, launch arguments, app identity, the real TimeSource,
//               and MachineIdentity (sysctl hw.model, kern.osversion).
//   Settings/   SettingsStore (Cranny's, per-key Observation), SettingsUpgrades (revision 0), InMemoryDefaults and the
//               keys catalog of §3.8 (Keys/, one file per namespace).
//   Model/      the value types of §3.2–§3.5, one per file (Displays, System, Policy, Engine, App).
//   Ports/      the protocols of §3.6, one per file.
//   Shortcuts/  the global shortcut identifiers and their default catalog (§3.7).
//   Services/   OverbrightServices (the hub), OwnEDRSurfaces, Announcer, RingBufferJournal (§3.9).
//   Fakes/      one fake per port plus the display fixtures (§3.9): public, used by tests, #Previews and --qa-simulate.
//   Additions/  new types and extension methods staged by a contract-lane PR (§10.0).
//
// Core stays UI-free and string-free: the user-facing names and sentences of its enums live in OverbrightDesign (§8.8).
// Changes after WP0a go through the contract lane (§10.0).
