// Android application build and environment-provided release signing for T006.
// Debug workflows require no secrets; requested release tasks fail rather than
// producing an unsigned or debug-signed artifact when local credentials are absent.
plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningEnvironment =
    listOf(
        "ANDROID_RELEASE_KEYSTORE_PATH",
        "ANDROID_RELEASE_KEYSTORE_PASSWORD",
        "ANDROID_RELEASE_KEY_PASSWORD",
        "ANDROID_RELEASE_KEY_ALIAS",
    )
val releaseSigningValues =
    releaseSigningEnvironment.associateWith { name ->
        providers.environmentVariable(name).orNull?.takeIf { it.isNotBlank() }
    }
gradle.taskGraph.whenReady {
    if (allTasks.any { task -> task.name.contains("release", ignoreCase = true) }) {
        val missingValues = releaseSigningEnvironment.filter { releaseSigningValues[it] == null }
        check(missingValues.isEmpty()) {
            "Release signing requires environment variables: ${missingValues.joinToString()}"
        }
        check(file(releaseSigningValues.getValue("ANDROID_RELEASE_KEYSTORE_PATH")!!).isFile) {
            "Release signing keystore does not exist at ANDROID_RELEASE_KEYSTORE_PATH"
        }
    }
}

android {
    namespace = "ai.codegeist.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "ai.codegeist.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Direct-distribution baseline: Android 13 (API 33) or newer.
        minSdk = 33
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningEnvironment.all { releaseSigningValues[it] != null }) {
            create("release") {
                storeFile = file(releaseSigningValues.getValue("ANDROID_RELEASE_KEYSTORE_PATH")!!)
                storePassword = releaseSigningValues.getValue("ANDROID_RELEASE_KEYSTORE_PASSWORD")
                keyPassword = releaseSigningValues.getValue("ANDROID_RELEASE_KEY_PASSWORD")
                keyAlias = releaseSigningValues.getValue("ANDROID_RELEASE_KEY_ALIAS")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
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
