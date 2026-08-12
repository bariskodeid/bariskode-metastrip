import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load signing config from key.properties (standard Flutter pattern)
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use(keystoreProperties::load)
}

val propertySigningValues = listOf(
    keystoreProperties["storeFile"] as? String,
    keystoreProperties["storePassword"] as? String,
    keystoreProperties["keyAlias"] as? String,
    keystoreProperties["keyPassword"] as? String,
)
val environmentSigningValues = listOf(
    System.getenv("KEYSTORE_PATH"),
    System.getenv("KEYSTORE_PASSWORD"),
    System.getenv("KEY_ALIAS"),
    System.getenv("KEY_PASSWORD"),
)
val hasPropertySigning = propertySigningValues.all { !it.isNullOrBlank() }
val hasEnvironmentSigning = environmentSigningValues.all { !it.isNullOrBlank() }

dependencies {
  // Import the Firebase BoM
  implementation(platform("com.google.firebase:firebase-bom:34.17.0"))


  // TODO: Add the dependencies for Firebase products you want to use
  // When using the BoM, don't specify versions in Firebase dependencies
  implementation("com.google.firebase:firebase-analytics")


  // Add the dependencies for any other desired Firebase products
  // https://firebase.google.com/docs/android/setup#available-libraries
}

android {
    namespace = "com.bariskode.metastrip"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.bariskode.metastrip"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // Primary: read from key.properties
            if (hasPropertySigning) {
                storeFile = file(propertySigningValues[0]!!)
                storePassword = propertySigningValues[1]
                keyAlias = propertySigningValues[2]
                keyPassword = propertySigningValues[3]
            } else if (hasEnvironmentSigning) {
                storeFile = file(environmentSigningValues[0]!!)
                storePassword = environmentSigningValues[1]
                keyAlias = environmentSigningValues[2]
                keyPassword = environmentSigningValues[3]
            }
        }
    }

    buildTypes {
        release {
            val isReleaseTask = gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }
            if (isReleaseTask && !hasPropertySigning && !hasEnvironmentSigning) {
                throw GradleException(
                    "Incomplete release signing config: provide storeFile, storePassword, keyAlias, and keyPassword in key.properties or the matching environment variables"
                )
            }
            isDebuggable = false
            // Obfuscation untuk release build (IMPLEMENTATION_PLAN Phase 6)
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("release")
            ndk {
                debugSymbolLevel = "SYMBOL_TABLE"
            }
        }
    }
}

flutter {
    source = "../.."
}
