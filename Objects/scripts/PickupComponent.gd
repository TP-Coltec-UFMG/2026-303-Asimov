extends Node
class_name PickupComponent

@export var item_id: String = ""
@export var item_scene: PackedScene
@export var interactable: Area2D
@export var destruir_ao_coletar: bool = true


func _ready() -> void:
	if interactable == null:
		interactable = get_parent().get_node_or_null("Interectable")

	if interactable == null:
		push_warning("PickupComponent sem Interectable em: " + str(get_parent().name))
		return

	if item_scene == null:
		var parent_scene_path := get_parent().scene_file_path

		if parent_scene_path != "":
			item_scene = load(parent_scene_path)

	interactable.interact = coletar


func coletar() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player

	if player == null:
		push_warning("Nenhum Player encontrado no grupo 'player'.")
		return

	if player.inventory == null:
		push_warning("Player está sem referência para o inventory.")
		return

	var coletou: bool = player.inventory.add_item(item_id, item_scene)

	if coletou and destruir_ao_coletar:
		get_parent().queue_free()
