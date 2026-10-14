class_name ClienteMU
extends Node
# Conversa com o OpenMU no protocolo do Season 6 (cliente 1.04d, versao 10404):
# connect server (lista e endereco) -> game server (login, personagens, mundo).
# Os pacotes e campos sao os de openmu/src/Network/Packets/*.xml.

signal estado_mudou(estado: String, texto: String)
signal servidores(lista: Array)
signal personagens(lista: Array)
signal entrou(info: Dictionary)
signal objeto_entrou(o: Dictionary)
signal objeto_saiu(id: int)
signal objeto_andou(id: int, x: int, y: int, passos: Array)
signal objeto_moveu(id: int, x: int, y: int)
signal objeto_morreu(id: int)
signal mapa_mudou(mapa: int, x: int, y: int)
signal vida(atual: int)
signal golpe(id: int, dano: int)
signal ataque(id: int, alvo: int)
signal mensagem(texto: String)
signal mana(atual: int)
signal sd(atual: int)
signal ag(atual: int)
signal maximo(qual: String, v: int)
signal experiencia(morto: int, ganho: int)
signal nivel(info: Dictionary)
signal itens_cairam(lista: Array)
signal itens_sumiram(ids: Array)
signal pegou(slot: int, item: Dictionary)
signal nao_pegou(motivo: int)
signal zen(valor: int)
signal inventario(itens: Dictionary)
signal item_movido(slot: int, item: Dictionary)
signal item_nao_moveu
signal item_removido(slot: int)
signal durabilidade(slot: int, valor: int)
signal largou(ok: bool, slot: int)
signal nao_consumiu
signal skills(lista: Array)
signal skill_nova(indice: int, numero: int)
signal skill_saiu(indice: int, numero: int)
signal skill_animacao(skill: int, quem: int, alvo: int)
signal area_animacao(skill: int, quem: int, x: int, y: int, giro: int)
signal efeito(ativo: bool, quem: int, efeito: int)
signal aparencia_mudou(quem: int, slot: int, chave: String)

const VERSAO := [0x31, 0x30, 0x34, 0x30, 0x34]
const SERIAL := "k1Pk2jcET48mxL3b"
# direcao do pacote (0..7) -> passo em x, y (GameLogic/DirectionExtensions.cs)
const PASSOS := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0),
	Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0)]

var con: Conexao
var estado := "parado"
var usuario := ""
var senha := ""
var meu_id := -1
var host := ""
var _ping := 0.0
var _depurar := OS.get_environment("MU_DEBUG") != ""


func log_rede(t: String) -> void:
	print("REDE ", t)


func _mudar(e: String, texto := "") -> void:
	estado = e
	log_rede("%s %s" % [e, texto])
	estado_mudou.emit(e, texto)


# 1) connect server
func conectar(h: String, porta: int) -> void:
	host = h
	_fechar()
	con = Conexao.new()
	con.abrir(h, porta)
	_mudar("conectando", "%s:%d" % [h, porta])


func pedir_servidor(id: int) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0xF4, 0x03, id & 0xFF, (id >> 8) & 0xFF]))
	_mudar("pedindo_endereco", str(id))


func entrar(u: String, s: String) -> void:
	usuario = u
	senha = s
	if estado == "esperando_login":
		_mandar_login()


func escolher(nome: String) -> void:
	var p := PackedByteArray([0xC1, 0, 0xF3, 0x03])
	p.append_array(_texto(nome, 10))
	con.enviar(p)
	_mudar("entrando", nome)


# anda pelos passos (direcoes 0..7) a partir de (x, y); ate 15 por pacote
func andar(x: int, y: int, dirs: Array) -> void:
	var n := mini(dirs.size(), 15)
	var rot: int = dirs[n - 1] if n > 0 else 0
	var p := PackedByteArray([0xC1, 0, 0xD4, x, y, (rot << 4) | n])
	for i in range(0, n, 2):
		var a: int = dirs[i]
		var b: int = dirs[i + 1] if i + 1 < n else 0
		p.append((a << 4) | b)
	con.enviar(p)


# ataque sem skill: alvo, acao que o boneco toca e pra onde olha (indice de PASSOS)
func atacar(alvo: int, acao: int, direcao: int) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0x11, (alvo >> 8) & 0xFF, alvo & 0xFF, acao & 0xFF, direcao & 0x07]))


func pegar(item: int) -> void:
	con.enviar(PackedByteArray([0xC3, 0, 0x22, (item >> 8) & 0xFF, item & 0xFF]))


# itens: inventario e 0 (equipamento 0..11, mochila 12..75)
func mover_item(de: int, para: int, dados: PackedByteArray) -> void:
	var p := PackedByteArray([0xC3, 0, 0x24, 0, de])
	p.append_array(dados)
	p.append_array(PackedByteArray([0, para]))
	con.enviar(p)


func usar_item(slot: int, alvo := 0) -> void:
	con.enviar(PackedByteArray([0xC3, 0, 0x26, slot, alvo, 0]))


func largar_item(x: int, y: int, slot: int) -> void:
	con.enviar(PackedByteArray([0xC3, 0, 0x23, x, y, slot]))


# skill num alvo (ataque, cura, buff; o alvo pode ser eu mesmo)
func skill_alvo(skill: int, alvo: int) -> void:
	con.enviar(PackedByteArray([0xC3, 0, 0x19, (skill >> 8) & 0xFF, skill & 0xFF, (alvo >> 8) & 0xFF, alvo & 0xFF]))


# skill de area: centro (x, y), giro 0..255 e o contador de animacao (1..50, um por pedido)
var _contador := 1


func skill_area(skill: int, x: int, y: int, giro: int, extra := 0) -> int:
	var c := _contador
	_contador = 1 if _contador >= 0x32 else _contador + 1
	con.enviar(PackedByteArray([0xC3, 0, 0x1E, (skill >> 8) & 0xFF, skill & 0xFF, x, y, giro & 0xFF, 0, 0,
		(extra >> 8) & 0xFF, extra & 0xFF, c]))
	return c


# acertos de uma skill de area que o cliente escolhe (AreaSkillExplicitHits)
func skill_acertos(skill: int, x: int, y: int, anim: int, alvos: Array) -> void:
	var c := _contador
	_contador = 1 if _contador >= 0x32 else _contador + 1
	var p := PackedByteArray([0xC3, 0, 0xDB, (skill >> 8) & 0xFF, skill & 0xFF, x, y, c, alvos.size()])
	for a in alvos:
		p.append_array(PackedByteArray([(a >> 8) & 0xFF, a & 0xFF, anim]))
	con.enviar(p)


func pronto_no_mapa() -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0xF3, 0x12]))


func _pedir_lista() -> void:
	for i in 5:
		await get_tree().create_timer(0.3 if i == 0 else 2.0).timeout
		if estado != "logado" or con == null:
			return
		con.enviar(PackedByteArray([0xC1, 0, 0xF3, 0x00, 0]))


func _fechar() -> void:
	if con:
		con.fechar()
	con = null


func _process(dt: float) -> void:
	if con == null:
		return
	var ok := con.atualizar()
	if con.erro != "":
		var e := con.erro
		_fechar()
		_mudar("erro", e)
		return
	if not ok:
		return
	var atual := con
	for p in con.pacotes():
		if con != atual:
			break  # trocou de servidor no meio: o resto era da conexao velha
		if _depurar:
			log_rede("<- " + p.slice(0, 12).hex_encode() + (" (%d)" % p.size()))
		_tratar(p)
	if estado == "jogo":
		_ping += dt
		if _ping > 10.0:
			_ping = 0.0
			var t := Time.get_ticks_msec()
			con.enviar(PackedByteArray([0xC3, 0, 0x0E, 0x00, t & 0xFF, (t >> 8) & 0xFF, (t >> 16) & 0xFF, (t >> 24) & 0xFF, 0, 0, 0, 0]))


func _tratar(p: PackedByteArray) -> void:
	var c := Cripto.tamanho_cabecalho(p[0])
	var cod := p[c]
	var sub := p[c + 1] if p.size() > c + 1 else -1
	match [cod, sub]:
		[0x00, 0x01]:
			if p.size() == 4:
				# connect server mandou ola: pede a lista
				con.enviar(PackedByteArray([0xC1, 0, 0xF4, 0x06]))
				_mudar("lista")
				return
		[0xF4, 0x06]:
			var n := (p[c + 2] << 8) | p[c + 3]
			var lista := []
			for i in n:
				var o := c + 4 + i * 4
				lista.append({"id": p[o] | (p[o + 1] << 8), "carga": p[o + 2]})
			servidores.emit(lista)
			return
		[0xF4, 0x03]:
			var ip := _ler_texto(p, 4, 16)
			var porta := p[20] | (p[21] << 8)
			_fechar()
			# o servidor pode responder com o IP de dentro do docker; o host que a pessoa digitou vale mais
			con = Conexao.new()
			con.cripto.jogo = true
			con.abrir(host, porta)
			_mudar("conectando_jogo", "%s:%d (servidor disse %s)" % [host, porta, ip])
			return
		[0xF1, 0x00]:
			meu_id = ((p[5] << 8) | p[6]) & 0x7FFF
			_mudar("esperando_login")
			if usuario != "":
				_mandar_login()
			return
		[0xF1, 0x01]:
			var r := p[4]
			if r == 1:
				_mudar("logado")
				# o OpenMU ainda esta fechando o login quando a resposta sai; pedir
				# a lista na mesma hora as vezes cai antes e ele ignora. Pede e repete.
				_pedir_lista()
			else:
				var motivos := {0: "senha errada", 2: "conta nao existe", 3: "conta ja conectada", 4: "servidor cheio", 5: "conta bloqueada", 6: "versao do cliente recusada", 8: "muitas tentativas"}
				_mudar("erro_login", motivos.get(r, "recusado (%d)" % r))
			return
		[0xF3, 0x00]:
			var n := p[6]
			var lista := []
			for i in n:
				var o := 8 + i * 34
				if o + 34 > p.size():
					break
				lista.append({"slot": p[o], "nome": _ler_texto(p, o + 1, 10), "nivel": p[o + 12] | (p[o + 13] << 8), "classe": p[o + 15] >> 3})
			_mudar("personagens")
			personagens.emit(lista)
			return
		[0xF3, 0x03]:
			if p[0] == 0xC3:
				var info := {"x": p[4], "y": p[5], "mapa": p[6] | (p[7] << 8),
					"exp": _ler_be(p, 8, 8), "exp_prox": _ler_be(p, 16, 8), "pontos": p[24] | (p[25] << 8),
					"zen": p[52] | (p[53] << 8) | (p[54] << 16) | (p[55] << 24),
					"vida": p[34] | (p[35] << 8), "vida_max": p[36] | (p[37] << 8),
					"mana": p[38] | (p[39] << 8), "mana_max": p[40] | (p[41] << 8),
					"sd": p[42] | (p[43] << 8), "sd_max": p[44] | (p[45] << 8),
					"ag": p[46] | (p[47] << 8), "ag_max": p[48] | (p[49] << 8)}
				_mudar("jogo")
				entrou.emit(info)
				return
		[0xF3, 0x04]:
			mapa_mudou.emit(p[6], p[4], p[5])
			return
		[0x1C, 0x0F]:
			var mapa := (p[5] << 8) | p[6]
			mapa_mudou.emit(mapa, p[7], p[8])
			if p[4] != 0:
				pronto_no_mapa()
			return
		[0x26, 0xFF]:
			vida.emit((p[4] << 8) | p[5])
			if p.size() >= 9:
				sd.emit((p[7] << 8) | p[8])
			return
		[0x27, 0xFF]:
			mana.emit((p[4] << 8) | p[5])
			if p.size() >= 8:
				ag.emit((p[6] << 8) | p[7])
			return
		[0x26, 0xFE]:
			maximo.emit("vida", (p[4] << 8) | p[5])
			if p.size() >= 9:
				maximo.emit("sd", (p[7] << 8) | p[8])
			return
		[0x27, 0xFE]:
			maximo.emit("mana", (p[4] << 8) | p[5])
			if p.size() >= 8:
				maximo.emit("ag", (p[6] << 8) | p[7])
			return
		[0xF3, 0x05]:
			nivel.emit({"nivel": p[4] | (p[5] << 8), "pontos": p[6] | (p[7] << 8),
				"vida_max": p[8] | (p[9] << 8), "mana_max": p[10] | (p[11] << 8)})
			return
		[0x22, 0xFE]:
			if p[0] == 0xC3:
				zen.emit(_ler_be(p, 4, 4))
				return
		[0xF3, 0x10]:
			# C4: tamanho em 2 bytes; quantidade e itens de 1 + 12 bytes
			var itens := {}
			for i in p[5]:
				var o := 6 + i * 13
				if o + 13 > p.size():
					break
				itens[p[o]] = item_de(p, o + 1)
			inventario.emit(itens)
			return
		[0xF3, 0x11]:
			if p[4] == 0xFE:
				skill_nova.emit(p[6], p[7] | (p[8] << 8))
			elif p[4] == 0xFF:
				skill_saiu.emit(p[6], p[7] | (p[8] << 8))
			else:
				var lista := []
				for i in p[4]:
					var o := 6 + i * 4
					if o + 4 > p.size():
						break
					lista.append({"indice": p[o], "numero": p[o + 1] | (p[o + 2] << 8), "nivel": p[o + 3]})
				skills.emit(lista)
			return
		[0x26, 0xFD]:
			nao_consumiu.emit()
			return
	match cod:
		0x12:
			_ler_personagens(p)
		0x13:
			_ler_npcs(p)
		0x14:
			for i in p[3]:
				objeto_saiu.emit(((p[4 + i * 2] << 8) | p[5 + i * 2]) & 0x7FFF)
		0xD4:
			# o OpenMU manda o destino; os passos podem vir vazios, o mundo acha o caminho
			objeto_andou.emit(((p[3] << 8) | p[4]) & 0x7FFF, p[5], p[6], [])
		0x11:
			if p.size() >= 10:
				golpe.emit(((p[3] << 8) | p[4]) & 0x7FFF, ((p[5] << 8) | p[6]) + ((p[8] << 8) | p[9]))
		0x18:
			if p.size() >= 9:
				ataque.emit(((p[3] << 8) | p[4]) & 0x7FFF, ((p[7] << 8) | p[8]) & 0x7FFF)
		0x15:
			objeto_moveu.emit(((p[3] << 8) | p[4]) & 0x7FFF, p[5], p[6])
		0x17:
			objeto_morreu.emit(((p[3] << 8) | p[4]) & 0x7FFF)
		0x16:
			experiencia.emit(((p[3] << 8) | p[4]) & 0x7FFF, (p[5] << 8) | p[6])
		0x20:
			if p[0] == 0xC2:
				_ler_itens(p)
		0x21:
			if p[0] == 0xC2:
				var ids := []
				for i in p[4]:
					ids.append(((p[5 + i * 2] << 8) | p[6 + i * 2]) & 0x7FFF)
				itens_sumiram.emit(ids)
		0x24:
			if p[3] == 0xFF:
				item_nao_moveu.emit()
			elif p.size() >= 17:
				item_movido.emit(p[4], item_de(p, 5))
		0x23:
			largou.emit(p[3] != 0, p[4])
		0x25:
			# C1 25: alguem trocou o que veste; byte 1 do item = slot << 4; item vazio e tudo FF
			if p.size() >= 17:
				var it := p.slice(5, 17)
				var vazio := it[0] == 0xFF and it[5] == 0xFF
				aparencia_mudou.emit(((p[3] << 8) | p[4]) & 0x7FFF, it[1] >> 4,
					"" if vazio else "%d,%d" % [it[5] >> 4, it[0] | ((it[3] & 0x80) << 1)])
		0x28:
			item_removido.emit(p[3])
		0x2A:
			durabilidade.emit(p[3], p[4])
		0x19:
			if p.size() >= 9:
				skill_animacao.emit((p[3] << 8) | p[4], ((p[5] << 8) | p[6]) & 0x7FFF, ((p[7] << 8) | p[8]) & 0x7FFF)
		0x1E:
			if p.size() >= 10:
				area_animacao.emit((p[3] << 8) | p[4], ((p[5] << 8) | p[6]) & 0x7FFF, p[7], p[8], p[9])
		0x07:
			if p.size() >= 7:
				efeito.emit(p[3] != 0, ((p[4] << 8) | p[5]) & 0x7FFF, p[6])
		0x22:
			if p.size() == 4:
				nao_pegou.emit(p[3])
			elif p.size() >= 4 + 12:
				pegou.emit(p[3], item_de(p, 4))
		0x0D:
			# aviso do servidor: tipo e 9 bytes de cabecalho do aviso antes do texto
			var ini := 13 if p.size() > 13 else 4
			mensagem.emit(_ler_texto(p, ini, p.size() - ini))
		0x00:
			if p[0] == 0xC1 and p.size() > 13:
				mensagem.emit("%s: %s" % [_ler_texto(p, 3, 10), _ler_texto(p, 13, p.size() - 13)])
		0x71:
			con.enviar(PackedByteArray([0xC1, 0, 0x71]))


# C2 12: personagens (Season 6: 36 bytes + 1 por efeito)
func _ler_personagens(p: PackedByteArray) -> void:
	var o := 5
	for i in p[4]:
		if o + 36 > p.size():
			break
		var id := ((p[o] << 8) | p[o + 1]) & 0x7FFF
		objeto_entrou.emit({"id": id, "tipo": "eu" if id == meu_id else "jogador",
			"nome": _ler_texto(p, o + 22, 10), "classe": p[o + 4] >> 3,
			"x": p[o + 2], "y": p[o + 3], "ax": p[o + 32], "ay": p[o + 33],
			"equip": aparencia(p.slice(o + 4, o + 22))})
		o += 36 + p[o + 35]


# C2 20: itens no chao (S6: id, x, y e os 12 bytes do item; zen e o item 14/15 com o valor
# nos bytes 1..4, big endian: o OpenMU manda 00 00 00 1d pra 29 Zen)
# aparencia de 18 bytes do OpenMU (AppearanceSerializer, cliente S6): slot -> "grupo,numero"
const _ASAS := {4: {1: 0, 2: 1, 3: 2, 4: 41}, 8: {1: 3, 2: 4, 3: 5, 4: 6, 5: -30, 6: 42, 7: 49},
	12: {1: 36, 2: 37, 3: 38, 4: 39, 5: 40, 6: 43, 7: 50}}


static func aparencia(a: PackedByteArray) -> Dictionary:
	var e := {}
	if a.size() < 18:
		return e
	# armas: numero no byte 1 (mao direita) e 2 (esquerda), grupo nos 3 bits de cima do 12 e 13
	for i in 2:
		var g: int = a[12 + i] >> 5
		if a[1 + i] != 0xFF and g != 7:
			e[i] = "%d,%d" % [g, a[1 + i]]
	# armaduras: 4 bits + 1 bit no byte 9 + 4 bits (numero ate 511; tudo 1 = vazio)
	var partes := [[3, true, 0x80, 13, false], [3, false, 0x40, 14, true], [4, true, 0x20, 14, false],
		[4, false, 0x10, 15, true], [5, true, 0x08, 15, false]]
	for i in 5:
		var d: Array = partes[i]
		var baixo: int = (a[d[0]] >> 4) if d[1] else (a[d[0]] & 0x0F)
		var meio := 16 if a[9] & d[2] else 0
		var alto: int = (a[d[3]] >> 4) if d[4] else (a[d[3]] & 0x0F)
		var n: int = baixo + meio + alto * 32
		if n != 511:
			e[2 + i] = "%d,%d" % [7 + i, n]
	# asa: o tipo nos bits 2-3 do byte 5, qual nos 3 bits de baixo do 9 (as pequenas no 17)
	var tipo: int = a[5] & 0x0C
	var qual: int = a[9] & 0x07
	if _ASAS.has(tipo) and _ASAS[tipo].has(qual):
		var w: int = _ASAS[tipo][qual]
		e[7] = "13,30" if w == -30 else "12,%d" % w
	elif tipo == 12 and a[17] >> 5 > 0:
		e[7] = "12,%d" % (129 + (a[17] >> 5))
	# ajudante: 0 anjo, 1 imp, 2 unicornio; 3 = nenhum ou dinorant/cavalo/fenrir
	var pet: int = a[5] & 0x03
	if pet < 3:
		e[8] = "13,%d" % pet
	elif a[10] & 0x01:
		e[8] = "13,3"
	elif a[12] & 0x04:
		e[8] = "13,37"
	elif a[12] & 0x01:
		e[8] = "13,4"
	return e


func _ler_itens(p: PackedByteArray) -> void:
	var lista := []
	var o := 5
	for i in p[4]:
		if o + 16 > p.size():
			break
		var it := item_de(p, o + 4)
		it.id = ((p[o] << 8) | p[o + 1]) & 0x7FFF
		it.novo = (p[o] & 0x80) != 0
		it.x = p[o + 2]
		it.y = p[o + 3]
		if it.grupo == 14 and (it.numero & 0xFF) == 15:
			it.zen = _ler_be(p, o + 5, 4)
		lista.append(it)
		o += 16
	itens_cairam.emit(lista)


# os 12 bytes de um item (GameServer/RemoteView/ItemSerializer.cs)
static func item_de(p: PackedByteArray, o: int) -> Dictionary:
	return {"numero": p[o] | ((p[o + 3] & 0x80) << 1), "grupo": p[o + 5] >> 4, "nivel": (p[o + 1] >> 3) & 0x0F,
		"sorte": (p[o + 1] & 0x04) != 0, "skill": (p[o + 1] & 0x80) != 0, "exc": p[o + 3] & 0x3F,
		"durabilidade": p[o + 2], "opcao": (p[o + 1] & 0x03) | ((p[o + 3] & 0x40) >> 4), "anc": p[o + 4],
		"bytes": p.slice(o, o + 12)}


static func _ler_be(p: PackedByteArray, o: int, n: int) -> int:
	var v := 0
	for i in n:
		v = (v << 8) | p[o + i]
	return v


# C2 13: npcs e monstros (Season 6: 10 bytes cada)
func _ler_npcs(p: PackedByteArray) -> void:
	for i in p[4]:
		var o := 5 + i * 10
		if o + 10 > p.size():
			break
		objeto_entrou.emit({"id": ((p[o] << 8) | p[o + 1]) & 0x7FFF, "tipo": "npc",
			"numero": ((p[o + 2] << 8) | p[o + 3]) & 0x0FFF,
			"x": p[o + 4], "y": p[o + 5], "ax": p[o + 6], "ay": p[o + 7]})


func _mandar_login() -> void:
	var longa := senha.to_utf8_buffer().size() > 10
	var p := PackedByteArray([0xC3, 0, 0xF1, 0x01])
	p.append_array(Cripto.xor3(_texto(usuario, 10)))
	p.append_array(Cripto.xor3(_texto(senha, 20 if longa else 10)))
	var t := Time.get_ticks_msec()
	p.append_array(PackedByteArray([(t >> 24) & 0xFF, (t >> 16) & 0xFF, (t >> 8) & 0xFF, t & 0xFF]))
	p.append_array(PackedByteArray(VERSAO))
	p.append_array(SERIAL.to_ascii_buffer())
	con.enviar(p)
	_mudar("login", usuario)


static func _texto(s: String, n: int) -> PackedByteArray:
	var b := s.to_utf8_buffer()
	b.resize(n)
	return b


static func _ler_texto(p: PackedByteArray, ini: int, n: int) -> String:
	var b := p.slice(ini, mini(ini + n, p.size()))
	var z := b.find(0)
	if z >= 0:
		b = b.slice(0, z)
	return b.get_string_from_utf8()
