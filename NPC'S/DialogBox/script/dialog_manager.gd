extends CanvasLayer

signal dialog_started(dialog_id: String)
signal dialog_finished(dialog_id: String)
signal dialog_line_started(dialog_id: String, index: int)

var dialog_box = null
var is_showing_dialog: bool = false
var current_dialog_id: String = ""
var suspended_dialogs: Array[Dictionary] = []
var input_blocked: bool = false
var current_sequence_id: String = ""
var current_line_data: Dictionary = {}


func _input(event: InputEvent) -> void:
	if input_blocked or not is_showing_dialog or dialog_box == null:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		dialog_box.avancar()

func start_catalog_dialog(sequence_id: String, dialog_id: String = "", start_index: int = 0) -> void:
	start_dialog(DialogueCatalog.texts(sequence_id), dialog_id, start_index, sequence_id)


func start_dialog(texts: Array[String], dialog_id: String = "", start_index: int = 0, sequence_id: String = "") -> void:
	if is_showing_dialog:
		return
	if texts.is_empty():
		return

	var caixa_disponivel := _obter_caixa_disponivel()
	if caixa_disponivel != null:
		dialog_box = caixa_disponivel
		current_dialog_id = dialog_id
		current_sequence_id = sequence_id
		is_showing_dialog = true

		dialog_box.textos = texts
		dialog_box.indice_atual = clampi(start_index, 0, maxi(texts.size() - 1, 0))

		dialog_box.iniciar_exibicao()
		dialog_started.emit(current_dialog_id)
	else:
		push_error("Não há uma caixa de diálogo disponível na cena do DialogManager.")


func _obter_caixa_disponivel() -> MarginContainer:
	for caixa: Node in get_children():
		if caixa is MarginContainer and not bool(caixa.em_uso):
			return caixa as MarginContainer
	return null


func limpar_dialogos() -> void:
	for caixa: Node in get_children():
		if caixa is MarginContainer:
			caixa.cancelar_exibicao()
	dialog_box = null
	is_showing_dialog = false
	current_dialog_id = ""
	current_sequence_id = ""
	current_line_data = {}
	suspended_dialogs.clear()
	input_blocked = false


func interrupt_with_dialog(texts: Array[String], dialog_id: String, auto_resume: bool = true) -> void:
	suspend_current_dialog(auto_resume)
	start_dialog(texts, dialog_id)


func interrupt_with_catalog_dialog(sequence_id: String, dialog_id: String, auto_resume: bool = true) -> void:
	suspend_current_dialog(auto_resume)
	start_catalog_dialog(sequence_id, dialog_id)


func suspend_current_dialog(auto_resume: bool = false) -> void:
	if not is_showing_dialog or dialog_box == null:
		return
	dialog_box.hide()
	suspended_dialogs.append({"box": dialog_box, "dialog_id": current_dialog_id, "auto_resume": auto_resume, "sequence_id": current_sequence_id, "line_data": current_line_data.duplicate(true)})
	dialog_box = null
	current_dialog_id = ""
	current_sequence_id = ""
	current_line_data = {}
	is_showing_dialog = false


func _on_dialog_line_started(index: int) -> void:
	current_line_data = {}
	if not current_sequence_id.is_empty():
		var lines := DialogueCatalog.entries(current_sequence_id)
		if index >= 0 and index < lines.size():
			current_line_data = lines[index]
	dialog_line_started.emit(current_dialog_id, index)


func resume_suspended_dialog(expected_dialog_id: String = "") -> bool:
	if is_showing_dialog or suspended_dialogs.is_empty():
		return false
	if not expected_dialog_id.is_empty() and str(suspended_dialogs.back().get("dialog_id", "")) != expected_dialog_id:
		return false
	var previous: Dictionary = suspended_dialogs.pop_back()
	var previous_box: Node = previous.get("box")
	if not is_instance_valid(previous_box) or not previous_box.is_inside_tree():
		return false
	dialog_box = previous_box
	current_dialog_id = str(previous.get("dialog_id", ""))
	current_sequence_id = str(previous.get("sequence_id", ""))
	current_line_data = previous.get("line_data", {}).duplicate(true)
	is_showing_dialog = true
	dialog_box.show()
	return true

func _on_dialog_finished() -> void:
	var finished_dialog_id := current_dialog_id
	is_showing_dialog = false
	current_dialog_id = ""
	current_sequence_id = ""
	current_line_data = {}

	if dialog_box:
		dialog_box = null

	dialog_finished.emit(finished_dialog_id)
	if not is_showing_dialog and not suspended_dialogs.is_empty() and bool(suspended_dialogs.back().get("auto_resume", true)):
		resume_suspended_dialog()
