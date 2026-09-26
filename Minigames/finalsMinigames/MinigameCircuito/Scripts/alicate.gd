
extends Area2D



var fio_em_cima: Node2D = null
var segurando: bool = false

var total_cortes: int = 0

@onready var sprite: Sprite2D = $Sprite2D
var material_shader: ShaderMaterial


func _ready():
	
	input_pickable = true

	material_shader = sprite.material as ShaderMaterial
	desativar_destaque()


func ativar_destaque() -> void:
	sprite.material = material_shader


func desativar_destaque() -> void:
	sprite.material = null


func _process(_delta):


	if segurando:

		global_position = get_global_mouse_position()



	fio_em_cima = null

	for area in get_overlapping_areas():

		var fio = area.get_parent()

		if fio == null:
			continue

		if not fio.is_in_group("fios"):
			continue

		if not is_instance_valid(fio):
			continue

		fio_em_cima = fio

		break



func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index == MOUSE_BUTTON_LEFT:
		if not mouse_button.pressed:
			segurando = false
		elif mouse_button.position.distance_to(get_global_transform_with_canvas().origin) <= 18.0:
			segurando = true
			get_viewport().set_input_as_handled()
	elif mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed and segurando:
		cortar_fio()
		get_viewport().set_input_as_handled()


func cortar_fio():

	if fio_em_cima == null:

		pass

		return


	var fio_cortado = fio_em_cima

	total_cortes += 1

	pass



	var circuit = self.get_parent(
		
	)


	if circuit != null:

		circuit.cortar_fio(
			fio_cortado
		)



	fio_cortado.queue_free()

	fio_em_cima = null
