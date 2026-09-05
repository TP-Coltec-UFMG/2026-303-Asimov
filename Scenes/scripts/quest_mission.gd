extends CanvasLayer

@export var save_id: String = "hall_quest_01"

@onready var M2: AnimatedSprite2D = (
	$VBoxContainer/HBoxContainer/AnimatedSprite2D
)
@onready var M1: AnimatedSprite2D = (
	$VBoxContainer/HBoxContainer2/AnimatedSprite2D
)

@onready var man_player = $"../ManPlayer"

var f1_acesso: bool = true
var f2_acesso: bool = true
var f3_acesso: bool = true

var M1_feito: bool = false
var M2_feito: bool = false

var _hide_scheduled: bool = false


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PAUSED:
			$"../UI/Controle_de_tempo".hide()
			hide()

		NOTIFICATION_UNPAUSED:
			$"../UI/Controle_de_tempo".show()

			if not (M1_feito and M2_feito):
				show()


func _ready() -> void:
	hide()

	_restore_progress()
	_apply_saved_visuals()

	MusicController._start_som_de_fundo()
	MusicController._stop_bg_ambient()
	MusicController._set_volume_som_de_fundo(1.0)

	if M1_feito and M2_feito:
		_hide_scheduled = true
		_start_npc_exit_paths(true)
		hide()
		return

	await man_player._mostrar_no_balao_de_pensamento(
		"O que está acontecendo?"
	)

	await man_player._mostrar_no_balao_de_pensamento(
		"Temos que sair desse andar!"
	)

	await man_player._mostrar_no_balao_de_pensamento(
		"Como?!"
	)

	show()

	await man_player._mostrar_no_balao_de_pensamento(
		"Preciso de um extintor."
	)


func _on_fogo_3_fogo_apagou() -> void:
	if not f1_acesso:
		return

	f1_acesso = false

	_save_progress_and_checkpoint()
	_update_fire_task()


func _on_fogo_5_fogo_apagou() -> void:
	if not f2_acesso:
		return

	f2_acesso = false

	_save_progress_and_checkpoint()
	_update_fire_task()


func _on_fogo_6_fogo_apagou() -> void:
	if not f3_acesso:
		return

	f3_acesso = false

	_save_progress_and_checkpoint()
	_update_fire_task()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if not body is ObjetoEmpurravel:
		return

	if M2_feito:
		return

	M2_feito = true
	M2.play(&"default")

	_save_progress_and_checkpoint()

	if not M1_feito:
		await man_player._mostrar_no_balao_de_pensamento(
			"Tenho que apagar todos os fogos!"
		)

		await man_player._mostrar_no_balao_de_pensamento(
			"Não é seguro passar assim."
		)

	_tentar_finalizar_missao()


func _update_fire_task() -> void:
	if f1_acesso:
		return

	if f2_acesso:
		return

	if f3_acesso:
		return

	if M1_feito:
		return

	M1_feito = true
	M1.play(&"default")

	_save_progress_and_checkpoint()

	await man_player._mostrar_no_balao_de_pensamento(
		"Só preciso tirar essas pedras do caminho!"
	)

	_tentar_finalizar_missao()


func _tentar_finalizar_missao() -> void:
	if not M1_feito:
		return

	if not M2_feito:
		return

	if _hide_scheduled:
		return

	_hide_scheduled = true

	_start_npc_exit_paths()
	_save_progress_and_checkpoint()

	await man_player._mostrar_no_balao_de_pensamento(
		"Saiam todos! SAIAM, SAIAM, SAIAM!!"
	)

	await _hide_after_completion()


func _start_npc_exit_paths(legacy_restore: bool = false) -> void:
	var npcs := get_node_or_null("../NPCs")

	if npcs == null:
		return

	for npc in npcs.get_children():
		if npc.is_queued_for_deletion():
			continue

		var path := npc.get_node_or_null("Line2D2") as NPCPath

		if path == null:
			continue

		if legacy_restore:
			if not npc.get_script():
				continue

			if npc.get("checkpoint_restored") != false:
				continue

			path.start_path()

			var points: Variant = npc.get("path_points")

			if points is Array and not points.is_empty():
				npc.global_position = points[0]

		else:
			path.start_path()


func _hide_after_completion() -> void:
	await get_tree().create_timer(5.0).timeout

	if is_inside_tree():
		hide()


func _save_progress_and_checkpoint() -> void:
	SaveGame.save_object_state(
		save_id,
		{
			"fire_1_done": not f1_acesso,
			"fire_2_done": not f2_acesso,
			"fire_3_done": not f3_acesso,
			"task_fire_done": M1_feito,
			"task_elevator_done": M2_feito
		}
	)

	var player := get_tree().get_first_node_in_group("player") as Player

	if player != null and player.checkpoint_enabled:
		SaveGame.create_checkpoint(player)


func _restore_progress() -> void:
	var saved_value: Variant = SaveGame.load_object_state(save_id)

	if saved_value is Dictionary:
		var saved_state: Dictionary = saved_value

		f1_acesso = not bool(
			saved_state.get("fire_1_done", false)
		)

		f2_acesso = not bool(
			saved_state.get("fire_2_done", false)
		)

		if saved_state.has("fire_3_done"):
			f3_acesso = not bool(
				saved_state.get("fire_3_done", false)
			)
		else:
			f3_acesso = not _is_saved_fire_extinguished("fogo06")

		M1_feito = bool(
			saved_state.get("task_fire_done", false)
		)

		M2_feito = bool(
			saved_state.get("task_elevator_done", false)
		)

	else:
		f1_acesso = not _is_saved_fire_extinguished("fogo04")
		f2_acesso = not _is_saved_fire_extinguished("fogo05")
		f3_acesso = not _is_saved_fire_extinguished("fogo06")

		M1_feito = (
			not f1_acesso
			and not f2_acesso
			and not f3_acesso
		)

	if not f1_acesso and not f2_acesso and not f3_acesso:
		M1_feito = true


func _is_saved_fire_extinguished(fire_save_id: String) -> bool:
	var fire_state: Variant = SaveGame.load_object_state(fire_save_id)

	return (
		fire_state is Dictionary
		and bool(fire_state.get("apagado", false))
	)


func _apply_saved_visuals() -> void:
	M1.stop()
	M2.stop()

	M1.frame = 0
	M2.frame = 0

	if M1_feito:
		_set_completed_frame(M1)

	if M2_feito:
		_set_completed_frame(M2)


func _set_completed_frame(marker: AnimatedSprite2D) -> void:
	if marker.sprite_frames == null:
		return

	var frame_count := marker.sprite_frames.get_frame_count(
		&"default"
	)

	marker.animation = &"default"
	marker.frame = maxi(frame_count - 1, 0)
