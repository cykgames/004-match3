extends Node2D
class_name Piece

## Represents a piece. Mostly handle data, only.

@export var _piece_res: PieceRes
@onready var label_index = $Debug_index
@onready var texture_rect = $TextureRect
signal piece_clicked(piece: Piece)
signal action_animation_finished
var _interactable: bool = true
var _grid_size_x: int
var next_index = -1
var used = false

var index = -1:
    set(value):
        assert(_grid_size_x, "call init() first")
        index = value
        label_index.text = str(index)
        Events.piece_index_changed.emit(self)
        name = "piece_" + str(value)
        _interactable = index >= _grid_size_x

        




func init(piece_res: PieceRes, grid_size_x: int):
    self._piece_res = piece_res
    self._grid_size_x = grid_size_x

func _ready():
    assert(_piece_res, "call init() before instantiate")
    assert(label_index, "missing child label_index")
    texture_rect.texture = _piece_res.sprite
    
    texture_rect.piece = self

func on_score(multiplier):
    var score = _piece_res.points * multiplier
    Events.piece_scored.emit(int(score))
    return score

func set_selected(on: bool) -> void:
    # Tap-tap selection affordance (fun-review H3): brighten tint + ~10%
    # scale so the picked piece is obvious. Cleared before any swap/score
    # animation, so it never fights the piece tweener.
    texture_rect.pivot_offset = texture_rect.size / 2.0
    var target_scale := Vector2(1.1, 1.1) if on else Vector2.ONE
    var target_mod := Color(1.3, 1.3, 1.35) if on else Color.WHITE
    var tw := create_tween().set_parallel(true)
    tw.tween_property(texture_rect, "scale", target_scale, 0.08)
    tw.tween_property(texture_rect, "modulate", target_mod, 0.08)
