# Photo Editor — Implementation Plan

Why: [DESIGN.md](DESIGN.md) · What it looks like: [UIUX_DESIGN.md](UIUX_DESIGN.md)

Target code layout (created as tasks land):

```
PhotoEditor/
├── App/            entry, root navigation
├── Engine/         EditDocument, ops, RenderEngine, runtime-compiled Metal warp
├── Canvas/         MTKView canvas, gestures
├── Projects/       ProjectStore, import, thumbnails
├── Features/       Home, Editor (+ Tools/<Tool>), Settings, AI
└── Services/       Keychain, AIKeyStore, AI vendor clients, PhotoSaver
PhotoEditorTests/
```

The anti-collision rule: T1.1 declares **every** op type up front. Each tool task
then only adds its own `Engine/Ops/<Op>.swift` renderer plus `Features/Editor/Tools/<Tool>/`,
so the Phase 3–5 tools never share a file.

## Phase 0: Foundation

Toolchain and navigation that everything else sits on. The tab bar goes now,
so later UI tasks don't build on a shape that's being removed.

- [x] T0.1 Toolchain — Swift 6 language mode, main-actor default isolation, gitignored `Config/Local.xcconfig` for the team, unit test target, swap `NSPhotoLibraryUsageDescription` for `NSPhotoLibraryAddUsageDescription` — see `project.yml`, `PhotoEditor/Info.plist` — depends: none
- [x] T0.2 App shell — remove the TabView and `AIToolsView`. `NavigationStack` Home → Editor (full-screen) / Settings (push). Stub screens only — see `PhotoEditor/App`, `PhotoEditor/ContentView.swift`, `PhotoEditor/Features`, [uiux map](UIUX_DESIGN.md#screen-map) — depends: none

## Phase 1: Engine core

Non-destructive model + GPU pipeline + persistence, with no UI. Every tool and
screen depends on these, and 48 MP memory risk has to be settled here, not later.

- [x] T1.1 Edit document & ops — Codable `EditDocument`: base adjustments, ordered ops, layers, schema version. **All** op cases declared (adjust, filter, crop, retouch, heal, text, sticker, cutout, aiResult) behind an `OpRenderer` protocol. Undo/redo as document snapshots — see [t1.1.md](t1.1.md) — depends: T0.1
- [x] T1.2 Render engine — one Metal-backed `CIContext`. Builds a `CIImage` graph from the document, with a screen-sized proxy and full-res tiled export. Pass-through renderers for unimplemented ops. Signposts for render time — see [t1.2.md](t1.2.md) — depends: T1.1
- [x] T1.3 Canvas view — `MTKView` in `UIViewRepresentable`, draws on demand (not a 60 fps loop). Pinch/pan/double-tap, hold-to-compare hook, P3/EDR drawable — see `PhotoEditor/Canvas`, `uiux/editor.md → Canvas behaviour` — depends: T1.2
- [x] T1.4 Project store — create from `PhotosPicker` data (copy the original bytes), load/save `document.json` debounced, thumbnail render, list, duplicate, delete, total size — see `PhotoEditor/Projects` — depends: T1.1
- [x] T1.5 48 MP benchmark — test fixture (48 MP HEIC). Measure open→preview, slider render, export, and peak memory against the [DESIGN targets](DESIGN.md#performance-targets). Record the results in the test log — see `PhotoEditorTests` — depends: T1.2, T1.4

## Phase 2: Editor shell & I/O

The first end-to-end loop: pick → edit → save → resume. Tools plug into this
frame, so it lands before any of them.

- [x] T2.1 Editor screen — `EditorModel` (document ↔ engine ↔ canvas, autosave, undo/redo), top bar, tool bar, `ToolPanel` host, canvas resize on panel open/close, render-error toast — see `PhotoEditor/Features/Editor`, `uiux/editor.md` — depends: T1.3, T1.4
- [x] T2.2 Shared components — `ToolPanel`, `ValueSlider` (haptic at 0, double-tap reset, one drag = one undo step), `ChipRow`, `ThumbStrip`, `Toast` — see `PhotoEditor/Features/Components`, `uiux/components.md` — depends: T0.2
- [x] T2.3 Home — recents grid (lazy thumbnails), Open Photo → PhotosPicker → project, empty/opening/error states, long-press menu, delete alert — see `PhotoEditor/Features/Home`, `uiux/home.md` — depends: T1.4, T2.2
- [x] T2.4 Save & export — Save sheet (format/size, auto-PNG on alpha), progress + cancel, `PHPhotoLibrary` add-only save, denied alert → Settings, share sheet, strip location unless kept — see `PhotoEditor/Services/PhotoSaver.swift`, `uiux/editor.md → Save sheet` — depends: T1.2, T2.2

## Phase 3: Core tools

The free, everyday toolset. Each task is independent (its own op renderer + its
own panel folder), so all six run in parallel.

- [x] T3.1 Adjust — 12 sliders plus Auto (`autoAdjustmentFilters`), chip-changed dots — see `Engine/Ops/Adjust.swift`, `Features/Editor/Tools/Adjust`, `uiux/tools.md → Adjust` — depends: T2.1, T2.2
- [x] T3.2 Filters — preset looks as `CIColorCube` LUTs (bundled `.cube`), intensity mix, live thumb strip ≤ 300 ms — see `Engine/Ops/Filter.swift`, `Features/Editor/Tools/Filters`, `uiux/tools.md → Filters` — depends: T2.1, T2.2
- [x] T3.3 Crop & rotate — crop-mode canvas overlay, aspect presets, straighten dial, rotate 90/flip, commit on leave — see `Engine/Ops/Crop.swift`, `Features/Editor/Tools/Crop`, `uiux/tools.md → Crop` — depends: T2.1, T2.2
- [x] T3.4 Layers system — layer compositing in the engine (transform, opacity, order), the `CanvasObject` selection/gestures, the Layers sheet — see `Engine/Ops/Layer.swift`, `Features/Editor/Layers`, `uiux/editor.md → Layers sheet` — depends: T2.1, T2.2
- [x] T3.5 Text — text layer rendered via Core Text → `CIImage`, fonts/colors/styles/align, inline editing — see `Engine/Ops/Text.swift`, `Features/Editor/Tools/Text`, `uiux/tools.md → Text` — depends: T3.4
- [x] T3.6 Stickers — emoji/shapes sheet with search, "From Photos" (uses Cutout when present) — see `Engine/Ops/Sticker.swift`, `Features/Editor/Tools/Stickers`, `uiux/tools.md → Stickers` — depends: T3.4

## Phase 4: On-device intelligence

Vision plus GPU work. It comes after Phase 3 because Cutout produces layers
that rely on the layer system. Custom GPU code is a Metal compute shader
compiled at runtime inside a `CIImageProcessorKernel`, because the offline Metal
toolchain isn't part of a default Xcode install.

- [x] T4.1 Cutout — `VNGenerateForegroundInstanceMaskRequest`, per-subject toggle, background keep/remove/blur/color, copy as sticker layer — see `Engine/Ops/Cutout.swift`, `Features/Editor/Tools/Cutout`, `uiux/tools.md → Cutout` — depends: T3.4
- [x] T4.2 Smooth skin — face mask from Vision landmarks (eyes, brows and lips cut out) × `CIEdgePreserveUpsampleFilter` over the face rect only — see `Engine/Ops/Retouch.swift`, `Features/Editor/Tools/Retouch` — depends: T2.1, T2.2
- [x] T4.3 Heal brush — tap or paint; strokes stored in the document, filled by normalized convolution (blur with the hole weighted out) — see `Engine/Ops/Heal.swift` — depends: T4.2
- [x] T4.4 Red eye — Core Image red-eye correction, detected on the image being rendered — see `Engine/Ops/Retouch.swift` — depends: T4.2
- [x] T4.5 Reshape — face (slim, chin, eyes, nose, forehead) from face landmarks, body (waist, hips, chest, legs, shoulders, arms) from `VNDetectHumanBodyPoseRequest`, manual push/grow/shrink brush; all summed into one displacement field and applied by a runtime-compiled Metal warp — see `Engine/Ops/Warp.swift`, `Engine/Ops/Reshape.swift`, `Features/Editor/Tools/Reshape` — depends: T2.1, T2.2

## Phase 5: Bring-your-own-key AI

Generative tools on top of the finished editor. It comes last because they're
the only networked, paid, optional part, and they reuse masks and layers.

- [x] T5.1 AI key store — ordered multi-key list in Keychain (`…ThisDeviceOnly`), vendor table as data (OpenAI, Gemini), request counts, last error, Sequential/Round Robin, legacy `ai.api.key` migration — see `PhotoEditor/Services/AIKeyStore.swift`, `KeychainStore.swift` — depends: T0.1
- [x] T5.2 Settings screen — AI KEYS (reorder, ⋯ delete, ⓘ popover), Add AI Key sheet (Save = live test, draft kept, input hygiene), Export defaults, Storage — see `PhotoEditor/Features/Settings`, `uiux/settings.md` — depends: T5.1, T1.4, T2.2
- [x] T5.3 AI clients — `OpenAIImageClient`, `GeminiImageClient` behind one protocol (edit with image + mask + prompt), downscale to vendor max, fallback runner, vendor errors kept verbatim, cancel — see `PhotoEditor/Services/AI` — depends: T5.1
- [x] T5.4 AI tool — Magic Erase (brush mask), Fill (brush mask + prompt, e.g. "fuller hair") and Restyle (prompt + presets), no-key/offline/running/error states, result stored as a patch asset and composited full-res into the feathered mask — see `Engine/Ops/AIResult.swift`, `Features/Editor/Tools/AI`, `uiux/ai.md` — depends: T5.3, T3.4

## Phase 6: Ship readiness

Verification against the targets and the App Store requirements, done once the
feature set is frozen.

- [ ] T6.1 Performance pass (in-progress: iPhone 14 benchmark passes all targets; older devices not tested) — re-run T1.5 on all tools stacked. Instruments (Metal System Trace, Allocations) on the devices at hand, and fix regressions — see `PhotoEditorTests` — depends: T3.1–T3.6, T4.1–T4.5, T5.4
- [ ] T6.2 Accessibility (in-progress: labels and adjustable sliders done; full VoiceOver walk pending) — VoiceOver labels on icon buttons, adjustable-action sliders, Dynamic Type in the chrome, Reduce Motion — see `PhotoEditor/Features` — depends: T3.1–T3.6, T4.1–T4.5, T5.4
- [ ] T6.3 Privacy & store — `PrivacyInfo.xcprivacy`, privacy policy page, App Store privacy label (auth info), README update — see `PhotoEditor`, `README.md` — depends: T5.4
