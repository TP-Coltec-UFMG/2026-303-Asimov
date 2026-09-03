extends CharacterBody2D

@export var speed := 6.0

@onready var sprite: Sprite2D = $Sprite2D

var moving := false
var direction := Vector2.ZERO


func _process(delta: float) -> void:
	if position.x < 0 or position.x > 480 or position.y < 0 or position.y > 270:
		await get_tree().create_timer(1).timeout
		get_tree().reload_current_scene()

func _physics_process(_delta: float) -> void:
	if not moving:
		get_direction()

		if Input.is_action_just_pressed("move") and direction != Vector2.ZERO:
			moving = true

	if moving:
		move()


func get_direction() -> void:
	if Input.is_action_pressed("ui_up"):
		direction = Vector2.UP
		sprite.rotation_degrees = 0

	elif Input.is_action_pressed("ui_right"):
		direction = Vector2.RIGHT
		sprite.rotation_degrees = 90

	elif Input.is_action_pressed("ui_down"):
		direction = Vector2.DOWN
		sprite.rotation_degrees = 180

	elif Input.is_action_pressed("ui_left"):
		direction = Vector2.LEFT
		sprite.rotation_degrees = 270


func move() -> void:
	var collision := move_and_collide(direction * speed)

	if collision:
		moving = false
		direction = Vector2.ZERO
