class_name Movimento
extends PanelContainer
# Janela Move (M), como o CNewUIMoveCommandWindow do S6: cada destino da lista do
# servidor (WarpInfo do OpenMU, em dados/movimento.json) com o nivel pedido e o zen.
# Clique leva (o servidor confere de novo e cobra). Cinza: falta nivel; laranja: falta zen.
# Os portais do mapa (EnterGate: pisou, entra) ficam em portal_em().

signal ir(indice: int, nome: String)

var lista: Array = []       # [indice, nome, zen, nivel, mapa]
var portais := {}           # mapa -> [[numero, x1, y1, x2, y2, nivel, destino]]
var reducao := {}           # classe -> % a menos no nivel
var mapas := {}             # numero -> nome
var _caixa: VBoxContainer
var _rolagem: ScrollContainer
var _info: Label


func _ready() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://dados/movimento.json")) if FileAccess.file_exists("res://dados/movimento.json") else null
	if d is Dictionary:
		lista = d.lista
		portais = d.portais
		reducao = d.reducao
	JanelaMU.painel_mu(self)
	custom_minimum_size = Vector2(360, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var topo := HBoxContainer.new()
	v.add_child(topo)
	var t := Amigos._rotulo("Mover", 17, Color(1, 0.86, 0.45))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(t)
	var x := Button.new()
	x.text = "Fechar (M)"
	JanelaMU.botao_mu(x)
	x.pressed.connect(func(): visible = false)
	topo.add_child(x)
	var cab := HBoxContainer.new()
	v.add_child(cab)
	for c in [["Mapa", 170], ["Nivel", 60], ["Zen", 80]]:
		var l := Amigos._rotulo(c[0], 12, Color(0.65, 0.6, 0.5))
		l.custom_minimum_size.x = c[1]
		cab.add_child(l)
	_rolagem = ScrollContainer.new()
	_rolagem.custom_minimum_size = Vector2(340, 380)
	_rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_rolagem)
	_caixa = VBoxContainer.new()
	_caixa.add_theme_constant_override("separation", 2)
	_caixa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rolagem.add_child(_caixa)
	_info = Amigos._rotulo("", 12, Color(0.7, 0.7, 0.75))
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size.x = 330
	v.add_child(_info)
	visible = false


# nivel que o servidor pede pra essa classe (MG, DL e RF pedem 2/3; 400 vale pra todos)
func nivel_pedido(nivel: int, classe: int) -> int:
	var r := int(reducao.get(str(classe), 0))
	if nivel == 400 or r <= 0:
		return nivel
	return nivel * (100 - r) / 100


static func nome_bonito(n: String) -> String:
	# "Devias2" -> "Devias 2", "LostTower3" -> "Lost Tower 3", "KanturuRuins1" -> "Kanturu Ruins 1"
	var r := ""
	for i in n.length():
		var c := n[i]
		if i > 0 and ((c >= "A" and c <= "Z" and n[i - 1] >= "a") or (c >= "0" and c <= "9" and not (n[i - 1] >= "0" and n[i - 1] <= "9"))):
			r += " "
		r += c
	return r


func abrir(nivel: int, zen: int, classe: int) -> void:
	for c in _caixa.get_children():
		c.queue_free()
	var pode := 0
	for w in lista:
		var precisa := nivel_pedido(int(w[3]), classe)
		var tem_mapa := PacoteMapa.tem(int(w[4]) + 1)
		var falta_nivel := nivel < precisa
		var falta_zen := zen < int(w[2])
		var b := Button.new()
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(320, 24)
		b.add_theme_font_size_override("font_size", 13)
		var cor := Color(0.92, 0.92, 0.95)
		if falta_nivel:
			cor = Color(0.5, 0.5, 0.52)
		elif falta_zen:
			cor = Color(0.95, 0.6, 0.3)
		else:
			pode += 1
		b.add_theme_color_override("font_color", cor)
		b.add_theme_color_override("font_hover_color", Color(1, 0.86, 0.45) if not falta_nivel else cor)
		var nome := nome_bonito(str(w[1]))
		var linha := HBoxContainer.new()
		linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
		linha.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.add_child(linha)
		for c in [[nome + ("" if tem_mapa else "  *"), 170], [str(precisa), 60], [ItemChao._milhar(int(w[2])), 80]]:
			var l := Amigos._rotulo(c[0], 13, cor)
			l.custom_minimum_size.x = c[1]
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			linha.add_child(l)
		b.tooltip_text = "Precisa do nivel %d e %s zen." % [precisa, ItemChao._milhar(int(w[2]))]
		b.disabled = falta_nivel
		var idx := int(w[0])
		b.pressed.connect(func():
			visible = false
			ir.emit(idx, nome))
		_caixa.add_child(b)
	_info.text = "Nivel %d · %s zen · %d destinos pra ir agora.\n* mapa ainda sem cenario neste cliente (chao liso, so as posicoes)." % [nivel, ItemChao._milhar(zen), pode]
	visible = true
	move_to_front()
	await get_tree().process_frame
	position = Vector2(get_viewport_rect().size.x - size.x - 16, 70)


func alternar(nivel: int, zen: int, classe: int) -> void:
	if visible:
		visible = false
	else:
		abrir(nivel, zen, classe)


# portal do mapa embaixo de (x, y): [numero, x1, y1, x2, y2, nivel, destino] ou []
func portal_em(mapa: int, x: int, y: int) -> Array:
	for g in portais.get(str(mapa), []):
		if x >= int(g[1]) and x <= int(g[3]) and y >= int(g[2]) and y <= int(g[4]):
			return g
	return []
