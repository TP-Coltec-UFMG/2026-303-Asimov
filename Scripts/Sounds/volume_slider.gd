extends HSlider

@export var bus_name: String
var bus_index: int = -1


func _ready() -> void:
	value_changed.connect(_on_value_changed)

	if bus_name == "Master":
		bus_index = AudioServer.get_bus_index("Master")
		value = Configs.configs.volume_geral
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))

	elif bus_name == "Music":
		bus_index = AudioServer.get_bus_index("Music")
		value = Configs.configs.volume_musica
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))

	elif bus_name == "sfx":
		bus_index = AudioServer.get_bus_index("sfx")
		value = Configs.configs.volume_sfx
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))

	elif bus_name == "ldt":
		value = Configs.configs.volume_leitor


func _on_value_changed(new_value: float) -> void:
	if bus_name == "ldt":
		Configs._change_volume_leitor_de_tela(new_value)
		return

	if bus_index == -1:
		return

	AudioServer.set_bus_volume_db(
		bus_index,
		linear_to_db(new_value)
	)

	if bus_name == "Master":
		Configs._change_volume_geral(new_value)
	elif bus_name == "Music":
		Configs._change_volume_musica(new_value)
	elif bus_name == "sfx":
		Configs._change_volume_sfx(new_value)
