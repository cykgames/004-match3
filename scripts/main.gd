extends Node2D

# The main node. Handle scene changes and some inputs.
# Touch additions: restart_game() / back_to_menu() are called by the
# on-screen buttons in GameUI; Android hardware back maps to _go_back().

const UiGamePrefab = preload("res://scenes/game.tscn")
const UiGameOverPrefab = preload("res://scenes/game_over.tscn")
@onready var ui_menu = $MainMenuUI
var ui_game = null
var ui_game_over = null

func _ready():
    # Desktop convenience only; on phones the window IS the screen.
    if not (OS.has_feature("android") or OS.has_feature("ios")):
        get_window().size *= 2
        get_window().position = Vector2.ZERO
    Events.game_over.connect(on_game_over)
    # Android hardware back button (Window signal, API 33+ handled by Godot).
    get_window().go_back_requested.connect(_on_go_back_request)

func on_game_over(score):
    _clear_ui_game_over()
    ui_game_over = UiGameOverPrefab.instantiate()
    ui_game_over.init(score)
    add_child(ui_game_over)

func _on_btn_new_game_pressed():
    # Clear first so this also works as "restart" from any state.
    _clear_ui_game()
    _clear_ui_game_over()
    ui_game = UiGamePrefab.instantiate()
    add_child(ui_game)

func _on_btn_exit_pressed():
    get_tree().quit()

## On-screen Restart button (GameUI) delegates here.
func restart_game():
    _on_btn_new_game_pressed()

## On-screen Menu button (GameUI) delegates here.
func back_to_menu():
    _clear_ui_game()
    _clear_ui_game_over()

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
