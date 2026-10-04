class_name GameAudio
extends RefCounted

const RASPAGENS: Array[AudioStream] = [
	preload("res://Sounds/External/scrape-1.ogg"),
	preload("res://Sounds/External/scrape-2.ogg")
]
const PASSAR_CARTAO: AudioStream = preload("res://Sounds/External/keyhole-lockbox-insert-01.wav")
const TECLA_TERMINAL: AudioStream = preload("res://Sounds/External/sfx100v2_switch_02.ogg")
const DISJUNTOR: AudioStream = preload("res://Sounds/External/sfx100v2_metal_hit_01.ogg")
const ACESSO_PERMITIDO: AudioStream = preload("res://Sounds/External/sfx100v2_lock_open_01.ogg")
const ACESSO_NEGADO: AudioStream = preload("res://Sounds/External/sfx100v2_switch_01.ogg")
const MAXIMO_VOZES: int = 8


static func tocar_no_mundo(origem: Node2D, som: AudioStream, volume_db: float = -10.0, alcance: float = 260.0) -> void:
	var gerenciador := _obter_gerenciador(origem)
	if gerenciador != null:
		gerenciador.tocar_no_mundo(origem, som, volume_db, alcance)


static func tocar_interface(origem: Node, som: AudioStream, volume_db: float = -12.0) -> void:
	tocar_sequencia_interface(origem, [som], [volume_db])


static func tocar_sequencia_interface(origem: Node, sons: Array[AudioStream], volumes: Array[float]) -> void:
	var gerenciador := _obter_gerenciador(origem)
	if gerenciador != null:
		gerenciador.tocar_sequencia_interface(origem, sons, volumes)


static func _obter_gerenciador(origem: Node) -> Node:
	if not is_instance_valid(origem) or not origem.is_inside_tree():
		return null
	return origem.get_tree().root.get_node_or_null("EfeitosSonoros")
