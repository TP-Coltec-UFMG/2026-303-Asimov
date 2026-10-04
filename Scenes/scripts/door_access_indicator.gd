extends Node2D

@export var deslocamento_porta: Vector2 = Vector2(0, -8)
@export var cor_liberado: Color = Color(0.2, 1.0, 0.35)
@export var cor_negado: Color = Color(1.0, 0.18, 0.12)

var liberado: bool = false
var cor_estado: Color
var transicao_estado: Tween

@onready var brilho_externo: Polygon2D = $BrilhoExterno
@onready var brilho_interno: Polygon2D = $BrilhoInterno
@onready var luz_estado: Polygon2D = $LuzEstado
@onready var sinal_liberado: Line2D = $SinalLiberado
@onready var sinal_negado: Node2D = $SinalNegado


func mostrar_estado(acesso_liberado: bool) -> void:
	var porta := get_parent() as SceneTrigger
	if porta == null or porta.eh_elevador:
		return
	var colisao := porta.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if colisao == null or colisao.shape == null:
		return
	var limites := colisao.shape.get_rect()
	position = porta.to_local(colisao.to_global(Vector2(limites.get_center().x, limites.position.y))) + deslocamento_porta
	liberado = acesso_liberado
	cor_estado = cor_liberado if liberado else cor_negado
	brilho_externo.color = Color(cor_estado, 0.08)
	brilho_interno.color = Color(cor_estado, 0.2)
	luz_estado.color = cor_estado
	sinal_liberado.visible = liberado
	sinal_negado.visible = not liberado
	if transicao_estado != null and transicao_estado.is_valid():
		transicao_estado.kill()
	modulate.a = 0.0
	show()
	transicao_estado = create_tween()
	transicao_estado.tween_property(self, "modulate:a", 1.0, 0.12)
