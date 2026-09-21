# Photo Editor

> 🚧 Work in progress — skeleton only, not yet functional.

A free iPhone photo editor in the spirit of Meitu and similar apps, without
the subscription paywall. Core editing tools — crop, filters, adjust
(brightness/contrast/saturation), text & stickers, layers — are yours to use
with no limits.

AI-assisted tools (enhance, background removal, generate variations) call
out to an AI provider using your own API key, entered in Settings and stored
in the Keychain. There's no bundled or paid AI backend — you bring the key,
you pay the provider directly.

## Setup

```
xcodegen generate && open PhotoEditor.xcodeproj
```
