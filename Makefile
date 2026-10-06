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

# Which edition to build: lite, the free one, or premium, the paid one (#135). One
# source tree builds both. The edition picks the jungle list, the manifest -- and so
# the application id -- and the output names, so the two never overwrite each other.
#
# The edition jungle comes LAST in the list, always. It appends its exclusion to
# base.excludeAnnotations; a jungle layered after it that replaced the list, as
# graphics.jungle does, would silently drop it. See monkey.jungle.
EDITION ?= lite
ifeq ($(EDITION),lite)
  MANIFEST := manifest.xml
  APP := MatrixTime
else ifeq ($(EDITION),premium)
  MANIFEST := manifest-premium.xml
  APP := MatrixTimePremium
else
  $(error EDITION must be lite or premium, not "$(EDITION)")
endif
JUNGLES := monkey.jungle;$(EDITION).jungle

# Output filename
OUTPUT := $(APP).prg

# RELEASE=1 builds the .prg the way "make export" builds the bundle: -r, no debug
# information. Only a release build can be compared byte for byte -- a debug build
# embeds the absolute build path and line numbers -- which is what "make check-lite"
# does with it (#35, finding 4). Empty, the default, keeps the debug symbols the
# simulator and the profiler use.
RELEASE ?=

# The store bundle "make export" produces: one signed package covering every
# product in the edition's manifest, not one device's binary. Written under export/,
# which "make clean" already removes -- it is an upload artefact, not a build tree.
EXPORT_DIR := export
EXPORT := $(EXPORT_DIR)/$(APP).iq

# The products "make check-lite" compares Lite on. One is enough to catch a Premium
# file on Lite's path; CI passes one product per device family.
DEVICES ?= $(DEVICE)

# How long "make sideload" keeps looking for a watch before giving up. Empty --
# the default -- is no looking at all: the first probe decides, which is the right
# behaviour for a watch that is already plugged in. WAIT=1 turns the wait on with
# the script's own budget, WAIT=<n> bounds it at n seconds; tools/sideload.sh
# carries both. EVERY is the gap between one look and the next: a look is a single
# mtp-detect that answers in well under a second, but it opens a USB session to do
# it, so the loop is deliberately unhurried rather than tight.
WAIT ?=
EVERY ?= 60

# TCP port the Connect IQ simulator listens on. Probing the port reports that the
# simulator is accepting connections, which is what monkeydo needs -- the app being
# launched is not enough, since "open -a" returns long before the port is up.
SIM_PORT ?= 1234

# Container platform for "make graphics". The Connect IQ tester image the capture
# runs in is built for amd64 only, so an arm64 machine has to ask for it explicitly
# and accept emulation: PLATFORM=linux/amd64. Empty on an amd64 machine, where
# Docker picks the right one by itself.
PLATFORM ?=

# The zone "make graphics" captures in, and so the time the captured face shows.
# Named TZ_NAME rather than TZ because TZ is a real environment variable: make
# exports what it inherits, so a target testing $(TZ) would follow the developer's
# own clock setting rather than an explicit choice, and behave differently on two
# machines for no visible reason.
TZ_NAME ?=
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
BUILD_FLAGS := $(if $(RELEASE),-r,) -w -y "$(DEV_KEY)" -d $(DEVICE) -f "$(JUNGLES)"
TEST_FLAGS := -w -y "$(DEV_KEY)" -d $(DEVICE) -f "$(JUNGLES)" --unit-test
# -e: package the app, -r: strip debug information. No -d: the package covers every
# product the edition's manifest names, which is the whole point of it. -r is the difference
# between this and build: the .prg keeps its debug symbols so the simulator and the
# profiler can say something useful, and the shipped bundle has no use for them.
EXPORT_FLAGS := -e -r -w -y "$(DEV_KEY)" -f "$(JUNGLES)"

.PHONY: all build sim run test sideload export check-fonts check-manifests check-lite \
        icons check-icons graphics hero preview clean

all: build

build:
	$(require_sdk)
	@echo "Building $(EDITION) for $(DEVICE)..."
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
# face does not support is caught here too, against the manifest, rather than
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
	@tools/sideload.sh wait "$(WAIT)" "$(EVERY)" || exit 1
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
	grep -q '<iq:product id="'"$$watch"'"/>' $(MANIFEST) || { \
	  echo "The watch is a $$watch, which this face does not support:"; \
	  echo "$(MANIFEST) lists no <iq:product> for it, so there is nothing to build."; \
	  echo "Matrix Time is AMOLED-only; see \"Features\" in README.md."; \
	  exit 1; }; \
	$(SUBMAKE) --no-print-directory build DEVICE=$$watch && \
	tools/sideload.sh install $(OUTPUT)

# The store bundle. "export" is also a GNU make directive, but only when what
# follows on the line is a variable name or an assignment; with a colon it is an
# ordinary rule, and has been since 3.81, the make macOS ships. Do not rename it
# on that suspicion.
#
# This is the one build whose output is uploaded, and the only one that compiles
# every product rather than one, so it is also where a device that breaks the
# packaging step shows up. monkeyc counts part numbers rather than products as it
# goes, so it reports more devices than manifest.xml lists: several products ship
# under more than one part, venu2 under four.
# monkeyc prints one progress line per device, "<n> OUT OF <total> DEVICES BUILT",
# with the counter left-aligned, so the whole line jogs right as n gains a digit.
# Pad n to the width of the total and the column stands still. Three things the
# filter must not break, hence its shape:
#
#   - monkeyc's exit status. A pipeline reports its LAST command's status, so a
#     plain "monkeyc | awk" would report awk's and make every failed export look
#     successful. "set -o pipefail" is not portable to every shell make might run
#     a recipe under, so the status crosses the pipe as a sentinel line that awk
#     strips and exits with;
#   - stderr, which stays out of the pipe entirely. Only stdout carries the
#     progress lines, so a compiler error reaches the terminal unfiltered and
#     unbuffered, exactly as before;
#   - live output. The counter is the only sign the build is moving, so awk
#     flushes per line rather than holding 65 of them until the end.
#
# Any line the pattern does not match passes through untouched: BUILD SUCCESSFUL,
# warnings, errors, and whatever monkeyc adds next.
EXPORT_STATUS := __monkeyc_status__:

export:
	$(require_sdk)
	@echo "Exporting $(EXPORT) for every product in $(MANIFEST)..."
	@mkdir -p $(EXPORT_DIR)
	@{ $(MONKEYC) $(EXPORT_FLAGS) -o $(EXPORT); echo "$(EXPORT_STATUS)$$?"; } | awk -v s='$(EXPORT_STATUS)' '\
	  index($$0, s) == 1 { status = substr($$0, length(s) + 1); next } \
	  $$0 ~ /^[0-9]+ OUT OF [0-9]+ DEVICES BUILT$$/ { \
	    printf "%*d OUT OF %s DEVICES BUILT\n", length($$4), $$1, $$4; fflush(); next } \
	  { print; fflush() } \
	  END { exit status + 0 }'
	@echo "Export complete: $(EXPORT)"

check-fonts:
	@echo "Checking font configuration consistency..."
	@python3 tools/check-font-config.py

# manifest-premium.xml duplicates manifest.xml's product list, and everything else
# in it but the application id, name and version. Checked rather than generated:
# the duplicate is small, a generator would be one more step to forget before a
# commit, and a check in CI cannot be forgotten (#135). Pure Python, no SDK.
check-manifests:
	@echo "Checking the edition manifests against each other..."
	@python3 tools/check-manifests.py

# The Lite invariant (#135): a change that touches only Premium files -- premium/,
# premium.jungle, manifest-premium.xml -- must leave the Lite release build byte for
# byte what it was. The script builds Lite twice per product, here and in a copy of
# the tree with the Premium files deleted, and compares the release PRGs. Release,
# not debug, because a debug build embeds the build path (#35, finding 4).
check-lite:
	$(require_sdk)
	@SDK_BIN="$(SDK_BIN)" DEV_KEY="$(DEV_KEY)" tools/check-lite-invariant.sh $(DEVICES)

# The launcher icon size is a per-device property, not a per-resolution one, so the
# icons and the per-product jungle mapping that serves them are generated from the
# SDK's device definitions rather than maintained by hand (#42). The generator
# rewrites the block between the markers in monkey.jungle in place.
#
# Both editions, every time: Premium's icons are Lite's with a gold star (#189), so a
# change to Lite's artwork is a change to Premium's too. Lite's come from the local
# tools/make-launcher-icons.py, until #78 moves them to the shared command. Premium's
# come from the shared garmin-graphics-generator, into premium/resources-icon-<size>/
# and mapped from premium.jungle, which only a Premium build reads -- so Lite never
# sees them, and make check-lite holds. premium/tools/launcher_icon.py is the
# renderer, and also writes and checks the store cover, which the shared command
# knows nothing about.
#
# 0.7.0 is the first release that can target an edition: its own manifest, jungle and
# icon directory. --check needs no SDK, as Lite's does.
#
# The tool runs through the python3 on PATH, not through its garmin-graphics-generator
# script, which may belong to another interpreter (pipx, a venv). That python3 draws
# Lite's icons and the cover, and the tool's -R loads the Premium renderer into its own
# interpreter, so this way one Pillow draws all three. Two Pillows antialias the glyphs
# differently -- 12.1.0 against 12.3.0 at 60 px -- and Premium would quietly stop being
# Lite's icon but for the star.
ICONS_TOOL_VERSION := 0.7.0
ICONS_TOOL := python3 -c 'import sys; from garmin_graphics_generator.cli import main; \
  sys.argv[0] = "garmin-graphics-generator"; sys.exit(main())'
PREMIUM_ICONS := --manifest manifest-premium.xml --jungle premium.jungle --icon-root premium
PREMIUM_FALLBACK := premium/resources-base/drawables/launcher_icon.png
PREMIUM_COVER := premium/graphics/MatrixTimePremiumCover.png

define require_icons_tool
@python3 -c 'from importlib.metadata import version; v = version("garmin_graphics_generator").split("."); \
  raise SystemExit(int(v[0]) == 0 and int(v[1]) < 7)' 2>/dev/null || { \
  echo "make $@ needs garmin-graphics-generator $(ICONS_TOOL_VERSION) or newer, installed for the"; \
  echo "python3 on PATH (python3 -m pip install ...); see README.md."; exit 1; }
endef

icons:
	$(require_icons_tool)
	@echo "Generating launcher icons..."
	@python3 tools/make-launcher-icons.py
	@echo "Generating Premium's launcher icons and store cover..."
	@$(ICONS_TOOL) icons -R premium/tools/launcher_icon.py $(PREMIUM_ICONS) \
	  --fallback-icon $(PREMIUM_FALLBACK)
	@python3 premium/tools/launcher_icon.py cover $(PREMIUM_COVER)

check-icons:
	$(require_icons_tool)
	@echo "Checking launcher icon configuration consistency..."
	@python3 tools/make-launcher-icons.py --check
	@echo "Checking Premium's launcher icons..."
	@$(ICONS_TOOL) icons $(PREMIUM_ICONS) --check
	@python3 premium/tools/launcher_icon.py check $(PREMIUM_FALLBACK) $(PREMIUM_COVER)

# Every image in resources/graphics/ that is generated, regenerated from the current
# build (#125). They used to be made by hand -- run the simulator, capture, resize,
# composite -- which is why #54 could change what the face draws and leave all seven
# showing the old charset for months (#80). A capture is derived from the app but is
# not generated output, so nothing reported them stale.
#
# The exceptions are MatrixTimeHero.png and MatrixTimeHero-small.png, which are
# composed with an image model and are what the store serves (#130); see make hero.
# This target writes MatrixTimeHero-draft.png and its banner instead, and never those
# two, so a capture run cannot overwrite an adopted hero. Recomposing it is owed
# whenever what the face draws changes.
#
# The capture and the hero composition come from garmin-graphics-generator, shared
# with the sibling faces; what is here is the names, the sizes and the reference
# product. It captures through the containerised simulator rather than the desktop
# one, so this needs Docker running and nothing else: no GUI, and no macOS
# screen-recording permission.
#
# PLATFORM is passed through because the Connect IQ tester image is built for amd64
# and an arm64 machine therefore needs to ask for it explicitly.
#
# Two capture runs, not one: MatrixTime5.png is the always-on scene, which the
# simulator will not enter headlessly, so it is captured from a second build whose
# low-power branch is forced -- graphics.jungle layered between monkey.jungle and
# lite.jungle (#128, #135). Expect roughly twice the wait of a woken-only capture,
# since each run compiles the face and starts a container of its own.
#
# EDITION=premium writes Premium's set instead, into premium/graphics/ beside its
# store cover, and leaves Lite's alone (#188): MatrixTimePremium1.png to 5.png and
# MatrixTimePremiumHero-draft.png. Each of its five images is a look rather than a
# moment -- the three built-in presets, a gradient rain, and always-on -- so each is a
# build of its own with its settings as the property defaults, all five in one
# container. MatrixTimePremiumHero.png is never written, as Lite's hero is not.
#
# Both editions also keep the full-size watch renders in HERO_DIR/captures, which is
# what make hero sends to the image model.
graphics:
	@echo "Regenerating the $(EDITION) store images..."
	@python3 tools/make-graphics.py --edition $(EDITION) \
	                                $(if $(PLATFORM),--platform $(PLATFORM),) \
	                                $(if $(TZ_NAME),--timezone $(TZ_NAME),)

# The published hero, composed by an image model from the captures make graphics
# keeps (#188). Two steps, with the model between them:
#
#   make hero EDITION=premium                           prints the prompt, and saves it
#   make hero EDITION=premium CANDIDATES="a.png b.png"  sizes and screens what came back
#
# The first fills in the edition's prompt and writes it to HERO_DIR/prompt.txt, to
# paste into the Gemini app with HERO_DIR/captures/watch-*.png attached. The second
# hands each image the app returned to garmin-graphics-generator compose, which
# crops and resizes it to exactly the store's 1440x720 (and Lite's banner size), and
# screens it: the size and the 2048 KB limit locally, and the watch count and the
# edition's checks file by a vision model. Candidates land in HERO_DIR/candidates,
# numbered on from any already there, and nothing is ever overwritten. Picking one and
# copying it over the published hero is yours to do.
#
# Screening needs a Gemini API key, GEMINI_API_KEY or GEMINI_KEY_FILE=path; the vision
# model it uses is on the free tier. Generating through the API is not, which is why
# the candidates come from the app: compose -g is there for whoever wants to pay.
#
# 0.7.0 is the first release with compose. The PATH tool is fine here: nothing it
# draws has to match a Pillow elsewhere, as the icons do.
HERO_TOOL_VERSION := 0.7.0
HERO_DIR := .dev/scratchpad/hero/$(EDITION)
ifeq ($(EDITION),premium)
  HERO_PROMPT := premium/tools/hero-prompt.txt
  HERO_CHECKS := premium/tools/hero-checks.json
  HERO_SIZES := -s 1440x720
else
  HERO_PROMPT := tools/hero-prompt.txt
  HERO_CHECKS := tools/hero-checks.json
  HERO_SIZES := -s 1440x720 -s 900x450
endif
CANDIDATES ?=
GEMINI_KEY_FILE ?=

hero:
	@garmin-graphics-generator --about 2>/dev/null | awk '/version:/ { split($$NF, v, "."); \
	  found = 1; old = v[1] + 0 == 0 && v[2] + 0 < 7 } END { exit !found || old }' || { \
	  echo "make hero needs garmin-graphics-generator $(HERO_TOOL_VERSION) or newer on PATH; see README.md."; exit 1; }
	@ls $(HERO_DIR)/captures/watch-*.png >/dev/null 2>&1 || { \
	  echo "No captures in $(HERO_DIR)/captures; run make graphics EDITION=$(EDITION) first."; exit 1; }
ifeq ($(strip $(CANDIDATES)),)
	@garmin-graphics-generator compose -p $(HERO_PROMPT) --print-prompt \
	  $(HERO_DIR)/captures/watch-*.png > $(HERO_DIR)/prompt.txt
	@cat $(HERO_DIR)/prompt.txt
	@echo
	@echo "Prompt: $(HERO_DIR)/prompt.txt"
	@echo "Attach: $(HERO_DIR)/captures/watch-*.png"
	@echo "Then:   make hero EDITION=$(EDITION) CANDIDATES=\"<the images the model returned>\""
else
	@garmin-graphics-generator compose -p $(HERO_PROMPT) -o $(HERO_DIR)/candidates \
	  --checks $(HERO_CHECKS) $(HERO_SIZES) $(foreach file,$(CANDIDATES),-c $(file)) \
	  $(if $(GEMINI_KEY_FILE),--key-file $(GEMINI_KEY_FILE),) \
	  $(HERO_DIR)/captures/watch-*.png
endif

# A labelled contact sheet of the face across its settings, for review before a
# setting merges (#140). Not store artwork: it goes to .dev/scratchpad/preview/<edition>/,
# which is gitignored, as contact-sheet.png with one directory of frames per build
# and an index.json saying which settings each holds.
#
# The survey is garmin-graphics-generator's (0.6.0 or newer), shared with the sibling
# faces; what is here is Matrix Time's choice of builds. Each combination of settings
# is a build whose property defaults are rewritten in a copy of the tree inside the
# container, so the tree itself is never written to.
#
# Two scenes, always, so every tile says which screen it shows: woken, and always-on
# from the build graphics.jungle forces into the low-power branch, as make graphics
# captures it. The time colour and the always-on brightness reach the always-on
# screen, and a preview of the woken screen alone would not show them; the time
# size, style and alignment do not, since the always-on time is the filled XL,
# centred, whatever they hold (#164, #154). SCENES=woken, or SCENES=always-on, keeps
# one. The edition jungle comes last in both lists, as in every build.
#
# Premium sweeps every setting, one at a time with the others at their defaults.
# PREVIEW_SETTINGS names them, so that the preset lists (#172), which are actions
# and draw nothing of their own, are not swept too. Keep it in step with
# SettingsMenu.properties(): a setting missing here is left out of the sweep.
# The resource directories are named, not discovered: the settings are in
# premium/resources-base, and a directory off the build's path would be varied and
# then ignored. VARY narrows the sweep, GRID="ACROSS DOWN" crosses two settings,
# CASES=file.json lists the combinations; PREVIEW_FLAGS passes anything else through,
# such as --set timeSize=0,6. Lite has no settings, so it captures its defaults,
# one build per scene.
#
# Expect it to be slow. Every build is compiled in the one container, then captured
# on a fresh simulator: about a minute a build on an arm64 Mac, where the image
# runs emulated. The full Premium sweep is 28 builds a scene, about an hour; one
# setting of three values in both scenes took six minutes.
PREVIEW_DIR := .dev/scratchpad/preview/$(EDITION)
SCENES ?= woken always-on
SCENE_JUNGLE_woken := monkey.jungle;$(EDITION).jungle
SCENE_JUNGLE_always-on := monkey.jungle;graphics.jungle;$(EDITION).jungle
VARY ?=
GRID ?=
CASES ?=
PREVIEW_FLAGS ?=
ifeq ($(EDITION),premium)
  PREVIEW_RESOURCES := --resources resources --resources premium/resources-base
  PREVIEW_SETTINGS := timeSize trailLength timeStyle timeAlign timeColor rainColor alwaysOnBrightness date
  PREVIEW_PLAN := $(if $(GRID),--grid $(GRID),$(if $(CASES),--cases $(CASES),--sweep)) \
                  $(foreach key,$(if $(GRID)$(CASES),$(VARY),$(or $(VARY),$(PREVIEW_SETTINGS))),--vary $(key))
else
  PREVIEW_RESOURCES := --resources resources
  PREVIEW_PLAN := --cases $(PREVIEW_DIR)/defaults.json
endif

preview:
	@garmin-graphics-generator --about 2>/dev/null | awk '/version:/ { split($$NF, v, "."); \
	  found = 1; old = v[1] + 0 == 0 && v[2] + 0 < 6 } END { exit !found || old }' || { \
	  echo "make preview needs garmin-graphics-generator 0.6.0 or newer on PATH; see README.md."; exit 1; }
	@test -n "$(strip $(SCENES))" || { echo "SCENES is empty; name woken, always-on or both."; exit 1; }
	@$(foreach scene,$(SCENES),test -n "$(SCENE_JUNGLE_$(scene))" || { \
	  echo "SCENES takes woken and always-on, not \"$(scene)\"."; exit 1; };)
	@test -z "$(strip $(GRID))" -o -z "$(strip $(CASES))" || { \
	  echo "GRID and CASES are two different plans; name one."; exit 1; }
	@test "$(EDITION)" = premium -o -z "$(VARY)$(GRID)$(CASES)" || { \
	  echo "Lite has no settings to vary; drop VARY, GRID and CASES."; exit 1; }
	@mkdir -p $(PREVIEW_DIR)
	@$(if $(filter lite,$(EDITION)),echo '[{}]' > $(PREVIEW_DIR)/defaults.json,:)
	@echo "Capturing the $(EDITION) preview into $(PREVIEW_DIR)..."
	@garmin-graphics-generator shots -p . -d $(DEVICE) -o $(PREVIEW_DIR) \
	  $(PREVIEW_RESOURCES) $(PREVIEW_PLAN) \
	  $(foreach scene,$(SCENES),--scene "$(scene)=$(SCENE_JUNGLE_$(scene))") \
	  $(if $(PLATFORM),--platform $(PLATFORM),) $(if $(TZ_NAME),--timezone $(TZ_NAME),) \
	  $(PREVIEW_FLAGS)
	@echo "Contact sheet: $(PREVIEW_DIR)/contact-sheet.png"

clean:
	@rm -Rf MatrixTime.prg MatrixTimePremium.prg MatrixTime*-settings.json test_build* *.debug.xml bin/ deploy/ gen/ internal-mir/ external-mir/ export/ 
	@echo "Clean complete."