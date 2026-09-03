extends Node2D

@export var save_id: String = "dijuntor_principal"
@export var canvas_modulate: CanvasModulate

@onready var sprite_2d: AnimatedSprite2D = $Sprite2D

var ligado: bool = false
var alterando_estado: bool = false


func _ready() -> void:
	call_deferred("carregar_estado_salvo")


func carregar_estado_salvo() -> void:
	var estado_salvo: Variant = SaveGame.load_object_state(save_id)

	if estado_salvo == null:
		return

	ligado = bool(estado_salvo)
	aplicar_estado_visual()


func interagir_dijuntor() -> void:
	if alterando_estado:
		return

	alterando_estado = true

	if ligado:
		sprite_2d.play("default")
		await sprite_2d.animation_finished
		ligado = false
	else:
		sprite_2d.play_backwards("default")
		await sprite_2d.animation_finished
		ligado = true

	aplicar_estado_visual()
	SaveGame.save_object_state(save_id, ligado)

	alterando_estado = false


func aplicar_estado_visual() -> void:
	sprite_2d.stop()
	sprite_2d.animation = "default"

	if ligado:
		sprite_2d.frame = 0
		canvas_modulate.color = Color("b7b7b7ff")
	else:
		sprite_2d.frame = (
			sprite_2d.sprite_frames.get_frame_count("default") - 1
		)

		canvas_modulate.color = Color("#020202")


func _on_pickup_component_interagiu() -> void:
	interagir_dijuntor()
