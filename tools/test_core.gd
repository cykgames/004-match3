extends Node

## Headless unit tests for scripts/standalone/match3_core.gd (kept VERBATIM
## from upstream luiz734/match3_game). These tests pin its behavior so any
## future engine-drift fix can be checked against them.
##
## Run: godot --headless --path . res://tools/test_core.tscn
##
## Notes:
## - The core type-hints Piece and emits Events.piece_removed_from_poll, so
##   tests use real Piece instances (piece.tscn) and the Events autoload.
## - The core intentionally skips grid row 0 (the hidden "dispenser" row)
##   when scanning; all planted patterns live in rows >= 1.

const Match3Core = preload("res://scripts/standalone/match3_core.gd")
const PiecePrefab = preload("res://scenes/piece.tscn")
const GamePrefab = preload("res://scenes/game.tscn")
const GX = 6
const GY = 8

var _res: Array[PieceRes] = []
var _passed = 0
var _failed = 0

func _ready():
	_res = [
		preload("res://resources/bat.tres"),
		preload("res://resources/candle.tres"),
		preload("res://resources/ghost.tres"),
		preload("res://resources/hat.tres"),
		preload("res://resources/pumpkin.tres"),
	]
	await _run_all()
	print("TEST_CORE SUMMARY: passed=%d failed=%d" % [_passed, _failed])
	if _failed == 0:
		print("TEST_CORE PASS")
	else:
		print("TEST_CORE FAIL")
	get_tree().quit(0 if _failed == 0 else 1)

func _check(test_name: String, cond: bool) -> void:
	if cond:
		_passed += 1
		print("  ok: " + test_name)
	else:
		_failed += 1
		print("  FAIL: " + test_name)

func _make_piece(type_idx: int) -> Piece:
	var p: Piece = PiecePrefab.instantiate()
	p.init(_res[type_idx], GX)
	return p

func _free_grid(g: Array) -> void:
	for p in g:
		if p != null and is_instance_valid(p):
			p.free()

## Diagonal stripes: no 3-in-a-row anywhere (adjacent cells differ by 1
## horizontally and 2 vertically, mod 5).
func _striped_grid() -> Array:
	var g: Array = []
	for row in range(GY):
		for col in range(GX):
			g.push_back(_make_piece((col + 2 * row) % 5))
	return g

func _cmp(a: Piece, b: Piece) -> bool:
	if a == null or b == null:
		return false
	if a.used or b.used:
		return false
	return b._piece_res.matches.any(func(x): return x == a._piece_res.type)

func _idx(row: int, col: int) -> int:
	return row * GX + col

func _run_all() -> void:
	print("TEST_CORE BEGIN")

	# 1. No match on a clean board.
	var g = _striped_grid()
	var core = Match3Core.new(GX, GY)
	var candidates = core.get_candidate_matches_as_arrays(g, _cmp)
	var best = core.get_most_valuable_match(candidates)
	_check("no_match on striped board", candidates.is_empty() and best.type == Match3Core.MatchType.NO_MATCH)
	_free_grid(g)
	core.free()

	# 2. Horizontal MATCH_3 at row 2, cols 1-3.
	g = _striped_grid()
	core = Match3Core.new(GX, GY)
	for col in [1, 2, 3]:
		g[_idx(2, col)].free()
		g[_idx(2, col)] = _make_piece(0)
	candidates = core.get_candidate_matches_as_arrays(g, _cmp)
	best = core.get_most_valuable_match(candidates)
	_check("horizontal MATCH_3 indexes", best.type == Match3Core.MatchType.MATCH_3 and best.indexes == [13, 14, 15])
	_free_grid(g)
	core.free()

	# 3. Vertical MATCH_3 at col 2, rows 2-4.
	g = _striped_grid()
	core = Match3Core.new(GX, GY)
	for row in [2, 3, 4]:
		g[_idx(row, 2)].free()
		g[_idx(row, 2)] = _make_piece(1)
	candidates = core.get_candidate_matches_as_arrays(g, _cmp)
	best = core.get_most_valuable_match(candidates)
	_check("vertical MATCH_3 indexes", best.type == Match3Core.MatchType.MATCH_3 and best.indexes == [14, 20, 26])
	_free_grid(g)
	core.free()

	# 4. MATCH_4 at row 3, cols 1-4.
	g = _striped_grid()
	core = Match3Core.new(GX, GY)
	for col in [1, 2, 3, 4]:
		g[_idx(3, col)].free()
		g[_idx(3, col)] = _make_piece(2)
	candidates = core.get_candidate_matches_as_arrays(g, _cmp)
	best = core.get_most_valuable_match(candidates)
	_check("MATCH_4 detected", best.type == Match3Core.MatchType.MATCH_4 and best.indexes.size() == 4)
	_free_grid(g)
	core.free()

	# 5. MATCH_5 at row 4, cols 0-4.
	g = _striped_grid()
	core = Match3Core.new(GX, GY)
	for col in [0, 1, 2, 3, 4]:
		g[_idx(4, col)].free()
		g[_idx(4, col)] = _make_piece(0)
	candidates = core.get_candidate_matches_as_arrays(g, _cmp)
	best = core.get_most_valuable_match(candidates)
	_check("MATCH_5 detected", best.type == Match3Core.MatchType.MATCH_5 and best.indexes.size() == 5)
	_free_grid(g)
	core.free()

	# 6. MATCH_T: horizontal bar row 3 cols 1-3 + vertical stem col 2 rows 3-5.
	g = _striped_grid()
	core = Match3Core.new(GX, GY)
	for cell in [[3, 1], [3, 2], [3, 3], [4, 2], [5, 2]]:
		g[_idx(cell[0], cell[1])].free()
		g[_idx(cell[0], cell[1])] = _make_piece(2)
	candidates = core.get_candidate_matches_as_arrays(g, _cmp)
	best = core.get_most_valuable_match(candidates)
	var t_expected = [19, 20, 21, 26, 32]
	var t_ok = best.type == Match3Core.MatchType.MATCH_T and best.indexes.size() == 5
	if t_ok:
		for i in t_expected:
			if not (i in best.indexes):
				t_ok = false
	_check("MATCH_T detected (bar+stem, 5 cells)", t_ok)
	_free_grid(g)
	core.free()

	# 7. Swap semantics (mirrors grid.on_swap_requested): a swap that creates
	#    a match is accepted; the same board without the swap has no match.
	g = _striped_grid()
	core = Match3Core.new(GX, GY)
	for cell in [[2, 1], [2, 2]]:
		g[_idx(cell[0], cell[1])].free()
		g[_idx(cell[0], cell[1])] = _make_piece(0)
	g[_idx(2, 3)].free()
	g[_idx(2, 3)] = _make_piece(1)
	g[_idx(1, 3)].free()
	g[_idx(1, 3)] = _make_piece(0)
	var before = core.get_candidate_matches_as_arrays(g, _cmp)
	var sim: Array = g.duplicate()
	var ia = _idx(2, 3)
	var ib = _idx(1, 3)
	var tmp = sim[ia]
	sim[ia] = sim[ib]
	sim[ib] = tmp
	var after = core.get_candidate_matches_as_arrays(sim, _cmp)
	_check("swap creates match (accept path)", before.is_empty() and not after.is_empty())
	# revert -> empty again (reject path)
	var rev: Array = sim.duplicate()
	tmp = rev[ia]
	rev[ia] = rev[ib]
	rev[ib] = tmp
	var reverted = core.get_candidate_matches_as_arrays(rev, _cmp)
	_check("swap revert -> no match (reject path)", reverted.is_empty())
	_free_grid(g)
	core.free()

	# 8. Gravity compaction: nulls bubble to column top, order preserved.
	g = _striped_grid()
	core = Match3Core.new(GX, GY)
	var kept: Array = []
	for row in range(GY):
		if row != 3 and row != 5:
			kept.push_back(g[_idx(row, 1)])
	g[_idx(3, 1)].free()
	g[_idx(3, 1)] = null
	g[_idx(5, 1)].free()
	g[_idx(5, 1)] = null
	var compacted = core.get_notnull_first(g, 1, 1 + GY * GX, GX)
	# NOTE: despite its docstring, the core returns non-nulls FIRST, nulls
	# last. grid.gd does not use this helper for gravity (it moves pieces
	# row-by-row); the cascade test below places them at the BOTTOM rows to
	# mirror the real game.
	var grav_ok = compacted.size() == GY and compacted[GY - 2] == null and compacted[GY - 1] == null
	for i in range(kept.size()):
		if compacted[i] != kept[i]:
			grav_ok = false
	_check("gravity: get_notnull_first compacts column (non-nulls first)", grav_ok)
	_free_grid(g)
	core.free()

	# 9. Cascade: match -> remove -> compact -> refill -> NEW match appears.
	g = _striped_grid()
	core = Match3Core.new(GX, GY)
	for row in [2, 3, 4]:
		g[_idx(row, 2)].free()
		g[_idx(row, 2)] = _make_piece(2)
	g[_idx(5, 2)].free()
	g[_idx(5, 2)] = _make_piece(0)  # keep the planted match at exactly 3
	var iterations = 0
	var total_removed = 0
	var refill_iter = 0
	while iterations < 20:
		core.reset_removed_from_poll()
		candidates = core.get_candidate_matches_as_arrays(g, _cmp)
		if candidates.is_empty():
			break
		best = core.get_most_valuable_match(candidates)
		core.remove_from_poll(best.indexes)
		total_removed += best.indexes.size()
		for i in best.indexes:
			g[i].free()
			g[i] = null
		# compact every column (game gravity: pieces fall to the BOTTOM),
		# then refill the empty top rows
		for col in range(GX):
			var column = core.get_notnull_first(g, col, col + GY * GX, GX)
			var n_null = 0
			for p in column:
				if p == null:
					n_null += 1
			for row in range(GY):
				if row < n_null:
					g[_idx(row, col)] = null
				else:
					g[_idx(row, col)] = column[row - n_null]
			for row in range(n_null):
				var t: int
				if refill_iter == 0 and col == 2:
					t = 2  # force a second vertical match in col 2
				else:
					t = (col + 2 * row + refill_iter + 1) % 5
				g[_idx(row, col)] = _make_piece(t)
		refill_iter += 1
		iterations += 1
	_check("cascade: >=2 iterations, >=6 pieces removed", iterations >= 2 and total_removed >= 6)
	print("  cascade detail: iterations=%d removed=%d" % [iterations, total_removed])
	_free_grid(g)
	core.free()

	# 10. removed_from_poll bookkeeping.
	core = Match3Core.new(GX, GY)
	core.remove_from_poll([0, 1])
	var removed_ok = core.get_removed_from_poll_indexes() == [0, 1]
	core.reset_removed_from_poll()
	removed_ok = removed_ok and core.get_removed_from_poll_indexes().is_empty()
	_check("removed_from_poll set/reset", removed_ok)
	core.free()

	# 11. Loss condition (integration): real game scene, level 0 -> lose_level
	#     must emit game_over (grid.try_next_match ends the game at level < 0).
	var game = GamePrefab.instantiate()
	add_child(game)
	var grid = game.get_node("CanvasGroup/Grid")
	var frames = 0
	while frames < 600:
		await get_tree().process_frame
		frames += 1
		if frames > 10 and not grid.action_locked:
			break
	var sm = game.get_node("ScoreManager")
	# GDScript lambdas capture locals BY VALUE: use a dict holder so the
	# mutation is visible outside the callback.
	var flag = {"over": false}
	var cb = func(_score): flag["over"] = true
	Events.game_over.connect(cb)
	Events.current_level = 0
	sm.lose_level()
	_check("loss: level 0 -> -1 emits game_over", flag["over"] and Events.current_level == -1)
	Events.game_over.disconnect(cb)
	await get_tree().process_frame
	await get_tree().process_frame
	# Wait for floating score labels (tween + audio) to free themselves so
	# nothing leaks at exit. They are children of the root, not of the game.
	var drain_frames = 0
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
	print("TEST_CORE END")
