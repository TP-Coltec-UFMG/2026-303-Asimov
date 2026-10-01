extends CanvasLayer

const DURATION: float = 10.0
const INITIAL_BLUR: float = 9.0
const SILENT_VOLUME_DB: float = -80.0

@onready var blur_rect: ColorRect = $Blur

var master_bus_index: int = -1


func _ready() -> void:
	var material := blur_rect.material as ShaderMaterial
	if material == null:
		queue_free()
		return
	material = material.duplicate() as ShaderMaterial
	blur_rect.material = material
	material.set_shader_parameter("blur_amount", INITIAL_BLUR)
	master_bus_index = AudioServer.get_bus_index("Master")
	_set_master_volume(0.0)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_method(_set_opening_progress, 0.0, 1.0, DURATION)
	await tween.finished
	_restore_configured_volume()
	queue_free()


func _exit_tree() -> void:
	_restore_configured_volume()


func _set_opening_progress(progress: float) -> void:
	var material := blur_rect.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter(
			"blur_amount",
			lerpf(INITIAL_BLUR, 0.0, progress)
		)
	_set_master_volume(_configured_master_volume() * progress)


func _configured_master_volume() -> float:
	return clampf(float(Configs.configs.get("volume_geral", 1.0)), 0.0, 1.0)


func _set_master_volume(linear_volume: float) -> void:
	if master_bus_index < 0:
		return
	var volume_db := SILENT_VOLUME_DB
	if linear_volume > 0.0001:
		volume_db = linear_to_db(linear_volume)
	AudioServer.set_bus_volume_db(master_bus_index, volume_db)


func _restore_configured_volume() -> void:
	_set_master_volume(_configured_master_volume())
