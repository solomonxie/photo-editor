# Publishing Photo Editor — step by step

Every field below is ready to paste. `TODO` = only you can supply it.
App Store Connect paths start at **Apps → Photo Editor → Distribution →**.

| | |
|---|---|
| Bundle ID | `com.example.photoeditor.app` |
| SKU | `photoeditor-ios` |
| Version | `1.0.0` (`MARKETING_VERSION` in `project.yml`) |
| Build | timestamp, set by `make release` |
| Devices | iPhone only (`TARGETED_DEVICE_FAMILY = 1`) — no iPad screenshots needed |
| Min iOS | 17.0 |
| Privacy Policy URL | `https://github.com/solomonxie/photo-editor/blob/master/docs/release/privacy-policy.md` |
| Support URL | `https://github.com/solomonxie/photo-editor/issues` |

---

## 1. Apple Developer account

- [ ] developer.apple.com → Account → membership **active** (paid, Individual is fine).
- [ ] App Store Connect → **Business** (Agreements, Tax, and Banking) → no pending agreement banner. Free app: no Paid Apps agreement or banking needed.

## 2. Xcode and tools

- [ ] Xcode → Settings → **Accounts** → signed in with the developer Apple ID; the team shows under it.
- [ ] `cp Config/Local.xcconfig.example Config/Local.xcconfig`, set your Team ID (developer.apple.com → Membership). Gitignored — never commit it; the repo is public.
- [ ] `brew install xcodegen` if `xcodegen` isn't on the PATH. The `.xcodeproj` is generated from `project.yml` and gitignored.

## 3. Bundle ID

Created by automatic signing on the first device build. Verify at developer.apple.com →
Certificates, Identifiers & Profiles → Identifiers → `com.example.photoeditor.app`.
No capabilities are needed (no iCloud, no push, no App Groups).

## 4. Run on the iPhone

- [ ] `make ios` → Release build on the paired iPhone.
- [ ] Smoke test:
  - Retouch → Smooth skin on a face, and heal a spot.
  - Reshape → Body on a full-length photo.
  - Cutout → Blur, then Copy as Sticker.
  - Save to Photos (grant add-only access). Open Photos and check the result.
  - Reopen the edit from Home: every slider is still adjustable.
  - Home → ⇲ Compress: pick a few photos and a video, compress, check the copies in Photos, delete originals.
- [ ] `make test` → unit tests and the 48 MP benchmark on the device (numbers print as `PERF …`).

## 5. Create the app in App Store Connect

**Apps → + → New App**

| Field | Value |
|---|---|
| Platforms | iOS |
| Name | `Photo Editor: Retouch & Shape` |
| Primary Language | English (U.S.) |
| Bundle ID | `com.example.photoeditor.app` (dropdown) |
| SKU | `photoeditor-ios` |
| User Access | Full Access |

If the name is taken, the runner-up list is in [App Store Connect pages](#app-store-connect-pages).

## 6. Listing content

Fill the pages in [App Store Connect pages](#app-store-connect-pages) below. Screenshots: see [Screenshots](#screenshots).

## 7. Archive and upload

```
make release
```

Runs `make check`, then generates the project, archives Release, signs for the App Store and
uploads — no Xcode Organizer, no Product → Archive → Distribute. `make release BUILD=202609261830`
pins the build number; left off, it is a timestamp.

Upload authenticates as the Apple ID signed into Xcode → Settings → Accounts. If it asks
for credentials in a terminal, add an App Store Connect API key instead: download the
`.p8`, then append `-authenticationKeyPath <abs path> -authenticationKeyID <id>
-authenticationKeyIssuerID <issuer>` to the `-exportArchive` call in `scripts/release-ios.sh`.
Processing in App Store Connect: 15–60 min, then an email "build has completed processing".

Fallback, Xcode GUI: `xcodegen generate && open PhotoEditor.xcodeproj` → destination **Any iOS Device (arm64)** → Product → **Archive** → Organizer → **Distribute App** → App Store Connect → Upload.

## 8. TestFlight

- [ ] App Store Connect → **TestFlight** → the build shows no "Missing Compliance" (see [Export compliance](#export-compliance)).
- [ ] Internal Testing → **+** group `Me` → add your Apple ID → install via the TestFlight app on the iPhone.
- [ ] Same smoke test as step 4, on the TestFlight build (this is the exact binary Apple reviews). If you have an OpenAI or Gemini key, also run one Magic Erase.

## 9. Submit

- [ ] `iOS App → 1.0.0 Prepare for Submission` → **Build** → **+** → pick the build.
- [ ] Every page in [App Store Connect pages](#app-store-connect-pages) filled; App Privacy published.
- [ ] **Add for Review** → **Submit for Review**.

## 10. App Review

- Typical: 24–48 h. Status: Waiting for Review → In Review → Pending Developer Release.
- Rejection → **Resolution Center**: reply there, or fix and re-run `make release` (the build number is a fresh timestamp), attach the new build, resubmit. `MARKETING_VERSION` does not need bumping for a rejected version.
- Likely questions, all answered in the review notes:
  - The AI features: optional, and they need the user's own key.
  - Photos access: add-only for the editor; read/write only for Compress.
  - Body reshape: a standard beauty-editor tool, applied only to the user's own photo.

## 11. Release

- [ ] Status **Pending Developer Release** → `1.0.0` page → **Release This Version**. Live in the store within ~24 h.
- [ ] `git tag v1.0.0 && git push --tags`.

---

## Screenshots

Apple requires one set: **iPhone 6.9" Display**, exactly `1320 × 2868` (or `1290 × 2796`).
App Store Connect scales it down for every smaller phone. The 6.5" slot (`1284 × 2778`) is
optional and generated anyway.

Capture on the paired iPhone 14 (`1170 × 2532`) and let the script do the rest — the
aspect ratios differ by 0.4%, which is invisible.

What sits in `docs/release/screenshots/` now was captured from the Debug build using your own
photos. It proves the pipeline and is usable as-is, but it's gitignored because it shows you.
Recapture with photos you're happy to publish (a model-released stock photo is safest), then:

1. `make ios` — a Release build.
2. Status bar: full battery, Wi-Fi, no notification banners. Side button + Volume Up per shot.
3. Shots, in upload order (3 minimum, 10 maximum — the first two are what people actually see):
   1. **Cutout** — a person with the background on Blur (reads as Portrait mode)
   2. **Retouch** — a close-up portrait, Smooth skin at ~40
   3. **Reshape** — a full-length photo, Body → Waist moved
   4. **AI** — Fill with "fuller hair" typed (needs a key in Settings)
   5. **Home** — a grid of your recent edits
4. AirDrop to the Mac, e.g. `~/Desktop/shots/`, then:

```
make screenshots SHOTS=~/Desktop/shots
```

Outputs overwrite `docs/release/screenshots/{6.9,6.5}/`, named after the files you fed in —
so name them `01-cutout.png`, `02-retouch.png` … and the upload order sorts itself.
Drag the `6.9` folder's files into the 6.9" slot.

App Preview video: skip for 1.0.

---

## App Store Connect pages

### `iOS App → 1.0.0 Prepare for Submission`

| Field | Value |
|---|---|
| Previews and Screenshots | [Screenshots](#screenshots) |
| Promotional Text | below |
| Description | below |
| Keywords | below |
| Support URL | `https://github.com/solomonxie/photo-editor/issues` |
| Marketing URL | leave blank |
| Version | `1.0.0` |
| Copyright | `2026 solomonxie` |
| Routing App Coverage File | leave blank |
| Build | the uploaded build (step 9) |
| App Review → Sign-In Required | Off |
| App Review → Contact First / Last Name | TODO |
| App Review → Phone | TODO (with country code, e.g. `+1 …`) |
| App Review → Email | TODO |
| App Review → Notes | below |
| App Review → Attachment | none |
| Version Release | **Manually release this version** |

Promotional Text (138/170):

```
Edit photos on your iPhone, no subscription: background cutout, smooth skin, reshape face and body. Everything but AI stays on the device.
```

Description:

```
A photo editor that does the touch-ups people pay monthly for — on your iPhone, with no account, no subscription and no watermark.

RETOUCH
• Smooth skin that keeps eyes, brows and lips sharp
• Tap a blemish to heal it, or paint over a larger spot
• Red-eye correction

RESHAPE
• Face: slimmer cheeks, chin, bigger eyes, smaller nose, forehead
• Body: waist, hips, chest, legs, shoulders and arms, placed by on-device pose detection
• A manual brush to push, grow or shrink anything by hand

CUTOUT
• Find the people, pets and objects in a photo automatically
• Remove the background, blur it like Portrait mode, or swap it for a colour
• Lift a subject out as a sticker; move, pinch, rotate, reorder and fade it as a layer

NOTHING IS FINAL
Every edit stays adjustable. Save a photo, come back next week, and every slider is where you left it. Saving always adds a new photo — your original is never touched.

FAST
Built on Apple's Metal and Core Image. Sliders update every frame, and a 48-megapixel photo exports in about a second on an iPhone 14.

OPTIONAL AI, ON YOUR OWN KEY
Magic Erase, Fill ("fuller hair", "a hat") and Restyle use your own OpenAI or Google Gemini API key. The key stays in this iPhone's Keychain, the provider bills you directly, and only the photo and prompt you run are sent. Skip it and everything else still works.

PRIVATE
Photos are picked with the system picker, and saving needs add-only access. Only the optional Compress tool asks for library access, to shrink the items you choose. No analytics, no ads, no tracking.
```

Keywords (99/100 — "photo" and "editor" are omitted, the name already indexes them):

```
beauty,body,face,slim,skin,blemish,makeup,eyes,cutout,background,blur,sticker,portrait,selfie,waist
```

App Review Notes:

```
No account or login is needed. Tap Open Photo, pick any photo, and every tool in the bottom bar works immediately and offline.

Photos access: photos are chosen with the system PHPicker, which needs no permission. Saving asks for add-only access (NSPhotoLibraryAddUsageDescription). The separate Compress tool (Home → ⇲) asks for read/write access (NSPhotoLibraryUsageDescription) only when used: it re-encodes the photos and videos the user picks into smaller copies, and deletes originals only after the user taps Delete and confirms the iOS prompt.

Face and body tools (Retouch, Reshape) use Apple's Vision framework on the device to place edits on the user's own photo. Landmarks are never stored or transmitted.

Optional AI (the "AI" tool: Magic Erase, Fill, Restyle): requires the reviewer's own API key from OpenAI or Google Gemini, added in Settings → AI Keys. Without a key the AI tool shows an "Add AI Key" button and nothing else changes. With a key, the photo region and prompt are sent directly from the device to that provider. We operate no server.

All edits are stored locally on the device. We receive no user data.
```

What's New: not shown for a first version. From 1.1 on, write it here.

### `General → App Information`

| Field | Value |
|---|---|
| Name | `Photo Editor: Retouch & Shape` (29/30) |
| Subtitle | `Cutout, face & body reshape` (27/30) |
| Category — Primary | Photo & Video |
| Category — Secondary | Lifestyle |
| Content Rights | **No**, it does not contain, show, or access third-party content |
| Age Rating | **Edit** → answers below → result **4+** |
| License Agreement | Apple standard EULA (default) |
| Privacy Policy URL | `https://github.com/solomonxie/photo-editor/blob/master/docs/release/privacy-policy.md` |

If `Photo Editor: Retouch & Shape` is taken, in order of preference:
`Retouch Studio: Photo Editor` (28), `Photo Editor: Face & Body` (25), `Reshape & Retouch Photo Editor` (30).
The name is what gets indexed; the subtitle can absorb whatever the name loses. Don't put "free"
or a competitor's name in any field — both are rejection reasons under guideline 2.3.7.

Age rating questionnaire — every answer:

| Section | Answer |
|---|---|
| Parental controls / age assurance | No |
| Unrestricted web access | **No** — no in-app browser. The only links open the AI vendor's key page in Safari. |
| User-generated content | No — edits are private to the device, not shared or published by the app |
| Messaging and chat | No |
| Advertising | No |
| Violence, sexual content, profanity, horror, mature themes | None — the app ships no content of its own |
| Alcohol, tobacco, drugs | None |
| Medical or treatment information / health & wellness | None |
| Gambling, simulated gambling, contests, loot boxes | None / No |
| Made for Kids | No |

Regional (Korea, China Mainland, Vietnam) — leave unset.
**Digital Services Act** trader status: **Not a trader** (free, no monetization) — if App Store Connect blocks EU availability without it, answer it in Business → Compliance.

### `App Store → Trust & Safety → App Privacy`

| Field | Value |
|---|---|
| Privacy Policy URL | same as above |
| Do you or your third-party partners collect data from this app? | **No, we do not collect data from this app** |

Then **Publish**. The label shows "Data Not Collected".

True only while there is no analytics or crash SDK — re-check before each submission:

```
grep -rniE "analytics|firebase|sentry|amplitude|mixpanel|posthog|bugsnag|crashlytics" PhotoEditor project.yml
```

Data leaves the device only when the user taps Erase, Fill or Restyle, and only to the AI
provider whose key they added — a live request under their own account, not an SDK, and you
never receive any of it, so none of it is "collected" in Apple's sense. The app's
`PrivacyInfo.xcprivacy` declares no tracking, no collected data, and the two required-reason
APIs it uses (UserDefaults `CA92.1`, file timestamps `C617.1`).

### `App Store → Trust & Safety → App Accessibility`

Skip for 1.0 rather than over-claim.

### `App Store → Monetization → Pricing and Availability`

| Field | Value |
|---|---|
| Base Country or Region | United States (USD) |
| Price | **Free** ($0.00) |
| Availability | All countries or regions |
| Tax Category | App Store software (default) |
| iPhone and iPad Apps on Apple Silicon Macs | **Off** for 1.0 (untested on Mac) |
| Apple Vision Pro | Off |

### Not needed for 1.0

In-App Purchases, Subscriptions, In-App Events, Custom Product Pages, Product Page Optimization, Promo Codes, Game Center, Featuring Nominations, Ratings and Reviews, History.

---

## Export compliance

No page for it in App Store Connect — nothing to fill in. `ITSAppUsesNonExemptEncryption = false`
in `Info.plist` (set in `project.yml`) answers it at upload. The app uses only HTTPS/TLS and the
Keychain, both exempt.
Verify: TestFlight → the build is **not** marked "Missing Compliance".
Only if it is: **Manage** → **None of the algorithms mentioned above**.
