extends CanvasLayer

@export var save_id: String = "hall_quest_01"

@onready var M2: AnimatedSprite2D = (
	$VBoxContainer/HBoxContainer/AnimatedSprite2D
)
@onready var M1: AnimatedSprite2D = (
	$VBoxContainer/HBoxContainer2/AnimatedSprite2D
)

var man_player: Player
var _inicializado: bool = false
signal orientacao_elevador_iniciada
signal pensamento_extintor_iniciado
var orientar_elevador: bool = false
var orientar_extintor: bool = false

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

			_atualizar_visibilidade()


func _ready() -> void:
	hide()
	# BaseScene escolhe o Player persistente e aplica o checkpoint no _ready.
	call_deferred("_inicializar")


func _inicializar() -> void:
	man_player = get_parent().player as Player
	if not is_instance_valid(man_player):
		return

	_restore_progress()
	_apply_saved_visuals()
	_inicializado = true
	man_player.balao_de_pensamento.pensamento_finalizado.connect(_on_pensamento_finalizado)
	man_player.balao_de_pensamento.pensamento_iniciado.connect(_on_pensamento_iniciado)

	MusicController._start_som_de_fundo()
	MusicController._stop_bg_ambient()
	MusicController._set_volume_som_de_fundo(1.0)
	_descartar_instrucoes_obsoletas()
	# O Player pode ter restaurado a fala antes da conexão dos sinais da missão.
	_on_pensamento_iniciado(man_player.balao_de_pensamento.pensamento_atual_id())

	if _hide_scheduled:
		_start_npc_exit_paths(true)
		_atualizar_visibilidade()
		return

	# Registra a sequência inteira, inclusive as falas que ainda não começaram.
	_pensar("intro_1", "O que está acontecendo?")
	_pensar("intro_2", "Temos que sair desse andar!")
	_pensar("intro_4", "Preciso de um extintor.")
	_atualizar_visibilidade()
	_tentar_finalizar_missao()


func _pensamento_id(id: String) -> String:
	return "hall:" + save_id + ":" + id


func _pensar(id: String, texto: String) -> void:
	man_player.balao_de_pensamento.enfileirar(_pensamento_id(id), texto)


func _pensamento_pendente(id: String) -> bool:
	var balao = man_player.balao_de_pensamento
	return balao.esta_pendente(_pensamento_id(id))


func _descartar_instrucoes_obsoletas() -> void:
	# Remove também a fala antiga quando ela vier ativa ou enfileirada no save.
	var ids: Array[String] = [_pensamento_id("intro_3")]
	if M1_feito:
		ids.append_array([_pensamento_id("intro_4"), _pensamento_id("aviso_1"), _pensamento_id("aviso_2")])
	if M2_feito:
		ids.append(_pensamento_id("pedras"))
	if M1_feito and M2_feito:
		ids.append_array([_pensamento_id("intro_1"), _pensamento_id("intro_2"), _pensamento_id("intro_3")])
	if not ids.is_empty():
		man_player.balao_de_pensamento.descartar(ids)


func _atualizar_visibilidade() -> void:
	if not _inicializado or get_tree().paused:
		return
	var balao = man_player.balao_de_pensamento
	visible = balao.foi_concluido(_pensamento_id("intro_2")) and not (_hide_scheduled and not _pensamento_pendente("saida"))


func _on_pensamento_iniciado(id: String) -> void:
	if id == _pensamento_id("intro_2") and not orientar_elevador:
		orientar_elevador = true
		orientacao_elevador_iniciada.emit()
	if id == _pensamento_id("intro_4") and not orientar_extintor:
		orientar_extintor = true
		pensamento_extintor_iniciado.emit()


func _on_pensamento_finalizado(id: String) -> void:
	if id == _pensamento_id("intro_2"):
		_atualizar_visibilidade()
	elif id == _pensamento_id("saida"):
		_hide_after_completion()


func _on_fogo_3_fogo_apagou() -> void:
	if not f1_acesso:
		return

	f1_acesso = false

	_update_fire_task()
	if not _tentar_finalizar_missao():
		_save_progress_and_checkpoint()


func _on_fogo_5_fogo_apagou() -> void:
	if not f2_acesso:
		return

	f2_acesso = false

	_update_fire_task()
	if not _tentar_finalizar_missao():
		_save_progress_and_checkpoint()


func _on_fogo_6_fogo_apagou() -> void:
	if not f3_acesso:
		return

	f3_acesso = false

	_update_fire_task()
	if not _tentar_finalizar_missao():
		_save_progress_and_checkpoint()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if not body is ObjetoEmpurravel:
		return

	if M2_feito:
		return

	M2_feito = true
	M2.play(&"default")

	if not M1_feito:
		_pensar("aviso_1", "Tenho que apagar todos os fogos!")
		_pensar("aviso_2", "Não é seguro passar assim.")

	if not _tentar_finalizar_missao():
		_save_progress_and_checkpoint()


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

	if not M2_feito:
		_pensar("pedras", "Só preciso tirar essas pedras do caminho!")


func _tentar_finalizar_missao() -> bool:
	if not _inicializado:
		return false
	_descartar_instrucoes_obsoletas()
	if not M1_feito:
		return false

	if not M2_feito:
		return false

	if _hide_scheduled:
		return false

	_hide_scheduled = true

	_start_npc_exit_paths()
	_pensar("saida", "Saiam todos! SAIAM, SAIAM, SAIAM!!")
	_save_progress_and_checkpoint()
	return true


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
			"task_elevator_done": M2_feito,
			"exit_started": _hide_scheduled
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
		# Saves antigos só registravam as tarefas, sem a etapa de saída.
		_hide_scheduled = bool(saved_state.get("exit_started", M1_feito and M2_feito))

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
