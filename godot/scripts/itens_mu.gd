class_name ItensMU
extends RefCounted
# O que o cliente sabe dos itens: tamanho, onde equipa, nome (dados/itens_info.json
# e itens.json, tirados do OpenMU) e o icone (dados/icones.png, feito pelo
# testes/icones.sh a partir do modelo 3D de cada item).

const JOIAS_ALVO := ["14,13", "14,14", "14,16", "14,42", "14,43", "14,44"]  # vao em cima de outro item

static var _info := {}
static var _nomes := {}
static var _icones := {}
static var _atlas: Texture2D


static func _carregar() -> void:
	if not _info.is_empty():
		return
	_info = _json("res://dados/itens_info.json")
	_nomes = _json("res://dados/itens.json")
	_icones = _json("res://dados/icones.json")
	if ResourceLoader.exists("res://dados/icones.png"):
		_atlas = load("res://dados/icones.png")


static func _json(c: String) -> Dictionary:
	if not FileAccess.file_exists(c):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(c))
	return d if d is Dictionary else {}


static func chave(it: Dictionary) -> String:
	return "%d,%d" % [it.grupo, it.numero]


# [largura, altura, slots, durabilidade, consome, skill]
static func info(it: Dictionary) -> Array:
	_carregar()
	return _info.get(chave(it), [1, 1, [], 0, false, -1])


static func tamanho(it: Dictionary) -> Vector2i:
	var i := info(it)
	return Vector2i(int(i[0]), int(i[1]))


static func slots(it: Dictionary) -> Array:
	return info(it)[2]


static func consome(it: Dictionary) -> bool:
	return info(it)[4]


static func nome(it: Dictionary) -> String:
	_carregar()
	var n: String = _nomes.get(chave(it), "Item %s" % chave(it))
	if it.get("nivel", 0) > 0:
		n += " +%d" % it.nivel
	return n


# poções e joias empilham: a "durabilidade" e a quantidade
static func empilha(it: Dictionary) -> bool:
	return it.grupo == 14 and int(info(it)[3]) <= 3 and consome(it)


static func linhas(it: Dictionary) -> Array:
	var l := []
	var cor := Color(1, 1, 1)
	if it.exc > 0:
		cor = Color(0.4, 0.95, 0.5)
	elif it.nivel >= 7 or it.sorte:
		cor = Color(0.6, 0.85, 1.0)
	l.append([("Excelente " if it.exc > 0 else "") + nome(it), cor])
	var i := info(it)
	if empilha(it) or it.grupo == 14:
		if it.durabilidade > 1:
			l.append(["Quantidade: %d" % it.durabilidade, Color(0.85, 0.85, 0.85)])
	elif int(i[3]) > 0:
		l.append(["Durabilidade: %d" % it.durabilidade, Color(0.85, 0.85, 0.85)])
	if it.skill:
		l.append(["Skill da arma", Color(0.6, 0.75, 1.0)])
	if it.sorte:
		l.append(["Sorte (+5% de sucesso na joia, +5% de critico)", Color(0.6, 0.75, 1.0)])
	if it.get("opcao", 0) > 0:
		l.append(["Opcao adicional +%d" % (it.opcao * 4), Color(0.6, 0.75, 1.0)])
	if it.exc > 0:
		l.append(["Opcoes excelentes: %d" % _bits(it.exc), Color(0.4, 0.95, 0.5)])
	if consome(it) and chave(it) not in JOIAS_ALVO:
		l.append(["Botao direito: usar", Color(0.95, 0.8, 0.45)])
	elif not slots(it).is_empty():
		l.append(["Botao direito: equipar ou tirar", Color(0.95, 0.8, 0.45)])
	if chave(it) in JOIAS_ALVO:
		l.append(["Arraste em cima do item pra usar", Color(0.95, 0.8, 0.45)])
	return l


static func _bits(v: int) -> int:
	var n := 0
	while v > 0:
		n += v & 1
		v >>= 1
	return n


# desenha o icone do item dentro do retangulo (centrado, sem esticar)
static func desenhar(ci: CanvasItem, it: Dictionary, r: Rect2, cor := Color.WHITE) -> void:
	_carregar()
	var a: Array = _icones.get(chave(it), [])
	if a.is_empty() or _atlas == null:
		ci.draw_rect(r.grow(-2), Color(0.5, 0.5, 0.6, 0.5 * cor.a))
		return
	var src := Rect2(a[0], a[1], a[2], a[3])
	var e := minf(r.size.x / src.size.x, r.size.y / src.size.y)
	var t := src.size * e
	ci.draw_texture_rect_region(_atlas, Rect2(r.position + (r.size - t) / 2.0, t), src, cor)
