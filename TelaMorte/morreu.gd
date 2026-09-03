extends Control
@onready var button_renascer: AnimatedButton = $Renascer
@onready var label_renascer: Label = $Renascer/Label
@onready var label: Label = $Label

@onready var voltar_menu: AnimatedButton = $Voltar_menu
@onready var label_voltar_menu: Label = $Voltar_menu/Label


@onready var reiniciar: AnimatedButton = $Reiniciar
@onready var label_reiniciar: Label = $Reiniciar/Label

@onready var transition: AnimatedSprite2D = $Transition

@onready var confirmacao_reiniciar: Control = $Confirmacao_reiniciar



func _on_renascer_mouse_entered() -> void:
	label_renascer.label_settings.font_color = Color.WHITE
	label_renascer.label_settings.outline_color = Color.BLACK


func _on_renascer_mouse_exited() -> void:
	label_renascer.label_settings.font_color = Color.BLACK
	label_renascer.label_settings.outline_color = Color.WHITE


func _on_voltar_menu_mouse_entered() -> void:
	label_voltar_menu.label_settings.font_color = Color.WHITE
	label_voltar_menu.label_settings.outline_color = Color.BLACK


func _on_voltar_menu_mouse_exited() -> void:
	label_voltar_menu.label_settings.font_color = Color.BLACK
	label_voltar_menu.label_settings.outline_color = Color.WHITE

func _on_reiniciar_mouse_entered() -> void:
	label_reiniciar.label_settings.font_color = Color.RED
	label_reiniciar.label_settings.outline_color = Color.WHITE

func _on_reiniciar_mouse_exited() -> void:
	label_reiniciar.label_settings.font_color = Color.BLACK
	label_reiniciar.label_settings.outline_color = Color.WHITE


func _on_renascer_pressed() -> void:
	transition.show()
	transition.play("default")

	await transition.animation_finished

	get_tree().paused = false
	SaveGame.load_last_checkpoint()
	

func _on_voltar_menu_pressed() -> void:
	transition.show()
	transition.play("default")
	await transition.animation_finished
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/principal.tscn")


func _on_reiniciar_pressed() -> void:
	button_renascer.hide()
	voltar_menu.hide()
	label.hide()
	reiniciar.hide()
	confirmacao_reiniciar.show()


func _on_sim_pressed() -> void:
	SaveGame.reset_progress()


func _on_nao_pressed() -> void:
	button_renascer.show()
	voltar_menu.show()
	label.show()
	reiniciar.show()
	confirmacao_reiniciar.hide()
