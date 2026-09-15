# ================= CONFIGURATION =================
# Path to the Connect IQ SDK 'bin' folder.
# Resolved from the SDK manager's own pointer, so it follows whatever SDK is
# currently selected and needs no edit when the SDK is updated.
#   Mac: ~/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg
#   Win: %APPDATA%/Garmin/ConnectIQ/current-sdk.cfg
# Override for CI or a pinned build:  make build SDK_BIN=/path/to/sdk/bin
CIQ_HOME ?= $(HOME)/Library/Application Support/Garmin/ConnectIQ
# Trailing slashes are stripped in the shell: the file's format is not guaranteed,
# and make's own text functions split on whitespace, which the macOS path contains.
SDK_BIN  ?= $(shell sed -e 's:/*$$::' "$(CIQ_HOME)/current-sdk.cfg" 2>/dev/null)/bin

# Path to your developer key (generated via SDK manager or openssl)
DEV_KEY ?= ../garmin-keys/developer_key

# The device to simulate (must match one in manifest.xml)
DEVICE ?= epix2pro47mm

# Output filename
OUTPUT := MatrixTime.prg
# =================================================

# Commands
MONKEYC := "$(SDK_BIN)/monkeyc"
MONKEYDO := "$(SDK_BIN)/monkeydo"

# Fail with a readable message rather than "No such file or directory".
# $(wildcard) splits on spaces, and the macOS path contains "Application Support",
# so the existence test has to go through the shell with the path quoted.
ifeq ($(shell test -x "$(SDK_BIN)/monkeyc" && echo found),)
  $(error Connect IQ SDK not found at "$(SDK_BIN)". Open the SDK manager and \
select an SDK, or override: make $(MAKECMDGOALS) SDK_BIN=/path/to/sdk/bin)
endif

# Flags
# -w: warn, -y: private key, -d: device, -f: jungle file, -o: output
BUILD_FLAGS := -w -y "$(DEV_KEY)" -d $(DEVICE) -f monkey.jungle
TEST_FLAGS := -w -y "$(DEV_KEY)" -d $(DEVICE) -f monkey.jungle --unit-test

.PHONY: all build run test check-fonts clean

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

check-fonts:
	@echo "Checking font configuration consistency..."
	@python3 tools/check-font-config.py

clean:
	@rm -Rf $(OUTPUT) test_build* *.debug.xml bin/ deploy/ gen/ internal-mir/ external-mir/ export/ 
	@echo "Clean complete."