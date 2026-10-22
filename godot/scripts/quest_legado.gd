class_name QuestLegado
extends RefCounted
# Quests antigas do S6 (troca de classe), na logica do CSQuest do MuMain:
# o servidor manda o estado de cada quest em 2 bits (4 por byte): 1 ativa, 2 feita, 3 nao comecou.
# As quests e as falas vem do Quest_eng.bmd e Dialog_eng.bmd (ferramentas/dados_quest.py ->
# dados/quest_legado.json). Cada quest tem "acts" (o que pede, por classe) e "pedidos" (nivel,
# quest anterior, zen); a fala mostrada sai das 4 falas do act da classe:
# 0 oferecendo, 1 ainda falta, 2 trouxe tudo, 3 ja feita.

const ATIVA := 1
const FEITA := 2
const NAO := 3
const ITEM := 1
const MONSTRO := 2
const COMBO := 3    # Secret of the Dark Stone: so o cavaleiro faz

var quests: Array = []
var falas: Dictionary = {}
var estados := PackedByteArray()
var atual := 0          # quest que o NPC esta mostrando
var classe := 0         # classe base (0 DW, 1 DK, 2 elfa, 3 MG, 4 DL, 5 summoner, 6 RF)
var mortes: Array = []  # [[monstro, mortes] x5] do C1 A4
var pagina := 0
var zen_preciso := 0
var erro := false
# o que o personagem tem (o jogo preenche antes de perguntar): nivel, zen e os itens da mochila
var nivel := 0
var zen := 0
var itens: Array = []


func _init() -> void:
	estados.resize(50)
	if FileAccess.file_exists("res://dados/quest_legado.json"):
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://dados/quest_legado.json"))
		if d is Dictionary:
			quests = _inteiros(d.quests)
			falas = _inteiros(d.falas)


# o JSON le todo numero como float: "1.0 in [1, 2]" da falso e str(235.0) e "235.0"
static func _inteiros(v: Variant) -> Variant:
	if v is float:
		return int(v)
	if v is Array:
		return v.map(_inteiros)
	if v is Dictionary:
		var r := {}
		for k in v:
			r[k] = _inteiros(v[k])
		return r
	return v


func estado(i: int) -> int:
	if i < 0 or i / 4 >= estados.size():
		return 0
	return (estados[i / 4] >> ((i % 4) * 2)) & 3


# C1 A0: a lista inteira; a quest atual e a primeira nao feita (a ordem depende da classe)
func definir_lista(n: int, bytes: PackedByteArray, classe_openmu: int) -> void:
	classe = classe_openmu >> 2
	estados.fill(0)
	for i in mini(bytes.size(), estados.size()):
		estados[i] = bytes[i]
	var i := 4 if classe in [3, 4, 6] else 0
	while i < n:
		if not (classe != 1 and i == COMBO) and estado(i) != FEITA:
			break
		i += 1
	atual = i


# C1 A1 e A2: o byte inteiro das 4 quests do grupo da quest
func definir(i: int, byte: int) -> void:
	atual = i
	if i / 4 < estados.size():
		estados[i / 4] = byte


func quest() -> Dictionary:
	return quests[atual] if atual >= 0 and atual < quests.size() else {}


func titulo() -> String:
	return quest().get("nome", "")


# os acts dessa quest que valem pra minha classe
func acts() -> Array:
	return quest().get("acts", []).filter(func(a): return a.classes[classe] >= 1)


func _fala_do_act(k: int) -> int:
	var a := acts()
	if not a.is_empty():
		return a[0].falas[k]
	# nenhum act pra minha classe: o original volta uma quest e confere de novo
	if atual > 0:
		atual -= 1
		return pagina_npc()
	return pagina


# pedidos que valem pros acts da minha classe (tipo 255 vale pra todos)
func _confere_pedidos(com_zen: bool) -> bool:
	var q := quest()
	for a in acts():
		for r in q.get("pedidos", []):
			if r.tipo != a.pedido and r.tipo != 255:
				continue
			if r.feita >= 0 and estado(r.feita) != FEITA:
				return _erro(r)
			if r.nivel_min > 0 and nivel < r.nivel_min:
				return _erro(r)
			if r.nivel_max > 0 and nivel > r.nivel_max:
				return _erro(r)
			if r.zen > 0:
				zen_preciso = r.zen
				if com_zen and zen < r.zen:
					return _erro(r)
	return true


func _erro(r: Dictionary) -> bool:
	pagina = r.erro
	erro = true
	return false


# quantos desse item ainda faltam na mochila (o original confere o nivel exato)
func falta_item(a: Dictionary) -> int:
	var achou := 0
	for it in itens:
		if it.grupo == a.grupo and it.numero == a.numero and it.get("nivel", 0) == a.nivel:
			achou += 1
	return maxi(0, a.quantos - achou)


func mortes_de(monstro: int) -> int:
	for m in mortes:
		if m[0] == monstro:
			return m[1]
	return 0


func cumpriu(a: Dictionary) -> bool:
	if a.tipo == ITEM:
		return falta_item(a) == 0
	if a.tipo == MONSTRO:
		return mortes_de(a.grupo) >= a.quantos
	return true


# CheckQuestState: a fala que o NPC mostra agora
func pagina_npc() -> int:
	erro = false
	zen_preciso = 0
	match estado(atual):
		NAO:
			if _confere_pedidos(false):
				pagina = _fala_do_act(0)
		ATIVA:
			pagina = _fala_do_act(2)
			for a in acts():
				if not cumpriu(a):
					pagina = _fala_do_act(1)
					break
		FEITA:
			pagina = _fala_do_act(3)
	return pagina


# BeQuestItem: o botao de concluir acende quando tudo que a quest pede esta cumprido
func pronta() -> bool:
	if estado(atual) != ATIVA:
		return false
	var tem := false
	for a in acts():
		if a.tipo in [ITEM, MONSTRO]:
			tem = true
			if not cumpriu(a):
				return false
	return tem


# ProcessNextProgress: aceitar confere nivel e zen de novo; devolve false se mostrou o erro
func pode_aceitar() -> bool:
	return _confere_pedidos(true)


func fala(i: int) -> Dictionary:
	return falas.get(str(i), {"texto": "", "respostas": []})
