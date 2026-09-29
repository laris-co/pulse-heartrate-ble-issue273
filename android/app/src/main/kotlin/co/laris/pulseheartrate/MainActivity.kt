package co.laris.pulseheartrate

import android.Manifest
import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Log
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import java.util.UUID

class MainActivity : Activity() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val foundDevices = linkedMapOf<String, ScanResult>()
    private lateinit var statusText: TextView
    private lateinit var readingText: TextView
    private lateinit var deviceList: LinearLayout
    private lateinit var scanButton: Button
    private lateinit var diagnosticScanButton: Button
    private lateinit var disconnectButton: Button

    private var scanGeneration = 0
    private var activeScanCallback: ScanCallback? = null
    private var connectionGeneration = 0
    private var activeGatt: BluetoothGatt? = null
    private var pendingScanAfterPermission = false
    private var pendingDiagnosticScan = false
    private var pendingNotificationAfterPermission = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(buildUi())
        updateState("Disconnected", "Tap Scan for heart-rate devices.")
    }

    private fun buildUi(): View {
        val padding = (16 * resources.displayMetrics.density).toInt()
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(padding, padding, padding, padding)
        }
        content.addView(TextView(this).apply {
            text = "Pulse BLE Diagnostic"
            textSize = 24f
        })
        statusText = TextView(this).apply {
            textSize = 17f
            setPadding(0, padding, 0, padding / 2)
        }
        content.addView(statusText)
        readingText = TextView(this).apply {
            text = "No heart-rate measurement yet"
            textSize = 22f
            setPadding(0, 0, 0, padding)
        }
        content.addView(readingText)

        scanButton = Button(this).apply {
            text = "Scan for 0x180D devices"
            setOnClickListener { requestScan(diagnostic = false) }
        }
        content.addView(scanButton)
        diagnosticScanButton = Button(this).apply {
            text = "Scan all (diagnostic)"
            setOnClickListener { requestScan(diagnostic = true) }
        }
        content.addView(diagnosticScanButton)
        disconnectButton = Button(this).apply {
            text = "Disconnect"
            isEnabled = false
            setOnClickListener {
                closeConnection()
                updateState("Disconnected", "Connection closed.")
            }
        }
        content.addView(disconnectButton)
        deviceList = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        content.addView(deviceList)

        content.addView(Button(this).apply {
            text = "Send local test notification"
            setOnClickListener { requestTestNotification() }
        })
        content.addView(TextView(this).apply {
            val installed = isGarminConnectInstalled()
            text = buildString {
                append("Watch notification path: phone OS → Garmin Connect → paired watch. ")
                append("Garmin Connect must be installed, paired to the watch, and allowed notification access. ")
                append("This is not a write to the BLE Heart Rate Service.\n\n")
                append(if (installed) "Garmin Connect: installed." else "Garmin Connect: not installed.")
                append(" The broad diagnostic scan lists nearby advertisements, but connects only after you select your own watch. ")
                append("This foreground-only prototype does not record sessions or send data to the internet.")
            }
            setPadding(0, padding, 0, padding)
        })
        return ScrollView(this).apply { addView(content) }
    }

    private fun requestScan(diagnostic: Boolean) {
        if (!hasBlePermissions()) {
            pendingScanAfterPermission = true
            pendingDiagnosticScan = diagnostic
            requestPermissions(
                arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT),
                REQUEST_BLE_PERMISSIONS,
            )
            return
        }
        startScan(diagnostic)
    }

    private fun startScan(diagnostic: Boolean) {
        stopScan()
        closeConnection()
        foundDevices.clear()
        deviceList.removeAllViews()

        val adapter = getSystemService(BluetoothManager::class.java).adapter
        if (adapter == null) {
            updateState("Error", "Bluetooth LE is unavailable on this phone.")
            return
        }
        if (!adapter.isEnabled) {
            updateState("Error", "Bluetooth is off. Turn it on, then scan again.")
            return
        }
        val scanner = adapter.bluetoothLeScanner
        if (scanner == null) {
            updateState("Error", "BLE scanner is unavailable.")
            return
        }

        val generation = ++scanGeneration
        val callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                if (generation != scanGeneration || activeScanCallback !== this) return
                showScanResult(result)
            }

            override fun onBatchScanResults(results: MutableList<ScanResult>) {
                if (generation != scanGeneration || activeScanCallback !== this) return
                results.forEach(::showScanResult)
            }

            override fun onScanFailed(errorCode: Int) {
                if (generation != scanGeneration || activeScanCallback !== this) return
                stopScan()
                updateState("Error", "BLE scan failed (code $errorCode).")
            }
        }
        activeScanCallback = callback
        val settings = ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build()
        try {
            val filters = if (diagnostic) emptyList() else
                listOf(ScanFilter.Builder().setServiceUuid(ParcelUuid(HEART_RATE_SERVICE)).build())
            scanner.startScan(filters, settings, callback)
            scanButton.isEnabled = false
            diagnosticScanButton.isEnabled = false
            updateState(
                "Scanning",
                if (diagnostic) "Listing all nearby BLE advertisements…" else
                    "Looking for devices advertising Heart Rate Service 0x180D…",
            )
            Log.i(TAG, "BLE scan started")
            mainHandler.postDelayed({
                if (generation == scanGeneration && activeScanCallback === callback) {
                    stopScan()
                    val emptyMessage = if (diagnostic) "No BLE advertisements found." else "No 0x180D devices found."
                    updateState("Timeout", if (foundDevices.isEmpty()) emptyMessage else "Scan finished; select your own device.")
                }
            }, SCAN_TIMEOUT_MS)
        } catch (security: SecurityException) {
            activeScanCallback = null
            scanButton.isEnabled = true
            diagnosticScanButton.isEnabled = true
            updateState("Error", "Bluetooth scan permission was not granted.")
        }
    }

    private fun showScanResult(result: ScanResult) {
        val address = try {
            result.device.address
        } catch (_: SecurityException) {
            return
        }
        if (foundDevices.putIfAbsent(address, result) != null) return
        val name = try {
            result.device.name ?: result.scanRecord?.deviceName ?: "Unnamed BLE device"
        } catch (_: SecurityException) {
            "Unnamed BLE device"
        }
        val services = result.scanRecord?.serviceUuids
            ?.joinToString { shortUuid(it.uuid) }
            ?.ifBlank { "none advertised" }
            ?: "none advertised"
        deviceList.addView(Button(this).apply {
            text = "$name\n$address\nServices: $services"
            isAllCaps = false
            setOnClickListener { connect(result) }
        })
    }

    private fun stopScan() {
        val callback = activeScanCallback ?: return
        activeScanCallback = null
        ++scanGeneration
        scanButton.isEnabled = true
        diagnosticScanButton.isEnabled = true
        try {
            getSystemService(BluetoothManager::class.java).adapter?.bluetoothLeScanner?.stopScan(callback)
        } catch (_: SecurityException) {
            // Permission may have been revoked while the scan was active.
        }
        Log.i(TAG, "BLE scan stopped")
    }

    private fun connect(result: ScanResult) {
        stopScan()
        closeConnection()
        val generation = ++connectionGeneration
        updateState("Connecting", "Opening GATT connection…")
        disconnectButton.isEnabled = true

        val callback = object : BluetoothGattCallback() {
            override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                if (!isCurrentConnection(generation, gatt)) {
                    try {
                        gatt.close()
                    } catch (_: SecurityException) {
                        // A stale connection must still be ignored if permission was revoked.
                    }
                    return
                }
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    failConnection(generation, gatt, "GATT connection error $status.")
                } else if (newState == BluetoothProfile.STATE_CONNECTED) {
                    Log.i(TAG, "GATT connected; discovering services")
                    runOnUiThread {
                        if (isCurrentConnection(generation, gatt)) {
                            updateState("Discovering", "Connected; discovering Heart Rate Service…")
                        }
                    }
                    try {
                        if (!gatt.discoverServices()) failConnection(generation, gatt, "Service discovery did not start.")
                    } catch (_: SecurityException) {
                        failConnection(generation, gatt, "Bluetooth connect permission was revoked.")
                    }
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    failConnection(generation, gatt, "Device disconnected.", "Disconnected")
                }
            }

            override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                if (!isCurrentConnection(generation, gatt)) return
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    failConnection(generation, gatt, "Service discovery error $status.")
                    return
                }
                val characteristic = gatt.getService(HEART_RATE_SERVICE)
                    ?.getCharacteristic(HEART_RATE_MEASUREMENT)
                if (characteristic == null) {
                    failConnection(generation, gatt, "Heart Rate Measurement 0x2A37 not found.")
                    return
                }
                subscribe(generation, gatt, characteristic)
            }

            override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
                if (!isCurrentConnection(generation, gatt) || descriptor.uuid != CLIENT_CONFIG) return
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    Log.i(TAG, "Heart-rate notifications subscribed")
                    runOnUiThread {
                        if (isCurrentConnection(generation, gatt)) {
                            mainHandler.removeCallbacksAndMessages(CONNECTION_TIMEOUT_TOKEN)
                            updateState("Subscribed", "Waiting for 0x2A37 measurements…")
                        }
                    }
                } else {
                    failConnection(generation, gatt, "Subscription descriptor error $status.")
                }
            }

            override fun onCharacteristicChanged(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
                value: ByteArray,
            ) {
                if (isCurrentConnection(generation, gatt) && characteristic.uuid == HEART_RATE_MEASUREMENT) {
                    showMeasurement(generation, gatt, value)
                }
            }

            @Deprecated("Used by Android 12 callbacks")
            override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
                if (isCurrentConnection(generation, gatt) && characteristic.uuid == HEART_RATE_MEASUREMENT) {
                    showMeasurement(generation, gatt, characteristic.value ?: byteArrayOf())
                }
            }
        }

        try {
            activeGatt = result.device.connectGatt(this, false, callback, BluetoothDevice.TRANSPORT_LE)
            val timeout = Runnable {
                val gatt = activeGatt
                if (generation == connectionGeneration && gatt != null) {
                    closeConnection()
                    updateState("Timeout", "Connection or subscription timed out.")
                }
            }
            mainHandler.postAtTime(timeout, CONNECTION_TIMEOUT_TOKEN, android.os.SystemClock.uptimeMillis() + CONNECTION_TIMEOUT_MS)
        } catch (_: SecurityException) {
            updateState("Error", "Bluetooth connect permission was not granted.")
            disconnectButton.isEnabled = false
        }
    }

    @Suppress("DEPRECATION")
    private fun subscribe(generation: Int, gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
        val supportsNotify = characteristic.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0
        val supportsIndicate = characteristic.properties and BluetoothGattCharacteristic.PROPERTY_INDICATE != 0
        val descriptorValue = when {
            supportsNotify -> BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
            supportsIndicate -> BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
            else -> {
                failConnection(generation, gatt, "0x2A37 does not support notify or indicate.")
                return
            }
        }
        val descriptor = characteristic.getDescriptor(CLIENT_CONFIG)
        if (descriptor == null) {
            failConnection(generation, gatt, "Client Configuration descriptor 0x2902 not found.")
            return
        }
        try {
            if (!gatt.setCharacteristicNotification(characteristic, true)) {
                failConnection(generation, gatt, "Could not enable local characteristic notifications.")
                return
            }
            val writeStarted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                gatt.writeDescriptor(descriptor, descriptorValue) == android.bluetooth.BluetoothStatusCodes.SUCCESS
            } else {
                descriptor.value = descriptorValue
                gatt.writeDescriptor(descriptor)
            }
            if (!writeStarted) {
                failConnection(generation, gatt, "Could not start subscription descriptor write.")
            } else {
                runOnUiThread {
                    if (isCurrentConnection(generation, gatt)) {
                        updateState("Subscribing", "Enabling 0x2A37 notifications…")
                    }
                }
            }
        } catch (_: SecurityException) {
            failConnection(generation, gatt, "Bluetooth connect permission was revoked.")
        }
    }

    private fun showMeasurement(generation: Int, gatt: BluetoothGatt, value: ByteArray) {
        val parsed = HeartRateMeasurementParser.parse(value)
        runOnUiThread {
            if (!isCurrentConnection(generation, gatt)) return@runOnUiThread
            when (parsed) {
                is HeartRateParseResult.Success -> {
                    val rr = if (parsed.measurement.rrIntervalsSeconds.isEmpty()) "none" else
                        parsed.measurement.rrIntervalsSeconds.joinToString { "%.3f s".format(it) }
                    readingText.text = "${parsed.measurement.beatsPerMinute} BPM\nRR: $rr"
                    statusText.text = "Subscribed — measurement received"
                }
                is HeartRateParseResult.Malformed -> {
                    statusText.text = "Malformed packet ignored: ${parsed.reason}"
                }
            }
        }
    }

    private fun isCurrentConnection(generation: Int, gatt: BluetoothGatt): Boolean =
        generation == connectionGeneration && activeGatt === gatt

    private fun failConnection(
        generation: Int,
        gatt: BluetoothGatt,
        message: String,
        state: String = "Error",
    ) {
        if (!isCurrentConnection(generation, gatt)) return
        runOnUiThread {
            if (!isCurrentConnection(generation, gatt)) return@runOnUiThread
            closeConnection()
            updateState(state, message)
        }
    }

    private fun closeConnection() {
        mainHandler.removeCallbacksAndMessages(CONNECTION_TIMEOUT_TOKEN)
        val gatt = activeGatt
        activeGatt = null
        ++connectionGeneration
        if (gatt != null) {
            try {
                gatt.disconnect()
            } catch (_: SecurityException) {
                // Always close below, even if permission was revoked.
            } finally {
                gatt.close()
            }
        }
        disconnectButton.isEnabled = false
        readingText.text = "No heart-rate measurement yet"
    }

    private fun requestTestNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            pendingNotificationAfterPermission = true
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATION_PERMISSION)
            return
        }
        postTestNotification()
    }

    private fun postTestNotification() {
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(NOTIFICATION_CHANNEL, "Watch link diagnostics", NotificationManager.IMPORTANCE_HIGH),
        )
        val notification = android.app.Notification.Builder(this, NOTIFICATION_CHANNEL)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("Pulse watch-link test")
            .setContentText("If Garmin Connect forwarding is enabled, this should appear on the paired watch.")
            .setAutoCancel(true)
            .build()
        try {
            manager.notify(TEST_NOTIFICATION_ID, notification)
            updateState("Notification sent", "Phone OS received the local test notification.")
        } catch (_: SecurityException) {
            updateState("Error", "Notification permission was not granted.")
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        val granted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        when (requestCode) {
            REQUEST_BLE_PERMISSIONS -> {
                val resume = pendingScanAfterPermission
                val diagnostic = pendingDiagnosticScan
                pendingScanAfterPermission = false
                pendingDiagnosticScan = false
                if (granted && resume) startScan(diagnostic) else updateState("Error", "Nearby devices permission is required to scan and connect.")
            }
            REQUEST_NOTIFICATION_PERMISSION -> {
                val resume = pendingNotificationAfterPermission
                pendingNotificationAfterPermission = false
                if (granted && resume) postTestNotification() else updateState("Error", "Notification permission is required for the local link test.")
            }
        }
    }

    private fun hasBlePermissions(): Boolean =
        checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED &&
            checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED

    private fun isGarminConnectInstalled(): Boolean = try {
        packageManager.getPackageInfo(GARMIN_CONNECT_PACKAGE, 0)
        true
    } catch (_: PackageManager.NameNotFoundException) {
        false
    }

    private fun updateState(state: String, detail: String) {
        statusText.text = "$state — $detail"
    }

    private fun shortUuid(uuid: UUID): String {
        val text = uuid.toString()
        return if (text.endsWith("-0000-1000-8000-00805f9b34fb")) "0x${text.substring(4, 8).uppercase()}" else text
    }

    override fun onStop() {
        stopScan()
        closeConnection()
        foundDevices.clear()
        deviceList.removeAllViews()
        updateState("Disconnected", "Foreground activity stopped; BLE resources closed.")
        super.onStop()
    }

    override fun onDestroy() {
        stopScan()
        closeConnection()
        super.onDestroy()
    }

    companion object {
        private const val TAG = "PulseBleStage"
        private const val REQUEST_BLE_PERMISSIONS = 100
        private const val REQUEST_NOTIFICATION_PERMISSION = 101
        private const val SCAN_TIMEOUT_MS = 10_000L
        private const val CONNECTION_TIMEOUT_MS = 15_000L
        private const val NOTIFICATION_CHANNEL = "watch-link-diagnostic"
        private const val TEST_NOTIFICATION_ID = 1
        private const val GARMIN_CONNECT_PACKAGE = "com.garmin.android.apps.connectmobile"
        private val CONNECTION_TIMEOUT_TOKEN = Any()
        private val HEART_RATE_SERVICE: UUID = UUID.fromString("0000180d-0000-1000-8000-00805f9b34fb")
        private val HEART_RATE_MEASUREMENT: UUID = UUID.fromString("00002a37-0000-1000-8000-00805f9b34fb")
        private val CLIENT_CONFIG: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }
}
