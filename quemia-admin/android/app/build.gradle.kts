import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Plugin de Google Services: lee android/app/google-services.json.
    id("com.google.gms.google-services")
}

android {
    namespace = "com.melliqui.quemia_admin"
    // Pinned to 37: flutter_local_notifications and androidx.core 1.19.0
    // require compiling against Android API 37+, while Flutter 3.47.9's
    // default (flutter.compileSdkVersion) is 36. Restore the default once
    // a newer Flutter raises it to 37. minSdk/targetSdk stay on Flutter
    // defaults (only compileSdk is raised; targetSdk 36 keeps runtime
    // behaviour unchanged). Mismo arreglo que la app principal (7.1):
    // sin esto el build del Admin falla en checkReleaseAarMetadata.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications (it uses java.time APIs).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.melliqui.quemia_admin"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // Firma release permanente (keystore Quemia). El workflow de
            // GitHub genera android/key.properties desde los secretos del
            // repo; sin ese archivo, las claves quedan vacías y el build
            // usa la configuración debug (ver buildTypes abajo).
            val keystoreProperties = Properties()
            val keystorePropertiesFile = rootProject.file("key.properties")
            if (keystorePropertiesFile.exists()) {
                keystoreProperties.load(FileInputStream(keystorePropertiesFile))
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            // Con key.properties: firma release permanente (la que Google
            // reconoce para el inicio de sesión). Sin él: claves debug,
            // para que `flutter run --release` siga funcionando.
            signingConfig = if (rootProject.file("key.properties").exists()) {
                signingConfigs.getByName("release")
            } else {
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

dependencies {
    // Core library desugaring, required by flutter_local_notifications.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
