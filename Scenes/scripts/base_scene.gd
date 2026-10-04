class_name BaseScene
extends Node

const OFFICE_EMPTY_THOUGHT_ID: String = "office:empty_floor"
const HALL_EXIT_THOUGHT_IDS: Array[String] = [
	"hall:hall_quest_01:pos_saida_1",
	"hall:hall_quest_01:pos_saida_2",
]
const OFFICE_EMPTY_THOUGHT_DELAY: float = 6.0
const OPENING_BLUR_SCENE: PackedScene = preload(
	"res://Cutscenes/opening_gameplay_blur.tscn"
)
const OPENING_BLUR_META: StringName = &"intro_opening_blur"

var player: Player = null

@onready var entrance_markers: Node2D = $EntranceMarkers


func _ready() -> void:
	_start_opening_blur_if_requested()
	var scene_player: Player = get_scene_player()

	if is_instance_valid(scene_manager.player):
		if is_instance_valid(scene_player) and scene_player != scene_manager.player:
			if scene_player.get_parent() != null:
				scene_player.get_parent().remove_child(scene_player)

			scene_player.queue_free()

		player = scene_manager.player

		if player.get_parent() != null:
			player.get_parent().remove_child(player)

		add_child(player)

	elif is_instance_valid(scene_player):
		player = scene_player
		scene_manager.player = player

	elif SaveGame.restore_checkpoint_pending:
		player = SaveGame.create_player_from_checkpoint()

		if player == null:
			push_error(
				"Não foi possível criar o Player para carregar o checkpoint."
			)
			return

		add_child(player)
		scene_manager.player = player

	else:
		push_error(
			"A cena " + name
			+ " não possui Player e não existe Player persistente."
		)
		return

	var restaurou_checkpoint: bool = (
		SaveGame.apply_pending_checkpoint(player)
	)

	if not restaurou_checkpoint:
		position_player()

		if not SaveGame.has_checkpoint():
			SaveGame.create_checkpoint(player)

	call_deferred("atualizar_camera")
	call_deferred("_registrar_chegada_escritorio")


func _start_opening_blur_if_requested() -> void:
	if not bool(get_tree().get_meta(OPENING_BLUR_META, false)):
		return
	get_tree().remove_meta(OPENING_BLUR_META)
	var blur_overlay := OPENING_BLUR_SCENE.instantiate()
	add_child(blur_overlay)


func get_scene_player() -> Player:
	for child in get_children():
		if child is Player:
			return child as Player

	return null


func position_player() -> void:
	if player == null:
		return

	var last_scene: String = scene_manager.last_scene_name

	if last_scene.is_empty():
		for entrance in entrance_markers.get_children():
			if entrance is Marker2D and entrance.name == "start_game_position":
				player.global_position = entrance.global_position
				return

	if not last_scene.is_empty():
		for entrance in entrance_markers.get_children():
			if entrance is Marker2D and entrance.name == last_scene:
				player.global_position = entrance.global_position
				return

	for entrance in entrance_markers.get_children():
		if entrance is Marker2D and entrance.name == "any":
			player.global_position = entrance.global_position
			return


func atualizar_camera() -> void:
	if player == null:
		return

	var camera: Camera2D = player.get_node_or_null(
		"Camera2D"
	) as Camera2D

	if camera == null:
		return

	camera.enabled = true
	camera.make_current()
	camera.reset_smoothing()
	camera.force_update_scroll()


func _registrar_chegada_escritorio() -> void:
	if not is_inside_tree() or not is_instance_valid(player):
		return
	if not get_tree().current_scene.scene_file_path.ends_with("andar_escritorio.tscn"):
		return
	var estado := SaveGame.office_mission_state(player)
	if not bool(estado.get("elevator_third_floor_unlocked", false)):
		return
	var primeira_chegada := not bool(estado.get("arrived_third_floor", false))
	if primeira_chegada:
		estado["arrived_third_floor"] = true
		SaveGame.save_global_state("hall_quest_01", estado)
		player.balao_de_pensamento.descartar(HALL_EXIT_THOUGHT_IDS)
	var quest_ui := player.get_node_or_null("QUEST_MISSION") as QuestMissionUI
	if quest_ui != null:
		if primeira_chegada:
			quest_ui.concluir_terceiro_andar()
		else:
			quest_ui.restaurar_estado_salvo()
	var balao := player.balao_de_pensamento
	var pensamento_novo: bool = not balao.tem_pensamento(OFFICE_EMPTY_THOUGHT_ID)
	if pensamento_novo:
		_agendar_pensamento_escritorio_vazio()
	if player.checkpoint_enabled and (
		primeira_chegada
		or bool(estado.get("office_boss_room_hacked", false))
	):
		SaveGame.create_checkpoint(player)


func _agendar_pensamento_escritorio_vazio() -> void:
	await get_tree().create_timer(OFFICE_EMPTY_THOUGHT_DELAY, false).timeout
	if not is_inside_tree() or not is_instance_valid(player):
		return
	if get_tree().current_scene != self:
		return
	var balao := player.balao_de_pensamento
	if balao.tem_pensamento(OFFICE_EMPTY_THOUGHT_ID):
		return
	balao.enfileirar_dialogo("base_scene.agendar_pensamento_escritorio_vazio.player", OFFICE_EMPTY_THOUGHT_ID)
	if player.checkpoint_enabled:
		SaveGame.create_checkpoint(player)
