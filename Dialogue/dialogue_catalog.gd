extends Node

const DATA: JSON = preload("res://Dialogue/dialogues.pt_BR.json")


func get_line(line_id: String) -> Dictionary:
	var lines: Dictionary = DATA.data.get("lines", {})
	if not lines.has(line_id):
		push_error("Fala não encontrada no catálogo: " + line_id)
		return {}
	var line: Dictionary = lines[line_id].duplicate(true)
	line["line_id"] = line_id
	return line


func text(line_id: String, parameters: Dictionary = {}) -> String:
	var line := get_line(line_id)
	if line.is_empty():
		return ""
	var result: String = line["text"]
	for key: Variant in parameters:
		result = result.replace("{" + str(key) + "}", str(parameters[key]))
	if bool(line.get("show_speaker", false)):
		var actors: Dictionary = DATA.data["actors"]
		result = str(actors[line["sender_id"]]["name"]) + ": " + result
	return result


func texts(sequence_id: String) -> Array[String]:
	var result: Array[String] = []
	for line_id: String in _sequence(sequence_id):
		result.append(text(line_id))
	return result


func entries(sequence_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for line_id: String in _sequence(sequence_id):
		var line := get_line(line_id)
		var entry: Dictionary = line.get("metadata", {}).duplicate(true)
		entry["text"] = text(line_id)
		entry["texto"] = entry["text"]
		entry["line_id"] = line_id
		entry["sender_id"] = line["sender_id"]
		entry["recipient_id"] = line["recipient_id"]
		entry["thought"] = line["thought"]
		result.append(entry)
	return result


func _sequence(sequence_id: String) -> Array[String]:
	var result: Array[String] = []
	var sequences: Dictionary = DATA.data.get("sequences", {})
	if not sequences.has(sequence_id):
		push_error("Conversa não encontrada no catálogo: " + sequence_id)
		return result
	result.assign(sequences[sequence_id])
	return result
