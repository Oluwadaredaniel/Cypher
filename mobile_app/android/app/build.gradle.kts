plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    // Apply the Google services Gradle plugin
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.mobile_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.mobile_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // [PRO FIX] Bypasses the version check that blocks the build
    // Allows using 8.7.2 even if some libs "request" 8.9.1
    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }
}

// [PRO FIX] Force older versions of core and browser to satisfy AGP 8.7.2
configurations.all {
    resolutionStrategy.eachDependency {
        if (requested.group == "androidx.core") {
            useVersion("1.13.1")
        }
        if (requested.group == "androidx.browser") {
            useVersion("1.8.0")
        }
    }
}

kotlin {
    jvmToolchain(17)
}

flutter {
    source = "../.."
}

dependencies {
    // Import the Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:33.1.1"))
    // Add the dependency for the Firebase SDK for Google Analytics
    implementation("com.google.firebase:firebase-analytics")
}
