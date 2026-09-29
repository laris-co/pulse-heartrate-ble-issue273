plugins {
    id("com.android.application")
}

android {
    namespace = "co.laris.pulseheartrate"
    compileSdk = 35

    defaultConfig {
        applicationId = "co.laris.pulseheartrate"
        minSdk = 31
        targetSdk = 35
        versionCode = 1
        versionName = "0.1"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

val parserRegressionTest = tasks.register<JavaExec>("parserRegressionTest") {
    group = "verification"
    description = "Runs dependency-free Heart Rate Measurement parser regressions."
    dependsOn("compileDebugUnitTestKotlin")
    classpath(
        files(
            layout.buildDirectory.dir("intermediates/built_in_kotlinc/debugUnitTest/compileDebugUnitTestKotlin/classes"),
            layout.buildDirectory.dir("intermediates/built_in_kotlinc/debug/compileDebugKotlin/classes"),
        ),
        configurations.named("debugUnitTestRuntimeClasspath"),
    )
    mainClass.set("co.laris.pulseheartrate.HeartRateMeasurementParserRegression")
}

// There is intentionally no JUnit dependency. This one empty framework task
// cannot discover our dependency-free main/check runner, so keep it out of the
// lifecycle and make the real parser regression task canonical instead.
tasks.withType<Test>().configureEach {
    if (name == "testDebugUnitTest") enabled = false
}

tasks.named("check") {
    dependsOn(parserRegressionTest)
}
