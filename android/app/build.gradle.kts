// android/app/build.gradle.kts (module)
plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // your package / namespace
    namespace = "com.ophen.littlebird"

    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Play Store applicationId (this is what users install)
        applicationId = "com.ophen.littlebird"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 🔐 Release signing configuration (no gradle.properties, no nulls)
    signingConfigs {
        create("release") {
            // From android/app, this points to android/new-release.jks
            storeFile = file("../new-release.jks")

            // ⬇️ REPLACE THESE with the real values you used in keytool
            storePassword = "Aditya@6626"
            keyAlias = "new-alias"
            keyPassword = "Aditya@6626"

            isV1SigningEnabled = true
            isV2SigningEnabled = true
        }
    }

    buildTypes {
        getByName("release") {
            // Use the release keystore instead of debug
            signingConfig = signingConfigs.getByName("release")

            isMinifyEnabled = false
            isShrinkResources = false

            // If you want minify later:
            // proguardFiles(
            //     getDefaultProguardFile("proguard-android-optimize.txt"),
            //     "proguard-rules.pro"
            // )
        }
    }
}

flutter {
    source = "../.."
}
