extends Node2D

const CUE_SHADER: Shader = preload("res://shaders/filtro_daltonismo.gdshader")

# Instanciado na cena como filho apenas do sprite relevante.
@export var interaction_path: NodePath

var _sprite: Node2D
var _interaction: Node
var _texture: Texture2D
var _source: Rect2
var _destination: Rect2
var _flip_h: bool = false
var _flip_v: bool = false
var _padding: Vector2 = Vector2.ONE
var _last_geometry: Array = []
var _cue_material: ShaderMaterial


func _ready() -> void:
	_sprite = get_parent() as Node2D
	if not (_sprite is Sprite2D or _sprite is AnimatedSprite2D):
		push_warning("ColorAccessibilityCue deve ser filho de um sprite.")
		hide()
		set_process(false)
		return
	if not interaction_path.is_empty():
		_interaction = get_node_or_null(interaction_path)
	if material is ShaderMaterial:
		_cue_material = material.duplicate() as ShaderMaterial
	else:
		_cue_material = ShaderMaterial.new()
	_cue_material.shader = CUE_SHADER
	material = _cue_material
	FiltroDaltonismo.modo_alterado.connect(_on_mode_changed)
	_on_mode_changed(FiltroDaltonismo.modo)


func _on_mode_changed(mode: int) -> void:
	material = _cue_material
	_cue_material.set_shader_parameter("modo", mode)
	set_process(mode != 0)
	visible = mode != 0
	if mode != 0:
		_process(0.0)


func _process(_delta: float) -> void:
	visible = _target_available()
	if not visible or not _sprite.is_visible_in_tree():
		return
	var texture: Texture2D
	var source: Rect2
	if _sprite is Sprite2D:
		var sprite := _sprite as Sprite2D
		texture = sprite.texture
		if texture == null:
			hide()
			return
		source = sprite.region_rect if sprite.region_enabled else Rect2(Vector2.ZERO, texture.get_size())
		source.size /= Vector2(sprite.hframes, sprite.vframes)
		source.position += Vector2(sprite.frame_coords) * source.size
		_flip_h = sprite.flip_h
		_flip_v = sprite.flip_v
		_destination = sprite.get_rect()
	else:
		var sprite := _sprite as AnimatedSprite2D
		if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(sprite.animation):
			hide()
			return
		texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		if texture == null:
			hide()
			return
		source = Rect2(Vector2.ZERO, texture.get_size())
		_flip_h = sprite.flip_h
		_flip_v = sprite.flip_v
		_destination = Rect2(sprite.offset, source.size)
		if sprite.centered:
			_destination.position -= source.size * 0.5
	# AtlasTexture usa UVs da folha inteira; limita as amostras ao frame atual.
	while texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		source.position += atlas.region.position - atlas.margin.position
		texture = atlas.atlas
	if texture == null or source.size.x <= 0.0 or source.size.y <= 0.0:
		hide()
		return
	_texture = texture
	_source = source
	var scale_x := maxf(_sprite.global_transform.x.length(), 0.01)
	var scale_y := maxf(_sprite.global_transform.y.length(), 0.01)
	_padding = Vector2(0.75 / scale_x, 0.75 / scale_y)
	# self_modulate não é herdado pelos filhos (modulate já é).
	self_modulate = _sprite.self_modulate
	var geometry: Array = [_texture, _source, _destination, _flip_h, _flip_v, _padding]
	if geometry != _last_geometry:
		_last_geometry = geometry
		queue_redraw()


func _target_available() -> bool:
	if not is_instance_valid(_interaction):
		return true
	# Itens guardados continuam recebendo o auxílio no ícone do inventário.
	var ancestor := _sprite.get_parent()
	while ancestor != null:
		if ancestor is Inventory:
			return true
		ancestor = ancestor.get_parent()
	return bool(_interaction.get("is_interactable")) and _interaction.process_mode != Node.PROCESS_MODE_DISABLED


func _draw() -> void:
	if _texture == null or _destination.size.x <= 0.0 or _destination.size.y <= 0.0:
		return
	var texture_size := _texture.get_size()
	var uv_start := _source.position / texture_size
	var uv_end := _source.end / texture_size
	var uv_padding := _padding * _source.size / _destination.size / texture_size
	_cue_material.set_shader_parameter("sprite_texture", _texture)
	_cue_material.set_shader_parameter("frame_uv", Vector4(uv_start.x, uv_start.y, uv_end.x, uv_end.y))
	_cue_material.set_shader_parameter("outline_uv", uv_padding)
	var destination := _destination.grow_individual(_padding.x, _padding.y, _padding.x, _padding.y)
	var first_uv := uv_start - uv_padding
	var last_uv := uv_end + uv_padding
	if _flip_h:
		var swap := first_uv.x
		first_uv.x = last_uv.x
		last_uv.x = swap
	if _flip_v:
		var swap := first_uv.y
		first_uv.y = last_uv.y
		last_uv.y = swap
	draw_primitive(
		PackedVector2Array([destination.position, Vector2(destination.end.x, destination.position.y), destination.end, Vector2(destination.position.x, destination.end.y)]),
		PackedColorArray([Color.WHITE]),
		PackedVector2Array([first_uv, Vector2(last_uv.x, first_uv.y), last_uv, Vector2(first_uv.x, last_uv.y)]),
		_texture
	)
