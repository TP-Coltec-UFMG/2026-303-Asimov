extends Panel


const EMPTY_ALPHA: float = 0.5882353
const BIND_HEIGHT: float = 9.0
const BIND_GAP: float = 2.0
const NORMAL_BIND_BACKGROUND: Color = Color(0.055, 0.071, 0.086, 0.0)
const NORMAL_BIND_BORDER: Color = Color(0.58, 0.639, 0.678, 0.0)
const ACTIVE_BIND_BACKGROUND: Color = Color(0.278, 0.922, 0.698, 0.0)
const ACTIVE_BIND_BORDER: Color = Color(0.722, 1.0, 0.902, 0.0)
const ACTIVE_SLOT_BACKGROUND: Color = Color(0.765, 0.0, 0.176, 0.42)
const ACTIVE_SLOT_BORDER: Color = Color(0.173, 0.0, 0.0, 0.961)

@export var input_action: StringName = &""
@export var allow_higher_tier_replacement: bool = true
@export var item_display_scale: Vector2 = Vector2.ONE

var item: Node2D = null
var equipped: bool = false

var bind_label: Label
var equipped_highlight: Panel
var normal_bind_style: StyleBoxFlat
var active_bind_style: StyleBoxFlat
var unshaded_hud_material: CanvasItemMaterial


func _ready() -> void:
	add_to_group(&"inventory_binding_slots")
	_create_equipped_highlight()
	_create_bind_label()
	resized.connect(_layout_auxiliary_controls)
	_layout_auxiliary_controls()
	refresh_bind_label()
	_apply_visual_state()


func put_item_on_inventory(item_scene: PackedScene) -> bool:
	if item_scene == null:
		push_warning("Tentativa de adicionar um item sem PackedScene ao inventário.")
		return false

	if item != null and not allow_higher_tier_replacement:
		return false

	var novo_item: Node2D = item_scene.instantiate() as Node2D

	if novo_item == null:
		push_warning("A cena do item não possui Node2D como nó raiz.")
		return false

	if item != null:
		var tipo_atual := _get_tipo(item)
		var tipo_novo := _get_tipo(novo_item)

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
	item.scale = item_display_scale

	_make_unshaded(item)
	_desativar_interacao_do_item(item)
	_apply_visual_state()

	return true


func _put_item_on_inventary(item_scene: PackedScene) -> void:
	put_item_on_inventory(item_scene)


func clear_item() -> void:
	if item != null and is_instance_valid(item):
		item.queue_free()

	item = null
	self_modulate.a = EMPTY_ALPHA
	set_equipped(false)


func set_equipped(value: bool) -> void:
	equipped = value and item != null and is_instance_valid(item)
	_apply_visual_state()


func refresh_bind_label() -> void:
	if bind_label == null:
		return

	bind_label.text = get_bind_text()
	bind_label.accessibility_name = "Tecla do item: " + bind_label.text

	var events: Array[InputEvent] = InputMap.action_get_events(input_action)
	bind_label.tooltip_text = events[0].as_text() if not events.is_empty() else ""


func get_bind_text() -> String:
	if input_action.is_empty() or not InputMap.has_action(input_action):
		return "—"

	var events: Array[InputEvent] = InputMap.action_get_events(input_action)

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


func _create_equipped_highlight() -> void:
	equipped_highlight = Panel.new()
	equipped_highlight.name = "EquippedHighlight"
	equipped_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equipped_highlight.material = _get_unshaded_hud_material()

	var highlight_style := StyleBoxFlat.new()
	highlight_style.bg_color = ACTIVE_SLOT_BACKGROUND
	highlight_style.border_color = ACTIVE_SLOT_BORDER
	highlight_style.set_border_width_all(1)
	highlight_style.set_corner_radius_all(0)

	equipped_highlight.add_theme_stylebox_override("panel", highlight_style)
	add_child(equipped_highlight)
	move_child(equipped_highlight, 0)


func _create_bind_label() -> void:
	normal_bind_style = _make_bind_style(
		NORMAL_BIND_BACKGROUND,
		NORMAL_BIND_BORDER
	)
	active_bind_style = _make_bind_style(
		ACTIVE_BIND_BACKGROUND,
		ACTIVE_BIND_BORDER
	)

	bind_label = Label.new()
	bind_label.name = "BindLabel"
	bind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bind_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bind_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bind_label.z_index = 10
	bind_label.material = _get_unshaded_hud_material()
	bind_label.add_theme_font_size_override("font_size", 7)
	bind_label.add_theme_color_override("font_color", Color.WHITE)
	bind_label.add_theme_constant_override("outline_size", 2)
	bind_label.add_theme_stylebox_override("normal", normal_bind_style)
	add_child(bind_label)


func _make_bind_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	style.content_margin_left = 1.0
	style.content_margin_right = 1.0
	return style


func _get_unshaded_hud_material() -> CanvasItemMaterial:
	if unshaded_hud_material == null:
		unshaded_hud_material = CanvasItemMaterial.new()
		unshaded_hud_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

	return unshaded_hud_material


func _layout_auxiliary_controls() -> void:
	if equipped_highlight != null:
		equipped_highlight.position = Vector2.ZERO
		equipped_highlight.size = size

	if bind_label != null:
		bind_label.position = Vector2(1.0, size.y + BIND_GAP)
		bind_label.size = Vector2(maxf(size.x - 2.0, 16.0), BIND_HEIGHT)

	if item != null and is_instance_valid(item):
		item.position = size * 0.5


func _apply_visual_state() -> void:
	if equipped_highlight != null:
		equipped_highlight.visible = equipped

	if bind_label == null:
		return

	if equipped:
		bind_label.add_theme_stylebox_override("normal", active_bind_style)
		bind_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	else:
		bind_label.add_theme_stylebox_override("normal", normal_bind_style)
		bind_label.add_theme_color_override("font_color", Color.WHITE)


func _get_tipo(node: Node) -> int:
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


func _make_unshaded(node: Node) -> void:
	if node is CanvasItem:
		var mat := CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		node.material = mat

	for child in node.get_children():
		_make_unshaded(child)
