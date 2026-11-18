extends TextureRect

## Drag-and-drop AND tap-tap selection for pieces (fun-review H3: the old
## drag-only path made a plain tap do nothing). A tap emits piece_clicked;
## the grid turns two taps into a swap. Drag still works unchanged.

var piece: Piece

const _TAP_SLOP := 16.0
var _press_local := Vector2.ZERO
var _press_active := false

func _can_drop_data(_at_position, _data):
    return true

func _get_drag_data(_at_position):
    # A real drag began: cancel any pending tap so press+drag does not also
    # fire a selection click.
    _press_active = false
    return piece

func _drop_data(_at_position, data):
    Events.swap_requested.emit(piece, data)

func _gui_input(event: InputEvent) -> void:
    var pos := Vector2.ZERO
    var pressed := false
    var released := false
    if event is InputEventScreenTouch:
        pos = event.position
        pressed = event.pressed
        released = not event.pressed
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        pos = event.position
        pressed = event.pressed
        released = not event.pressed
    else:
        return
    if pressed:
        _press_active = true
        _press_local = pos
    elif released and _press_active:
        _press_active = false
        # Only a near-stationary press/release inside the rect counts as a
        # tap; a drag is handled by _get_drag_data/_drop_data instead.
        if pos.distance_to(_press_local) <= _TAP_SLOP and Rect2(Vector2.ZERO, size).has_point(pos):
            if piece != null:
                piece.piece_clicked.emit(piece)
