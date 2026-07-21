// Copyright (c) 2026 Peter Huang.
// SPDX-License-Identifier: BSD-3-Clause

// Real Android library module — ./gradlew assembleRelease produces an AAR.
// externalNativeBuild here only compiles the thin JNI glue (jni/unirt_jni.cpp)
// against a prebuilt libunirt.so (see jni/CMakeLists.txt); the SDK itself is
// closed-source and ships as the prebuilt libraries under prebuilt/<abi>/,
// bundled into the AAR via the jniLibs source set below. Run
// scripts/fetch-prebuilt.sh (or see README) to populate prebuilt/ before
// building — it's gitignored, refreshed per release.
//
// LlmSession/VlmSession are interfaces specifically so they're fakeable in
// test/: Native's System.loadLibrary("unirt_jni") means anything touching
// NativeLlmSession/NativeVlmSession/Native directly cannot run in a local
// unit test (no device/emulator) — those need instrumentation tests (future
// work). Local unit tests need no android.* framework classes here (the
// sources have none), so they run as plain JVM tests without Robolectric.

plugins {
    id("com.android.library") version "8.7.3"
    kotlin("android") version "2.0.21"
}

android {
    namespace = "ai.unirt"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    defaultConfig {
        minSdk = 28 // matches ANDROID_PLATFORM=android-28 used everywhere else in this repo

        externalNativeBuild {
            cmake {
                abiFilters += "arm64-v8a"
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("jni/CMakeLists.txt")
        }
    }

    sourceSets {
        getByName("main") {
            kotlin.srcDirs("kotlin")
            // Prebuilt libunirt.so / libunirt_plugin_llama_cpp.so / llama.cpp's
            // own libs — populated per release, not checked into source
            // control (see prebuilt/README or the top-level README).
            jniLibs.srcDirs("prebuilt")
        }
        getByName("test") {
            kotlin.srcDirs("test")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    @Suppress("UnstableApiUsage")
    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.9.0")
    testImplementation(kotlin("test"))
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.9.0")
}

tasks.withType<Test> {
    useJUnitPlatform()
}
