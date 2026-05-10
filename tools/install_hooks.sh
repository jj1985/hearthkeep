#!/usr/bin/env bash
# Installs the project's git hooks. Run once after clone.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

mkdir -p "$HOOKS_DIR"

# pre-commit: run headless tests; abort if any fail.
cat > "$HOOKS_DIR/pre-commit" <<'EOF'
#!/usr/bin/env bash
# Hearthkeep pre-commit hook — runs the GUT test suite headless.
# Skip with `git commit --no-verify` only for trivial changes that don't
# touch GDScript; the engineering mandates require green tests on every
# commit.

set -e
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# Locate godot binary in PATH or fall back to the project default
GODOT_BIN="$(command -v godot 2>/dev/null || true)"
if [ -z "$GODOT_BIN" ] && [ -x "$HOME/bin/godot" ]; then
    GODOT_BIN="$HOME/bin/godot"
fi
if [ -z "$GODOT_BIN" ]; then
    echo "[pre-commit] godot binary not found — skipping tests."
    echo "[pre-commit] (install godot or symlink it to ~/bin/godot)"
    exit 0
fi

echo "[pre-commit] running GUT tests via $GODOT_BIN..."
OUTPUT="$("$GODOT_BIN" --headless --path "$REPO_ROOT" -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1)"
EXIT_CODE=$?

echo "$OUTPUT" | grep -E "passed\.\$|FAIL|Tests |Asserts |---- All tests"

if echo "$OUTPUT" | grep -q "Failing Tests" || [ "$EXIT_CODE" -ne 0 ]; then
    echo ""
    echo "[pre-commit] TESTS FAILED — commit aborted. Re-run \`make test\` to debug."
    exit 1
fi
echo "[pre-commit] all tests passed."
EOF

chmod +x "$HOOKS_DIR/pre-commit"
echo "[install-hooks] pre-commit hook installed at $HOOKS_DIR/pre-commit"

# pre-push: builds + uploads APK in the background after the push
# completes (forked + disowned so the user's terminal isn't blocked).
# Logs to .git/last-ship.log.
cat > "$HOOKS_DIR/pre-push" <<'EOF'
#!/usr/bin/env bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
LOG="$REPO_ROOT/.git/last-ship.log"
(
    sleep 3
    echo "[ship-bg] $(date) starting" > "$LOG"
    make ship >> "$LOG" 2>&1 \
        && echo "[ship-bg] $(date) OK" >> "$LOG" \
        || echo "[ship-bg] $(date) FAILED" >> "$LOG"
) </dev/null >/dev/null 2>&1 &
disown $! || true
exit 0
EOF
chmod +x "$HOOKS_DIR/pre-push"
echo "[install-hooks] pre-push hook installed at $HOOKS_DIR/pre-push"
