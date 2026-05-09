.PHONY: run test apk apk-clean apk-bump assets-audit balance-sim clean install-hooks

GODOT ?= $(HOME)/bin/godot
PROJECT_PATH ?= .
VERSION_NAME := $(shell grep '^version/name=' export_presets.cfg | cut -d'"' -f2)

run:
	$(GODOT) --path $(PROJECT_PATH)

test:
	$(GODOT) --headless --path $(PROJECT_PATH) -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit

# Bumps Android versionCode in export_presets.cfg by +1.
# Required before every APK build so Android treats it as a real upgrade.
apk-bump:
	python3 tools/bump_version.py

apk: apk-bump
	mkdir -p build
	$(GODOT) --headless --path $(PROJECT_PATH) --export-debug "Android" build/HearthkeepDemo-v$(VERSION_NAME).apk

apk-clean:
	rm -rf build/

assets-audit:
	python3 tools/asset_audit.py

install-hooks:
	bash tools/install_hooks.sh

balance-sim:
	$(GODOT) --headless --path $(PROJECT_PATH) -s tests/balance_sim.gd

clean: apk-clean
	rm -rf .godot
