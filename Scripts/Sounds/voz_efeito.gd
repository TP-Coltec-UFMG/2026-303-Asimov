extends Node

var em_uso: bool = false
var origem: WeakRef
var cena_origem: WeakRef
var sequencia: Array[AudioStream] = []
var volumes: Array[float] = []
var indice: int = 0
var ordem_inicio: int = 0
var som_inicial: AudioStream

@onready var som_mundo: AudioStreamPlayer2D = $SomMundo
@onready var som_interface: AudioStreamPlayer = $SomInterface


func iniciar_no_mundo(emissor: Node2D, som: AudioStream, volume: float, alcance: float, ordem: int) -> void:
	_preparar(emissor, som, ordem)
	som_mundo.stream = som
	som_mundo.volume_db = volume
	som_mundo.max_distance = alcance
	som_mundo.global_position = emissor.global_position
	som_mundo.play()


func iniciar_sequencia(emissor: Node, sons: Array[AudioStream], niveis: Array[float], ordem: int) -> void:
	_preparar(emissor, sons[0], ordem)
	sequencia.assign(sons)
	volumes.assign(niveis)
	_tocar_proximo()


func _preparar(emissor: Node, primeiro_som: AudioStream, ordem: int) -> void:
	parar()
	em_uso = true
	origem = weakref(emissor)
	var cena := emissor.get_tree().current_scene
	cena_origem = weakref(cena) if cena != null else null
	som_inicial = primeiro_som
	ordem_inicio = ordem


func origem_valida() -> bool:
	if origem == null:
		return false
	var emissor := origem.get_ref() as Node
	if not is_instance_valid(emissor) or not emissor.is_inside_tree() or emissor.is_queued_for_deletion():
		return false
	if cena_origem != null:
		var cena := cena_origem.get_ref() as Node
		if not is_instance_valid(cena) or cena.is_queued_for_deletion() or get_tree().current_scene != cena:
			return false
	return true


func mesmo_som(emissor: Node, som: AudioStream) -> bool:
	return em_uso and origem != null and origem.get_ref() == emissor and som_inicial == som


func obter_tocador() -> Node:
	return som_mundo if sequencia.is_empty() else som_interface


func parar() -> void:
	em_uso = false
	som_mundo.stop()
	som_interface.stop()
	som_mundo.stream = null
	som_interface.stream = null
	sequencia.clear()
	volumes.clear()
	indice = 0
	origem = null
	cena_origem = null
	som_inicial = null


func _ao_terminar_som_mundo() -> void:
	parar()


func _ao_terminar_som_interface() -> void:
	if em_uso:
		indice += 1
		_tocar_proximo()


func _tocar_proximo() -> void:
	if indice >= sequencia.size() or not origem_valida():
		parar()
		return
	som_interface.stream = sequencia[indice]
	som_interface.volume_db = volumes[indice] if indice < volumes.size() else -12.0
	som_interface.play()
