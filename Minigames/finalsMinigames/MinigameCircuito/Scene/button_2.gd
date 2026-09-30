extends Button

var destaque_ativo: bool = false
var tween_destaque: Tween
var escala_original: Vector2


func _ready() -> void:
	escala_original = scale


func ativar_destaque() -> void:
	if destaque_ativo:
		return

	destaque_ativo = true

	if tween_destaque:
		tween_destaque.kill()

	scale = escala_original

	tween_destaque = create_tween()
	tween_destaque.set_loops()

	tween_destaque.tween_property(
		self,
		"scale",
		escala_original * 1.12,
		0.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween_destaque.tween_property(
		self,
		"scale",
		escala_original,
		0.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func desativar_destaque() -> void:
	if not destaque_ativo:
		return

	destaque_ativo = false

	if tween_destaque:
		tween_destaque.kill()
		tween_destaque = null

	scale = escala_original
