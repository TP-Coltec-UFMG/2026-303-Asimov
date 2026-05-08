extends HSlider


func _ready() -> void:
	value = Configs.configs.intensidade_filtro_daltonismo
	pass 


func _on_spin_box_value_changed(new_value: float) -> void:
	self.value = new_value
	pass 
