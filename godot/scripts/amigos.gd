class_name Amigos
extends PanelContainer
# Lista de amigos (F), no jeito do messenger do MU: quem esta on (servidor) ou off,
# campo pra adicionar pelo nome, apagar, e os pedidos de amizade que chegaram
# (aceitar ou recusar). O OpenMU manda a lista ao entrar (C2 C0).

signal adicionar(nome: String)
signal apagar(nome: String)
signal responder(aceita: bool, nome: String)

const FORA := 0xFF
const INVISIVEL := 0xFE

var lista := {}        # nome -> servidor (0xFF fora)
var pedidos := []      # nomes que pediram amizade
var cartas := 0
var _caixa: VBoxContainer
var _campo: LineEdit
var _aviso: Label


func _ready() -> void:
	var e := StyleBoxFlat.new()
	e.bg_color = Color(0.05, 0.04, 0.03, 0.92)
	e.border_color = Color(0.55, 0.45, 0.25)
	e.set_border_width_all(1)
	e.set_corner_radius_all(4)
	e.set_content_margin_all(12)
	add_theme_stylebox_override("panel", e)
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(16, 70)
	custom_minimum_size = Vector2(340, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var topo := HBoxContainer.new()
	v.add_child(topo)
	var t := _rotulo("Amigos", 17, Color(1, 0.86, 0.45))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(t)
	var x := Button.new()
	x.text = "Fechar (F)"
	x.pressed.connect(func(): visible = false)
	topo.add_child(x)
	_caixa = VBoxContainer.new()
	_caixa.add_theme_constant_override("separation", 4)
	v.add_child(_caixa)
	var linha := HBoxContainer.new()
	v.add_child(linha)
	_campo = LineEdit.new()
	_campo.placeholder_text = "Nome do amigo"
	_campo.max_length = 10
	_campo.custom_minimum_size = Vector2(190, 0)
	_campo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_campo.text_submitted.connect(func(_t): _adicionar())
	linha.add_child(_campo)
	var b := Button.new()
	b.text = "Adicionar"
	b.pressed.connect(_adicionar)
	linha.add_child(b)
	_aviso = _rotulo("O amigo precisa aceitar o pedido. Ele aparece aqui quando o servidor confirmar.", 12, Color(0.7, 0.7, 0.75))
	_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_aviso.custom_minimum_size = Vector2(316, 0)
	v.add_child(_aviso)
	visible = false
	_montar()


func alternar() -> void:
	visible = not visible
	if visible:
		move_to_front()
		_montar()


func definir(l: Array, n_cartas: int) -> void:
	lista.clear()
	for a in l:
		lista[a.nome] = a.servidor
	cartas = n_cartas
	_montar()


func novo(nome: String, servidor: int) -> void:
	lista[nome] = servidor
	_aviso.text = "%s entrou na sua lista." % nome
	_montar()


func saiu(nome: String) -> void:
	lista.erase(nome)
	_montar()


func estado(nome: String, servidor: int) -> void:
	if lista.has(nome):
		lista[nome] = servidor
		_montar()


func pedido(nome: String) -> void:
	if nome not in pedidos:
		pedidos.append(nome)
	_montar()


func _adicionar() -> void:
	var n := _campo.text.strip_edges()
	if n == "":
		return
	if lista.has(n):
		_aviso.text = "%s ja esta na lista." % n
		return
	adicionar.emit(n)
	_aviso.text = "Pedido mandado pra %s. Se o nome nao existir, nada muda." % n
	_campo.text = ""


func _montar() -> void:
	if _caixa == null:
		return
	for c in _caixa.get_children():
		c.queue_free()
	for n in pedidos:
		var h := HBoxContainer.new()
		var r := _rotulo("%s quer ser seu amigo" % n, 14, Color(0.6, 0.85, 1.0))
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(r)
		for aceita in [true, false]:
			var b := Button.new()
			b.text = "Aceitar" if aceita else "Recusar"
			b.pressed.connect(func():
				pedidos.erase(n)
				responder.emit(aceita, n)
				_montar())
			h.add_child(b)
		_caixa.add_child(h)
	if lista.is_empty():
		_caixa.add_child(_rotulo("Nenhum amigo ainda.", 14, Color(0.7, 0.7, 0.75)))
	var nomes := lista.keys()
	nomes.sort_custom(func(a, b): return [lista[a] >= INVISIVEL, a] < [lista[b] >= INVISIVEL, b])
	for n in nomes:
		var h := HBoxContainer.new()
		var on: bool = lista[n] < INVISIVEL
		var r := _rotulo(n, 15, Color(0.4, 0.95, 0.5) if on else Color(0.6, 0.6, 0.65))
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(r)
		h.add_child(_rotulo("Servidor %d" % (lista[n] + 1) if on else "fora", 12, Color(0.75, 0.75, 0.8)))
		var b := Button.new()
		b.text = "Apagar"
		b.pressed.connect(func(): apagar.emit(n))
		h.add_child(b)
		_caixa.add_child(h)
	if cartas > 0:
		_caixa.add_child(_rotulo("%d carta(s) na caixa." % cartas, 12, Color(0.75, 0.75, 0.8)))


static func _rotulo(t: String, tam: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	return l
