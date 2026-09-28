# Tool panels

Each panel replaces the area between the canvas and the tool bar. Everything
here is on-device and free. The panel frame comes from `components.md → ToolPanel`.

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

## Copy

| Key | String |
|---|---|
| `retouch.noface` | No faces found in this photo. |
| `retouch.heal.hint` | Tap a blemish or paint over a spot. |
| `retouch.redeye` | Fix red eyes |
| `reshape.noface` | No faces found. Try Manual to reshape by hand. |
| `reshape.nobody` | No full body found. Try Manual to reshape by hand. |
| `cutout.finding` | Finding subjects… |
| `cutout.count` | %d of %d subjects |
| `cutout.none` | No clear subject found. Try a photo with a person, pet or object. |
| `cutout.copy` | Copy as Sticker Layer |
