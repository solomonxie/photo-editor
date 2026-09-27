# Components

Parts used in more than one place.

## ToolPanel

The container between the canvas and the tool bar. Fixed height 132 pt, so the
canvas doesn't jump when switching tools.

```
┌──────────────────────────────────────────────────────┐
│ <Label>                                      <value> │ ← optional ValueSlider
│ ├──────────────────●───────────────────────────────┤ │
│ <chip row | segmented | swatches>                    │ ← one selector row
└──────────────────────────────────────────────────────┘
knobs: title?, slider?, selector, footer?  (footer = "via OpenAI · …")
```

## ValueSlider

```
bipolar    ├──────────────●──────────────┤  +24    ← centre tick, −100…+100
unipolar   ├────────●────────────────────┤   40%   ← 0…100
disabled   ├────────●────────────────────┤·        ← reason on the right
```

- Haptic tick at 0 / centre.
- Double-tap resets.
- One drag = one undo step.

## ChipRow

```
( Auto )  EXPOSURE  Brilliance  Contrast•  Highlights  ›
   ↑         ↑                      ↑                  ↑
 action   selected (bold,       changed (dot)      scrolls
          accent underline)
```

## ThumbStrip

```
┌────────┬────────┬────────┐
│[thumb] │[thumb]✓│[thumb] │   ← 64×64 pt, rendered from the proxy
└────────┴────────┴────────┘
 Original  Vivid    Film
loading: grey tile · selected: accent border + ✓
```

## CanvasObject (text, sticker, cutout layer)

```
selected                      unselected
   ┌┄┄┄┄┄┄┄┄┄┄┄┄┐ ⊗             Summer in Kyoto
   ┊ Summer in  ┊                ← no chrome
   ┊ Kyoto      ┊
   └┄┄┄┄┄┄┄┄┄┄┄┄┘ ⤡
⊗ = delete  ⤡ = one-finger scale/rotate handle
```

## Toast

```
⌐ Saved to Photos ¬               ← 2 s, above tool bar, one line
⌐ 1 layer deleted   ( Undo ) ¬    ← max one action
```

## Busy overlay (canvas-local)

```
⟳ Erasing… (8 s)   ( Cancel )      ← never blocks the tool bar;
                                      ↶ stays available after cancel
```
