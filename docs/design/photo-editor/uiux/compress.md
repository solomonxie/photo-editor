# Compress

Pushed from Home (⇲). Makes smaller copies of library photos and videos;
originals are deleted only on an explicit tap, and iOS confirms that too.

```
‹ Photo Editor            Compress
╭──────────────────────────────────────────────────────╮
│ Photos          [ FULL | 4K | 2K | HD ]              │ ← defaults 2K,
│ Quality         [ HIGH | MEDIUM | SMALL ]            │   Medium, 1080p;
│ Videos          [ 4K | 1080p | 720p ]                │   remembered
╰──────────────────────────────────────────────────────╯
 Photos become HEIC, videos HEVC. Live Photos are saved
 as still photos. A copy is kept only if it's at least
 10% smaller.
12 ITEMS
╭──────────────────────────────────────────────────────╮
│ [▣] Photo              4032×3024            6.1 MB   │ ← pending
│ [▣] Live Photo         4032×3024        ⟳            │ ← working
│ [▶] Video · 1:23       3840×2160      48 MB  ̶2̶1̶0̶ ̶M̶B̶   │ ← done
│ [▣] Photo              1280×960        Already small │ ← skipped
│ [▣] Photo              4032×3024             ⚠       │ ← failed (VO reads
╰──────────────────────────────────────────────────────╯   the error)
▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁
            [[ Compress 12 Items ]]                       ← idle
               ( Choose Again )
```

## States

```
empty      [⇲ icon]  Make photos and videos smaller
           Smaller copies are added to your library with the
           same date and place. You choose whether to delete
           the originals.       [[ + Choose Photos & Videos ]]
running    ⟳ Compressing 3 of 12…                 ( Stop )   settings disabled
finished   Copies saved · 180 MB smaller
           [[ Delete 12 Originals ]]  (red) → iOS confirm → Recently Deleted
deleted    empty state, title "Freed 180 MB"
denied     alert "Allow access to Photos" ( Cancel ) [[ Open Settings ]]
```

Copies keep the original's creation date, location and favourite flag, so
they sort in place in Photos.
