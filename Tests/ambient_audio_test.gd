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
	_expect(moving.playing, "O som de deslocamento precisa iniciar junto com a viagem.")
	elevator_panel.animacao()
	_expect(not moving.playing, "O som de deslocamento precisa parar na chegada.")
	_expect(elevator_panel.get_node_or_null("ElevatorArrival") == null, "O elevador não deve mais tocar o plim de chegada.")
	(elevator_panel.get_node("Abrindo") as AnimatedSprite2D).animation_finished.emit()
	await get_tree().process_frame

	var player := PLAYER_SCENE.instantiate() as Player
	player.checkpoint_enabled = false
	add_child(player)
	scene_manager.player = player
	var mission := SaveGame.office_mission_state(player)
	var heartbeat_audio := MusicController.heartbeat as AudioStreamPlayer2D
	var background_music := MusicController.initial_background_music as AudioStreamPlayer2D
	var expected_heartbeat := load(
		"res://Sounds/Ambient/batimento_cardiaco.mp3"
	) as AudioStreamMP3
	var expected_background_music := load(
		"res://Sounds/Ambient/Musica_de_fundo_inicial.mp3"
	) as AudioStreamMP3
	_expect(
		heartbeat_audio.stream is AudioStreamMP3
		and (heartbeat_audio.stream as AudioStreamMP3).data == expected_heartbeat.data,
		"A aceleração precisa controlar o arquivo de batimento cardíaco."
	)
	_expect(
		background_music.stream is AudioStreamMP3
		and (background_music.stream as AudioStreamMP3).data == expected_background_music.data,
		"A faixa reduzida precisa ser a música de fundo inicial."
	)
	SaveGame.tempo_atual = 120.0
	MusicController.heartbeat_intro_elapsed = MusicController.HEARTBEAT_INTRO_DURATION
	player.cansaco = 0.0
	mission["data_center_power_outage"] = true
	mission["data_center_breaker_restored"] = false
	heartbeat_audio.pitch_scale = MusicController.HEARTBEAT_NORMAL_PITCH
	MusicController.call("_update_heartbeat", 1.0)
	_expect(heartbeat_audio.playing, "O batimento precisa tocar durante a partida.")
	_expect(heartbeat_audio.pitch_scale > 1.0, "O batimento precisa acelerar com o disjuntor desligado.")
	mission["data_center_breaker_restored"] = true
	MusicController.call("_update_heartbeat", 5.0)
	_expect(is_equal_approx(heartbeat_audio.pitch_scale, 1.0), "O batimento precisa voltar à velocidade normal após religar o disjuntor.")
	player.cansaco = 1.0
	MusicController.call("_update_heartbeat", 5.0)
	_expect(heartbeat_audio.pitch_scale > 1.0, "O batimento precisa acelerar quando a estamina estiver baixa.")
	_expect(is_equal_approx(heartbeat_audio.pitch_scale, 3.0), "O batimento precisa chegar a três vezes a velocidade com a estamina esgotada.")
	var middle_stamina_pitch: float = MusicController.call(
		"_heartbeat_pitch_from_stamina",
		0.5
	)
	_expect(
		middle_stamina_pitch > MusicController.HEARTBEAT_NORMAL_PITCH
		and middle_stamina_pitch < MusicController.HEARTBEAT_LOW_STAMINA_PITCH,
		"A aceleração precisa crescer gradualmente durante o consumo da estamina."
	)
	player.cansaco = 0.0
	MusicController.call("_update_heartbeat", 5.0)
	_expect(is_equal_approx(heartbeat_audio.pitch_scale, MusicController.HEARTBEAT_NORMAL_PITCH), "O batimento precisa voltar suavemente ao normal com a estamina recuperada.")

	MusicController.heartbeat_intro_elapsed = 0.0
	heartbeat_audio.pitch_scale = MusicController.HEARTBEAT_NORMAL_PITCH
	MusicController.call("_update_heartbeat", 1.0)
	_expect(heartbeat_audio.pitch_scale > 1.0, "O batimento precisa começar acelerado.")
	MusicController.heartbeat_intro_elapsed = MusicController.HEARTBEAT_INTRO_DURATION
	MusicController.call("_update_heartbeat", 5.0)
	_expect(is_equal_approx(heartbeat_audio.pitch_scale, 1.0), "Depois da introdução, o batimento precisa voltar à velocidade normal.")

	SaveGame.tempo_atual = 46.0
	heartbeat_audio.pitch_scale = 1.0
	MusicController.call("_update_heartbeat", 2.0)
	var final_start_pitch := heartbeat_audio.pitch_scale
	SaveGame.tempo_atual = 1.0
	MusicController.call("_update_heartbeat", 2.0)
	_expect(heartbeat_audio.pitch_scale > final_start_pitch, "O batimento precisa acelerar progressivamente entre 46 e zero segundos.")
	MusicController.call("_update_initial_background_music", 0.1)
	_expect(background_music.playing, "A música de fundo inicial precisa tocar durante a partida.")
	_expect(is_equal_approx(background_music.pitch_scale, 1.0), "A música de fundo inicial não pode acelerar junto com o batimento.")
	_expect(is_equal_approx(MusicController.initial_background_music_normal_volume_db, -19.0), "A música de fundo inicial precisa manter a redução de volume.")
	var audio_state := MusicController.get_checkpoint_state()
	_expect((audio_state.get("alarm_envelope", {}) as Dictionary).has("heartbeat_intro_elapsed"), "O progresso inicial do batimento precisa participar do checkpoint.")

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
	MusicController.call("_update_initial_background_music", 2.0)
	var background_music_ratio := (
		db_to_linear(background_music.volume_db)
		/ db_to_linear(MusicController.initial_background_music_normal_volume_db)
	)
	_expect(is_equal_approx(background_music_ratio, 0.5), "A música de fundo inicial precisa cair para 50% quando a faixa final começa.")
	MusicController._stop_countdown()
	MusicController.call("_update_initial_background_music", 2.0)

	MusicController.pause_all_audio()
	_expect(not heartbeat_audio.playing, "Pausar o jogo precisa pausar o batimento cardíaco.")
	_expect(not background_music.playing, "Pausar o jogo precisa pausar a música de fundo inicial.")
	MusicController.resume_all_audio()
	_expect(heartbeat_audio.playing, "Retomar o jogo precisa continuar o batimento cardíaco.")
	_expect(background_music.playing, "Retomar o jogo precisa continuar a música de fundo inicial.")

	var main_menu_scene := load("res://Scenes/principal.tscn") as PackedScene
	var pause_menu_scene := load("res://Scenes/pause_menu.tscn") as PackedScene
	var main_menu := main_menu_scene.instantiate()
	var pause_menu := pause_menu_scene.instantiate()
	_expect(main_menu.get_node_or_null("Accessibility/VContainer/MovimentoCamera") is CheckBox, "O menu principal precisa exibir a opção de movimento de câmera.")
	_expect(pause_menu.get_node_or_null("Accessibility/VContainer/MovimentoCamera") is CheckBox, "O menu de pausa precisa exibir a opção de movimento de câmera.")
	_expect(main_menu.get_node_or_null("EndingReturnFade/Black") is ColorRect, "O retorno do final precisa ter um fade de entrada próprio.")
	var ending_return_animation := main_menu.get_node_or_null("EndingReturnFade/AnimationPlayer") as AnimationPlayer
	_expect(ending_return_animation != null and ending_return_animation.has_animation(&"ending_return_fade_in"), "O fade de entrada do menu precisa estar configurado no AnimationPlayer.")
	var strong_data_center_scene := load("res://Scenes/data_center_forte.tscn") as PackedScene
	var strong_data_center := strong_data_center_scene.instantiate()
	_expect(strong_data_center.get_node_or_null("ProgrammerEnding/Audio/FinalResolution") == null, "O encerramento não pode iniciar uma segunda música.")
	var programmer_ending := strong_data_center.get_node_or_null("ProgrammerEnding")
	if programmer_ending != null:
		programmer_ending.set("dialogue_busy", true)
		programmer_ending.set("task_busy", false)
		_expect(bool(programmer_ending.get("busy")), "O estado geral precisa registrar uma conversa em andamento.")
		_expect(not bool(programmer_ending.get("task_busy")), "Uma conversa não pode bloquear o início da tarefa atual.")
		var all_steps_finished := {
			"programmer_launch_isolated": true,
			"programmer_neural_completed": true,
			"programmer_laws_completed": true,
			"programmer_recalibration_applied": true,
		}
		_expect(programmer_ending.call("_pending_exchange", all_steps_finished) == &"isolation", "Conversas acumuladas precisam começar pela tarefa mais antiga.")
		all_steps_finished["programmer_launch_exchange_seen"] = true
		_expect(programmer_ending.call("_pending_exchange", all_steps_finished) == &"neural", "A conversa da rede neural precisa manter a ordem linear.")
		all_steps_finished["programmer_neural_resistance_seen"] = true
		_expect(programmer_ending.call("_pending_exchange", all_steps_finished) == &"laws", "A conversa das Leis precisa manter a ordem linear.")
		all_steps_finished["programmer_laws_dialog_seen"] = true
		_expect(programmer_ending.call("_pending_exchange", all_steps_finished) == &"final", "A conversa final só pode começar depois das anteriores.")
	strong_data_center.free()
	main_menu.free()
	pause_menu.free()

	fire_audio.stop()
	moving.stop()
	fire.queue_free()
	elevator_panel.queue_free()
	timer.queue_free()
	player.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	# Reproduz a troca para a cutscene: o gerenciador ainda pode conservar por
	# um frame a referência para o Player que acabou de ser liberado.
	MusicController.call("_update_heartbeat", 0.1)
	MusicController.call("_update_initial_background_music", 0.1)
	_expect(not heartbeat_audio.playing, "Uma referência liberada do Player não pode quebrar o áudio no tempo zero.")
	_expect(not background_music.playing, "A música de fundo inicial precisa parar fora da partida.")
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
