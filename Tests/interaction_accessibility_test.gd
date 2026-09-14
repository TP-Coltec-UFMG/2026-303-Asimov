extends Node2D

# Executar somente na cópia isolada; o teste não chama saves ou checkpoints.
@onready var fixture: Node2D = $Fixture
@onready var trigger: SceneTrigger = $Fixture/SceneTrigger
@onready var interaction: Area2D = $Fixture/SceneTrigger/Interectable
@onready var collision: CollisionShape2D = $Fixture/SceneTrigger/Interectable/CollisionShape2D
@onready var cue: Node2D = $Fixture/SceneTrigger/InteractionAccessibilityCue

var failures: Array[String] = []


func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--accessibility-test"):
		push_error("Execute este teste na cópia isolada com --accessibility-test.")
		get_tree().quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	var saved_mode: int = FiltroDaltonismo.modo
	var node_count := _count_nodes(fixture)
	FiltroDaltonismo.aplicar_filtro(0)
	trigger.dentro_da_area = true
	await _frames()
	_expect(not cue.visible, "Modo desativado não deve mostrar o contorno.")
	HighContrast.set_enabled(true)
	await _frames()
	_expect(cue.is_visible_in_tree(), "Alto contraste deve mostrar o contorno da interação sem filtro cromático.")
	HighContrast.set_enabled(false)
	await _frames()
	_expect(not cue.visible, "Desativar alto contraste deve esconder o contorno da interação.")
	FiltroDaltonismo.aplicar_filtro(1)
	await _frames()
	_expect(cue.is_visible_in_tree(), "O acesso próximo e ativo deve ter os quatro cantos.")
	_expect(cue.global_position.is_equal_approx(collision.global_position), "O contorno deve respeitar o deslocamento real do leitor RFID.")
	var top_left := cue.get_node("TopLeft/Line") as Line2D
	var expected_rect: Rect2 = collision.shape.get_rect().grow(0.75)
	_expect(top_left.points.size() == 3 and top_left.points[1].is_equal_approx(expected_rect.position), "Os cantos devem acompanhar o retângulo da interação, sem enquadrar o cenário.")
	for corner: Node in cue.get_children():
		_expect((corner as CanvasItem).use_parent_material, "Os cantos devem herdar o material legível em regiões escuras.")
		for line: Node in corner.get_children():
			_expect((line as CanvasItem).use_parent_material, "As linhas devem herdar o material dos cantos.")

	trigger.dentro_da_area = false
	await _frames()
	_expect(not cue.visible, "Acessos distantes não devem poluir o cenário.")
	trigger.dentro_da_area = true
	interaction.set("is_interactable", false)
	await _frames()
	_expect(not cue.visible, "Uma interação desativada não deve ser destacada.")
	interaction.set("is_interactable", true)
	interaction.hide()
	await _frames()
	_expect(not cue.visible, "Uma interação oculta não deve ser revelada.")
	interaction.show()
	trigger.hide()
	await _frames()
	_expect(not cue.visible, "Um acesso oculto não deve ser revelado.")
	trigger.show()
	collision.disabled = true
	await _frames()
	_expect(not cue.visible, "Uma colisão desativada não deve receber contorno.")
	collision.disabled = false
	fixture.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames()
	_expect(not cue.visible, "Desativar o processamento do andar deve ocultar o contorno.")
	fixture.process_mode = Node.PROCESS_MODE_PAUSABLE

	get_tree().paused = true
	FiltroDaltonismo.aplicar_filtro(0)
	await _frames()
	_expect(not cue.visible, "Desativar o auxílio pelo menu de pausa deve funcionar.")
	FiltroDaltonismo.aplicar_filtro(3)
	await _frames()
	_expect(cue.is_visible_in_tree(), "Ativar o auxílio durante a pausa deve funcionar.")
	interaction.set("is_interactable", false)
	await _frames()
	_expect(not cue.visible, "O estado da interação deve continuar sendo respeitado durante a pausa.")
	interaction.set("is_interactable", true)
	get_tree().paused = false

	collision.position += Vector2(13, -5)
	await _frames()
	_expect(cue.global_position.is_equal_approx(collision.global_position), "Mover o leitor deve mover o contorno com ele.")
	_expect(_count_nodes(fixture) == node_count, "Trocar o auxílio não deve criar novos elementos de cena.")
	FiltroDaltonismo.aplicar_filtro(saved_mode)
	if failures.is_empty():
		print("PASS: interaction accessibility proximity, visibility, disabled state, paused toggles and collision geometry.")
	else:
		for failure in failures:
			push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _count_nodes(node: Node) -> int:
	var count := 1
	for child: Node in node.get_children():
		count += _count_nodes(child)
	return count
