extends Node

## Headless autoplay bot: plays the REAL game (main.tscn) with random valid
## swaps for >= 60s. Pass criteria: elapsed >= 60s, cumulative score > 0,
## swaps performed, and no script errors (driver greps the log for those).
## Also exercises the on-screen Restart / Menu buttons mid-run.
##
## Run: godot --headless --path . res://tools/autoplay.tscn
##
## Swap policy: pick random adjacent interactable pairs; prefer one that
## actually produces a match (simulated with the untouched match3_core),
## fall back to any random valid pair. This is "random valid swaps" with a
## match-seeking bias so score > 0 is deterministic-ish within the timebox.

const MainPrefab = preload("res://scenes/main.tscn")
const DURATION_SEC = 65.0
const SWAP_INTERVAL = 0.4
const BUTTON_TEST_AT = 30.0

var main = null
var _total_score = 0
var _swaps = 0
var _game_overs = 0
var _restarts = 0
var _back_to_menu = 0
var _elapsed = 0.0
var _swap_timer = 0.0
var _button_test_done = false
var _finished = false
var _rng = RandomNumberGenerator.new()

func _ready():
	_rng.seed = 20261115
	Events.piece_scored.connect(func(amount): _total_score += amount)
	Events.game_over.connect(func(_s): _game_overs += 1)
	main = MainPrefab.instantiate()
	add_child(main)
	await get_tree().process_frame
	main._on_btn_new_game_pressed()
	print("AUTOPLAY START: duration=%.0fs interval=%.1fs" % [DURATION_SEC, SWAP_INTERVAL])

func _process(delta):
	if _finished:
		return
	_elapsed += delta
	if not _button_test_done and _elapsed >= BUTTON_TEST_AT:
		_button_test_done = true
		_exercise_buttons()
	_swap_timer -= delta
	if _swap_timer <= 0.0:
		_swap_timer = SWAP_INTERVAL
		_try_swap()
	if _elapsed >= DURATION_SEC:
		_finish()

## Press the real on-screen buttons (same path a touch would take).
func _exercise_buttons() -> void:
	var game = main.ui_game
	if is_instance_valid(game):
		var restart_btn = game.get_node_or_null("HBoxContainer/BottomBar/MarginContainer/HBoxContainer/Restart")
		if restart_btn != null:
			restart_btn.pressed.emit()
			_restarts += 1
			print("AUTOPLAY: pressed on-screen Restart at t=%.1fs" % _elapsed)
			await get_tree().process_frame
			await get_tree().process_frame
	# Restart replaced the game scene: re-fetch before pressing Menu.
	game = main.ui_game
	if is_instance_valid(game):
		var back_btn = game.get_node_or_null("HBoxContainer/BottomBar/MarginContainer/HBoxContainer/Back")
		if back_btn != null:
			back_btn.pressed.emit()
			_back_to_menu += 1
			print("AUTOPLAY: pressed on-screen Menu at t=%.1fs" % _elapsed)
			await get_tree().process_frame
			await get_tree().process_frame
	if not is_instance_valid(main.ui_game):
		main._on_btn_new_game_pressed()

func _try_swap() -> void:
	var game = main.ui_game
	if not is_instance_valid(game):
		# Game over screen or menu: start a fresh game and keep playing.
		if is_instance_valid(main.ui_game_over):
			main._clear_ui_game_over()
		main._on_btn_new_game_pressed()
		return
	if Events.input_locket:
		return
	var grid = game.get_node_or_null("CanvasGroup/Grid")
	if grid == null or grid.action_locked:
		return
	var pieces: Array = grid.pieces
	var pairs: Array = []
	for i in range(pieces.size()):
		var a = pieces[i]
		if a == null or not a._interactable:
			continue
		var col = i % grid.grid_size_x
		var row = int(i / grid.grid_size_x)
		if col + 1 < grid.grid_size_x:
			var b = pieces[i + 1]
			if b != null and b._interactable:
				pairs.append([a, b])
		if row + 1 < grid.grid_size_y:
			var b2 = pieces[i + grid.grid_size_x]
			if b2 != null and b2._interactable:
				pairs.append([a, b2])
	if pairs.is_empty():
		return
	# Prefer a swap that produces a match (simulate on a shallow copy).
	var chosen: Array = []
	var core = grid.match3_core
	for _attempt in range(12):
		var pair: Array = pairs[_rng.randi_range(0, pairs.size() - 1)]
		var sim: Array = pieces.duplicate()
		var ia: int = pair[0].index
		var ib: int = pair[1].index
		sim[ia] = pair[1]
		sim[ib] = pair[0]
		var candidates = core.get_candidate_matches_as_arrays(sim, grid.cmp_func)
		if not candidates.is_empty():
			chosen = pair
			break
	if chosen.is_empty():
		chosen = pairs[_rng.randi_range(0, pairs.size() - 1)]
	Events.swap_requested.emit(chosen[0], chosen[1])
	_swaps += 1

func _finish() -> void:
	_finished = true
	set_process(false)
	var ui_score = -1
	var game = main.ui_game
	if is_instance_valid(game):
		var label = game.get_node_or_null("HBoxContainer/TopBar/HBoxContainer/HBoxContainer/Score")
		if label != null:
			ui_score = int(label.text)
	var ok = _elapsed >= 60.0 and _total_score > 0 and _swaps > 0
	print("AUTOPLAY SUMMARY: elapsed=%.1fs swaps=%d score=%d ui_score=%d game_overs=%d restarts=%d back_to_menu=%d" % [
		_elapsed, _swaps, _total_score, ui_score, _game_overs, _restarts, _back_to_menu])
	# Drain floating score labels (tween + audio) before quit so the log has
	# no leak warnings. They live under the root, not under the game scene.
	var drain_frames = 0
	var labels_at_start = 0
	for c in get_tree().get_root().get_children():
		if str(c.name).contains("FloatingScoreLabel"):
			labels_at_start += 1
	while drain_frames < 300:
		var any_label = false
		for c in get_tree().get_root().get_children():
			if str(c.name).contains("FloatingScoreLabel"):
				any_label = true
				break
		if not any_label:
			break
		await get_tree().process_frame
		drain_frames += 1
	print("AUTOPLAY DRAIN: labels_at_start=%d drain_frames=%d" % [labels_at_start, drain_frames])
	if ok:
		print("AUTOPLAY PASS")
		get_tree().quit(0)
	else:
		print("AUTOPLAY FAIL")
		get_tree().quit(1)
