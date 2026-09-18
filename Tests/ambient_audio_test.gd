extends Node

const PLAYER_SCENE := preload("res://Player/ManPlayer.tscn")
const FIRE_SCENE := preload("res://Objects/fogo.tscn")
const ELEVATOR_PANEL_SCENE := preload("res://Objects/painel_elevador.tscn")
const TIMER_SCENE := preload("res://Objects/controle_de_tempo.tscn")

var failures: Array[String] = []
var original_save: Dictionary
var original_player: Player
var original_time: float
var original_camera_movement: bool


func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--ambient-audio-test"):
		get_tree().quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	original_save = SaveGame.save_data.duplicate(true)
	original_player = scene_manager.player
	original_time = SaveGame.tempo_atual
	original_camera_movement = bool(
		Configs.configs.get("movimento_camera", true)
	)
	SaveGame.save_data = {}

	var fire := FIRE_SCENE.instantiate()
	fire.save_enabled = false
	add_child(fire)
	await get_tree().process_frame
	var fire_audio := fire.get_node("FireAmbient") as AudioStreamPlayer2D
	_expect(fire_audio != null, "O fogo precisa ter áudio espacial na própria cena.")
	_expect(fire_audio.max_distance == 240.0, "O som do fogo precisa diminuir com a distância.")
	_expect(fire_audio.stream is AudioStreamOggVorbis, "O fogo precisa escolher uma das duas gravações configuradas.")
	if fire_audio.stream is AudioStreamOggVorbis:
		_expect((fire_audio.stream as AudioStreamOggVorbis).loop, "O som do fogo precisa tocar em loop.")

	var elevator_panel := ELEVATOR_PANEL_SCENE.instantiate()
	add_child(elevator_panel)
	await get_tree().process_frame
	elevator_panel.iniciar_movimento()
	var moving := elevator_panel.get_node("ElevatorMoving") as AudioStreamPlayer
	var arrival := elevator_panel.get_node("ElevatorArrival") as AudioStreamPlayer
	_expect(moving.playing, "O som de deslocamento precisa iniciar junto com a viagem.")
	elevator_panel.animacao()
	_expect(not moving.playing, "O som de deslocamento precisa parar na chegada.")
	_expect(arrival.playing, "O som de chegada precisa tocar quando a porta abre.")
	(elevator_panel.get_node("Abrindo") as AnimatedSprite2D).animation_finished.emit()
	await get_tree().process_frame

	var player := PLAYER_SCENE.instantiate() as Player
	player.checkpoint_enabled = false
	add_child(player)
	scene_manager.player = player
	var mission := SaveGame.office_mission_state(player)
	mission["data_center_power_outage"] = true
	mission["data_center_breaker_restored"] = false
	MusicController.heartbeat.pitch_scale = MusicController.HEARTBEAT_NORMAL_PITCH
	MusicController.call("_update_heartbeat", 1.0)
	_expect(MusicController.heartbeat.playing, "O batimento precisa tocar durante a partida.")
	_expect(MusicController.heartbeat.pitch_scale > 1.0, "O batimento precisa acelerar com o disjuntor desligado.")
	mission["data_center_breaker_restored"] = true
	MusicController.call("_update_heartbeat", 2.0)
	_expect(is_equal_approx(MusicController.heartbeat.pitch_scale, 1.0), "O batimento precisa voltar à velocidade normal após religar o disjuntor.")

	var tension_audio := MusicController.tension_ambience as AudioStreamPlayer2D
	_expect(tension_audio.stream is AudioStreamMP3, "A nova camada ambiente precisa usar o áudio configurado.")
	if tension_audio.stream is AudioStreamMP3:
		_expect((tension_audio.stream as AudioStreamMP3).loop, "A nova camada ambiente precisa tocar em loop.")
	SaveGame.tempo_atual = 120.0
	MusicController.tension_intro_elapsed = 0.0
	tension_audio.pitch_scale = MusicController.TENSION_NORMAL_PITCH
	MusicController.call("_update_tension_ambience", 1.0)
	_expect(tension_audio.playing, "A camada de tensão precisa tocar durante a partida.")
	_expect(tension_audio.pitch_scale > 1.0, "A camada de tensão precisa começar acelerada.")
	MusicController.tension_intro_elapsed = MusicController.TENSION_INTRO_DURATION
	MusicController.call("_update_tension_ambience", 2.0)
	_expect(is_equal_approx(tension_audio.pitch_scale, 1.0), "Depois da introdução, a camada de tensão precisa voltar à velocidade normal.")
	mission["data_center_power_outage"] = true
	mission["data_center_breaker_restored"] = false
	MusicController.call("_update_tension_ambience", 2.0)
	_expect(tension_audio.pitch_scale > 1.0, "A camada de tensão precisa acelerar com o disjuntor desligado.")
	mission["data_center_breaker_restored"] = true
	SaveGame.tempo_atual = 46.0
	tension_audio.pitch_scale = 1.0
	MusicController.call("_update_tension_ambience", 2.0)
	var final_start_pitch := tension_audio.pitch_scale
	SaveGame.tempo_atual = 1.0
	MusicController.call("_update_tension_ambience", 2.0)
	_expect(tension_audio.pitch_scale > final_start_pitch, "A camada de tensão precisa acelerar progressivamente entre 46 e zero segundos.")
	var audio_state := MusicController.get_checkpoint_state()
	_expect((audio_state.get("alarm_envelope", {}) as Dictionary).has("tension_intro_elapsed"), "O progresso inicial da camada ambiente precisa participar do checkpoint.")

	SaveGame.tempo_atual = 60.0
	var timer := TIMER_SCENE.instantiate()
	add_child(timer)
	timer.set_process(false)
	var camera := player.get_node("Camera2D") as Camera2D
	var camera_base_offset := camera.offset
	Configs._change_movimento_camera(false)
	timer.call("_atualizar_tremor_final", 0.1, 20.0)
	_expect(is_zero_approx(float(timer.get("intensidade_tremor_final"))), "Desativar movimento de câmera precisa impedir o tremor final.")
	_expect(camera.offset == camera_base_offset, "A opção desativada precisa manter a câmera estável.")
	Configs._change_movimento_camera(true)
	timer.call("_atualizar_tremor_final", 0.1, 46.0)
	var initial_shake := float(timer.get("intensidade_tremor_final"))
	timer.call("_atualizar_tremor_final", 0.1, 1.0)
	_expect(float(timer.get("intensidade_tremor_final")) > initial_shake, "O tremor precisa ficar mais forte conforme o cronômetro se aproxima de zero.")
	_expect(camera.offset != camera_base_offset, "Os últimos 46 segundos precisam aplicar o tremor à câmera.")
	timer.call("_resetar_tremor_final")
	_expect(camera.offset == camera_base_offset, "A câmera precisa voltar ao lugar quando o efeito termina.")

	MusicController._start_countdown()
	MusicController.call("_update_heartbeat", 2.0)
	var heartbeat_ratio := (
		db_to_linear(MusicController.heartbeat.volume_db)
		/ db_to_linear(MusicController.heartbeat_normal_volume_db)
	)
	_expect(is_equal_approx(heartbeat_ratio, 0.5), "A música ENDGAME precisa cair para 50% quando a faixa final começa.")
	MusicController._stop_countdown()
	MusicController.call("_update_heartbeat", 2.0)

	var main_menu_scene := load("res://Scenes/principal.tscn") as PackedScene
	var pause_menu_scene := load("res://Scenes/pause_menu.tscn") as PackedScene
	var main_menu := main_menu_scene.instantiate()
	var pause_menu := pause_menu_scene.instantiate()
	_expect(main_menu.get_node_or_null("Accessibility/VContainer/MovimentoCamera") is CheckBox, "O menu principal precisa exibir a opção de movimento de câmera.")
	_expect(pause_menu.get_node_or_null("Accessibility/VContainer/MovimentoCamera") is CheckBox, "O menu de pausa precisa exibir a opção de movimento de câmera.")
	main_menu.free()
	pause_menu.free()

	fire_audio.stop()
	moving.stop()
	arrival.stop()
	fire.queue_free()
	elevator_panel.queue_free()
	timer.queue_free()
	player.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	# Reproduz a troca para a cutscene: o gerenciador ainda pode conservar por
	# um frame a referência para o Player que acabou de ser liberado.
	MusicController.call("_update_heartbeat", 0.1)
	MusicController.call("_update_tension_ambience", 0.1)
	_expect(not MusicController.heartbeat.playing, "Uma referência liberada do Player não pode quebrar o áudio no tempo zero.")
	_expect(not tension_audio.playing, "A camada de tensão precisa parar fora da partida.")
	SaveGame.save_data = original_save
	SaveGame.tempo_atual = original_time
	Configs._change_movimento_camera(original_camera_movement)
	scene_manager.player = original_player
	MusicController.call("_update_heartbeat", 0.0)
	if failures.is_empty():
		print("AMBIENT_AUDIO_TEST_PASSED")
		get_tree().quit(0)
	else:
		print("AMBIENT_AUDIO_TEST_FAILED: ", failures)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
