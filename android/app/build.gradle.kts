import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: the upload key stays out of the repository (AGENTS.md rule 7).
// Either android/key.properties (git-ignored, see docs/release.md) or the
// CLEAN_GALLERY_* environment variables, for CI. Without either, release
// builds fall back to the debug key so `flutter run --release` still works.
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

fun signingValue(property: String, variable: String): String? =
    keyProperties.getProperty(property) ?: System.getenv(variable)

val releaseStoreFile = signingValue("storeFile", "CLEAN_GALLERY_STORE_FILE")

android {
    namespace = "com.bichoumac.clean_gallery"
    // permission_handler_android 14+ compiles against API 37 and requires the app to match.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Final, confirmed by the product owner on 2026-11-05.
        applicationId = "com.bichoumac.clean_gallery"
        // Android 11: needed for scoped-storage MediaStore APIs, see docs/decisions/0006-permissions.md.
        minSdk = 30
        // Must match the latest API level required by Google Play, see docs/release.md.
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseStoreFile != null) {
            create("release") {
                storeFile = rootProject.file(releaseStoreFile)
                storePassword = signingValue("storePassword", "CLEAN_GALLERY_STORE_PASSWORD")
                keyAlias = signingValue("keyAlias", "CLEAN_GALLERY_KEY_ALIAS")
                keyPassword = signingValue("keyPassword", "CLEAN_GALLERY_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (releaseStoreFile != null) {
                signingConfigs.getByName("release")
            } else {
                logger.warn("Clean Gallery: no release key found, signing with the debug key (docs/release.md).")
                signingConfigs.getByName("debug")
            }
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

dependencies {
    // Removing GPS data from shared copies.
    implementation("androidx.exifinterface:exifinterface:1.4.2")
    // FileProvider for shared copies.
    implementation("androidx.core:core-ktx:1.19.1")
}
