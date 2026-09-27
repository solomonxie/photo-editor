# Tool panels

Each panel replaces the area between the canvas and the tool bar. Everything
here is on-device and free. The panel frame comes from `components.md → ToolPanel`.

## Adjust

```
 Exposure                                             +24
 ├───────────────────────────────●─────────────────────┤  ← −100…+100, centre 0
 ( Auto )  EXPOSURE  Brilliance  Contrast  Highlights  ›  ← chips scroll
```

Chips: Auto · Exposure · Brilliance · Contrast · Highlights · Shadows ·
Saturation · Vibrance · Warmth · Tint · Sharpness · Vignette · Grain.

```
chip, untouched   Contrast
chip, changed     Contrast•         ← dot = non-zero
Auto, on          ( AUTO ✓ )        ← CIImage.autoAdjustmentFilters;
                                      tap again = off
slider            double-tap ⇒ reset to 0; light haptic at 0 while dragging
```

## Filters

```
 Kodak Warm                                           80%  ← shown after
 ├────────────────────────────────────────●───────────┤     2nd tap
┌────────┬────────┬────────┬────────┬────────┬────────┐
│[thumb] │[thumb] │[thumb]✓│[thumb] │[thumb] │[thumb] │ ›  ← live thumbs of
└────────┴────────┴────────┴────────┴────────┴────────┘     THIS photo
 Original  Vivid   Kodak W.  Film    Mono     Noir
```

```
tap filter        apply at 100%
tap selected      reveal intensity slider (0–100%)
loading thumbs    grey tiles fade in left→right   ← ≤ 300 ms for 20
```

## Crop

The canvas switches to crop mode and the photo shrinks to fit the handles.

```
┌────────────────────────────────────────────────────────┐
│   ┌──────────────┼──────────────┼──────────────┐       │
│   │              │              │              │       │ ← rule-of-thirds
│   ┼──────────────┼──────────────┼──────────────┼       │   grid while dragging
│   │              │              │              │       │
│   └──────────────┼──────────────┼──────────────┘       │ ← corner handles
└────────────────────────────────────────────────────────┘
   −10°  ·  ·  ·  ·  ·  │  ·  ·  ·  ·  ·  +10°            ← straighten dial
                       2.5°                                  (±45°)
 [ FREE ] [ Original ] [ 1:1 ] [ 4:5 ] [ 9:16 ] [ 16:9 ] ›
 Rotate ⟲    Flip ⇋                              ( Reset )
```

- Leaving Crop (another tool, or tapping Crop again) commits it. There's no Done button.
- Reset is disabled (`·`) while the crop is untouched.

## Retouch

```
 Smooth skin                                           40
 ├──────────────────●──────────────────────────────────┤
 [ SMOOTH SKIN | Heal | Red eye ]
```

```
smooth skin, faces found    applies to face/skin mask; slider 0–100
smooth skin, no face        slider ·   "No faces found in this photo."
heal                        "Tap a blemish or paint over a spot."
                            Brush size ├────●─────┤
                            painting shows a red trail; lift ⇒ healed
red eye                     Fix red eyes                              ─●
```

## Reshape

On-device warp guided by Vision face and body landmarks.

```
 Waist · + slimmer                                    +40   ← caption says what + does
 ├──────────────────────────────────●──────────────────┤
 WAIST•  Hips  Chest  Legs  Shoulders  Arms              ›
 [ Face | BODY | Manual ]
```

```
face       Slim Face · Chin · Eyes · Nose · Forehead      (bipolar sliders)
body       Waist · Hips · Chest · Legs · Shoulders · Arms
manual     [ PUSH | Grow | Shrink ]  ( Clear )
           Brush ├────●─────┤         drag on the photo; ring = brush
no face    "No faces found. Try Manual to reshape by hand."
no body    "No full body found. Try Manual to reshape by hand."
           → opens on Body when there's a body but no face
```

## Text

```
 tap Text ↓   new text box centred, keyboard up, "Your text" selected

┌────────────────────────────────────────────────────────┐
│               ┌┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┐                   │
│               ┊  Summer in Kyoto▌  ┊                   │ ← drag move, pinch
│               └┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┘                   │   scale, twist rotate
└────────────────────────────────────────────────────────┘
 [ FONT | Color | Style | Align ]
 Aa SF Pro  Aa New York  Aa Rounded  Aa Marker  Aa Mono  ›

 Style:  [ PLAIN | Outline | Background | Shadow ]
 Color:  ● ● ● ● ● ● ● ● ⊕                                ← ⊕ = system picker
```

- Tap text on the canvas to select it. Double-tap to edit.
- It's stored as a layer and shows up in the Layers sheet.

## Stickers

```
▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁  ← sheet, not panel:
 🔍 Search emoji                                            grid needs room
 [ EMOJI | Shapes | From Photos ]
 😀 😂 🥹 😍 🤩 😎 🥳 🤔 🙌 👍 ❤️ 🔥 ✨ 🌴 🌸 ☀️
```

```
pick ⇒ sheet closes, sticker centred on canvas, selected (same gestures as Text)
From Photos ⇒ [PhotosPicker] ⇒ image lifted with Cutout ⇒ sticker
```

## Cutout

On-device. Vision `VNGenerateForegroundInstanceMaskRequest`.

```
 ⟳ Finding subjects…                                      ← on open, ≤ 1 s

┌────────────────────────────────────────────────────────┐
│     ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░       │ ← background dimmed,
│     ░░░░░░░░░░ ╭──────────╮ ░░░░░░░╭──────╮ ░░░░       │   subjects glow;
│     ░░░░░░░░░░ │ person 1 │ ░░░░░░░│ dog  │ ░░░░       │   tap a subject to
│     ░░░░░░░░░░ ╰──────────╯ ░░░░░░░╰──────╯ ░░░░       │   toggle it
└────────────────────────────────────────────────────────┘
 2 of 2 subjects
 Background:  [ KEEP | Remove | Blur | Color ]
 [ Copy as Sticker Layer ]
```

```
no subject     "No clear subject found. Try a photo with a person, pet or object."
remove         transparent (checkerboard) → Save offers PNG
blur           slider 0–100 appears
color          swatches ● ● ● ● ⊕
```

## Copy

| Key | String |
|---|---|
| `adjust.auto` | Auto |
| `retouch.noface` | No faces found in this photo. |
| `retouch.heal.hint` | Tap a blemish or paint over a spot. |
| `retouch.redeye` | Fix red eyes |
| `reshape.noface` | No faces found. Try Manual to reshape by hand. |
| `reshape.nobody` | No full body found. Try Manual to reshape by hand. |
| `text.placeholder` | Your text |
| `stickers.search` | Search emoji |
| `cutout.finding` | Finding subjects… |
| `cutout.count` | %d of %d subjects |
| `cutout.none` | No clear subject found. Try a photo with a person, pet or object. |
| `cutout.copy` | Copy as Sticker Layer |
