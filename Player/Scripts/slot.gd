extends Panel


const OPACIDADE_VAZIO: float = 0.5882353

@export var acao_equipar: StringName = &""
@export var permitir_cartao_superior: bool = true
@export var escala_item: Vector2 = Vector2.ONE

var item: Node2D = null
var equipped: bool = false

@onready var texto_tecla: Label = $BindLabel
@onready var destaque_equipado: Panel = $EquippedHighlight
@export var estilo_tecla_normal: StyleBoxFlat
@export var estilo_tecla_ativa: StyleBoxFlat
@export var material_interface: CanvasItemMaterial


func _ready() -> void:
	refresh_bind_label()
	_aplicar_estado_visual()


func put_item_on_inventory(item_scene: PackedScene) -> bool:
	if item_scene == null:
		push_warning("Tentativa de adicionar um item sem PackedScene ao inventário.")
		return false

	if item != null and not permitir_cartao_superior:
		return false

	var novo_item: Node2D = item_scene.instantiate() as Node2D

	if novo_item == null:
		push_warning("A cena do item não possui Node2D como nó raiz.")
		return false

	if item != null:
		var tipo_atual := _obter_tipo(item)
		var tipo_novo := _obter_tipo(novo_item)

		if tipo_novo <= tipo_atual:
			novo_item.queue_free()
			return false

		remove_child(item)
		item.queue_free()
		item = null

	self_modulate.a = 1.0

	if novo_item.has_method("marcar_como_item_inventario"):
		novo_item.marcar_como_item_inventario()

	item = novo_item
	add_child(item)

	item.position = size * 0.5
	item.scale = escala_item

	_aplicar_material_interface(item)
	_desativar_interacao_do_item(item)
	_aplicar_estado_visual()

	return true


func put_existing_item_on_inventory(
	existing_item: Node2D,
	force_replace: bool = false
) -> bool:
	if existing_item == null or not is_instance_valid(existing_item):
		push_warning("Tentativa de adicionar um item inexistente ao inventário.")
		return false

	if item != null and not force_replace:
		var tipo_atual := _obter_tipo(item)
		var tipo_novo := _obter_tipo(existing_item)
		if not permitir_cartao_superior or tipo_novo <= tipo_atual:
			return false

	if item != null:
		remove_child(item)
		item.queue_free()
		item = null

	var old_parent := existing_item.get_parent()
	if old_parent != null:
		old_parent.remove_child(existing_item)

	self_modulate.a = 1.0
	if existing_item.has_method("marcar_como_item_inventario"):
		existing_item.call("marcar_como_item_inventario")

	item = existing_item
	add_child(item)
	item.visible = true
	item.position = size * 0.5
	item.scale = escala_item

	_aplicar_material_interface(item)
	_desativar_interacao_do_item(item)
	_aplicar_estado_visual()
	return true


func _put_item_on_inventary(item_scene: PackedScene) -> void:
	put_item_on_inventory(item_scene)


func clear_item() -> void:
	if item != null and is_instance_valid(item):
		item.queue_free()

	item = null
	self_modulate.a = OPACIDADE_VAZIO
	set_equipped(false)


func set_equipped(value: bool) -> void:
	equipped = value and item != null and is_instance_valid(item)
	_aplicar_estado_visual()


func refresh_bind_label() -> void:
	if texto_tecla == null:
		return

	texto_tecla.text = get_bind_text()
	texto_tecla.accessibility_name = "Tecla do item: " + texto_tecla.text

	var events: Array[InputEvent] = InputMap.action_get_events(acao_equipar)
	texto_tecla.tooltip_text = events[0].as_text() if not events.is_empty() else ""


func get_bind_text() -> String:
	if acao_equipar.is_empty() or not InputMap.has_action(acao_equipar):
		return "—"

	var events: Array[InputEvent] = InputMap.action_get_events(acao_equipar)

	if events.is_empty():
		return "—"

	var event: InputEvent = events[0]

	if event is InputEventKey:
		var key_event := event as InputEventKey
		var keycode: Key = key_event.physical_keycode

		if keycode == KEY_NONE:
			keycode = key_event.keycode

		return OS.get_keycode_string(keycode).to_upper()

	if event is InputEventMouseButton:
		return "M%d" % (event as InputEventMouseButton).button_index

	if event is InputEventJoypadButton:
		return "J%d" % (event as InputEventJoypadButton).button_index

	var event_text: String = event.as_text().to_upper()
	return event_text.left(4) if not event_text.is_empty() else "—"


func _atualizar_posicao_item() -> void:
	if is_instance_valid(item):
		item.position = size * 0.5


func _aplicar_estado_visual() -> void:
	if destaque_equipado != null:
		destaque_equipado.visible = equipped

	if texto_tecla == null:
		return

	if equipped:
		texto_tecla.add_theme_stylebox_override("normal", estilo_tecla_ativa)
		texto_tecla.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	else:
		texto_tecla.add_theme_stylebox_override("normal", estilo_tecla_normal)
		texto_tecla.add_theme_color_override("font_color", Color.WHITE)


func _obter_tipo(node: Node) -> int:
	var valor = node.get("tipo")

	if valor == null:
		return 0

	return int(valor)


func _desativar_interacao_do_item(node: Node) -> void:
	var interactable = node.get_node_or_null("Interectable")

	if interactable != null:
		interactable.is_interactable = false

		if interactable is Area2D:
			interactable.monitoring = false
			interactable.monitorable = false

	var pickup_component = node.get_node_or_null("PickupComponent")

	if pickup_component != null:
		pickup_component.queue_free()


func _aplicar_material_interface(node: Node) -> void:

	if node.is_in_group(&"color_accessibility_cue"):
		return
	if node is CanvasItem:
		node.material = material_interface

	for child in node.get_children():
		_aplicar_material_interface(child)
