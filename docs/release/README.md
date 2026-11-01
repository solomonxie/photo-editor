# App Store Release

Bundle ID `com.example.photoeditor.app` (yours — set `APP_NAMESPACE` in `Config/Local.xcconfig`) · iOS 17.0+ · iPhone only, portrait.

- [`listing.md`](listing.md) — step-by-step plan and every App Store Connect field, ready to paste
- [`privacy-policy.md`](privacy-policy.md) — the policy; its GitHub URL is the Privacy Policy URL
- `screenshots/` — 3 shots (Home, Beauty, Hair), 2026-10-03, from the iPhone with a non-personal portrait; `make screenshots SHOTS=<dir>` to add more.
  Gitignored (public repo, and earlier sets showed real photos). The current set shows a generated portrait, so it is safe to commit if you want it in the repo; see [Screenshots](listing.md#screenshots).

Before the first build: `cp Config/Local.xcconfig.example Config/Local.xcconfig` and put your
Apple Developer Team ID in it. It is gitignored — an account identifier does not belong in a
public repo.

Upload a build: `make release` — generates the project, builds, archives, signs, uploads.
Nothing in Xcode. Build number is a timestamp unless you pass `BUILD=`. `make help` lists the rest.

Versioning: `MARKETING_VERSION` in `project.yml` is the user-visible version; bump it per
release. `CURRENT_PROJECT_VERSION` is set per upload by the script and never committed.
