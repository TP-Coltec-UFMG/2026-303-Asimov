extends RefCounted

# O leitor conserva a identidade numérica; somente sua representação é hexadecimal.
const VALOR: int = 1234567891234567
const DIGITOS: String = "0123456789ABCDEF"
const LIMITE_ANTES_DO_PROXIMO_DIGITO: int = 0x07FFFFFFFFFFFFFF


static func formatar(valor: int) -> String:
	return "0x%X" % valor


static func interpretar(texto: String) -> int:
	var normalizado := texto.strip_edges().to_upper()
	if not normalizado.begins_with("0X") or normalizado.length() <= 2:
		return 0

	var resultado: int = 0
	for indice in range(2, normalizado.length()):
		var digito := DIGITOS.find(normalizado.substr(indice, 1))
		if digito < 0 or resultado > LIMITE_ANTES_DO_PROXIMO_DIGITO:
			return 0
		resultado = resultado * 16 + digito

	return resultado
