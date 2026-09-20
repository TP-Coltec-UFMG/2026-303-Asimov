
extends Panel


@onready var label: Label = $Label
@onready var botao: Button = $Button
@onready var panel_superior: Panel = $Panel


@export var margem_horizontal: float = 15.0
@export var margem_vertical: float = 10.0
@export var espacamento: float = 10.0


func _ready() -> void:
	
	# Espera o Godot terminar de calcular os tamanhos iniciais
	await get_tree().process_frame
	
	_atualizar_tamanho()
	
	# Atualiza quando a Label mudar de tamanho
	if not label.resized.is_connected(_on_label_resized):
		label.resized.connect(_on_label_resized)
	
	# Atualiza quando o botão aparecer/desaparecer
	if not botao.visibility_changed.is_connected(_on_button_visibility_changed):
		botao.visibility_changed.connect(_on_button_visibility_changed)


func _process(_delta: float) -> void:
	# Mantém tudo sincronizado caso os tamanhos mudem
	_atualizar_tamanho()


func _on_label_resized() -> void:
	_atualizar_tamanho()


func _on_button_visibility_changed() -> void:
	_atualizar_tamanho()


func _atualizar_tamanho() -> void:
	
	if not is_instance_valid(label):
		return
	
	if not is_instance_valid(botao):
		return
	
	if not is_instance_valid(panel_superior):
		return
	
	
	# ========================================================
	# TAMANHO REAL DA LABEL
	# ========================================================
	
	var tamanho_label: Vector2 = label.size
	
	
	# ========================================================
	# POSIÇÃO DO BOTÃO
	# ========================================================
	
	if botao.visible:
		botao.position.y = label.position.y + tamanho_label.y + espacamento
	
	
	# ========================================================
	# LARGURA
	# ========================================================
	
	var largura: float = label.position.x + tamanho_label.x
	
	if botao.visible:
		largura = max(
			largura,
			botao.position.x + botao.size.x
		)
	
	
	# ========================================================
	# ALTURA
	# ========================================================
	
	var altura: float = label.position.y + tamanho_label.y
	
	
	if botao.visible:
		altura = max(
			altura,
			botao.position.y + botao.size.y
		)
	
	
	altura += margem_vertical
	
	
	# ========================================================
	# APLICA O TAMANHO DO PANEL PRINCIPAL
	# ========================================================
	
	var novo_tamanho := Vector2(
		largura,
		altura
	)
	
	
	if size != novo_tamanho:
		size = novo_tamanho
	
	
	# ========================================================
	# POSIÇÃO HORIZONTAL DO BOTÃO
	# ========================================================
	
	if botao.visible:
		botao.position.x = (
			(size.x - botao.size.x) / 2.0
		)
	
	
	# ========================================================
	# PANEL SUPERIOR
	# ========================================================
	
	if panel_superior.visible:
		# Apenas centraliza horizontalmente.
		# A posição Y permanece exatamente como configurada
		# no editor.
		panel_superior.position.x = (
			size.x - panel_superior.size.x
		) / 2.0
