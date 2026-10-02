import SwiftUI

struct PulseDetailsSheet: View {
    @ObservedObject var store: PulseStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Your signal") {
                    LabeledContent("Source", value: store.sourceName ?? "No watch connected")
                    LabeledContent("Status", value: store.isDemo ? "Demo · Sample data" : store.signalStatus)
                    if !store.isPrivacySafe {
                        LabeledContent("Last update", value: store.measurementAgeText)
                        if let value = store.snapshot.liveBPM {
                            LabeledContent("Heart rate", value: "\(value) BPM")
                        }
                        if let low = store.snapshot.minimumBPM,
                           let high = store.snapshot.maximumBPM {
                            LabeledContent("Recent range", value: "\(low)–\(high) BPM")
                        }
                    }
                }

                Section("Pulse in motion") {
                    Text("The 3D heart moves at a pace estimated from your latest heart-rate reading. It isn't an ECG and doesn't show the exact timing of individual heartbeats.")
                    Text("Pause motion freezes the heart, not the readings. Reduce Motion also keeps the heart still.")
                }

                Section("Recent, not recorded") {
                    Text("The graph keeps up to 60 recent readings from the last minute in memory. Missing periods stay gaps. Low and high refer only to that visible window.")
                    Text("A reading more than five seconds old is no longer shown as live. Leaving the app or disconnecting clears the readings and the graph.")
                    Text("Your pulse stays on this device. No account, upload, saved session or notification access is used.")
                }
            }
            .accessibilityIdentifier("pulseDetailsSheet")
            .navigationTitle("About your pulse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
