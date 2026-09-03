extends BaseScene

const CUTSCENE_SAVE_ID: String = "cutscene_concluida"

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var camera_cutscene: Camera2D = $AnimationPlayer/Camera2D

var inventario_visivel_antes_da_cutscene: bool = true


func _ready() -> void:
	super._ready()
	
	if SaveGame.load_object_state(CUTSCENE_SAVE_ID) == true:
		aplicar_estado_final()
		call_deferred("atualizar_camera")
		return

	ocultar_barra_do_inventario()
	bloquear_player()

	await get_tree().process_frame

	camera_cutscene.enabled = true
	camera_cutscene.make_current()

	animation_player.play("cutscene")
	get_tree().paused = true
	animation_player.process_mode = Node.PROCESS_MODE_ALWAYS
	await animation_player.animation_finished
	get_tree().paused = false

	aplicar_estado_final()

	SaveGame.save_object_state(CUTSCENE_SAVE_ID, true)
	SaveGame.create_checkpoint(player)

	restaurar_barra_do_inventario()
	desbloquear_player()
	atualizar_camera()


func ocultar_barra_do_inventario() -> void:
	if not is_instance_valid(player) or not is_instance_valid(player.inventory):
		return

	inventario_visivel_antes_da_cutscene = player.inventory.visible
	player.inventory.hide()


func restaurar_barra_do_inventario() -> void:
	if not is_instance_valid(player) or not is_instance_valid(player.inventory):
		return

	player.inventory.visible = inventario_visivel_antes_da_cutscene


func aplicar_estado_final() -> void:
	var animacao: Animation = animation_player.get_animation(
		"cutscene"
	)

	if animacao != null:
		animation_player.play("cutscene")
		animation_player.seek(animacao.length, true)
		animation_player.stop(true)

	camera_cutscene.enabled = false


func bloquear_player() -> void:
	if not is_instance_valid(player):
		return

	player.velocity = Vector2.ZERO

	player.set_process(false)
	player.set_physics_process(false)
	player.set_process_input(false)
	player.set_process_unhandled_input(false)
	player.set_process_unhandled_key_input(false)


func desbloquear_player() -> void:
	if not is_instance_valid(player):
		return

	player.set_process(true)
	player.set_physics_process(true)
	player.set_process_input(true)
	player.set_process_unhandled_input(true)
	player.set_process_unhandled_key_input(true)
