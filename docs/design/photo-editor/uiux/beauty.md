# Beauty, Makeup, Reshape additions (v1.1)

All face work reuses one `FaceAnalysis` (Vision landmarks) per photo. Masks are
drawn from landmarks, feathered, and blended in output space. No face → the
panel says so, like Retouch did.

## Retouch → "Beauty"

Tool renamed Beauty. One slider for the selected chip; Auto is a look picker.

```
 Whiten                                               40
 ├────────────────────●────────────────────────────────┤  ← 0…100
 ( Auto )  Smooth•  WHITEN  Even tone  De-shine  Dark circles  Bright eyes  Teeth  Heal  Red eye ›
```

```
Auto chip       [ Off | Natural | Soft | Glam ]      ← writes real values into
                                                       Smooth/Whiten/Eyes/Slim…;
                                                       any later tweak keeps them
Heal chip       "Tap a blemish or paint over a spot."  ( Clear )  brush size
Red eye chip    [Fix red eyes  ◯]
```

| Chip | What it does | Mask |
|---|---|---|
| Smooth | edge-preserving blur (existing) | skin oval − eyes/brows/lips |
| Whiten | lift skin luma, pull yellow out | skin |
| Even tone | blur chroma only (keeps texture) | skin |
| De-shine | compress skin highlights | skin |
| Dark circles | lift + warm under-eye | ellipses below each eye |
| Bright eyes | brighten + sharpen iris/whites | eye polygons |
| Teeth | desaturate yellow, brighten | inner-lips polygon |

## Makeup (new tool)

```
 Lips · Rose                                          60
 ├───────────────────────────────●─────────────────────┤
 ● ● ● ● ● ● ●  (+)                                     ← swatches per part
 LOOKS  Lips•  Blush  Brows  Liner  Contour  Hair
```

```
Looks chip   [thumb-less pills] None · Natural · Rosy · Glam · K-beauty · Bold
             ← one tap sets lips+blush+brows+liner+contour; "None" clears
Hair chip    swatches Brown · Black · Auburn · Blonde · Rose · Ash · Blue
             hair = person mask ∩ head region − face oval; colour-blend keeps
             luminance, so strands and shine survive
```

## Reshape additions

Face chips gain **Head** (+ = smaller head: shrink the whole head region toward
the chin). Body chips gain **Neck** (+ = longer: stretch between chin and shoulders).
