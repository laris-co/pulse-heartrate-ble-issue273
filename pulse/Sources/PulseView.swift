import Charts
import SwiftUI

struct PulseView: View {
    @ObservedObject var store: PulseStore

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var pulseDisplaySize: CGFloat = 88

    @State private var isMotionPaused = false
    @State private var isShowingDevices = false
    @State private var isShowingDetails = false
    @State private var isShowingHeart = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    Group {
                        if usesWideLayout(in: geometry.size) {
                            wideLayout(height: geometry.size.height)
                        } else {
                            compactLayout(height: geometry.size.height)
                        }
                    }
                    .frame(maxWidth: usesWideLayout(in: geometry.size) ? 1_160 : 720)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, horizontalPadding(for: geometry.size.width))
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)
            }
            .background(PulsePalette.background.ignoresSafeArea())
            .foregroundStyle(PulsePalette.foreground)
            .navigationTitle("Pulse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(PulsePalette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingDevices = true
                    } label: {
                        Image(systemName: "applewatch")
                            .font(.title3.weight(.semibold))
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(store.sourceName == nil ? "Choose watch" : "Manage watch")
                    .accessibilityIdentifier("watchControlButton")
                }
            }
            .tint(PulsePalette.action)
            .sheet(isPresented: $isShowingDevices) {
                PulseDevicesSheet(store: store)
            }
            .sheet(isPresented: $isShowingDetails) {
                PulseDetailsSheet(store: store)
            }
            .fullScreenCover(isPresented: $isShowingHeart) {
                PulseHeartStage(store: store, isMotionPaused: $isMotionPaused)
            }
        }
    }

    private func compactLayout(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            sculptureSection
                .frame(height: compactArtHeight(for: height))

            pulseReading()

            if store.isPrivacySafe {
                privacySummary
                    .padding(.top, dynamicTypeSize.isAccessibilitySize ? 28 : 20)
            } else {
                historySection
                    .padding(.top, dynamicTypeSize.isAccessibilitySize ? 34 : 20)
            }

            chooseWatchButton
                .padding(.top, dynamicTypeSize.isAccessibilitySize ? 28 : 16)
        }
    }

    private func wideLayout(height: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 54) {
            sculptureSection
                .frame(maxWidth: .infinity)
                .frame(height: max(420, min(590, height - 110)))

            VStack(spacing: 0) {
                pulseReading(scale: 1.15)

                if store.isPrivacySafe {
                    privacySummary
                        .padding(.top, 34)
                } else {
                    historySection
                        .padding(.top, 42)
                }

                chooseWatchButton
                    .padding(.top, 32)
            }
            .frame(maxWidth: 520)
            .padding(.top, 26)
        }
        .frame(minHeight: max(580, height - 48), alignment: .center)
    }

    private var sculptureSection: some View {
        ZStack(alignment: .bottomTrailing) {
            PulseSculpture(
                beatsPerMinute: store.isPrivacySafe ? nil : store.snapshot.liveBPM,
                isActive: isSculptureActive && !isShowingHeart
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button {
                isMotionPaused.toggle()
            } label: {
                Image(systemName: isMotionPaused ? "play.fill" : "pause.fill")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(PulsePalette.controlSurface, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!motionIsAvailable || reduceMotion)
            .opacity(motionIsAvailable ? 1 : 0.55)
            .accessibilityLabel(isMotionPaused ? "Resume heart animation" : "Pause heart animation")
            .accessibilityHint("Controls the heart only, not the watch connection")
            .accessibilityIdentifier("pulseMotionButton")
            .padding(.trailing, 4)
            .padding(.bottom, 8)
        }
        .overlay(alignment: .bottomLeading) {
            if !store.isPrivacySafe {
                Button { isShowingHeart = true } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(PulsePalette.controlSurface, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Expand 3D heart")
                .accessibilityIdentifier("heartExpandButton")
                .padding(.leading, 4)
                .padding(.bottom, 8)
            }
        }
    }

    private func pulseReading(scale: CGFloat = 1) -> some View {
        VStack(spacing: 9) {
            HStack(alignment: .lastTextBaseline, spacing: 9) {
                Text(pulseText)
                    .font(.system(size: pulseDisplaySize * scale, weight: .bold, design: .default))
                    .monospacedDigit()
                    .minimumScaleFactor(0.64)
                    .lineLimit(1)
                    .accessibilityIdentifier("pulseValue")

                Text("BPM")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(PulsePalette.foreground.opacity(0.88))
                    .padding(.bottom, 12)
                    .accessibilityHidden(true)
            }
            .fixedSize(horizontal: false, vertical: true)

            if !store.isDemo || store.snapshot.state != .live {
                HStack(spacing: 7) {
                    Text(store.signalStatus)
                        .font(.headline)
                        .foregroundStyle(PulsePalette.foreground)
                        .accessibilityIdentifier("pulseSignalStatus")

                    if !store.isDemo && !store.isPrivacySafe {
                        Text("·")
                            .foregroundStyle(PulsePalette.secondary)
                            .accessibilityHidden(true)
                        Text(store.measurementAgeText)
                            .font(.subheadline)
                            .foregroundStyle(PulsePalette.secondary)
                    }
                }
            }

            if store.isDemo {
                Text("Demo · Sample data")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulsePalette.secondary)
                    .accessibilityValue("Demo · Sample data")
                    .accessibilityIdentifier("pulseDemoLabel")
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private var historySection: some View {
        VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 18 : 10) {
            HStack(alignment: .center) {
                Text("Last 60 seconds")
                    .font(.title2.weight(.bold))

                Spacer()

                Button {
                    isShowingDetails = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Pulse details")
                .accessibilityIdentifier("pulseDetailsButton")
            }

            PulseHistoryChart(samples: store.snapshot.samples)
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 250 : 138)

            rangeSummary
        }
    }

    @ViewBuilder
    private var rangeSummary: some View {
        if let minimum = store.snapshot.minimumBPM,
           let maximum = store.snapshot.maximumBPM {
            HStack(spacing: 24) {
                rangeValue(minimum, label: "low")
                Divider()
                    .overlay(PulsePalette.separator)
                    .frame(height: dynamicTypeSize.isAccessibilitySize ? 54 : 40)
                rangeValue(maximum, label: "high")
            }
            .accessibilityElement(children: .combine)
        } else {
            Text("Low and high appear after the first reading.")
                .font(.subheadline)
                .foregroundStyle(PulsePalette.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func rangeValue(_ value: Int, label: String) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text(String(value))
                .font((dynamicTypeSize.isAccessibilitySize ? Font.largeTitle : Font.title2).weight(.bold))
                .monospacedDigit()
            Text(label)
                .font(.headline)
                .foregroundStyle(PulsePalette.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var privacySummary: some View {
        VStack(spacing: 10) {
            Text("Measurements received")
                .font(.headline)
            Text(String(store.measurementCount))
                .font(.largeTitle.weight(.bold))
                .monospacedDigit()
                .accessibilityIdentifier("measurementCount")
            #if DEBUG
            if let diagnostic = store.connectIQ?.transportDiagnostics, !diagnostic.isEmpty {
                Text(diagnostic)
                    .font(.caption2)
                    .lineLimit(8)
                    .accessibilityIdentifier("ciqTransportDiagnostics")
            }
            #endif
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var chooseWatchButton: some View {
        Button {
            isShowingDevices = true
        } label: {
            HStack {
                Spacer(minLength: 24)
                Text("Choose watch")
                    .font(.headline)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.headline.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .tint(PulsePalette.action)
        .foregroundStyle(PulsePalette.background)
        .accessibilityIdentifier("connectWatchButton")
    }

    private var pulseText: String {
        guard !store.isPrivacySafe, let bpm = store.snapshot.liveBPM else {
            return "—"
        }
        return String(bpm)
    }

    private var motionIsAvailable: Bool {
        !store.isPrivacySafe && store.snapshot.state == .live
    }

    private var isSculptureActive: Bool {
        motionIsAvailable && !isMotionPaused
    }

    private func usesWideLayout(in size: CGSize) -> Bool {
        size.width >= 760 && size.width > size.height * 1.04
    }

    private func horizontalPadding(for width: CGFloat) -> CGFloat {
        width >= 760 ? 34 : 22
    }

    private func compactArtHeight(for availableHeight: CGFloat) -> CGFloat {
        guard !dynamicTypeSize.isAccessibilitySize else { return 250 }

        // The rest of the standard-size composition occupies about 505 points,
        // including content margins. Spend only the remaining first viewport on
        // art so the primary watch action stays visible on compact phones.
        return max(200, min(270, availableHeight - 505))
    }
}

private struct PulseHistoryChart: View {
    let samples: [PulseSample]
    private let chartEnd: Date

    init(samples: [PulseSample]) {
        self.samples = samples
        self.chartEnd = Date()
    }

    private var sortedSamples: [PulseSample] {
        samples.sorted { $0.timestamp < $1.timestamp }
    }

    private var chartStart: Date {
        chartEnd.addingTimeInterval(-PulseSignal.historyWindow)
    }

    private var yDomain: ClosedRange<Double> {
        let values = sortedSamples.map { Double($0.bpm) }
        guard let minimum = values.min(), let maximum = values.max() else {
            return 50...110
        }
        let padding = max(4, (maximum - minimum) * 0.22)
        return max(1, minimum - padding)...(maximum + padding)
    }

    private var segments: [SampleSegment] {
        var result: [SampleSegment] = []
        var current: [PulseSample] = []

        for sample in sortedSamples {
            if let previous = current.last,
               (sample.segmentID != previous.segmentID ||
                sample.timestamp.timeIntervalSince(previous.timestamp) > 5) {
                result.append(SampleSegment(index: result.count, samples: current))
                current = []
            }
            current.append(sample)
        }
        if !current.isEmpty {
            result.append(SampleSegment(index: result.count, samples: current))
        }
        return result
    }

    var body: some View {
        Group {
            if sortedSamples.isEmpty {
                emptyState
            } else {
                VStack(spacing: 2) {
                    Chart {
                        ForEach(segments) { segment in
                            ForEach(segment.samples, id: \.timestamp) { sample in
                                LineMark(
                                    x: .value("Time", sample.timestamp),
                                    y: .value("Pulse", sample.bpm),
                                    series: .value("Continuous segment", segment.index)
                                )
                                .foregroundStyle(PulsePalette.chartLine)
                                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                                .interpolationMethod(.monotone)
                            }

                            if segment.samples.count == 1,
                               let sample = segment.samples.first {
                                PointMark(
                                    x: .value("Time", sample.timestamp),
                                    y: .value("Pulse", sample.bpm)
                                )
                                .foregroundStyle(PulsePalette.chartLine)
                                .symbolSize(34)
                            }
                        }
                    }
                    .chartXScale(domain: chartStart...chartEnd)
                    .chartYScale(domain: yDomain)
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.7, dash: [3, 5]))
                                .foregroundStyle(PulsePalette.separator.opacity(0.7))
                            AxisValueLabel()
                                .foregroundStyle(PulsePalette.secondary)
                        }
                    }

                    HStack {
                        Text("60s ago")
                        Spacer()
                        Text("Now")
                    }
                    .font(.caption)
                    .foregroundStyle(PulsePalette.secondary)
                    .padding(.leading, 39)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pulse chart")
        .accessibilityValue(chartAccessibilityValue)
        .accessibilityIdentifier("pulseChart")
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform.path")
                .font(.title2)
                .foregroundStyle(PulsePalette.secondary)
                .accessibilityHidden(true)
            Text("No pulse history yet")
                .font(.headline)
            Text("Choose a watch to begin the last 60 seconds view.")
                .font(.subheadline)
                .foregroundStyle(PulsePalette.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PulsePalette.separator)
                .frame(height: 1)
                .accessibilityHidden(true)
        }
    }

    private var chartAccessibilityValue: String {
        guard let minimum = sortedSamples.map(\.bpm).min(),
              let maximum = sortedSamples.map(\.bpm).max() else {
            return "No pulse history yet"
        }
        return "Last 60 seconds. Low \(minimum) BPM, high \(maximum) BPM."
    }
}

private struct SampleSegment: Identifiable {
    let index: Int
    let samples: [PulseSample]

    var id: Int { index }
}
