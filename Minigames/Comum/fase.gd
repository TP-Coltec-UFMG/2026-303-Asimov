extends Node2D

@export_enum("Vigilância", "Deslizar") var jogo: int = 0
@export_range(0, 3) var fase: int = 0
@export var nome_fase: String = "Primeiro acesso"
@export_multiline var dica: String = "Alcance o terminal sem entrar no cone vermelho."

var estado: String = "jogando"
var tempo: float = 0.0
@onready var hud: Control = $Interface/HUD
@onready var modal: Control = $Interface/HUD/Modal
@onready var contador: Label = $Interface/HUD/Contador
@onready var sons: SonsAsimov = $Sons
@onready var cronometro: Control = $Interface/HUD/Cronometro
@onready var jogador: CharacterBody2D = $Arena/Jogador
@onready var objetivo: Area2D = $Arena/Objetivo
@onready var botao_continuar: Button = $Interface/HUD/Modal/Continuar
@onready var botao_reiniciar: Button = $Interface/HUD/Modal/Reiniciar
@onready var botao_desfazer: Button = $Interface/HUD/Modal/Desfazer
@onready var botao_sair: Button = $Interface/HUD/Modal/Sair

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.get_node("TipoJogo").text = "VIGILÂNCIA" if jogo == 0 else "DESLIZAR"
	hud.get_node("NomeFase").text = nome_fase
	hud.get_node("NumeroFase").text = "%02d" % (fase + 1)
	hud.get_node("Terminal").visible = jogo == 0
	hud.get_node("Engrenagem").visible = jogo == 1
	hud.get_node("Instrucao").text = (
		"WASD / SETAS: mover    |    Evite os cones vermelhos."
		if jogo == 0 else "WASD / SETAS: direção    ESPAÇO: deslizar    Z: desfazer"
	)

func _unhandled_key_input(evento: InputEvent) -> void:
	if not evento is InputEventKey or not evento.pressed or evento.echo:
		return
	if evento.physical_keycode == KEY_ESCAPE:
		if estado == "pausado":
			retomar()
		elif estado == "jogando":
			pausar()
	elif evento.physical_keycode == KEY_R:
		reiniciar()
	elif evento.physical_keycode == KEY_Z and estado == "falhou" and jogo == 1:
		desfazer_falha()

func limpar_modal() -> void:
	var foco := get_viewport().gui_get_focus_owner()
	if foco != null and modal.is_ancestor_of(foco):
		foco.release_focus()
	modal.hide()

func abrir_modal(titulo: String, mensagem: String, cor: Color) -> Control:
	limpar_modal()
	modal.get_node("Titulo").text = titulo
	modal.get_node("Titulo").add_theme_color_override("font_color", cor)
	modal.get_node("Mensagem").text = mensagem
	var estilo := (modal.get_node("Painel") as Panel).get_theme_stylebox("panel") as StyleBoxFlat
	estilo.border_color = cor
	for botao: Button in [botao_continuar, botao_reiniciar, botao_desfazer, botao_sair]:
		botao.hide()
	modal.show()
	return modal

func pausar() -> void:
	if estado != "jogando":
		return
	estado = "pausado"
	get_tree().paused = true
	abrir_modal("SISTEMA EM PAUSA", "", VisualAsimov.CIANO)
	_exibir_botao(botao_continuar, "CONTINUAR", Rect2(110, 154, 123, 22))
	_exibir_botao(botao_reiniciar, "REINICIAR", Rect2(248, 154, 123, 22))
	_exibir_botao(botao_sair, Progresso.texto_saida(), Rect2(110, 186, 261, 21))
	botao_continuar.grab_focus()

func _exibir_botao(botao: Button, texto: String, retangulo: Rect2) -> void:
	botao.text = texto
	botao.position = retangulo.position
	botao.size = retangulo.size
	botao.show()

func retomar() -> void:
	if estado != "pausado":
		return
	limpar_modal()
	estado = "jogando"
	get_tree().paused = false

func reiniciar() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _sair() -> void:
	Progresso.menu()

func _ao_ser_capturado() -> void:
	falhar("SINAL DETECTADO", "Espere o sensor virar ou use uma cobertura.")

func _ao_sair_da_arena() -> void:
	falhar("FORA DO SISTEMA", "Desfaça o movimento ou tente outra rota.")

func _ao_iniciar_movimento() -> void:
	sons.tocar("passo")

func _ao_parar_movimento() -> void:
	sons.tocar("toque")

func falhar(titulo: String, mensagem: String) -> void:
	if estado != "jogando":
		return
	estado = "falhou"
	sons.tocar("erro")
	$Arena.process_mode = Node.PROCESS_MODE_DISABLED
	abrir_modal(titulo, mensagem, VisualAsimov.VERMELHO)
	_exibir_botao(botao_reiniciar, "TENTAR DE NOVO", Rect2(110, 154, 261, 22))
	if jogo == 1:
		_exibir_botao(botao_desfazer, "DESFAZER [Z]", Rect2(110, 185, 123, 21))
	_exibir_botao(botao_sair, Progresso.texto_saida(), Rect2(248 if jogo == 1 else 110, 185, 123 if jogo == 1 else 261, 21))
	botao_reiniciar.grab_focus()

func desfazer_falha() -> void:
	if jogador.historico.is_empty():
		return
	jogador.desfazer()
	$Arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	limpar_modal()
	estado = "jogando"

func vencer() -> void:
	if estado != "jogando":
		return
	estado = "venceu"
	cronometro.call("pausar_timer")
	jogador.habilitado = false
	for sensor in $Arena.get_children():
		if sensor.is_in_group("sensores"):
			sensor.set_physics_process(false)
	Progresso.concluir(jogo, fase)
	sons.tocar("ok")
	await get_tree().create_timer(0.45).timeout
	if fase < 3:
		Progresso.abrir(jogo, fase + 1)
	else:
		abrir_modal("ACESSO LIBERADO", "Acesso à sala do chefe concedido", VisualAsimov.VERDE)
		_exibir_botao(botao_sair, Progresso.texto_saida(), Rect2(110, 154, 261, 22))
		botao_sair.grab_focus()
