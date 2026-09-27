# Settings

A page pushed from Home ⚙. It uses the system light/dark appearance.

```
‹ Home                  Settings
AI KEYS ⓘ                                   Sequential ▾
Only for Magic Erase and Restyle.
┌──────────────────────────────────────────────────────┐
│ OpenAI                                  ↑   ↓   ⋯    │
│ 42 requests                                          │
├──────────────────────────────────────────────────────┤
│ Google Gemini                           ↑   ↓   ⋯    │
│ 3 requests                                           │
├──────────────────────────────────────────────────────┤
│                    + Add AI Key                      │
└──────────────────────────────────────────────────────┘

EXPORT
┌──────────────────────────────────────────────────────┐
│ Default format                    [ HEIC | JPEG ]    │
├──────────────────────────────────────────────────────┤
│ Keep location data                              ─●   │
└──────────────────────────────────────────────────────┘

STORAGE                                         1.8 GB
┌──────────────────────────────────────────────────────┐
│ Saved edits                                  (14) ›  │ ← list with per-
├──────────────────────────────────────────────────────┤   project size, swipe
│ Delete All Edits…                                 !  │   to delete
└──────────────────────────────────────────────────────┘

ABOUT
┌──────────────────────────────────────────────────────┐
│ Privacy                                           ›  │
│ Version                                  1.0 (12)    │
└──────────────────────────────────────────────────────┘
```

```
ⓘ ↓ popover
 ⌐ Keys stay in this iPhone's Keychain and never sync or leave it,
   except to call that vendor. Only the photo region and prompt you
   run are sent. The vendor bills your account.
   Order = fallback order. ¬

Sequential ▾ with < 2 keys  ⇒ disabled ·
Sequential ▾ ↓
   ┌───────────────────┐
   │ ✓ Sequential      │  ← stick to key 1 until it fails
   │   Round Robin     │  ← rotate every call
   └───────────────────┘
```

## States

```
no keys     AI KEYS ⓘ
            Only for Magic Erase and Restyle.
            ┌──────────────────────────────────┐
            │          + Add AI Key            │
            └──────────────────────────────────┘
key error   │ OpenAI                 ↑ ↓ ⋯  │
            │ ⚠ Rejected (401) · 42 requests │  ← last error inline in the row
no edits    STORAGE  0 KB · "Delete All Edits…" disabled ·
```

## Add AI Key sheet

Half sheet. Save runs the test (`byo-ai-keys.md`).

```
▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁
( Cancel )              Add AI Key                 Save
╭──────────────────────────────────────────────────────╮
│ Vendor                            [ OPENAI | Gemini ]│ ← only vendors that
├──────────────────────────────────────────────────────┤   can edit images
│ API key          │ sk-proj-••••••••••••••••••  👁 │  │ ← autocorrect, smart
╰──────────────────────────────────────────────────────╯   quotes off
 Don't have an OpenAI key?  Get one →
```

```
testing    ⟳ Testing the key…                       ← inline, Save ·
rejected   ⚠ OpenAI said: invalid_api_key (401)     ← draft kept
hint       ⓘ 51 characters — OpenAI keys usually start with sk-
saved      sheet closes, row appears at the bottom of AI KEYS
```

## Delete-all alert

```
 ┌──────────────────────────────────────────┐
 │  Delete all 14 edits?                    │
 │  Originals in Photos aren't affected.    │
 │  This can't be undone.                   │
 │          ( Cancel )  [[ Delete All ]]!   │
 └──────────────────────────────────────────┘
```

## Copy

| Key | String |
|---|---|
| `settings.ai.header` | AI KEYS |
| `settings.ai.hint` | Only for Magic Erase and Restyle. |
| `settings.ai.info` | Keys stay in this iPhone's Keychain and never sync or leave it, except to call that vendor. Only the photo region and prompt you run are sent. The vendor bills your account. Order = fallback order. |
| `settings.ai.add` | Add AI Key |
| `settings.ai.requests` | %d requests |
| `settings.export.format` | Default format |
| `settings.export.location` | Keep location data |
| `settings.storage.edits` | Saved edits |
| `settings.storage.deleteAll` | Delete All Edits… |
| `addkey.title` | Add AI Key |
| `addkey.get` | Don't have an %@ key?  Get one → |
| `addkey.testing` | Testing the key… |
| `addkey.rejected` | %@ said: %@ (%d) |
