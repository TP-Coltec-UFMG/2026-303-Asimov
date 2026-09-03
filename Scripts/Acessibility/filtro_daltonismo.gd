extends CanvasLayer

@onready var tela_filtro: ColorRect = $TelaFiltro


func aplicar_filtro(
	modo: int,
	intensidade: float = 0.85,
	severidade: float = 1.0,
	contraste_extra: float = 0.08,
	saturacao_extra: float = 0.08,
	realce_bordas: float = 0.06,
	forca_compensacao: float = 1.0
) -> void:

	tela_filtro.material.set_shader_parameter("modo", modo)
	tela_filtro.material.set_shader_parameter("intensidade", intensidade)
	tela_filtro.material.set_shader_parameter("severidade", severidade)
	tela_filtro.material.set_shader_parameter("contraste_extra", contraste_extra)
	tela_filtro.material.set_shader_parameter("saturacao_extra", saturacao_extra)
	tela_filtro.material.set_shader_parameter("realce_bordas", realce_bordas)
	tela_filtro.material.set_shader_parameter("forca_compensacao", forca_compensacao)
