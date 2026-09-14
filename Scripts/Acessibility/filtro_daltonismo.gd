extends CanvasLayer

signal modo_alterado(modo: int)

# Perfis de assistência. A cena global só distribui a preferência.
# Nenhum perfil simula a visão de uma pessoa daltônica.
var modo: int = 0


func aplicar_filtro(novo_modo: int) -> void:
	var selecionado := clampi(novo_modo, 0, 3)
	if modo == selecionado:
		return
	modo = selecionado
	modo_alterado.emit(modo)
