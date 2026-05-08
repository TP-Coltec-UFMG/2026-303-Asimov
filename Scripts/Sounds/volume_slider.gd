extends HSlider

@export var bus_name: String
var bus_index: int

func _ready() -> void:
	if bus_name == "ldt":
		value = Configs.configs.volume_leitor
	else:
		bus_index = AudioServer.get_bus_index(bus_name)
		value_changed.connect(_on_value_changed)
		
		value = db_to_linear(
			AudioServer.get_bus_volume_db(bus_index)
		)
		
func _on_value_changed(new_value: float) -> void:
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
	elif bus_name == "sfx":
		Configs._change_volume_sfx(new_value)
