// OverbrightSettingsUI/Components/Acknowledgments.swift — the Acknowledgments sheet of Settings ▸ About (DESIGN.md
// §7.9): the same entries as THIRD_PARTY_NOTICES.md (ARCHITECTURE.md D2). Cranny's MIT notice is reproduced verbatim
// (legal text, not translated); the projects studied for ideas are credited with one sentence each. The spelling is
// American ("Acknowledgments"), which the copy lint enforces.
import Foundation
import OverbrightDesign
import SwiftUI

/// One credited project.
struct AcknowledgmentEntry: Identifiable, Equatable {
    let name: String
    let license: String
    let url: URL?
    let note: String
    var id: String { name }

    /// Every entry of THIRD_PARTY_NOTICES.md, Cranny first.
    static var all: [AcknowledgmentEntry] {
        [
            AcknowledgmentEntry(name: "Cranny", license: "MIT", url: nil,
                                note: String(localized: "Parts of the build scripts, translation tools, settings store, keyboard shortcuts and update check come from Cranny, by the same author.",
                                             bundle: .module, comment: "Settings ▸ About ▸ Acknowledgments: what Overbright uses from Cranny (keep the name)")),
            AcknowledgmentEntry(name: "xdr-boost", license: "MIT", url: URL(string: "https://github.com/levelsio/xdr-boost"),
                                note: String(localized: "The idea behind Compatibility mode: a full-screen overlay that multiplies the picture. No code was copied.",
                                             bundle: .module, comment: "Settings ▸ About ▸ Acknowledgments: what Overbright learned from xdr-boost")),
            AcknowledgmentEntry(name: "xdr-light", license: "MIT", url: URL(string: "https://github.com/lichengzhe/xdr-light"),
                                note: String(localized: "Pairing a tiny trigger for the display’s extra range with color table scaling. No code was copied.",
                                             bundle: .module, comment: "Settings ▸ About ▸ Acknowledgments: what Overbright learned from xdr-light")),
            AcknowledgmentEntry(name: "displaytint", license: "MIT", url: URL(string: "https://github.com/noahlincke/displaytint"),
                                note: String(localized: "Its report that macOS restores a display’s colors when the app that changed them quits. No code was copied.",
                                             bundle: .module, comment: "Settings ▸ About ▸ Acknowledgments: what Overbright learned from displaytint")),
            AcknowledgmentEntry(name: "MonitorControl", license: "MIT", url: URL(string: "https://github.com/MonitorControl/MonitorControl"),
                                note: String(localized: "How color table changes behave in screenshots. No code was copied.",
                                             bundle: .module, comment: "Settings ▸ About ▸ Acknowledgments: what Overbright learned from MonitorControl")),
        ]
    }

    /// Cranny's MIT notice, reproduced as the license requires (not translated).
    static let crannyNotice = """
        MIT License

        Copyright (c) 2026 Cranny contributors

        Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated \
        documentation files (the "Software"), to deal in the Software without restriction, including without limitation \
        the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and \
        to permit persons to whom the Software is furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all copies or substantial portions of \
        the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO \
        THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE \
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF \
        CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS \
        IN THE SOFTWARE.
        """
}

/// The Acknowledgments sheet.
struct AcknowledgmentsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Text("Acknowledgments", bundle: .module, comment: "Settings ▸ About: title of the acknowledgments sheet")
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    ForEach(AcknowledgmentEntry.all) { entry in
                        VStack(alignment: .leading, spacing: Space.xxs) {
                            HStack(spacing: Space.s) {
                                if let url = entry.url {
                                    Link(destination: url) { Text(verbatim: entry.name) }
                                } else {
                                    Text(verbatim: entry.name).fontWeight(.medium)
                                }
                                Text(verbatim: entry.license).font(.caption).foregroundStyle(.secondary)
                            }
                            Text(verbatim: entry.note).font(.callout).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    Text(verbatim: AcknowledgmentEntry.crannyNotice)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .environment(\.layoutDirection, .leftToRight)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("Done", bundle: .module, comment: "Settings ▸ About: closes the acknowledgments sheet (title case)")
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Space.xxl)
        .frame(width: SettingsMetrics.acknowledgmentsSize.width, height: SettingsMetrics.acknowledgmentsSize.height)
    }
}

#Preview("Acknowledgments") {
    AcknowledgmentsSheet()
}
