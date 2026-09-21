# ================= CONFIGURATION =================
# Path to the Connect IQ SDK 'bin' folder.
# Resolved from the SDK manager's own pointer, so it follows whatever SDK is
# currently selected and needs no edit when the SDK is updated.
#   ~/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg
# macOS only. On another platform, pass CIQ_HOME or SDK_BIN explicitly.
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

# How long "make sideload" keeps looking for a watch before giving up. Empty --
# the default -- is no looking at all: the first probe decides, which is the right
# behaviour for a watch that is already plugged in. WAIT=1 turns the wait on with
# the script's own budget, WAIT=<n> bounds it at n seconds; tools/sideload.sh
# carries both. WAIT_EVERY is how long to leave between looks: each one opens a
# USB session, so this is deliberately slow rather than a tight loop.
WAIT ?=
WAIT_EVERY ?= 60

# TCP port the Connect IQ simulator listens on. Probing the port reports that the
# simulator is accepting connections, which is what monkeydo needs -- the app being
# launched is not enough, since "open -a" returns long before the port is up.
SIM_PORT ?= 1234
# =================================================

# Commands
MONKEYC := "$(SDK_BIN)/monkeyc"
MONKEYDO := "$(SDK_BIN)/monkeydo"
CONNECTIQ := "$(SDK_BIN)/connectiq"

# The sub-make sideload runs, held at one remove on purpose. make executes a
# recipe line that literally contains "$$(MAKE)" even under -n, so spelling it
# directly there would make "make -n sideload" detect the watch and transfer to
# it -- a dry run with a side effect on hardware. Behind a variable the line is
# only printed, and the flags a sub-make needs still reach it through MAKEFLAGS,
# which is exported either way.
SUBMAKE := $(MAKE)

# Fail with a readable message rather than "No such file or directory".
# Checked inside the recipes rather than at parse time, so targets that need no
# SDK -- clean, check-fonts, check-icons -- still work on a machine without one.
# The test goes through the shell with the path quoted: make's own text functions
# split on whitespace, and the macOS path contains "Application Support".
define require_sdk
@test -x "$(SDK_BIN)/monkeyc" || { \
  echo "Connect IQ SDK not found at \"$(SDK_BIN)\"."; \
  echo "Open the SDK manager and select an SDK, or override:"; \
  echo "  make $@ SDK_BIN=/path/to/sdk/bin"; \
  exit 1; }
endef

# Flags
# -w: warn, -y: private key, -d: device, -f: jungle file, -o: output
BUILD_FLAGS := -w -y "$(DEV_KEY)" -d $(DEVICE) -f monkey.jungle
TEST_FLAGS := -w -y "$(DEV_KEY)" -d $(DEVICE) -f monkey.jungle --unit-test

.PHONY: all build sim run test sideload check-fonts icons check-icons clean

all: build

build:
	$(require_sdk)
	@echo "Building for $(DEVICE)..."
	@$(MONKEYC) $(BUILD_FLAGS) -o $(OUTPUT)
	@echo "Build complete: $(OUTPUT)"

# monkeydo only pushes a .prg into a simulator that is already running, so both
# run and test depend on this target. It starts the simulator when the port is
# closed and waits, bounded, for it to accept connections. The launcher is checked
# separately from require_sdk, which only covers monkeyc: a partial SDK without
# connectiq would otherwise fail silently in the background and be reported, sixty
# seconds later, as a port that never opened.
sim:
	$(require_sdk)
	@if nc -z 127.0.0.1 $(SIM_PORT) 2>/dev/null; then \
	  echo "Simulator already running."; \
	else \
	  test -x $(CONNECTIQ) || { \
	    echo "Simulator launcher not found at $(CONNECTIQ)."; \
	    echo "Open the SDK manager and select an SDK, or override:"; \
	    echo "  make $@ SDK_BIN=/path/to/sdk/bin"; \
	    exit 1; }; \
	  echo "Starting simulator..."; \
	  $(CONNECTIQ) & \
	  n=0; \
	  until nc -z 127.0.0.1 $(SIM_PORT) 2>/dev/null; do \
	    n=$$((n+1)); \
	    test $$n -lt 60 || { \
	      echo "Simulator did not open port $(SIM_PORT) within $$n seconds."; \
	      echo "Start it by hand and retry:  $(CONNECTIQ)"; \
	      echo "If it came up on another port, re-run with SIM_PORT=<port>."; \
	      exit 1; }; \
	    sleep 1; \
	  done; \
	  echo "Simulator ready."; \
	fi

# monkeydo does not return once the .prg is pushed. MonkeyDoDeux spawns the SDK's
# own "shell", which stays attached for the life of the app session and relays the
# app's console output to this terminal, so the command sits in the foreground
# while the watch face runs. Every other target here ends on a terminal state --
# "Build complete", "Simulator ready." -- so a run that stops on "Loading" reads as
# a hang even though the app started (#73). Announce the whole sequence up front
# rather than after the fact: there is no point at which the push can be observed
# to have finished. #66 was the same mistake one step earlier in this target.
run: build sim
	@echo "Loading $(OUTPUT) into simulator..."
	@echo "monkeydo then stays attached to relay the app's console output, so this"
	@echo "command does not return -- press Ctrl-C when you are done with the run."
	@$(MONKEYDO) $(OUTPUT) $(DEVICE)

# monkeydo's output is printed rather than piped straight into grep: piping hid
# every real failure behind a bare "Error 1" from grep matching nothing.
#
# Its exit status is not consulted, because it carries nothing: monkeydo exits 1 on a
# suite that passes every test and 1 on a suite that fails one, measured both ways on
# SDK 9.2.0. What the status used to gate was therefore an unconditional failure once
# there were tests to run at all. The summary line is the only signal there is, and it
# is unambiguous -- "PASSED (passed=N, failed=0, errors=0)" or "FAILED (...)" in the
# first column -- so the grep is anchored there rather than matching the word anywhere
# in the log, where a test name could supply it (#23).
test: sim
	$(require_sdk)
	@echo "Running Unit Tests..."
	@$(MONKEYC) $(TEST_FLAGS) -o test_build.prg
	@echo "Loading tests into simulator..."
	@output=$$($(MONKEYDO) test_build.prg $(DEVICE) -t 2>&1); \
	  echo "$$output"; \
	  echo "$$output" | grep -qE '^PASSED \(' || { \
	    echo "Unit tests did not report PASSED."; exit 1; }

# Sideloading goes over MTP rather than mass storage. macOS does not mount MTP
# devices as volumes -- which is what OpenMTP exists to work around -- and the
# epix Pro (Gen 2) presents nothing macOS will mount: with the watch attached,
# /Volumes stays empty and the watch answers as MTP. The transfer therefore needs
# libmtp ("brew install libmtp"); tools/sideload.sh says so if it is missing, and
# carries the rest of the detail, the awkward parts of libmtp's CLI included.
#
# The device is read off the watch rather than assumed, because a .prg built for
# another product installs without complaint and only fails once the watch tries
# to run it. DEVICE is therefore resolved from the watch by default. An explicit
# DEVICE -- on the command line or in the environment, which "origin" separates
# from this file's own default -- is honoured but checked against the watch, so a
# mismatch is reported rather than silently overridden either way. A watch this
# face does not support is caught here too, against manifest.xml, rather than
# left to surface as a compiler error about an unknown product.
#
# An explicit DEVICE is also the way out when detection cannot answer -- a watch
# whose device definition is not downloaded, say. That is why the script separates
# "no watch answered" (exit 2) from "something went wrong" (exit 1): the first is
# fatal whatever DEVICE says, since there is nothing to install to, while the
# second is exactly what naming the device is for. Without that split the advice
# those errors print, to re-run with DEVICE set, could not be followed: detection
# runs first and would fail again the same way.
#
# The wait is a separate call ahead of all that, and unconditional: with WAIT
# unset the script returns without looking at anything or printing anything, so
# the ordinary run is the one it always was. Keeping the whole spelling of WAIT --
# what counts as "yes", what the default budget is -- in one place there beats
# splitting it between a make conditional and a shell case.
#
# build is reached through a sub-make (SUBMAKE, see above) rather than named as a
# prerequisite: the
# device has to be known before the binary is compiled, and a prerequisite would
# have built for the default DEVICE before the watch was ever consulted. The
# binary is still always current, which is what that ordering is for.
sideload:
	$(require_sdk)
	@tools/sideload.sh wait "$(WAIT)" "$(WAIT_EVERY)" || exit 1
	@watch=$$(CIQ_HOME="$(CIQ_HOME)" tools/sideload.sh detect) && rc=0 || rc=$$?; \
	if [ $$rc -eq 2 ]; then \
	  exit 1; \
	elif [ $$rc -ne 0 ]; then \
	  test "$(origin DEVICE)" != "file" || exit 1; \
	  watch=$(DEVICE); \
	  echo "Building for DEVICE=$$watch as asked; the watch could not confirm it."; \
	else \
	  if [ "$(origin DEVICE)" != "file" ] && [ "$$watch" != "$(DEVICE)" ]; then \
	    echo "DEVICE=$(DEVICE) was asked for, but the watch is a $$watch."; \
	    echo "A .prg built for another product fails on the watch rather than at"; \
	    echo "install time, so this is refused. Drop DEVICE to build for the watch."; \
	    exit 1; \
	  fi; \
	  echo "Watch detected: $$watch"; \
	fi; \
	grep -q '<iq:product id="'"$$watch"'"/>' manifest.xml || { \
	  echo "The watch is a $$watch, which this face does not support:"; \
	  echo "manifest.xml lists no <iq:product> for it, so there is nothing to build."; \
	  echo "Matrix Time is AMOLED-only; see \"Features\" in README.md."; \
	  exit 1; }; \
	$(SUBMAKE) --no-print-directory build DEVICE=$$watch && \
	tools/sideload.sh install $(OUTPUT)

check-fonts:
	@echo "Checking font configuration consistency..."
	@python3 tools/check-font-config.py

# The launcher icon size is a per-device property, not a per-resolution one, so the
# icons and the per-product jungle mapping that serves them are generated from the
# SDK's device definitions rather than maintained by hand (#42). The generator
# rewrites the block between the markers in monkey.jungle in place.
icons:
	@echo "Generating launcher icons..."
	@python3 tools/make-launcher-icons.py

check-icons:
	@echo "Checking launcher icon configuration consistency..."
	@python3 tools/make-launcher-icons.py --check

clean:
	@rm -Rf $(OUTPUT) test_build* *.debug.xml bin/ deploy/ gen/ internal-mir/ external-mir/ export/ 
	@echo "Clean complete."