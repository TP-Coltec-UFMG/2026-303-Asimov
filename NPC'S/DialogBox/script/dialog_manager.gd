extends CanvasLayer

signal dialog_started(dialog_id: String)
signal dialog_finished(dialog_id: String)
signal dialog_line_started(dialog_id: String, index: int)

@export var dialog_scene: PackedScene

var dialog_box = null
var is_showing_dialog: bool = false
var current_dialog_id: String = ""
var suspended_dialogs: Array[Dictionary] = []
var input_blocked: bool = false


func _input(event: InputEvent) -> void:
	if input_blocked or not is_showing_dialog or dialog_box == null:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		dialog_box.advance()

func start_dialog(texts: Array[String], dialog_id: String = "", start_index: int = 0) -> void:
	if is_showing_dialog:
		return

	if dialog_scene:
		dialog_box = dialog_scene.instantiate()
		current_dialog_id = dialog_id
		is_showing_dialog = true

		add_child(dialog_box)

		dialog_box.texts_to_display = texts
		dialog_box.current_index = clampi(start_index, 0, maxi(texts.size() - 1, 0))

		dialog_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		dialog_box.offset_left = 16
		dialog_box.offset_right = -16
		dialog_box.offset_top = -120 
		dialog_box.offset_bottom = -16

		dialog_box.dialog_finished.connect(_on_dialog_finished)
		dialog_box.line_started.connect(_on_dialog_line_started)
		dialog_box.show_text()
		dialog_started.emit(current_dialog_id)


func interrupt_with_dialog(texts: Array[String], dialog_id: String, auto_resume: bool = true) -> void:
	if is_showing_dialog and dialog_box != null:
		dialog_box.hide()
		suspended_dialogs.append({"box": dialog_box, "dialog_id": current_dialog_id, "auto_resume": auto_resume})
		dialog_box = null
		current_dialog_id = ""
		is_showing_dialog = false
	start_dialog(texts, dialog_id)


func _on_dialog_line_started(index: int) -> void:
	dialog_line_started.emit(current_dialog_id, index)


func resume_suspended_dialog() -> bool:
	if is_showing_dialog or suspended_dialogs.is_empty():
		return false
	var previous: Dictionary = suspended_dialogs.pop_back()
	var previous_box: Node = previous.get("box")
	if not is_instance_valid(previous_box) or not previous_box.is_inside_tree():
		return false
	dialog_box = previous_box
	current_dialog_id = str(previous.get("dialog_id", ""))
	is_showing_dialog = true
	dialog_box.show()
	return true

func _on_dialog_finished() -> void:
	var finished_dialog_id := current_dialog_id
	is_showing_dialog = false
	current_dialog_id = ""

	if dialog_box:
		dialog_box = null

	dialog_finished.emit(finished_dialog_id)
	if not is_showing_dialog and not suspended_dialogs.is_empty() and bool(suspended_dialogs.back().get("auto_resume", true)):
		resume_suspended_dialog()
