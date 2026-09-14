extends Node2D

# Os quatro cantos existem na cena; aqui apenas acompanham a área já existente.
@onready var _corners: Array[Node2D] = [$TopLeft, $TopRight, $BottomRight, $BottomLeft]

var _trigger: SceneTrigger
var _interaction: Area2D
var _collision: CollisionShape2D
var _last_rect: Rect2
var _last_scale: Vector2 = Vector2.ZERO


func _ready() -> void:
	_trigger = get_parent() as SceneTrigger
	if _trigger == null:
		hide()
		set_process(false)
		return
	_interaction = _trigger.get_node_or_null("Interectable") as Area2D
	_collision = _trigger.get_node_or_null("Interectable/CollisionShape2D") as CollisionShape2D
	FiltroDaltonismo.modo_alterado.connect(_on_mode_changed)
	HighContrast.enabled_changed.connect(_on_high_contrast_changed)
	_refresh_enabled_state()


func _on_mode_changed(mode: int) -> void:
	_refresh_enabled_state(mode)


func _on_high_contrast_changed(_enabled: bool) -> void:
	_refresh_enabled_state()


func _refresh_enabled_state(mode: int = FiltroDaltonismo.modo) -> void:
	var enabled := mode != 0 or HighContrast.enabled
	set_process(enabled)
	if not enabled:
		hide()
	else:
		_process(0.0)


func _process(_delta: float) -> void:
	visible = _target_available()
	if not visible:
		return
	# Mantém o contorno exatamente no retângulo local da interação, inclusive
	# quando a cena posiciona o leitor longe da origem do SceneTrigger.
	global_transform = _collision.global_transform
	var target_scale := Vector2(global_transform.x.length(), global_transform.y.length())
	var local_rect: Rect2 = _collision.shape.get_rect()
	if local_rect == _last_rect and target_scale == _last_scale:
		return
	_last_rect = local_rect
	_last_scale = target_scale
	var scale_factor := maxf(minf(target_scale.x, target_scale.y), 0.01)
	var frame := local_rect.grow(0.75 / scale_factor)
	var corner_length := minf(3.0 / scale_factor, minf(frame.size.x, frame.size.y) * 0.3)
	var positions: Array[Vector2] = [frame.position, Vector2(frame.end.x, frame.position.y), frame.end, Vector2(frame.position.x, frame.end.y)]
	var directions: Array[Vector2] = [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	for index in _corners.size():
		var corner := positions[index]
		var direction := directions[index]
		var points := PackedVector2Array([
			corner + Vector2(direction.x * corner_length, 0),
			corner,
			corner + Vector2(0, direction.y * corner_length),
		])
		var shadow := _corners[index].get_node("Shadow") as Line2D
		var line := _corners[index].get_node("Line") as Line2D
		shadow.points = points
		line.points = points
		shadow.width = 1.5 / scale_factor
		line.width = 0.65 / scale_factor


func _target_available() -> bool:
	if not is_instance_valid(_trigger) or not is_instance_valid(_interaction) or not is_instance_valid(_collision):
		return false
	if not _trigger.dentro_da_area or not _trigger.is_visible_in_tree() or not _interaction.is_visible_in_tree():
		return false
	if _processing_disabled(_trigger) or _processing_disabled(_interaction):
		return false
	return bool(_interaction.get("is_interactable")) and not _collision.disabled and _collision.shape != null


func _processing_disabled(node: Node) -> bool:
	while node != null:
		if node.process_mode != Node.PROCESS_MODE_INHERIT:
			return node.process_mode == Node.PROCESS_MODE_DISABLED
		node = node.get_parent()
	return false
