extends Node

var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	MusicController.set_process(false)
	var player := preload("res://Player/ManPlayer.tscn").instantiate() as Player
	add_child(player)
	scene_manager.player = player
	await get_tree().process_frame
	MusicController.stop_all_audio()
	MusicController._start_som_alarme()
	_expect(MusicController.som_alarme.playing, "O alarme deve estar tocando para iniciar o aviso.")
	MusicController.alarm_hint_elapsed = 119.0
	MusicController._update_alarm_hint(0.5)
	_expect(not player.alarm_tip.visible, "O aviso não deve aparecer antes de dois minutos.")
	MusicController._update_alarm_hint(0.5)
	_expect(player.alarm_tip.visible, "O aviso deve aparecer após dois minutos com o alarme ligado.")
	_expect(player.alarm_tip.text.contains("P"), "O aviso deve indicar a tecla P.")
	var saved_audio := MusicController.get_checkpoint_state()
	_expect(bool(saved_audio.get("alarm_envelope", {}).get("hint_shown", false)), "O aviso exibido deve ser salvo.")
	MusicController.load_checkpoint_state(saved_audio)
	_expect(MusicController.alarm_hint_shown, "O aviso não deve reaparecer após carregar o save.")
	_expect(player._toggle_alarm_from_player(), "A tecla P deve desligar o alarme.")
	_expect(player.alarm_tip.text == "Alarme desativado", "Desligar deve confirmar a ação.")
	MusicController.alarm_hint_shown = false
	MusicController._update_alarm_hint(120.0)
	_expect(player.alarm_tip.text == "Alarme desativado", "O aviso não deve sugerir desligar um alarme já desligado.")
	_expect(player._toggle_alarm_from_player(), "A tecla P deve religar o alarme.")
	_expect(player.alarm_tip.text == "Alarme ativado", "Religar deve confirmar a ação.")
	MusicController.stop_all_audio()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: aviso de dois minutos, tecla P e persistência.")
	get_tree().quit(0 if failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
