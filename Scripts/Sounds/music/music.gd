extends Node2D

@onready var bg_music: AudioStreamPlayer2D = $"BG Music"
@onready var bg_ambient: AudioStreamPlayer2D = $"BG Ambient"
@onready var countdown_music: AudioStreamPlayer2D = $COUNTDOWN_MUSIC
@onready var som_alarme: AudioStreamPlayer2D = $SOM_ALARME
@onready var som_de_fundo: AudioStreamPlayer2D = $SOM_DE_FUNDO

const AUDIO_PLAYERS: Dictionary = {
	"bg_music": NodePath("BG Music"),
	"bg_ambient": NodePath("BG Ambient"),
	"countdown_music": NodePath("COUNTDOWN_MUSIC"),
	"som_alarme": NodePath("SOM_ALARME"),
	"som_de_fundo": NodePath("SOM_DE_FUNDO")
}

var scene_audio_blocked: bool = false
var pending_scene_starts: Dictionary = {}


func _ready() -> void:
	# Os volumes pertencem ao SaveLoad. Alterá-los aqui fazia o autoload de
	# música sobrescrever as preferências logo depois de elas serem carregadas.
	_play_if_stopped(bg_ambient)
	_play_if_stopped(bg_music)


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
	_play_if_stopped(som_alarme, from_position)

func _stop_som_alarme() -> void:
	som_alarme.stop()


# SOM DE FUNDO
func _start_som_de_fundo(from_position: float = 0.0) -> void:
	_play_if_stopped(som_de_fundo, from_position)

func _stop_som_de_fundo() -> void:
	som_de_fundo.stop()
	

func _set_volume_som_de_fundo(volume: float) -> void:
	som_de_fundo.volume_db = linear_to_db(volume)


func _set_volume_som_alarme(volume: float) -> void:
	som_alarme.volume_db = linear_to_db(volume)


func _set_volume_countdown(volume: float) -> void:
	countdown_music.volume_db = linear_to_db(volume)


func stop_all_audio() -> void:
	scene_audio_blocked = false
	pending_scene_starts.clear()

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
