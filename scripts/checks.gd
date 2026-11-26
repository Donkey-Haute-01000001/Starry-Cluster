extends RefCounted
## Test checks that can fail. Test runs call check() at each milestone and
## finish() at the end: it prints PASS/FAIL and quits with exit code 1 on any
## failure, so tools/run_tests.sh can catch it.

static var failures: Array[String] = []
static var count := 0


static func check(ok: bool, what: String) -> void:
	count += 1
	if ok:
		return
	failures.append(what)
	print("[checks] FAIL: %s" % what)


static func finish(tree: SceneTree, label: String) -> void:
	if failures.is_empty():
		print("[checks] PASS %s (%d checks)" % [label, count])
		tree.quit(0)
	else:
		print("[checks] FAIL %s: %d of %d checks failed" % [label, failures.size(), count])
		tree.quit(1)
