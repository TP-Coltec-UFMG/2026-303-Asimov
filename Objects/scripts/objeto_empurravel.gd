class_name ObjetoEmpurravel
extends CharacterBody2D

@export var velocidade_empurrao: float = 40.0
@export var save_id: String = "empurravel01"
@export var save_enabled: bool = true

var ultima_posicao: Vector2


func set_manipulated_outline(enabled: bool) -> void:
	for cue in find_children("*", "", true, false):
		if cue.is_in_group(&"color_accessibility_cue") and cue.has_method("set_forced_outline"):
			cue.call("set_forced_outline", enabled)


func _ready() -> void:
	add_to_group("empurravel")

	if not save_enabled:
		ultima_posicao = position
		return

	var estado_salvo = SaveGame.load_object_state(save_id)

	if estado_salvo != null:
		position.x = estado_salvo.get("position_x", position.x)
		position.y = estado_salvo.get("position_y", position.y)

	ultima_posicao = position


func _process(_delta: float) -> void:
	if not save_enabled:
		return

	if not position.is_equal_approx(ultima_posicao):
		ultima_posicao = position

		SaveGame.save_object_state(save_id, {
			"position_x": position.x,
			"position_y": position.y
		})
