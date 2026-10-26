class_name JanelaImperial
extends JanelaDoppel
# Entrada do Imperial Fortress pelo Jerint the Assistant (CNewUIEmpireGuardianNPC, NPC janela 0x24): a mesma
# moldura do Lugard, "Without Gaion's Order," e o resto da fala quebrado a 150, "Will you show me the order?",
# o Gaion's Order (14,102) desenhado com o nome em negrito amarelo, o Enter (em 190), a linha, o aviso em
# vermelho (o domingo so com o Complete Secromicon; so em grupo, quebrado a 155) e o Close (em 380).
# Enter manda C1 F7 01; quem responde e o F7 02 (caixa no jogo), entao o botao nao trava.

const ORDEM := {"grupo": 14, "numero": 102}


func abrir(min_: int) -> void:
	minutos = min_
	travado = false
	var f := get_theme_default_font()
	_linhas.clear()
	_linhas.append_array(cortar(f, DicaItem.t(2796), 150))
	_linhas.append_array(cortar(f, DicaItem.t(2838), 155))
	visible = true
	queue_redraw()


func resultado(_r: int) -> void:
	pass


func _botao(i: int) -> Rect2:
	return Rect2(68, 190 if i == 0 else 380, 54, 23)


func _draw() -> void:
	draw_texture_rect(_tex.inv_fundo, Rect2(0, 0, L, A), false)
	draw_texture_rect(_tex.inv_topo, Rect2(0, 0, 190, 64), false)
	draw_texture_rect(_tex.inv_esq, Rect2(0, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_dir, Rect2(L - 21, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_baixo, Rect2(0, A - 45, 190, 45), false)
	var f := get_theme_default_font()
	var cinza := Color8(220, 220, 220)
	_texto(f, Vector2(15, 13), DicaItem.t(2794), 160, 11, cinza, true)
	_texto(f, Vector2(0, 50), DicaItem.t(2795), L, 10, cinza)
	if _linhas.size() >= 4:
		_texto(f, Vector2(0, 70), _linhas[0], L, 10, cinza)
		_texto(f, Vector2(0, 90), _linhas[1], L, 10, cinza)
	_texto(f, Vector2(0, 110), DicaItem.t(2797), L, 10, cinza)
	ItensMU.desenhar(self, ORDEM, Rect2((L - 20) / 2, 120, 20, 27))
	_texto(f, Vector2(0, 170), DicaItem.t(2783), L, 10, Color8(255, 240, 0), true)
	draw_texture_rect(_tex.quest_linha, Rect2(1, 220, 188, 21), false)
	_texto(f, Vector2(0, 260), DicaItem.t(2223), L, 10, Color8(255, 0, 0), true)
	for i in 3:
		_texto(f, Vector2(0, 280 + 20 * i), DicaItem.t(2835 + i), L, 10, cinza)
	if _linhas.size() >= 4:
		_texto(f, Vector2(0, 340), _linhas[2], L, 10, cinza)
		_texto(f, Vector2(0, 360), _linhas[3], L, 10, cinza)
	for i in 2:
		var r := _botao(i)
		var estado := 0
		if r.has_point(_mouse):
			estado = 2 if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 1
		draw_texture_rect_region(_tex.btn_mini, r, Rect2(0, 23 * estado, 54, 23))
		_texto(f, Vector2(r.position.x, r.position.y + 5), DicaItem.t(1593 if i == 0 else 388), 54, 10, Color.WHITE)
