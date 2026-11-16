extends Node2D

# The main node. Handle scene changes and some inputs.
# Touch additions: restart_game() / back_to_menu() are called by the
# on-screen buttons in GameUI; Android hardware back maps to _go_back().

const UiGamePrefab = preload("res://scenes/game.tscn")
const UiGameOverPrefab = preload("res://scenes/game_over.tscn")
@onready var ui_menu = $MainMenuUI
var ui_game = null
var ui_game_over = null

# Best-score persistence for the title screen (branding pass). Lives in
# user:// so it survives restarts; no gameplay values are touched.
const BEST_SCORE_FILE := "user://spooky_swap_best.cfg"
var _best_score := 0

func _ready():
    # Desktop convenience only; on phones the window IS the screen.
    if not (OS.has_feature("android") or OS.has_feature("ios")):
        get_window().size *= 2
        get_window().position = Vector2.ZERO
    Events.game_over.connect(on_game_over)
    # Android hardware back button (Window signal, API 33+ handled by Godot).
    get_window().go_back_requested.connect(_on_go_back_request)
    # UI roots are Controls parented to a Node2D: their anchor reference
    # area is zero, so full-rect anchors collapse to the minimum size
    # centered on the origin. Size them against the viewport instead.
    get_viewport().size_changed.connect(_refit_ui)
    _fit_ui(ui_menu)
    _best_score = _load_best_score()
    _refresh_best_label()

func on_game_over(score):
    if int(score) > _best_score:
        _best_score = int(score)
        _save_best_score()
    _refresh_best_label()
    _clear_ui_game_over()
    ui_game_over = UiGameOverPrefab.instantiate()
    ui_game_over.init(score)
    add_child(ui_game_over)
    _fit_ui(ui_game_over)

func _on_btn_new_game_pressed():
    # Clear first so this also works as "restart" from any state.
    _clear_ui_game()
    _clear_ui_game_over()
    ui_game = UiGamePrefab.instantiate()
    add_child(ui_game)
    _fit_ui(ui_game)

## Pin a UI root Control to the viewport visible rect. Controls under a
## Node2D have a zero anchor reference area (Godot 4), so anchors alone
## cannot fill the screen; explicit size + top-left anchors are stable.
func _fit_ui(ctrl):
    if not is_instance_valid(ctrl):
        return
    ctrl.set_anchors_preset(Control.PRESET_TOP_LEFT)
    ctrl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    ctrl.grow_vertical = Control.GROW_DIRECTION_BEGIN
    ctrl.position = Vector2.ZERO
    ctrl.size = get_viewport().get_visible_rect().size

func _refit_ui():
    _fit_ui(ui_menu)
    _fit_ui(ui_game)
    _fit_ui(ui_game_over)

func _on_btn_exit_pressed():
    get_tree().quit()

## On-screen Restart button (GameUI) delegates here.
func restart_game():
    _on_btn_new_game_pressed()

## On-screen Menu button (GameUI) delegates here.
func back_to_menu():
    _clear_ui_game()
    _clear_ui_game_over()
    _refresh_best_label()

# The game / game-over screens can free themselves (game_over signal,
# "Main Menu" button), so references may be freed instances: always guard
# with is_instance_valid() instead of truthiness checks.
func _clear_ui_game():
    if is_instance_valid(ui_game):
        ui_game.queue_free()
    ui_game = null

func _clear_ui_game_over():
    if is_instance_valid(ui_game_over):
        ui_game_over.queue_free()
    ui_game_over = null

func _on_go_back_request():
    _go_back()

func _input(event):
    if event.is_action_pressed("GoBack"):
        _go_back()

func _go_back():
    if is_instance_valid(ui_game_over):
        _clear_ui_game_over()
    elif is_instance_valid(ui_game):
        _clear_ui_game()
    else:
        get_tree().quit()

func _load_best_score() -> int:
    var cfg := ConfigFile.new()
    if cfg.load(BEST_SCORE_FILE) != OK:
        return 0
    return int(cfg.get_value("score", "best", 0))

func _save_best_score() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("score", "best", _best_score)
    cfg.save(BEST_SCORE_FILE)

func _refresh_best_label() -> void:
    var lbl := get_node_or_null("MainMenuUI/Background/MarginContainer/HBoxContainer/BestScore") as Label
    if lbl != null:
        lbl.text = "BEST %d" % _best_score
