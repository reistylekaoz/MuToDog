class_name Imperial
extends Control
# Imperial Fortress durante o evento (CNewUIEmpireGuardianTimer e GMEmpireGuardian1 do S6), na tela de 640x480
# colada embaixo (largura da janela / 640):
#   janela do tempo de 124x81 em (507, 342) (newui_Figure_blood, a mesma do Blood Castle): "Round %d (Zone %d)",
#     "Standby Time" em verde (tipo 0 e 1) ou "Time Left (Remaining Monsters)" em laranja (tipo 2) e o relogio
#     MM:SS(monstros) na fonte grande, laranja, laranja escuro nos 2 ultimos minutos e vermelho no ultimo.
#     Aparece no C1 F7 04 (o tempo e os monstros chegam a cada segundo) e some no resultado (F7 06).
#   clima (byte 7 do F7 02, sorteado pelo servidor): 1 chuva, 2 neblina (Map_Smoke1 somado na tela inteira,
#     duas camadas correndo), 3 tempestade (chuva e, 1 em 20 quadros, a fumaca somada correndo rapido). O som
#     de fundo segue o clima; no mapa 72 (Imperial Fortress 4, dentro) e sempre o mesmo e nao chove.

const SONS := "res://dados/mundo0/imperial/%s"   # musica, sons do clima, chuva e neblina: no pacote dos eventos
const MAPAS := [69, 70, 71, 72]
const SOL := 0
const CHUVA := 1
const NEBLINA := 2
const TEMPESTADE := 3

var mostrando := false      # INTERFACE_EMPIREGUARDIAN_TIMER
var tipo := 1
var ms := 600000
var monstros := 0
var dia := 1
var zona := 1
var clima := SOL
var mapa_atual := -1
var som: Som
var ambiente: Ambiente      # o jogo passa a do mapa: a chuva cai em volta do heroi
var _tex: Texture2D
var _neblina: Texture2D
var _relampago := false
var _camada := Control.new()  # a neblina, somada e repetindo, embaixo da janela do tempo


func _ready() -> void:
	_tex = load(Inventario.PASTA + "bc_tempo.png")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_camada.material = mat
	_camada.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_camada.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camada.set_anchors_preset(Control.PRESET_FULL_RECT)
	_camada.show_behind_parent = true
	_camada.draw.connect(_desenhar_neblina)
	add_child(_camada)


static func no_imperial(mapa: int) -> bool:
	return mapa in MAPAS


static func _carregar(nome: String) -> Resource:
	var c := SONS % nome
	return load(c) if ResourceLoader.exists(c) else null


# o jogo chama ao trocar de mapa: fora dos 4 mapas a janela, o clima e o som somem
func mapa(m: int) -> void:
	mapa_atual = m
	if not no_imperial(m):
		if mostrando:
			print("TESTE imperial saiu do mapa")
		mostrando = false
		clima = SOL
		if som:
			som.imperial = -1
	queue_redraw()


# C1 F7 02 resultado 0: entrou (ou zona nova): dia, zona, clima e quanto falta
func entrar(dia_: int, zona_: int, clima_: int, ms_: int) -> void:
	dia = dia_
	zona = zona_
	ms = ms_
	mudar_clima(clima_)
	print("TESTE imperial entrou dia %d zona %d clima %d" % [dia, zona, clima])


func mudar_clima(c: int) -> void:
	clima = c
	if som:
		som.imperial = 4 if mapa_atual == 72 else c
	if ambiente and is_instance_valid(ambiente):
		ambiente.chover(mapa_atual != 72 and (c == CHUVA or c == TEMPESTADE), _carregar("chuva.png"))
	if c == NEBLINA or c == TEMPESTADE:
		_neblina = _carregar("neblina.png")
	queue_redraw()
	_camada.queue_redraw()


# C1 F7 04
func tempo(tipo_: int, ms_: int, monstros_: int) -> void:
	if not mostrando or tipo_ != tipo:
		print("TESTE imperial tempo tipo %d %d ms %d monstros" % [tipo_, ms_, monstros_])
	mostrando = true
	tipo = tipo_
	ms = ms_
	monstros = monstros_
	queue_redraw()


# C1 F7 06: a janela some
func fim() -> void:
	mostrando = false
	queue_redraw()


func relogio() -> String:
	var s := ms / 1000
	return "%02d:%02d(%d)" % [s / 60, s % 60, monstros]


func cor_relogio() -> Color:
	var m := ms / 60000
	if m > 2:
		return Color8(255, 150, 0)
	if m > 0:
		return Color8(255, 70, 0)
	return Color8(255, 0, 0)


func _process(_dt: float) -> void:
	if no_imperial(mapa_atual) and clima == TEMPESTADE:
		# rand_fps_check(20): 1 em 20 quadros do cliente (25 por segundo)
		_relampago = randf() < get_process_delta_time() * 25.0 / 20.0
		_camada.queue_redraw()
	elif no_imperial(mapa_atual) and clima == NEBLINA:
		_camada.queue_redraw()


func _draw() -> void:
	var v := get_viewport_rect().size
	if not mostrando:
		return
	var e := v.x / 640.0
	var f := get_theme_default_font()
	draw_set_transform(Vector2.ZERO, 0, Vector2(e, e))
	var p := Vector2(507, v.y / e - 480 + 342)
	draw_texture_rect(_tex, Rect2(p, Vector2(124, 81)), false)
	_escrever(f, p + Vector2(7, 13), DicaItem.t(2805, [dia, zona]), 110, 10, Color.WHITE)
	if tipo == 2:
		_escrever(f, p + Vector2(7, 38), "%s (%s)" % [DicaItem.t(865), DicaItem.t(2845)], 110, 10, Color8(255, 150, 0))
	else:
		_escrever(f, p + Vector2(7, 38), DicaItem.t(2844), 110, 10, Color8(10, 200, 10))
	_escrever(f, p + Vector2(7, 50), relogio(), 110, 16, cor_relogio())
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


# RenderFrontSideVisual: RenderBitmapUV com EnableAlphaBlend (somado), o WorldTime em milissegundos
func _desenhar_neblina() -> void:
	if not (no_imperial(mapa_atual) and _neblina and (clima == NEBLINA or (clima == TEMPESTADE and _relampago))):
		return
	var v := _camada.get_viewport_rect().size   # o hud nao estica: o tamanho vem da tela
	var t := float(Time.get_ticks_msec() % 100000)
	var camadas := []
	if clima == NEBLINA:
		camadas = [[Vector2(t * 0.00005, t * 0.00008), Vector2(2, 2)], [Vector2(-t * 0.00005, 0), Vector2(0.3, 0.3)]]
	else:
		camadas = [[Vector2(t * 0.0006, -t * 0.0006), Vector2(3, 2)], [Vector2(-t * 0.0006, t * 0.0006), Vector2(3, 2)]]
	var ts := _neblina.get_size()
	for c in camadas:
		var uv: Vector2 = c[0]
		var esc: Vector2 = c[1]
		# a textura repete: a regiao de origem anda pelo uv e cobre esc vezes a textura
		_camada.draw_texture_rect_region(_neblina, Rect2(Vector2.ZERO, v), Rect2(uv * ts, esc * ts))


func _escrever(f: Font, p: Vector2, t: String, largura: float, tam: int, cor: Color) -> void:
	while tam > 7 and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > largura - 2:
		tam -= 1
	var q := p + Vector2(0, tam)
	draw_string_outline(f, q, t, HORIZONTAL_ALIGNMENT_CENTER, largura, tam, 2, Color(0, 0, 0, 0.9))
	draw_string(f, q, t, HORIZONTAL_ALIGNMENT_CENTER, largura, tam, cor)
