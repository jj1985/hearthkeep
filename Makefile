.PHONY: run test apk apk-clean apk-bump assets-audit balance-sim clean

GODOT ?= $(HOME)/bin/godot
PROJECT_PATH ?= .

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
	$(GODOT) --headless --path $(PROJECT_PATH) --export-debug "Android" build/HearthkeepDemo-v0.0.1.apk

apk-clean:
	rm -rf build/

assets-audit:
	@echo "Walking art/ASSET_MANIFEST.csv and audio/AUDIO_MANIFEST.csv"
	@test -f art/ASSET_MANIFEST.csv && wc -l art/ASSET_MANIFEST.csv || echo "MISSING"
	@test -f audio/AUDIO_MANIFEST.csv && wc -l audio/AUDIO_MANIFEST.csv || echo "MISSING"

balance-sim:
	$(GODOT) --headless --path $(PROJECT_PATH) -s tests/balance_sim.gd

clean: apk-clean
	rm -rf .godot
