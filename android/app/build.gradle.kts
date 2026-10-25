plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/** Google's public AdMob test application ID. Safe to commit. */
val TEST_ADMOB_APP_ID = "ca-app-pub-3940256099942544~3347511713"

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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.bichoumac.clean_gallery"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Android 11: needed for scoped-storage MediaStore APIs, see docs/decisions/0006-permissions.md.
        minSdk = 30
        // Must match the latest API level required by Google Play, see docs/release.md.
        targetSdk = 36
        // AdMob application ID. Set with -PadmobAppId=... for release builds.
        // The default is Google's public test ID, so debug builds never serve real ads.
        manifestPlaceholders["admobAppId"] =
            (project.findProperty("admobAppId") as String?) ?: TEST_ADMOB_APP_ID
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
