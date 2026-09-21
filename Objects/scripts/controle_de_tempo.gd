extends Control

signal tempo_esgotado

const TEMPO_LIMITE_DE_JOGO: float = 60 * 12
const TEMPO_INICIO_AUDIO: float = 11.0
const TEMPO_INICIO_COUNT_DOWN: float = 46.0
const TEMPO_EVENTO_REFRIGERACAO: float = 120.0
const TREMOR_FINAL_MINIMO: float = 0.05
const TREMOR_FINAL_MAXIMO: float = 1.75
const TREMOR_FINAL_FREQUENCIA_MINIMA: float = 3.5
const TREMOR_FINAL_FREQUENCIA_MAXIMA: float = 12.0

@onready var audio_stream_player_2d: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var label: Label = $Label

var tempo_decorrido: float = 0.0
var ultimo_segundo_exibido: int = -1
var finalizado: bool = false
var audio_iniciado: bool = false
var count_down_audio_iniciado: bool = false
var tempo_tremor_final: float = 0.0
var intensidade_tremor_final: float = 0.0
var camera_em_tremor: Camera2D = null
var offset_original_camera: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("temporizador_jogo")
	if SaveGame.tempo_atual >= 0.0:
		carregar_tempo_restante(SaveGame.tempo_atual)
	else:
		SaveGame.tempo_atual = get_tempo_restante()
		atualizar_label()
		set_process(true)


func _process(delta: float) -> void:
	tempo_decorrido = minf(
		tempo_decorrido + delta,
		TEMPO_LIMITE_DE_JOGO
	)

	var tempo_restante_atual: float = get_tempo_restante()

	SaveGame.tempo_atual = tempo_restante_atual
	_verificar_evento_refrigeracao(tempo_restante_atual)

	var segundos_restantes := maxi(
		0,
		ceili(tempo_restante_atual)
	)
	
	if segundos_restantes <= TEMPO_INICIO_COUNT_DOWN and not count_down_audio_iniciado:
		count_down_audio_iniciado = true
		MusicController._start_countdown()

	_atualizar_tremor_final(delta, tempo_restante_atual)
		

	if segundos_restantes <= TEMPO_INICIO_AUDIO and not audio_iniciado:
		audio_iniciado = true
		audio_stream_player_2d.play()

	if segundos_restantes != ultimo_segundo_exibido:
		ultimo_segundo_exibido = segundos_restantes
		atualizar_label()
		

	if tempo_decorrido >= TEMPO_LIMITE_DE_JOGO:
		fim_de_jogo()


func get_tempo_restante() -> float:
	return maxf(
		0.0,
		TEMPO_LIMITE_DE_JOGO - tempo_decorrido
	)


func _verificar_evento_refrigeracao(tempo_restante_atual: float) -> void:
	if tempo_restante_atual > TEMPO_EVENTO_REFRIGERACAO:
		return
	var estado := SaveGame.office_mission_state()
	if bool(estado.get("cooling_opportunity_triggered", false)):
		return
	if bool(estado.get("cooling_optional_task_completed", false)):
		return
	# A redução temporária da queda de energia não pode antecipar o evento.
	if (
		bool(estado.get("data_center_power_outage", false))
		and not bool(estado.get("data_center_breaker_restored", false))
	):
		return
	estado["cooling_opportunity_triggered"] = true
	estado["cooling_opportunity_pending"] = true
	SaveGame.save_global_state("hall_quest_01", estado)


func carregar_tempo_restante(novo_tempo: float) -> void:
	var tempo_carregado := clampf(
		novo_tempo,
		0.0,
		TEMPO_LIMITE_DE_JOGO
	)

	tempo_decorrido = TEMPO_LIMITE_DE_JOGO - tempo_carregado
	ultimo_segundo_exibido = -1
	audio_iniciado = tempo_carregado <= TEMPO_INICIO_AUDIO
	count_down_audio_iniciado = (
		tempo_carregado <= TEMPO_INICIO_COUNT_DOWN
	)

	SaveGame.tempo_atual = tempo_carregado

	audio_stream_player_2d.stop()
	audio_stream_player_2d.stream_paused = false

	atualizar_label()

	# Se o tempo carregado for 0 ou menor, encerra o jogo imediatamente
	if tempo_carregado <= 0.0:
		fim_de_jogo()
		return

	finalizado = false

	if count_down_audio_iniciado:
		MusicController._start_countdown(
			maxf(
				0.0,
				TEMPO_INICIO_COUNT_DOWN - tempo_carregado
			)
		)
	else:
		MusicController._stop_countdown()
		_resetar_tremor_final()

	if audio_iniciado:
		var posicao_audio := maxf(
			0.0,
			TEMPO_INICIO_AUDIO - tempo_carregado
		)

		audio_stream_player_2d.play(posicao_audio)

	set_process(true)


func pausar_timer() -> void:
	SaveGame.tempo_atual = get_tempo_restante()

	set_process(false)
	audio_stream_player_2d.stream_paused = true
	_resetar_tremor_final()


func comecar_timer() -> void:
	if finalizado:
		return

	set_process(true)
	audio_stream_player_2d.stream_paused = false


func reiniciar_timer() -> void:
	tempo_decorrido = 0.0
	ultimo_segundo_exibido = -1
	finalizado = false
	audio_iniciado = false
	count_down_audio_iniciado = false

	SaveGame.tempo_atual = TEMPO_LIMITE_DE_JOGO

	audio_stream_player_2d.stop()
	audio_stream_player_2d.stream_paused = false
	MusicController._stop_countdown()
	_resetar_tremor_final()

	atualizar_label()
	set_process(true)


func atualizar_label() -> void:
	var tempo_restante := maxi(
		0,
		ceili(get_tempo_restante())
	)

	@warning_ignore("integer_division")
	var minutos := tempo_restante / 60
	var segundos := tempo_restante % 60

	label.text = "%02dm : %02ds" % [minutos, segundos]


func fim_de_jogo() -> void:
	if finalizado:
		return

	finalizado = true
	SaveGame.tempo_atual = 0.0
	_resetar_tremor_final()

	set_process(false)

	label.text = "00m : 00s"
	tempo_esgotado.emit()


func _on_tempo_esgotado() -> void:
	MusicController._stop_som_alarme()
	$Timer.start()
	await $Timer.timeout
	get_tree().change_scene_to_file("res://Cutscenes/cutscene_final_1.tscn")


func _on_man_player_jogador_morreu() -> void:
	hide()
	pausar_timer()
	_resetar_tremor_final()


func _atualizar_tremor_final(delta: float, tempo_restante: float) -> void:
	if not bool(Configs.configs.get("movimento_camera", true)):
		_resetar_tremor_final()
		return
	if tempo_restante > TEMPO_INICIO_COUNT_DOWN or tempo_restante <= 0.0:
		_resetar_tremor_final()
		return

	var camera := _obter_camera_do_player()
	if camera == null:
		_resetar_tremor_final()
		return

	if camera != camera_em_tremor:
		_resetar_tremor_final()
		camera_em_tremor = camera
		offset_original_camera = camera.offset

	var progresso := clampf(
		1.0 - (tempo_restante / TEMPO_INICIO_COUNT_DOWN),
		0.0,
		1.0
	)
	var progresso_suave := progresso * progresso * (3.0 - 2.0 * progresso)
	intensidade_tremor_final = lerpf(
		TREMOR_FINAL_MINIMO,
		TREMOR_FINAL_MAXIMO,
		progresso_suave
	)
	var frequencia := lerpf(
		TREMOR_FINAL_FREQUENCIA_MINIMA,
		TREMOR_FINAL_FREQUENCIA_MAXIMA,
		progresso_suave
	)
	tempo_tremor_final += delta
	camera_em_tremor.offset = offset_original_camera + Vector2(
		sin(tempo_tremor_final * frequencia),
		sin(tempo_tremor_final * frequencia * 1.37 + 1.8)
	) * intensidade_tremor_final


func _obter_camera_do_player() -> Camera2D:
	if not is_instance_valid(scene_manager.player):
		return null
	return scene_manager.player.get_node_or_null("Camera2D") as Camera2D


func _resetar_tremor_final() -> void:
	if is_instance_valid(camera_em_tremor):
		camera_em_tremor.offset = offset_original_camera
	camera_em_tremor = null
	offset_original_camera = Vector2.ZERO
	tempo_tremor_final = 0.0
	intensidade_tremor_final = 0.0


func _exit_tree() -> void:
	_resetar_tremor_final()
