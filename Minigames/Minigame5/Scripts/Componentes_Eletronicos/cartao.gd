extends Area2D

const ID_CARTAO = preload("res://Minigames/Minigame5/Scripts/id_cartao.gd")
const DURACAO_VOLTA: float = 0.25

var segurando: bool = false
var posicao_inicial: Vector2 = Vector2.ZERO
var voltando: bool = false
var id: int = 0
var acesso: String = "FORTE"
var _deslocamento_arraste: Vector2 = Vector2.ZERO
var _tween_volta: Tween


func _ready() -> void:
	add_to_group("cartao")
	input_pickable = true
	posicao_inicial = global_position
	visibility_changed.connect(_on_visibility_changed)
	var notebook := get_tree().get_first_node_in_group("note")
	if notebook != null:
		_atualizar_dados(notebook.dados_alterados)
		notebook.dados_atualizados.connect(_atualizar_dados)


func _atualizar_dados(dados: Dictionary) -> void:
	id = ID_CARTAO.interpretar(str(dados.get("id", "")))
	acesso = str(dados.get("acesso", "FORTE"))


func _process(_delta: float) -> void:
	if segurando and not voltando and is_visible_in_tree():
		global_position = get_global_mouse_position() + _deslocamento_arraste


func cancelar_arraste() -> void:
	segurando = false


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		cancelar_arraste()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancelar_arraste()


func _input(event: InputEvent) -> void:
	# O botão pode ser solto fora da colisão, sobre a UI ou após um movimento rápido.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		cancelar_arraste()


func voltar_para_posicao_inicial() -> void:
	_mover_para(posicao_inicial)


func retirar_do_leitor() -> void:
	_mover_para(global_position + Vector2(0, 50))


func _mover_para(destino: Vector2) -> void:
	if is_instance_valid(_tween_volta):
		_tween_volta.kill()
	voltando = true
	cancelar_arraste()
	_tween_volta = create_tween()
	_tween_volta.tween_property(self, "global_position", destino, DURACAO_VOLTA).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween_volta.finished.connect(func(): voltando = false)


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not event.pressed:
		cancelar_arraste()
		return
	if voltando or not is_visible_in_tree() or not can_process():
		return
	segurando = true
	_deslocamento_arraste = global_position - get_global_mouse_position()
	get_viewport().set_input_as_handled()
