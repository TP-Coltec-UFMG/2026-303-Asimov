extends ColorRect
@onready var timer: Timer = $timer
@onready var transition: AnimatedSprite2D = $Transition

func _ready() -> void:
	timer.start()

func _on_timer_timeout() -> void:
	transition.visible = true
	transition.play("default")
	

func _on_transition_animation_finished() -> void:
	get_tree().change_scene_to_file("res://Minigames/PuzzleDosCanos/tscn/gameplay.tscn")
