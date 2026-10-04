extends Node2D

@export_enum("Hall", "Data Center", "Refrigeração", "Escritório", "Ferramentas") var tipo_ambiente: int = 0
@export_range(0.01, 2.0) var duracao_transicao: float = 0.5
@export var gotas: Array[AudioStream] = []

const VOLUMES_AMBIENTE: Array[float] = [-25.0, -28.0, -17.0, -27.0, -23.0]

var transicao_loop: bool = false
var tempo_transicao: float = 0.0
var entrada_suave: float = 0.0
var silenciado_elevador: bool = false

@onready var fundo: AudioStreamPlayer = $Fundo
@onready var proximo_fundo: AudioStreamPlayer = $ProximoFundo
@onready var som_gota: AudioStreamPlayer2D = $SomGota
@onready var som_metal: AudioStreamPlayer2D = $SomMetal
@onready var temporizador_gotas: Timer = $TemporizadorGotas
@onready var temporizador_metal: Timer = $TemporizadorMetal


func _ready() -> void:
	tipo_ambiente = clampi(tipo_ambiente, 0, VOLUMES_AMBIENTE.size() - 1)
	fundo.play()
	_iniciar_eventos_hall()


func _process(delta: float) -> void:
	if silenciado_elevador:
		fundo.volume_linear = 0.0
		proximo_fundo.volume_linear = 0.0
		return
	entrada_suave = minf(entrada_suave + delta, 1.0)
	var volume := db_to_linear(VOLUMES_AMBIENTE[tipo_ambiente]) * entrada_suave
	if not transicao_loop and fundo.get_playback_position() >= fundo.stream.get_length() - duracao_transicao:
		transicao_loop = true
		tempo_transicao = 0.0
		proximo_fundo.volume_linear = 0.0
		proximo_fundo.play()
	if transicao_loop:
		tempo_transicao = minf(tempo_transicao + delta, duracao_transicao)
		var progresso := tempo_transicao / duracao_transicao
		fundo.volume_linear = volume * (1.0 - progresso)
		proximo_fundo.volume_linear = volume * progresso
		if progresso >= 1.0:
			fundo.stop()
			var anterior := fundo
			fundo = proximo_fundo
			proximo_fundo = anterior
			transicao_loop = false
	else:
		fundo.volume_linear = volume
		if not fundo.playing:
			fundo.play()


func _ao_gotejar() -> void:
	if silenciado_elevador or tipo_ambiente != 0 or gotas.is_empty():
		return
	if som_metal.playing:
		temporizador_gotas.start(3.0)
		return
	som_gota.stream = gotas.pick_random()
	som_gota.play()
	temporizador_gotas.start(randf_range(7.0, 17.0))


func _ao_ranger_metal() -> void:
	if silenciado_elevador or tipo_ambiente != 0:
		return
	if som_gota.playing:
		temporizador_metal.start(3.0)
		return
	som_metal.play()
	temporizador_metal.start(randf_range(22.0, 42.0))


func definir_silencio_elevador(ativo: bool) -> void:
	if silenciado_elevador == ativo:
		return
	silenciado_elevador = ativo
	if ativo:
		temporizador_gotas.stop()
		temporizador_metal.stop()
		som_gota.stop()
		som_metal.stop()
		fundo.volume_linear = 0.0
		proximo_fundo.volume_linear = 0.0
	else:
		entrada_suave = 0.0
		_iniciar_eventos_hall()


func _iniciar_eventos_hall() -> void:
	if tipo_ambiente == 0:
		temporizador_gotas.start(randf_range(5.0, 11.0))
		temporizador_metal.start(randf_range(14.0, 25.0))
