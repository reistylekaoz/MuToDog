class_name BrilhoMU
# Brilho dos itens pelo nivel (+3 a +15), no jeito do cliente: material_overlay em cada
# malha da peca (scripts/brilho_item.gdshader e tinta_item.gdshader). As cores por item
# vem de dados/brilho/cores.json (ferramentas/brilho_itens.py, do MuMain).

const PASTA := "res://dados/brilho/"
static var _cores := {}
static var _sh_brilho: Shader
static var _sh_tinta: Shader
static var _tex := {}


static func _carregar() -> void:
	if _sh_brilho:
		return
	_sh_brilho = load("res://scripts/brilho_item.gdshader")
	_sh_tinta = load("res://scripts/tinta_item.gdshader")
	for n in ["chrome01", "chrome02", "shiny01"]:
		_tex[n] = load(PASTA + n + ".jpg")
	if FileAccess.file_exists(PASTA + "cores.json"):
		_cores = JSON.parse_string(FileAccess.get_file_as_string(PASTA + "cores.json"))


# o nivel que o item mostra (asa brilha como +0, joia como +8...)
static func nivel_visivel(chave: String, nivel: int) -> int:
	_carregar()
	var c: Array = _cores.get(chave, [])
	if c.size() > 2 and c[2] is Array:   # flecha, chave e olho do Devil Square: tabela por nivel
		return int(c[2][clampi(nivel, 0, c[2].size() - 1)])
	if c.size() > 2 and c[2] >= 0:
		return int(c[2])
	return nivel


static func material(chave: String, nivel: int) -> Material:
	_carregar()
	var n := nivel_visivel(chave, nivel)
	if n < 3:
		return null
	if n < 7:
		var t := ShaderMaterial.new()
		t.shader = _sh_tinta
		t.set_shader_parameter("tinta", Color(1, 0.6, 0.6) if n < 5 else Color(0.5, 0.7, 1.0))
		return t
	var c: Array = _cores.get(chave, [[1, 0.5, 0], [1, 1, 1], -1])
	var m := ShaderMaterial.new()
	m.shader = _sh_brilho
	m.set_shader_parameter("cromo", _tex.chrome01)
	m.set_shader_parameter("cromo2", _tex.chrome02)
	m.set_shader_parameter("metal", _tex.shiny01)
	m.set_shader_parameter("cor", Color(c[0][0], c[0][1], c[0][2]))
	m.set_shader_parameter("cor2", Color(c[1][0], c[1][1], c[1][2]))
	m.set_shader_parameter("nivel", n)
	return m


# poe (ou tira, nivel baixo) o brilho em todas as malhas do no
static func aplicar(no: Node, chave: String, nivel: int) -> void:
	var m := material(chave, nivel)
	var lista: Array = no.find_children("*", "MeshInstance3D", true, false)
	if no is MeshInstance3D:
		lista.append(no)
	for mi: MeshInstance3D in lista:
		mi.material_overlay = m
