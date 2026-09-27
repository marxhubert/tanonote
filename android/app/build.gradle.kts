import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// The release keystore lives outside the repository (android/.gitignore keeps
// key.properties out). Without it the release build falls back to the debug
// signature: enough to compile and try, not to publish.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasKeystore = keystorePropertiesFile.exists()
if (hasKeystore) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.marxhubert.tanonote"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.marxhubert.tanonote"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

// Keep the Malagasy references in sync with l10n before the assets are
// bundled. The Dart CLI rewrites assets/config/malagasy_refs.json and prints
// the keys it added or removed, so a stale file is caught during the build.
val syncMalagasyRefs by tasks.registering(Exec::class) {
    val localProperties = rootProject.file("local.properties")
    val flutterSdk: String? = if (localProperties.exists()) {
        // Properties is already imported at the top of this script; a fully
        // qualified java.util would resolve against Gradle's java extension.
        Properties().apply {
            localProperties.inputStream().use { load(it) }
        }.getProperty("flutter.sdk")
    } else {
        null
    }
    // The tool is gated to a local debug or profile build: the mode comes from
    // the requested task, so a local release build skips it too.
    val requested = gradle.startParameter.taskNames.joinToString(" ").lowercase()
    val mode = when {
        requested.contains("release") -> "release"
        requested.contains("profile") -> "profile"
        else -> "debug"
    }
    // rootProject is android/, so its parent is the Flutter project root.
    workingDir = rootProject.projectDir.parentFile
    commandLine(
        if (flutterSdk != null) "$flutterSdk/bin/dart" else "dart",
        "run",
        "tool/update_malagasy_refs.dart",
        "--mode=$mode",
        "--sync-web",
        "--limit=15",
    )
}

tasks.matching { it.name == "preBuild" }.configureEach {
    dependsOn(syncMalagasyRefs)
}
