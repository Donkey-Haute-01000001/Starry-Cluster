#!/usr/bin/env bash
# Runs every headless test and the rule check. Exits 1 if anything fails.
# Usage: tools/run_tests.sh [path/to/godot]   (default: godot on PATH)
# A test fails on a failed check, a script error, a crash or a hang.
cd "$(dirname "$0")/.." || exit 1
GODOT="${1:-godot}"
LOGS="${TMPDIR:-/tmp}/sector-tests"
mkdir -p "$LOGS"
fail=0

python3 tools/check_rules.py || fail=1

"$GODOT" --headless --import >/dev/null 2>&1

run() {
	local name="$1"; shift
	local log="$LOGS/$name.log"
	timeout 300 "$GODOT" --headless --fixed-fps 60 -- "$@" >"$log" 2>&1
	local code=$?
	if [ $code -ne 0 ] || grep -q "SCRIPT ERROR" "$log" || ! grep -q "^\[checks\] PASS" "$log"; then
		echo "FAIL  $name (exit $code, log: $log)"
		grep -E "SCRIPT ERROR|\[checks\] FAIL" "$log" | head -5 | sed 's/^/      /'
		fail=1
	else
		echo "pass  $name  $(grep '^\[checks\] PASS' "$log" | sed 's/.*(//; s/)//')"
	fi
}

run autotest --autotest
run new-career --new-career-test
run merchant --merchant-test
for m in surrender fight driven tally; do
	run "capture-$m" --merchant-test --capture-test=$m
done

[ $fail -eq 0 ] && echo "ALL PASS" || echo "SOME FAILED"
exit $fail
