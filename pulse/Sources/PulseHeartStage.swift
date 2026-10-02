import SwiftUI

/// An immersive presentation of the same store, never a second connection or data source.
struct PulseHeartStage: View {
    @ObservedObject var store: PulseStore
    @Binding var isMotionPaused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var readingSize: CGFloat = 88

    private var hasVisiblePulse: Bool { !store.isPrivacySafe && store.snapshot.liveBPM != nil }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    Group {
                        if geometry.size.width > geometry.size.height && !dynamicTypeSize.isAccessibilitySize {
                            HStack(spacing: 24) {
                                heart.frame(maxWidth: .infinity)
                                    .frame(height: max(230, geometry.size.height - 48))
                                reading.frame(width: min(310, geometry.size.width * 0.3))
                            }
                        } else {
                            VStack(spacing: 12) {
                                heart.frame(height: max(220, min(640, geometry.size.height * 0.62)))
                                reading
                            }
                        }
                    }
                    .frame(maxWidth: 1_400)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .background(PulsePalette.background.ignoresSafeArea())
            .foregroundStyle(PulsePalette.foreground)
            .navigationTitle("Your pulse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(PulsePalette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Close full-screen heart")
                    .accessibilityIdentifier("heartCloseButton")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { isMotionPaused.toggle() } label: {
                        Image(systemName: isMotionPaused ? "play.fill" : "pause.fill")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .disabled(!hasVisiblePulse || reduceMotion)
                    .accessibilityLabel(isMotionPaused ? "Resume heart animation" : "Pause heart animation")
                    .accessibilityHint("Readings continue while the heart is still")
                    .accessibilityIdentifier("heartMotionButton")
                }
            }
            .tint(PulsePalette.action)
        }
    }

    private var heart: some View {
        PulseSculpture(beatsPerMinute: store.isPrivacySafe ? nil : store.snapshot.liveBPM,
                       isActive: hasVisiblePulse && !isMotionPaused)
    }

    private var reading: some View {
        VStack(spacing: 12) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(hasVisiblePulse ? String(store.snapshot.liveBPM ?? 0) : "—")
                    .font(.system(size: readingSize, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .accessibilityIdentifier("heartPulseValue")
                Text("BPM").font(.title3.weight(.medium))
                    .foregroundStyle(PulsePalette.secondary)
            }
            if store.isDemo {
                Text("Demo · Sample data")
                    .font(.headline)
                    .accessibilityIdentifier("heartDemoLabel")
            }
            Text(store.isDemo && hasVisiblePulse ? "Sample signal" : store.signalStatus)
                .font(.headline)
                .accessibilityIdentifier("heartSignalStatus")
            Text(reduceMotion ? "Reduce Motion is on" : isMotionPaused ? "Motion paused" : "Drag the heart to turn it")
                .font(.subheadline)
                .foregroundStyle(PulsePalette.secondary)
            Text("Motion follows the rate, not individual beats.")
                .font(.footnote)
                .foregroundStyle(PulsePalette.secondary)
                .padding(.top, 8)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}
