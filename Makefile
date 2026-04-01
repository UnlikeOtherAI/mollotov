.PHONY: all cli ios android macos monitor help \
        cli-build cli-link \
        ios-build ios-run \
        android-build android-run android-ensure-avd \
        macos-build macos-run

REPO_ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# ── Android SDK ────────────────────────────────────────────────────────────────
ANDROID_SDK   := $(HOME)/Library/Android/sdk
ADB           := $(ANDROID_SDK)/platform-tools/adb
EMULATOR      := $(ANDROID_SDK)/emulator/emulator
AVDMANAGER    := $(ANDROID_SDK)/cmdline-tools/latest/bin/avdmanager
SDKMANAGER    := $(ANDROID_SDK)/cmdline-tools/latest/bin/sdkmanager
ANDROID_AVD   ?= codex_api34

# ── Xcode ──────────────────────────────────────────────────────────────────────
IOS_SCHEME    := Mollotov
IOS_PROJECT   := apps/ios/Mollotov.xcodeproj

MACOS_SCHEME  := Mollotov
MACOS_PROJECT := apps/macos/Mollotov.xcodeproj

# ── CLI ────────────────────────────────────────────────────────────────────────
CLI_DIR       := packages/cli

# ── Targets ────────────────────────────────────────────────────────────────────

help:
	@echo ""
	@echo "  make cli          Build CLI and link to system (mollotov command)"
	@echo "  make ios          Build and launch iOS app (interactive device picker)"
	@echo "  make android      Build and launch Android app (auto-creates AVD if needed)"
	@echo "  make macos        Build and launch macOS app"
	@echo "  make monitor      Start monitoring API + dashboard (see monitoring/)"
	@echo ""
	@echo "  Env overrides:"
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
# Interactive device/simulator picker. Remembers last selection in .cache/ios-device.
# Override by setting IOS_TARGET=<udid_or_identifier> IOS_TARGET_TYPE=simulator|device.

ios:
	@TARGET_LINE=$$(bash scripts/ios-select.sh); \
	IOS_TARGET=$$(echo "$$TARGET_LINE" | cut -f1); \
	IOS_TYPE=$$(echo "$$TARGET_LINE" | cut -f2); \
	$(MAKE) ios-build IOS_TARGET="$$IOS_TARGET" IOS_TYPE="$$IOS_TYPE"; \
	$(MAKE) ios-run   IOS_TARGET="$$IOS_TARGET" IOS_TYPE="$$IOS_TYPE"

ios-build:
	@if [ "$(IOS_TYPE)" = "device" ]; then \
		echo "→ Building iOS app (device $(IOS_TARGET))..."; \
		xcodebuild \
			-project $(IOS_PROJECT) \
			-scheme $(IOS_SCHEME) \
			-destination 'platform=iOS,id=$(IOS_TARGET)' \
			-configuration Debug \
			-derivedDataPath apps/ios/.build \
			build | xcpretty 2>/dev/null || xcodebuild \
			-project $(IOS_PROJECT) \
			-scheme $(IOS_SCHEME) \
			-destination 'platform=iOS,id=$(IOS_TARGET)' \
			-configuration Debug \
			-derivedDataPath apps/ios/.build \
			build; \
	else \
		echo "→ Building iOS app (simulator $(IOS_TARGET))..."; \
		xcodebuild \
			-project $(IOS_PROJECT) \
			-scheme $(IOS_SCHEME) \
			-destination 'platform=iOS Simulator,id=$(IOS_TARGET)' \
			-configuration Debug \
			-derivedDataPath apps/ios/.build \
			build | xcpretty 2>/dev/null || xcodebuild \
			-project $(IOS_PROJECT) \
			-scheme $(IOS_SCHEME) \
			-destination 'platform=iOS Simulator,id=$(IOS_TARGET)' \
			-configuration Debug \
			-derivedDataPath apps/ios/.build \
			build; \
	fi

ios-run:
	@if [ "$(IOS_TYPE)" = "device" ]; then \
		APP_PATH=$$(find apps/ios/.build -name "Mollotov.app" -not -path "*simulator*" 2>/dev/null | head -1); \
		echo "→ Installing on device $(IOS_TARGET) ..."; \
		xcrun devicectl device install app --device $(IOS_TARGET) "$$APP_PATH"; \
		echo "→ Launching..."; \
		xcrun devicectl device process launch --device $(IOS_TARGET) com.unlikeotherai.mollotov; \
	else \
		echo "→ Booting simulator $(IOS_TARGET)..."; \
		xcrun simctl boot $(IOS_TARGET) 2>/dev/null || true; \
		open -a Simulator; \
		APP_PATH=$$(find apps/ios/.build -name "Mollotov.app" -not -path "*iphonesimulator.xcarchive*" 2>/dev/null | head -1); \
		echo "→ Installing $$APP_PATH ..."; \
		xcrun simctl install $(IOS_TARGET) "$$APP_PATH"; \
		echo "→ Launching..."; \
		xcrun simctl launch $(IOS_TARGET) com.unlikeotherai.mollotov; \
	fi

# ── Android ────────────────────────────────────────────────────────────────────

android: android-build android-run

android-build:
	@echo "→ Building Android APK (debug)..."
	cd apps/android && ./gradlew assembleDebug

android-ensure-avd:
	@if ! $(AVDMANAGER) list avd -c 2>/dev/null | grep -qx "$(ANDROID_AVD)"; then \
		echo "→ AVD '$(ANDROID_AVD)' not found — creating it..."; \
		$(SDKMANAGER) --install "system-images;android-34;google_apis;arm64-v8a" 2>&1 | grep -v '^\[='; \
		echo no | $(AVDMANAGER) create avd \
			--name "$(ANDROID_AVD)" \
			--package "system-images;android-34;google_apis;arm64-v8a" \
			--device "pixel_7" \
			--force 2>&1; \
		echo "✓ AVD '$(ANDROID_AVD)' created"; \
	fi

android-run: android-ensure-avd
	@echo "→ Checking for running emulator..."
	@if ! $(ADB) devices | grep -q emulator; then \
		echo "→ Starting emulator $(ANDROID_AVD)..."; \
		$(EMULATOR) -avd $(ANDROID_AVD) -no-snapshot-save &>/dev/null & \
		echo "→ Waiting for emulator to boot..."; \
		$(ADB) wait-for-device; \
		$(ADB) shell 'while [ "$$(getprop sys.boot_completed)" != "1" ]; do sleep 1; done'; \
		echo "✓ Emulator ready"; \
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
