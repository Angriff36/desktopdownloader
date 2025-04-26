pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        // Ensure the local.properties file exists or handle potential exceptions
        val localPropertiesFile = file("local.properties")
        if (localPropertiesFile.exists()) {
            localPropertiesFile.inputStream().use { properties.load(it) }
        }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // Consider updating AGP and Kotlin versions if compatible with your Flutter version
    id("com.android.application") version "8.7.0" apply false
    id("org.jetbrains.kotlin.android") version "1.9.22" apply false // Match the version used elsewhere
}

include(":app")

// Apply Flutter's include script if it's not handled by the plugin loader
// apply(from = File(flutterSdkPath, ".android/include_flutter.groovy")) // Check if this line is needed
