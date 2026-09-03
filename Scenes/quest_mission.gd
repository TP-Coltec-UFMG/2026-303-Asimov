extends CanvasLayer
@onready var M2: AnimatedSprite2D = $VBoxContainer/HBoxContainer/AnimatedSprite2D
@onready var M1: AnimatedSprite2D = $VBoxContainer/HBoxContainer2/AnimatedSprite2D

var f1_acesso = true
var f2_acesso = true

var M1_feito = false
var M2_feito = false

func _ready() -> void:
	M1.frame = 0
	M2.frame = 0
	MusicController._start_som_de_fundo()
	MusicController._stop_bg_ambient()
	MusicController._set_volume_som_de_fundo(1)


func _process(delta: float) -> void:
	if not f1_acesso and not f2_acesso and not M1_feito:
		M1.play("default")
		M1_feito = true
		
	if M1_feito and M2_feito:
		await get_tree().create_timer(5).timeout
		self.hide()
		


func _on_fogo_3_fogo_apagou() -> void:
	f1_acesso = false


func _on_fogo_5_fogo_apagou() -> void:
	f2_acesso = false


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Player:
		M2.play("default")
		M2_feito = true
