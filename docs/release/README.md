# App Store Release

Bundle ID `com.example.photoeditor.app` · iOS 17.0+ · iPhone only, portrait.

- [`listing.md`](listing.md) — step-by-step plan and every App Store Connect field, ready to paste
- [`privacy-policy.md`](privacy-policy.md) — the policy; its GitHub URL is the Privacy Policy URL
- `screenshots/6.9`, `screenshots/6.5` — upload-ready, from `make screenshots SHOTS=<dir>`.
  **Gitignored:** they show real photos, and this repo is public.

Before the first build: `cp Config/Local.xcconfig.example Config/Local.xcconfig` and put your
Apple Developer Team ID in it. It is gitignored — an account identifier does not belong in a
public repo.

Upload a build: `make release` — generates the project, builds, archives, signs, uploads.
Nothing in Xcode. Build number is a timestamp unless you pass `BUILD=`. `make help` lists the rest.

Versioning: `MARKETING_VERSION` in `project.yml` is the user-visible version; bump it per
release. `CURRENT_PROJECT_VERSION` is set per upload by the script and never committed.
