# ================= CONFIGURATION =================
# Path to your Connect IQ SDK 'bin' folder
# Example (Mac): /Users/username/Library/Application Support/Garmin/ConnectIQ/Sdks/sdks/6.4.0/bin
# Example (Win): C:/Users/username/AppData/Roaming/Garmin/ConnectIQ/Sdks/sdks/6.4.0/bin
SDK_BIN ?= /Users/waku/Library/Application_Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.0-2025-12-03-5122605dc/bin

# Path to your developer key (generated via SDK manager or openssl)
DEV_KEY ?= ../garmin-keys/developer_key

# The device to simulate (must match one in manifest.xml)
DEVICE ?= fenix7xpronowifi

# Output filename
OUTPUT := {blank:ucname}Time.prg
# =================================================

# Commands
MONKEYC := "$(SDK_BIN)/monkeyc"
MONKEYDO := "$(SDK_BIN)/monkeydo"

# Flags
# -w: warn, -y: private key, -d: device, -f: jungle file, -o: output
BUILD_FLAGS := -w -y "$(DEV_KEY)" -d $(DEVICE) -f monkey.jungle
TEST_FLAGS := -w -y "$(DEV_KEY)" -d $(DEVICE) -f monkey.jungle --unit-test

.PHONY: all build run test clean

all: build

build:
	@echo "Building for $(DEVICE)..."
	@$(MONKEYC) $(BUILD_FLAGS) -o $(OUTPUT)
	@echo "Build complete: $(OUTPUT)"

run: build
	@echo "Launching simulator for $(DEVICE)..."
	@$(MONKEYDO) $(OUTPUT) $(DEVICE)

test:
	@echo "Running Unit Tests..."
	@$(MONKEYC) $(TEST_FLAGS) -o test_build.prg
	@echo "Loading tests into simulator..."
	@$(MONKEYDO) test_build.prg $(DEVICE) -t | grep PASSED

clean:
	@rm -Rf $(OUTPUT) test_build* *.debug.xml bin/ deploy/ gen/ internal-mir/ external-mir/ export/ 
	@echo "Clean complete."