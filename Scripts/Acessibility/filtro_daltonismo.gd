extends CanvasLayer

signal modo_alterado(modo: int)

enum Modo {
	DESLIGADO = 0,
	PROTAN = 1,
	DEUTAN = 2,
	TRITAN = 3,
}

# Perfis de assistência. A cena global só distribui a preferência.
# Nenhum perfil simula a visão de uma pessoa daltônica.
var modo: int = Modo.DESLIGADO

@onready var _mapa_acessibilidade: ColorRect = $MapaAcessibilidade


func _ready() -> void:
	# A camada é desenhada depois do mundo e antes dos HUDs que vêm da cena.
	# O autoload entra antes da cena atual, então o mapa fica fora do pós-processamento.
	layer = 1
	if not modo_alterado.is_connected(_on_modo_alterado):
		modo_alterado.connect(_on_modo_alterado)
	if not get_tree().scene_changed.is_connected(_atualizar_cena):
		get_tree().scene_changed.connect(_atualizar_cena)
	_on_modo_alterado(modo)
	_atualizar_cena()


func aplicar_filtro(novo_modo: int) -> void:
	var selecionado := clampi(novo_modo, 0, 3)
	if modo == selecionado:
		return
	modo = selecionado
	modo_alterado.emit(modo)


func _on_modo_alterado(novo_modo: int) -> void:
	if not is_instance_valid(_mapa_acessibilidade):
		return
	var material := _mapa_acessibilidade.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("modo", novo_modo)
	_mapa_acessibilidade.visible = novo_modo != 0 and _cena_e_mapa()


func _atualizar_cena(_cena: Node = null) -> void:
	if not is_instance_valid(_mapa_acessibilidade):
		return
	_mapa_acessibilidade.visible = modo != 0 and _cena_e_mapa()


func _cena_e_mapa() -> bool:
	var cena_atual := get_tree().current_scene
	if cena_atual == null:
		return false
	var nome := String(cena_atual.name).to_lower()
	return nome.begins_with("andar_") or nome in ["data_center_forte", "sala_chefe", "office_mission"]
