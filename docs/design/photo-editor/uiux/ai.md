# AI (generative)

The AI tool in the Editor's tool bar. These are the only features that leave
the device, and they need the user's own key (`byo-ai-keys.md`).

```
 [ MAGIC ERASE | Restyle ]
 Paint over what to remove.
 Brush ├──────●───────────────┤              ( Clear )
 via OpenAI · your account is billed      [[ Erase ]]   ← vendor = first key
                                                           in fallback order
```

## Magic Erase

```
┌────────────────────────────────────────────────────────┐
│                                                        │
│          ▓▓▓▓▓                                         │ ← painted mask,
│         ▓▓▓▓▓▓▓   ← stranger in background             │   red 50%
│          ▓▓▓▓▓                                         │
└────────────────────────────────────────────────────────┘
```

## Restyle

```
 [ Magic Erase | RESTYLE ]
 ┌──────────────────────────────────────────────────────┐
 │ Describe a style, e.g. watercolor, 90s film…         │
 └──────────────────────────────────────────────────────┘
 ( Watercolor )  ( Anime )  ( Oil paint )  ( Pixel art ) ›  ← fills the prompt
 via Google Gemini · your account is billed  [[ Restyle ]]
```

## States

```
no key      ⓘ Uses your own AI key.         [[ Add AI Key ]]
                                            ← tap ⇒ Add AI Key sheet
                                              (settings.md), then back here
offline     [[ Erase ]]·   You're offline.
empty mask  [[ Erase ]]·   ← nothing painted yet
running     ⟳ Erasing… (8 s)                        ( Cancel )
            canvas: shimmer over the masked area only
done        result lands as a new layer "Magic Erase"; ↶ removes it
error       ⚠ OpenAI rejected the key (401).   ( Fix key )
            ⚠ Rate limited — tried Gemini too.  ( Try again )
            ⚠ Couldn't reach OpenAI.            ( Try again )
            ← vendor's own code verbatim (credentials.md)
```

```
fallback: key1 ─✗ 429─▶ key2 ─✓─▶ done      (Sequential, see settings.md)
```

## Copy

| Key | String |
|---|---|
| `ai.erase` | Magic Erase |
| `ai.erase.hint` | Paint over what to remove. |
| `ai.erase.run` | Erase |
| `ai.restyle` | Restyle |
| `ai.restyle.placeholder` | Describe a style, e.g. watercolor, 90s film… |
| `ai.restyle.run` | Restyle |
| `ai.via` | via %@ · your account is billed |
| `ai.nokey` | Uses your own AI key. |
| `ai.nokey.cta` | Add AI Key |
| `ai.offline` | You're offline. |
| `ai.running.erase` | Erasing… |
| `ai.error.key` | %@ rejected the key (%d). |
| `ai.error.rate` | Rate limited — tried %@ too. |
| `ai.error.network` | Couldn't reach %@. |
