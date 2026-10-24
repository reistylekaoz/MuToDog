class_name JanelaPergunta
extends JanelaMU
# As janelinhas de 150x100 do "My Friend": CUIQuestionWindow (titulo Question, texto em ate 2 linhas de 125, Yes em
# 18,40 e No em 73,40, 50x20) e o tipo OK (so o botao em 45,40), e a CUITextInputWindow (o pedido no titulo,
# campo de 80x14 em 30,14 e OK / Cancel). Enter responde sim, Esc nao.

signal respondeu(sim: bool, texto: String)

var linhas: Array[String] = []
var tipo := 0              # 0 pergunta (Yes/No), 1 aviso (OK), 2 texto (OK/Cancel com campo)
var guardado := ""         # nome que a pergunta carrega (pedido de amizade, amigo pra apagar...)
var _campo: LineEdit


func _init(t := "", tipo_janela := 0, limite := 10) -> void:
	tipo = tipo_janela
	super._init(DicaItem.t(991) if tipo == 0 else (DicaItem.t(228) if tipo == 1 else t), 150, 100)
	if tipo == 2:
		_campo = JanelaMU.campo(limite)
		_campo.position = dentro(30, 14)
		_campo.size = Vector2(80, 14)
		_campo.text_submitted.connect(func(_t): responder(true))
		add_child(_campo)
	else:
		linhas = _quebrar(t, 125)


func _ready() -> void:
	super._ready()
	if _campo:
		_campo.grab_focus()


func _quebrar(t: String, w: float) -> Array[String]:
	var r: Array[String] = []
	var atual := ""
	for p in t.split(" ", false):
		var tenta := p if atual == "" else atual + " " + p
		if atual != "" and get_theme_default_font().get_string_size(tenta, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x > w:
			r.append(atual)
			atual = p
		else:
			atual = tenta
	if atual != "":
		r.append(atual)
	return r.slice(0, 2)


func _conteudo() -> void:
	if tipo == 2:
		draw_rect(Rect2(dentro(29, 13), Vector2(82, 16)), COR[2], false, 1.0)
	for i in linhas.size():
		texto(dentro(5, 8 + i * 13), linhas[i], Color.WHITE)
	if tipo == 1:
		botao("sim", Rect2(dentro(45, 40), Vector2(50, 20)), DicaItem.t(228))
	else:
		botao("sim", Rect2(dentro(18, 40), Vector2(50, 20)), DicaItem.t(1037) if tipo == 0 else DicaItem.t(228))
		botao("nao", Rect2(dentro(73, 40), Vector2(50, 20)), DicaItem.t(1038) if tipo == 0 else DicaItem.t(229))


func _apertou(n: String) -> void:
	responder(n == "sim")


func responder(sim: bool) -> void:
	if not is_instance_valid(self) or is_queued_for_deletion():
		return
	respondeu.emit(true if tipo == 1 else sim, _campo.text.strip_edges() if _campo else "")
	queue_free()


func fechar() -> void:
	responder(false)


func _unhandled_key_input(ev: InputEvent) -> void:
	if not visible or not no_topo() or not ev.pressed or ev.echo:
		return
	if ev.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		responder(true)
		get_viewport().set_input_as_handled()
	elif ev.keycode == KEY_ESCAPE:
		responder(false)
		get_viewport().set_input_as_handled()
