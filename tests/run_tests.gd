# SPDX-License-Identifier: Apache-2.0
# Headless test runner:  godot --headless --path . --script res://tests/run_tests.gd
extends SceneTree

const SUITES := [
	"res://tests/test_parity.gd",
	"res://tests/test_svg.gd",
	"res://tests/test_game.gd",
	"res://tests/test_live.gd",
	"res://tests/test_composition.gd",
	"res://tests/test_kit.gd",
	"res://tests/test_cues.gd",
	"res://tests/test_paths.gd",
	"res://tests/test_polygons.gd",
	"res://tests/test_motion_path.gd",
	"res://tests/test_motion_poly.gd",
	"res://tests/test_motion_travel.gd",
	"res://tests/test_kit_helpers.gd",
	"res://tests/test_kit_classes.gd",
	"res://tests/test_city_plan.gd",
]

# Run once the tree is up (root inside the tree, after the first flush), so
# suites can add nodes to it.
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failed := 0
	var passed := 0
	for path in SUITES:
		if not ResourceLoader.exists(path):
			continue
		var suite: Object = load(path).new()
		if "tree" in suite:
			suite.set("tree", self)   # suites that need nodes in a tree
		for m in suite.get_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			var res: Variant = suite.call(name)
			# a test that hits a script error returns null: that is a failure too
			var err: String = res if res is String else "script error (no result)"
			if err == "":
				passed += 1
				print("  ok    %s::%s" % [path.get_file(), name])
			else:
				failed += 1
				print("  FAIL  %s::%s  %s" % [path.get_file(), name, err])
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
