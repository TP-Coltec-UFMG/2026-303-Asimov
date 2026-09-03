extends CanvasLayer

@export var dialog_scene: PackedScene

var dialog_box = null
var is_showing_dialog: bool = false

func start_dialog(texts: Array[String]):
	if is_showing_dialog:
		return

	if dialog_scene:
		dialog_box = dialog_scene.instantiate()

		add_child(dialog_box)

		dialog_box.texts_to_display = texts

		dialog_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		dialog_box.offset_left = 16
		dialog_box.offset_right = -16
		dialog_box.offset_top = -120 
		dialog_box.offset_bottom = -16

		dialog_box.show_text()

		is_showing_dialog = true

		dialog_box.dialog_finished.connect(_on_dialog_finished)

func _on_dialog_finished():
	is_showing_dialog = false

	if dialog_box:
		dialog_box = null
