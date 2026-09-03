extends Area2D

@onready var anti_hack: Node2D = $".."
@onready var energy: CharacterBody2D = $"../../../Energy"

var triggered = false

func _physics_process(_delta):
	if triggered or not visible:
		return

	for body in get_overlapping_bodies():
		if body.name == "Energy":
			triggered = true
			
			energy.canmove = false
			energy.fadeout()
			
			await get_tree().create_timer(0.1).timeout
			anti_hack.process_mode = Node.PROCESS_MODE_DISABLED
			
			return
