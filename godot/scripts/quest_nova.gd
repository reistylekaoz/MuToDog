class_name QuestNova
extends RefCounted
# Quests novas do S6 (F6), na logica do CQuestMng do MuMain. Cada passo de quest e um indice
# (grupo << 16) | passo; o QuestProgress.bmd diz a fala do NPC, a do jogador, ate 5 respostas,
# o assunto e o resumo (ferramentas/dados_quest_nova.py -> dados/quest_nova.json). Passo sem
# respostas mostra o que a quest pede e o que da (F6 0C / 1B, guardado em info).
# Os tipos de pedido sao os do OpenMU (ConditionType): 1 monstros, 2 skill, 4 item, 8 nivel,
# 16 acao no cliente, 32 buff do NPC. Premio: 1 exp, 2 zen, 4 item, 16 contribuicao; 0x20 = sorteado.

const PEDIDO_MONSTRO := 1
const PEDIDO_SKILL := 2
const PEDIDO_ITEM := 4
const PEDIDO_NIVEL := 8
const PEDIDO_ACAO := 16
const PEDIDO_BUFF := 32
const SORTEADO := 0x20

const COR_TITULO := Color8(179, 230, 77)
const COR_OK := Color8(223, 191, 103)
const COR_FALTA := Color8(255, 30, 30)
const COR_SORTEADO := Color8(103, 103, 223)

var passos := {}
var palavras := {}
var ativas: Array = []      # indices em andamento (F6 1A, depois atualizado), em ordem
var info := {}              # indice -> {numero, grupo, pedidos, premios} do ultimo F6 0C / 1B
var monstros := {}          # dados/monstros.json (o jogo passa)
var textos := {}            # dados/textos_eng.json


func _init() -> void:
	if FileAccess.file_exists("res://dados/quest_nova.json"):
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://dados/quest_nova.json"))
		if d is Dictionary:
			passos = d.passos
			palavras = d.palavras
	if FileAccess.file_exists("res://dados/textos_eng.json"):
		textos = JSON.parse_string(FileAccess.get_file_as_string("res://dados/textos_eng.json"))


static func indice(numero: int, grupo: int) -> int:
	return (grupo << 16) | numero


func _passo(i: int) -> Array:
	return passos.get(str(i), [0, "", "", [], "", ""])


func tem(i: int) -> bool:
	return passos.has(str(i))


func por_outro(i: int) -> bool:   # janela "ByEtc" (quest que nao vem de NPC)
	return int(_passo(i)[0]) == 1


func fala_npc(i: int) -> String:
	return _passo(i)[1]


func fala_jogador(i: int) -> String:
	return _passo(i)[2]


func respostas(i: int) -> Array:
	return _passo(i)[3]


func assunto(i: int) -> String:
	return _passo(i)[4]


func resumo(i: int) -> String:
	return _passo(i)[5]


func texto(n: int) -> String:
	return str(textos.get(str(n), ""))


func palavra(n: int) -> String:
	return str(palavras.get(str(n), ""))


# AddCurQuestIndexList: o passo novo de um grupo troca o anterior; 0 e 0xFF tiram o grupo da lista
func atualizar_ativa(i: int) -> void:
	var grupo := i >> 16
	var passo := i & 0xFFFF
	ativas = ativas.filter(func(x): return x >> 16 != grupo)
	if passo != 0 and passo != 0xFF:
		ativas.append(i)
	ativas.sort()


func tirar_grupo(grupo: int) -> void:
	ativas = ativas.filter(func(x): return x >> 16 != grupo)


# GetRequestRewardText: as linhas [texto, cor, titulo?, item ou {}] e se os pedidos estao cumpridos
func linhas(i: int) -> Array:
	var q: Dictionary = info.get(i, {})
	var l := []
	var cumpriu := true
	l.append([texto(2809), COR_TITULO, true, {}])
	var pedidos: Array = q.get("pedidos", [])
	if pedidos.is_empty():
		l.append([texto(1361), COR_OK, false, {}])
	for p in pedidos:
		var ok := false
		var t := ""
		var it := {}
		match int(p.tipo):
			PEDIDO_MONSTRO:
				ok = p.feitos >= p.quantos
				t = "%s x %d/%d" % [_monstro(p.id), mini(p.feitos, p.quantos), p.quantos]
			PEDIDO_ITEM:
				ok = p.feitos >= p.quantos
				it = p.get("item", {})
				t = "%s x %d/%d" % [ItensMU.nome(it) if not it.is_empty() else "Item", mini(p.feitos, p.quantos), p.quantos]
			PEDIDO_NIVEL:
				ok = p.feitos >= p.quantos
				t = "Level %d" % p.quantos
			PEDIDO_SKILL:
				ok = p.feitos > 0
				t = "Skill %d" % p.id
			PEDIDO_ACAO:
				ok = p.feitos == 1
				t = texto(2819) if i == 0x10009 else (texto(2820) if i == 0x1000F else "Action")
			PEDIDO_BUFF:
				ok = p.feitos > 0
				t = "Buff"
			_:
				ok = p.feitos >= p.quantos
				t = "? x %d/%d" % [mini(p.feitos, p.quantos), p.quantos]
		cumpriu = cumpriu and ok
		l.append([t, COR_OK if ok else COR_FALTA, false, it])
	var premios: Array = q.get("premios", [])
	var gerais := premios.filter(func(r): return int(r.tipo) & SORTEADO == 0)
	var sorteados := premios.filter(func(r): return int(r.tipo) & SORTEADO != 0)
	if not gerais.is_empty():
		l.append(["", COR_OK, false, {}])
		l.append([texto(2810), COR_TITULO, true, {}])
		for r in gerais:
			l.append(_premio(r, COR_OK))
	if not sorteados.is_empty():
		l.append(["", COR_OK, false, {}])
		l.append([texto(3082).replace("%lu", str(sorteados.size())), COR_TITULO, true, {}])
		for r in sorteados:
			l.append(_premio(r, COR_SORTEADO))
	return [l, cumpriu and not pedidos.is_empty()]


func _premio(r: Dictionary, cor: Color) -> Array:
	match int(r.tipo) & 0x1F:
		1:
			return ["Exp %s" % ItemChao._milhar(r.quanto), cor, false, {}]
		2:
			return ["%s Zen" % ItemChao._milhar(r.quanto), cor, false, {}]
		4:
			var it: Dictionary = r.get("item", {})
			return ["%s x %d" % [ItensMU.nome(it) if not it.is_empty() else "Item", r.quanto], cor, false, it]
		16:
			return [texto(2994).replace("%lu", str(r.quanto)), cor, false, {}]
	return [texto(1361), cor, false, {}]


func _monstro(n: int) -> String:
	return str(monstros.get(str(n), ["Monstro %d" % n])[0])
