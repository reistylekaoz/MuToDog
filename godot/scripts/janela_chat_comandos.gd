class_name JanelaChatComandos
extends PainelLateral
# Janela dos comandos de chat (tecla J, CNewUIChatCommandWindow do MuMain): a lista vem do servidor pelo C2 F5 01,
# um comando por pacote, depois do C1 F5 00 que o cliente manda ao entrar. Tres paginas: comandos (20 linhas de 15
# a partir do 36, favoritos em cima com "* ", " ..." quando pede parametro; sem parametro manda na hora), parametros
# (descricao, cada parametro com o nome e a caixa do valor: lista de valores gira no clique, o resto digita) e modelos
# (linhas guardadas, x apaga). Executar manda a linha como chat publico. Favoritos e modelos ficam neste PC.
# Os textos da janela nao estao no material de referencia (I18N do fork): rotulos em ingles no jeito dela.

signal executar(linha: String)

const ARQ := "user://comandos_chat.json"
const ESQ := 22.0
const LARG := 146.0
const TOPO := 36.0
const LINHA := 15.0
const LINHAS := 20
const VALOR_A := 16.0
const PARAM_A := LINHA + VALOR_A + 4
const BAIXO := 358.0 - LINHA
const COR_TITULO := Color8(255, 220, 120)
const COR_NORMAL := Color8(220, 220, 220)
const COR_DESC := Color8(200, 220, 255)
const COR_FALTA := Color8(255, 150, 150)
const COR_ACAO := Color8(150, 210, 255)

var comandos: Array = []      # na ordem do servidor
var ordem: Array = []         # indices, favoritos primeiro
var favoritos: Array = []     # nomes dos comandos
var modelos: Array = []       # [{rotulo, comando, valores}]
var pagina := 0               # 0 comandos, 1 parametros, 2 modelos
var rolagem := 0
var escolhido := -1           # linha em ordem
var valores: Array = []
var editando := -1
var _campo: LineEdit
var _desc: Array = []


func _ready() -> void:
	super()
	topo = "inv_topo01"
	_campo = LineEdit.new()
	_campo.visible = false
	_campo.flat = true
	_campo.add_theme_font_size_override("font_size", 10)
	_campo.add_theme_color_override("font_color", COR_NORMAL)
	_campo.position = Vector2(ESQ + 2, 0)
	_campo.size = Vector2(LARG - 4, VALOR_A)
	_campo.text_submitted.connect(func(_t): _parar_edicao())
	add_child(_campo)
	_ler_arquivo()


func _ler_arquivo() -> void:
	if not FileAccess.file_exists(ARQ):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(ARQ))
	if d is Dictionary:
		favoritos = d.get("favoritos", [])
		modelos = d.get("modelos", [])


func _guardar() -> void:
	var f := FileAccess.open(ARQ, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"favoritos": favoritos, "modelos": modelos}))


# C2 F5 01: o indice 0 recomeca a lista
func receber(indice: int, _total: int, cmd: Dictionary) -> void:
	if indice == 0:
		comandos.clear()
	comandos.append(cmd)
	_reordenar()
	queue_redraw()


func _reordenar() -> void:
	var fav := []
	var resto := []
	for i in comandos.size():
		(fav if comandos[i].comando in favoritos else resto).append(i)
	ordem = fav + resto


func abrir() -> void:
	_mostrar(0)
	visible = true
	print("TESTE comandos_chat %d" % comandos.size())


func _cmd(linha: int) -> Dictionary:
	if linha < 0 or linha >= ordem.size():
		return {}
	return comandos[ordem[linha]]


func _mostrar(p: int) -> void:
	_parar_edicao()
	pagina = p
	rolagem = 0
	if p == 1:
		_desc = _quebrar(_cmd(escolhido).get("descricao", ""))


func _quebrar(t: String) -> Array:
	var l := []
	var atual := ""
	for w in t.split(" ", false):
		var tenta := w if atual == "" else atual + " " + w
		if largura_texto(tenta) > LARG and atual != "":
			l.append(atual)
			atual = w
		else:
			atual = tenta
	if atual != "":
		l.append(atual)
	return l


# ChatCommandCatalog::BuildCommandLine: "curto=valor" quando o primeiro parametro tem nome curto
static func linha_comando(cmd: Dictionary, vals: Array) -> String:
	var ps: Array = cmd.get("parametros", [])
	var curtos: bool = not ps.is_empty() and ps[0].curto != ""
	var s: String = cmd.comando
	for i in mini(ps.size(), vals.size()):
		if str(vals[i]) == "":
			continue
		s += " "
		if curtos and ps[i].curto != "":
			s += ps[i].curto + "="
		s += str(vals[i])
	return s


func _escolher(linha: int) -> void:
	escolhido = linha
	var c := _cmd(linha)
	if c.is_empty():
		return
	if c.parametros.is_empty():
		_mandar(c.comando)
		return
	valores = []
	valores.resize(c.parametros.size())
	valores.fill("")
	_mostrar(1)


func _mandar(linha: String) -> void:
	print("TESTE comando_chat_executa %s" % linha)
	executar.emit(linha)
	fechar()


func _faltando() -> bool:
	var c := _cmd(escolhido)
	for i in c.get("parametros", []).size():
		if c.parametros[i].obrigatorio and valores[i] == "":
			return true
	return false


func _linhas_desc() -> int:
	var c := _cmd(escolhido)
	var reservado: float = c.get("parametros", []).size() * PARAM_A + 3 * LINHA
	return mini(maxi(0, int((BAIXO - TOPO - reservado) / LINHA)), _desc.size())


func _topo_param() -> float:
	return TOPO + (_linhas_desc() + 1) * LINHA


func _topo_acao() -> float:
	return _topo_param() + _cmd(escolhido).get("parametros", []).size() * PARAM_A + LINHA


func _parar_edicao() -> void:
	if editando >= 0 and editando < valores.size():
		valores[editando] = _campo.text
	editando = -1
	if _campo:
		_campo.visible = false
		_campo.release_focus()


func fechar() -> void:
	_parar_edicao()
	super()


func _conteudo() -> void:
	var titulo := "Chat Commands"
	if pagina == 2:
		titulo = "Templates"
	elif pagina == 1:
		titulo = _cmd(escolhido).get("comando", titulo)
	texto(Vector2(0, 12 + 9), titulo, L, COR_TITULO, true)
	match pagina:
		0: _pag_comandos()
		1: _pag_parametros()
		2: _pag_modelos()
	if pagina != 0:
		botao("esq", Rect2(ESQ, 358, 64, 29), "Back", true, "btn_pequeno")
	if pagina != 2:
		botao("dir", Rect2(104, 358, 64, 29), "Templates" if pagina == 0 else "Execute", true, "btn_pequeno")


func _pag_comandos() -> void:
	if ordem.is_empty():
		texto(Vector2(ESQ, TOPO + 9), "The server sends no chat commands.", 0, COR_NORMAL)
		return
	for r in LINHAS:
		var c := _cmd(rolagem + r)
		if c.is_empty():
			break
		var fav: bool = c.comando in favoritos
		var t: String = ("* " if fav else "") + c.comando + (" ..." if not c.parametros.is_empty() else "")
		var y := TOPO + r * LINHA
		if Rect2(ESQ, y, LARG, LINHA).has_point(_mouse):
			draw_rect(Rect2(ESQ, y, LARG, LINHA), Color(1, 1, 1, 0.08))
		texto(Vector2(ESQ, y + 10), t, 0, COR_TITULO if fav else COR_NORMAL)


func _pag_parametros() -> void:
	var c := _cmd(escolhido)
	if c.is_empty():
		return
	for i in _linhas_desc():
		texto(Vector2(ESQ, TOPO + i * LINHA + 10), _desc[i], 0, COR_DESC)
	for i in c.parametros.size():
		var pr: Dictionary = c.parametros[i]
		var y: float = _topo_param() + i * PARAM_A
		var v: String = valores[i]
		texto(Vector2(ESQ, y + 10), pr.nome + (" *" if pr.obrigatorio else ""), 0,
				COR_FALTA if pr.obrigatorio and v == "" else COR_NORMAL)
		draw_rect(Rect2(ESQ, y + LINHA, LARG, VALOR_A), Color8(0, 0, 0, 160))
		if editando != i:
			texto(Vector2(ESQ + 2, y + LINHA + 12), v if v != "" else "|".join(pr.valores), 0, COR_NORMAL if v != "" else COR_DESC)
	var a := _topo_acao()
	texto(Vector2(ESQ, a + 10), "Remove from favourites" if c.comando in favoritos else "Add to favourites", 0, COR_ACAO)
	texto(Vector2(ESQ, a + LINHA + 10), "Save as template", 0, COR_ACAO)


func _pag_modelos() -> void:
	if modelos.is_empty():
		texto(Vector2(ESQ, TOPO + 9), "No templates saved yet.", 0, COR_NORMAL)
		return
	for r in LINHAS:
		var i := rolagem + r
		if i >= modelos.size():
			break
		var y := TOPO + r * LINHA
		texto(Vector2(ESQ, y + 10), modelos[i].rotulo, 0, COR_NORMAL)
		texto(Vector2(ESQ + LARG - LINHA, y + 10), "x", LINHA, COR_FALTA)


func _clique(p: Vector2) -> void:
	match botao_em(p):
		"esq":
			_mostrar(0)
			return
		"dir":
			if pagina == 0:
				_mostrar(2)
			else:
				_executar()
			return
	match pagina:
		0:
			for r in LINHAS:
				if _cmd(rolagem + r).is_empty():
					break
				if Rect2(ESQ, TOPO + r * LINHA, LARG, LINHA).has_point(p):
					_escolher(rolagem + r)
					return
		1:
			_clique_parametros(p)
		2:
			for r in LINHAS:
				var i := rolagem + r
				if i >= modelos.size():
					break
				var y := TOPO + r * LINHA
				if Rect2(ESQ + LARG - LINHA, y, LINHA, LINHA).has_point(p):
					modelos.remove_at(i)
					_guardar()
					return
				if Rect2(ESQ, y, LARG - LINHA, LINHA).has_point(p):
					_executar_modelo(i)
					return


func _clique_parametros(p: Vector2) -> void:
	var c := _cmd(escolhido)
	for i in c.parametros.size():
		var y: float = _topo_param() + i * PARAM_A + LINHA
		if not Rect2(ESQ, y, LARG, VALOR_A).has_point(p):
			continue
		var vs: PackedStringArray = c.parametros[i].valores
		if not vs.is_empty():
			_parar_edicao()
			var n := vs.find(valores[i]) + 1
			valores[i] = "" if n >= vs.size() else vs[n]
		else:
			_parar_edicao()
			editando = i
			_campo.position.y = y + 1
			_campo.text = valores[i]
			_campo.visible = true
			_campo.grab_focus()
		return
	var a := _topo_acao()
	if Rect2(ESQ, a, LARG, LINHA).has_point(p):
		if c.comando in favoritos:
			favoritos.erase(c.comando)
		else:
			favoritos.append(c.comando)
		var nome: String = c.comando
		_reordenar()
		for r in ordem.size():
			if comandos[ordem[r]].comando == nome:
				escolhido = r
		_guardar()
	elif Rect2(ESQ, a + LINHA, LARG, LINHA).has_point(p):
		_parar_edicao()
		modelos.append({"rotulo": linha_comando(c, valores), "comando": c.comando, "valores": valores.duplicate()})
		_guardar()


func _executar() -> void:
	_parar_edicao()
	var c := _cmd(escolhido)
	if c.is_empty():
		return
	if _faltando():
		print("TESTE comando_chat_falta")
		return
	_mandar(linha_comando(c, valores))


func _executar_modelo(i: int) -> void:
	var m: Dictionary = modelos[i]
	for c in comandos:
		if c.comando == m.comando:
			_mandar(linha_comando(c, m.valores))
			return


func _roda(passo: int) -> void:
	var total := modelos.size() if pagina == 2 else ordem.size()
	rolagem = clampi(rolagem + passo, 0, maxi(0, total - LINHAS))


# Esc (UpdateKeyEvent): sai do campo, depois volta pra lista, depois fecha
func esc() -> void:
	if editando >= 0:
		_parar_edicao()
	elif pagina != 0:
		_mostrar(0)
	else:
		fechar()
	queue_redraw()
