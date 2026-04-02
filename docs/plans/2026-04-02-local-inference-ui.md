# Local Inference — UI Design

Companion to [2026-04-02-local-inference.md](2026-04-02-local-inference.md). This document covers the visual interface for AI model management across all platforms.

---

## Prerequisite: Hardware Info

`DeviceInfo` currently lacks RAM, CPU, and disk space. All platforms must add:

```
system:
  totalMemoryMB: 16384          # Total physical RAM
  availableMemoryMB: 9200       # RAM currently free
  diskFreeGB: 87.3              # Free storage on the data volume
  chipset: "Apple M2"           # CPU/chip name (best-effort)
```

**How to read on each platform:**

| Field | macOS | iOS | Android |
|---|---|---|---|
| totalMemoryMB | `ProcessInfo.processInfo.physicalMemory` | `ProcessInfo.processInfo.physicalMemory` | `ActivityManager.MemoryInfo.totalMem` |
| availableMemoryMB | `ProcessInfo` + `host_statistics64` | `os_proc_available_memory()` | `ActivityManager.MemoryInfo.availMem` |
| diskFreeGB | `FileManager.attributesOfFileSystem` | `FileManager.attributesOfFileSystem` | `StatFs(dataDir)` |
| chipset | `sysctl("machdep.cpu.brand_string")` | Model identifier lookup table | `Build.SOC_MODEL` (API 31+) or `/proc/cpuinfo` |

Linux and Windows already report memory. Add `diskFreeGB` and `chipset` to them too.

---

## Icons

### Font Awesome Solid (all platforms)

**Font file:** `FontAwesome6Free-Solid-900.otf` (bundled in each app's resources)

| Icon | Codepoint | Usage |
|---|---|---|
| `fa-eye` | U+F06E | Vision-capable model |
| `fa-eye-slash` | U+F070 | Text-only model |
| `fa-cloud-arrow-down` | U+F0ED | Download available |
| `fa-circle-check` | U+F058 | Downloaded / ready |
| `fa-spinner` | U+F110 | Downloading (animated rotation) |
| `fa-trash-can` | U+F2ED | Delete model |
| `fa-brain` | U+F5DC | AI status pill in URL bar |
| `fa-circle-exclamation` | U+F06A | Warning (model too large for device) |
| `fa-server` | U+F233 | Ollama backend indicator |

### Platform integration

- **macOS:** Extend `FontAwesome.swift` — add Solid font alongside existing Brands font. Register both in `registerFonts()`. Add icon constants to the enum.
- **iOS:** Bundle `FontAwesome6Free-Solid-900.otf`, register via `Info.plist` `UIAppFonts`. Create `FontAwesome.swift` mirroring macOS pattern.
- **Android:** Bundle the `.otf` in `assets/fonts/`. Load via `FontFamily(Font(R.font.fontawesome6_free_solid_900))` in Compose.

---

## Model Card Design

Every model in the list is rendered as a card. The card adapts to the model's state and the device's hardware.

### Card anatomy

```
┌──────────────────────────────────────────────────┐
│                                                  │
│  [eye]  Gemma 4 E2B                        Q4   │
│                                                  │
│  Multimodal model by Google. Understands text    │
│  and images — can describe screenshots, read     │
│  page layouts, and extract visual information.   │
│  Good balance of speed and quality.              │
│                                                  │
│  2.5 GB download  •  ~3.8 GB RAM when loaded     │
│                                                  │
│  ┌──────────────────────────────────────────┐    │
│  │  [cloud-arrow-down]  Download            │    │
│  └──────────────────────────────────────────┘    │
│                                                  │
└──────────────────────────────────────────────────┘
```

### Card states

**Available — not downloaded:**

```
┌──────────────────────────────────────────────────┐
│  [eye]  Gemma 4 E2B                        Q4   │
│                                                  │
│  Multimodal model by Google. Understands text    │
│  and images — can describe screenshots, read     │
│  page layouts, and extract visual information.   │
│                                                  │
│  2.5 GB download  •  ~3.8 GB RAM when loaded     │
│                                                  │
│  [cloud-arrow-down]  Download                    │
└──────────────────────────────────────────────────┘
```

**Downloading:**

```
┌──────────────────────────────────────────────────┐
│  [eye]  Gemma 4 E2B                        Q4   │
│                                                  │
│  Multimodal model by Google. Understands text    │
│  and images — ...                                │
│                                                  │
│  ████████████░░░░░░░░░░░░  1.2 / 2.5 GB  48%    │
│                                                  │
│  [cancel]  Cancel                                │
└──────────────────────────────────────────────────┘
```

**Downloaded — not loaded:**

```
┌──────────────────────────────────────────────────┐
│  [eye]  Gemma 4 E2B                  Q4  [check] │
│                                                  │
│  Multimodal model by Google. Understands text    │
│  and images — ...                                │
│                                                  │
│  2.5 GB on disk  •  ~3.8 GB RAM when loaded      │
│                                                  │
│  [▶ Load]                          [trash] Delete│
└──────────────────────────────────────────────────┘
```

**Loaded — active:**

```
┌──────────────────────────────────────────────────┐
│  [eye]  Gemma 4 E2B              Q4  ● Active    │
│                                                  │
│  Multimodal model by Google. Understands text    │
│  and images — ...                                │
│                                                  │
│  Using 3.8 GB RAM                                │
│                                                  │
│  [⏹ Unload]                                      │
└──────────────────────────────────────────────────┘
```

**Warning — insufficient resources:**

```
┌──────────────────────────────────────────────────┐
│  [eye]  Gemma 4 E2B Q8                     Q8   │
│                                                  │
│  Higher quality variant. Needs 16 GB RAM.        │
│                                                  │
│  5.0 GB download  •  ~8 GB RAM when loaded       │
│                                                  │
│  [!] Not recommended for this device             │
│      Requires ~8 GB free RAM — you have 4.2 GB   │
│                                                  │
│  [cloud-arrow-down]  Download anyway             │
└──────────────────────────────────────────────────┘
```

**Insufficient storage:**

```
│  [!] Not enough storage                          │
│      Needs 5.0 GB — you have 2.1 GB free         │
│                                                  │
│  [cloud-arrow-down greyed]  Download  (disabled) │
```

---

## Hardware Evaluation Logic

### Model fitness scoring

Each model declares its requirements. The device reports its capabilities. The UI evaluates fitness at display time.

```ts
interface ModelRequirements {
  downloadSizeGB: number;          // Disk needed for download
  ramWhenLoadedGB: number;         // RAM consumed when model is active
  minRamGB: number;                // Minimum total device RAM
  recommendedRamGB: number;        // Comfortable total device RAM
  supportsMetalGPU?: boolean;      // Needs Metal (Apple) or Vulkan (Android)
}

interface DeviceCapabilities {
  totalRamGB: number;
  availableRamGB: number;
  diskFreeGB: number;
  chipset: string;
  platform: "macos" | "ios" | "android" | "linux" | "windows";
}
```

### Fitness levels

| Level | Condition | UI Treatment |
|---|---|---|
| **recommended** | `totalRam >= recommendedRam` AND `diskFree >= downloadSize * 1.2` | Normal card, download button prominent |
| **possible** | `totalRam >= minRam` AND `diskFree >= downloadSize` | Card shown with amber note: "May run slowly on this device" |
| **not-recommended** | `totalRam < minRam` | Card shown with warning: "Not recommended — requires X GB RAM, you have Y GB". Download button says "Download anyway" |
| **no-storage** | `diskFree < downloadSize` | Card greyed, download disabled: "Not enough storage — needs X GB, you have Y GB free" |

### Ollama models

Ollama models running on the same Mac need no fitness check — Ollama manages its own memory. Ollama models accessed remotely from mobile don't consume device resources at all. Show them with a `[server]` badge and no resource warnings.

### Platform AI models (Apple Intelligence / Gemini Nano)

No resource check needed — the OS manages these. Show them with an "On-device" badge. If the device doesn't support them (too old, wrong chip), show: "Requires [A17 Pro / Pixel 8+] — not available on this device" and disable.

### Sorting

Models are sorted within each section by fitness, then by size:

1. Recommended models, smallest first
2. Possible models, smallest first
3. Not-recommended models (shown at bottom, dimmed)

---

## Model Descriptions

Every model in the approved registry needs a human-readable description written for users who don't know what an LLM is. No jargon. Focus on what it can do, not how it works.

### Required description fields

```ts
interface ModelDescription {
  summary: string;            // 1 sentence: what does this model do?
  strengths: string[];        // 2-3 bullet points: what it's good at
  limitations: string[];      // 1-2 bullet points: what it can't do
  bestFor: string;            // "Best for: ___" one-liner
  speedRating: "fast" | "moderate" | "slow";  // Relative to other models in the list
}
```

### Example descriptions

**Gemma 4 E2B Q4:**
```
summary: "Understands text and images — can describe screenshots, read page layouts, and extract visual information."
strengths:
  - "Describe what's on a webpage from a screenshot"
  - "Summarise articles and extract key information"
  - "Answer questions about page content and structure"
limitations:
  - "Slower than text-only models when processing images"
  - "May struggle with very long pages (over 10,000 words)"
bestFor: "General page analysis with visual understanding"
speedRating: "moderate"
```

**Gemma 4 E2B Q8:**
```
summary: "Higher quality version of Gemma 4 — more accurate but needs more memory."
strengths:
  - "More accurate responses than Q4, especially for nuanced questions"
  - "Better at understanding complex page layouts"
  - "Same vision and text capabilities as Q4"
limitations:
  - "Needs 16 GB RAM — won't run comfortably on 8 GB machines"
  - "Slightly slower than Q4 due to larger model size"
bestFor: "When accuracy matters more than speed"
speedRating: "moderate"
```

**Ollama model (generic, auto-generated from Ollama metadata):**
```
summary: "Installed via Ollama. Managed externally — Mollotov can use it but doesn't download or delete it."
strengths: [derived from model capabilities if known]
limitations: ["Requires Ollama to be running"]
bestFor: "Use your existing Ollama models without re-downloading"
speedRating: [not shown — varies by model]
```

**Apple Intelligence:**
```
summary: "Apple's built-in on-device model. Fast and private — runs entirely on your device's neural engine."
strengths:
  - "Instant startup — no download needed"
  - "Very fast inference using the Neural Engine"
  - "Zero memory overhead — managed by the OS"
limitations:
  - "Text only — cannot analyse screenshots or images"
  - "Cannot be customised or replaced"
bestFor: "Quick text summaries when you don't need vision"
speedRating: "fast"
```

---

## CLI Output

### `mollotov ai list`

```
AI Models

  Recommended for this device (Apple M2, 16 GB RAM, 87 GB free)

  NATIVE
  ────────────────────────────────────────────────────────────
  👁  gemma-4-e2b-q4      2.5 GB    ~3.8 GB RAM    ✓ downloaded
     Understands text and images — page analysis with visual understanding
     [moderate speed]

  👁  gemma-4-e2b-q8      5.0 GB    ~8 GB RAM      not downloaded
     Higher quality Gemma 4 — more accurate but needs more memory
     [moderate speed]

  OLLAMA (localhost:11434 ● online)
  ────────────────────────────────────────────────────────────
  👁  ollama:llava:7b      4.7 GB    managed by Ollama
     Vision model — can describe images and screenshots

  ⊘  ollama:llama3.2:3b   2.0 GB    managed by Ollama
     Text-only general purpose model

  ⊘  ollama:gemma2:2b     1.6 GB    managed by Ollama
     Text-only, lightweight and fast

  PLATFORM
  ────────────────────────────────────────────────────────────
  ⊘  platform:apple       on-device  managed by OS
     Apple Intelligence — fast text summaries, no vision
```

### `mollotov ai list` on a constrained device (8 GB)

```
  AI Models

  Device: MacBook Air M1, 8 GB RAM, 34 GB free

  NATIVE
  ────────────────────────────────────────────────────────────
  👁  gemma-4-e2b-q4      2.5 GB    ~3.8 GB RAM    not downloaded
     Understands text and images — page analysis with visual understanding
     ⚠ May run slowly — leaves only ~4.2 GB for other apps

  👁  gemma-4-e2b-q8      5.0 GB    ~8 GB RAM      not downloaded
     Higher quality Gemma 4 — more accurate but needs more memory
     ✗ Not recommended — needs ~8 GB RAM, you have 8 GB total
```

### `mollotov ai status --device mac`

```
  Device: Mac Studio (Apple M2 Ultra, 64 GB RAM)
  Model:  gemma-4-e2b-q4 (native)
  Status: ● Loaded
  Vision: 👁 yes
  RAM:    3.8 GB used
  Uptime: 12m 34s
```

---

## macOS Settings — AI Section

New "AI" section added to `SettingsView` between "Renderer" and "Network":

```
┌──────────────────────────────────────────────────────────────┐
│  Settings                                         [Done]     │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Device                                                      │
│  Name         Mac Studio                                     │
│  Model        Mac14,13                                       │
│  ...                                                         │
│                                                              │
│  Renderer                                                    │
│  Active       WebKit                                         │
│  Available    webkit, chromium                                │
│                                                              │
│  AI                                                          │
│  ┌──────────────────────────────────────────────────────────┐│
│  │  Active Model    None                              [▾]   ││
│  │                                                          ││
│  │  Device: Apple M2, 16 GB RAM, 87 GB free                ││
│  └──────────────────────────────────────────────────────────┘│
│                                                              │
│  When the model picker [▾] is expanded:                      │
│                                                              │
│  ┌──────────────────────────────────────────────────────────┐│
│  │  ○  None (AI disabled)                                   ││
│  │  ──── Native ────────────────────────────────────────    ││
│  │  ┌────────────────────────────────────────────────────┐  ││
│  │  │  👁 Gemma 4 E2B Q4                    [✓ Ready]    │  ││
│  │  │  Text + Vision • 3.8 GB RAM • moderate speed      │  ││
│  │  │  Understands text and images — page analysis      │  ││
│  │  │  with visual understanding                        │  ││
│  │  └────────────────────────────────────────────────────┘  ││
│  │  ┌────────────────────────────────────────────────────┐  ││
│  │  │  👁 Gemma 4 E2B Q8                  [↓ Download]   │  ││
│  │  │  Text + Vision • 8 GB RAM • moderate speed        │  ││
│  │  │  Higher quality — more accurate, needs more RAM   │  ││
│  │  └────────────────────────────────────────────────────┘  ││
│  │  ──── Ollama (● online) ─────────────────────────────    ││
│  │  ┌────────────────────────────────────────────────────┐  ││
│  │  │  👁 llava:7b                          [Ready]      │  ││
│  │  │  Text + Vision • managed by Ollama                │  ││
│  │  └────────────────────────────────────────────────────┘  ││
│  │  ┌────────────────────────────────────────────────────┐  ││
│  │  │  ⊘ llama3.2:3b                       [Ready]      │  ││
│  │  │  Text only • managed by Ollama                    │  ││
│  │  └────────────────────────────────────────────────────┘  ││
│  │  ──── On-Device ─────────────────────────────────────    ││
│  │  ┌────────────────────────────────────────────────────┐  ││
│  │  │  ⊘ Apple Intelligence                 [Ready]      │  ││
│  │  │  Text only • instant • managed by OS              │  ││
│  │  └────────────────────────────────────────────────────┘  ││
│  └──────────────────────────────────────────────────────────┘│
│                                                              │
│  Ollama Endpoint                                             │
│  http://localhost:11434                      [Test] ● Online │
│                                                              │
│  Models run locally. No data leaves your device.             │
│                                                              │
│  Network                                                     │
│  ...                                                         │
└──────────────────────────────────────────────────────────────┘
```

### Download flow within Settings

When user clicks [↓ Download] on a model card:

1. Button changes to a progress bar with cancel option
2. Progress shows bytes downloaded / total and percentage
3. On completion, button changes to [✓ Ready]
4. If error, shows brief error message with retry button

### Model loading flow

When user selects a downloaded model from the picker:

1. If another model is loaded, auto-unload it first
2. Show loading spinner on the card: "Loading model..."
3. On success, card shows ● Active with RAM usage
4. If load fails (e.g. not enough RAM), show error with suggestion

---

## iOS / Android Settings — AI Section

Same structure as macOS, adapted to mobile list-based settings.

### iOS

```
┌──────────────────────────────────────────────────┐
│  Settings                              [Done]     │
├──────────────────────────────────────────────────┤
│                                                  │
│  AI                                              │
│  ──────────────────────────────────────────────  │
│  Active Model              None               >  │
│  Ollama Endpoint           Not configured     >  │
│                                                  │
│  Device: iPhone 15 Pro, 8 GB RAM, 34 GB free     │
│  ──────────────────────────────────────────────  │
│                                                  │
│  Tapping "Active Model" pushes to model list:    │
│                                                  │
│  ┌──────────────────────────────────────────────┐│
│  │  AI Models                          [Back]   ││
│  │                                              ││
│  │  NATIVE                                      ││
│  │  ┌──────────────────────────────────────────┐││
│  │  │ 👁  Gemma 4 E2B Q4              2.5 GB  │││
│  │  │ Text + Vision                           │││
│  │  │ Understands text and images — page      │││
│  │  │ analysis with visual understanding      │││
│  │  │                                         │││
│  │  │ ⚠ May run slowly on this device         │││
│  │  │ Needs ~3.8 GB RAM                       │││
│  │  │                                         │││
│  │  │         [↓ Download]                    │││
│  │  └──────────────────────────────────────────┘││
│  │                                              ││
│  │  OLLAMA (remote)                             ││
│  │  ┌──────────────────────────────────────────┐││
│  │  │ 👁  llava:7b                             │││
│  │  │ Text + Vision • runs on your Mac         │││
│  │  │                          [Select]        │││
│  │  └──────────────────────────────────────────┘││
│  │                                              ││
│  │  ON-DEVICE                                   ││
│  │  ┌──────────────────────────────────────────┐││
│  │  │ ⊘  Apple Intelligence                    │││
│  │  │ Text only • instant • no download        │││
│  │  │                          [Select]        │││
│  │  └──────────────────────────────────────────┘││
│  │                                              ││
│  │  Want a model added to the list?             ││
│  │  Open a PR on GitHub                      >  ││
│  └──────────────────────────────────────────────┘│
│                                                  │
│  Tapping "Ollama Endpoint" pushes to config:     │
│                                                  │
│  ┌──────────────────────────────────────────────┐│
│  │  Ollama Endpoint                    [Back]   ││
│  │                                              ││
│  │  Server URL                                  ││
│  │  ┌──────────────────────────────────────────┐││
│  │  │ http://192.168.1.50:11434                │││
│  │  └──────────────────────────────────────────┘││
│  │                                              ││
│  │  [Test Connection]              ● Connected  ││
│  │                                              ││
│  │  Found 3 models on this server               ││
│  │                                              ││
│  │  Your Mac runs the model. This device sends  ││
│  │  page data to it over your local network.    ││
│  │  Nothing leaves your network.                ││
│  └──────────────────────────────────────────────┘│
└──────────────────────────────────────────────────┘
```

### Android

Identical structure to iOS, using Material 3 components:
- `ListItem` with `leadingContent` for icons, `trailingContent` for status
- `LinearProgressIndicator` for download progress
- `OutlinedTextField` for Ollama endpoint
- Same card layout with Material3 `Card` composable

---

## URL Bar AI Status Pill

The AI pill lives in the URL bar on every platform. It's always visible when a model is loaded — this is a first-class feature, not buried in settings.

### iOS

The URL bar is `< > [URL field]`. The pill sits to the right of the URL field as a 34x34 tappable circle (matching nav button size). When no model is loaded, the pill isn't shown and the URL field stretches to fill.

```
No model:
┌──────────────────────────────────────────────────┐
│  <  >  [  https://example.com                  ] │
└──────────────────────────────────────────────────┘

Vision model loaded:
┌──────────────────────────────────────────────────┐
│  <  >  [  https://example.com          ]  (🧠👁) │
└──────────────────────────────────────────────────┘

Text-only model loaded:
┌──────────────────────────────────────────────────┐
│  <  >  [  https://example.com          ]  (🧠⊘) │
└──────────────────────────────────────────────────┘
```

The pill is a circle with `fa-brain` as the main icon. A tiny 10px badge in the bottom-right corner shows `fa-eye` (vision) or `fa-eye-slash` (text-only). Background is a subtle tinted fill (e.g. `systemGray5` with accent overlay when active).

**Tapping the pill** shows a popover sheet:

```
┌────────────────────────────────────┐
│                                    │
│  🧠  Gemma 4 E2B Q4               │
│                                    │
│  👁  Text + Vision                 │
│  3.8 GB RAM  •  native             │
│  Speed: moderate                   │
│                                    │
│  ┌──────────┐   ┌──────────────┐   │
│  │  Unload  │   │  AI Settings │   │
│  └──────────┘   └──────────────┘   │
│                                    │
└────────────────────────────────────┘
```

"AI Settings" navigates to the full model list (same as Settings > AI > Active Model).

**When no model is loaded** — the pill spot is empty. But to make AI discoverable, add a subtle ghost pill on first launch (or until the user has configured AI):

```
┌──────────────────────────────────────────────────┐
│  <  >  [  https://example.com          ]  (🧠?)  │
└──────────────────────────────────────────────────┘
```

Tapping the ghost pill opens the AI models screen directly. After the user either loads a model or explicitly dismisses, the ghost pill disappears permanently (stored in `UserDefaults`).

### macOS

The pill sits between the address field and the selectors row. It's a capsule shape showing the brain icon + model name.

```
Wide window:
← → ↻ [ https://example.com ] [🧠 👁 Gemma 4 Q4] [iPhone 15 ▾] [⬜▬] [Safari Chrome] [−100%+]

Narrow window (selectors on second row):
← → ↻ [ https://example.com ] [🧠 👁 Gemma 4 Q4]
       [iPhone 15 ▾] [⬜▬] [Safari Chrome] [−100%+]

No model:
← → ↻ [ https://example.com ] [iPhone 15 ▾] [⬜▬] [Safari Chrome] [−100%+]
```

The macOS pill has room to show the model name inline. Clicking it shows a popover with model info and an Unload button, same content as iOS.

When no model is loaded, the pill is hidden. No ghost pill on macOS — the Settings panel is discoverable enough.

### Android

Same layout as iOS — pill to the right of the URL field, same 34dp tappable circle, same popover behavior.

### Pill Implementation (all platforms)

The pill component needs:

```swift
// iOS/macOS
struct AIStatusPill: View {
    @ObservedObject var aiState: AIState  // Published: isLoaded, modelName, hasVision, backend, ramUsageMB

    var body: some View {
        // If no model loaded: hidden (or ghost on iOS first-launch)
        // If loaded: 34pt circle with fa-brain, vision badge
        // Tap -> popover
    }
}
```

```kotlin
// Android
@Composable
fun AIStatusPill(aiState: AIState, onTap: () -> Unit)
```

The `AIState` observable is shared with the AIHandler — it updates when models are loaded/unloaded.

---

## Download Progress — Implementation Notes

### Progress tracking

Downloads are managed by the CLI (macOS) or the app directly (mobile). Progress is reported as:

```json
{
  "modelId": "gemma-4-e2b-q4",
  "state": "downloading",        // "pending" | "downloading" | "complete" | "failed" | "cancelled"
  "bytesDownloaded": 1258291200,
  "bytesTotal": 2500000000,
  "bytesPerSecond": 45000000,
  "etaSeconds": 28
}
```

### macOS: CLI downloads, browser shows progress

The CLI manages the download to `~/.mollotov/models/`. When the Settings UI triggers a download:

1. Settings sends `POST /v1/ai-pull { model: "gemma-4-e2b-q4" }` (new endpoint)
2. The macOS app delegates to a `ModelDownloader` actor
3. `ModelDownloader` streams from HuggingFace using `URLSession`, reports progress
4. Settings UI polls or observes the `ModelDownloader` `@Published` state

### Mobile: App downloads directly

On iOS/Android, the app downloads models directly:
- iOS: `URLSession` background download task (survives app backgrounding)
- Android: `DownloadManager` system service (shows in notification bar)

Both write to the app's local model directory and update the local registry.

---

## Summary of New Files Needed

| Platform | File | Purpose |
|---|---|---|
| All | `FontAwesome6Free-Solid-900.otf` | Font file bundled in resources |
| macOS | `Mollotov/Views/AISettingsView.swift` | AI section in settings |
| macOS | `Mollotov/AI/ModelDownloader.swift` | HuggingFace download with progress |
| macOS | `Mollotov/AI/ModelRegistry.swift` | Approved models, fitness scoring, Ollama detection |
| iOS | `Mollotov/Views/AISettingsView.swift` | AI model list and Ollama config |
| iOS | `Mollotov/AI/ModelDownloader.swift` | Background download support |
| iOS | `Mollotov/AI/ModelRegistry.swift` | Curated model list + fitness |
| Android | `ui/AISettingsScreen.kt` | AI model list and Ollama config |
| Android | `ai/ModelDownloader.kt` | DownloadManager integration |
| Android | `ai/ModelRegistry.kt` | Curated model list + fitness |
| CLI | `src/ai/fitness.ts` | Hardware evaluation logic |
