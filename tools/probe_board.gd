extends SceneTree
## Regression probe for the "gray digit instead of piece art" device report.
## Runs the opening cascade to rest, then asserts:
##   1. every board cell holds a piece with a non-null sprite texture,
##   2. no numeric-only Label ever spawned at the root (the old floating
##      score popup did exactly that, over cleared cells),
##   3. no visible numeric-only Label overlaps the board rect at rest.
## Run: godot --headless --path . --script tools/probe_board.gd

var _numeric_root_labels := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.child_entered_tree.connect(_on_root_child)
	var game := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	var grid: Node = game.get_node("CanvasGroup/Grid")

	# Let the opening cascade settle (pieces refilled, actions unlocked).
	var settled := false
	for i in range(1200):
		await process_frame
		if not grid.action_locked and grid.pieces.all(func(p): return p != null):
			settled = true
			break
	for i in range(30):
		await process_frame

	var failures: Array[String] = []
	if not settled:
		failures.append("cascade never settled")
	var cells: int = grid.grid_size_x * grid.grid_size_y
	if grid.pieces.size() != cells:
		failures.append("piece count %d != %d" % [grid.pieces.size(), cells])
	for p in grid.pieces:
		if p == null or p.texture_rect.texture == null:
			failures.append("cell without piece art: %s" % str(p))
			break
	if _numeric_root_labels > 0:
		failures.append("numeric popup spawned at root: %d" % _numeric_root_labels)

	var board := Rect2(grid.global_position - Vector2(16, 16),
		Vector2(grid.grid_size_x * 32, grid.grid_size_y * 32))
	var numeric_over_board := 0
	for lbl in _labels(game):
		if lbl.visible and lbl.text.is_valid_int() \
				and board.intersects(lbl.get_global_rect()):
			numeric_over_board += 1
	if numeric_over_board > 0:
		failures.append("numeric labels over board: %d" % numeric_over_board)

	if failures.is_empty():
		print("PROBE PASS: %d cells all textured, 0 numeric popups, 0 numeric labels over board" % cells)
		quit(0)
	else:
		for f in failures:
			printerr("PROBE FAIL: ", f)
		quit(1)


func _on_root_child(n: Node) -> void:
	if n is Label and n.text.is_valid_int():
		_numeric_root_labels += 1


func _labels(n: Node) -> Array:
	var out: Array = []
	if n is Label:
		out.append(n)
	for c in n.get_children():
		out.append_array(_labels(c))
	return out