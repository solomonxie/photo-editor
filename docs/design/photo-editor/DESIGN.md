# Photo Editor — Design

UI: [UIUX_DESIGN.md](UIUX_DESIGN.md) · Build: [IMPLEMENT_PLAN.md](IMPLEMENT_PLAN.md)

## Problem

Meitu, Picsart and Lightroom Mobile put everyday tools (crop, adjust, filters,
text, background removal) behind subscriptions and accounts. People who just
want quick, good-looking edits on their iPhone pay monthly, or they put up
with watermarks and ads.

## Goals

- Every non-generative tool is free, offline and unlimited.
- Feels instant: a slider move shows up on screen within one frame, even at 120 Hz.
- Non-destructive: any edit can be changed later, and the original stays untouched.
- Exports at full resolution and keeps wide color (P3) / HDR when the source has it.
- Generative AI runs only on the user's own API key. There's no backend.
- Meitu-style touch-ups on-device: smooth skin, heal blemishes, red eye, face reshape
  (slim, eyes, nose, chin, forehead), and body reshape (waist, hips, chest, legs,
  shoulders, arms) guided by Vision landmarks, plus a manual push/grow/shrink brush.
- Save space: export at HD/2K/4K with a quality level and a live file-size estimate,
  and Compress library photos/videos into smaller HEIC/HEVC copies. Originals are
  deleted only on explicit confirm. This is the one feature that needs full Photos access.

## Non-goals (v1)

- Android, iPad-specific layout, Mac.
- Video editing, RAW / ProRAW development. (Video is only re-encoded by Compress.) (`CIRAWFilter` keeps adding them later cheap.)
- Accounts, cloud sync, social feed, template marketplace.
- Makeup, hair recolour, AI "beauty filters" that regenerate a face.
- Replacing the original in Photos. v1 always saves a copy.
- An in-app library browser. The system picker covers it.
- Our own AI backend or paid credits.

## Performance targets

| Metric | Target | Device floor |
|---|---|---|
| Slider → frame on screen | ≤ 8 ms render (120 Hz), never drop below 60 fps | iPhone 12 |
| Open 48 MP photo → first preview | ≤ 500 ms | iPhone 14 Pro |
| Filter thumbnail strip (20) | ≤ 300 ms total | iPhone 12 |
| Export 48 MP HEIC | ≤ 3 s | iPhone 14 Pro |
| Peak memory while editing 48 MP | ≤ 800 MB | iPhone 12 |
| Cutout (subject mask) | ≤ 1 s | iPhone 12 |

## Options considered

**App stack**

| Option | Verdict |
|---|---|
| Native Swift + SwiftUI + Core Image on Metal | **Chosen.** GPU filter graphs fused into one pass, direct Metal / Vision / Core ML access, zero bridge |
| Flutter (Impeller) | UI is fast, but the pipeline would still be a native plugin: two languages plus texture bridging |
| React Native / Expo | JS bridge. Image work ends up in native modules anyway, so it's the worst fit |
| Kotlin / Compose Multiplatform | Its value is Android, which is out of scope. iOS UI is less mature |
| Custom Metal engine, no Core Image | Most control, but rebuilds 200+ filters, color management and RAW. Only worth it for gaps |
| GPUImage3 | Little upside over Core Image, and slow maintenance |

**Canvas**

- SwiftUI `Image` from a `CGImage` per frame: a CPU round-trip on every slider tick. Rejected.
- `MTKView` drawing directly from `CIContext`: **chosen**.

**AI**

- On-device (Vision, Core Image, Metal): cutout / background removal, auto
  enhance, skin smoothing, red eye, face/body reshape. Free, private, offline,
  fast. **Chosen for everything it can do.**
- Cloud, bring-your-own key: **only for generative work**. That means Magic Erase,
  Fill (paint an area and describe it, e.g. "fuller hair") and Restyle.
  - Only vendors with image-edit APIs are listed: OpenAI, Google Gemini.
  - Anthropic is dropped from the vendor list: it has no image output, so a key could never work.
- Bundled Core ML super-resolution: +30–60 MB app size. Deferred (see open questions).

**Navigation**

- The current scaffold has 3 tabs: Library / AI Tools / Settings.
  - A standalone AI tab has no photo to act on.
  - A Library tab duplicates the system picker.
- **Decision:** no tab bar. Home (recent edits + Open Photo) → full-screen Editor.
  AI is a tool inside the Editor, and Settings is pushed from Home.

## Decision summary

- Swift 6, SwiftUI for the chrome, `MTKView` for the canvas.
- One shared Metal-backed `CIContext`.
- Custom GPU work is a `CIImageProcessorKernel` running a Metal compute shader
  compiled from source at runtime (the reshape warp).
  - This avoids the offline Metal toolchain, which isn't part of a default Xcode install.
- Skin smoothing uses Core Image's edge-preserving upsample instead of a custom bilateral kernel.
- The edit document is an ordered list of ops. Rendering = building a
  `CIImage` graph from it (lazy, fused).
- Screen-sized proxy while editing; full resolution only on export and thumbnails-on-demand.
- On-device AI by default. Cloud is only for generative tools, via the user's keys.

## Data & integrations

- **Project** = `Application Support/Projects/<uuid>/`
  - `original.<heic|jpg|png>`: a copy of the picked bytes, so the project
    survives the source being deleted from Photos.
  - `document.json`: the edit ops, layers, schema version.
  - `thumb.jpg`, plus `assets/` (AI results, cutout masks, imported sticker images).
- **Input:** `PhotosPicker`. It needs no library permission.
- **Output:** `PHPhotoLibrary` with `.addOnly` authorization → saves a new asset. Also the share sheet.
  - `NSPhotoLibraryUsageDescription` → `NSPhotoLibraryAddUsageDescription`.
- **AI keys:** Keychain, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, several keys, ordered.
  - The single legacy key (`ai.api.key`) moves into the list on first read.
- **AI calls:**
  - Sent: the image downscaled to the vendor's max (≈1536 px long edge), plus a mask
    PNG and the prompt. Only when the user taps Run.
  - Results are cached in the project, and the user's vendor account pays.
- **Network:** nothing else. No analytics, no crash SDK.

## Measured (iPhone 14, synthetic 48 MP HEIC)

| Metric | Result | Target |
|---|---|---|
| Open → preview | 89 ms | ≤ 500 ms |
| Slider frame (median) | 4.5 ms | ≤ 8 ms |
| Export 48 MP HEIC | 0.8 s | ≤ 3 s |
| Footprint after export | ~250 MB | ≤ 800 MB |

## Risks / open questions

- **48 MP memory.** A single RGBA16F buffer is ~384 MB.
  - Needs 8-bit proxies, tiled export, and `CIContext` cache limits.
  - Must be profiled early (Phase 1), not at the end.
- **Generative results come back lower-res than the source.** Composite only the
  masked region back and feather the edge. Otherwise quality visibly drops.
- **Vendor image APIs churn.** Keep the vendor list and model names as data, not code paths.
- **Open:** bundle a super-resolution model (bigger app) or skip "Enhance → Upscale" in v1?
- **Open:** a cap or auto-prune for project storage? The default is none, with usage shown in Settings.
- **App Store:** API keys count as "authentication info" → declare it in the privacy
  label, plus a privacy policy URL.
