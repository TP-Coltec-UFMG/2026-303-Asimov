extends Panel


@onready var label: Label = $Label
@onready var botao: Button = $Button
@onready var panel_superior: Panel = $Panel


@export var margem_horizontal: float = 15.0
@export var margem_vertical: float = 10.0
@export var espacamento: float = 10.0

# Configurações da pulsação do botão
@export var pulso_escala_maxima: float = 1.05
@export var pulso_escala_minima: float = 0.95
@export var pulso_duracao: float = 0.5

var _tween_pulso: Tween


func _ready() -> void:
	

	await get_tree().process_frame
	
	_atualizar_tamanho()
	

	if not label.resized.is_connected(_on_label_resized):
		label.resized.connect(_on_label_resized)
	

	if not botao.visibility_changed.is_connected(_on_button_visibility_changed):
		botao.visibility_changed.connect(_on_button_visibility_changed)
	
	
	# Caso o botão já esteja visível quando a cena começa
	_atualizar_pulso()


func _process(_delta: float) -> void:

	_atualizar_tamanho()


func _on_label_resized() -> void:
	_atualizar_tamanho()


func _on_button_visibility_changed() -> void:
	_atualizar_tamanho()
	_atualizar_pulso()


func _atualizar_pulso() -> void:
	
	if not is_instance_valid(botao):
		return
	
	if botao.visible:
		_iniciar_pulso()
	else:
		_parar_pulso()


func _iniciar_pulso() -> void:
	
	# Evita criar vários tweens ao mesmo tempo
	if _tween_pulso != null and _tween_pulso.is_valid():
		_tween_pulso.kill()
	
	# Faz a escala crescer a partir do centro do botão
	botao.pivot_offset = botao.size / 2.0
	botao.scale = Vector2.ONE
	
	_tween_pulso = create_tween()
	_tween_pulso.set_loops()
	_tween_pulso.set_trans(Tween.TRANS_SINE)
	_tween_pulso.set_ease(Tween.EASE_IN_OUT)
	
	_tween_pulso.tween_property(
		botao,
		"scale",
		Vector2.ONE * pulso_escala_maxima,
		pulso_duracao
	)
	_tween_pulso.tween_property(
		botao,
		"scale",
		Vector2.ONE * pulso_escala_minima,
		pulso_duracao
	)


func _parar_pulso() -> void:
	
	if _tween_pulso != null and _tween_pulso.is_valid():
		_tween_pulso.kill()
	
	_tween_pulso = null
	
	if is_instance_valid(botao):
		botao.scale = Vector2.ONE


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
