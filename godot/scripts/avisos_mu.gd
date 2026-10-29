class_name AvisosMU
extends Control
# Avisos do meio da tela como o UI::Notices do cliente (HUD/Notices.cpp): ate 6 linhas centradas em x 320,
# de y 300 em diante de 13 em 13 (tela de 640 x 480), letra negrito com faixa preta pela metade. Aviso global
# (tipo 0 do C1 0D) em dourado 255,200,80 piscando a cada 10 quadros; aviso da guilda (tipo 2) em 100,255,200.
# A cada 300 quadros (12 s a 25 por segundo) entra uma linha vazia embaixo e a de cima sai.

const MAX := 6
const VIDA := 12.0

var _linhas: Array = []   # [texto, cor 0 ou 1]
var _tempo := VIDA
var _fase := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func criar(texto: String, cor := 0) -> void:
	var f := get_theme_default_font()
	# texto largo demais quebra em duas linhas, como o CutText
	if f.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x > 600 and texto.contains(" "):
		var meio := texto.length() / 2
		var corte := texto.rfind(" ", meio)
		if corte <= 0:
			corte = texto.find(" ", meio)
		_empurrar(texto.substr(0, corte), cor)
		_empurrar(texto.substr(corte + 1), cor)
	else:
		_empurrar(texto, cor)
	_tempo = VIDA
	print("TESTE aviso centro %s" % texto)
	queue_redraw()


func _empurrar(t: String, cor: int) -> void:
	_linhas.append([t, cor])
	while _linhas.size() > MAX:
		_linhas.pop_front()


func _process(dt: float) -> void:
	if _linhas.is_empty():
		return
	_fase += dt * 25.0
	_tempo -= dt
	if _tempo <= 0.0:
		_tempo = VIDA
		_empurrar("", 0)
		while not _linhas.is_empty() and _linhas.all(func(l): return l[0] == ""):
			_linhas.clear()
	queue_redraw()


func _draw() -> void:
	var v := get_viewport_rect().size
	var e := v.x / 640.0
	var f := get_theme_default_font()
	var tam := int(10 * e)
	# o vetor de 6 do cliente: a primeira linha em y 300 e as outras embaixo; cheio, sobe uma
	var ini := 0
	for i in _linhas.size():
		var t: String = _linhas[i][0]
		if t == "":
			continue
		var cor := Color8(100, 255, 200)
		if _linhas[i][1] == 0:
			cor = Color8(255, 200, 80, 128 if int(_fase) % 10 < 5 else 255)
		var y := (300.0 + (ini + i) * 13.0) * v.y / 480.0
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		var x := (v.x - w) / 2.0
		draw_rect(Rect2(x - 2 * e, y, w + 4 * e, 13.0 * v.y / 480.0), Color(0, 0, 0, 0.5))
		var base := Vector2(x, y + 10.0 * v.y / 480.0)
		draw_string(f, base, t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)
		draw_string(f, base + Vector2(0.6 * e, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)
