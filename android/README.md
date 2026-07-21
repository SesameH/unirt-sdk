# UniRT Android binding

Kotlin + JNI layer over the UniRT C API. LLM (text) and VLM (multimodal)
both via llama_cpp/GGUF; embeddings follow the same pattern when needed.

## Build the AAR

This is a real Android library module (Gradle + AGP,
`com.android.library`). The SDK's own implementation is closed-source, so
`externalNativeBuild` here only compiles the thin JNI glue
(`jni/unirt_jni.cpp`) against a **prebuilt** `libunirt.so`; the rest
(`libunirt_plugin_llama_cpp.so`, llama.cpp's own `libggml*`/`libllama`/
`libmtmd`, `libomp.so`) are bundled straight in via the `jniLibs` source
set. Grab them first:

```sh
cd android
# Download and unzip the latest arm64-v8a native libs from this repo's
# Releases into prebuilt/arm64-v8a/ (must contain libunirt.so at minimum —
# see jni/CMakeLists.txt).
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

## Skip Gradle — use the downloaded AAR directly

If you don't need to touch the JNI glue, just drop the prebuilt AAR from
this repo's [Releases](../../../releases) straight into your app module
and skip building anything here at all.

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
