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
	if not _pode_ligar_disjuntor_do_data_center():
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
	if ligado:
		_registrar_energia_restaurada()

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


func _pode_ligar_disjuntor_do_data_center() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return true
	var state: Dictionary = SaveGame.office_mission_state(player)
	if not bool(state.get("data_center_power_outage", false)):
		return true
	if bool(state.get("data_center_breaker_restored", false)):
		return false
	if player.inventory.get_item_on_inventary("lanterna"):
		return true
	player.balao_de_pensamento.enfileirar(
		"data_center:need_flashlight_for_breaker",
		"Preciso de uma lanterna para chegar até o disjuntor."
	)
	return false


func _registrar_energia_restaurada() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	if not bool(state.get("data_center_power_outage", false)):
		return
	if bool(state.get("data_center_breaker_restored", false)):
		return
	if not player.inventory.get_item_on_inventary("lanterna"):
		return
	state["data_center_breaker_restored"] = true
	if not bool(state.get("data_center_time_restored", false)):
		var timer := get_tree().get_first_node_in_group("temporizador_jogo")
		if timer != null and timer.has_method("get_tempo_restante"):
			var remaining := float(timer.call("get_tempo_restante"))
			timer.call("carregar_tempo_restante", remaining * 2.0)
		state["data_center_time_restored"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	MusicController._stop_power_outage_audio()
	var quest_ui := player.get_node_or_null("QUEST_MISSION") as QuestMissionUI
	if quest_ui != null:
		quest_ui.show_data_center_power_tasks(
			true,
			bool(state.get("data_center_tools_floor_task_completed", false)),
			true
		)
	SaveGame.create_checkpoint(player)
