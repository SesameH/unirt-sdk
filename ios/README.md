# UniRT iOS binding

Swift wrapper (`UniRTKit`) over the UniRT C API: LLM (text) and VLM
(multimodal) both via llama_cpp/GGUF; embeddings follow the same pattern
when needed.

Unlike Android, there is no JNI-style glue layer: Swift calls the C ABI
directly. The one iOS-specific wrinkle is plugin loading — iOS forbids
`dlopen` of arbitrary paths, so plugins cannot be discovered from a
directory scan the way `llama_cpp` is on macOS/Linux/Windows. Instead the
app links the plugin as a **static library** and joins it in-process with
`unirt_register_plugin()` before `unirt_init()`.

## Install v0.2.0 as a local Swift package

`UniRT.xcframework` is a prebuilt binary (merges `libunirt` + the
llama_cpp plugin + llama.cpp's own engine into one dylib per platform
slice) — it isn't built from this repo, since doing so needs the private
core repo's CMake project.

Clone the matching tag and place the release asset inside `ios/`, next to
`Package.swift`:

```sh
git clone --branch v0.2.0 --depth 1 \
  https://github.com/SesameH/unirt-sdk.git
cd unirt-sdk
curl -fLO \
  https://github.com/SesameH/unirt-sdk/releases/download/v0.2.0/unirt-ios-xcframework.zip
unzip -q unirt-ios-xcframework.zip -d ios
```

The resulting layout must be:

```text
ios/
├── Package.swift
├── UniRT.xcframework/
├── Sources/
└── Tests/
```

In Xcode:

1. Choose **File → Add Package Dependencies… → Add Local…**.
2. Select the checkout's `ios` directory (the directory containing
   `Package.swift`).
3. Add the `UniRTKit` product to the app target.

For another local Swift package, add `.package(path: "../unirt-sdk/ios")`
to its dependencies and depend on the `UniRTKit` product.

The v0.2.0 repository tag intentionally does not contain the binary, so
pasting the GitHub repository URL as a remote package is not sufficient.
Use the local-package steps above. `Package.swift`'s `UniRTNative` binary
target then links and embeds the downloaded XCFramework automatically; no
manual linker flags or separate **Embed & Sign** step is needed.

```swift
import UniRTKit

try UniRT.registerStaticPlugin(identity: unirt_plugin_id, open: unirt_plugin_open)
try UniRT.start()
```

(Registration is still explicit — the merged dylib bundles the plugin, but
doesn't self-register at load time, matching this project's preference for
explicit calls over load-time magic elsewhere. `unirt_plugin_id`/
`unirt_plugin_open` are declared in `CUniRT`, resolved from the linked
`UniRTNative` binary target.)

## Use

```swift
import UniRTKit

try UniRT.registerStaticPlugin(identity: unirt_plugin_id, open: unirt_plugin_open)
try UniRT.start()

let session = try await UniRT.createLlmSession(
    modelPath: "/path/to/SmolLM2-135M-Instruct-Q8_0.gguf")
let prompt = try await session.applyChatTemplate([.user("What is the capital of France?")])
for try await piece in session.stream(prompt: prompt) {
    print(piece, terminator: "")     // cancel the enclosing Task to stop decoding
}

try UniRT.stop()
```

`VlmSession` mirrors `LlmSession` (same actor, same registration/start
sequence) but takes multimodal turns (`ContentPart.text`/`.image`/`.audio`)
and per-request media on `VlmGenerateOptions`:

```swift
let session = try await UniRT.createVlmSession(
    modelPath: "/path/to/vision-model.gguf", mmprojPath: "/path/to/mmproj.gguf")
let prompt = try await session.applyChatTemplate([
    .user(.text("What's in this image?"), .image(path: "/path/to/photo.jpg")),
])
let reply = try await session.generate(
    prompt: prompt, options: VlmGenerateOptions(imagePaths: ["/path/to/photo.jpg"]))
```

`LlmSession`/`VlmSession` are Swift `actor`s: the native handle is
single-threaded by contract, and actor isolation confines every native call
without extra locking, mirroring the Kotlin binding's dedicated-dispatcher
approach.

Models ship however the app prefers (bundled resource, downloaded at first
run); pass an absolute filesystem path — the sandbox means that's usually
somewhere under `FileManager.default.urls(for: .documentDirectory, ...)`
or `Bundle.main`.

## Run the integration tests

`Tests/UniRTKitTests/InferenceSmokeTests.swift` is the Swift-layer
counterpart to `tests/native/test_inference_smoke.cpp`: registers the real
llama_cpp plugin, loads a GGUF model, applies the chat template, and runs
both blocking and streaming generation. `VlmLinkSmokeTests.swift` proves the
six `unirt_vlm_*` entry points actually link (no VLM test model is available
to run real multimodal inference, so it only checks that a missing model
fails cleanly through the whole chain rather than link-erroring or
crashing).

Once `UniRT.xcframework` is downloaded (see above), both just run:

```sh
export TEST_RUNNER_UNIRT_TEST_MODEL_PATH="/absolute/path/to/SmolLM2-135M-Instruct-Q8_0.gguf"
xcodebuild test -scheme UniRTKit -destination "id=$SIM_UDID"   # or 'platform=macOS' to
                                                                 # sanity-check without a simulator
```

(`TEST_RUNNER_`-prefixed variables are xcodebuild's mechanism for passing
environment into the test process; `InferenceSmokeTests` `XCTSkip`s without
one.) No linker flags needed — that's the point of the binary target.
