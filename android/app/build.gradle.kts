plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.offbeat.offbeat"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.offbeat.offbeat"
        // Section 0: minSdk 24
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Section H.3: abiFilters arm64-v8a + armeabi-v7a
        // Note: when running 'flutter build apk --split-per-abi', Flutter configures splits.abi.
        // Uncomment ndk.abiFilters if packaging a single fat/universal APK without splits:
        // ndk {
        //     abiFilters.addAll(listOf("arm64-v8a", "armeabi-v7a"))
        // }
    }

    packaging {
        jniLibs {
            // Section H.3: useLegacyPackaging = true for libmpv / media_kit native libraries
            useLegacyPackaging = true
        }
    }

    buildTypes {
        release {
            // Signing with debug keys so release APK is immediately installable
            signingConfig = signingConfigs.getByName("debug")

            // Section H.3: Release optimization switch (toggle false for testing without minification)
            val enableMinifyAndShrink = true
            isMinifyEnabled = enableMinifyAndShrink
            isShrinkResources = enableMinifyAndShrink

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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
    implementation("androidx.media:media:1.7.0")
}
