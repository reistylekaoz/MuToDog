class_name JanelaArqueiro
extends PainelLateral
# Golden Archer (CNewUIGoldBowmanLena, NPC 236): o C1 94 com resultado 0 abre (e responde a cada registro) com as
# Renas registradas e quantas tenho. Textos 700 a 702 do evento, 245/246 em dourado com "    X    n" embaixo e o
# icone da Rena (14,21), 703/704 em violeta. Registering Rena (243, botao vazio de 108x29 no 45,285) manda o C1 95
# com o tipo 0 e a casa da primeira Rena; fechar manda o C1 97.

signal registrar(casa: int)

const RENA := {"grupo": 14, "numero": 21, "nivel": 0}

var nome := "Golden Archer"
var registradas := 0
var itens := {}          # a mochila (inventario.itens), pra contar e achar a Rena


func _ready() -> void:
	super()
	topo = "inv_topo04"


func abrir(reg: int) -> void:
	registradas = reg
	visible = true
	print("TESTE arqueiro registradas %d na_mochila %d" % [reg, quantas()])
	queue_redraw()


func quantas() -> int:
	var n := 0
	for s in itens:
		if s >= 12 and itens[s].grupo == 14 and itens[s].numero == 21:
			n += 1
	return n


func casa_rena() -> int:
	var l: Array = itens.keys()
	l.sort()
	for s in l:
		if s >= 12 and itens[s].grupo == 14 and itens[s].numero == 21:
			return s
	return -1


func _conteudo() -> void:
	texto(Vector2(0, 15 + 9), nome, L)
	for i in 3:
		texto(Vector2(0, 100 + i * 15 + 9), DicaItem.t(700 + i), L)
	var ouro := Color8(0xFA, 0xDF, 0x47)   # 0xFF47DFFA em ABGR
	texto(Vector2(20, 180 + 9), DicaItem.t(245), 0, ouro)
	texto(Vector2(5, 202 + 9), "    X    %d" % quantas(), L)
	texto(Vector2(20, 225 + 9), DicaItem.t(246), 0, ouro)
	texto(Vector2(5, 245 + 9), "    X    %d" % registradas, L)
	ItensMU.desenhar(self, RENA, Rect2(58, 196, 24, 24))
	ItensMU.desenhar(self, RENA, Rect2(58, 238, 24, 24))
	botao("registrar", Rect2(45, 285, 108, 29), DicaItem.t(243), true, "btn_vazio")
	for j in 2:
		texto(Vector2(0, 350 + j * 15 + 9), DicaItem.t(703 + j), L, Color8(0xD6, 0x47, 0xFA))


func _clique(p: Vector2) -> void:
	if botao_em(p) == "registrar":
		var c := casa_rena()
		if c >= 0:
			registrar.emit(c)
