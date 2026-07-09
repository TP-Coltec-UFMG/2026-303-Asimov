class_name Player extends CharacterBody2D

@onready var camera_2d: Camera2D = $Camera2D

var cardinal_direction : Vector2 = Vector2.DOWN
var direction : Vector2 = Vector2.ZERO
var move_speed : float = 40
var state : String = "idle"

@onready var sfx_walking: AudioStreamPlayer2D = $sfx_walking

@onready var occluder_side: LightOccluder2D = $Sprite2D/OccluderSide
@onready var occluder_back: LightOccluder2D = $Sprite2D/OccluderBack
@onready var occluder_front: LightOccluder2D = $Sprite2D/OccluderFront


@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D


@onready var inteligencia: TextureProgressBar = $Control/Inteligencia
@onready var vida_1: TextureProgressBar = $Control/Vida1
@onready var vida_2: TextureProgressBar = $Control/Vida2
@onready var vida_3: TextureProgressBar = $Control/Vida3


@onready var inventory: Inventory = $Control/Inventory


var usando_lanterna = false
var usando_arma = false
var usando_cartao = false
var usando_laptop = false
var usando_faca = false

var correndo = false
var andando = false
var cansaco = 0

const vida_total = 300

func _ready() -> void:
	add_to_group("player")


func _process(_delta: float) -> void:
	direction.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	direction.y = Input.get_action_strength("down") - Input.get_action_strength("up")
	
	if Input.is_action_pressed("correr") and state != "idle":
		if cansaco <= 1:
			correndo = true
			andando = false
			UpdateAnimation()
			move_speed = 80 - int((40 * cansaco))
			cansaco += 0.0001
	else:
		if cansaco >= 1 - (get_vida() / vida_total):
			cansaco -= 0.00007
		correndo = false
		UpdateAnimation()
		move_speed = 40
	
	velocity = direction * move_speed
	
	_update_walking_sfx()
	
	if SetState() == true || SetDirection() == true:
		UpdateAnimation()
		UpdateOccluderLight()
		
	if usando_lanterna:
		inventory.get_item_control("lanterna").update_position_luz()


func _update_walking_sfx() -> void:
	var esta_andando := direction.length() > 0.0

	if esta_andando:
		if not sfx_walking.playing:
			sfx_walking.play()

		if move_speed <= 40:
			sfx_walking.pitch_scale = 1.0
		else:
			sfx_walking.pitch_scale = lerp(1.0, 1.8, clamp(move_speed / 80.0, 0.0, 1.0))
	else:
		if sfx_walking.playing:
			sfx_walking.stop()


func _physics_process(_delta: float) -> void:
	move_and_slide()


func SetDirection() -> bool:
	var new_direction : Vector2 = cardinal_direction
	
	if direction == Vector2.ZERO:
		return false
	if direction.y == 0:
		new_direction = Vector2.LEFT if direction.x < 0 else Vector2.RIGHT
	elif direction.x == 0:
		new_direction = Vector2.UP if direction.y < 0 else Vector2.DOWN
		
	if new_direction == cardinal_direction:
		return false
	
	cardinal_direction = new_direction
	sprite.scale.x = -1 if cardinal_direction == Vector2.LEFT else 1
	occluder_side.scale.x = -1 if cardinal_direction == Vector2.LEFT else 1
	return true


func SetState() -> bool:
	var new_state : String = "idle" if direction == Vector2.ZERO else "walk"
	if new_state == state:
		return false
	
	state = new_state
	return true


func UpdateAnimation() -> void:
	animation_player.play(state + "_" + AnimDirection())
	if correndo and cansaco <= 0.5:
		animation_player.speed_scale = 2.0
	else:
		animation_player.speed_scale = 1.0
	pass


func UpdateOccluderLight() -> void:
	var _direction = AnimDirection()
	occluder_front.visible = true if _direction == "down" else false
	occluder_back.visible = true if _direction == "up" else false
	occluder_side.visible = true if _direction == "side" else false


func AnimDirection() -> String:
	if cardinal_direction == Vector2.DOWN:
		return "down"
	elif cardinal_direction == Vector2.UP:
		return "up"
	else:
		return 'side'


func reset_sprite_player() -> void:
	usando_lanterna = false
	var lanterna = inventory.get_item_control("lanterna")
	if lanterna != null:
		lanterna.set_luz(false)
	usando_arma = false
	usando_cartao = false
	usando_laptop = false
	usando_faca = false
	$Sprite2D.texture = preload("res://Player/Sprites/Alex_16x16.png")


func _input(event: InputEvent) -> void:

	if event.is_action_pressed("use_lanterna") and inventory.get_item_on_inventary("lanterna"):
		var lanterna = inventory.get_item_control("lanterna")
		lanterna.set_player(self)

		if usando_lanterna:
			lanterna.set_luz(false)
			reset_sprite_player()
		else:
			reset_sprite_player()
			usando_lanterna = true
			lanterna.set_luz(true)
			$Sprite2D.texture = preload("res://Player/Sprites/Alex_com_lanterna16x16.png")

	if event.is_action_pressed("use_arma") and inventory.get_item_on_inventary("gun"):
		var gun = inventory.get_item_control("gun")
		gun.set_player(self)
		
		if usando_arma:
			reset_sprite_player()
		else:
			reset_sprite_player()
			usando_arma = true
			$Sprite2D.texture = preload("res://Player/Sprites/Alex_com_arma16x16.png")

	if event.is_action_pressed("use_cartao") and inventory.get_item_on_inventary("cartao"):
		var cartao = inventory.get_item_control("cartao")
		cartao.set_player(self)
		
		if usando_cartao:
			reset_sprite_player()
		else:
			reset_sprite_player()
			usando_cartao = true
			if cartao.tipo == 3:
				$Sprite2D.texture = preload("res://Player/Sprites/Alex_com_cartao_chefe16x16.png")
			elif cartao.tipo == 2:
				$Sprite2D.texture = preload("res://Player/Sprites/Alex_com_cartao_forte16x16.png")
			else:
				$Sprite2D.texture = preload("res://Player/Sprites/Alex_com_cartao_padrao16x16.png")
				

	if event.is_action_pressed("use_laptop") and inventory.get_item_on_inventary("laptop"):
		var laptop = inventory.get_item_control("laptop")
		laptop.set_player(self)
		
		if usando_laptop:
			reset_sprite_player()
		else:
			reset_sprite_player()
			usando_laptop = true
			$Sprite2D.texture = preload("res://Player/Sprites/Alex_com_laptop16x16.png")


	if event.is_action_pressed("use_faca") and inventory.get_item_on_inventary("faca"):
		var faca = inventory.get_item_control("faca")
		faca.set_player(self)
		
		if usando_faca:
			reset_sprite_player()
		else:
			reset_sprite_player()
			usando_faca = true
			$Sprite2D.texture = preload("res://Player/Sprites/Alex_com_faca16x16.png")	


func _on_animation_player_current_animation_changed(_name: StringName) -> void:
	if usando_lanterna:
		inventory.get_item_control("lanterna").update_position_luz()


func put_conhecimento() -> void:
	inteligencia.value += 10


func get_conhecimento() -> float:
	return inteligencia.value


func tomar_dano(dano: float) -> void:
	if vida_3.value + dano <= 100:
		vida_3.value += dano
		atualizar_estamina_apos_dano()
	else:
		var dano_restante = (vida_3.value + dano) - 100
		print(dano_restante)
		vida_3.value = 100
		if vida_2.value + dano_restante <= 100:
			vida_2.value += dano_restante
			atualizar_estamina_apos_dano()
		else:
			var dano_restante_2 = (vida_2.value + dano_restante) - 100
			print(dano_restante_2)
			vida_2.value = 100
			if vida_1.value + dano_restante_2 < 100:
				vida_1.value += dano_restante_2
				atualizar_estamina_apos_dano()
			else:
				vida_1.value = 100
				print("morreu")


func get_vida() -> float:
	return 300 - (vida_1.value + vida_2.value + vida_3.value)


func atualizar_estamina_apos_dano() -> void:
	cansaco = 1 - get_vida() / vida_total
	return
