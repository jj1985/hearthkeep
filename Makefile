.PHONY: run test lint apk apk-clean apk-bump assets-audit balance-sim clean install-hooks ship release-attach

GODOT ?= $(HOME)/bin/godot
PROJECT_PATH ?= .
VERSION_NAME := $(shell grep '^version/name=' export_presets.cfg | cut -d'"' -f2)

run:
	$(GODOT) --path $(PROJECT_PATH)

test:
	$(GODOT) --headless --path $(PROJECT_PATH) -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit

# Re-import all assets/scripts; surfaces parse errors and any
# resource-loading issues across the whole tree.
lint:
	$(GODOT) --headless --path $(PROJECT_PATH) --import 2>&1 | grep -E "ERROR|WARNING|SCRIPT ERROR" || echo "[lint] clean (no errors or warnings reported)"

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

# `make ship` — one-shot: tests → APK build → push to GitHub release.
# Defaults to attaching the freshly built APK (with --clobber) to the
# latest release. Override with TAG=v0.x.y to target a different one.
TAG ?= $(shell gh release list --limit 1 --json tagName --jq '.[0].tagName')

ship: test apk release-attach
	@echo "[ship] APK uploaded to release $(TAG)"

release-attach:
	@APK="build/HearthkeepDemo-v$(VERSION_NAME).apk"; \
	if [ ! -f "$$APK" ]; then echo "[ship] missing $$APK"; exit 1; fi; \
	echo "[ship] uploading $$APK to release $(TAG)"; \
	gh release upload "$(TAG)" "$$APK" --clobber
