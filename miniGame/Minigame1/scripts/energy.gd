extends CharacterBody2D 

@export var speed := 150.0 
var canmove = true 

func _physics_process(_delta): 
	if canmove: 
		var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") 
		 
		velocity = direction * speed 
		move_and_slide() 

func fadeout(): 
	var tween = create_tween() 
	tween.tween_property($Sprite2D, "modulate:a", 0.0, 0.5)
	
	await tween.finished
	
	await get_tree().create_timer(1.0).timeout
	get_tree().reload_current_scene()
