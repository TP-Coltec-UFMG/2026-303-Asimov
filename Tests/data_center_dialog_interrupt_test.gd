extends Node

var finished_ids: Array[String] = []
var started_lines: Array[String] = []
var failures: Array[String] = []


func _ready() -> void:
	DialogManager.dialog_finished.connect(_on_dialog_finished)
	DialogManager.dialog_line_started.connect(_on_line_started)
	_run.call_deferred()


func _run() -> void:
	DialogManager.start_dialog(["Primeira fala", "Segunda fala"], "original")
	await get_tree().process_frame
	var original_box: MarginContainer = DialogManager.dialog_box as MarginContainer
	original_box.set("current_index", 1)
	original_box.call("show_text")
	DialogManager.interrupt_with_dialog(["Queda de energia"], "energia")
	_expect(DialogManager.current_dialog_id == "energia", "A fala da queda deve assumir o foco.")
	_expect(not original_box.visible, "A fala interrompida deve ficar oculta.")
	DialogManager.dialog_box.call("_close_dialog")
	await get_tree().create_timer(1.0).timeout
	_expect(finished_ids == ["energia"], "A interrupção deve concluir somente a fala da energia.")
	_expect(DialogManager.current_dialog_id == "original", "A conversa original deve voltar.")
	_expect(DialogManager.dialog_box == original_box, "A conversa deve manter o mesmo balão.")
	_expect(int(original_box.get("current_index")) == 1, "A conversa deve manter a mesma fala.")
	_expect(original_box.visible, "A conversa retomada deve ficar visível.")
	original_box.call("_close_dialog")
	await get_tree().create_timer(1.0).timeout
	_expect(finished_ids == ["energia", "original"], "Cada conversa deve terminar uma única vez.")
	DialogManager.start_dialog(["Inicio", "Continuacao"], "adiado")
	await get_tree().process_frame
	var delayed_box: MarginContainer = DialogManager.dialog_box as MarginContainer
	delayed_box.set("current_index", 1)
	delayed_box.call("show_text")
	_expect(started_lines.has("adiado:1"), "A segunda fala deve emitir o marco da conversa.")
	DialogManager.interrupt_with_dialog(["Energia"], "energia_adiada", false)
	DialogManager.dialog_box.call("_close_dialog")
	await get_tree().create_timer(1.0).timeout
	_expect(not DialogManager.is_showing_dialog, "A conversa deve aguardar o reparo.")
	_expect(DialogManager.suspended_dialogs.size() == 1, "A fala interrompida deve permanecer guardada.")
	_expect(DialogManager.resume_suspended_dialog(), "A conversa deve poder ser retomada depois.")
	_expect(DialogManager.dialog_box == delayed_box and int(delayed_box.get("current_index")) == 1, "A fala deve voltar no mesmo ponto.")
	delayed_box.call("_close_dialog")
	await get_tree().create_timer(1.0).timeout
	_expect(finished_ids == ["energia", "original", "energia_adiada", "adiado"], "Cada etapa deve terminar uma vez.")
	DialogManager.start_dialog(["Primeira", "Fala salva"], "restaurado", 1)
	_expect(started_lines.has("restaurado:1"), "Um save deve recriar a conversa na fala registrada.")
	DialogManager.dialog_box.call("_close_dialog")
	await get_tree().create_timer(1.0).timeout
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: interrupção e retomada do diálogo no mesmo ponto.")
	get_tree().quit(0 if failures.is_empty() else 1)


func _on_dialog_finished(dialog_id: String) -> void:
	finished_ids.append(dialog_id)


func _on_line_started(dialog_id: String, index: int) -> void:
	started_lines.append("%s:%d" % [dialog_id, index])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
