# Photo Editor — UI/UX Design

Why and scope: [DESIGN.md](DESIGN.md). Mockups live in [`uiux/`](uiux/). Width
is 60 cols throughout. Glyphs follow the `uiux` skill's `notation.md`.

## Screen map

```
      Launch
        │
        ▼
   ┌ Home ┐──tap recent────────────────┐
   │      │──Open Photo──▶ [PhotosPicker]──pick──┐
   │  ⚙ ──┼──▶ Settings ──Add AI Key──▶ Add Key (sheet)
   │  ⇲ ──┼──▶ Compress ──Choose──▶ [PhotosPicker, multi]
   └──────┘◀─────✕───────┐              ▼        ▼
                         └──────────── Editor ◀──┘
                                        │
             ┌────────────┬─────────────┼─────────────┬──────────┐
             ▼            ▼             ▼             ▼          ▼
        tool panels   Layers (sheet)  Save (sheet)  AI (sheet)  [share sheet]
        (in place)                                    │
                                                      └─no key─▶ Add Key (sheet)

   [brackets] = OS-owned surface
```

| Surface | Kind | File |
|---|---|---|
| Home | page (root) | [uiux/home.md](uiux/home.md) |
| Editor | full-screen page, dark | [uiux/editor.md](uiux/editor.md) |
| Tool panels (Adjust, Filters, Crop, Retouch, Reshape, Text, Stickers, Cutout) | in-place panel above the tool bar | [uiux/tools.md](uiux/tools.md) |
| AI (Magic Erase, Fill, Restyle) | in-place panel + run state | [uiux/ai.md](uiux/ai.md) |
| Layers | half sheet | [uiux/editor.md](uiux/editor.md#layers-sheet) |
| Save | half sheet | [uiux/editor.md](uiux/editor.md#save-sheet) |
| Beauty, Makeup, Reshape (v1.1) | in-place panels | [uiux/beauty.md](uiux/beauty.md) |
| Draw, Mosaic, Background, Frame, ID Photo | in-place panels | [uiux/creative.md](uiux/creative.md) |
| Home actions, Collage, Batch | page / pushed page | [uiux/collage-batch.md](uiux/collage-batch.md) |
| Settings | pushed page | [uiux/settings.md](uiux/settings.md) |
| Compress | pushed page | [uiux/compress.md](uiux/compress.md) |
| Add AI Key | half sheet | [uiux/settings.md](uiux/settings.md#add-ai-key-sheet) |
| Shared parts | — | [uiux/components.md](uiux/components.md) |

The Editor is its own page because it needs the whole screen. Everything else
that is a single decision is a sheet.

## Core flows

```
First edit
 Home ─Open Photo─▶ [PhotosPicker] ─pick─▶ ⟳ Opening… ─▶ Editor (Adjust open)
                          │                    │
                          └─cancel─▶ Home      └─fail─▶ Home + ⌐ Couldn't open photo ¬

Save
 Editor ─Save─▶ Save sheet ─Save to Photos─▶ ⟳ Exporting 62% ─▶ ⌐ Saved to Photos ¬
                    │                              │
                    ├─Share…─▶ [share sheet]       └─no add permission─▶ alert ─▶ [iOS Settings]
                    └─drag ▼─▶ Editor

Resume
 Home ─tap recent─▶ Editor with its full edit stack (every op still adjustable)

Generative AI
 Editor ─AI─▶ Magic Erase ─brush─▶ Run
                 │                  ├─ key ok ─▶ ⟳ Erasing… ─▶ result as layer
                 │                  ├─ no key ─▶ Add Key sheet ─save─▶ back to Run
                 │                  └─ error  ─▶ inline ⚠ + ( Try again )
                 └─ offline ─▶ Run disabled, "You're offline"

Leave
 Editor ─✕─▶ Home                        (no unsaved edits)
        └─✕─▶ "Discard changes?" ─┬─ Discard ─▶ Home (a never-saved new photo leaves Recent)
                                 ├─ Save… ─▶ Save sheet
                                 └─ Keep Editing
```

## Principles applied

- **Save is explicit.** Edits persist only on Save or Share; leaving with unsaved edits asks first.
- **The photo is the UI.** Chrome is dark and minimal. Panels never cover the canvas: the canvas shrinks.
- **Hold to compare.** Press and hold the canvas (or the Compare button) to show the original.
- **Degrade, never error** (`byo-ai-keys.md`). With no key, only the three generative
  tools ask for one. Everything else works.
- **Explanations behind ⓘ** (`mobile.md`) in Settings.

## Deviations from the `uiux` skill

- **Editor is always dark**, whatever the system appearance. A neutral dark
  surround doesn't skew how the photo's color and exposure are judged, and it's the editor convention.
- **Tool options sit in a bottom panel, not unfolded in place** (`mobile.md` picker rule).
  The Editor isn't a form: the options drive a canvas that must stay visible.
- Otherwise none.
