# Android BLE diagnostic

Foreground-only Android prototype for scanning Heart Rate Service (`0x180D`)
advertisements, letting the user select a device, and subscribing to Heart Rate
Measurement (`0x2A37`). **Scan all (diagnostic)** is an explicit fallback that
shows nearby advertised service UUIDs; it never auto-connects.

## Build and verify

Requires Android SDK platform 35 and Gradle with the Android Gradle Plugin
already available.

```sh
gradle --no-daemon check :app:assembleDebug
```

`check` runs Android lint and the dependency-free `:app:parserRegressionTest`.
The latter compiles the pure Kotlin parser regression source and executes its
`main`/`check` assertions. `:app:testDebugUnitTest` alone is intentionally
disabled because there is no JUnit or other test-framework dependency.

The debug APK is written to:

```text
app/build/outputs/apk/debug/app-debug.apk
```

The app has no runtime or test library dependencies beyond the Android/Kotlin
toolchain supplied by AGP. Its manifest does not request internet access.

The local notification button only posts to the phone OS. Watch delivery is
phone OS → Garmin Connect → paired watch, requiring Garmin Connect to be
installed, paired, and allowed notification access; it is not a BLE Heart Rate
Service write.
