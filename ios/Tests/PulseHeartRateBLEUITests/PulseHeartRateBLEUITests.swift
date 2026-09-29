import XCTest

final class PulseHeartRateBLEUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--privacy-safe-hardware-test")
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    func testScanCompletesWithoutAutomaticConnection() throws {
        let scanButton = app.buttons["scanToggleButton"]
        XCTAssertTrue(scanButton.waitForExistence(timeout: 5), "Scan control did not appear.")
        scrollToMakeHittable(scanButton)

        scanButton.tap()
        allowOwnBluetoothPromptIfPresent()

        // A first-ever Bluetooth prompt can complete after the initial tap. If scanning did not
        // start, retry once after CoreBluetooth has delivered its updated authorization/state.
        let scanning = NSPredicate(format: "label == %@", "Stop scan")
        if !expectation(for: scanning, evaluatedWith: scanButton).wait(timeout: 3) {
            scanButton.tap()
            allowOwnBluetoothPromptIfPresent()
        }
        XCTAssertTrue(expectation(for: scanning, evaluatedWith: scanButton).wait(timeout: 5))

        let scanFinished = NSPredicate(format: "label == %@", "Scan for sensors")
        XCTAssertTrue(
            expectation(for: scanFinished, evaluatedWith: scanButton).wait(timeout: 20),
            "The bounded scan did not stop within 20 seconds."
        )

        let sensorRows = app.buttons.matching(identifier: "sensorRow")
        let sensorCount = sensorRows.count
        let containsForerunner = (0..<sensorCount).contains { index in
            sensorRows.element(boundBy: index).label.localizedCaseInsensitiveContains("Forerunner")
        }
        let status = app.staticTexts["bluetoothStatus"].label

        let diagnostic = XCTAttachment(
            string: "scanStatus=\(status)\nsensorCount=\(sensorCount)\ncontainsForerunner=\(containsForerunner)"
        )
        diagnostic.name = "Privacy-safe BLE scan diagnostic"
        diagnostic.lifetime = .keepAlways
        add(diagnostic)

        XCTAssertEqual(status, "Idle", "The smoke test must not automatically connect to a sensor.")
        XCTAssertEqual(app.staticTexts["measurementCount"].label, "0")
        XCTAssertFalse(app.staticTexts["measurementReceived"].exists)
    }

    func testNotificationSchedulesGenericLocalNotification() throws {
        try verifyNotificationDelivery(backgroundApp: false)
    }

    func testReceiveTenGarminMeasurementsThenDisconnectAndRescan() throws {
        #if PULSE_ALLOW_REAL_GARMIN_CONNECTION
        let allowRealConnection = true
        #else
        let allowRealConnection = false
        #endif
        try XCTSkipUnless(allowRealConnection,
                          "Real sensor connection requires an explicitly authorized hardware-test build.")
        let scan = app.buttons["scanToggleButton"]
        XCTAssertTrue(scan.waitForExistence(timeout: 5))
        scrollToMakeHittable(scan)
        scan.tap()
        allowOwnBluetoothPromptIfPresent()
        let scanning = NSPredicate(format: "label == %@", "Stop scan")
        if !expectation(for: scanning, evaluatedWith: scan).wait(timeout: 3) {
            scan.tap()
            allowOwnBluetoothPromptIfPresent()
        }
        XCTAssertTrue(expectation(for: scanning, evaluatedWith: scan).wait(timeout: 5))

        let garmins = app.buttons.matching(identifier: "sensorRow").matching(
            NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", "Forerunner", "FR245")
        )
        XCTAssertTrue(garmins.firstMatch.waitForExistence(timeout: 18), "No Garmin advertising the standard Heart Rate Service was found.")
        XCTAssertEqual(garmins.count, 1, "Refusing to choose between multiple Garmin sensors.")
        let sensor = garmins.firstMatch
        scrollToMakeHittable(sensor)
        sensor.tap()

        let status = app.staticTexts["bluetoothStatus"]
        XCTAssertTrue(expectation(
            for: NSPredicate(format: "label BEGINSWITH %@", "Subscribed to"), evaluatedWith: status
        ).wait(timeout: 20), "The watch did not confirm the 2A37 notification subscription.")

        let count = app.staticTexts["measurementCount"]
        scrollToMakeHittable(count)
        let tenUpdates = NSPredicate { element, _ in
            guard let text = element as? XCUIElement, text.exists,
                  let count = Int(text.label) else { return false }
            return count >= 10
        }
        XCTAssertTrue(expectation(for: tenUpdates, evaluatedWith: count).wait(timeout: 45),
                      "Fewer than ten valid live measurement callbacks arrived.")
        let diagnostic = XCTAttachment(string:
            "standardHeartRateService=true\nmeasurementCharacteristicSubscribed=true\nvalidMeasurementUpdates=\(count.label)\nhealthValuesExported=false"
        )
        diagnostic.name = "Privacy-safe real Garmin measurement evidence"
        diagnostic.lifetime = .keepAlways
        add(diagnostic)

        let disconnect = app.buttons["disconnectButton"]
        scrollToMakeHittable(disconnect, swipeUp: false)
        disconnect.tap()
        XCTAssertTrue(expectation(for: NSPredicate(format: "label == %@", "0"), evaluatedWith: count).wait(timeout: 5))
        XCTAssertFalse(app.staticTexts["Measurement received"].exists)
        scan.tap()
        XCTAssertTrue(expectation(for: scanning, evaluatedWith: scan).wait(timeout: 5))
        scan.tap()
        XCTAssertEqual(status.label, "Idle")
        XCTAssertEqual(count.label, "0")
    }

    func testBackgroundNotificationDeliveredOnDevice() throws {
        try verifyNotificationDelivery(backgroundApp: true)
    }

    func testReadGarminForwardingSettingsWithoutChangingThem() throws {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        defer { app.activate() }

        // Navigate only known back controls; do not dismiss arbitrary dialogs.
        for _ in 0..<6 where !settings.navigationBars["Settings"].exists {
            let knownBack = ["Pulse HR Diagnostic", "Settings", "Bluetooth", "Notifications", "Apps"]
                .map { settings.navigationBars.buttons[$0] }
                .first { $0.exists }
            guard let knownBack else { break }
            knownBack.tap()
        }
        guard settings.navigationBars["Settings"].waitForExistence(timeout: 3) else {
            throw XCTSkip("Could not safely return to the Settings root; no settings changed.")
        }
        let bluetooth = settings.staticTexts["Bluetooth"]
        for _ in 0..<3 where !bluetooth.isHittable { settings.swipeDown() }
        guard bluetooth.waitForExistence(timeout: 3) else {
            throw XCTSkip("Could not safely locate Bluetooth settings; no settings changed.")
        }
        bluetooth.tap()

        let watchRows = settings.cells.containing(
            NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", "Forerunner", "Garmin")
        )
        guard watchRows.firstMatch.waitForExistence(timeout: 5) else {
            throw XCTSkip("No Garmin row found; no Bluetooth device was changed.")
        }
        let isConnected: (XCUIElement) -> Bool = { row in
            row.staticTexts.matching(NSPredicate(format: "label == %@", "Connected")).count > 0 ||
                (row.value as? String) == "Connected" || row.label.hasSuffix(", Connected")
        }
        let candidates = watchRows.allElementsBoundByIndex
        let connectedRows = candidates.filter(isConnected)
        let candidateDiagnostic = XCTAttachment(string:
            "garminMatchingRows=\(candidates.count)\nconnectedMatchingRows=\(connectedRows.count)\nsettingsChanged=false"
        )
        candidateDiagnostic.name = "Privacy-safe Garmin candidate count"
        candidateDiagnostic.lifetime = .keepAlways
        add(candidateDiagnostic)
        guard connectedRows.count == 1 || candidates.count == 1 else {
            throw XCTSkip("No unambiguous Garmin row found; no Bluetooth device was changed.")
        }
        let row = connectedRows.first ?? candidates[0]
        let connected = isConnected(row)
        let info = row.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "more info")
        ).firstMatch
        guard info.exists else {
            throw XCTSkip("Could not identify Garmin's information button; did not tap its connection row.")
        }
        info.tap()
        let sharing = settings.switches["Share System Notifications"]
        let present = sharing.waitForExistence(timeout: 3)
        let diagnostic = XCTAttachment(string:
            "garminConnectedLabel=\(connected)\nshareSystemNotificationsControlPresent=\(present)\n" +
            "shareSystemNotificationsValue=\(present ? String(describing: sharing.value ?? "unknown") : "unknown")\nsettingsChanged=false"
        )
        diagnostic.name = "Privacy-safe Garmin forwarding settings"
        diagnostic.lifetime = .keepAlways
        add(diagnostic)
    }

    func testReadOwnNotificationSettings() throws {
        let check = app.buttons["checkNotificationSettingsButton"]
        XCTAssertTrue(check.waitForExistence(timeout: 5))
        scrollToMakeHittable(check)
        check.tap()
        let output = app.staticTexts["notificationSettingsOutput"]
        XCTAssertTrue(expectation(
            for: NSPredicate(format: "label CONTAINS %@", "Authorization:"), evaluatedWith: output
        ).wait(timeout: 5))
        let diagnostic = XCTAttachment(string: output.label)
        diagnostic.name = "Own-app notification settings"
        diagnostic.lifetime = .keepAlways
        add(diagnostic)
    }

    func testOpenOwnNotificationSettingsWithoutChangingThem() throws {
        let settings = try openOwnNotificationPreferences()
        defer { app.activate() }
        let previews = settings.staticTexts["Show Previews"]
        for _ in 0..<3 where !previews.isHittable { settings.swipeUp() }
        XCTAssertTrue(previews.exists, "Own notification settings did not expose Show Previews.")
    }

    private func openOwnNotificationPreferences() throws -> XCUIApplication {
        let open = app.buttons["openNotificationSettingsButton"]
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        scrollToMakeHittable(open)
        open.tap()
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 5))
        let notifications = settings.staticTexts["Notifications"]
        guard notifications.waitForExistence(timeout: 3) else {
            throw XCTSkip("Could not safely identify this app's notification settings.")
        }
        notifications.tap()
        return settings
    }

    private func verifyNotificationDelivery(backgroundApp: Bool) throws {
        let notificationButton = app.buttons["notificationTestButton"]
        XCTAssertTrue(notificationButton.waitForExistence(timeout: 5), "Notification control did not appear.")
        notificationButton.tap()
        allowOwnNotificationPromptIfPresent()

        if backgroundApp {
            XCUIDevice.shared.press(.home)
            Thread.sleep(forTimeInterval: 7)
            app.activate()
        }

        let status = app.staticTexts["notificationStatus"]
        let scheduled = NSPredicate(
            format: "label CONTAINS %@ OR label CONTAINS %@",
            "Generic notification scheduled", "Local notification delivered"
        )
        XCTAssertTrue(
            expectation(for: scheduled, evaluatedWith: status).wait(timeout: 10),
            "The generic local notification was not scheduled. Current status: \(status.label)"
        )

        let delivered = NSPredicate(format: "label CONTAINS %@", "Local notification delivered on this device")
        XCTAssertTrue(
            expectation(for: delivered, evaluatedWith: status).wait(timeout: 12),
            "The device did not report the diagnostic in its delivered notifications."
        )
        let diagnostic = XCTAttachment(
            string: "notificationDeliveredOnDevice=true\nwatchDeliveryVerified=false\nheartRateDataIncluded=false"
        )
        diagnostic.name = "Privacy-safe local notification diagnostic"
        diagnostic.lifetime = .keepAlways
        add(diagnostic)
    }

    private func allowOwnNotificationPromptIfPresent() {
        // On physical iOS 18 devices the permission alert belongs to SpringBoard,
        // and Xcode's interruption monitor may fail to construct an app query.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        guard alert.waitForExistence(timeout: 3) else { return }
        let ownAppText = alert.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Pulse HR Diagnostic")).firstMatch
        let notificationText = alert.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "would like to send you notifications")).firstMatch
        guard (alert.label.contains("Pulse HR Diagnostic") || ownAppText.exists),
              (alert.label.localizedCaseInsensitiveContains("would like to send you notifications") || notificationText.exists) else {
            XCTFail("Refusing to interact with an unrelated system permission alert.")
            return
        }
        let allow = alert.buttons["Allow"]
        XCTAssertTrue(allow.exists, "The app notification prompt has no Allow action.")
        allow.tap()
    }

    private func allowOwnBluetoothPromptIfPresent() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        guard alert.waitForExistence(timeout: 3) else { return }
        // Query stable text predicates rather than enumerating indexes while the
        // iPad permission sheet animates; its text count can change mid-snapshot.
        let ownAppText = alert.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Pulse HR Diagnostic")).firstMatch
        let bluetoothText = alert.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Bluetooth")).firstMatch
        guard (alert.label.contains("Pulse HR Diagnostic") || ownAppText.exists),
              (alert.label.contains("Bluetooth") || bluetoothText.exists) else {
            XCTFail("Refusing to interact with an unrelated system permission alert.")
            return
        }
        guard let allow = ["OK", "Allow"].map({ alert.buttons[$0] }).first(where: \.exists) else {
            XCTFail("The app Bluetooth prompt has no supported allow action.")
            return
        }
        allow.tap()
    }

    private func scrollToMakeHittable(_ element: XCUIElement, swipeUp: Bool = true) {
        for _ in 0..<4 where !element.isHittable {
            if swipeUp { app.swipeUp() } else { app.swipeDown() }
        }
        XCTAssertTrue(element.isHittable, "Expected control is present but not tappable.")
    }
}

private extension XCTestExpectation {
    @discardableResult
    func wait(timeout: TimeInterval) -> Bool {
        XCTWaiter.wait(for: [self], timeout: timeout) == .completed
    }
}
