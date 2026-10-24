class_name CaixaChat
extends Control
# A caixa de chat do cliente S6 (CNewUIChatInputBox): newui_chat_back de 281x47 logo acima da barra (0, 480-51-47),
# Enter abre e manda, Esc fecha, setas andam no historico. Em cima, botoes de 27x26: normal, grupo, guilda e Gens
# (o "_on" marca o escolhido), bloquear cochicho (4*27+6), mensagens do sistema e o registro do chat. O campo do
# texto (176x14 em 72,32, cor 255,255,230) e o do nome do cochicho (50x14 em 5,32, ate 10, cor 255,200,200).
# Grupo vai com "~" na frente, guilda com "@", Gens com "$"; com nome no cochicho vai C1 02. "/comando" vai puro.

signal falar(texto: String, para: String)       # para != "": cochicho
signal botao_registro(ligado: bool)
signal botao_sistema(ligado: bool)

const PASTA := "res://dados/hud/"
const L := 281.0
const A := 47.0
const BOTAO := Vector2(27, 26)
const PREFIXO := ["", "~", "@", "$"]
const DICAS := [1681, 1682, 1683, 3321, 1684, 1685, 750]

var tipo := 0                  # 0 normal, 1 grupo, 2 guilda, 3 Gens
var bloquear_cochicho := false
var sistema := true
var registro := true
var historico: Array[String] = []
var _passo := -1
var _ultimo_envio := -10000
var _tex := {}
var _esc := 1.0
var _mouse := Vector2(-100, -100)
var texto: LineEdit
var para: LineEdit


func _init() -> void:
	texto = JanelaMU.campo(59, Color8(255, 255, 230))
	texto.position = Vector2(72, 32)
	texto.size = Vector2(176, 14)
	texto.text_submitted.connect(func(_t): enviar())
	texto.gui_input.connect(_tecla_campo)
	add_child(texto)
	para = JanelaMU.campo(10, Color8(255, 200, 200))
	para.position = Vector2(5, 32)
	para.size = Vector2(50, 14)
	para.text_submitted.connect(func(_t): texto.grab_focus())
	para.gui_input.connect(_tecla_campo)
	add_child(para)


func _ready() -> void:
	for n in ["chat_back", "chat_normal_on", "chat_party_on", "chat_guild_on", "chat_gens_on", "chat_whisper_on",
			"chat_system_on", "chat_chat_on"]:
		_tex[n] = load(PASTA + n + ".png")
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()
	JanelaMU.altura_campos(self)
	visible = false


func _ajustar() -> void:
	var v := get_viewport_rect().size
	_esc = v.x / 640.0
	scale = Vector2(_esc, _esc)
	size = Vector2(L, A)
	position = Vector2(0, v.y - (51.0 + A) * _esc)


func abrir(nome_cochicho := "") -> void:
	visible = true
	if nome_cochicho != "":
		para.text = nome_cochicho
	texto.grab_focus()
	queue_redraw()


func fechar() -> void:
	visible = false
	texto.release_focus()
	para.release_focus()


# Enter no campo: manda (com o prefixo do tipo) e fecha; vazio so fecha
func enviar() -> void:
	var t := texto.text.strip_edges()
	texto.text = ""
	_passo = -1
	if t == "":
		fechar()
		return
	if Time.get_ticks_msec() - _ultimo_envio < 1000 and not historico.is_empty() and historico[-1] == t:
		fechar()
		return
	_ultimo_envio = Time.get_ticks_msec()
	historico.append(t)
	if historico.size() > 12:
		historico.pop_front()
	var nome := para.text.strip_edges()
	if nome != "" and not t.begins_with("/"):
		falar.emit(t, nome)
	else:
		falar.emit(t if t.begins_with("/") else PREFIXO[tipo] + t, "")
	fechar()


func _tecla_campo(ev: InputEvent) -> void:
	if not ev is InputEventKey or not ev.pressed:
		return
	if ev.keycode == KEY_ESCAPE:
		fechar()
		accept_event()
	elif ev.keycode in [KEY_UP, KEY_DOWN] and not historico.is_empty():
		if ev.keycode == KEY_UP:
			_passo = historico.size() - 1 if _passo < 0 else maxi(_passo - 1, 0)
		else:
			_passo = mini(_passo + 1, historico.size() - 1) if _passo >= 0 else -1
		if _passo >= 0:
			texto.text = historico[_passo]
			texto.caret_column = texto.text.length()
		accept_event()
	elif ev.keycode == KEY_TAB:
		(para if texto.has_focus() else texto).grab_focus()
		accept_event()


func _botao(i: int) -> Rect2:
	var x: int = [0, 27, 54, 81, 114, 141, 168][i]
	return Rect2(Vector2(x, 0), BOTAO)


func _draw() -> void:
	draw_texture_rect(_tex.chat_back, Rect2(0, 0, L, A), false)
	var on := ["chat_normal_on", "chat_party_on", "chat_guild_on", "chat_gens_on"]
	draw_texture_rect(_tex[on[tipo]], _botao(tipo), false)
	if bloquear_cochicho:
		draw_texture_rect(_tex.chat_whisper_on, _botao(4), false)
		draw_rect(Rect2(2, 28, 61, 17), Color8(0x80, 0x33, 0x33, 0x33))
	if sistema:
		draw_texture_rect(_tex.chat_system_on, _botao(5), false)
	if registro:
		draw_texture_rect(_tex.chat_chat_on, _botao(6), false)
	for i in 7:
		if _botao(i).has_point(_mouse):
			var t := DicaItem.t(DICAS[i])
			var f := get_theme_default_font()
			var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			var x := maxf(_botao(i).position.x + 10 - w / 2, 0)
			draw_rect(Rect2(x, -14, w + 6, 13), Color8(0, 0, 0, 180))
			draw_string(f, Vector2(x + 3, -4), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		for i in 7:
			if _botao(i).has_point(ev.position):
				if i < 4:
					tipo = i
				elif i == 4:
					bloquear_cochicho = not bloquear_cochicho
				elif i == 5:
					sistema = not sistema
					botao_sistema.emit(sistema)
				else:
					registro = not registro
					botao_registro.emit(registro)
		texto.grab_focus()
		queue_redraw()
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_mouse = Vector2(-100, -100)
		queue_redraw()
