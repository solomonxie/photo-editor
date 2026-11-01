# TestFlight external testing

App Store Connect → TestFlight → External Testing → **+** group → add the build. First build of a version goes through Beta App Review (~1 day).

## Test Information

Beta App Description (≤4000):

```
Photo Editor does the edits the Photos app can't, on the device: cut out the subject, retouch faces, reshape face and body (one person at a time in a group photo), and compress your library to HEIC/HEVC.

No account. Tap Open Photo and pick any picture; Cutout, Beauty and Reshape work immediately and offline. To browse sample edits without touching your library: Settings → Demo mode (separate store; Export and Compress don't write to Photos while it's on).

What's in this beta:
• Cutout: remove, blur or recolour the background; lift the subject as a sticker layer
• Beauty: one-tap looks, skin smoothing, tap-to-heal, red eye
• Reshape: face (slim, chin, eyes, nose, forehead) and body (waist, hips, chest, legs, shoulders, arms), plus push/grow/shrink brush
• Save keeps edits adjustable; Export writes a new photo at HD–4K
• Compress: HEIC/HEVC copies of photos and videos
• Optional AI (Magic Erase, Fill, Restyle) and Hair tools with your own OpenAI or Gemini key
```

Feedback Email: `you@example.com`

## Contact Information

| Field | Value |
|---|---|
| First Name | TODO |
| Last Name | TODO |
| Phone number | TODO — yours, with country code (`+1 …`) |
| Email | `you@example.com` |

## Sign-In Information

Sign-in required: **off** (no account in the app). Leave User Name / Password blank.

Review Notes: paste the App Review Notes block from [listing.md](listing.md) if present.

## Per build: What to Test

```
Open a portrait: remove the background, smooth skin, heal a spot, slim the face slightly, save, then export and check the result in Photos. Open a group photo and reshape one person only. Compress one photo and one video. Turn on Settings → Demo mode and browse the sample edits. Report any artifact, crash or slowness, with the photo size and your iPhone model, via TestFlight.
```
