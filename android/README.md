# UniRT Android binding

Kotlin + JNI layer over the UniRT C API. LLM (text) and VLM (multimodal)
both via llama_cpp/GGUF; embeddings follow the same pattern when needed.

## Install from JitPack

The published AAR already contains the Kotlin API, JNI bridge, UniRT runtime,
and llama.cpp libraries. Add JitPack to `settings.gradle.kts`:

```kotlin
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven(url = "https://jitpack.io")
    }
}
```

Then add the release tag to the app module:

```kotlin
// app/build.gradle.kts
dependencies {
    implementation("com.github.SesameH:unirt-sdk:v0.2.0")
}
```

JitPack publishes the AAR attached to the matching GitHub Release; it does
not rebuild the closed-source native runtime. The POM supplies Kotlin stdlib
and `kotlinx-coroutines-core` transitively.

The current artifact requires `minSdk 28` and ships only `arm64-v8a`. Use an
arm64 device/emulator; an x86_64 emulator cannot load the native libraries.

## Use the downloaded AAR directly

Alternatively, download `unirt-android.aar` from the
[v0.2.0 Release](https://github.com/SesameH/unirt-sdk/releases/tag/v0.2.0),
place it at `app/libs/unirt-android.aar`, and add:

```kotlin
// app/build.gradle.kts
dependencies {
    implementation(files("libs/unirt-android.aar"))
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
}
```

Direct AAR dependencies do not carry Maven transitive dependencies, hence
the explicit coroutines dependency.

## Rebuild the AAR wrapper

This is a real Android library module (Gradle + AGP,
`com.android.library`). The SDK's own implementation is closed-source, so
`externalNativeBuild` here only compiles the thin JNI glue
(`jni/unirt_jni.cpp`) against a **prebuilt** `libunirt.so`; the rest
(`libunirt_plugin_llama_cpp.so`, llama.cpp's own `libggml*`/`libllama`/
`libmtmd`, `libomp.so`) are bundled straight in via the `jniLibs` source
set. Extract the native libraries from the published AAR, discard its JNI
bridge, and rebuild that bridge from this checkout:

```sh
git checkout v0.2.0
cd android
curl -fL -o unirt-android.aar \
  https://github.com/SesameH/unirt-sdk/releases/download/v0.2.0/unirt-android.aar
mkdir -p prebuilt/arm64-v8a
unzip -jo unirt-android.aar 'jni/arm64-v8a/*.so' -d prebuilt/arm64-v8a
rm prebuilt/arm64-v8a/libunirt_jni.so

./gradlew assembleRelease   # -> build/outputs/aar/unirt-android-release.aar
./gradlew test              # unit tests: fakes LlmSession/VlmSession — anything
                             # touching Native itself needs a real device/emulator
```

Needs `ANDROID_HOME`/`ANDROID_SDK_ROOT` set (NDK 27.0.12077973, matched in
`build.gradle.kts`'s `ndkVersion`) and a JDK 17. Add the AAR as a dependency
in your app module — plugins are still discovered automatically at runtime
(the registry scans the directory holding `libunirt.so` for the flat
`libunirt_plugin_<id>.so` naming), no environment variables needed.

Only `arm64-v8a` is shipped today (`abiFilters` in `build.gradle.kts`);
add more ABIs there once prebuilt libs for them exist.

## Use

Requires `kotlinx-coroutines-core`. `LlmSession` is an interface (fake it in
unit tests — local JVM tests cannot load the native library); the bundled
implementation confines all native calls to one thread per session, so every
member is safe to call from any coroutine.

```kotlin
UniRT.start()
UniRT.createLlmSession("/data/local/tmp/SmolLM2-135M-Instruct-Q8_0.gguf").use { session ->
    val prompt = session.applyChatTemplate(
        listOf(ChatMessage.user("What is the capital of France?"))
    )
    session.stream(prompt).collect { event ->
        when (event) {
            is LlmStreamResult.Token -> print(event.text)                  // cancel to stop decoding
            is LlmStreamResult.Completed -> println("\n${event.profile}")  // ttft, tok/s, stop reason
            is LlmStreamResult.Error -> println("\ngeneration failed: ${event.cause}")
        }
    }
}
UniRT.stop()
```

`VlmSession` mirrors `LlmSession` — same threading contract, same
`LlmStreamResult` stream events — but takes multimodal turns (`ContentPart.Text`/
`Image`/`Audio`) and per-request media on `VlmGenerateOptions` instead of
`GenerateOptions` (kept separate: image/audio fields would be dead weight on
every LLM call):

```kotlin
UniRT.start()
UniRT.createVlmSession(
    modelPath = "/data/local/tmp/vision-model.gguf",
    mmprojPath = "/data/local/tmp/mmproj.gguf",
).use { session ->
    val prompt = session.applyChatTemplate(
        listOf(VlmChatMessage.user(
            ContentPart.Text("What's in this image?"),
            ContentPart.Image("/data/local/tmp/photo.jpg"),
        ))
    )
    val reply = session.generate(
        prompt,
        VlmGenerateOptions(imagePaths = listOf("/data/local/tmp/photo.jpg")),
    )
    println(reply)
}
UniRT.stop()
```

Kotlin conventions over ceremony: default arguments instead of builders,
`object` instead of a singleton class, `Flow` instead of listener
interfaces.

Models ship however the app prefers (assets, download at first run); pass an
absolute filesystem path. On-device instrumentation tests are future work.
