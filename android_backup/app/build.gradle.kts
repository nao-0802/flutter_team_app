plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.flutter_temp_fix"
    compileSdk = 36

    ndkVersion = "27.0.12077973"

    compileOptions {
        // ✅ Java 11 + desugaring有効化
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true // ← これが超重要！
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.flutter_temp_fix"
        minSdk = flutter.minSdkVersion // ← Firebase Auth にも必要（21だとビルド失敗）
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ Kotlin 標準ライブラリ
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8")

    // ✅ Desugaring 対応
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
