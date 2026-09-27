# Draw, Mosaic, Background, Frame, ID Photo (v1.1)

## Draw (new tool)

Strokes become one Drawing layer (movable, hideable, deletable like any layer).

```
 [ Pen | Neon | Marker ]                     ↶ stroke   ( Clear )
 ● ● ● ● ● ● ● ●                     ○──────●───────○  size
```
Canvas: finger paints; pinch/pan disabled while Draw is open.

## Mosaic (new tool)

```
 [ Pixelate | Blur ]                ( Blur faces )    ( Clear )
 ○──────●──────○ brush size          ○────●────○ strength
```
Paint to hide; "Blur faces" drops one pixelate dab per detected face.

## Cutout → Background

```
 Background  [ Keep | Remove | Blur | Colour | Photo | Gradient ]
 Photo      ( Choose photo… )  → [PhotosPicker] → aspect-filled behind subject
 Gradient   ◐ ◐ ◐ ◐ ◐ ◐                              ← 6 presets
```

## Frame (new tool)

```
 Style   ( None ) ( Colour ) ( Blur ) ( Polaroid )
 Ratio   [ Fit | 1:1 | 4:5 | 9:16 | 16:9 ]
 Border  ○─────●─────○     Corners ○──●────────○
 ● ● ● ● ● ● ● ●  (Colour / Polaroid)
```
The canvas grows to the framed size; layers and brushes stay mapped to the photo.

## ID Photo (new tool)

```
 Size   US 2×2in · EU 35×45 · UK 35×45 · CN 33×48 · 1-inch · 2-inch   ›
 Background  ● White  ● Light blue  ● Red  ● Grey
 "Face centred, head fills 50–69% of the height."    [[ Apply ]]
```
Apply = cutout person on a solid colour + crop at the size's ratio, positioned
from the face box. Export at 300 dpi pixel size is the Save sheet's job (Full).
No face → "Needs a front-facing photo with one face."
