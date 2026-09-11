extends Node2D

@onready var bg_music: AudioStreamPlayer2D = $"BG Music"
@onready var bg_ambient: AudioStreamPlayer2D = $"BG Ambient"
@onready var countdown_music: AudioStreamPlayer2D = $COUNTDOWN_MUSIC
@onready var som_alarme: AudioStreamPlayer2D = $SOM_ALARME
@onready var som_de_fundo: AudioStreamPlayer2D = $SOM_DE_FUNDO
@onready var musica_quando_o_disjuntor_apagar: AudioStreamPlayer2D = $MUSICA_QUANDO_O_DISJUNTOR_APAGAR

const AUDIO_PLAYERS: Dictionary = {
	"bg_music": NodePath("BG Music"),
	"bg_ambient": NodePath("BG Ambient"),
	"countdown_music": NodePath("COUNTDOWN_MUSIC"),
	"som_alarme": NodePath("SOM_ALARME"),
	"som_de_fundo": NodePath("SOM_DE_FUNDO"),
	"musica_quando_o_disjuntor_apagar": NodePath("MUSICA_QUANDO_O_DISJUNTOR_APAGAR")
}

const SILENT_VOLUME_DB: float = -80.0
const OPENING_MUSIC_FADE_DURATION: float = 3.0
const POWER_OUTAGE_FADE_DURATION: float = 4.0
const POWER_OUTAGE_ALARM_VOLUME: float = 0.3
const ALARM_INITIAL_VOLUME: float = 0.3
const ALARM_REDUCED_VOLUME: float = 0.1
const ALARM_INITIAL_DURATION: float = 30.0
const ALARM_FADE_DURATION: float = 4.0
const ALARM_QUIET_CONTEXT_VOLUME: float = 0.05

enum PowerOutageAudioState {
	IDLE,
	FADING_IN,
	ACTIVE,
	FADING_OUT
}

var scene_audio_blocked: bool = false
var pending_scene_starts: Dictionary = {}
var alarm_normal_volume_db: float = 0.0
var alarm_elapsed: float = 0.0
var alarm_unducked_volume_db: float = 0.0
var alarm_user_muted: bool = false
var alarm_user_position: float = 0.0
var alarm_quiet_contexts: Dictionary = {}
var opening_music_normal_volume_db: float = 0.0
var opening_music_started: bool = false
var opening_music_finished: bool = false
var power_outage_music_normal_volume_db: float = 0.0
var power_outage_audio_state: PowerOutageAudioState = PowerOutageAudioState.IDLE
var power_outage_fade_elapsed: float = 0.0
var power_outage_alarm_start_db: float = SILENT_VOLUME_DB
var power_outage_alarm_target_db: float = SILENT_VOLUME_DB
var power_outage_music_start_db: float = SILENT_VOLUME_DB
var power_outage_music_target_db: float = SILENT_VOLUME_DB


func _ready() -> void:
	# Os volumes pertencem ao SaveLoad. Alterá-los aqui fazia o autoload de
	# música sobrescrever as preferências logo depois de elas serem carregadas.
	_play_if_stopped(bg_ambient)
	_play_if_stopped(bg_music)
	alarm_normal_volume_db = som_alarme.volume_db
	alarm_unducked_volume_db = som_alarme.volume_db
	opening_music_normal_volume_db = som_de_fundo.volume_db
	power_outage_music_normal_volume_db = musica_quando_o_disjuntor_apagar.volume_db


func _process(delta: float) -> void:
	if scene_audio_blocked or get_tree().paused:
		return
	_update_opening_music_fade()
	_update_alarm_volume(delta)
	_update_power_outage_audio(delta)


func _update_alarm_volume(delta: float) -> void:
	if not som_alarme.playing or som_alarme.stream_paused:
		return
	alarm_elapsed = minf(alarm_elapsed + delta, ALARM_INITIAL_DURATION + ALARM_FADE_DURATION)
	if power_outage_audio_state != PowerOutageAudioState.IDLE:
		return
	var progress := clampf((alarm_elapsed - ALARM_INITIAL_DURATION) / ALARM_FADE_DURATION, 0.0, 1.0)
	_apply_alarm_volume(linear_to_db(
		db_to_linear(alarm_normal_volume_db)
		* lerpf(ALARM_INITIAL_VOLUME, ALARM_REDUCED_VOLUME, progress)
	))


# BG MUSIC
func _start_bg_music(from_position: float = 0.0) -> void:
	_play_if_stopped(bg_music, from_position)

func _stop_bg_music() -> void:
	bg_music.stop()


# BG AMBIENT
func _start_bg_ambient(from_position: float = 0.0) -> void:
	_play_if_stopped(bg_ambient, from_position)

func _stop_bg_ambient() -> void:
	bg_ambient.stop()


# COUNTDOWN
func _start_countdown(from_position: float = 0.0) -> void:
	_play_if_stopped(countdown_music, from_position)

func _stop_countdown() -> void:
	countdown_music.stop()


# ALARME
func _start_som_alarme(from_position: float = 0.0) -> void:
	if alarm_user_muted:
		return
	_play_if_stopped(som_alarme, from_position)
	_update_alarm_volume(0.0)

func _stop_som_alarme() -> void:
	if power_outage_audio_state != PowerOutageAudioState.IDLE:
		return
	som_alarme.stop()
	alarm_unducked_volume_db = alarm_normal_volume_db
	_refresh_alarm_output()


# SOM DE FUNDO
func _start_som_de_fundo(from_position: float = 0.0) -> void:
	if opening_music_finished:
		return
	if not som_de_fundo.playing:
		som_de_fundo.volume_db = opening_music_normal_volume_db
		opening_music_started = true
	_play_if_stopped(som_de_fundo, from_position)

func _stop_som_de_fundo() -> void:
	som_de_fundo.stop()
	

func _set_volume_som_de_fundo(volume: float) -> void:
	opening_music_normal_volume_db = linear_to_db(volume)
	if not opening_music_finished:
		som_de_fundo.volume_db = opening_music_normal_volume_db


func _set_volume_som_alarme(volume: float) -> void:
	alarm_normal_volume_db = linear_to_db(volume)
	if power_outage_audio_state == PowerOutageAudioState.IDLE:
		_update_alarm_volume(0.0)


func _set_volume_countdown(volume: float) -> void:
	countdown_music.volume_db = linear_to_db(volume)


func _start_power_outage_audio() -> void:
	if power_outage_audio_state == PowerOutageAudioState.ACTIVE or power_outage_audio_state == PowerOutageAudioState.FADING_IN:
		return
	var resuming_fade_out := power_outage_audio_state == PowerOutageAudioState.FADING_OUT
	if not resuming_fade_out:
		musica_quando_o_disjuntor_apagar.volume_db = SILENT_VOLUME_DB
	if not alarm_user_muted and not som_alarme.playing:
		som_alarme.volume_db = SILENT_VOLUME_DB
		_play_if_stopped(som_alarme)
	if not musica_quando_o_disjuntor_apagar.playing:
		_play_if_stopped(musica_quando_o_disjuntor_apagar)
	_start_power_outage_fade(
		PowerOutageAudioState.FADING_IN,
		linear_to_db(db_to_linear(alarm_normal_volume_db) * POWER_OUTAGE_ALARM_VOLUME),
		power_outage_music_normal_volume_db
	)


func _stop_power_outage_audio() -> void:
	if power_outage_audio_state == PowerOutageAudioState.FADING_OUT:
		return
	if power_outage_audio_state == PowerOutageAudioState.IDLE and not musica_quando_o_disjuntor_apagar.playing:
		return
	# Religou o disjuntor: o alarme continua baixo, mesmo se a queda de
	# energia aconteceu antes de terminar os 30 segundos iniciais.
	alarm_elapsed = ALARM_INITIAL_DURATION + ALARM_FADE_DURATION
	_start_power_outage_fade(
		PowerOutageAudioState.FADING_OUT,
		linear_to_db(db_to_linear(alarm_normal_volume_db) * ALARM_REDUCED_VOLUME),
		SILENT_VOLUME_DB
	)


func _update_opening_music_fade() -> void:
	if opening_music_finished or not opening_music_started:
		return
	if not som_de_fundo.playing:
		opening_music_finished = true
		return
	if som_de_fundo.stream == null:
		return
	var duration := som_de_fundo.stream.get_length()
	if duration <= 0.0:
		return
	var fade_start := maxf(0.0, duration - OPENING_MUSIC_FADE_DURATION)
	var progress := clampf(
		(som_de_fundo.get_playback_position() - fade_start) / OPENING_MUSIC_FADE_DURATION,
		0.0,
		1.0
	)
	if progress > 0.0:
		som_de_fundo.volume_db = lerpf(
			opening_music_normal_volume_db,
			SILENT_VOLUME_DB,
			progress
		)


func _start_power_outage_fade(
	new_state: PowerOutageAudioState,
	alarm_target_db: float,
	music_target_db: float
) -> void:
	power_outage_audio_state = new_state
	power_outage_fade_elapsed = 0.0
	# O fade usa o volume da sequência; elevador e minigame só alteram a saída.
	power_outage_alarm_start_db = alarm_unducked_volume_db
	power_outage_alarm_target_db = alarm_target_db
	power_outage_music_start_db = musica_quando_o_disjuntor_apagar.volume_db
	power_outage_music_target_db = music_target_db


func _update_power_outage_audio(delta: float) -> void:
	if power_outage_audio_state == PowerOutageAudioState.IDLE:
		return
	power_outage_fade_elapsed += delta
	var progress := clampf(power_outage_fade_elapsed / POWER_OUTAGE_FADE_DURATION, 0.0, 1.0)
	_apply_alarm_volume(lerpf(
		power_outage_alarm_start_db,
		power_outage_alarm_target_db,
		progress
	))
	musica_quando_o_disjuntor_apagar.volume_db = lerpf(
		power_outage_music_start_db,
		power_outage_music_target_db,
		progress
	)
	if progress < 1.0:
		return
	if power_outage_audio_state == PowerOutageAudioState.FADING_OUT:
		musica_quando_o_disjuntor_apagar.stop()
		musica_quando_o_disjuntor_apagar.volume_db = power_outage_music_normal_volume_db
		power_outage_audio_state = PowerOutageAudioState.IDLE
		return
	power_outage_audio_state = PowerOutageAudioState.ACTIVE


func stop_all_audio() -> void:
	scene_audio_blocked = false
	pending_scene_starts.clear()
	opening_music_started = false
	opening_music_finished = false
	power_outage_audio_state = PowerOutageAudioState.IDLE
	power_outage_fade_elapsed = 0.0
	alarm_elapsed = 0.0
	alarm_user_muted = false
	alarm_user_position = 0.0
	alarm_quiet_contexts.clear()

	# MusicController é um autoload e sobrevive às mudanças de cena. Por isso,
	# um reset de campanha precisa parar explicitamente todos os players.
	for player_id: String in AUDIO_PLAYERS:
		var audio_player := _get_audio_player(player_id)

		if audio_player == null:
			continue

		audio_player.stop()
		audio_player.stream_paused = false


func pause_all_audio() -> void:
	# O menu silencia sem destruir o playback. Isso evita recriar vários buffers
	# do WASAPI e permite fazer seek no mesmo stream ao continuar a partida.
	scene_audio_blocked = true

	for player_id: String in AUDIO_PLAYERS:
		var audio_player := _get_audio_player(player_id)

		if audio_player != null and audio_player.playing:
			audio_player.stream_paused = true


func begin_checkpoint_restore() -> void:
	pending_scene_starts.clear()
	pause_all_audio()


func allow_scene_audio() -> void:
	scene_audio_blocked = false
	pending_scene_starts.clear()


func get_checkpoint_state() -> Dictionary:
	var state: Dictionary = {}
	state["alarm_envelope"] = {
		"elapsed": alarm_elapsed,
		"unducked_volume_db": alarm_unducked_volume_db,
		"user_muted": alarm_user_muted,
		"user_position": alarm_user_position,
		"power_state": power_outage_audio_state,
		"fade_elapsed": power_outage_fade_elapsed,
		"alarm_start": power_outage_alarm_start_db,
		"alarm_target": power_outage_alarm_target_db,
		"music_start": power_outage_music_start_db,
		"music_target": power_outage_music_target_db
	}

	for player_id: String in AUDIO_PLAYERS:
		var audio_player := _get_audio_player(player_id)

		if audio_player == null:
			continue

		state[player_id] = {
			"playing": audio_player.playing,
			"position": (
				audio_player.get_playback_position()
				if audio_player.playing
				else 0.0
			),
			"volume_db": audio_player.volume_db
		}

	return state


func load_checkpoint_state(state: Dictionary) -> void:
	# Saves anteriores à versão com áudio não possuem este bloco. Nesse caso,
	# preservamos o comportamento iniciado pela própria cena.
	if state.is_empty():
		scene_audio_blocked = false
		pending_scene_starts.clear()
		return

	# Versões anteriores conseguiam salvar o silêncio do menu como se todas as
	# faixas da fase estivessem paradas. Se a própria cena pediu uma faixa em
	# _ready(), usamos esse pedido para recuperar também o save já afetado.
	var recover_silent_save := (
		_is_silent_checkpoint_state(state)
		and not pending_scene_starts.is_empty()
	)

	for player_id: String in AUDIO_PLAYERS:
		if not state.has(player_id):
			continue

		var audio_player := _get_audio_player(player_id)
		var saved_value: Variant = state[player_id]

		if audio_player == null or not saved_value is Dictionary:
			continue

		var saved_player: Dictionary = saved_value
		var should_play := bool(saved_player.get("playing", false))
		var playback_position := maxf(
			0.0,
			float(saved_player.get("position", 0.0))
		)

		if recover_silent_save and pending_scene_starts.has(player_id):
			should_play = true
			playback_position = maxf(
				0.0,
				float(pending_scene_starts[player_id])
			)

		audio_player.volume_db = float(
			saved_player.get("volume_db", audio_player.volume_db)
		)

		if not should_play:
			if audio_player.playing:
				audio_player.stop()

			audio_player.stream_paused = false
			continue

		if audio_player.stream == null:
			continue

		var stream_length := audio_player.stream.get_length()

		if stream_length > 0.0:
			playback_position = fmod(playback_position, stream_length)

		if audio_player.playing:
			# Mantém o mesmo playback/buffer ativo e apenas reposiciona a faixa.
			audio_player.stream_paused = true
			audio_player.seek(playback_position)
		else:
			audio_player.play(playback_position)

		# stream_paused é um estado técnico da troca de cena/ menu de pausa,
		# não uma preferência do jogador. Saves antigos podiam registrar true
		# aqui e deixar a faixa permanentemente muda ao abrir o jogo novamente.
		audio_player.stream_paused = false

	scene_audio_blocked = false
	pending_scene_starts.clear()
	_restore_alarm_envelope(state)


func _restore_alarm_envelope(state: Dictionary) -> void:
	var envelope: Dictionary = state.get("alarm_envelope", {})
	# Saves anteriores não contavam os 30 segundos. Retomam no patamar baixo.
	alarm_elapsed = float(envelope.get("elapsed", ALARM_INITIAL_DURATION + ALARM_FADE_DURATION))
	alarm_unducked_volume_db = float(envelope.get("unducked_volume_db", som_alarme.volume_db))
	alarm_user_muted = bool(envelope.get("user_muted", false))
	alarm_user_position = maxf(0.0, float(envelope.get("user_position", 0.0)))
	alarm_quiet_contexts.clear()
	power_outage_audio_state = int(envelope.get("power_state", PowerOutageAudioState.IDLE)) as PowerOutageAudioState
	power_outage_fade_elapsed = float(envelope.get("fade_elapsed", 0.0))
	power_outage_alarm_start_db = float(envelope.get("alarm_start", som_alarme.volume_db))
	power_outage_alarm_target_db = float(envelope.get("alarm_target", som_alarme.volume_db))
	power_outage_music_start_db = float(envelope.get("music_start", musica_quando_o_disjuntor_apagar.volume_db))
	power_outage_music_target_db = float(envelope.get("music_target", musica_quando_o_disjuntor_apagar.volume_db))
	if envelope.is_empty():
		var mission: Dictionary = SaveGame.office_mission_state()
		if bool(mission.get("data_center_power_outage", false)) and not bool(mission.get("data_center_breaker_restored", false)):
			_start_power_outage_audio()
		else:
			_stop_power_outage_audio()
	_update_alarm_volume(0.0)
	if alarm_user_muted:
		som_alarme.stop()


func mute_alarm_by_player() -> bool:
	if alarm_user_muted or not som_alarme.playing:
		return false
	alarm_user_position = maxf(0.0, som_alarme.get_playback_position())
	alarm_user_muted = true
	som_alarme.stop()
	_refresh_alarm_output()
	return true


func toggle_alarm_by_player() -> bool:
	if not alarm_user_muted:
		return mute_alarm_by_player()
	alarm_user_muted = false
	_play_if_stopped(som_alarme, alarm_user_position)
	_refresh_alarm_output()
	return true


func set_alarm_quiet_context(context: StringName, active: bool) -> void:
	if active:
		alarm_quiet_contexts[context] = true
	else:
		alarm_quiet_contexts.erase(context)
	_refresh_alarm_output()


func is_alarm_quiet_context_active(context: StringName) -> bool:
	return alarm_quiet_contexts.has(context)


func _apply_alarm_volume(volume_db: float) -> void:
	alarm_unducked_volume_db = volume_db
	_refresh_alarm_output()


func _refresh_alarm_output() -> void:
	if alarm_user_muted:
		som_alarme.volume_db = SILENT_VOLUME_DB
		return
	if not alarm_quiet_contexts.is_empty():
		som_alarme.volume_db = linear_to_db(
			db_to_linear(alarm_normal_volume_db) * ALARM_QUIET_CONTEXT_VOLUME
		)
		return
	som_alarme.volume_db = alarm_unducked_volume_db


func _get_audio_player(player_id: String) -> AudioStreamPlayer2D:
	if not AUDIO_PLAYERS.has(player_id):
		return null

	return get_node_or_null(AUDIO_PLAYERS[player_id]) as AudioStreamPlayer2D


func _play_if_stopped(
	audio_player: AudioStreamPlayer2D,
	from_position: float = 0.0
) -> void:
	if audio_player == null or audio_player.stream == null:
		return

	if scene_audio_blocked:
		var player_id := _get_audio_player_id(audio_player)

		if not player_id.is_empty():
			pending_scene_starts[player_id] = maxf(from_position, 0.0)

		return

	if audio_player.playing:
		if audio_player.stream_paused:
			audio_player.stream_paused = false
		return

	audio_player.play(maxf(from_position, 0.0))


func _get_audio_player_id(audio_player: AudioStreamPlayer2D) -> String:
	for player_id: String in AUDIO_PLAYERS:
		if _get_audio_player(player_id) == audio_player:
			return player_id

	return ""


func _is_silent_checkpoint_state(state: Dictionary) -> bool:
	var found_player := false

	for player_id: String in AUDIO_PLAYERS:
		if not state.has(player_id):
			continue

		var saved_value: Variant = state[player_id]

		if not saved_value is Dictionary:
			continue

		found_player = true

		if bool((saved_value as Dictionary).get("playing", false)):
			return false

	return found_player
