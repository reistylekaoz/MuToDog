class_name JanelaAjuda
extends JanelaMU
# Os comandos e atalhos do jogo numa janela do cliente (a mesma familia do My Friend). Abre no botao "?" da placa
# de cima ou no F1, como a ajuda do cliente original.

const LINHAS := [
	["Mouse", ""],
	["Clique esquerdo", "anda, ataca, pega item, fala com NPC"],
	["Clique direito", "usa a skill escolhida"],
	["Ctrl + clique", "ataca outro jogador"],
	["Setas", "giram a camera"],
	["Roda do mouse", "aproxima e afasta"],
	["Teclado", ""],
	["1 a 0", "troca a skill (mouse na lista: grava)"],
	["Shift + 1 a 4", "ordens do corvo"],
	["Q W E R", "usam as pocoes da barra"],
	["Alt", "nome de todos os itens do chao"],
	["Enter", "escreve no chat"],
	["I ou V", "inventario"],
	["C", "personagem"],
	["A", "arvore de master"],
	["T", "minhas quests"],
	["F", "amigos"],
	["G", "guilda"],
	["B", "gens"],
	["D", "comandos (troca, grupo, duelo)"],
	["J", "comandos do chat"],
	["M", "mover de mapa"],
	["Tab", "minimapa"],
	["S", "loja pessoal"],
	["X", "loja de cash"],
	["Z", "configurar o MU Helper"],
	["Home", "liga e desliga o MU Helper"],
	["U ou Esc", "menu (Esc fecha a janela de cima)"],
	["- e =", "brilho"],
	["F1", "esta ajuda"],
]
const ALTURA := 12.0


func _init() -> void:
	super("Comandos e atalhos", 330.0, 21.0 + LINHAS.size() * ALTURA + 34.0)


func abrir() -> void:
	centrar()
	visible = true
	trazer()
	print("TESTE ajuda aberta")


func alternar() -> void:
	if visible:
		fechar()
	else:
		abrir()


func _conteudo() -> void:
	var y := TITULO + 4.0
	for l in LINHAS:
		if l[1] == "":
			texto(Vector2(10, y), l[0], Color8(255, 204, 26), true)
		else:
			texto(Vector2(16, y), l[0], Color8(127, 178, 255))
			texto(Vector2(104, y), l[1], TEXTO, false, L - 112)
		y += ALTURA
	botao("fechar", Rect2((L - 49) / 2, A - 26, 49, 16), "Fechar")


func _apertou(nome: String) -> void:
	if nome == "fechar":
		fechar()
