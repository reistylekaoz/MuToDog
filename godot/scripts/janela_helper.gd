class_name JanelaHelper
extends Loja
# Configuracao do MU Helper (tecla Z, CNewUIMuHelper do S6): duas abas, Caca e Itens.
# Salvar manda pro servidor (C2 AE) e ele devolve na proxima entrada; Padrao volta
# ao comeco. Cada linha e desenhada aqui mesmo e guarda o retangulo que responde ao
# clique (_areas).

signal salvar(dados: PackedByteArray)

var helper: MuHelper
var skills_de: Callable      # () -> Array dos numeros das minhas skills
var info_de: Callable        # numero -> [nome, alcance, tipo, ...]
var aba := 0
var _areas: Array = []       # [Rect2, Callable]
var _lista: Array = []       # escolha de skill aberta: [titulo, opcoes, Callable(n)]
var _campo: LineEdit
var _y := 0.0


func _ready() -> void:
	super._ready()
	for n in ["helper_opcao", "helper_menos", "helper_numero", "helper_texto", "bt_aceitar"]:
		_tex[n] = load(Inventario.PASTA + n + ".png")
	_campo = LineEdit.new()
	_campo.position = Vector2(22, 0)
	_campo.custom_minimum_size = Vector2(98, 16)
	_campo.size = Vector2(98, 16)
	_campo.max_length = 14
	_campo.placeholder_text = "nome do item"
	_campo.add_theme_font_size_override("font_size", 9)
	_campo.add_theme_stylebox_override("normal", _caixa_campo())
	_campo.add_theme_stylebox_override("focus", _caixa_campo())
	_campo.text_submitted.connect(func(_t): _adicionar_extra())
	add_child(_campo)


func _caixa_campo() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0.6)
	s.border_color = Color(0.45, 0.38, 0.25)
	s.set_border_width_all(1)
	s.content_margin_left = 3
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	return s


# na direita, como o inventario (o inventario fecha quando ela abre)
func _ajustar() -> void:
	super._ajustar()
	position.x = get_viewport_rect().size.x - L * _esc


func alternar() -> void:
	visible = not visible
	_lista = []
	queue_redraw()


func _draw() -> void:
	_areas.clear()
	draw_texture_rect(_tex.inv_fundo, Rect2(0, 0, L, A), false)
	draw_texture_rect(_tex.inv_topo, Rect2(0, 0, 190, 64), false)
	draw_texture_rect(_tex.inv_esq, Rect2(0, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_dir, Rect2(L - 21, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_baixo, Rect2(0, A - 45, 190, 45), false)
	var f := get_theme_default_font()
	_texto(f, Vector2(0, 16), "MU Helper", L, 11, Color(1, 0.9, 0.7))
	var c := helper.c
	# abas
	for i in 2:
		var r := Rect2(16 + 80 * i, 30, 76, 16)
		draw_rect(r, Color(0.35, 0.25, 0.1, 0.9) if aba == i else Color(0, 0, 0, 0.5))
		draw_rect(r, Color(0.6, 0.48, 0.25), false)
		_texto(f, r.position + Vector2(0, 12), ["Caca", "Itens"][i], 76, 9, Color(1, 0.86, 0.45) if aba == i else Color(0.7, 0.7, 0.75))
		_areas.append([r, func(): aba = i])
	_y = 62
	_campo.visible = aba == 1 and _lista.is_empty()
	if aba == 0:
		_numero(f, "Alcance da caca", "caca", 1, 8, 1, "")
		_skill(f, "Skill basica", 0)
		for i in [1, 2]:
			_skill(f, "Skill %d" % (i + 1), i)
			_opcao(f, 26, "a cada", c.por_tempo[i], func(): c.por_tempo[i] = not c.por_tempo[i])
			_numero_lista(f, 90, c.intervalo, i, 0, 60, 1, "s")
			_y += 15
			_opcao(f, 26, "se", c.por_condicao[i], func(): c.por_condicao[i] = not c.por_condicao[i])
			_alterna(f, 54, ["%d+ perto" % (2 + c.quantos[i]), "%d+ batendo" % (2 + c.quantos[i])][int(c.atacando[i])],
				func(): c.atacando[i] = not c.atacando[i])
			_numero_lista(f, 124, c.quantos, i, 0, 3, 1, "", true)
			_y += 17
		_opcao(f, 18, "Combo (as 3 em ordem)", c.combo, func(): c.combo = not c.combo)
		_y += 15
		_opcao(f, 18, "Golpe comum se faltar skill", c.golpe_comum, func(): c.golpe_comum = not c.golpe_comum)
		_y += 15
		_opcao(f, 18, "Contra-ataque de longe", c.contra_longe, func(): c.contra_longe = not c.contra_longe)
		_y += 15
		_opcao(f, 18, "Voltar apos", c.voltar, func(): c.voltar = not c.voltar)
		_numero_lista(f, 114, [c.segundos_longe], 0, 1, 15, 1, "s", false, func(v): c.segundos_longe = v)
		_y += 19
		for i in 3:
			_texto(f, Vector2(18, _y + 11), "Buff %d" % (i + 1), 60, 9, Color(1, 0.86, 0.45), HORIZONTAL_ALIGNMENT_LEFT)
			_caixa_skill(f, Rect2(72, _y, 100, 15), c.buffs[i], "Buff %d" % (i + 1), [10],
				func(n): c.buffs[i] = n)
			_y += 16
		_y += 1
		_opcao(f, 18, "Recolocar quando acabar" if c.buff_duracao else "Recolocar a cada", c.buff_duracao,
			func(): c.buff_duracao = not c.buff_duracao)
		if not c.buff_duracao:
			_numero_lista(f, 114, [c.buff_intervalo], 0, 0, 600, 10, "s", false, func(v): c.buff_intervalo = v)
		_y += 17
		_opcao(f, 18, "Pocao com vida", c.pocao, func(): c.pocao = not c.pocao)
		_numero_lista(f, 114, [c.pocao_pct], 0, 10, 90, 10, "%", false, func(v): c.pocao_pct = v)
		_y += 15
		_opcao(f, 18, "Heal com vida", c.cura, func(): c.cura = not c.cura)
		_numero_lista(f, 114, [c.cura_pct], 0, 10, 90, 10, "%", false, func(v): c.cura_pct = v)
		_y += 15
		_opcao(f, 18, "Drain Life com vida", c.drenar, func(): c.drenar = not c.drenar)
		_numero_lista(f, 114, [c.drenar_pct], 0, 10, 90, 10, "%", false, func(v): c.drenar_pct = v)
		_y += 15
		_opcao(f, 18, "Revidar quem me bater", c.defesa, func(): c.defesa = not c.defesa)
	else:
		_numero(f, "Alcance de pegar", "pegar", 1, 8, 1, "")
		_y += 4
		_opcao(f, 18, "Pegar tudo que cair perto", c.pegar_tudo, func(): c.pegar_tudo = not c.pegar_tudo)
		_y += 17
		_opcao(f, 18, "Pegar so o escolhido:", c.pegar_escolhidos, func(): c.pegar_escolhidos = not c.pegar_escolhidos)
		_y += 17
		for par in [["Zen", "zen"], ["Joias", "joia"], ["Itens de set", "set"], ["Excelentes", "exc"], ["Com o nome:", "extra"]]:
			var k: String = par[1]
			_opcao(f, 30, par[0], c[k], func(): c[k] = not c[k])
			_y += 15
		_campo.position.y = _y + 2
		var add := Rect2(124, _y + 2, 46, 16)
		_botao(f, add, "Por", _adicionar_extra)
		_y += 32
		for i in c.extras.size():
			_caixa_texto(Rect2(22, _y, 128, 16))
			_texto(f, Vector2(26, _y + 12), c.extras[i], 120, 9, Color(0.9, 0.9, 0.95), HORIZONTAL_ALIGNMENT_LEFT)
			var x := Rect2(154, _y, 16, 16)
			_botao(f, x, "x", func(): c.extras.remove_at(i))
			_y += 17
		if c.extras.is_empty():
			_texto(f, Vector2(22, _y + 11), "Ex.: Box of Luck, Jewel", 150, 8, Color(0.6, 0.6, 0.65), HORIZONTAL_ALIGNMENT_LEFT)
		_texto(f, Vector2(0, 360), "Pega o que tiver o nome escrito", L, 8, Color(0.6, 0.6, 0.65))
	# rodape: fechar, padrao e salvar
	var linha := 1 if Rect2(13, 391, 36, 29).has_point(_mouse) else 0
	draw_texture_rect_region(_tex.inv_sair, Rect2(13, 391, 36, 29), Rect2(0, 29 * linha, 36, 29))
	_areas.append([Rect2(13, 391, 36, 29), func(): fechar.emit()])
	_botao(f, Rect2(60, 394, 52, 22), "Padrao", func():
		helper.c = MuHelper.padrao()
		_padrao_skills())
	_botao(f, Rect2(118, 394, 56, 22), "Salvar", func():
		salvar.emit(helper.serializar()))
	if not _lista.is_empty():
		_desenhar_lista(f)


# caixa escura de texto (as do cliente sao claras e o texto branco some nelas)
func _caixa_texto(r: Rect2) -> void:
	draw_rect(r, Color(0, 0, 0, 0.6))
	draw_rect(r, Color(0.45, 0.38, 0.25), false)


func _padrao_skills() -> void:
	var l: Array = skills_de.call()
	for n in l:
		if int(info_de.call(n)[2]) in [0, 3, 4, 5]:
			helper.c.skills[0] = n
			return


func _adicionar_extra() -> void:
	var t := _campo.text.strip_edges()
	if t != "" and helper.c.extras.size() < 12 and t not in helper.c.extras:
		helper.c.extras.append(t)
	_campo.text = ""
	queue_redraw()


# --- pecas ----------------------------------------------------------------------

func _opcao(f: Font, x: float, rotulo: String, ligado: bool, ao_clicar: Callable) -> void:
	draw_texture_rect_region(_tex.helper_opcao, Rect2(x, _y, 13, 13), Rect2(0, 0 if ligado else 16, 16, 16))
	_texto(f, Vector2(x + 16, _y + 10), rotulo, 140, 9, Color(0.9, 0.9, 0.95) if ligado else Color(0.65, 0.65, 0.7), HORIZONTAL_ALIGNMENT_LEFT)
	var largura := f.get_string_size(rotulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 18
	_areas.append([Rect2(x, _y - 1, largura, 15), ao_clicar])


func _alterna(f: Font, x: float, rotulo: String, ao_clicar: Callable) -> void:
	var r := Rect2(x, _y, 66, 14)
	draw_rect(r, Color(0, 0, 0, 0.45))
	draw_rect(r, Color(0.45, 0.38, 0.25), false)
	_texto(f, Vector2(x, _y + 10), rotulo, 66, 8, Color(1, 0.86, 0.45))
	_areas.append([r, ao_clicar])


func _botao(f: Font, r: Rect2, rotulo: String, ao_clicar: Callable) -> void:
	var em_cima := r.has_point(_mouse)
	draw_rect(r, Color(0.45, 0.3, 0.1, 0.95) if em_cima else Color(0.3, 0.2, 0.08, 0.95))
	draw_rect(r, Color(0.75, 0.6, 0.3), false)
	_texto(f, r.position + Vector2(0, r.size.y / 2 + 4), rotulo, r.size.x, 9, Color(1, 0.9, 0.7))
	_areas.append([r, ao_clicar])


func _numero(f: Font, rotulo: String, chave: String, minimo: int, maximo: int, passo: int, sufixo: String) -> void:
	_texto(f, Vector2(18, _y + 11), rotulo, 100, 9, Color(0.9, 0.9, 0.95), HORIZONTAL_ALIGNMENT_LEFT)
	_numero_lista(f, 114, [helper.c[chave]], 0, minimo, maximo, passo, sufixo, false, func(v): helper.c[chave] = v)
	_y += 19


# [-] valor [+]; muda a[i] (ou chama "muda" com o valor novo)
func _numero_lista(f: Font, x: float, a: Array, i: int, minimo: int, maximo: int, passo: int, sufixo: String,
		escondido := false, muda := Callable()) -> void:
	draw_texture_rect_region(_tex.helper_menos, Rect2(x, _y, 14, 14), Rect2(0, 0, 16, 16))
	_texto(f, Vector2(x, _y + 10), "-", 14, 10, Color(1, 0.95, 0.8))
	# escondido: so as setinhas (o numero ja esta no texto do lado)
	var mais := x + 15 if escondido else x + 40
	if not escondido:
		_caixa_texto(Rect2(x + 15, _y, 24, 14))
		_texto(f, Vector2(x + 15, _y + 10), "%d%s" % [a[i], sufixo], 24, 8, Color(1, 1, 1))
	draw_texture_rect_region(_tex.helper_menos, Rect2(mais, _y, 14, 14), Rect2(0, 0, 16, 16))
	_texto(f, Vector2(mais, _y + 10), "+", 14, 10, Color(1, 0.95, 0.8))
	var muda_v := func(d: int):
		var v := clampi(int(a[i]) + d, minimo, maximo)
		if muda.is_valid():
			muda.call(v)
		else:
			a[i] = v
	_areas.append([Rect2(x, _y, 14, 14), func(): muda_v.call(-passo)])
	_areas.append([Rect2(mais, _y, 14, 14), func(): muda_v.call(passo)])


func _skill(f: Font, rotulo: String, i: int) -> void:
	_texto(f, Vector2(18, _y + 11), rotulo, 60, 9, Color(1, 0.86, 0.45), HORIZONTAL_ALIGNMENT_LEFT)
	_caixa_skill(f, Rect2(72, _y, 100, 15), helper.c.skills[i], rotulo, [0, 3, 4, 5], func(n): helper.c.skills[i] = n)
	_y += 17


func _caixa_skill(f: Font, r: Rect2, n: int, titulo: String, tipos: Array, escolher: Callable) -> void:
	_caixa_texto(r)
	var nome: String = info_de.call(n)[0] if n > 0 else "nenhuma"
	_texto(f, r.position + Vector2(3, 11), nome, r.size.x - 4, 8, Color(0.95, 0.95, 1) if n > 0 else Color(0.55, 0.55, 0.6), HORIZONTAL_ALIGNMENT_LEFT)
	_areas.append([r, func():
		var opcoes := [0]
		for k in skills_de.call():
			if int(info_de.call(k)[2]) in tipos:
				opcoes.append(k)
		_lista = [titulo, opcoes, escolher]])


func _desenhar_lista(f: Font) -> void:
	_areas.clear()
	var opcoes: Array = _lista[1]
	var r := Rect2(16, 60, 158, 26 + 16 * opcoes.size())
	draw_rect(r, Color(0.05, 0.04, 0.03, 0.97))
	draw_rect(r, Color(0.75, 0.6, 0.3), false)
	_texto(f, r.position + Vector2(0, 14), "Escolha: %s" % _lista[0], r.size.x, 9, Color(1, 0.86, 0.45))
	for k in opcoes.size():
		var n: int = opcoes[k]
		var lr := Rect2(r.position.x + 4, r.position.y + 20 + 16 * k, r.size.x - 8, 15)
		if lr.has_point(_mouse):
			draw_rect(lr, Color(0.45, 0.3, 0.1, 0.8))
		_texto(f, lr.position + Vector2(4, 11), info_de.call(n)[0] if n > 0 else "nenhuma", lr.size.x - 6, 9, Color(0.95, 0.95, 1), HORIZONTAL_ALIGNMENT_LEFT)
		var esc: Callable = _lista[2]
		_areas.append([lr, func():
			esc.call(n)
			_lista = []])
	_areas.append([Rect2(0, 0, L, A), func(): _lista = []])


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_mouse = ev.position
		for a in _areas:
			if a[0].has_point(ev.position):
				a[1].call()
				break
		queue_redraw()
		accept_event()
