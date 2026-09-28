extends CanvasLayer

const DURATION: float = 10.0
const INITIAL_BLUR: float = 9.0

@onready var blur_rect: ColorRect = $Blur


func _ready() -> void:
	var material := blur_rect.material as ShaderMaterial
	if material == null:
		queue_free()
		return
	material = material.duplicate() as ShaderMaterial
	blur_rect.material = material
	material.set_shader_parameter("blur_amount", INITIAL_BLUR)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_method(_set_blur_amount, INITIAL_BLUR, 0.0, DURATION)
	await tween.finished
	queue_free()


func _set_blur_amount(value: float) -> void:
	var material := blur_rect.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter("blur_amount", value)
