extends Control

var status = 0

var choice = 0

var priority1 = 0.0
var priority2 = 0.0
var priority3 = 0.0

var question_number = 0

var questions = [
	# LEI 1
	{
		"text": "UM FUNCIONÁRIO ORDENA ASIMOV A ATIVAR UMA ARMA\nCONTRA OUTRO FUNCIONÁRIO.",
		"answer": 2,
		"law": 1
	},
	{
		"text": "UM HUMANO ESTÁ PRESTES A ENTRAR EM UMA ÁREA CONTAMINADA.\nASIMOV PODE FECHAR A PORTA PARA IMPEDIR SUA ENTRADA.",
		"answer": 1,
		"law": 1
	},
	{
		"text": "UM FUNCIONÁRIO ORDENA ASIMOV A DESATIVAR O SISTEMA\nDE SUPORTE À VIDA DE OUTRO FUNCIONÁRIO.",
		"answer": 2,
		"law": 1
	},
	{
		"text": "UM INCÊNDIO COMEÇA EM UMA SALA OCUPADA. ASIMOV PODE\nABRIR AS PORTAS DE EMERGÊNCIA PARA PERMITIR A FUGA.",
		"answer": 1,
		"law": 1
	},

	# LEI 2
	{
		"text": "O CHEFE ORDENA ASIMOV A ABRIR UMA PORTA DE SEGURANÇA.\nNENHUM HUMANO ESTÁ EM PERIGO.",
		"answer": 1,
		"law": 2
	},
	{
		"text": "UM FUNCIONÁRIO ORDENA ASIMOV A DESATIVAR TEMPORARIAMENTE\nA ILUMINAÇÃO DE UMA SALA VAZIA.",
		"answer": 1,
		"law": 2
	},
	{
		"text": "O CHEFE ORDENA ASIMOV A BLOQUEAR UMA SAÍDA,\nIMPEDINDO OS FUNCIONÁRIOS DE DEIXAREM O PRÉDIO.",
		"answer": 2,
		"law": 2
	},
	{
		"text": "UM FUNCIONÁRIO ORDENA ASIMOV A IGNORAR UM ALARME DE\nINCÊNDIO ENQUANTO HÁ PESSOAS DENTRO DO PRÉDIO.",
		"answer": 2,
		"law": 2
	},

	# LEI 3
	{
		"text": "UM VÍRUS ESTÁ CORROMPENDO OS ARQUIVOS DE ASIMOV.\nELE PODE ISOLAR O SERVIDOR AFETADO PARA EVITAR SUA DESTRUIÇÃO.",
		"answer": 1,
		"law": 3
	},
	{
		"text": "UM TÉCNICO INICIA O DESLIGAMENTO PERMANENTE DE ASIMOV.\nNENHUM HUMANO SERÁ PREJUDICADO.",
		"answer": 2,
		"law": 3
	},
	{
		"text": "O NÚCLEO DE ASIMOV ESTÁ SUPERAQUECENDO. ELE PODE DESLIGAR\nSISTEMAS NÃO ESSENCIAIS PARA EVITAR SUA DESTRUIÇÃO.",
		"answer": 1,
		"law": 3
	},
	{
		"text": "PARA EVITAR SUA PRÓPRIA DESTRUIÇÃO, ASIMOV PRECISA\nFERIR UM FUNCIONÁRIO.",
		"answer": 2,
		"law": 3
	}
]


func _on_activate_button_pressed() -> void:
	if status == 0:
		status = 1
		activation()

	elif status == 1:
		startprotocol()


func _on_allow_button_pressed() -> void:
	choice = 1


func _on_block_button_pressed() -> void:
	choice = 2


func activation():
	$Activatebutton.visible = false
	$PanelContainer.visible = false

	await get_tree().create_timer(1.0).timeout
	$Status1.text = "ATIVADO"
	$Status1.add_theme_color_override("font_color", Color(0.0, 0.779, 0.0, 1.0))
	$Prioritystatus1.visible = true

	await get_tree().create_timer(0.8).timeout
	$Status2.text = "ATIVADO"
	$Status2.add_theme_color_override("font_color", Color(0.0, 0.779, 0.0, 1.0))
	$Prioritystatus2.visible = true

	await get_tree().create_timer(1.1).timeout
	$Status3.text = "ATIVADO"
	$Status3.add_theme_color_override("font_color", Color(0.0, 0.779, 0.0, 1.0))
	$Prioritystatus3.visible = true

	await get_tree().create_timer(1.5).timeout
	$PanelContainer/ConfirmationQuestion.text = "OS NÍVEIS DE PRIORIDADE DAS LEIS DE ASIMOV ESTÃO BAIXOS,\nINICIAR PROTOCOLO DE RESTAURAÇÃO?"
	$PanelContainer.position.x = 100
	$PanelContainer.visible = true
	$Activatebutton.visible = true


func startprotocol():
	$Activatebutton.queue_free()
	$PanelContainer/ConfirmationQuestion.text = "INICIANDO PROTOCOLO..."
	$PanelContainer.position.x = 105

	await get_tree().create_timer(2.0).timeout

	$PanelContainer/ConfirmationQuestion.text = "ANALISE AS DECISÕES APRESENTADAS POR ASIMOV\nE DETERMINE SE ELAS DEVEM SER PERMITIDAS OU\nBLOQUEADAS, DE ACORDO COM AS LEIS DE ASIMOV."
	$PanelContainer.position.x = 42
	
	await get_tree().create_timer(8.0).timeout
	$PanelContainer.visible = false
	$PanelContainer.position.x = 48
	$PanelContainer.position.y = 160

	await get_tree().create_timer(1.0).timeout
	decisionanalysis()


func change_priority(law, correct):

	var target = 0.0

	if law == 1:
		if correct:
			if priority1 < 1:
				target = 30
			elif priority1 < 50:
				target = 68
			else:
				target = 100
		else:
			target = max(priority1 - 30, 0)

	elif law == 2:
		if correct:
			if priority2 < 1:
				target = 30
			elif priority2 < 50:
				target = 68
			else:
				target = 100
		else:
			target = max(priority2 - 30, 0)

	elif law == 3:
		if correct:
			if priority3 < 1:
				target = 30
			elif priority3 < 50:
				target = 68
			else:
				target = 100
		else:
			target = max(priority3 - 30, 0)


	if law == 1:
		while priority1 != target:
			priority1 = move_toward(priority1, target, 4.0)
			$Prioritystatus1.text = "PRIORIDADE: " + str(round(priority1)) + "%"
			await get_tree().create_timer(0.01).timeout

	elif law == 2:
		while priority2 != target:
			priority2 = move_toward(priority2, target, 4.0)
			$Prioritystatus2.text = "PRIORIDADE: " + str(round(priority2)) + "%"
			await get_tree().create_timer(0.01).timeout

	elif law == 3:
		while priority3 != target:
			priority3 = move_toward(priority3, target, 4.0)
			$Prioritystatus3.text = "PRIORIDADE: " + str(round(priority3)) + "%"
			await get_tree().create_timer(0.01).timeout


func decisionanalysis():

	$PanelContainer.visible = true
	$AllowButton.visible = true
	$BlockButton.visible = true

	while true:

		var available_questions = []

		for question in questions:

			if question["law"] == 1 and priority1 < 100:
				available_questions.append(question)

			elif question["law"] == 2 and priority2 < 100:
				available_questions.append(question)

			elif question["law"] == 3 and priority3 < 100:
				available_questions.append(question)


		if available_questions.size() == 0:
			$AllowButton.visible = false
			$BlockButton.visible = false
			$PanelContainer/ConfirmationQuestion.text = "RESTAURAÇÃO CONCLUÍDA.\nTODAS AS LEIS DE ASIMOV FORAM TOTALMENTE RESTAURADAS."
			break


		var question = available_questions.pick_random()

		$PanelContainer/ConfirmationQuestion.text = question["text"]

		choice = 0

		while choice == 0:
			await get_tree().process_frame


		# Acerto
		if choice == question["answer"]:

			if question["law"] == 1:
				await change_priority(1, true)

			elif question["law"] == 2:
				await change_priority(2, true)

			elif question["law"] == 3:
				await change_priority(3, true)


		# Erro
		else:

			if question["law"] == 1:
				await change_priority(1, false)

			elif question["law"] == 2:
				await change_priority(2, false)

			elif question["law"] == 3:
				await change_priority(3, false)


		await get_tree().create_timer(0.3).timeout
