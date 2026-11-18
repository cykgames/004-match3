extends Control

@onready var score_label: Label = $Background/MarginContainer/VBoxContainer/ScoreLabel
var _score_value: String = ""

func _ready():
    assert(not _score_value.is_empty(), "call init() first")
    score_label.text = _score_value

func init(score):
    _score_value= str(score)

func _on_button_pressed():
    self.queue_free()

func _on_retry_pressed():
    # Restart straight into a new game (no trip through the main menu).
    # main.gd owns restart_game(); this overlay is its direct child.
    var m = get_parent()
    if m != null and m.has_method("restart_game"):
        m.restart_game()
