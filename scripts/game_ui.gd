extends Control

## Handle the UI for the game scene. Not cover the pieces (see grid.gd).

@onready var grid = $CanvasGroup/Grid
@onready var grid_border = $HBoxContainer/MarginContainer/GridBorder

func _ready():
    if not grid.is_node_ready():
        await grid.ready
    grid.try_next_match()
    Events.current_level = 1
    
    Events.game_over.connect(func(_score): self.queue_free())
    # The border stretches with the viewport; keep the board centered in it.
    grid_border.resized.connect(_place_grid)
    call_deferred("_place_grid")

## Piece sprites are center-anchored on their cell origin, so the board
## content spans grid.position - half_cell .. + (cols, rows) * cell - half.
## Center that content inside the (stretching) GridBorder rect.
func _place_grid():
    var cell = grid.SPRITE_SIZE
    var board = Vector2(grid.grid_size_x * cell, grid.grid_size_y * cell)
    var b = grid_border.get_global_rect()
    grid.global_position = b.position + (b.size - board) / 2.0 + Vector2(cell / 2.0, cell / 2.0)
    
func _on_btn_swap_pressed():
    grid.swap_all_random()

## On-screen Restart (touch). Delegates to Main, which owns scene switching.
func _on_btn_restart_pressed():
    var main = get_parent()
    if main and main.has_method("restart_game"):
        main.restart_game()

## On-screen back-to-menu (touch). Delegates to Main.
func _on_btn_back_pressed():
    var main = get_parent()
    if main and main.has_method("back_to_menu"):
        main.back_to_menu()
