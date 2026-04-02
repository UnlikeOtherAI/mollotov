# Local Inference Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add on-device LLM inference to Mollotov — the CLI manages model downloads from Hugging Face, the macOS browser loads and runs them, and new MCP tools let LLMs ask the local model to summarise/describe/analyse the current page without sending data to the cloud.

**Architecture:** The CLI owns model lifecycle (download, list, delete) using GGUF files from Hugging Face. Each browser app exposes new HTTP endpoints for model loading/unloading and inference. The MCP server adds tools to query model status and run inference. On macOS, inference runs via `llama.cpp` as a compiled Swift package. Mobile will use platform-native inference frameworks (Core ML on iOS, MediaPipe on Android) in a later phase.

**Tech Stack:** llama.cpp (Swift package), Hugging Face Hub API (REST), GGUF model format, existing Mollotov HTTP/MCP patterns.

---

## System Design

### Model Storage

```
~/.mollotov/models/
  registry.json            # Tracks downloaded models, metadata, source URLs
  gemma-4-e2b-q4/
    model.gguf
    metadata.json          # Name, size, quantization, capabilities, source URL
  moondream2-q4/
    model.gguf
    metadata.json
```

Mobile model storage:
- iOS: `<app>/Documents/models/`
- Android: `<app>/files/models/`

### Approved Model Registry

The CLI ships with a built-in list of approved models (JSON embedded in the package). Each entry specifies:

```ts
interface ApprovedModel {
  id: string;                    // e.g. "gemma-4-e2b-q4"
  name: string;                  // e.g. "Gemma 4 E2B Q4"
  huggingFaceRepo: string;       // e.g. "bartowski/gemma-4-E2B-it-GGUF"
  huggingFaceFile: string;       // e.g. "gemma-4-E2B-it-Q4_K_M.gguf"
  sizeBytes: number;             // Approximate download size
  capabilities: string[];        // ["text", "vision", "audio"]
  platforms: string[];           // ["macos", "ios", "android"]
  minRamGB: number;              // Minimum RAM to run this model
  quantization: string;          // "Q4_K_M", "Q8_0", etc.
  description: string;           // One-line description for users
}
```

Mobile apps (iOS/Android) embed their own curated subset of this list. To add a model to the mobile list, users raise a PR against the relevant app.

On macOS via CLI, users can also specify an arbitrary Hugging Face GGUF URL to download — the approved list is the default, not a restriction.

### Ollama Integration

If the user has Ollama installed, Mollotov detects it and surfaces Ollama-managed models as a second-tier option alongside the native GGUF models.

**Detection:** Check if the Ollama API is reachable at `http://localhost:11434/api/tags` (the default Ollama endpoint). This is a simple GET that returns a JSON list of installed models. No configuration needed — if Ollama is running, we find it.

**Display in `mollotov ai list`:**

```
Native Models (GGUF via llama.cpp)
─────────────────────────────────────────────────────
  gemma-4-e2b-q4      2.5 GB   text, vision   ✓ downloaded
  gemma-4-e2b-q8      5.0 GB   text, vision   not downloaded

─── Ollama Models (detected at localhost:11434) ────
  llama3.2:3b          2.0 GB   text
  gemma2:2b            1.6 GB   text
  llava:7b             4.7 GB   text, vision
```

**How Ollama models work in the inference pipeline:**

When the user loads an Ollama model, the browser doesn't load a GGUF file — instead, the `ai-infer` endpoint proxies the request to Ollama's `/api/generate` endpoint. This means:

1. `ai-load` with an Ollama model ID sets the engine mode to `ollama` and records the model name — no file path needed, no memory consumed in the browser process
2. `ai-infer` detects the Ollama backend and forwards the prompt to `POST http://localhost:11434/api/generate` (or `/api/chat` for chat models)
3. `ai-unload` simply clears the state — Ollama manages its own model memory
4. `ai-status` reports `backend: "ollama"` so the caller knows which engine is active

**Request routing in AIHandler:**

```
ai-infer request arrives
  → check backend mode
  → if "native": run llama.cpp inference (existing path)
  → if "ollama": POST to Ollama API with prompt + image
      → parse Ollama response
      → return in standard Mollotov response format
```

**Ollama API usage:**

```
# List models
GET http://localhost:11434/api/tags
→ { "models": [{ "name": "llama3.2:3b", "size": 2000000000, ... }] }

# Generate (text)
POST http://localhost:11434/api/generate
{ "model": "llama3.2:3b", "prompt": "...", "stream": false }
→ { "response": "...", "total_duration": 1234, "eval_count": 50 }

# Generate (vision — models like llava)
POST http://localhost:11434/api/generate
{ "model": "llava:7b", "prompt": "...", "images": ["<base64>"], "stream": false }
→ { "response": "...", "total_duration": 2345, "eval_count": 80 }
```

**CLI model ID convention:**

- Native models: `gemma-4-e2b-q4` (plain ID)
- Ollama models: `ollama:llama3.2:3b` (prefixed with `ollama:`)

This prefix makes it unambiguous in all commands:
```
mollotov ai load ollama:llava:7b --device mac
mollotov ai ask "describe this page" --device mac --context screenshot
```

**No download management for Ollama:** Mollotov doesn't pull or delete Ollama models — the user manages those with `ollama pull` / `ollama rm` directly. Mollotov only reads what's available.

### Architecture Layers

```
┌─────────────────────────────────────────────┐
│                 LLM (Claude)                │
│         Uses MCP tools to interact          │
├─────────────────────────────────────────────┤
│              CLI MCP Server                 │
│  mollotov_ai_*  tools (model + inference)   │
├─────────────────────────────────────────────┤
│              CLI Commands                   │
│  mollotov ai pull / list / rm / status      │
├─────────┬───────────────────────────────────┤
│  Model  │     HTTP Client                   │
│  Store  │  POST /v1/ai-load                 │
│ (~/.m/) │  POST /v1/ai-unload              │
│         │  POST /v1/ai-infer               │
│         │  GET  /v1/ai-status              │
├─────────┴───────────────────────────────────┤
│           Browser App (macOS)               │
│                                             │
│  AIHandler (HTTP handler)                   │
│  ┌─────────────────────────────────────┐    │
│  │ ai-load: load model (native/ollama) │    │
│  │ ai-unload: free model from memory   │    │
│  │ ai-status: report loaded model      │    │
│  │ ai-infer: route to active backend   │    │
│  └──────────┬──────────────┬───────────┘    │
│             │              │                │
│  ┌──────────▼────┐  ┌─────▼──────────┐     │
│  │ Native Engine │  │ Ollama Proxy   │     │
│  │ (llama.cpp)   │  │ localhost:11434│     │
│  │ Load GGUF     │  │ /api/generate  │     │
│  │ Run locally   │  │ Forward prompt │     │
│  └───────────────┘  └────────────────┘     │
└─────────────────────────────────────────────┘
```

### HTTP API (Browser App Endpoints)

All new endpoints use the existing `/v1/` prefix pattern.

#### `POST /v1/ai-load`

Load a model into memory. Only one model can be loaded at a time. Supports both native GGUF and Ollama backends.

```json
// Request (native GGUF)
{ "path": "/Users/foo/.mollotov/models/gemma-4-e2b-q4/model.gguf" }

// Request (Ollama model — local, no path needed)
{ "ollama": "llava:7b" }

// Request (Ollama model — remote endpoint, used by mobile devices)
{ "ollama": "llava:7b", "ollamaEndpoint": "http://192.168.1.50:11434" }

// Response (success — native)
{ "success": true, "model": "gemma-4-e2b-q4", "backend": "native", "loadTimeMs": 2340 }

// Response (success — Ollama)
{ "success": true, "model": "llava:7b", "backend": "ollama", "loadTimeMs": 12 }

// Response (error — already loaded)
{ "success": false, "error": { "code": "MODEL_ALREADY_LOADED", "message": "Unload current model first", "currentModel": "gemma-4-e2b-q4" } }

// Response (error — file not found)
{ "success": false, "error": { "code": "MODEL_NOT_FOUND", "message": "No GGUF file at specified path" } }

// Response (error — Ollama not running)
{ "success": false, "error": { "code": "OLLAMA_NOT_AVAILABLE", "message": "Ollama is not running at localhost:11434" } }
```

#### `POST /v1/ai-unload`

Unload the current model, freeing memory.

```json
// Request
{}

// Response
{ "success": true }
```

#### `GET /v1/ai-status`

Report the current inference state.

```json
// Response (native model loaded)
{
  "success": true,
  "loaded": true,
  "model": "gemma-4-e2b-q4",
  "backend": "native",
  "capabilities": ["text", "vision"],
  "memoryUsageMB": 2800
}

// Response (Ollama model loaded)
{
  "success": true,
  "loaded": true,
  "model": "llava:7b",
  "backend": "ollama",
  "capabilities": ["text", "vision"],
  "ollamaEndpoint": "http://localhost:11434"
}

// Response (remote Ollama — mobile)
{
  "success": true,
  "loaded": true,
  "model": "llava:7b",
  "backend": "ollama",
  "capabilities": ["text", "vision"],
  "ollamaEndpoint": "http://192.168.1.50:11434"
}

// Response (no model)
{
  "success": true,
  "loaded": false
}
```

#### `POST /v1/ai-infer`

Run inference. The model generates a response to the prompt. Optionally attach a base64 image for vision models.

```json
// Request (text only)
{
  "prompt": "Summarise this page content in 3 bullet points",
  "context": "page_text",
  "maxTokens": 512,
  "temperature": 0.7
}

// Request (with screenshot)
{
  "prompt": "Describe what you see on this page",
  "context": "screenshot",
  "maxTokens": 512
}

// Request (with explicit data — for debugging or custom use)
{
  "prompt": "What language is this code?",
  "text": "<html>...</html>",
  "maxTokens": 256
}

// Response
{
  "success": true,
  "response": "The page shows a pricing table with three tiers...",
  "tokensUsed": 187,
  "inferenceTimeMs": 1450
}

// Error — no model loaded
{
  "success": false,
  "error": { "code": "NO_MODEL_LOADED", "message": "Load a model first with ai-load" }
}
```

The `context` field is a shortcut that tells the browser to auto-gather data before prompting:
- `"page_text"` — browser runs its existing `get-page-text` handler internally and prepends the result to the prompt
- `"screenshot"` — browser takes a viewport screenshot and passes it as the image input to a vision model
- `"dom"` — browser runs `get-dom` and prepends the HTML
- `"accessibility"` — browser runs `get-accessibility-tree` and prepends the result
- omitted — uses only the `text` field as raw input, or just the prompt with no additional context

### MCP Tools

All new tools use the `mollotov_ai_` prefix.

#### Browser Tools (per-device)

| Tool | Description | Method |
|------|-------------|--------|
| `mollotov_ai_status` | Get the inference engine status on a device — whether a model is loaded, which model, capabilities, memory usage | `aiStatus` |
| `mollotov_ai_load` | Load a model on a device from a file path | `aiLoad` |
| `mollotov_ai_unload` | Unload the current model from a device, freeing memory | `aiUnload` |
| `mollotov_ai_ask` | Ask the local model a question about the current page. Specify a context mode to auto-gather page data. Returns the model's response. This is a cheap, local, private alternative to sending page data to a cloud LLM. | `aiInfer` |

#### CLI Tools (model management)

| Tool | Description | Kind |
|------|-------------|------|
| `mollotov_ai_models` | List all available models: approved registry, downloaded, and Ollama-detected. Ollama models appear with an `ollama:` prefix. | `discovery` |
| `mollotov_ai_pull` | Download a model from Hugging Face to the local model store | `discovery` |
| `mollotov_ai_remove` | Delete a downloaded model from the local store | `discovery` |

### CLI Commands

```
mollotov ai pull <model-id>       Download a model (from approved list or HF URL)
mollotov ai list                  List approved models and their download status
mollotov ai rm <model-id>         Delete a downloaded model
mollotov ai status [--device X]   Check what model is loaded on a device
mollotov ai load <model-id> [--device X]    Load model on device
mollotov ai unload [--device X]   Unload model from device
mollotov ai ask "<prompt>" [--device X] [--context page_text|screenshot|dom|accessibility]
                                  Run inference on the device's loaded model
```

The `pull` command:
1. Resolves model-id against the approved registry
2. If not found and it looks like a HF repo path (contains `/`), treats it as a custom HF GGUF
3. Downloads to `~/.mollotov/models/<model-id>/model.gguf` with progress bar
4. Writes `metadata.json` with source info

The `load` command:
1. Resolves model-id to local file path
2. Sends `POST /v1/ai-load { path: "..." }` to the target device

### Error Handling

The MCP tools should return clear, actionable errors:

| Error Code | Meaning | Action |
|---|---|---|
| `NO_MODEL_LOADED` | Inference requested but no model is loaded | Use `mollotov_ai_load` first |
| `MODEL_ALREADY_LOADED` | Load requested but a model is already active | Use `mollotov_ai_unload` first, or use the loaded model |
| `MODEL_NOT_FOUND` | The specified model file doesn't exist locally | Use `mollotov_ai_pull` to download it |
| `MODEL_TOO_LARGE` | Device doesn't have enough RAM for this model | Try a smaller quantization or different model |
| `INFERENCE_FAILED` | The model failed to generate a response | Check model compatibility, try a simpler prompt |
| `VISION_NOT_SUPPORTED` | Screenshot context requested but model has no vision capability | Use `page_text` context instead, or load a vision-capable model |
| `OLLAMA_NOT_AVAILABLE` | Ollama backend requested but the API is unreachable | Start Ollama or check the endpoint URL |
| `OLLAMA_MODEL_NOT_FOUND` | The specified Ollama model isn't installed | Run `ollama pull <model>` to install it |

---

## Implementation Tasks

### Task 1: Approved Model Registry (CLI)

**Files:**
- Create: `packages/cli/src/ai/models.ts`
- Test: `packages/cli/tests/ai/models.test.ts`

**Step 1: Write the failing test**

```ts
import { describe, it, expect } from "vitest";
import { getApprovedModels, findModel } from "../../src/ai/models.js";

describe("approved model registry", () => {
  it("returns a non-empty list of approved models", () => {
    const models = getApprovedModels();
    expect(models.length).toBeGreaterThan(0);
    expect(models[0]).toHaveProperty("id");
    expect(models[0]).toHaveProperty("huggingFaceRepo");
  });

  it("finds a model by id", () => {
    const model = findModel("gemma-4-e2b-q4");
    expect(model).toBeDefined();
    expect(model!.id).toBe("gemma-4-e2b-q4");
  });

  it("returns undefined for unknown model", () => {
    expect(findModel("nonexistent")).toBeUndefined();
  });
});
```

**Step 2: Run test to verify it fails**

Run: `cd packages/cli && pnpm test -- --run tests/ai/models.test.ts`
Expected: FAIL — module not found

**Step 3: Write minimal implementation**

`packages/cli/src/ai/models.ts`:
```ts
export interface ApprovedModel {
  id: string;
  name: string;
  huggingFaceRepo: string;
  huggingFaceFile: string;
  sizeBytes: number;
  capabilities: string[];
  platforms: string[];
  minRamGB: number;
  quantization: string;
  description: string;
}

const approvedModels: ApprovedModel[] = [
  {
    id: "gemma-4-e2b-q4",
    name: "Gemma 4 E2B Q4",
    huggingFaceRepo: "bartowski/gemma-4-E2B-it-GGUF",
    huggingFaceFile: "gemma-4-E2B-it-Q4_K_M.gguf",
    sizeBytes: 2_500_000_000,
    capabilities: ["text", "vision"],
    platforms: ["macos"],
    minRamGB: 8,
    quantization: "Q4_K_M",
    description: "Google Gemma 4 2B multimodal — text + vision, good for page analysis",
  },
  {
    id: "gemma-4-e2b-q8",
    name: "Gemma 4 E2B Q8",
    huggingFaceRepo: "bartowski/gemma-4-E2B-it-GGUF",
    huggingFaceFile: "gemma-4-E2B-it-Q8_0.gguf",
    sizeBytes: 5_000_000_000,
    capabilities: ["text", "vision"],
    platforms: ["macos"],
    minRamGB: 16,
    quantization: "Q8_0",
    description: "Google Gemma 4 2B multimodal — higher quality, needs 16GB RAM",
  },
];

export function getApprovedModels(): ApprovedModel[] {
  return approvedModels;
}

export function findModel(id: string): ApprovedModel | undefined {
  return approvedModels.find((m) => m.id === id);
}
```

**Step 4: Run test to verify it passes**

Run: `cd packages/cli && pnpm test -- --run tests/ai/models.test.ts`
Expected: PASS

**Step 5: Commit**

```bash
git add packages/cli/src/ai/models.ts packages/cli/tests/ai/models.test.ts
git commit -m "feat(cli): add approved model registry for local inference"
```

---

### Task 2: Model Store — Download & Manage (CLI)

**Files:**
- Create: `packages/cli/src/ai/store.ts`
- Test: `packages/cli/tests/ai/store.test.ts`

**Step 1: Write the failing test**

```ts
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { mkdtempSync, rmSync, existsSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { ModelStore } from "../../src/ai/store.js";

describe("ModelStore", () => {
  let dir: string;
  let store: ModelStore;

  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), "mollotov-models-"));
    store = new ModelStore(dir);
  });

  afterEach(() => {
    rmSync(dir, { recursive: true, force: true });
  });

  it("lists no models initially", () => {
    expect(store.listDownloaded()).toEqual([]);
  });

  it("reports model not downloaded", () => {
    expect(store.isDownloaded("gemma-4-e2b-q4")).toBe(false);
  });

  it("returns model path when registered", () => {
    store.register("gemma-4-e2b-q4", { name: "Gemma 4 E2B Q4", capabilities: ["text", "vision"] });
    expect(store.isDownloaded("gemma-4-e2b-q4")).toBe(true);
    expect(store.getModelPath("gemma-4-e2b-q4")).toContain("model.gguf");
  });

  it("removes a model", () => {
    store.register("gemma-4-e2b-q4", { name: "Gemma 4", capabilities: ["text"] });
    store.remove("gemma-4-e2b-q4");
    expect(store.isDownloaded("gemma-4-e2b-q4")).toBe(false);
  });
});
```

**Step 2: Run test to verify it fails**

Run: `cd packages/cli && pnpm test -- --run tests/ai/store.test.ts`
Expected: FAIL — module not found

**Step 3: Write minimal implementation**

`packages/cli/src/ai/store.ts` — manages `~/.mollotov/models/` directory, reads/writes `registry.json`, creates model subdirectories, returns file paths. Uses `node:fs` only.

Key methods:
- `listDownloaded(): DownloadedModel[]`
- `isDownloaded(id: string): boolean`
- `getModelPath(id: string): string | undefined`
- `getModelDir(id: string): string` — returns the directory for a model (creates if needed)
- `register(id: string, meta: ModelMeta): void` — marks model as downloaded, writes metadata.json
- `remove(id: string): void` — deletes model directory and registry entry

**Step 4: Run test to verify it passes**

Run: `cd packages/cli && pnpm test -- --run tests/ai/store.test.ts`
Expected: PASS

**Step 5: Commit**

```bash
git add packages/cli/src/ai/store.ts packages/cli/tests/ai/store.test.ts
git commit -m "feat(cli): add model store for managing downloaded GGUF files"
```

---

### Task 3: Hugging Face Download (CLI)

**Files:**
- Create: `packages/cli/src/ai/download.ts`
- Test: `packages/cli/tests/ai/download.test.ts`

**Step 1: Write the failing test**

```ts
import { describe, it, expect } from "vitest";
import { buildDownloadUrl, parseHuggingFaceUrl } from "../../src/ai/download.js";

describe("HuggingFace download", () => {
  it("builds a download URL from repo and file", () => {
    const url = buildDownloadUrl("bartowski/gemma-4-E2B-it-GGUF", "gemma-4-E2B-it-Q4_K_M.gguf");
    expect(url).toBe("https://huggingface.co/bartowski/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-E2B-it-Q4_K_M.gguf");
  });

  it("parses a full HF URL into repo and file", () => {
    const result = parseHuggingFaceUrl("https://huggingface.co/TheBloke/some-model-GGUF/resolve/main/model.Q4_K_M.gguf");
    expect(result).toEqual({ repo: "TheBloke/some-model-GGUF", file: "model.Q4_K_M.gguf" });
  });

  it("parses a repo/file shorthand", () => {
    const result = parseHuggingFaceUrl("TheBloke/some-model-GGUF/model.Q4_K_M.gguf");
    expect(result).toEqual({ repo: "TheBloke/some-model-GGUF", file: "model.Q4_K_M.gguf" });
  });
});
```

**Step 2: Run test to verify it fails**

Run: `cd packages/cli && pnpm test -- --run tests/ai/download.test.ts`
Expected: FAIL

**Step 3: Write minimal implementation**

`packages/cli/src/ai/download.ts`:
- `buildDownloadUrl(repo, file)` — constructs `https://huggingface.co/{repo}/resolve/main/{file}`
- `parseHuggingFaceUrl(input)` — handles full URLs and `owner/repo/file` shorthand
- `downloadModel(url, destPath, onProgress)` — streams the file to disk with progress callback, uses `node:https` or `fetch` with `ReadableStream` for progress tracking. Writes to a `.tmp` file and renames on completion (atomic write).

**Step 4: Run test to verify it passes**

Run: `cd packages/cli && pnpm test -- --run tests/ai/download.test.ts`
Expected: PASS

**Step 5: Commit**

```bash
git add packages/cli/src/ai/download.ts packages/cli/tests/ai/download.test.ts
git commit -m "feat(cli): add HuggingFace GGUF download support"
```

---

### Task 4: Ollama Detection & Proxy (CLI)

**Files:**
- Create: `packages/cli/src/ai/ollama.ts`
- Test: `packages/cli/tests/ai/ollama.test.ts`

**Step 1: Write the failing test**

```ts
import { describe, it, expect } from "vitest";
import { parseOllamaModelId, isOllamaModelId, buildOllamaGenerateRequest } from "../../src/ai/ollama.js";

describe("Ollama integration", () => {
  it("detects Ollama model IDs by prefix", () => {
    expect(isOllamaModelId("ollama:llama3.2:3b")).toBe(true);
    expect(isOllamaModelId("gemma-4-e2b-q4")).toBe(false);
  });

  it("extracts model name from prefixed ID", () => {
    expect(parseOllamaModelId("ollama:llava:7b")).toBe("llava:7b");
    expect(parseOllamaModelId("ollama:llama3.2:3b")).toBe("llama3.2:3b");
  });

  it("builds a generate request for text", () => {
    const req = buildOllamaGenerateRequest("llava:7b", "describe this", { maxTokens: 256 });
    expect(req.model).toBe("llava:7b");
    expect(req.prompt).toBe("describe this");
    expect(req.stream).toBe(false);
    expect(req.options.num_predict).toBe(256);
  });

  it("builds a generate request with image", () => {
    const req = buildOllamaGenerateRequest("llava:7b", "describe this", { image: "base64data" });
    expect(req.images).toEqual(["base64data"]);
  });
});
```

**Step 2: Run test to verify it fails**

Run: `cd packages/cli && pnpm test -- --run tests/ai/ollama.test.ts`
Expected: FAIL — module not found

**Step 3: Write minimal implementation**

`packages/cli/src/ai/ollama.ts`:

```ts
export const OLLAMA_PREFIX = "ollama:";
export const DEFAULT_OLLAMA_ENDPOINT = "http://localhost:11434";

export function isOllamaModelId(id: string): boolean {
  return id.startsWith(OLLAMA_PREFIX);
}

export function parseOllamaModelId(id: string): string {
  return id.slice(OLLAMA_PREFIX.length);
}

export interface OllamaModel {
  name: string;
  size: number;
  digest: string;
  modifiedAt: string;
}

export async function detectOllama(endpoint = DEFAULT_OLLAMA_ENDPOINT): Promise<boolean> {
  try {
    const res = await fetch(`${endpoint}/api/tags`, { signal: AbortSignal.timeout(2000) });
    return res.ok;
  } catch {
    return false;
  }
}

export async function listOllamaModels(endpoint = DEFAULT_OLLAMA_ENDPOINT): Promise<OllamaModel[]> {
  const res = await fetch(`${endpoint}/api/tags`, { signal: AbortSignal.timeout(5000) });
  if (!res.ok) return [];
  const data = (await res.json()) as { models: OllamaModel[] };
  return data.models ?? [];
}

export interface OllamaGenerateRequest {
  model: string;
  prompt: string;
  stream: false;
  images?: string[];
  options: { num_predict?: number; temperature?: number };
}

export function buildOllamaGenerateRequest(
  model: string,
  prompt: string,
  opts: { maxTokens?: number; temperature?: number; image?: string } = {},
): OllamaGenerateRequest {
  const req: OllamaGenerateRequest = {
    model,
    prompt,
    stream: false,
    options: {},
  };
  if (opts.maxTokens) req.options.num_predict = opts.maxTokens;
  if (opts.temperature) req.options.temperature = opts.temperature;
  if (opts.image) req.images = [opts.image];
  return req;
}

export async function ollamaGenerate(
  endpoint: string,
  request: OllamaGenerateRequest,
): Promise<{ response: string; totalDuration: number; evalCount: number }> {
  const res = await fetch(`${endpoint}/api/generate`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(request),
  });
  if (!res.ok) throw new Error(`Ollama error: ${res.status} ${res.statusText}`);
  const data = (await res.json()) as { response: string; total_duration: number; eval_count: number };
  return { response: data.response, totalDuration: data.total_duration, evalCount: data.eval_count };
}
```

**Step 4: Run test to verify it passes**

Run: `cd packages/cli && pnpm test -- --run tests/ai/ollama.test.ts`
Expected: PASS

**Step 5: Commit**

```bash
git add packages/cli/src/ai/ollama.ts packages/cli/tests/ai/ollama.test.ts
git commit -m "feat(cli): add Ollama detection, model listing, and inference proxy"
```

---

### Task 5: CLI `ai` Commands

**Files:**
- Create: `packages/cli/src/commands/ai.ts`
- Modify: `packages/cli/src/commands/index.ts` — add `registerAI(program)` import and call

**Step 1: Implement the CLI commands**

`packages/cli/src/commands/ai.ts`:
```ts
import type { Command } from "commander";

export function registerAI(program: Command): void {
  const ai = program.command("ai").description("Local AI model management and inference");

  ai.command("list")
    .description("List approved models, download status, and Ollama models if available")
    .action(async () => {
      // 1. Show native approved models with download status
      // 2. Probe Ollama at localhost:11434 — if reachable, list its models below a separator
      // 3. If Ollama not running, silently skip (no error)
    });

  ai.command("pull <model>")
    .description("Download a model from HuggingFace")
    .action(async (model: string) => { /* ... */ });

  ai.command("rm <model>")
    .description("Delete a downloaded model")
    .action(async (model: string) => { /* ... */ });

  ai.command("status")
    .description("Check inference status on a device")
    .option("-d, --device <device>", "Target device")
    .action(async (opts) => { /* ... */ });

  ai.command("load <model>")
    .description("Load a model on a device")
    .option("-d, --device <device>", "Target device")
    .action(async (model: string, opts) => { /* ... */ });

  ai.command("unload")
    .description("Unload model from a device")
    .option("-d, --device <device>", "Target device")
    .action(async (opts) => { /* ... */ });

  ai.command("ask <prompt>")
    .description("Run inference on the device's loaded model")
    .option("-d, --device <device>", "Target device")
    .option("-c, --context <mode>", "Context mode: page_text, screenshot, dom, accessibility")
    .option("--max-tokens <n>", "Max tokens", "512")
    .option("--temperature <t>", "Temperature", "0.7")
    .action(async (prompt: string, opts) => { /* ... */ });
}
```

**Step 2: Register in index.ts**

Add `import { registerAI } from "./ai.js";` and `registerAI(program);` in the AI section.

**Step 3: Build and verify**

Run: `cd packages/cli && pnpm build`
Expected: Compiles without errors

**Step 4: Commit**

```bash
git add packages/cli/src/commands/ai.ts packages/cli/src/commands/index.ts
git commit -m "feat(cli): add ai subcommands for model management and inference"
```

---

### Task 6: MCP Tool Definitions

**Files:**
- Modify: `packages/cli/src/mcp/tools.ts` — add AI browser tools and CLI tools
- Modify: `packages/shared/src/mcp-tools.ts` — add tool names to registries

**Step 1: Add browser tool definitions to `tools.ts`**

Add to the `browserTools` array:

```ts
// AI / Local Inference
{ name: "mollotov_ai_status", description: "Get the local inference engine status — whether a model is loaded, which model, its capabilities, and memory usage", method: "aiStatus", schema: { device }, bodyFromArgs: passthrough },
{ name: "mollotov_ai_load", description: "Load a GGUF model on a device for local inference. The model file must already be downloaded (use mollotov_ai_pull first). Only one model can be loaded at a time.", method: "aiLoad", schema: { device, path: z.string().describe("Absolute path to the GGUF model file") }, bodyFromArgs: passthrough },
{ name: "mollotov_ai_unload", description: "Unload the current model from a device, freeing memory", method: "aiUnload", schema: { device }, bodyFromArgs: passthrough },
{ name: "mollotov_ai_ask", description: "Ask the locally-loaded model a question about the current page. Use 'context' to auto-gather page data (page_text, screenshot, dom, accessibility) or provide 'text' directly. Returns the model's response. This runs entirely on-device — no data is sent to the cloud.", method: "aiInfer", schema: { device, prompt: z.string().describe("Question or instruction for the model"), context: z.enum(["page_text", "screenshot", "dom", "accessibility"]).optional().describe("Auto-gather page context before prompting"), text: z.string().optional().describe("Raw text input (alternative to context)"), maxTokens: z.number().optional().describe("Maximum tokens to generate (default 512)"), temperature: z.number().optional().describe("Sampling temperature (default 0.7)") }, bodyFromArgs: passthrough },
```

**Step 2: Add CLI tool definitions**

Add to the `cliTools` array:

```ts
// AI Model Management
{ name: "mollotov_ai_models", description: "List all approved models and their download status", method: "aiModels", kind: "discovery", schema: {}, bodyFromArgs: filterBody },
{ name: "mollotov_ai_pull", description: "Download a model from HuggingFace to the local model store. Accepts a model ID from the approved list or a HuggingFace repo path.", method: "aiPull", kind: "discovery", schema: { model: z.string().describe("Model ID or HuggingFace repo path (e.g. 'gemma-4-e2b-q4' or 'owner/repo/file.gguf')") }, bodyFromArgs: filterBody },
{ name: "mollotov_ai_remove", description: "Delete a downloaded model from the local store", method: "aiRemove", kind: "discovery", schema: { model: z.string().describe("Model ID to remove") }, bodyFromArgs: filterBody },
```

**Step 3: Update `packages/shared/src/mcp-tools.ts`**

Add to `BrowserMcpTools`:
```ts
"mollotov_ai_status",
"mollotov_ai_load",
"mollotov_ai_unload",
"mollotov_ai_ask",
```

Add to `CliMcpTools`:
```ts
"mollotov_ai_models",
"mollotov_ai_pull",
"mollotov_ai_remove",
```

Add to `httpToMcp`:
```ts
"ai-status": "mollotov_ai_status",
"ai-load": "mollotov_ai_load",
"ai-unload": "mollotov_ai_unload",
"ai-infer": "mollotov_ai_ask",
```

**Step 4: Add AI CLI tool handlers in `server.ts`**

The AI CLI tools (`mollotov_ai_models`, `mollotov_ai_pull`, `mollotov_ai_remove`) are `discovery` kind but need custom handling in `handleDiscovery()` — they don't scan for devices, they manage local model state. Add a new handler branch:

```ts
if (method === "aiModels") {
  const store = getModelStore();
  const approved = getApprovedModels();
  const downloaded = store.listDownloaded();
  return { content: [{ type: "text", text: JSON.stringify({ success: true, approved, downloaded }) }] };
}
```

**Step 5: Build and test**

Run: `cd packages/cli && pnpm build && pnpm test`
Expected: All pass

**Step 6: Commit**

```bash
git add packages/cli/src/mcp/tools.ts packages/shared/src/mcp-tools.ts packages/cli/src/mcp/server.ts
git commit -m "feat(mcp): add AI inference and model management tools"
```

---

### Task 7: macOS — llama.cpp Swift Package Integration

**Files:**
- Modify: `apps/macos/Mollotov.xcodeproj/project.pbxproj` — add llama.cpp SPM dependency
- Create: `apps/macos/Mollotov/AI/InferenceEngine.swift`

**Step 1: Add llama.cpp Swift Package**

Add the `ggerganov/llama.cpp` Swift package to the Xcode project via SPM. The package URL is `https://github.com/ggerganov/llama.cpp.git`. Pin to a stable release tag.

**Step 2: Implement InferenceEngine**

`apps/macos/Mollotov/AI/InferenceEngine.swift`:

```swift
import Foundation
import llama

@MainActor
class InferenceEngine: ObservableObject {
    @Published private(set) var isLoaded = false
    @Published private(set) var modelName: String?
    @Published private(set) var capabilities: [String] = []

    private var model: OpaquePointer?  // llama_model
    private var context: OpaquePointer?  // llama_context

    struct InferenceResult {
        let text: String
        let tokensUsed: Int
        let inferenceTimeMs: Int
    }

    func load(path: String, name: String, capabilities: [String]) throws {
        guard !isLoaded else {
            throw InferenceError.alreadyLoaded(current: modelName ?? "unknown")
        }
        // llama_model_load, llama_context_init
        // Set isLoaded, modelName, capabilities
    }

    func unload() {
        // llama_free, llama_model_free
        // Clear state
    }

    func infer(prompt: String, image: Data? = nil, maxTokens: Int = 512, temperature: Float = 0.7) throws -> InferenceResult {
        guard isLoaded else {
            throw InferenceError.noModelLoaded
        }
        // Tokenize prompt, sample, decode, collect output
    }

    var memoryUsageMB: Int {
        // Report approximate memory used by model + context
    }

    enum InferenceError: Error {
        case noModelLoaded
        case alreadyLoaded(current: String)
        case loadFailed(String)
        case inferenceFailed(String)
        case visionNotSupported
    }
}
```

**Step 3: Build and verify**

Build the macOS app in Xcode. Verify llama.cpp compiles and links.

**Step 4: Commit**

```bash
git add apps/macos/
git commit -m "feat(macos): integrate llama.cpp Swift package and InferenceEngine"
```

---

### Task 8: macOS — AIHandler HTTP Endpoints

**Files:**
- Create: `apps/macos/Mollotov/Handlers/AIHandler.swift`
- Modify: `apps/macos/Mollotov/Network/ServerState.swift` — register AI handlers

**Step 1: Implement AIHandler**

`apps/macos/Mollotov/Handlers/AIHandler.swift`:

```swift
import Foundation

struct AIHandler {
    static func register(on state: ServerState) {
        state.router.register("ai-status") { _ in
            // Return loaded state, model name, capabilities, memory
        }

        state.router.register("ai-load") { body in
            // If body has "path": load native GGUF via inferenceEngine.load()
            // If body has "ollama": set backend to ollama, store model name + endpoint
            //   Optionally verify Ollama is reachable before confirming
            // Return success or error
        }

        state.router.register("ai-unload") { _ in
            // Call inferenceEngine.unload()
        }

        state.router.register("ai-infer") { body in
            // Extract prompt, context mode, maxTokens, temperature
            // If context == "page_text": gather page text via existing handler
            // If context == "screenshot": take screenshot, encode as base64
            // Check backend mode:
            //   "native" → run llama.cpp inference
            //   "ollama" → forward to Ollama API endpoint
            // Return result in standard format
        }
    }
}
```

The `ai-infer` handler with `context` modes should reuse existing handler logic:
- `page_text`: call the same JS that `getPageText` uses, prepend to prompt
- `screenshot`: call `HandlerContext.takeSnapshot()`, pass image bytes to model
- `dom`: call the same JS that `getDOM` uses, prepend to prompt
- `accessibility`: call the same JS that `getAccessibilityTree` uses, prepend to prompt

**Step 2: Register in ServerState**

In `ServerState.registerHandlers()`, add `AIHandler.register(on: self)`.

**Step 3: Build and verify**

Build macOS app, verify new endpoints appear when calling `GET /health` or testing via curl.

**Step 4: Commit**

```bash
git add apps/macos/Mollotov/Handlers/AIHandler.swift apps/macos/Mollotov/Network/ServerState.swift
git commit -m "feat(macos): add AI HTTP endpoints for model loading and inference"
```

---

### Task 9: Integration Testing — End-to-End

**Files:**
- Create: `packages/cli/tests/ai/integration.test.ts`

**Step 1: Write integration tests**

Test the full CLI flow:
1. `mollotov ai list` — shows approved models, none downloaded
2. Model store operations — register, remove (unit-level but with real filesystem)
3. MCP tool schemas — verify all AI tools are registered with correct schemas

```ts
import { describe, it, expect } from "vitest";
import { getApprovedModels, findModel } from "../../src/ai/models.js";
import { buildDownloadUrl } from "../../src/ai/download.js";

describe("AI integration", () => {
  it("all approved models have valid HuggingFace URLs", () => {
    for (const model of getApprovedModels()) {
      const url = buildDownloadUrl(model.huggingFaceRepo, model.huggingFaceFile);
      expect(url).toMatch(/^https:\/\/huggingface\.co\//);
      expect(url).toMatch(/\.gguf$/);
    }
  });

  it("all approved models have required fields", () => {
    for (const model of getApprovedModels()) {
      expect(model.id).toBeTruthy();
      expect(model.capabilities.length).toBeGreaterThan(0);
      expect(model.platforms.length).toBeGreaterThan(0);
      expect(model.minRamGB).toBeGreaterThan(0);
    }
  });
});
```

**Step 2: Run tests**

Run: `cd packages/cli && pnpm build && pnpm test`
Expected: All pass

**Step 3: Commit**

```bash
git add packages/cli/tests/ai/integration.test.ts
git commit -m "test(cli): add AI model registry integration tests"
```

---

### Task 10: Documentation

**Files:**
- Modify: `docs/api/README.md` — add AI section link
- Create: `docs/api/ai.md` — full AI API reference
- Modify: `docs/cli.md` — add `ai` subcommands
- Modify: `docs/functionality.md` — add local inference feature

**Step 1: Write `docs/api/ai.md`**

Document all four HTTP endpoints (`ai-load`, `ai-unload`, `ai-status`, `ai-infer`) with request/response examples.

**Step 2: Update CLI docs**

Add the `ai` subcommand group to `docs/cli.md`.

**Step 3: Update functionality docs**

Add "Local AI Inference" feature to `docs/functionality.md`.

**Step 4: Commit**

```bash
git add docs/
git commit -m "docs: add local inference API reference, CLI commands, and feature description"
```

---

## Mobile Roadmap (Future Tasks — Not In This Plan)

### Mobile Ollama Proxy (Phase 2a — Fastest Path)

Mobile devices can use a remote Ollama instance over the local network. This requires no on-device model, no downloads, and no native ML framework integration — just HTTP calls.

**Settings UI (both iOS and Android):**
- New "AI" section in Settings
- "Ollama Endpoint" text field — user enters `http://192.168.1.50:11434` (their Mac's LAN IP)
- "Test Connection" button — calls `/api/tags`, shows green/red indicator
- "Model" picker — populated from the Ollama `/api/tags` response after successful connection
- Saved to UserDefaults (iOS) / SharedPreferences (Android)

**Implementation:**
- Mobile `AIHandler` only supports `backend: "ollama"` — no native inference
- `ai-load` stores the Ollama endpoint + model name
- `ai-infer` gathers context locally (screenshot, page text, DOM — these already work), then sends the prompt + data to the remote Ollama endpoint
- Same HTTP API surface as macOS, so the CLI and MCP tools work identically

**Advantage:** Ships fast, zero native ML dependencies, works with any model the user has in Ollama.

### iOS (Phase 2b — On-Device)

- Ship a curated model list embedded in the app (subset of approved models)
- Download models to `Documents/models/` with iOS progress UI
- Use `llama.cpp` compiled as a C library via SPM (same package, iOS target)
- Core ML conversion is optional — llama.cpp runs fine on Apple Silicon via Metal
- Implement the same native `AIHandler` backend as macOS
- Settings screen shows downloaded models and loaded status
- Add a note in settings: "Want a model added? Raise a PR on GitHub"

### Android (Phase 2b — On-Device)

- Ship a curated model list in the app resources
- Download to `files/models/` with Android DownloadManager
- Use `llama.cpp` via JNI (android.llm or llama.android bindings)
- Implement same native backend
- Settings screen mirrors iOS
- Same PR-based model addition process

### Platform Parity Note

Mobile inference is phased:
1. **Phase 2a (Ollama proxy)** is lightweight and ships alongside Phase 1 macOS work — just HTTP forwarding
2. **Phase 2b (on-device)** is deferred because it requires native ML framework integration, storage management, and download UI
3. The HTTP API surface is identical across all backends — native, Ollama local, Ollama remote — so CLI/MCP tools work without knowing which backend is active
