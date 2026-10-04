extends Node

var ordem_reproducao: int = 0
@onready var vozes: Array[Node] = $Vozes.get_children()


func _process(_delta: float) -> void:
	for voz in vozes:
		if voz.em_uso and not voz.origem_valida():
			voz.parar()


func tocar_no_mundo(origem: Node2D, som: AudioStream, volume: float, alcance: float) -> void:
	var voz := _reservar_voz(origem, som)
	if voz != null:
		voz.iniciar_no_mundo(origem, som, volume, alcance, ordem_reproducao)


func tocar_sequencia_interface(origem: Node, sons: Array[AudioStream], volumes: Array[float]) -> void:
	if sons.is_empty():
		return
	var voz := _reservar_voz(origem, sons[0])
	if voz != null:
		voz.iniciar_sequencia(origem, sons, volumes, ordem_reproducao)


func _reservar_voz(origem: Node, som: AudioStream) -> Node:
	if not is_instance_valid(origem) or som == null or not origem.is_inside_tree() or get_tree().paused:
		return null
	for voz in vozes:
		if voz.em_uso and not voz.origem_valida():
			voz.parar()
		if voz.mesmo_som(origem, som):
			return null
	ordem_reproducao += 1
	var mais_antiga: Node = vozes[0]
	for voz in vozes:
		if not voz.em_uso:
			return voz
		if voz.ordem_inicio < mais_antiga.ordem_inicio:
			mais_antiga = voz
	return mais_antiga


func obter_vozes_ativas() -> Array[Node]:
	var ativas: Array[Node] = []
	for voz in vozes:
		if voz.em_uso and voz.origem_valida():
			ativas.append(voz.obter_tocador())
	return ativas


func parar_todos() -> void:
	for voz in vozes:
		voz.parar()
