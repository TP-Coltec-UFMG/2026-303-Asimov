extends Node2D

var player: Player = null

@export var save_id: String = "arma"
var no_inventario: bool = false

@onready var position_on_player: Sprite2D = $Position_on_player
@onready var timer: Timer = $Timer
@onready var reticula: Sprite2D = $reticula

const BULLET = preload("res://bullet.tscn")

func _ready() -> void:
	if not no_inventario:
		if SaveGame.is_object_collected(save_id):
			queue_free()
			return
			
	set_process(false)

func foi_coletado() -> void:
	SaveGame.set_object_collected(save_id)

func marcar_como_item_inventario() -> void:
	no_inventario = true
	
func set_player(novo_player: Player) -> void:
	player = novo_player
	set_process(true)


func _process(_delta: float) -> void:
	position_on_player.look_at(get_global_mouse_position())
	
	#if player.usando_arma:
	#	reticula.show()
	#	reticula.global_position = get_global_mouse_position()
	
	position_on_player.rotation_degrees = wrap(position_on_player.rotation_degrees, 0, 360)
		
	if Input.is_action_just_pressed("fire") and player.usando_arma:
		var bullet_instance = BULLET.instantiate()
		get_tree().root.add_child(bullet_instance)
		bullet_instance.global_position = position_on_player.global_position
		bullet_instance.rotation = position_on_player.rotation
		timer.start()
		await timer.timeout
		bullet_instance.show()
