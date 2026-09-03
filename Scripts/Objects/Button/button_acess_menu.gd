extends Button
class_name AnimatedButton

@export_category("Hover")
@export var hover_scale: Vector2 = Vector2(1.1, 1.1)
@export_category("Press")
@export var press_scale: Vector2 = Vector2(0.95, 0.95)
@export var press_animation_length_1: float = 0.1
@export var press_animation_length_2: float = 0.1

var animation_tween: Tween

func _ready() -> void:
	pressed.connect(_button_press)
	resized.connect(update_pivot)
	update_pivot()

func update_pivot() -> void:
	pivot_offset = size / 2.0

func _button_press() -> void:
	if animation_tween:
		animation_tween.kill()
	animation_tween = create_tween().set_trans(Tween.TRANS_SINE)
	animation_tween.tween_property(self, "scale", press_scale, press_animation_length_1)
	animation_tween.chain().tween_property(self, "scale", hover_scale, press_animation_length_2)
