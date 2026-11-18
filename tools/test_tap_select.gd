extends Node

## Headless state-assertion tests for the tap-tap selection path added to
## grid.gd / piece.gd / piece_texture.gd (fun-review H3: drag-only made a
## plain tap do nothing). Verifies _on_piece_clicked selection transitions
## and that an adjacent second tap emits Events.swap_requested -- state
## evidence, not pixel evidence (skill red line). The grid's own swap
## handler is disconnected so no cascade runs and piece instances stay
## stable for deterministic assertions.
##
## Run: godot --headless --path . res://tools/test_tap_select.tscn

const GamePrefab = preload("res://scenes/game.tscn")
const GX = 6

var _passed = 0
var _failed = 0
var _swaps: Array = []

func _ready():
	await _run()
	print("TEST_TAP_SELECT SUMMARY: passed=%d failed=%d" % [_passed, _failed])
	print("TEST_TAP_SELECT PASS" if _failed == 0 else "TEST_TAP_SELECT FAIL")
	get_tree().quit(0 if _failed == 0 else 1)

func _check(name: String, cond: bool) -> void:
	if cond:
		_passed += 1
		print("  ok: " + name)
	else:
		_failed += 1
		print("  FAIL: " + name)

func _spy(a, b) -> void:
	_swaps.append([a, b])

func _idle(grid) -> void:
	var frames = 0
	while grid.action_locked and frames < 1200:
		await get_tree().process_frame
		frames += 1

func _run():
	var game = GamePrefab.instantiate()
	add_child(game)
	var grid = game.get_node("CanvasGroup/Grid")
	await _idle(grid)
	_check("grid reaches idle", not grid.action_locked)
	# Detach the real swap handler so taps only hit the spy (no cascade).
	Events.swap_requested.disconnect(grid.on_swap_requested)
	Events.swap_requested.connect(_spy)
	# Find an adjacent interactable pair (same row) and a non-adjacent piece.
	var a = null
	var b = null
	var c = null
	for i in range(grid.pieces.size()):
		var p = grid.pieces[i]
		if p == null or not p._interactable:
			continue
		var col = i % GX
		if col < GX - 1 and a == null:
			var q = grid.pieces[i + 1]
			if q != null and q._interactable:
				a = p
				b = q
		if a != null and c == null and i + 2 * GX < grid.pieces.size():
			var r = grid.pieces[i + 2 * GX]
			if r != null and r._interactable and r != a and r != b:
				c = r
		if a != null and b != null and c != null:
			break
	_check("found adjacent pair + non-adjacent piece", a != null and b != null and c != null)
	if a == null or b == null or c == null:
		return
	# 1. First tap selects.
	grid._on_piece_clicked(a)
	_check("first tap selects piece", grid._selected == a)
	# 2. Tap same piece deselects, no swap.
	grid._on_piece_clicked(a)
	_check("second tap on same deselects", grid._selected == null)
	_check("deselect emits no swap", _swaps.is_empty())
	# 3. Non-adjacent second tap moves selection, no swap.
	grid._on_piece_clicked(a)
	grid._on_piece_clicked(c)
	_check("non-adjacent tap moves selection", grid._selected == c)
	_check("non-adjacent emits no swap", _swaps.is_empty())
	grid._on_piece_clicked(c)  # clear
	# 4. Adjacent second tap emits swap_requested(a, b) and clears selection.
	grid._on_piece_clicked(a)
	grid._on_piece_clicked(b)
	_check("adjacent tap emits one swap", _swaps.size() == 1)
	_check("swap pair is (a, b)", _swaps.size() == 1 and _swaps[0][0] == a and _swaps[0][1] == b)
	_check("selection cleared after swap", grid._selected == null)
	# 5. Locked input ignores taps.
	grid.lock_actions()
	grid._on_piece_clicked(a)
	_check("locked tap ignored", grid._selected == null)
	grid.unlock_actions()
	# 6. set_selected drives the scale affordance (tween settles ~0.08s).
	a.set_selected(true)
	await get_tree().create_timer(0.15).timeout
	_check("selected scale > 1", a.texture_rect.scale.x > 1.0)
	a.set_selected(false)
	await get_tree().create_timer(0.15).timeout
	_check("deselected scale back to 1", is_equal_approx(a.texture_rect.scale.x, 1.0))
