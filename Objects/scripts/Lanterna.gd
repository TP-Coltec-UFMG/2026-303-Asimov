extends Node2D

@onready var ligando: AudioStreamPlayer2D = $ligando

@onready var luz: PointLight2D = $Luz
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var interectable: Area2D = $Interectable
@onready var point_light_2d: PointLight2D = $PointLight2D

var player: Player = null

var lanterna_acessa: bool = false
var no_chao: bool = true

var desvio_lanterna := 0.0
const LIMITE_LANTERNA := 45.0
const PASSO_SCROLL_LANTERNA := 5.0


func _ready() -> void:
	luz.visible = false
	point_light_2d.visible = false


func set_player(novo_player: Player) -> void:
	player = novo_player
	no_chao = false


func set_luz(ligada: bool) -> void:
	if lanterna_acessa:
		luz.visible = ligada
		point_light_2d.visible = ligada


func update_position_luz() -> void:
	if player == null:
		return

	var offset := Vector2.ZERO
	var animation := player.animation_player.current_animation
	var animation_frame := player.sprite.frame
	var angulo_base := 0.0

	match animation:
		"walk_down":
			offset = Vector2(-6, 4)
			angulo_base = 0

			if animation_frame == 66:
				offset = Vector2(-5, 5)
			if animation_frame == 67:
				offset = Vector2(-4, 6)
			if animation_frame == 68:
				offset = Vector2(-4.5, 6.5)
			if animation_frame == 69:
				offset = Vector2(-7, 2)
			if animation_frame == 70:
				offset = Vector2(-7, 2)

		"idle_down":
			offset = Vector2(-6, 4)
			angulo_base = 0

			if animation_frame == 45:
				offset = Vector2(-7, 3)

		"walk_up":
			offset = Vector2(6, -14)
			angulo_base = 180

			if animation_frame == 54:
				offset = Vector2(6, -16)
			if animation_frame == 55:
				offset = Vector2(6, -17)
			if animation_frame == 56:
				offset = Vector2(6, -15)
			if animation_frame == 57:
				offset = Vector2(7, -15)
			if animation_frame == 58:
				offset = Vector2(7, -15)

		"idle_up":
			offset = Vector2(6, -14)
			angulo_base = 180

			if animation_frame == 33:
				offset = Vector2(6, -15)

		"walk_side":
			offset = Vector2(-4 if player.cardinal_direction == Vector2.LEFT else 4, 1)
			angulo_base = 90 if player.cardinal_direction == Vector2.LEFT else -90

			if animation_frame == 48:
				offset = Vector2(
					-3.5 if player.cardinal_direction == Vector2.LEFT else 3.5,
					1
				)

			if animation_frame == 49:
				offset = Vector2(
					-3.5 if player.cardinal_direction == Vector2.LEFT else 3.5,
					0.5
				)

			if animation_frame == 50:
				offset = Vector2(
					-4 if player.cardinal_direction == Vector2.LEFT else 4,
					1
				)

			if animation_frame == 51:
				offset = Vector2(
					-4.5 if player.cardinal_direction == Vector2.LEFT else 4.5,
					0.5
				)

			if animation_frame == 52:
				offset = Vector2(
					-5 if player.cardinal_direction == Vector2.LEFT else 5,
					0
				)

			if animation_frame == 53:
				offset = Vector2(
					-4 if player.cardinal_direction == Vector2.LEFT else 4,
					1
				)

		"idle_side":
			offset = Vector2(-4 if player.cardinal_direction == Vector2.LEFT else 4, 1)

			angulo_base = 90 if player.cardinal_direction == Vector2.LEFT else -90

			if animation_frame == 27:
				offset = Vector2(
					-4 if player.cardinal_direction == Vector2.LEFT else 4,
					0
				)

	luz.global_position = player.global_position + offset
	luz.rotation_degrees = angulo_base + desvio_lanterna


func _input(event: InputEvent) -> void:
	if not no_chao and player != null and player.usando_lanterna:
		
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				desvio_lanterna -= PASSO_SCROLL_LANTERNA

			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				desvio_lanterna += PASSO_SCROLL_LANTERNA

			desvio_lanterna = clamp(
				desvio_lanterna,
				-LIMITE_LANTERNA,
				LIMITE_LANTERNA
			)

		if event.is_action_pressed("acende_lanterna"):
			ligando.play()
			lanterna_acessa = not lanterna_acessa
			luz.visible = lanterna_acessa
			point_light_2d.visible = lanterna_acessa
