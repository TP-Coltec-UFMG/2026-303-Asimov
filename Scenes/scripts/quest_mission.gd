extends CanvasLayer

@export var save_id: String = "hall_quest_01"

@onready var M2: AnimatedSprite2D = (
	$VBoxContainer/HBoxContainer/AnimatedSprite2D
)
@onready var M1: AnimatedSprite2D = (
	$VBoxContainer/HBoxContainer2/AnimatedSprite2D
)

var f1_acesso: bool = true
var f2_acesso: bool = true

var M1_feito: bool = false
var M2_feito: bool = false

var _hide_scheduled: bool = false


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PAUSED:
			$"../UI/Controle_de_tempo".hide()# Oculta a interface quando o menu de pausa abre
			hide()
		NOTIFICATION_UNPAUSED:
			$"../UI/Controle_de_tempo".show()
			if not (M1_feito and M2_feito):
				show()

func _ready() -> void:
	_restore_progress()
	_apply_saved_visuals()

	MusicController._start_som_de_fundo()
	MusicController._stop_bg_ambient()
	MusicController._set_volume_som_de_fundo(1.0)
	await get_tree().create_timer(0.5).timeout
	$"../UI/Transition".play_backwards("default")
	await $"../UI/Transition".animation_finished

	# Ao continuar uma partida já concluída, a lista não reaparece por cinco
	# segundos. Durante a partida normal, as duas marcações ainda ficam visíveis.
	if M1_feito and M2_feito:
		hide()


func _on_fogo_3_fogo_apagou() -> void:
	if not f1_acesso:
		return

	f1_acesso = false
	_update_fire_task()
	_save_progress_and_checkpoint()


func _on_fogo_5_fogo_apagou() -> void:
	if not f2_acesso:
		return

	f2_acesso = false
	_update_fire_task()
	_save_progress_and_checkpoint()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if not body is Player or M2_feito:
		return

	M2_feito = true
	M2.play(&"default")
	_save_progress_and_checkpoint()
	_check_all_tasks_completed()


func _update_fire_task() -> void:
	if f1_acesso or f2_acesso or M1_feito:
		return

	M1_feito = true
	M1.play(&"default")
	_check_all_tasks_completed()


func _check_all_tasks_completed() -> void:
	if not M1_feito or not M2_feito or _hide_scheduled:
		return

	_hide_scheduled = true
	_hide_after_completion()


func _hide_after_completion() -> void:
	await get_tree().create_timer(5.0).timeout

	if is_inside_tree():
		hide()


func _save_progress_and_checkpoint() -> void:
	SaveGame.save_object_state(save_id, {
		"fire_1_done": not f1_acesso,
		"fire_2_done": not f2_acesso,
		"task_fire_done": M1_feito,
		"task_elevator_done": M2_feito
	})

	# O fogo cria o próprio checkpoint antes de emitir fogo_apagou. Um novo
	# checkpoint aqui garante que a tarefa recém-concluída entre no mesmo save.
	var player := get_tree().get_first_node_in_group("player") as Player

	if player != null and player.checkpoint_enabled:
		SaveGame.create_checkpoint(player)


func _restore_progress() -> void:
	var saved_value: Variant = SaveGame.load_object_state(save_id)

	if saved_value is Dictionary:
		var saved_state: Dictionary = saved_value
		f1_acesso = not bool(saved_state.get("fire_1_done", false))
		f2_acesso = not bool(saved_state.get("fire_2_done", false))
		M1_feito = bool(saved_state.get("task_fire_done", false))
		M2_feito = bool(saved_state.get("task_elevator_done", false))
	else:
		# Migração de checkpoints antigos: os fogos já tinham estado próprio,
		# então a primeira tarefa pode ser reconstruída sem perder progresso.
		f1_acesso = not _is_saved_fire_extinguished("fogo04")
		f2_acesso = not _is_saved_fire_extinguished("fogo05")
		M1_feito = not f1_acesso and not f2_acesso

	if not f1_acesso and not f2_acesso:
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

	var frame_count := marker.sprite_frames.get_frame_count(&"default")
	marker.animation = &"default"
	marker.frame = maxi(frame_count - 1, 0)
