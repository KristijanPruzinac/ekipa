import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingPropertiesFile = rootProject.file("key.properties")
val signingProperties = Properties()
if (signingPropertiesFile.exists()) {
    signingPropertiesFile.inputStream().use { signingProperties.load(it) }
}
val signingFields = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val configuredFields = signingFields.count { !signingProperties.getProperty(it).isNullOrBlank() }
require(!signingPropertiesFile.exists() || configuredFields == signingFields.size) {
    "Android signing is incomplete. Supply all four values in android/key.properties."
}
val releaseSigningAvailable = configuredFields == signingFields.size
val releaseRequested = gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
require(!releaseRequested || releaseSigningAvailable || System.getenv("WAGZ_ALLOW_UNSIGNED_RELEASE") == "true") {
    "Release signing is not configured. Supply android/key.properties, or explicitly set WAGZ_ALLOW_UNSIGNED_RELEASE=true for non-installable verification artifacts."
}

android {
    namespace = "hr.wagz.wagz_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "hr.wagz.wagz_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningAvailable) {
            create("release") {
                storeFile = file(signingProperties.getProperty("storeFile"))
                storePassword = signingProperties.getProperty("storePassword")
                keyAlias = signingProperties.getProperty("keyAlias")
                keyPassword = signingProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (releaseSigningAvailable) signingConfigs.getByName("release") else null
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
