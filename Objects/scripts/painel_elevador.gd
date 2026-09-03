extends Node2D

@export var scene_trigger : SceneTrigger
@onready var bt_andar_normal: Sprite2D = $BtAndarNormal
@onready var bt_andar_01_apertado: Sprite2D = $BtAndar01Apertado
@onready var bt_andar_01_selecionado: Sprite2D = $BtAndar01Selecionado
@onready var bt_andar_02_apertado: Sprite2D = $BtAndar02Apertado
@onready var bt_andar_02_selecionado: Sprite2D = $BtAndar02Selecionado
@onready var bt_andar_03_apertado: Sprite2D = $BtAndar03Apertado
@onready var bt_andar_03_selecionado: Sprite2D = $BtAndar03Selecionado
@onready var bt_andar_04_apertado: Sprite2D = $BtAndar04Apertado
@onready var bt_andar_04_selecionado: Sprite2D = $BtAndar04Selecionado
@onready var bt_andar_05_apertado: Sprite2D = $BtAndar05Apertado
@onready var bt_andar_05_selecionado: Sprite2D = $BtAndar05Selecionado
@onready var bt_andar_06_apertado: Sprite2D = $BtAndar06Apertado
@onready var bt_andar_06_selecionado: Sprite2D = $BtAndar06Selecionado
@onready var bt_andar_porta_apertado: Sprite2D = $BtAndarPortaApertado
@onready var bt_andar_porta_selecionado: Sprite2D = $BtAndarPortaSelecionado
@onready var abrindo: AnimatedSprite2D = $Abrindo

@onready var label: Label = $Label


func resetar_sprites() -> void:
	bt_andar_01_apertado.hide()
	bt_andar_02_apertado.hide()
	bt_andar_03_apertado.hide()
	bt_andar_04_apertado.hide()
	bt_andar_05_apertado.hide()
	bt_andar_06_apertado.hide()
	bt_andar_porta_apertado.hide()
	bt_andar_01_selecionado.hide()
	bt_andar_02_selecionado.hide()
	bt_andar_03_selecionado.hide()
	bt_andar_04_selecionado.hide()
	bt_andar_05_selecionado.hide()
	bt_andar_06_selecionado.hide()
	bt_andar_porta_apertado.hide()
	abrindo.hide()
	abrindo.frame = 0
	label.hide()
	bt_andar_normal.show()
	

func animacao() -> void:
	bt_andar_normal.hide()
	abrindo.show()
	abrindo.play("default")
	await abrindo.animation_finished
	return

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func escolher_andar(andar: int) -> void:
	label.show()
	get_tree().paused = false
	scene_trigger.usar_elevador(andar)

func _on_andar_1_pressed() -> void:
	bt_andar_01_apertado.show()
	#escolher_andar(1)
	pass

func _on_andar_2_pressed() -> void:
	bt_andar_02_apertado.show()
	escolher_andar(2)
	pass

func _on_andar_3_pressed() -> void:
	bt_andar_03_apertado.show()
	escolher_andar(3)
	pass

func _on_andar_4_pressed() -> void:
	bt_andar_04_apertado.show()
	escolher_andar(4)

func _on_andar_5_pressed() -> void:
	bt_andar_05_apertado.show()
	#escolher_andar(5)
	pass

func _on_andar_6_pressed() -> void:
	bt_andar_06_apertado.show()
	escolher_andar(6)
	pass
	
func _on_fechar_pressed() -> void:
	bt_andar_porta_selecionado.show()
	escolher_andar(-2)
	pass
	


func _on_andar_1_mouse_entered() -> void:
	bt_andar_01_selecionado.show()


func _on_andar_1_mouse_exited() -> void:
	bt_andar_01_selecionado.hide()


func _on_andar_2_mouse_entered() -> void:
	bt_andar_02_selecionado.show()


func _on_andar_2_mouse_exited() -> void:
	bt_andar_02_selecionado.hide()


func _on_andar_3_mouse_entered() -> void:
	bt_andar_03_selecionado.show()


func _on_andar_3_mouse_exited() -> void:
	bt_andar_03_selecionado.hide()


func _on_andar_4_mouse_entered() -> void:
	bt_andar_04_selecionado.show()


func _on_andar_4_mouse_exited() -> void:
	bt_andar_04_selecionado.hide()


func _on_andar_5_mouse_entered() -> void:
	bt_andar_05_selecionado.show()


func _on_andar_5_mouse_exited() -> void:
	bt_andar_05_selecionado.hide()


func _on_andar_6_mouse_entered() -> void:
	bt_andar_06_selecionado.show()


func _on_andar_6_mouse_exited() -> void:
	bt_andar_06_selecionado.hide()


func _on_fechar_mouse_entered() -> void:
	bt_andar_porta_selecionado.show()


func _on_fechar_mouse_exited() -> void:
	bt_andar_porta_selecionado.hide()
