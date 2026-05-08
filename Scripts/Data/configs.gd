extends Node

var configs: Dictionary = {
	"traducao": "ENGLISH",
	"volume_geral": 1.0,
	"volume_musica": 0.1,
	"volume_sfx": 0.0,
	"tela_cheia" : false,
	"filtro_de_daltonismo" : 0,
	"intensidade_filtro_daltonismo" : 1.0,
	"frame_rate" : 0,
	"mostrar_fps" : false,
	"legenda_ativa" : false,
	"tamanho_legenda" : 10,
	"primeira_vez" : true,
	"leitor_de_tela" : false,
	"velocidade_leitor_de_tela" : 1.0,
	"volume_leitor": 1.0,
	"alto_contraste": false,
	"interface_size": 1.0
}


func _change_traducao(new_value : String):
	configs.traducao = new_value
	
func _change_volume_geral(new_value : float):
	configs.volume_geral = new_value
	
func _change_volume_musica(new_value : float):
	configs.volume_musica = new_value
	
func _change_volume_sfx(new_value : float):
	configs.volume_sfx = new_value
	
func _change_tela_cheia(new_value : bool):
	configs.tela_cheia = new_value
	
func _change_filtro_de_daltonismo(new_value : int):
	configs.filtro_de_daltonismo = new_value
	
func _change_intensidade_filtro_daltonismo(new_value : float):
	configs.intensidade_filtro_daltonismo = new_value
	
func _change_frame_rate(new_value : int):
	configs.frame_rate = new_value
	
func _change_mostrar_fps(new_value : bool):
	configs.mostrar_fps = new_value

func _change_legenda_ativa(new_value : bool):
	configs.legenda_ativa = new_value
	
func _change_tamanho_legenda(new_value : int):
	configs.tamanho_legenda = new_value
	
func _change_primeira_vez():
	configs.primeira_vez = false
	
func _change_leitor_de_tela(new_value : bool):
	configs.leitor_de_tela = new_value
	
func _change_velocidade_leitor_de_tela(new_value : float):
	configs.velocidade_leitor_de_tela = new_value
	
func _change_volume_leitor_de_tela(new_value : float):
	configs.volume_leitor = new_value
	
func _change_alto_contraste(new_value : bool):
	configs.alto_contraste = new_value
	
func _change_interface_size(new_value : int):
	configs.interface_size = new_value
