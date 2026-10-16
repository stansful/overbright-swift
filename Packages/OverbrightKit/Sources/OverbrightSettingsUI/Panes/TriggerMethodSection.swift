// OverbrightSettingsUI/Panes/TriggerMethodSection.swift — Advanced ▸ Trigger method (DESIGN.md §7.8; ARCHITECTURE.md
// §4.7): one pop-up per display with a transfer table (Automatic, or one rung of the ladder: Tagged layer, Metal layer,
// Metal layer refreshed, HDR frame, HDR video still), stored as the display's `triggerOverride`; a method this macOS
// cannot show is disabled with the reason. Forget Learned Methods clears what each display learned.
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// The per-display trigger methods.
struct TriggerMethodSection: View {
    let services: OverbrightServices
    @State private var forgot = false

    /// The displays that have a method to choose: a transfer table of their own (not virtual, not a mirror member).
    static func displays(_ services: OverbrightServices) -> [DisplayFacts] {
        services.displays.displays.filter { $0.gammaCapacity > 0 && $0.panelClass != .virtualDisplay && !$0.isMirrored }
    }

    /// The tagged layer (T1) needs macOS 26 (ARCHITECTURE.md D4).
    static func isAvailable(_ strategy: TriggerStrategy, on machine: MachineIdentity) -> Bool {
        strategy != .taggedLayer || machine.osMajor >= 26
    }

    /// One display's pop-up value and its Reset to Default (Automatic).
    static func value(_ facts: DisplayFacts, services: OverbrightServices) -> RowValue {
        let editor = DisplayPreferencesEditor(settings: services.settings)
        let key = facts.ref.key
        return RowValue(AdvancedRows.triggerMethod(key, name: facts.name),
                        isDefault: { editor.preferences(of: key).triggerOverride == nil }) {
            editor.update(key, name: facts.name) { $0.triggerOverride = nil }
        }
    }

    var body: some View {
        Section {
            ForEach(Self.displays(services), id: \.ref.key) { facts in
                methodRow(facts)
            }
            HStack(spacing: Space.m) {
                Button {
                    services.boost.forgetLearnedMethods()
                    forgot = true
                } label: {
                    Text(verbatim: AdvancedRows.forgetMethods.title)
                }
                if forgot {
                    Text("Every display will find its method again.", bundle: .module,
                         comment: "Settings ▸ Advanced: shown after Forget Learned Methods")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .searchTarget(AdvancedRows.forgetMethods)
        } header: {
            Text(verbatim: AdvancedRows.triggerMethodTitle)
        } footer: {
            Text("Automatic finds the lightest way to unlock extra range on each display and remembers it.",
                 bundle: .module, comment: "Settings ▸ Advanced: note under the trigger methods")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func methodRow(_ facts: DisplayFacts) -> some View {
        let editor = DisplayPreferencesEditor(settings: services.settings)
        let key = facts.ref.key
        let value = Self.value(facts, services: services)
        let selection = Binding<TriggerStrategy?>(get: { editor.preferences(of: key).triggerOverride }, set: { strategy in
            editor.update(key, name: facts.name) { $0.triggerOverride = strategy }
        })
        return Picker(selection: selection) {
            Text(verbatim: CommonNames.automatic()).tag(TriggerStrategy?.none)
            Divider()
            ForEach(TriggerStrategy.allCases, id: \.self) { strategy in
                Text(verbatim: label(strategy))
                    .tag(Optional(strategy))
                    .disabled(!Self.isAvailable(strategy, on: services.machine))
            }
        } label: {
            RowLabel(title: facts.name)
        }
        .pickerStyle(.menu)
        .settingRow(value)
    }

    private func label(_ strategy: TriggerStrategy) -> String {
        let name = strategy.localizedName()
        guard !Self.isAvailable(strategy, on: services.machine) else { return name }
        return String(localized: "\(name) (needs macOS 26 or later)", bundle: .module,
                      comment: "Settings ▸ Advanced: a trigger method this macOS cannot use, disabled in the pop-up; the argument is the method’s name")
    }
}
