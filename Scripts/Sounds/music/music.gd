extends Node2D

@onready var musica_fundo: AudioStreamPlayer = $"BG Music"
@onready var ambiente_fundo: AudioStreamPlayer = $"BG Ambient"
@onready var musica_contagem: AudioStreamPlayer = $COUNTDOWN_MUSIC
@onready var som_alarme: AudioStreamPlayer = $SOM_ALARME
@onready var som_de_fundo: AudioStreamPlayer = $SOM_DE_FUNDO
@onready var musica_quando_o_disjuntor_apagar: AudioStreamPlayer = $MUSICA_QUANDO_O_DISJUNTOR_APAGAR
@onready var batimento: AudioStreamPlayer = $HEARTBEAT
@onready var musica_cenario: AudioStreamPlayer = $INITIAL_BACKGROUND_MUSIC
@onready var musica_hack: AudioStreamPlayer = $HACKING_MUSIC

const TOCADORES_AUDIO: Dictionary = {
	"bg_music": NodePath("BG Music"),
	"bg_ambient": NodePath("BG Ambient"),
	"countdown_music": NodePath("COUNTDOWN_MUSIC"),
	"som_alarme": NodePath("SOM_ALARME"),
	"som_de_fundo": NodePath("SOM_DE_FUNDO"),
	"musica_quando_o_disjuntor_apagar": NodePath("MUSICA_QUANDO_O_DISJUNTOR_APAGAR"),
	"heartbeat": NodePath("HEARTBEAT"),

	"tension_ambience": NodePath("INITIAL_BACKGROUND_MUSIC")
}
const MUSICAS_ELEVADOR: Array[NodePath] = [
	NodePath("BG Music"),
	NodePath("COUNTDOWN_MUSIC"),
	NodePath("SOM_DE_FUNDO"),
	NodePath("MUSICA_QUANDO_O_DISJUNTOR_APAGAR"),
	NodePath("INITIAL_BACKGROUND_MUSIC"),
	NodePath("HACKING_MUSIC")
]
const MUSICA_APOS_DISJUNTOR = preload("res://Sounds/Cenario/Musica_de_cenario_3.mp3")

const VOLUME_SILENCIO_DB: float = -80.0
const DURACAO_TRANSICAO_MUSICA_ABERTURA: float = 3.0
const DURACAO_TRANSICAO_DISJUNTOR: float = 4.0
const ESPERA_INICIO_MUSICA_DISJUNTOR: float = 1.0
const DURACAO_TRANSICAO_FUNDO_DISJUNTOR: float = 1.0
const VOLUME_ALARME_DISJUNTOR: float = 0.3
const VOLUME_INICIAL_ALARME: float = 0.3
const VOLUME_REDUZIDO_ALARME: float = 0.1
const DURACAO_INICIAL_ALARME: float = 30.0
const DURACAO_TRANSICAO_ALARME: float = 4.0
const ESPERA_AVISO_ALARME: float = 120.0
const VOLUME_CONTEXTO_ALARME_BAIXO: float = 0.05
const TOM_NORMAL_BATIMENTO: float = 1.0
const TOM_BATIMENTO_CANSADO: float = 3.0
const TOM_BATIMENTO_DISJUNTOR: float = 1.45
const VELOCIDADE_TRANSICAO_TOM_BATIMENTO: float = 0.55
const INICIO_RESPOSTA_BATIMENTO_CANSACO: float = 0.2
const FIM_RESPOSTA_BATIMENTO_CANSACO: float = 0.85
const FATOR_VOLUME_MUSICA_CENARIO_FINAL: float = 0.5
const VELOCIDADE_TRANSICAO_VOLUME_CENARIO: float = 4.0
const VOLUME_ALVO_MUSICA_HACK_DB: float = -6.0
const DURACAO_TRANSICAO_MUSICA_HACK: float = 1.5
const FATOR_MUSICA_FUNDO_HACK: float = 0.28
const FATOR_MUSICA_DIALOGO_NPC: float = 0.5
const DURACAO_TRANSICAO_MUSICA_DIALOGO: float = 0.4
const DURACAO_BATIMENTO_INICIAL: float = 20.0
const TOM_BATIMENTO_INICIAL: float = 1.25
const TOM_INICIAL_BATIMENTO_FINAL: float = 1.2
const TOM_MAXIMO_BATIMENTO_FINAL: float = 1.65
const DURACAO_BATIMENTO_FINAL: float = 46.0
const VOLUME_FUNDO_FINAL_PROGRAMADOR_DB: float = -34.0
const VOLUME_CONTAGEM_FINAL_PROGRAMADOR_DB: float = -18.0

enum EstadoAudioDisjuntor {
	INATIVO,
	AUMENTANDO,
	ATIVO,
	DIMINUINDO
}

var audio_cena_bloqueado: bool = false
var inicios_pendentes: Dictionary = {}
var posicoes_audio_pausado: Dictionary = {}
var posicao_hack_pausada: float = -1.0
var mistura_hack: float = 0.0
var fator_fundo_hack_aplicado: float = 1.0
var fator_musica_dialogo: float = 1.0
var fator_dialogo_aplicado: float = 1.0
var volume_base_dialogo_db: float = 0.0
var fator_musica_tutorial: float = 1.0
var volume_normal_alarme_db: float = 0.0
var tempo_alarme: float = 0.0
var volume_alarme_sem_atenuacao_db: float = 0.0
var alarme_silenciado_jogador: bool = false
var posicao_alarme_jogador: float = 0.0
var tempo_aviso_alarme: float = 0.0
var aviso_alarme_exibido: bool = false
var contextos_alarme_baixo: Dictionary = {}
var volume_normal_musica_inicio_db: float = 0.0
var musica_inicio_iniciada: bool = false
var musica_inicio_finalizada: bool = false
var volume_normal_musica_disjuntor_db: float = 0.0
var estado_audio_disjuntor: EstadoAudioDisjuntor = EstadoAudioDisjuntor.INATIVO
var tempo_transicao_disjuntor: float = 0.0
var espera_musica_disjuntor: float = 0.0
var tempo_transicao_musica_disjuntor: float = 0.0
var volume_inicial_alarme_disjuntor_db: float = VOLUME_SILENCIO_DB
var volume_alvo_alarme_disjuntor_db: float = VOLUME_SILENCIO_DB
var volume_inicial_musica_disjuntor_db: float = VOLUME_SILENCIO_DB
var volume_alvo_musica_disjuntor_db: float = VOLUME_SILENCIO_DB
var volume_normal_musica_cenario_db: float = 0.0
var volume_alvo_musica_cenario_db: float = 0.0
var musica_cenario_retornando: bool = false
var faixa_inicial_cenario: AudioStream
var musica_cenario_apos_disjuntor: bool = false
var tempo_batimento_inicial: float = 0.0
var transicao_audio_menu: Tween
var volumes_retorno_menu: Dictionary = {}
var audio_elevador_ativo: bool = false
var modos_musica_elevador: Dictionary = {}


func _ready() -> void:

	faixa_inicial_cenario = musica_cenario.stream
	_tocar_se_parado(ambiente_fundo)
	_tocar_se_parado(musica_fundo)
	volume_normal_alarme_db = som_alarme.volume_db
	volume_alarme_sem_atenuacao_db = som_alarme.volume_db
	volume_normal_musica_inicio_db = som_de_fundo.volume_db
	volume_normal_musica_disjuntor_db = musica_quando_o_disjuntor_apagar.volume_db
	volume_normal_musica_cenario_db = musica_cenario.volume_db
	volume_alvo_musica_cenario_db = volume_normal_musica_cenario_db
	batimento.pitch_scale = TOM_NORMAL_BATIMENTO
	musica_cenario.pitch_scale = 1.0


func _process(delta: float) -> void:
	if audio_cena_bloqueado or get_tree().paused:
		return
	_atualizar_transicao_musica_abertura()
	_atualizar_volume_alarme(delta)
	_atualizar_aviso_alarme(delta)
	_atualizar_audio_disjuntor(delta)
	_atualizar_batimento(delta)
	_atualizar_musica_cenario(delta)
	_atualizar_musica_hack(delta)
	_atualizar_musica_dialogo(delta)


func _atualizar_musica_dialogo(delta: float) -> void:
	var canal_musica := AudioServer.get_bus_index(&"Music")
	if canal_musica < 0:
		return

	var volume_atual_db := AudioServer.get_bus_volume_db(canal_musica)
	if fator_dialogo_aplicado < 1.0:
		var volume_esperado_db := volume_base_dialogo_db + linear_to_db(fator_dialogo_aplicado)
		if is_equal_approx(volume_atual_db, volume_esperado_db):
			volume_atual_db = volume_base_dialogo_db
		fator_dialogo_aplicado = 1.0
	var fator_alvo := FATOR_MUSICA_DIALOGO_NPC if DialogManager.is_showing_dialog else 1.0
	fator_musica_dialogo = move_toward(
		fator_musica_dialogo,
		fator_alvo,
		delta / DURACAO_TRANSICAO_MUSICA_DIALOGO
	)
	volume_base_dialogo_db = volume_atual_db
	var fator_combinado := fator_musica_dialogo * fator_musica_tutorial
	AudioServer.set_bus_volume_db(canal_musica, volume_atual_db + linear_to_db(fator_combinado))
	fator_dialogo_aplicado = fator_combinado


func definir_fator_musica_tutorial(fator: float) -> void:
	fator_musica_tutorial = clampf(fator, 0.01, 1.0)
	_atualizar_musica_dialogo(0.0)
	_atualizar_saida_alarme()


func _atualizar_musica_hack(delta: float) -> void:
	var mistura_alvo := 1.0 if _cena_de_hack() else 0.0
	mistura_hack = move_toward(
		mistura_hack,
		mistura_alvo,
		delta / DURACAO_TRANSICAO_MUSICA_HACK
	)
	if mistura_alvo > 0.0 and not musica_hack.playing:
		musica_hack.play()
	var amplitude_musica := db_to_linear(VOLUME_ALVO_MUSICA_HACK_DB) * mistura_hack
	if amplitude_musica > db_to_linear(VOLUME_SILENCIO_DB):
		musica_hack.volume_db = linear_to_db(amplitude_musica)
	else:
		musica_hack.volume_db = VOLUME_SILENCIO_DB
		if musica_hack.playing:
			musica_hack.stop()

	var fator_fundo := lerpf(1.0, FATOR_MUSICA_FUNDO_HACK, mistura_hack)
	var amplitude_fundo := db_to_linear(musica_cenario.volume_db) * fator_fundo
	fator_fundo_hack_aplicado = fator_fundo
	musica_cenario.volume_db = linear_to_db(maxf(
		amplitude_fundo,
		db_to_linear(VOLUME_SILENCIO_DB)
	))


func _cena_de_hack() -> bool:
	var cena_atual := get_tree().current_scene
	if not is_instance_valid(cena_atual):
		return false
	var caminho_cena := cena_atual.scene_file_path
	return (
		caminho_cena.begins_with("res://Minigames/Minigame1/levels/")
		or caminho_cena.begins_with("res://Minigames/Minigame3/levels/")
	)


func _atualizar_batimento(delta: float) -> void:

	if not is_instance_valid(scene_manager.player):
		if batimento.playing:
			batimento.stop()
		batimento.pitch_scale = TOM_NORMAL_BATIMENTO
		return

	var jogador_atual: Player = scene_manager.player
	_tocar_se_parado(batimento)
	var missao := SaveGame.office_mission_state(jogador_atual)
	var energia_desligada := (
		bool(missao.get("data_center_power_outage", false))
		and not bool(missao.get("data_center_breaker_restored", false))
	)
	var tom_alvo := _tom_batimento_por_cansaco(jogador_atual.cansaco)
	if tempo_batimento_inicial < DURACAO_BATIMENTO_INICIAL:
		tempo_batimento_inicial = minf(
			tempo_batimento_inicial + delta,
			DURACAO_BATIMENTO_INICIAL
		)
		tom_alvo = maxf(tom_alvo, TOM_BATIMENTO_INICIAL)
	if energia_desligada:
		tom_alvo = maxf(tom_alvo, TOM_BATIMENTO_DISJUNTOR)
	var tempo_restante := SaveGame.tempo_atual
	if tempo_restante > 0.0 and tempo_restante <= DURACAO_BATIMENTO_FINAL:
		var progresso_final := clampf(
			1.0 - (tempo_restante / DURACAO_BATIMENTO_FINAL),
			0.0,
			1.0
		)
		var progresso_final_suave := (
			progresso_final * progresso_final
			* (3.0 - 2.0 * progresso_final)
		)
		tom_alvo = maxf(
			tom_alvo,
			lerpf(
				TOM_INICIAL_BATIMENTO_FINAL,
				TOM_MAXIMO_BATIMENTO_FINAL,
				progresso_final_suave
			)
		)
	batimento.pitch_scale = move_toward(
		batimento.pitch_scale,
		tom_alvo,
		VELOCIDADE_TRANSICAO_TOM_BATIMENTO * delta
	)


func _tom_batimento_por_cansaco(cansaco: float) -> float:

	var progresso := clampf(
		(cansaco - INICIO_RESPOSTA_BATIMENTO_CANSACO)
		/ (FIM_RESPOSTA_BATIMENTO_CANSACO - INICIO_RESPOSTA_BATIMENTO_CANSACO),
		0.0,
		1.0
	)
	var progresso_suave := progresso * progresso * (3.0 - 2.0 * progresso)
	return lerpf(
		TOM_NORMAL_BATIMENTO,
		TOM_BATIMENTO_CANSADO,
		progresso_suave
	)


func _atualizar_musica_cenario(delta: float) -> void:

	if fator_fundo_hack_aplicado < 1.0:
		musica_cenario.volume_db = linear_to_db(
			db_to_linear(musica_cenario.volume_db)
			/ fator_fundo_hack_aplicado
		)
		fator_fundo_hack_aplicado = 1.0
	if not is_instance_valid(scene_manager.player):
		if musica_cenario.playing:
			musica_cenario.stop()
		musica_cenario.pitch_scale = 1.0
		if estado_audio_disjuntor != EstadoAudioDisjuntor.INATIVO:

			musica_cenario.volume_db = VOLUME_SILENCIO_DB
		else:
			musica_cenario.volume_db = volume_normal_musica_cenario_db
			volume_alvo_musica_cenario_db = volume_normal_musica_cenario_db
			musica_cenario_retornando = false
		return

	_tocar_se_parado(musica_cenario)
	musica_cenario.pitch_scale = 1.0
	var disjuntor_desarmado := (
		estado_audio_disjuntor != EstadoAudioDisjuntor.INATIVO
		and not (
			estado_audio_disjuntor == EstadoAudioDisjuntor.DIMINUINDO
			and musica_cenario_apos_disjuntor
		)
	)
	var volume_alvo_db := (
		VOLUME_SILENCIO_DB if disjuntor_desarmado else volume_alvo_musica_cenario_db
	)
	if disjuntor_desarmado or musica_cenario_retornando:

		var duracao_transicao := (
			DURACAO_TRANSICAO_DISJUNTOR
			if estado_audio_disjuntor == EstadoAudioDisjuntor.DIMINUINDO
			and musica_cenario_apos_disjuntor
			else DURACAO_TRANSICAO_FUNDO_DISJUNTOR
		)
		var passo_transicao := (
			db_to_linear(volume_normal_musica_cenario_db)
			* delta / duracao_transicao
		)
		var proxima_amplitude := move_toward(
			db_to_linear(musica_cenario.volume_db),
			db_to_linear(volume_alvo_db),
			passo_transicao
		)
		musica_cenario.volume_db = linear_to_db(maxf(
			proxima_amplitude,
			db_to_linear(VOLUME_SILENCIO_DB)
		))
	else:
		musica_cenario.volume_db = move_toward(
			musica_cenario.volume_db,
			volume_alvo_db,
			VELOCIDADE_TRANSICAO_VOLUME_CENARIO * delta
		)
	if musica_cenario_retornando and is_equal_approx(
		musica_cenario.volume_db, volume_alvo_db
	):
		musica_cenario_retornando = false


func _definir_faixa_cenario(apos_disjuntor: bool) -> void:
	if musica_cenario_apos_disjuntor == apos_disjuntor:
		return
	musica_cenario.stop()
	var nova_faixa: AudioStream = (
		MUSICA_APOS_DISJUNTOR
		if apos_disjuntor else faixa_inicial_cenario
	)
	musica_cenario.stream = nova_faixa
	musica_cenario.volume_db = (
		VOLUME_SILENCIO_DB
		if apos_disjuntor else volume_normal_musica_cenario_db
	)
	musica_cenario_apos_disjuntor = apos_disjuntor


func _atualizar_volume_alarme(delta: float) -> void:
	if not som_alarme.playing or som_alarme.stream_paused:
		return
	tempo_alarme = minf(tempo_alarme + delta, DURACAO_INICIAL_ALARME + DURACAO_TRANSICAO_ALARME)
	if estado_audio_disjuntor != EstadoAudioDisjuntor.INATIVO:
		return
	var progresso := clampf((tempo_alarme - DURACAO_INICIAL_ALARME) / DURACAO_TRANSICAO_ALARME, 0.0, 1.0)
	_aplicar_volume_alarme(linear_to_db(
		db_to_linear(volume_normal_alarme_db)
		* lerpf(VOLUME_INICIAL_ALARME, VOLUME_REDUZIDO_ALARME, progresso)
	))


func _atualizar_aviso_alarme(delta: float) -> void:
	if aviso_alarme_exibido or alarme_silenciado_jogador or not som_alarme.playing or som_alarme.stream_paused:
		return
	tempo_aviso_alarme = minf(tempo_aviso_alarme + delta, ESPERA_AVISO_ALARME)
	if tempo_aviso_alarme < ESPERA_AVISO_ALARME or not is_instance_valid(scene_manager.player):
		return
	var jogador_atual := scene_manager.player as Player
	var cena_atual := get_tree().current_scene
	if cena_atual == null or not cena_atual.is_ancestor_of(jogador_atual):
		return
	if not jogador_atual.is_visible_in_tree() or not jogador_atual.is_physics_processing() or DialogManager.is_showing_dialog:
		return
	jogador_atual.show_alarm_hint()
	aviso_alarme_exibido = true


func _iniciar_musica_fundo(posicao_inicial: float = 0.0) -> void:
	_tocar_se_parado(musica_fundo, posicao_inicial)

func _parar_musica_fundo() -> void:
	musica_fundo.stop()


func _iniciar_ambiente_fundo(posicao_inicial: float = 0.0) -> void:
	_tocar_se_parado(ambiente_fundo, posicao_inicial)

func _parar_ambiente_fundo() -> void:
	ambiente_fundo.stop()


func _iniciar_musica_contagem(posicao_inicial: float = 0.0) -> void:
	volume_alvo_musica_cenario_db = linear_to_db(
		db_to_linear(volume_normal_musica_cenario_db)
		* FATOR_VOLUME_MUSICA_CENARIO_FINAL
	)
	_tocar_se_parado(musica_contagem, posicao_inicial)

func _parar_musica_contagem() -> void:
	musica_contagem.stop()
	volume_alvo_musica_cenario_db = volume_normal_musica_cenario_db


func iniciar_mixagem_final_programador() -> void:

	volume_alvo_musica_cenario_db = VOLUME_FUNDO_FINAL_PROGRAMADOR_DB
	musica_contagem.volume_db = VOLUME_CONTAGEM_FINAL_PROGRAMADOR_DB
	definir_contexto_alarme_baixo(&"programmer_ending", true)


func iniciar_mixagem_final_engenheiro() -> void:
	volume_alvo_musica_cenario_db = VOLUME_FUNDO_FINAL_PROGRAMADOR_DB
	musica_contagem.volume_db = VOLUME_CONTAGEM_FINAL_PROGRAMADOR_DB
	definir_contexto_alarme_baixo(&"engineer_ending", true)


func _iniciar_alarme(posicao_inicial: float = 0.0) -> void:
	if alarme_silenciado_jogador:
		return
	_tocar_se_parado(som_alarme, posicao_inicial)
	_atualizar_volume_alarme(0.0)

func _parar_alarme() -> void:
	if estado_audio_disjuntor != EstadoAudioDisjuntor.INATIVO:
		return
	som_alarme.stop()
	volume_alarme_sem_atenuacao_db = volume_normal_alarme_db
	_atualizar_saida_alarme()


func _iniciar_musica_abertura(posicao_inicial: float = 0.0) -> void:
	if musica_inicio_finalizada:
		return
	if not som_de_fundo.playing:
		som_de_fundo.volume_db = volume_normal_musica_inicio_db
		musica_inicio_iniciada = true
	_tocar_se_parado(som_de_fundo, posicao_inicial)

func _parar_musica_abertura() -> void:
	som_de_fundo.stop()
	

func _definir_volume_musica_abertura(volume: float) -> void:
	volume_normal_musica_inicio_db = linear_to_db(volume)
	if not musica_inicio_finalizada:
		som_de_fundo.volume_db = volume_normal_musica_inicio_db


func _definir_volume_alarme(volume: float) -> void:
	volume_normal_alarme_db = linear_to_db(volume)
	if estado_audio_disjuntor == EstadoAudioDisjuntor.INATIVO:
		_atualizar_volume_alarme(0.0)


func _definir_volume_contagem(volume: float) -> void:
	musica_contagem.volume_db = linear_to_db(volume)


func _iniciar_audio_disjuntor() -> void:
	if estado_audio_disjuntor == EstadoAudioDisjuntor.ATIVO or estado_audio_disjuntor == EstadoAudioDisjuntor.AUMENTANDO:
		return
	var retomando_transicao_saida := estado_audio_disjuntor == EstadoAudioDisjuntor.DIMINUINDO
	if not retomando_transicao_saida:
		musica_quando_o_disjuntor_apagar.stop()
		musica_quando_o_disjuntor_apagar.volume_db = VOLUME_SILENCIO_DB
	if not alarme_silenciado_jogador and not som_alarme.playing:
		som_alarme.volume_db = VOLUME_SILENCIO_DB
		volume_alarme_sem_atenuacao_db = VOLUME_SILENCIO_DB
		_tocar_se_parado(som_alarme)
	if retomando_transicao_saida and not musica_quando_o_disjuntor_apagar.playing:
		_tocar_se_parado(musica_quando_o_disjuntor_apagar)
	_iniciar_transicao_disjuntor(
		EstadoAudioDisjuntor.AUMENTANDO,
		linear_to_db(db_to_linear(volume_normal_alarme_db) * VOLUME_ALARME_DISJUNTOR),
		volume_normal_musica_disjuntor_db
	)
	espera_musica_disjuntor = (
		0.0 if retomando_transicao_saida else ESPERA_INICIO_MUSICA_DISJUNTOR
	)
	tempo_transicao_musica_disjuntor = 0.0


func _parar_audio_disjuntor() -> void:
	if bool(SaveGame.office_mission_state().get("data_center_breaker_restored", false)):
		_definir_faixa_cenario(true)
		musica_cenario_retornando = true
	if estado_audio_disjuntor == EstadoAudioDisjuntor.DIMINUINDO:
		return
	if estado_audio_disjuntor == EstadoAudioDisjuntor.INATIVO and not musica_quando_o_disjuntor_apagar.playing:
		return

	tempo_alarme = DURACAO_INICIAL_ALARME + DURACAO_TRANSICAO_ALARME
	espera_musica_disjuntor = 0.0
	_iniciar_transicao_disjuntor(
		EstadoAudioDisjuntor.DIMINUINDO,
		linear_to_db(db_to_linear(volume_normal_alarme_db) * VOLUME_REDUZIDO_ALARME),
		VOLUME_SILENCIO_DB
	)


func _atualizar_transicao_musica_abertura() -> void:
	if musica_inicio_finalizada or not musica_inicio_iniciada:
		return
	if not som_de_fundo.playing:
		musica_inicio_finalizada = true
		return
	if som_de_fundo.stream == null:
		return
	var duracao := som_de_fundo.stream.get_length()
	if duracao <= 0.0:
		return
	var inicio_transicao := maxf(0.0, duracao - DURACAO_TRANSICAO_MUSICA_ABERTURA)
	var progresso := clampf(
		(som_de_fundo.get_playback_position() - inicio_transicao) / DURACAO_TRANSICAO_MUSICA_ABERTURA,
		0.0,
		1.0
	)
	if progresso > 0.0:
		som_de_fundo.volume_db = lerpf(
			volume_normal_musica_inicio_db,
			VOLUME_SILENCIO_DB,
			progresso
		)


func _iniciar_transicao_disjuntor(
	novo_estado: EstadoAudioDisjuntor,
	volume_alvo_alarme_db: float,
	volume_alvo_musica_db: float
) -> void:
	estado_audio_disjuntor = novo_estado
	tempo_transicao_disjuntor = 0.0

	volume_inicial_alarme_disjuntor_db = volume_alarme_sem_atenuacao_db
	volume_alvo_alarme_disjuntor_db = volume_alvo_alarme_db
	volume_inicial_musica_disjuntor_db = musica_quando_o_disjuntor_apagar.volume_db
	volume_alvo_musica_disjuntor_db = volume_alvo_musica_db


func _atualizar_audio_disjuntor(delta: float) -> void:
	if estado_audio_disjuntor == EstadoAudioDisjuntor.INATIVO:
		return
	tempo_transicao_disjuntor += delta
	var progresso := clampf(tempo_transicao_disjuntor / DURACAO_TRANSICAO_DISJUNTOR, 0.0, 1.0)
	var progresso_suave := progresso * progresso * (3.0 - 2.0 * progresso)
	_aplicar_volume_alarme(linear_to_db(maxf(lerpf(
		db_to_linear(volume_inicial_alarme_disjuntor_db),
		db_to_linear(volume_alvo_alarme_disjuntor_db),
		progresso_suave
	), db_to_linear(VOLUME_SILENCIO_DB))))
	var progresso_musica := progresso
	if estado_audio_disjuntor == EstadoAudioDisjuntor.AUMENTANDO:
		var delta_musica := delta
		if espera_musica_disjuntor > 0.0:
			delta_musica = maxf(0.0, delta - espera_musica_disjuntor)
			espera_musica_disjuntor = maxf(
				0.0,
				espera_musica_disjuntor - delta
			)
			if espera_musica_disjuntor == 0.0:
				_tocar_se_parado(musica_quando_o_disjuntor_apagar)
		if espera_musica_disjuntor > 0.0:
			return
		tempo_transicao_musica_disjuntor += delta_musica
		progresso_musica = clampf(
			tempo_transicao_musica_disjuntor / DURACAO_TRANSICAO_DISJUNTOR,
			0.0,
			1.0
		)
	musica_quando_o_disjuntor_apagar.volume_db = linear_to_db(lerpf(
		db_to_linear(volume_inicial_musica_disjuntor_db),
		db_to_linear(volume_alvo_musica_disjuntor_db),
		progresso_musica
	))
	if progresso < 1.0 or progresso_musica < 1.0:
		return
	if estado_audio_disjuntor == EstadoAudioDisjuntor.DIMINUINDO:
		musica_quando_o_disjuntor_apagar.stop()
		musica_quando_o_disjuntor_apagar.volume_db = volume_normal_musica_disjuntor_db
		estado_audio_disjuntor = EstadoAudioDisjuntor.INATIVO
		musica_cenario_retornando = true
		return
	estado_audio_disjuntor = EstadoAudioDisjuntor.ATIVO


func parar_todos_audios() -> void:
	audio_cena_bloqueado = false
	inicios_pendentes.clear()
	posicoes_audio_pausado.clear()
	posicao_hack_pausada = -1.0
	mistura_hack = 0.0
	fator_fundo_hack_aplicado = 1.0
	musica_inicio_iniciada = false
	musica_inicio_finalizada = false
	estado_audio_disjuntor = EstadoAudioDisjuntor.INATIVO
	tempo_transicao_disjuntor = 0.0
	espera_musica_disjuntor = 0.0
	tempo_transicao_musica_disjuntor = 0.0
	musica_cenario_retornando = false
	tempo_alarme = 0.0
	alarme_silenciado_jogador = false
	posicao_alarme_jogador = 0.0
	tempo_aviso_alarme = 0.0
	aviso_alarme_exibido = false
	contextos_alarme_baixo.clear()
	tempo_batimento_inicial = 0.0
	batimento.pitch_scale = TOM_NORMAL_BATIMENTO
	musica_cenario.pitch_scale = 1.0
	volume_alvo_musica_cenario_db = volume_normal_musica_cenario_db

	for id_tocador: String in TOCADORES_AUDIO:
		var tocador := _obter_tocador(id_tocador)

		if tocador == null:
			continue

		tocador.stop()
		tocador.stream_paused = false
	musica_hack.stop()
	musica_hack.volume_db = VOLUME_SILENCIO_DB
	_definir_faixa_cenario(false)
	musica_cenario.volume_db = volume_normal_musica_cenario_db


func pausar_todos_audios() -> void:
	if audio_cena_bloqueado and not posicoes_audio_pausado.is_empty():
		return

	audio_cena_bloqueado = true
	posicoes_audio_pausado.clear()

	for id_tocador: String in TOCADORES_AUDIO:
		var tocador := _obter_tocador(id_tocador)

		if tocador != null and tocador.playing:
			posicoes_audio_pausado[id_tocador] = maxf(
				0.0,
				tocador.get_playback_position()
			)
			tocador.stop()
	if musica_hack.playing:
		posicao_hack_pausada = maxf(0.0, musica_hack.get_playback_position())
		musica_hack.stop()


func reduzir_audio_para_menu(duracao: float) -> void:
	if transicao_audio_menu != null and transicao_audio_menu.is_valid():
		transicao_audio_menu.kill()
	volumes_retorno_menu.clear()
	audio_cena_bloqueado = true
	volume_alvo_musica_cenario_db = VOLUME_SILENCIO_DB
	estado_audio_disjuntor = EstadoAudioDisjuntor.INATIVO
	espera_musica_disjuntor = 0.0
	tempo_transicao_musica_disjuntor = 0.0
	musica_cenario_retornando = false
	transicao_audio_menu = create_tween()
	transicao_audio_menu.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var tocadores: Array[AudioStreamPlayer] = [
		musica_fundo,
		ambiente_fundo,
		musica_contagem,
		som_alarme,
		som_de_fundo,
		musica_quando_o_disjuntor_apagar,
		batimento,
		musica_cenario,
		musica_hack
	]
	for tocador: AudioStreamPlayer in tocadores:
		if not tocador.playing:
			continue
		volumes_retorno_menu[tocador] = tocador.volume_db
		transicao_audio_menu.parallel().tween_property(
			tocador,
			"volume_db",
			VOLUME_SILENCIO_DB,
			maxf(duracao, 0.01)
		)
	transicao_audio_menu.chain().tween_callback(_finalizar_transicao_audio_menu)


func _finalizar_transicao_audio_menu() -> void:
	for tocador: Variant in volumes_retorno_menu:
		if not is_instance_valid(tocador):
			continue
		tocador.stop()
		tocador.volume_db = float(volumes_retorno_menu[tocador])
	volumes_retorno_menu.clear()
	posicao_hack_pausada = -1.0
	mistura_hack = 0.0
	fator_fundo_hack_aplicado = 1.0
	volume_alvo_musica_cenario_db = volume_normal_musica_cenario_db
	audio_cena_bloqueado = false


func retomar_todos_audios() -> void:
	audio_cena_bloqueado = false
	inicios_pendentes.clear()

	for id_tocador: String in posicoes_audio_pausado:
		var tocador := _obter_tocador(id_tocador)

		if tocador != null and tocador.stream != null:
			var posicao_reproducao := maxf(
				0.0,
				float(posicoes_audio_pausado[id_tocador])
			)
			var duracao_faixa := tocador.stream.get_length()
			if duracao_faixa > 0.0:
				posicao_reproducao = fmod(posicao_reproducao, duracao_faixa)
			tocador.play(posicao_reproducao)

	posicoes_audio_pausado.clear()
	if posicao_hack_pausada >= 0.0 and _cena_de_hack() and musica_hack.stream != null:
		musica_hack.play(posicao_hack_pausada)
	posicao_hack_pausada = -1.0


func iniciar_restauracao_checkpoint() -> void:
	inicios_pendentes.clear()
	pausar_todos_audios()


func permitir_audio_cena() -> void:
	retomar_todos_audios()


func get_checkpoint_state() -> Dictionary:
	var estado: Dictionary = {}
	estado["alarm_envelope"] = {
		"elapsed": tempo_alarme,
		"unducked_volume_db": volume_alarme_sem_atenuacao_db,
		"user_muted": alarme_silenciado_jogador,
		"user_position": posicao_alarme_jogador,
		"hint_elapsed": tempo_aviso_alarme,
		"hint_shown": aviso_alarme_exibido,
		"power_state": estado_audio_disjuntor,
		"fade_elapsed": tempo_transicao_disjuntor,
		"music_delay_remaining": espera_musica_disjuntor,
		"music_fade_elapsed": tempo_transicao_musica_disjuntor,
		"background_restoring": musica_cenario_retornando,
		"background_track_after_breaker": musica_cenario_apos_disjuntor,
		"alarm_start": volume_inicial_alarme_disjuntor_db,
		"alarm_target": volume_alvo_alarme_disjuntor_db,
		"music_start": volume_inicial_musica_disjuntor_db,
		"music_target": volume_alvo_musica_disjuntor_db,
		"heartbeat_intro_elapsed": tempo_batimento_inicial
	}

	for id_tocador: String in TOCADORES_AUDIO:
		var tocador := _obter_tocador(id_tocador)

		if tocador == null:
			continue

		estado[id_tocador] = {
			"playing": tocador.playing,
			"position": (
				tocador.get_playback_position()
				if tocador.playing
				else 0.0
			),
			"volume_db": tocador.volume_db
		}

	return estado


func load_checkpoint_state(estado: Dictionary) -> void:
	var disjuntor_religado := bool(
		SaveGame.office_mission_state().get("data_center_breaker_restored", false)
	)
	var estado_alarme_salvo: Dictionary = estado.get("alarm_envelope", {})
	var save_com_faixa_antiga := (
		disjuntor_religado and not estado_alarme_salvo.has("background_track_after_breaker")
	)
	_definir_faixa_cenario(disjuntor_religado)

	if estado.is_empty():
		audio_cena_bloqueado = false
		inicios_pendentes.clear()
		musica_cenario_retornando = disjuntor_religado
		return

	var recuperar_save_silencioso := (
		_checkpoint_sem_audio(estado)
		and not inicios_pendentes.is_empty()
	)

	for id_tocador: String in TOCADORES_AUDIO:
		if not estado.has(id_tocador):
			continue

		var tocador := _obter_tocador(id_tocador)
		var valor_salvo: Variant = estado[id_tocador]

		if tocador == null or not valor_salvo is Dictionary:
			continue

		var tocador_salvo: Dictionary = valor_salvo
		var deve_tocar := bool(tocador_salvo.get("playing", false))
		var posicao_reproducao := maxf(
			0.0,
			float(tocador_salvo.get("position", 0.0))
		)
		if recuperar_save_silencioso and inicios_pendentes.has(id_tocador):
			deve_tocar = true
			posicao_reproducao = maxf(
				0.0,
				float(inicios_pendentes[id_tocador])
			)

		if id_tocador == "som_alarme" and inicios_pendentes.has(id_tocador) and not bool(estado_alarme_salvo.get("user_muted", false)):
			deve_tocar = true
		if id_tocador == "tension_ambience" and save_com_faixa_antiga:
			posicao_reproducao = 0.0

		tocador.volume_db = float(
			tocador_salvo.get("volume_db", tocador.volume_db)
		)

		if not deve_tocar:
			if tocador.playing:
				tocador.stop()

			tocador.stream_paused = false
			continue

		if tocador.stream == null:
			continue

		var duracao_faixa := tocador.stream.get_length()

		if duracao_faixa > 0.0:
			posicao_reproducao = fmod(posicao_reproducao, duracao_faixa)

		if tocador.playing:

			tocador.stream_paused = true
			tocador.seek(posicao_reproducao)
		else:
			tocador.play(posicao_reproducao)

		tocador.stream_paused = false

	audio_cena_bloqueado = false
	inicios_pendentes.clear()
	posicoes_audio_pausado.clear()
	_restaurar_estado_alarme(estado)
	if disjuntor_religado and estado_audio_disjuntor in [
		EstadoAudioDisjuntor.AUMENTANDO,
		EstadoAudioDisjuntor.ATIVO
	]:
		_parar_audio_disjuntor()
	volume_alvo_musica_cenario_db = (
		linear_to_db(
			db_to_linear(volume_normal_musica_cenario_db)
			* FATOR_VOLUME_MUSICA_CENARIO_FINAL
		)
		if musica_contagem.playing
		else volume_normal_musica_cenario_db
	)


func _restaurar_estado_alarme(estado: Dictionary) -> void:
	var estado_alarme: Dictionary = estado.get("alarm_envelope", {})

	tempo_alarme = float(estado_alarme.get("elapsed", DURACAO_INICIAL_ALARME + DURACAO_TRANSICAO_ALARME))
	volume_alarme_sem_atenuacao_db = float(estado_alarme.get("unducked_volume_db", som_alarme.volume_db))
	alarme_silenciado_jogador = bool(estado_alarme.get("user_muted", false))
	posicao_alarme_jogador = maxf(0.0, float(estado_alarme.get("user_position", 0.0)))
	tempo_aviso_alarme = clampf(float(estado_alarme.get("hint_elapsed", 0.0)), 0.0, ESPERA_AVISO_ALARME)
	aviso_alarme_exibido = bool(estado_alarme.get("hint_shown", alarme_silenciado_jogador))
	contextos_alarme_baixo.clear()
	estado_audio_disjuntor = int(estado_alarme.get("power_state", EstadoAudioDisjuntor.INATIVO)) as EstadoAudioDisjuntor
	tempo_transicao_disjuntor = float(estado_alarme.get("fade_elapsed", 0.0))
	espera_musica_disjuntor = float(estado_alarme.get("music_delay_remaining", 0.0))
	tempo_transicao_musica_disjuntor = float(estado_alarme.get("music_fade_elapsed", tempo_transicao_disjuntor))
	musica_cenario_retornando = bool(estado_alarme.get("background_restoring", false))
	volume_inicial_alarme_disjuntor_db = float(estado_alarme.get("alarm_start", som_alarme.volume_db))
	volume_alvo_alarme_disjuntor_db = float(estado_alarme.get("alarm_target", som_alarme.volume_db))
	volume_inicial_musica_disjuntor_db = float(estado_alarme.get("music_start", musica_quando_o_disjuntor_apagar.volume_db))
	volume_alvo_musica_disjuntor_db = float(estado_alarme.get("music_target", musica_quando_o_disjuntor_apagar.volume_db))
	tempo_batimento_inicial = clampf(
		float(estado_alarme.get(
			"heartbeat_intro_elapsed",
			estado_alarme.get("tension_intro_elapsed", DURACAO_BATIMENTO_INICIAL)
		)),
		0.0,
		DURACAO_BATIMENTO_INICIAL
	)
	if estado_alarme.is_empty():
		var missao: Dictionary = SaveGame.office_mission_state()
		if bool(missao.get("data_center_power_outage", false)) and not bool(missao.get("data_center_breaker_restored", false)):
			_iniciar_audio_disjuntor()
		else:
			_parar_audio_disjuntor()
	_atualizar_volume_alarme(0.0)
	if alarme_silenciado_jogador:
		som_alarme.stop()


func silenciar_alarme_jogador() -> bool:
	if alarme_silenciado_jogador or not som_alarme.playing:
		return false
	posicao_alarme_jogador = maxf(0.0, som_alarme.get_playback_position())
	alarme_silenciado_jogador = true
	aviso_alarme_exibido = true
	som_alarme.stop()
	_atualizar_saida_alarme()
	return true


func alternar_alarme_jogador() -> bool:
	if not alarme_silenciado_jogador:
		return silenciar_alarme_jogador()
	alarme_silenciado_jogador = false
	_tocar_se_parado(som_alarme, posicao_alarme_jogador)
	_atualizar_saida_alarme()
	return true


func definir_contexto_alarme_baixo(contexto: StringName, ativo: bool) -> void:
	if ativo:
		contextos_alarme_baixo[contexto] = true
	else:
		contextos_alarme_baixo.erase(contexto)
	_atualizar_saida_alarme()


func definir_audio_elevador(ativo: bool) -> void:
	if audio_elevador_ativo == ativo:
		return
	audio_elevador_ativo = ativo
	for caminho_tocador: NodePath in MUSICAS_ELEVADOR:
		var tocador := get_node_or_null(caminho_tocador) as AudioStreamPlayer
		if tocador == null:
			continue
		if ativo:
			modos_musica_elevador[caminho_tocador] = tocador.process_mode
			tocador.process_mode = Node.PROCESS_MODE_ALWAYS
		else:
			var modo_anterior: int = modos_musica_elevador.get(caminho_tocador, Node.PROCESS_MODE_INHERIT)
			@warning_ignore("int_as_enum_without_cast")
			tocador.process_mode = modo_anterior
	modos_musica_elevador.clear()

	for ambiente: Node in get_tree().get_nodes_in_group("scene_ambience"):
		if is_instance_valid(ambiente) and ambiente.has_method("definir_silencio_elevador"):
			ambiente.call("definir_silencio_elevador", ativo)


func contexto_alarme_baixo_ativo(contexto: StringName) -> bool:
	return contextos_alarme_baixo.has(contexto)


func _aplicar_volume_alarme(volume_db: float) -> void:
	volume_alarme_sem_atenuacao_db = volume_db
	_atualizar_saida_alarme()


func _atualizar_saida_alarme() -> void:
	if alarme_silenciado_jogador:
		som_alarme.volume_db = VOLUME_SILENCIO_DB
		return
	var volume_saida_db := volume_alarme_sem_atenuacao_db
	if not contextos_alarme_baixo.is_empty():
		volume_saida_db = linear_to_db(
			db_to_linear(volume_normal_alarme_db) * VOLUME_CONTEXTO_ALARME_BAIXO
		)
	som_alarme.volume_db = volume_saida_db + linear_to_db(fator_musica_tutorial)


func _obter_tocador(id_tocador: String) -> AudioStreamPlayer:
	if not TOCADORES_AUDIO.has(id_tocador):
		return null

	return get_node_or_null(TOCADORES_AUDIO[id_tocador]) as AudioStreamPlayer


func _tocar_se_parado(
	tocador: AudioStreamPlayer,
	posicao_inicial: float = 0.0
) -> void:
	if tocador == null or tocador.stream == null:
		return

	if audio_cena_bloqueado:
		var id_tocador := _obter_id_tocador(tocador)

		if not id_tocador.is_empty():
			inicios_pendentes[id_tocador] = maxf(posicao_inicial, 0.0)

		return

	if tocador.playing:
		if tocador.stream_paused:
			tocador.stream_paused = false
		return

	tocador.play(maxf(posicao_inicial, 0.0))


func _obter_id_tocador(tocador: AudioStreamPlayer) -> String:
	for id_tocador: String in TOCADORES_AUDIO:
		if _obter_tocador(id_tocador) == tocador:
			return id_tocador

	return ""


func _checkpoint_sem_audio(estado: Dictionary) -> bool:
	var encontrou_tocador := false

	for id_tocador: String in TOCADORES_AUDIO:
		if not estado.has(id_tocador):
			continue

		var valor_salvo: Variant = estado[id_tocador]

		if not valor_salvo is Dictionary:
			continue

		encontrou_tocador = true

		if bool((valor_salvo as Dictionary).get("playing", false)):
			return false

	return encontrou_tocador
