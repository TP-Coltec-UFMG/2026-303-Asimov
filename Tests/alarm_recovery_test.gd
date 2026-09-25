extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	set_meta(&"dev_mission_jump_active", true)
	_run.call_deferred()


func _run() -> void:
	var music := root.get_node("MusicController")
	music.stop_all_audio()
	var alarm := music.get_node("SOM_ALARME") as AudioStreamPlayer
	_check(alarm.bus == &"sfx", "O volume da música não pode silenciar o alarme.")
	_check((alarm.stream as AudioStreamMP3).loop, "O alarme precisa repetir.")
	music._start_som_alarme(alarm.stream.get_length() - 0.15)
	await create_timer(0.5).timeout
	_check(alarm.playing, "O alarme deve continuar após o fim da gravação.")
	music.toggle_alarm_by_player()
	_check(not alarm.playing, "P deve desligar o alarme.")
	music.toggle_alarm_by_player()
	_check(alarm.playing, "P deve religar o alarme.")
	paused = true
	await create_timer(0.1).timeout
	_check(alarm.stream_paused, "O menu de pausa deve silenciar o alarme.")
	paused = false
	var state: Dictionary = music.get_checkpoint_state()
	state["som_alarme"]["playing"] = false
	music.begin_checkpoint_restore()
	music._start_som_alarme()
	music.load_checkpoint_state(state)
	_check(alarm.playing, "Um save afetado pelo fim do arquivo deve recuperar o alarme da cena.")
	state["alarm_envelope"]["user_muted"] = true
	music.begin_checkpoint_restore()
	music._start_som_alarme()
	music.load_checkpoint_state(state)
	_check(not alarm.playing, "Um save silenciado com P deve continuar silenciado.")
	music.stop_all_audio()
	print("ALARM_RECOVERY_TEST: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
