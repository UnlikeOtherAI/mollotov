# core-ai — Shared AI Management Library

C++17 static library providing all shareable AI logic across Mollotov platforms.

## What it does

| Feature | C API function |
|---------|---------------|
| Model catalog (approved models, metadata, download URLs) | `mollotov_ai_list_approved_models` |
| Device fitness evaluation (RAM/disk checks) | `mollotov_ai_model_fitness` |
| HF token storage | `mollotov_ai_set_hf_token`, `mollotov_ai_get_hf_token` |
| Model store (exists, path, remove) | `mollotov_ai_is_model_downloaded`, `mollotov_ai_model_path`, `mollotov_ai_remove_model` |
| Authenticated model downloads | `mollotov_ai_download_model` |
| Ollama HTTP client (reachable, list, infer) | `mollotov_ai_ollama_*` |
| HF Inference API cloud calls | `mollotov_ai_hf_infer` |

## Platform integration

| Platform | Linking | HTTPS |
|----------|---------|-------|
| macOS | Static `.a` via bridging header | cpp-httplib + OpenSSL |
| Linux | Static `.a` via direct C calls | cpp-httplib + OpenSSL |
| Android | Static via JNI (`mollotov_jni.so`) | Disabled — OkHttp handles HTTPS |
| iOS | Static `.a` via bridging header | Disabled — URLSession handles HTTPS |

On mobile, build with `-DMOLLOTOV_AI_USE_HTTPLIB=OFF` to exclude HTTP-dependent code. Catalog, fitness, and token functions remain available.

## Build

```bash
cd native && mkdir -p .build && cd .build
cmake .. -DBUILD_TESTING=ON
cmake --build . --target mollotov_core_ai
ctest -R test_ai --output-on-failure
```

## C API pattern

Follows the same conventions as `core-state`:
- Opaque pointer handle: `MollotovAiManagerRef`
- `extern "C"` block with null checks and try-catch on every function
- Caller-owned strings freed via `mollotov_ai_free_string()`
- JSON in/out via `nlohmann_json`

## Tests

| Test | What it covers |
|------|---------------|
| `test_ai_catalog` | Create/destroy, list models, fitness levels |
| `test_ai_store` | HF token, model not-downloaded, remove, download unknown model |
| `test_ai_ollama` | Endpoint setting, graceful failure with no server |
| `test_ai_hf_cloud` | No-token error, fake-token error, chat format |
