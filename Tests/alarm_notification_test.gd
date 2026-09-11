extends Node

const PLAYER_SCENE := preload("res://Player/ManPlayer.tscn")


func _ready() -> void:
	MusicController.stop_all_audio()
	var player := PLAYER_SCENE.instantiate() as Player
	player.checkpoint_enabled = false
	add_child(player)
	await get_tree().process_frame

	if not InputMap.has_action("toggle_alarm"):
		_fail("A ação remapeável do alarme não existe.")
		return
	MusicController._start_som_alarme()
	var alarm_tip := player.get_node("CanvasLayer/AlarmTip") as Button
	if alarm_tip.visible:
		_fail("O AlarmTip deve permanecer invisível.")
		return

	var normal_volume := linear_to_db(
		db_to_linear(MusicController.alarm_normal_volume_db)
		* MusicController.ALARM_REDUCED_VOLUME
	)
	MusicController._apply_alarm_volume(normal_volume)
	MusicController.set_alarm_quiet_context(&"test", true)
	var quiet_volume := linear_to_db(
		db_to_linear(MusicController.alarm_normal_volume_db)
		* MusicController.ALARM_QUIET_CONTEXT_VOLUME
	)
	if not is_equal_approx(MusicController.som_alarme.volume_db, quiet_volume):
		_fail("O alarme não caiu para 5% no contexto reduzido.")
		return
	MusicController.set_alarm_quiet_context(&"test", false)
	if not is_equal_approx(MusicController.som_alarme.volume_db, normal_volume):
		_fail("O alarme não recuperou o volume anterior ao sair do contexto.")
		return

	var event := InputEventAction.new()
	event.action = "toggle_alarm"
	event.pressed = true
	player._input(event)
	if not MusicController.alarm_user_muted or MusicController.som_alarme.playing:
		_fail("A ação configurada não desligou o alarme.")
		return
	if not alarm_tip.visible or alarm_tip.text != "Alarme desativado":
		_fail("O AlarmTip não mostrou que o alarme foi desativado.")
		return
	player.alarm_tip_tween.custom_step(0.36)
	if alarm_tip.visible:
		_fail("A primeira piscada do estado desativado não ocultou o AlarmTip.")
		return
	player.alarm_tip_tween.custom_step(0.17)
	if not alarm_tip.visible:
		_fail("A primeira piscada do estado desativado não reapareceu.")
		return
	if player.balao_de_pensamento.pensamento_atual_id() != "alarm:disabled_by_player":
		_fail("O pensamento do player não foi iniciado ao desligar o alarme.")
		return
	player._input(event)
	if MusicController.alarm_user_muted or not MusicController.som_alarme.playing:
		_fail("O segundo toque não reativou o alarme.")
		return
	if not alarm_tip.visible or alarm_tip.text != "Alarme ativado":
		_fail("O AlarmTip não mostrou que o alarme foi ativado.")
		return
	player.alarm_tip_tween.custom_step(0.36)
	if alarm_tip.visible:
		_fail("A primeira piscada do estado ativado não ocultou o AlarmTip.")
		return
	player.alarm_tip_tween.custom_step(0.17)
	if not alarm_tip.visible:
		_fail("A primeira piscada do estado ativado não reapareceu.")
		return
	print("ALARM_CONTROL_OK")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
