.PHONY: all cli ios android macos monitor help \
        cli-build cli-link \
        ios-build ios-run \
        android-build android-run \
        macos-build macos-run

REPO_ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# ── Android SDK ────────────────────────────────────────────────────────────────
ANDROID_SDK   := $(HOME)/Library/Android/sdk
ADB           := $(ANDROID_SDK)/platform-tools/adb
EMULATOR      := $(ANDROID_SDK)/emulator/emulator
ANDROID_AVD   ?= codex_api34

# ── Xcode ──────────────────────────────────────────────────────────────────────
IOS_SCHEME    := Mollotov
IOS_PROJECT   := apps/ios/Mollotov.xcodeproj
IOS_SIM       ?= $(shell xcrun simctl list devices available | grep 'iPhone' | head -1 | sed 's/.*(\([A-F0-9-]*\)).*/\1/')

MACOS_SCHEME  := Mollotov
MACOS_PROJECT := apps/macos/Mollotov.xcodeproj

# ── CLI ────────────────────────────────────────────────────────────────────────
CLI_DIR       := packages/cli

# ── Targets ────────────────────────────────────────────────────────────────────

help:
	@echo ""
	@echo "  make cli          Build CLI and link to system (mollotov command)"
	@echo "  make ios          Build and launch iOS app in simulator"
	@echo "  make android      Build and launch Android app in emulator"
	@echo "  make macos        Build and launch macOS app"
	@echo "  make monitor      Start monitoring API + dashboard (see monitoring/)"
	@echo ""
	@echo "  Env overrides:"
	@echo "    IOS_SIM=<uuid>       Use a specific iOS simulator"
	@echo "    ANDROID_AVD=<name>   Use a specific Android AVD (default: $(ANDROID_AVD))"
	@echo ""

# ── CLI ────────────────────────────────────────────────────────────────────────

cli: cli-build cli-link

cli-build:
	@echo "→ Building CLI..."
	pnpm --filter @unlikeotherai/mollotov build

cli-link:
	@echo "→ Linking mollotov to system..."
	cd $(CLI_DIR) && pnpm link --global
	@echo "✓ mollotov linked — run 'mollotov --help' to verify"

# ── iOS ────────────────────────────────────────────────────────────────────────

ios: ios-build ios-run

ios-build:
	@echo "→ Building iOS app (simulator)..."
	xcodebuild \
		-project $(IOS_PROJECT) \
		-scheme $(IOS_SCHEME) \
		-destination 'platform=iOS Simulator,id=$(IOS_SIM)' \
		-configuration Debug \
		-derivedDataPath apps/ios/.build \
		build | xcpretty 2>/dev/null || xcodebuild \
		-project $(IOS_PROJECT) \
		-scheme $(IOS_SCHEME) \
		-destination 'platform=iOS Simulator,id=$(IOS_SIM)' \
		-configuration Debug \
		-derivedDataPath apps/ios/.build \
		build

ios-run:
	@echo "→ Booting simulator $(IOS_SIM)..."
	xcrun simctl boot $(IOS_SIM) 2>/dev/null || true
	open -a Simulator
	@APP_PATH=$$(find apps/ios/.build -name "Mollotov.app" -not -path "*iphonesimulator.xcarchive*" 2>/dev/null | head -1); \
	echo "→ Installing $$APP_PATH ..."; \
	xcrun simctl install $(IOS_SIM) "$$APP_PATH"; \
	echo "→ Launching..."; \
	xcrun simctl launch $(IOS_SIM) com.unlikeotherai.mollotov

# ── Android ────────────────────────────────────────────────────────────────────

android: android-build android-run

android-build:
	@echo "→ Building Android APK (debug)..."
	cd apps/android && ./gradlew assembleDebug

android-run:
	@echo "→ Checking for running emulator..."
	@if ! $(ADB) devices | grep -q emulator; then \
		echo "→ Starting emulator $(ANDROID_AVD)..."; \
		$(EMULATOR) -avd $(ANDROID_AVD) -no-snapshot-save &>/dev/null & \
		echo "→ Waiting for emulator to boot..."; \
		$(ADB) wait-for-device shell 'while [[ -z $$(getprop sys.boot_completed) ]]; do sleep 1; done'; \
	fi
	@APK=$$(find apps/android -name "app-debug.apk" | head -1); \
	echo "→ Installing $$APK ..."; \
	$(ADB) install -r "$$APK"; \
	echo "→ Launching..."; \
	$(ADB) shell am start -n com.mollotov.browser/.MainActivity

# ── macOS ──────────────────────────────────────────────────────────────────────

macos: macos-build macos-run

macos-build:
	@echo "→ Building macOS app..."
	xcodebuild \
		-project $(MACOS_PROJECT) \
		-scheme $(MACOS_SCHEME) \
		-configuration Debug \
		-derivedDataPath apps/macos/.build \
		build | xcpretty 2>/dev/null || xcodebuild \
		-project $(MACOS_PROJECT) \
		-scheme $(MACOS_SCHEME) \
		-configuration Debug \
		-derivedDataPath apps/macos/.build \
		build

macos-run:
	@APP_PATH=$$(find apps/macos/.build -name "Mollotov.app" 2>/dev/null | head -1); \
	echo "→ Launching $$APP_PATH ..."; \
	open "$$APP_PATH"

# ── Monitoring ─────────────────────────────────────────────────────────────────

monitor:
	$(MAKE) -C monitoring monitor
