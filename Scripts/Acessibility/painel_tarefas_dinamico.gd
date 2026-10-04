extends CheckBox


func _ready() -> void:
	set_pressed_no_signal(
		bool(Configs.configs.get("painel_tarefas_dinamico", true))
	)


func _on_toggled(toggled_on: bool) -> void:
	Configs._change_painel_tarefas_dinamico(toggled_on)
	SaveLoad._save()
	get_tree().call_group(&"task_panels", &"aplicar_configuracao_painel_dinamico")
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(
			"Painel de tarefas dinâmico ativado"
			if toggled_on
			else "Painel de tarefas dinâmico desativado"
		)


func _on_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto("Painel de tarefas dinâmico")
