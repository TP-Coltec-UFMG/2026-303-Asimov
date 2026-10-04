extends Node
class_name PickupComponent

signal interagiu

@export var id_item: String = ""
@export var cena_item: PackedScene
@export var destruir_ao_coletar: bool = true
@export var criar_checkpoint_ao_coletar: bool = true


func _ready() -> void:
	if cena_item == null and not id_item.is_empty() and id_item != "conhecimento":
		var caminho_cena := get_parent().scene_file_path
		if not caminho_cena.is_empty():
			cena_item = load(caminho_cena)


func coletar() -> void:
	var jogador := get_tree().get_first_node_in_group("player") as Player
	if jogador == null or jogador.inventory == null:
		return
	if not jogador.inventory.add_item(id_item, cena_item):
		return
	interagiu.emit()
	var objeto := get_parent()
	if objeto.has_method("foi_coletado"):
		objeto.foi_coletado()
	if criar_checkpoint_ao_coletar:
		SaveGame.create_checkpoint(jogador)
	if destruir_ao_coletar:
		objeto.queue_free()
