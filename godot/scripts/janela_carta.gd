class_name JanelaCarta
extends JanelaMU
# As duas janelas de carta do "My Friend".
# Escrever (CUILetterWriteWindow, 370x216): "Write letter (Cost: %d zen)", Receiver (ate 10) e Title nas faixas
# pretas de cima, o texto de 238x135 em 5,33, Send e Close embaixo (12 e 63), Prev. Action e Next Action (250 e
# 301) e a minha foto de 119 na direita (angulo 90, em pe). Campo vazio avisa (1006, 1007, 1008); fechar com algo
# escrito pergunta (1009).
# Ler (CUILetterReadWindow, 370x182): "Read letter: %s", "Sender: %s (%s %s)" em cima, o texto, Reply, Delete,
# Previous, Next e Close embaixo, e a foto de quem mandou na pose e no giro que ele escolheu.

signal enviar(para: String, titulo: String, texto: String, giro: int, animacao: int)
signal responder(para: String, titulo: String)
signal apagar(indice: int)
signal andar(indice: int, passo: int)         # Previous / Next
signal pergunta(texto: String, tipo: int, guardado: String, retorno: Callable)

const CUSTO := 1000

var lendo := false
var carta := {}               # a que esta aberta (indice, de, data, titulo)
var id_envio := 0
var enviando := false
var foto: FotoMU
var _para: LineEdit
var _assunto: LineEdit
var _texto: TextEdit
var _linhas: PackedStringArray = []
var _primeira := 0


func _init(ler := false) -> void:
	lendo = ler
	super._init("", 370, 182 if ler else 216)
	foto = FotoMU.new()
	add_child(foto)
	if lendo:
		foto.position = dentro(largura_dentro() - 119, 15)
		foto.size = Vector2(119, altura_dentro() - 15)
		foto.controle = true
		return
	titulo = DicaItem.t(1071) % CUSTO
	var w := largura_texto(DicaItem.t(1000))
	_para = JanelaMU.campo(10)
	_para.position = dentro(w, 1)
	_para.size = Vector2(120, 14)
	add_child(_para)
	_assunto = JanelaMU.campo(32)
	_assunto.position = dentro(w, 15)
	_assunto.size = Vector2(238 - w, 14)
	add_child(_assunto)
	_texto = TextEdit.new()
	_texto.position = dentro(5, 33)
	_texto.size = Vector2(234, 135)
	_texto.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_texto.add_theme_font_size_override("font_size", 10)
	_texto.add_theme_color_override("font_color", TEXTO)
	_texto.add_theme_constant_override("line_spacing", 1)
	var vazio := StyleBoxFlat.new()
	vazio.bg_color = Color(0, 0, 0, 0)
	for s in ["normal", "focus", "read_only"]:
		_texto.add_theme_stylebox_override(s, vazio)
	add_child(_texto)
	foto.position = dentro(largura_dentro() - 119, 30)
	foto.size = Vector2(119, altura_dentro() - 49)


func _ready() -> void:
	super._ready()
	if _para:
		_para.focus_next = _assunto.get_path()
		(_para if _para.text == "" else (_assunto if _assunto.text == "" else _texto)).grab_focus()


# escrever: quem recebe e o assunto (Reply chega com "Re: titulo"); a foto e a minha
func preparar(para: String, assunto: String, classe: int, equip: Dictionary) -> void:
	_para.text = para
	_assunto.text = assunto
	foto.definir(classe, equip)
	if is_inside_tree():
		(_para if para == "" else (_assunto if assunto == "" else _texto)).grab_focus()


# ler: o cabecalho da lista e o que veio no C4 C7
func abrir(c: Dictionary, aberta: Dictionary) -> void:
	carta = c
	titulo = DicaItem.t(1054) % c.get("titulo", "")
	_linhas = []
	for l in str(aberta.get("texto", "")).split("\n"):
		_linhas.append_array(_quebrar(l, largura_dentro() - 120 - 8))
	_primeira = 0
	if str(c.get("de", "")).to_lower() == "webzen":
		foto.mostrar_webzen()
	else:
		var ap: Dictionary = aberta.get("aparencia", {})
		foto.definir(int(aberta.get("classe", 0)), ap)
		foto.usar_giro(int(aberta.get("giro", 0)))
		foto.usar_animacao(int(aberta.get("animacao", 2)))
	queue_redraw()


func _quebrar(t: String, w: float) -> PackedStringArray:
	var r: PackedStringArray = []
	var atual := ""
	for p in t.split(" "):
		var tenta := p if atual == "" else atual + " " + p
		if atual != "" and largura_texto(tenta) > w:
			r.append(atual)
			atual = p
		else:
			atual = tenta
	r.append(atual)
	return r


func _conteudo() -> void:
	var w := largura_dentro()
	var h := altura_dentro()
	if lendo:
		var cabem := int((h - 15 - 20) / 13)
		for k in cabem:
			var i := _primeira + k
			if i >= _linhas.size():
				break
			texto(dentro(4, 18 + k * 13), _linhas[i])
		rolagem(Rect2(dentro(w - 120 - 13, 15), Vector2(13, h - 35)), _linhas.size(), cabem, _primeira)
		draw_rect(Rect2(dentro(w - 120, h - 19), Vector2(1, 19)), COR[2])
		draw_rect(Rect2(dentro(0, h - 20), Vector2(w - 120, 1)), COR[2])
		draw_rect(Rect2(dentro(0, h - 19), Vector2(w - 120, 18)), COR[7])
		draw_rect(Rect2(dentro(0, 14), Vector2(w, 1)), COR[2])
		draw_rect(Rect2(dentro(0, 0), Vector2(w, 14)), COR[7])
		var d := str(carta.get("data", "")).split(" ")
		texto(dentro(3, 3), DicaItem.t(1014) % [carta.get("de", ""), d[0], d[1] if d.size() > 1 else ""])
		var y := h - 16
		botao("responder", Rect2(dentro(2, y), Vector2(50, 14)), DicaItem.t(1010))
		botao("apagar", Rect2(dentro(53, y), Vector2(50, 14)), DicaItem.t(1011))
		botao("anterior", Rect2(dentro(104, y), Vector2(40, 14)), DicaItem.t(1012))
		botao("proxima", Rect2(dentro(145, y), Vector2(40, 14)), DicaItem.t(1013))
		botao("fechar", Rect2(dentro(186, y), Vector2(50, 14)), DicaItem.t(1002))
		return
	draw_rect(Rect2(dentro(0, 0), Vector2(w, 29)), COR[7])
	draw_rect(Rect2(dentro(0, 14), Vector2(w, 1)), COR[2])
	draw_rect(Rect2(dentro(0, 29), Vector2(w, 1)), COR[2])
	draw_rect(Rect2(dentro(0, h - 19), Vector2(w, 19)), COR[7])
	draw_rect(Rect2(dentro(0, h - 19), Vector2(w, 1)), COR[2])
	var lw := largura_texto(DicaItem.t(1000))
	texto(dentro(3, 3), DicaItem.t(1000), TEXTO, false, lw, HORIZONTAL_ALIGNMENT_RIGHT)
	texto(dentro(3, 18), DicaItem.t(1005), TEXTO, false, lw, HORIZONTAL_ALIGNMENT_RIGHT)
	var y := h - 16
	botao("enviar", Rect2(dentro(12, y), Vector2(50, 14)), DicaItem.t(1001), not enviando)
	botao("fechar", Rect2(dentro(63, y), Vector2(50, 14)), DicaItem.t(1002))
	botao("pose_antes", Rect2(dentro(250, y), Vector2(50, 14)), DicaItem.t(1003))
	botao("pose_depois", Rect2(dentro(301, y), Vector2(50, 14)), DicaItem.t(1004))


func _roda(p: Vector2, passo: int) -> void:
	if lendo:
		var cabem := int((altura_dentro() - 35) / 13)
		_primeira = clampi(_primeira + passo, 0, maxi(_linhas.size() - cabem, 0))


func _apertou(n: String) -> void:
	match n:
		"enviar":
			if _para.text.strip_edges() == "":
				pergunta.emit(DicaItem.t(1006), 1, "", func(_s, _t): _para.grab_focus())
			elif _assunto.text.strip_edges() == "":
				pergunta.emit(DicaItem.t(1007), 1, "", func(_s, _t): _assunto.grab_focus())
			elif _texto.text.strip_edges() == "":
				pergunta.emit(DicaItem.t(1008), 1, "", func(_s, _t): _texto.grab_focus())
			else:
				enviando = true
				enviar.emit(_para.text.strip_edges(), _assunto.text.strip_edges(), _texto.text, foto.giro_byte(),
					foto.animacao_byte())
		"fechar":
			fechar()
		"pose_antes":
			foto.proxima(-1)
		"pose_depois":
			foto.proxima(1)
		"responder":
			responder.emit(carta.get("de", ""), (DicaItem.t(1016) % carta.get("titulo", "")).substr(0, 32))
		"apagar":
			pergunta.emit(DicaItem.t(1017), 0, "", func(sim, _t):
				if sim:
					apagar.emit(int(carta.get("indice", -1))))
		"anterior":
			andar.emit(int(carta.get("indice", -1)), -1)
		"proxima":
			andar.emit(int(carta.get("indice", -1)), 1)


func fechar() -> void:
	if not lendo and not enviando and (_texto.text.strip_edges() != "" or _assunto.text.strip_edges() != ""):
		pergunta.emit(DicaItem.t(1009), 0, "", func(sim, _t):
			if sim:
				_sair())
		return
	_sair()


func _sair() -> void:
	visible = false
	fechou.emit()
	queue_free()


# o C1 C5 que nao deu: libera o Send de novo
func falhou_envio() -> void:
	enviando = false
	queue_redraw()
