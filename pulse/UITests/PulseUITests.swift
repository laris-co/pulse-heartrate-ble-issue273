import XCTest
import UIKit

final class PulseUITests: XCTestCase {
    private var app: XCUIApplication!
    private var preserveAppAfterTest = false

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
        if !preserveAppAfterTest { app?.terminate() }
        app = nil
    }

    func testEmptyStateStartsReadyToConnectWithoutDiagnosticControls() {
        launch(arguments: ["--privacy-safe-hardware-test"])

        XCTAssertTrue(
            app.buttons["connectWatchButton"].waitForExistence(timeout: 5),
            "The empty state must offer a way to connect a watch."
        )
        XCTAssertEqual(app.staticTexts["pulseValue"].label, "—")
        XCTAssertFalse(
            app.buttons["notificationTestButton"].exists,
            "The consumer Pulse app must not expose diagnostic notification controls."
        )
    }

    func testDemoShowsSyntheticPulseAndOpensDetails() {
        launch(arguments: ["--demo"])

        let demoLabel = app.staticTexts["pulseDemoLabel"]
        XCTAssertTrue(demoLabel.waitForExistence(timeout: 5))
        XCTAssertTrue(
            wait(for: NSPredicate(format: "value CONTAINS[c] %@", "Demo"), evaluatedWith: demoLabel, timeout: 5),
            "Demo mode must be visibly identified as synthetic."
        )

        let pulseValue = app.staticTexts["pulseValue"]
        XCTAssertTrue(
            wait(
                for: NSPredicate(format: "label != %@ AND label != ''", "—"),
                evaluatedWith: pulseValue,
                timeout: 5
            ),
            "Demo mode must provide an available synthetic pulse."
        )

        let detailsButton = app.buttons["pulseDetailsButton"]
        XCTAssertTrue(detailsButton.waitForExistence(timeout: 5))
        detailsButton.tap()
        XCTAssertTrue(app.navigationBars["About your pulse"].waitForExistence(timeout: 5), "Pulse details must open as an info sheet.")
    }

    func testStaleDemoShowsPausedSignalWithoutPulse() {
        launch(arguments: ["--demo-stale"])

        let signalStatus = app.staticTexts["pulseSignalStatus"]
        XCTAssertTrue(signalStatus.waitForExistence(timeout: 5))
        XCTAssertEqual(signalStatus.label, "Signal paused")
        XCTAssertEqual(app.staticTexts["pulseValue"].label, "—")
    }

    func testDemoHeartFullscreenShowsSyntheticPulseAndEvidence() {
        launch(arguments: ["--demo"])

        let expand = app.buttons["heartExpandButton"]
        XCTAssertTrue(expand.waitForExistence(timeout: 5))
        expand.tap()

        let demoLabel = app.staticTexts["heartDemoLabel"]
        XCTAssertTrue(demoLabel.waitForExistence(timeout: 5))
        XCTAssertEqual(demoLabel.label, "Demo · Sample data")
        XCTAssertEqual(app.staticTexts["heartSignalStatus"].label, "Sample signal")

        let pulseValue = app.staticTexts["heartPulseValue"]
        XCTAssertTrue(
            wait(
                for: NSPredicate(format: "label != %@ AND label != ''", "—"),
                evaluatedWith: pulseValue,
                timeout: 5
            ),
            "The fullscreen demo heart must expose its readable synthetic pulse."
        )

        let deviceName = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        capture.name = "Pulse fullscreen demo \(deviceName)"
        capture.lifetime = .keepAlways
        add(capture)
    }

    func testFullscreenHeartMotionStateIsSharedWithDashboardAfterDismissal() {
        launch(arguments: ["--demo"])

        let dashboardPulse = app.staticTexts["pulseValue"]
        XCTAssertTrue(dashboardPulse.waitForExistence(timeout: 5))

        let expand = app.buttons["heartExpandButton"]
        XCTAssertTrue(expand.waitForExistence(timeout: 5))
        expand.tap()

        let fullscreenMotion = app.buttons["heartMotionButton"]
        XCTAssertTrue(fullscreenMotion.waitForExistence(timeout: 5))
        XCTAssertEqual(fullscreenMotion.label, "Pause heart animation")
        fullscreenMotion.tap()
        XCTAssertTrue(
            wait(
                for: NSPredicate(format: "label == %@", "Resume heart animation"),
                evaluatedWith: fullscreenMotion,
                timeout: 5
            )
        )

        let close = app.buttons["heartCloseButton"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()

        XCTAssertTrue(dashboardPulse.waitForExistence(timeout: 5))
        XCTAssertTrue(
            wait(
                for: NSPredicate { candidate, _ in
                    guard let element = candidate as? XCUIElement,
                          let pulse = Int(element.label) else {
                        return false
                    }
                    return pulse > 0
                },
                evaluatedWith: dashboardPulse,
                timeout: 5
            ),
            "Dismissing the fullscreen heart must preserve a readable live demo pulse."
        )
        let dashboardDemoLabel = app.staticTexts["pulseDemoLabel"]
        XCTAssertTrue(dashboardDemoLabel.waitForExistence(timeout: 5))
        XCTAssertTrue(
            wait(
                for: NSPredicate(format: "value CONTAINS[c] %@", "Demo"),
                evaluatedWith: dashboardDemoLabel,
                timeout: 5
            ),
            "Dismissing the fullscreen heart must keep the synthetic-data disclosure visible."
        )
        let dashboardMotion = app.buttons["pulseMotionButton"]
        XCTAssertTrue(dashboardMotion.waitForExistence(timeout: 5))
        XCTAssertEqual(dashboardMotion.label, "Resume heart animation")
        dashboardMotion.tap()
        XCTAssertTrue(
            wait(
                for: NSPredicate(format: "label == %@", "Pause heart animation"),
                evaluatedWith: dashboardMotion,
                timeout: 5
            )
        )
    }

    func testStaleDemoFullscreenShowsPausedSignalAndDisablesMotion() {
        launch(arguments: ["--demo-stale"])

        let expand = app.buttons["heartExpandButton"]
        XCTAssertTrue(expand.waitForExistence(timeout: 5))
        expand.tap()

        let pulseValue = app.staticTexts["heartPulseValue"]
        XCTAssertTrue(pulseValue.waitForExistence(timeout: 5))
        XCTAssertEqual(pulseValue.label, "—")

        let signalStatus = app.staticTexts["heartSignalStatus"]
        XCTAssertTrue(signalStatus.waitForExistence(timeout: 5))
        XCTAssertEqual(signalStatus.label, "Signal paused")

        let motion = app.buttons["heartMotionButton"]
        XCTAssertTrue(motion.waitForExistence(timeout: 5))
        XCTAssertFalse(motion.isEnabled, "A stale signal must not offer heart animation controls.")
    }

    func testPrivacySafeModeHidesHeartExpansion() {
        launch(arguments: ["--privacy-safe-hardware-test"])

        XCTAssertTrue(app.buttons["connectWatchButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(
            app.buttons["heartExpandButton"].exists,
            "Privacy-safe mode must not expose an informative fullscreen heart."
        )
    }

    func testDemoHeartAnimationChangesWhileRunningAndFreezesWhenPaused() throws {
        launch(arguments: ["--demo"])
        openFullscreenHeart()

        let runningFirst = try captureHeartCrop(named: "Demo heart running first frame")
        Thread.sleep(forTimeInterval: 0.45) // Sample a later animation phase, not UI readiness.
        let runningSecond = try captureHeartCrop(named: "Demo heart running second frame")
        let runningDifference = meanPixelDifference(runningFirst, runningSecond)
        XCTAssertGreaterThan(
            runningDifference,
            0.0008,
            "The demo heart must visibly change while animation is running (difference: \(runningDifference))."
        )

        let motion = app.buttons["heartMotionButton"]
        XCTAssertTrue(motion.waitForExistence(timeout: 5))
        motion.tap()
        XCTAssertTrue(wait(
            for: NSPredicate(format: "label == %@", "Resume heart animation"),
            evaluatedWith: motion,
            timeout: 5
        ))

        // Discard the transition frame captured while the pause state propagates.
        Thread.sleep(forTimeInterval: 0.2)
        let pausedFirst = try captureHeartCrop(named: "Demo heart paused first frame")
        Thread.sleep(forTimeInterval: 0.45)
        let pausedSecond = try captureHeartCrop(named: "Demo heart paused second frame")
        let pausedDifference = meanPixelDifference(pausedFirst, pausedSecond)
        XCTAssertLessThan(
            pausedDifference,
            0.00025,
            "The paused demo heart must remain visually frozen (difference: \(pausedDifference))."
        )
    }

    func testPausedDemoHeartChangesOrientationAfterDrag() throws {
        launch(arguments: ["--demo"])
        openFullscreenHeart()

        let motion = app.buttons["heartMotionButton"]
        XCTAssertTrue(motion.waitForExistence(timeout: 5))
        motion.tap()
        XCTAssertTrue(wait(
            for: NSPredicate(format: "label == %@", "Resume heart animation"),
            evaluatedWith: motion,
            timeout: 5
        ))
        Thread.sleep(forTimeInterval: 0.2)

        let beforeDrag = try captureHeartCrop(named: "Paused demo heart before drag")
        let dragStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: 0.32))
        let dragEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.68, dy: 0.32))
        dragStart.press(forDuration: 0.1, thenDragTo: dragEnd)
        let afterDrag = try captureHeartCrop(named: "Paused demo heart after drag")

        let draggedDifference = meanPixelDifference(beforeDrag, afterDrag)
        XCTAssertGreaterThan(
            draggedDifference,
            0.0008,
            "Dragging must visibly rotate the paused 3D heart (difference: \(draggedDifference))."
        )
        XCTAssertEqual(motion.label, "Resume heart animation", "Dragging must not resume the paused animation.")
    }

    func testFullscreenHeartRemainsAccessibleAtLargestDynamicTypeSize() {
        launch(arguments: [
            "--demo",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
        ])
        openFullscreenHeart()

        XCTAssertTrue(app.buttons["heartCloseButton"].isHittable)
        XCTAssertTrue(app.buttons["heartMotionButton"].isHittable)
        let pulseValue = app.staticTexts["heartPulseValue"]
        XCTAssertTrue(pulseValue.waitForExistence(timeout: 5))
        XCTAssertTrue(Int(pulseValue.label).map { $0 > 0 } == true)
        XCTAssertTrue(app.staticTexts["heartDemoLabel"].exists)
        XCTAssertTrue(app.staticTexts["heartSignalStatus"].exists)
    }

    func testStandardLayoutKeepsActionVisibleAndSupportsLandscape() throws {
        launch(arguments: ["--demo"])
        let connect = app.buttons["connectWatchButton"]
        XCTAssertTrue(connect.waitForExistence(timeout: 5))
        XCTAssertTrue(connect.isHittable, "The main action must be visible at the standard text size.")
        XCTAssertLessThanOrEqual(connect.frame.maxY, app.frame.maxY)

        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(wait(
            for: NSPredicate { _, _ in self.app.frame.width > self.app.frame.height },
            evaluatedWith: app as Any,
            timeout: 5
        ))
        XCTAssertTrue(connect.isHittable)
        // Wait for UIKit’s rotation transition before capturing the whole display.
        Thread.sleep(forTimeInterval: 2)
        let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        capture.name = "Pulse tablet landscape demo"
        capture.lifetime = .keepAlways
        add(capture)
    }

    func testConnectionOptionsKeepBothRoutesExplicit() {
        launch(arguments: ["--privacy-safe-hardware-test"])
        let connect = app.buttons["connectWatchButton"]
        XCTAssertTrue(connect.waitForExistence(timeout: 5))
        connect.tap()
        XCTAssertTrue(app.buttons["ciqAuthorizeButton"].waitForExistence(timeout: 5))
        let scan = app.buttons["scanToggleButton"]
        for _ in 0..<3 where !scan.exists {
            app.swipeUp()
        }
        XCTAssertTrue(scan.exists, "The original BLE route must remain available.")
        XCTAssertEqual(scan.label, "Scan for sensors", "Opening source options must not auto-scan.")
    }

    func testReceiveTenRealMeasurements() throws {
        #if !PULSE_ALLOW_REAL_GARMIN_CONNECTION
        throw XCTSkip("Real Garmin connection requires the PULSE_ALLOW_REAL_GARMIN_CONNECTION compile flag.")
        #else
        launch(arguments: ["--privacy-safe-hardware-test"])

        let connect = app.buttons["connectWatchButton"]
        XCTAssertTrue(connect.waitForExistence(timeout: 5))
        connect.tap()

        let scan = app.buttons["scanToggleButton"]
        XCTAssertTrue(scan.waitForExistence(timeout: 5), "The device sheet must provide its scan control.")
        XCTAssertTrue(["Scan for sensors", "Stop scan"].contains(scan.label))
        if scan.label == "Scan for sensors" {
            scan.tap()
            allowOwnBluetoothPromptIfPresent()
        }

        let scanning = NSPredicate(format: "label == %@", "Stop scan")
        if !wait(for: scanning, evaluatedWith: scan, timeout: 3) {
            scan.tap()
            allowOwnBluetoothPromptIfPresent()
        }
        XCTAssertTrue(wait(for: scanning, evaluatedWith: scan, timeout: 5), "Scanning did not begin.")

        let matchingSensors = app.buttons
            .matching(identifier: "sensorRow")
            .matching(NSPredicate(
                format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@",
                "Forerunner",
                "FR245"
            ))
        XCTAssertTrue(
            matchingSensors.firstMatch.waitForExistence(timeout: 18),
            "No supported Garmin heart-rate sensor was found."
        )
        XCTAssertEqual(matchingSensors.count, 1, "Refusing to choose between multiple matching sensors.")
        matchingSensors.firstMatch.tap()

        let signalStatus = app.staticTexts["pulseSignalStatus"]
        XCTAssertTrue(
            wait(for: NSPredicate(format: "label == %@", "Live"), evaluatedWith: signalStatus, timeout: 20),
            "The selected sensor did not reach the live state."
        )

        let measurementCount = app.staticTexts["measurementCount"]
        let receivedTen = NSPredicate { candidate, _ in
            guard let element = candidate as? XCUIElement,
                  element.exists,
                  let count = Int(element.label) else {
                return false
            }
            return count >= 10
        }
        XCTAssertTrue(
            wait(for: receivedTen, evaluatedWith: measurementCount, timeout: 45),
            "Fewer than ten live measurement callbacks arrived."
        )

        let pulseValueRedacted = app.staticTexts["pulseValue"].label == "—"
        let detailsHidden = !app.buttons["pulseDetailsButton"].exists
        let chartHidden = !app.descendants(matching: .any)["pulseChart"].exists
        XCTAssertTrue(pulseValueRedacted, "Privacy-safe hardware tests must not expose a BPM value.")
        XCTAssertTrue(detailsHidden, "Privacy-safe hardware tests must not expose pulse details.")
        XCTAssertTrue(chartHidden, "Privacy-safe hardware tests must not expose pulse chart values.")

        let evidence = XCTAttachment(string: [
            "measurementCount=\(measurementCount.label)",
            "liveStatusReached=true",
            "pulseValueRedacted=\(pulseValueRedacted)",
            "detailsHidden=\(detailsHidden)",
            "chartHidden=\(chartHidden)",
        ].joined(separator: "\n"))
        evidence.name = "Privacy-safe real sensor evidence"
        evidence.lifetime = .keepAlways
        add(evidence)

        XCTAssertTrue(connect.waitForExistence(timeout: 5), "The device sheet did not dismiss after selection.")
        connect.tap()
        let disconnect = app.buttons["disconnectButton"]
        XCTAssertTrue(disconnect.waitForExistence(timeout: 5))
        disconnect.tap()
        XCTAssertTrue(
            wait(for: NSPredicate(format: "label == %@", "0"), evaluatedWith: measurementCount, timeout: 5),
            "Disconnecting must clear the measurement count."
        )
        #endif
    }

    func testReceiveTenConnectIQMeasurementsWithoutVirtualRun() throws {
        #if !PULSE_ALLOW_CONNECTIQ_CONNECTION
        throw XCTSkip("Physical Connect IQ proof requires PULSE_ALLOW_CONNECTIQ_CONNECTION.")
        #else
        launch(arguments: ["--privacy-safe-hardware-test"])
        let connect = app.buttons["connectWatchButton"]
        XCTAssertTrue(connect.waitForExistence(timeout: 5))
        connect.tap()
        let authorize = app.buttons["ciqAuthorizeButton"]
        XCTAssertTrue(authorize.waitForExistence(timeout: 5))
        let cancelAuthorization = app.buttons["Cancel authorization"]
        if cancelAuthorization.exists { cancelAuthorization.tap() }
        authorize.tap()
        allowGarminConnectHandoffIfPresent()

        // The operator completes Garmin Connect's one-time authorization.
        // Never select an arbitrary paired device or change Garmin pairing.
        let returned = NSPredicate { _, _ in
            self.app.state == .runningForeground &&
                self.app.buttons["ciqDeviceRow"].firstMatch.exists
        }
        XCTAssertTrue(wait(for: returned, evaluatedWith: app as Any, timeout: 180),
                      "Garmin Connect did not return an authorized watch to Pulse.")
        let watches = app.buttons.matching(identifier: "ciqDeviceRow")
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Forerunner 245"))
        let openWatch = app.buttons["ciqOpenWatchButton"]
        let expectedName = ProcessInfo.processInfo.environment["PULSE_CIQ_EXPECTED_WATCH_NAME"]
        XCTAssertGreaterThan(watches.count, 0, "No authorized Forerunner 245 was returned.")
        if let expectedName, !expectedName.isEmpty {
            let exact = watches.matching(NSPredicate(format: "label == %@", expectedName))
            XCTAssertEqual(exact.count, 1, "The explicitly identified watch must match exactly once.")
            exact.firstMatch.tap()
        } else if watches.count == 1 {
            watches.firstMatch.tap()
        } else {
            // The user must choose when Garmin returns multiple saved entries.
            // Emit names only: never device identifiers or health values.
            print("CIQ_SELECTION_CANDIDATES: \(watches.allElementsBoundByIndex.map(\.label))")
            XCTAssertTrue(openWatch.waitForExistence(timeout: 180),
                          "Choose the currently paired watch in Pulse; automatic guessing is disabled.")
        }

        let isReady = openWatch.waitForExistence(timeout: 45)
        if !isReady, app.staticTexts["ciqStatus"].exists {
            print("CIQ_CONNECTION_STATUS: \(app.staticTexts["ciqStatus"].label)")
        }
        XCTAssertTrue(isReady,
                      "The selected watch did not expose the installed Pulse Link app.")
        if let expectedName, !expectedName.isEmpty {
            XCTAssertEqual(app.staticTexts["ciqConnectedWatch"].label, expectedName)
        }
        if ProcessInfo.processInfo.environment["PULSE_CIQ_SKIP_OPEN_REQUEST"] != "1" {
            openWatch.tap()
        }
        app.buttons["dismissDevicesButton"].tap()
        if ProcessInfo.processInfo.environment["PULSE_CIQ_LISTEN_ONLY_PROBE"] == "1" {
            let transport = app.staticTexts["ciqTransportDiagnostics"]
            XCTAssertTrue(transport.waitForExistence(timeout: 5))
            XCTAssertTrue(transport.label.contains("listen_only_ready"))
            print("CIQ_LISTEN_ONLY_READY: press START in the diagnostic Pulse Link watch build")
            let received = wait(
                for: NSPredicate(format: "label CONTAINS %@", "event=link_test_callback"),
                evaluatedWith: transport,
                timeout: 120
            )
            print("CIQ_LISTEN_ONLY_RESULT: \(transport.label)")
            XCTAssertTrue(received, "No watch-initiated link-test callback arrived.")
            XCTAssertEqual(app.staticTexts["measurementCount"].label, "0")
            // A fixed synthetic link packet can prove transport, not live HR.
            throw XCTSkip("Watch-initiated transport probe only; not a ten-response proof.")
        }
        Thread.sleep(forTimeInterval: 10)
        let transport = app.staticTexts["ciqTransportDiagnostics"]
        if transport.exists {
            print("CIQ_TRANSPORT_DIAGNOSTICS: \(transport.label)")
        }
        if ProcessInfo.processInfo.environment["PULSE_CIQ_SINGLE_QUEUED_PROBE"] == "1" {
            // Keep the receiver alive beyond the short request-expiry window.
            // A delayed callback remains rejected as stale, but still proves
            // return transport without changing the product freshness rules.
            preserveAppAfterTest = true
            print("CIQ_QUEUED_PROBE: receiver held open for another 80 seconds")
            Thread.sleep(forTimeInterval: 80)
            XCTAssertEqual(app.state, .runningForeground)
            if transport.exists {
                print("CIQ_TRANSPORT_DIAGNOSTICS_FINAL: \(transport.label)")
            }
            throw XCTSkip("One queued diagnostic request only; not a ten-response proof.")
        }
        let status = app.staticTexts["pulseSignalStatus"]
        XCTAssertTrue(wait(for: NSPredicate(format: "label == %@", "Live"),
                           evaluatedWith: status, timeout: 90),
                      "Pulse Link did not produce a fresh reading. Confirm opening it on the watch.")
        let count = app.staticTexts["measurementCount"]
        XCTAssertTrue(wait(for: NSPredicate { candidate, _ in
            guard let element = candidate as? XCUIElement, element.exists,
                  let value = Int(element.label) else { return false }
            return value >= 10
        }, evaluatedWith: count, timeout: 60), "Fewer than ten Connect IQ readings arrived.")
        XCTAssertEqual(status.label, "Live", "The latest reading must still be fresh at the count gate.")
        XCTAssertEqual(app.staticTexts["pulseValue"].label, "—")
        XCTAssertFalse(app.buttons["pulseDetailsButton"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["pulseChart"].exists)
        let evidence = XCTAttachment(string: "source=ConnectIQ\nacceptedReadings=\(count.label)\nhealthValuesRedacted=true\n")
        evidence.name = "Privacy-safe Connect IQ reception evidence"
        evidence.lifetime = .keepAlways
        add(evidence)

        connect.tap()
        let disconnect = app.buttons["ciqDisconnectButton"]
        XCTAssertTrue(disconnect.waitForExistence(timeout: 5))
        disconnect.tap()
        app.buttons["dismissDevicesButton"].tap()
        XCTAssertTrue(wait(for: NSPredicate(format: "label == %@", "0"),
                           evaluatedWith: count, timeout: 5))
        XCTAssertNotEqual(status.label, "Live")
        #endif
    }

    private func launch(arguments: [String]) {
        app = XCUIApplication()
        app.launchArguments = arguments
        if ProcessInfo.processInfo.environment["PULSE_CIQ_SINGLE_QUEUED_PROBE"] == "1" {
            app.launchArguments.append("--ciq-single-queued-probe")
        }
        if ProcessInfo.processInfo.environment["PULSE_CIQ_LISTEN_ONLY_PROBE"] == "1" {
            app.launchArguments.append("--ciq-listen-only-probe")
        }
        app.launch()
    }

    private func openFullscreenHeart() {
        let expand = app.buttons["heartExpandButton"]
        XCTAssertTrue(expand.waitForExistence(timeout: 5))
        expand.tap()
        XCTAssertTrue(app.buttons["heartCloseButton"].waitForExistence(timeout: 5))
    }

    private func captureHeartCrop(named name: String) throws -> Data {
        let screenshot = XCUIScreen.main.screenshot().image
        let source = try XCTUnwrap(
            screenshot.cgImage,
            "The simulator screenshot did not provide CGImage pixel data."
        )

        // The portrait fullscreen layout reserves its upper-middle region for the
        // heart. This crop excludes the navigation controls and the changing BPM.
        let sourceWidth = CGFloat(source.width)
        let sourceHeight = CGFloat(source.height)
        let cropRect = CGRect(
            x: sourceWidth * 0.18,
            y: sourceHeight * 0.10,
            width: sourceWidth * 0.64,
            height: sourceHeight * 0.45
        ).integral
        let cropped = try XCTUnwrap(
            source.cropping(to: cropRect),
            "The fullscreen heart crop was outside the simulator screenshot."
        )

        let image = UIImage(cgImage: cropped)
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let sampleWidth = 96
        let sampleHeight = 96
        let bytesPerRow = sampleWidth * 4
        var pixels = Data(count: bytesPerRow * sampleHeight)
        try pixels.withUnsafeMutableBytes { storage in
            let context = try XCTUnwrap(
                CGContext(
                    data: storage.baseAddress,
                    width: sampleWidth,
                    height: sampleHeight,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                        | CGBitmapInfo.byteOrder32Big.rawValue
                ),
                "The fullscreen heart crop could not be normalized for comparison."
            )
            context.interpolationQuality = .medium
            context.draw(cropped, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))
        }
        return pixels
    }

    private func meanPixelDifference(_ first: Data, _ second: Data) -> Double {
        guard first.count == second.count, !first.isEmpty else { return 1 }
        let totalDifference = zip(first, second).reduce(0) { partial, pair in
            partial + abs(Int(pair.0) - Int(pair.1))
        }
        return Double(totalDifference) / Double(first.count * 255)
    }

    /// Separate setup smoke: this deliberately makes no live-HR proof claim.
    /// It leaves the ordinary app open, without reading or attaching health UI.
    func testOpenPulseLinkForManualUse() throws {
        #if !PULSE_ALLOW_CONNECTIQ_CONNECTION
        throw XCTSkip("Manual-device setup requires PULSE_ALLOW_CONNECTIQ_CONNECTION.")
        #else
        guard let expectedName = ProcessInfo.processInfo.environment["PULSE_CIQ_EXPECTED_WATCH_NAME"],
              !expectedName.isEmpty else {
            throw XCTSkip("An explicitly identified watch name is required.")
        }
        preserveAppAfterTest = true
        if ProcessInfo.processInfo.environment["PULSE_MANUAL_ATTACH_EXISTING"] == "1" {
            app = XCUIApplication()
            XCTAssertEqual(app.state, .runningForeground,
                           "Launch the ordinary app before attaching the setup helper.")
        } else {
            launch(arguments: [])
        }
        let manageWatch = app.buttons["watchControlButton"]
        if manageWatch.waitForExistence(timeout: 5), manageWatch.isHittable {
            manageWatch.tap()
        } else {
            let connect = app.buttons["connectWatchButton"]
            XCTAssertTrue(connect.waitForExistence(timeout: 5))
            if !connect.isHittable { app.swipeUp() }
            connect.tap()
        }
        let existingConnection = app.buttons["ciqOpenWatchButton"]
        if existingConnection.waitForExistence(timeout: 3) {
            XCTAssertEqual(app.staticTexts["ciqConnectedWatch"].label, expectedName)
            app.buttons["dismissDevicesButton"].tap()
            XCTAssertEqual(app.state, .runningForeground)
            return
        }
        let cancel = app.buttons["Cancel authorization"]
        if cancel.exists { cancel.tap() }
        app.buttons["ciqAuthorizeButton"].tap()
        allowGarminConnectHandoffIfPresent()
        let exact = app.buttons.matching(identifier: "ciqDeviceRow")
            .matching(NSPredicate(format: "label == %@", expectedName))
        XCTAssertTrue(exact.firstMatch.waitForExistence(timeout: 45))
        XCTAssertEqual(exact.count, 1)
        exact.firstMatch.tap()
        let open = app.buttons["ciqOpenWatchButton"]
        XCTAssertTrue(open.waitForExistence(timeout: 45))
        XCTAssertEqual(app.staticTexts["ciqConnectedWatch"].label, expectedName)
        open.tap()
        app.buttons["dismissDevicesButton"].tap()
        XCTAssertEqual(app.state, .runningForeground)
        #endif
    }

    private func allowOwnBluetoothPromptIfPresent() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        guard alert.waitForExistence(timeout: 3) else { return }

        let exactAppName = alert.staticTexts["Pulse"].exists
        let quotedAppName = ["“Pulse”", "‘Pulse’", "\"Pulse\"", "'Pulse'"]
            .contains { alert.label.contains($0) }
        let mentionsBluetooth = alert.label.localizedCaseInsensitiveContains("Bluetooth") ||
            alert.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "Bluetooth")
            ).firstMatch.exists

        guard (exactAppName || quotedAppName), mentionsBluetooth else {
            XCTFail("Refusing to interact with a system alert that is not Pulse's Bluetooth permission prompt.")
            return
        }
        guard let allow = ["OK", "Allow"].map({ alert.buttons[$0] }).first(where: \.exists) else {
            XCTFail("Pulse's Bluetooth permission prompt has no supported allow action.")
            return
        }
        allow.tap()
    }

    private func allowGarminConnectHandoffIfPresent() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        guard alert.waitForExistence(timeout: 3) else { return }
        // Exact first-run handoff observed on this iPad. Never approve a
        // different destination or an unrelated system permission prompt.
        if alert.label == "“Pulse” wants to open “Connect”" {
            let open = alert.buttons["Open"]
            XCTAssertTrue(open.exists, "The recognized Garmin handoff has no Open button.")
            open.tap()
        } else {
            allowOwnBluetoothPromptIfPresent()
            if alert.waitForExistence(timeout: 3),
               alert.label == "“Pulse” wants to open “Connect”" {
                let open = alert.buttons["Open"]
                XCTAssertTrue(open.exists)
                open.tap()
            }
        }
    }

    private func wait(
        for predicate: NSPredicate,
        evaluatedWith object: Any,
        timeout: TimeInterval
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: object)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
