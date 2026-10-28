class_name JanelaGatekeeper
extends PainelLateral
# Gatekeeper do Valley of Loren (CNewUIGatemanWindow + CUIGateKeeper, NPC 220): abre com o C1 B9 03 (tipo 1
# visitante, 2 da alianca dona, 3 mestre da guilda dona; 0 = caixa de falha), preco atual, maximo e passo.
# Visitante: com a entrada aberta paga o preco e entra (B9 05 com o preco), sem zen a caixa 1628; fechada, as
# frases 1627/1629/1630/1631 e Enter apagado. Membro: so a pergunta e Enter. Mestre: abrir pra quem nao e da
# guilda (C1 B2 1F), preco com as setas (passo do servidor, 0 ao maximo), Confirm manda o imposto 3 (C1 B2 09) e Enter.

signal entrar(preco: int)
signal publico(sim: bool)          # C1 B2 1F: so o mestre
signal mudar_preco(preco: int)     # C1 B2 09 tipo 3
signal sem_zen

var tipo := 1
var aberto := false
var preco := 0          # o que vale agora
var maximo := 0
var passo := 0
var visto := 0          # o que o mestre esta escolhendo (m_iViewEntranceFee)
var meu_zen := 0


func abrir(t: int, ab: bool, p: int, mx: int, ps: int) -> void:
	tipo = t
	aberto = ab
	preco = p
	maximo = mx
	passo = ps
	visto = p
	visible = true
	print("TESTE gatekeeper tipo %d aberto %s preco %d maximo %d passo %d" % [t, ab, p, mx, ps])
	queue_redraw()


# C1 B2 1F (ReceiveHuntZoneEnter): a entrada mudou
func mudou_publico(sim: bool) -> void:
	print("TESTE gatekeeper entrada aberta %s" % sim)
	aberto = sim
	queue_redraw()


func _conteudo() -> void:
	texto(Vector2(15, 13 + 9), DicaItem.t(1596), 160, Color8(220, 220, 220), true)
	match tipo:
		3: _mestre()
		2: _membro()
		_: _visitante()


func _visitante() -> void:
	var y := 50.0 + 9
	if aberto:
		texto(Vector2(0, y), DicaItem.t(1632) % zen(preco), L, Color8(255, 100, 50) if preco > meu_zen else Color8(255, 255, 100))
		texto(Vector2(0, y + 10), DicaItem.t(1633), L)
		texto(Vector2(0, y + 20), DicaItem.t(1634), L)
	else:
		for i in 4:
			texto(Vector2(0, y + i * 10), DicaItem.t([1627, 1629, 1630, 1631][i]), L)
	botao("entrar", Rect2(L / 2 - 27, 100, 53, 23), DicaItem.t(1593), aberto)


func _membro() -> void:
	texto(Vector2(0, 50 + 9), DicaItem.t(1634), L)
	botao("entrar", Rect2(L / 2 - 27, 100, 53, 23), DicaItem.t(1593))


func _mestre() -> void:
	var y := 50.0
	texto(Vector2(0, y + 9), DicaItem.t(1597), L, Color.WHITE, true)
	y += 20
	texto(Vector2(0, y + 9), DicaItem.t(1624), L)
	texto(Vector2(0, y + 19), DicaItem.t(1625), L)
	texto(Vector2(0, y + 29), DicaItem.t(1626), L)
	y += 40
	caixa_marcar(Vector2(35, y), aberto)
	texto(Vector2(55, y + 9), DicaItem.t(1598), 0)
	y += 18
	texto(Vector2(35, y + 9), DicaItem.t(1602) % zen(preco), 0)
	draw_rect(Rect2(20, y + 52, 90, 30), Color(0, 0, 0, 0.3))
	y += 30
	texto(Vector2(0, y + 9), DicaItem.t(1599), L, Color.WHITE, true)
	texto(Vector2(0, y + 32 + 9), "%s %s" % [zen(visto), DicaItem.t(224)], 80, Color.WHITE, false, HORIZONTAL_ALIGNMENT_RIGHT)
	botao("mais", Rect2(118, 180, 15, 13), "", true, "seta_cima")
	botao("menos", Rect2(118, 196, 15, 13), "", true, "seta_baixo")
	botao("confirmar", Rect2(L / 2 - 27, 220, 53, 23), DicaItem.t(1619))
	y = 250.0
	texto(Vector2(0, y + 9), DicaItem.t(1600) % zen(maximo), L)
	texto(Vector2(0, y + 22), DicaItem.t(1601), L)
	texto(Vector2(0, y + 35), DicaItem.t(1618) % zen(passo), L)
	botao("entrar", Rect2(L / 2 - 27, 320, 53, 23), DicaItem.t(1593))


func _clique(p: Vector2) -> void:
	if tipo == 3 and Rect2(35, 110, 100, 16).has_point(p):
		publico.emit(not aberto)
		return
	match botao_em(p):
		"mais":
			visto = mini(visto + passo, maximo)
		"menos":
			visto = maxi(visto - passo, 0)
		"confirmar":
			mudar_preco.emit(visto)
		"entrar":
			if tipo == 1 and preco > meu_zen:
				sem_zen.emit()
				return
			entrar.emit(visto if tipo == 3 else preco)
			fechar()
