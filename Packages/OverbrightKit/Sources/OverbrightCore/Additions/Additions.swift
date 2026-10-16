// OverbrightCore/Additions/ — the contract lane's staging area (ARCHITECTURE.md §10.0 rule 4).
//
// A package that needs a new Core TYPE or extension METHOD before its contract PR has merged may add
// `Additions/<WPnn>-<Topic>.swift` here. Never enum cases, protocol requirements or stored properties: those go through
// the contract PR, which edits the Core file in place. The integration step folds every file here into its final place
// (WP13 moved WP0b's key caps to Shortcuts/KeyCombo+KeyCaps.swift); the folder is empty between phases.
