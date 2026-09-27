# Home

App root. Recent edits, and the single way to start a new one.

```
                                                      ⚙   ← → Settings
Photo Editor                                              ← large title
RECENT                                          14 edits
┌──────────────────┬──────────────────┬──────────────────┐
│                  │                  │                  │
│   [thumbnail]    │   [thumbnail]    │   [thumbnail]    │  ← square crop of
│                  │                  │                  │    the edited result
└──────────────────┴──────────────────┴──────────────────┘
 Today 4:13 PM      Today 9:02 AM      Yesterday
┌──────────────────┬──────────────────┬──────────────────┐
│   [thumbnail]    │   [thumbnail]    │   [thumbnail]    │
└──────────────────┴──────────────────┴──────────────────┘
 Sep 21             Sep 18             Sep 12

         ┌──────────────────────────────────────┐
         │          [[ + Open Photo ]]          │  ← pinned above the
         └──────────────────────────────────────┘    home indicator
```

Reached from: launch · ✕ in Editor

## States

```
empty    ┌──────────────────────────────────────────────┐
         │                                              │
         │          [photo.badge.plus icon]             │
         │            Edit your first photo             │
         │   Everything stays on this iPhone. No        │
         │   account, no watermark.                     │
         │                                              │
         │            [[ + Open Photo ]]                │
         └──────────────────────────────────────────────┘

opening  tile area dims    ⟳ Opening photo…              ← 48 MP decode + proxy;
                                                            target ≤ 500 ms
error    ⌐ Couldn't open that photo. Try another one. ¬   ← toast, stays on Home
missing  ┌──────────────────┐
         │  ⚠ Can't load    │  ← project folder damaged; long-press → Delete
         └──────────────────┘
999      grid scrolls; RECENT count reads "999 edits"; lazy thumbnails
```

## Overlays

```
long-press tile ↓
       ┌────────────────────┐
       │ Duplicate          │
       │ Save to Photos     │   ← exports without opening the Editor
       ├────────────────────┤
       │ Delete           ! │
       └────────────────────┘

 ┌─────────────────────────────────────────┐
 │  Delete this edit?                      │
 │  The original in Photos isn't affected. │
 │           ( Cancel )  [[ Delete ]]!     │
 └─────────────────────────────────────────┘
```

## Interactions

| Target | Action | Result |
|---|---|---|
| tile | tap | → Editor with that project |
| tile | long-press | context menu above |
| Open Photo | tap | → [PhotosPicker], single image, no permission prompt |
| ⚙ | tap | → Settings |

## Copy

| Key | String |
|---|---|
| `home.title` | Photo Editor |
| `home.recent` | RECENT |
| `home.count` | %d edits |
| `home.open` | Open Photo |
| `home.empty.title` | Edit your first photo |
| `home.empty.body` | Everything stays on this iPhone. No account, no watermark. |
| `home.opening` | Opening photo… |
| `home.error.open` | Couldn't open that photo. Try another one. |
| `home.delete.title` | Delete this edit? |
| `home.delete.body` | The original in Photos isn't affected. |
