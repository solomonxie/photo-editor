.PHONY: help check test ios release screenshots icon

.DEFAULT_GOAL := help

help:
	@echo "make ios          Release build onto the paired iPhone"
	@echo "make release      check, then archive + upload to App Store Connect"
	@echo "make release BUILD=202609261830   same, with the build number pinned"
	@echo "make check        generate the project and build Release"
	@echo "make test         unit tests + 48 MP benchmark on the paired iPhone"
	@echo "make screenshots  SHOTS=<dir>  resize to the App Store slots"
	@echo "make icon         regenerate the app icon PNGs"

check:
	xcodegen generate
	xcodebuild -project PhotoEditor.xcodeproj -scheme PhotoEditor -configuration Release \
	  -destination 'generic/platform=iOS' -derivedDataPath build/check -quiet build
	@echo "Release build OK"

test:
	xcodegen generate
	xcodebuild test -project PhotoEditor.xcodeproj -scheme PhotoEditor \
	  -destination "id=$$(xcrun devicectl list devices 2>/dev/null | awk '/available \(paired\)/ && /physical/ {for (i=1;i<=NF;i++) if ($$i ~ /^[0-9A-F]{8}-[0-9A-F]{16}$$/) print $$i; exit}')" \
	  -derivedDataPath build/test | grep -E "PERF (open|slider|export|foot)|error:|TEST (SUCC|FAIL)"

ios:
	scripts/install-ios.sh

# Archive, sign for the App Store and upload — no Xcode Organizer.
# Needs Config/Local.xcconfig (Team ID) and the app record already created in
# App Store Connect. Uploads whatever is on disk, so say so when that is not a commit.
release: check
	@git diff --quiet HEAD -- || echo "warning: uncommitted changes are going into this build"
	scripts/release-ios.sh $(BUILD)

screenshots:
	scripts/store-screenshots.sh $(SHOTS)

icon:
	swiftc -O scripts/make-icon.swift -o /tmp/make-icon
	for v in light dark tinted; do /tmp/make-icon PhotoEditor/Assets.xcassets/AppIcon.appiconset/icon-$$v.png $$v; done
