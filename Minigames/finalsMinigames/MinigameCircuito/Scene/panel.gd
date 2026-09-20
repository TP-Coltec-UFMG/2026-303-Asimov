extends Panel

@onready var label: Label = $Label2

@export var margem_horizontal: float = 10.0
@export var margem_vertical: float = 10.0


func _ready() -> void:
	
	# Espera o Godot terminar de calcular o tamanho inicial da Label
	await get_tree().process_frame
	
	_atualizar_tamanho()
	
	# Atualiza quando a Label mudar de tamanho
	if not label.resized.is_connected(_on_label_resized):
		label.resized.connect(_on_label_resized)


func _process(_delta: float) -> void:
	# Mantém o Panel sincronizado caso o texto da Label
	# mude sem disparar o sinal de resize imediatamente.
	_atualizar_tamanho()


func _on_label_resized() -> void:
	_atualizar_tamanho()


func _atualizar_tamanho() -> void:
	
	if not is_instance_valid(label):
		return
	
	
	# ========================================================
	# TAMANHO REAL DA LABEL
	# ========================================================
	
	var tamanho_label: Vector2 = label.size
	
	
	# ========================================================
	# LARGURA
	# ========================================================
	
	var largura: float = tamanho_label.x
	largura += margem_horizontal
	
	
	# ========================================================
	# ALTURA
	# ========================================================
	
	var altura: float = label.position.y + tamanho_label.y
	altura += margem_vertical
	
	
	# ========================================================
	# APLICA O TAMANHO
	# ========================================================
	
	var novo_tamanho := Vector2(
		largura,
		altura
	)
	
	
	if size != novo_tamanho:
		size = novo_tamanho
