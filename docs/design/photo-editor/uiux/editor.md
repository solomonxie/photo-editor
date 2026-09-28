# Editor

Full-screen, always dark. It's reached from Home (a new pick or a recent). Edits
are kept only when saved or shared; ✕ with unsaved edits asks "Discard changes?".

```
 ✕        ↶   ↷              Compare   Layers   [[ Save ]]
┌────────────────────────────────────────────────────────┐
│                                                        │
│                                                        │
│                                                        │
│                     [photo canvas]                     │ ← MTKView; pinch zoom,
│                                                        │   pan, double-tap
│                                                        │   fit ↔ 100%
│                                                        │ ← press-and-hold =
│                                                        │   show original
└────────────────────────────────────────────────────────┘
  2 of 3 subjects                                          ← tool panel
 [ Keep | REMOVE | Blur | Colour ]                            (tools.md)
────────────────────────────────────────────────────────
 CUTOUT Beauty Reshape AI                                 ← tool bar
```

- `↶ ↷` = SF `arrow.uturn.backward` / `.forward`. They're disabled (`·`) at the ends of the history.
- Compare = SF `square.split.2x1`. Holding it acts like holding the canvas.
- Layers = SF `square.3.layers.3d`. It shows a count badge when there are more than 1 layer.

Reached from: Home. Exits: ✕ → Home · Save → Save sheet · Layers → Layers sheet.

## Canvas behaviour

```
panel open                         panel closed (tap active tool again)
┌──────────────────────┐          ┌──────────────────────┐
│       [photo]        │          │                      │
│                      │          │       [photo]        │ ← canvas grows;
├──────────────────────┤          │                      │   the photo is never
│ panel                │          │                      │   covered by a panel
├──────────────────────┤          ├──────────────────────┤
│ tool bar             │          │ tool bar             │
└──────────────────────┘          └──────────────────────┘
```

## States

```
loading     canvas: blurred low-res preview → sharp     ← embedded HEIC thumb
                                                          first, proxy next
editing     as the default mock
comparing   top-left pill: "Original"                    ← while held
exporting   Save sheet shows ⟳ Exporting…  ( Cancel )     ← CI gives no progress;
                                                          no fake bar
error       ⌐ Something went wrong rendering. Undo the last change. ¬
low memory  ⌐ Closed other layers' previews to free memory ¬   ← rare; iOS warning
```

## Layers sheet

Half sheet. Top of the list = front.

```
▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁
                         Layers                    Done
╭──────────────────────────────────────────────────────╮
│ ≡  [▣ ]  Subject cutout                   👁   ⋯     │
├──────────────────────────────────────────────────────┤
│    [▣ ]  Photo                             🔒        │ ← base, fixed at bottom
╰──────────────────────────────────────────────────────╯
 Opacity                                           100%   ← for selected row
 ├──────────────────────────────────────────────●┤
```

```
⋯ ↓
   ┌──────────────────┐
   │ Duplicate        │
   │ Bring to Front   │
   │ Send to Back     │
   ├──────────────────┤
   │ Delete         ! │
   └──────────────────┘

one layer   only "Photo" row + hint "Copy a cutout as a sticker to get layers."
```

## Save sheet

```
▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁
                          Save
╭──────────────────────────────────────────────────────╮
│ Format              [ HEIC | JPEG | PNG ]            │ ← PNG auto-picked
├──────────────────────────────────────────────────────┤   when there's
│ Size       [ FULL | 4K | 2K | HD ]                   │   transparency
│                                   6048×4032          │
├──────────────────────────────────────────────────────┤
│ Quality         [ HIGH | MEDIUM | SMALL ]            │ ← hidden for PNG;
├──────────────────────────────────────────────────────┤   remembered
│ File size                              3.4 MB  / ⟳   │ ← real encode, 250 ms
╰──────────────────────────────────────────────────────╯   debounce; Save
                                                           reuses the bytes
            [[ Save to Photos ]]
               ( Share… )                                ← [share sheet]
```

```
exporting  ⟳ Exporting…                      ( Cancel )
done       sheet closes → ⌐ Saved to Photos ¬
denied     ┌───────────────────────────────────────────┐
           │  Allow adding to Photos                   │
           │  Photo Editor can only add new photos. It │
           │  can't see your library.                  │
           │       ( Cancel )  [[ Open Settings ]]     │
           └───────────────────────────────────────────┘
```

## Interactions

| Target | Action | Result |
|---|---|---|
| canvas | pinch / pan | zoom 1×–16×, pan clamped to the edges |
| canvas | double-tap | toggle fit ↔ 100% at the tap point |
| canvas | press and hold | show the original, release → edited |
| tool bar item | tap | open its panel; tapping the active one closes it |
| ↶ / ↷ | tap | undo / redo one op (a slider drag = one op) |
| ✕ | tap | → Home (already saved) |

## Copy

| Key | String |
|---|---|
| `editor.compare.pill` | Original |
| `editor.layers.title` | Layers |
| `editor.layers.empty` | Copy a cutout as a sticker to get layers. |
| `editor.save.title` | Save |
| `editor.save.photos` | Save to Photos |
| `editor.save.share` | Share… |
| `editor.save.done` | Saved to Photos |
| `editor.save.denied.title` | Allow adding to Photos |
| `editor.save.denied.body` | Photo Editor can only add new photos. It can't see your library. |
| `editor.error.render` | Something went wrong rendering. Undo the last change. |
