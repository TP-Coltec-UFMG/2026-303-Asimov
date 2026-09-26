
extends Panel


@onready var label: Label = $Label
@onready var botao: Button = $Button
@onready var panel_superior: Panel = $Panel


@export var margem_horizontal: float = 15.0
@export var margem_vertical: float = 10.0
@export var espacamento: float = 10.0


func _ready() -> void:
	

	await get_tree().process_frame
	
	_atualizar_tamanho()
	

	if not label.resized.is_connected(_on_label_resized):
		label.resized.connect(_on_label_resized)
	

	if not botao.visibility_changed.is_connected(_on_button_visibility_changed):
		botao.visibility_changed.connect(_on_button_visibility_changed)


func _process(_delta: float) -> void:

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
	
	

	
	var tamanho_label: Vector2 = label.size
	
	

	
	if botao.visible:
		botao.position.y = label.position.y + tamanho_label.y + espacamento
	
	

	
	var largura: float = label.position.x + tamanho_label.x
	
	if botao.visible:
		largura = max(
			largura,
			botao.position.x + botao.size.x
		)
	
	

	
	var altura: float = label.position.y + tamanho_label.y
	
	
	if botao.visible:
		altura = max(
			altura,
			botao.position.y + botao.size.y
		)
	
	
	altura += margem_vertical
	
	

	
	var novo_tamanho := Vector2(
		largura,
		altura
	)
	
	
	if size != novo_tamanho:
		size = novo_tamanho
	
	

	
	if botao.visible:
		botao.position.x = (
			(size.x - botao.size.x) / 2.0
		)
	
	

	
	if panel_superior.visible:

		panel_superior.position.x = (
			size.x - panel_superior.size.x
		) / 2.0
