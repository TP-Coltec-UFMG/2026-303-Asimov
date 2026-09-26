extends Panel

@onready var label: Label = $Label2

@export var margem_horizontal: float = 10.0
@export var margem_vertical: float = 10.0


func _ready() -> void:
	

	await get_tree().process_frame
	
	_atualizar_tamanho()
	

	if not label.resized.is_connected(_on_label_resized):
		label.resized.connect(_on_label_resized)


func _process(_delta: float) -> void:

	_atualizar_tamanho()


func _on_label_resized() -> void:
	_atualizar_tamanho()


func _atualizar_tamanho() -> void:
	
	if not is_instance_valid(label):
		return
	
	

	
	var tamanho_label: Vector2 = label.size
	
	

	
	var largura: float = tamanho_label.x
	largura += margem_horizontal
	
	

	
	var altura: float = label.position.y + tamanho_label.y
	altura += margem_vertical
	
	

	
	var novo_tamanho := Vector2(
		largura,
		altura
	)
	
	
	if size != novo_tamanho:
		size = novo_tamanho
