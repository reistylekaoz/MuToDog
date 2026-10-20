class_name MuHelper
extends Node
# MU Helper do Season 6 (tecla Z configura, Home liga e desliga), no jeito do
# MuHelper.cpp do MuMain: o servidor so liga, desliga e cobra o zen a cada 5 minutos;
# quem caca e o cliente. A cada 0,2 s, nesta ordem: buff, cura (Heal, Drain Life,
# pocao), pegar item, voltar pro lugar e atacar. Para sozinho na zona segura.
# A configuracao vai pro servidor (C2 AE, 257 bytes no formato do MuMain) e volta
# quando o personagem entra no jogo.

signal mudou(ligado: bool)

const LACO := 0.2
const DRENAR := [214, 458]   # Drain Life (e a do master)
const CURAR := [26, 413]     # Heal

var jogo: Node
var c := {}
var ligado := false
var pedindo := false         # mandei ligar e espero o servidor
var zen_gasto := 0
var mortos := 0              # testes

var _t := 0.0
var _laco := 0
var _segundos := 0
var _longe := 0
var _origem := Vector2i.ZERO
var _alvo := -1
var _combo := 0
var _item := -1
var _item_t := 0.0
var _tentados := {}          # item do chao -> true (nao insiste no que nao pegou)
var _atacando := {}          # monstro que me bateu -> segundos do helper
var _buff_i := 0
var _buff_timer := false
var _buff_efeito := {}       # skill de buff -> efeito que ela pos em mim
var _buff_t := {}            # skill de buff -> segundo em que foi solta
var _efeitos := {}           # efeitos ativos em mim
var _esperando_buff := -1
var _pocao_t := 0.0
var _voltando := false


func _init() -> void:
	c = padrao()


static func padrao() -> Dictionary:
	return {
		"caca": 6, "pegar": 6, "segundos_longe": 10,
		"skills": [0, 0, 0], "intervalo": [0, 0, 0], "por_tempo": [false, false, false],
		"por_condicao": [false, false, false], "atacando": [false, false, false], "quantos": [0, 0, 0],
		"combo": false, "golpe_comum": true, "contra_longe": false, "voltar": false,
		"buffs": [0, 0, 0], "buff_duracao": true, "buff_grupo": false, "buff_intervalo": 0,
		"pocao": true, "pocao_pct": 50, "cura": false, "cura_pct": 50, "drenar": false, "drenar_pct": 50,
		"grupo": false, "cura_grupo": false, "grupo_pct": 50, "corvo": false, "corvo_modo": 0,
		"reparar": false, "pegar_tudo": false, "pegar_escolhidos": true,
		"zen": true, "joia": true, "set": true, "exc": true, "extra": false, "extras": [],
		"defesa": false, "amigo": false, "guilda": false,
	}


# --- os 257 bytes do servidor (MuHelperData.cpp / PRECEIVE_MUHELPER_DATA) -------

func serializar() -> PackedByteArray:
	var d := PackedByteArray()
	d.resize(257)
	d[1] = (int(c.joia) << 3) | (int(c.set) << 4) | (int(c.exc) << 5) | (int(c.zen) << 6) | (int(c.extra) << 7)
	d[2] = (int(c.caca) & 15) | ((int(c.pegar) & 15) << 4)
	d.encode_u16(3, int(c.segundos_longe) & 15)
	d.encode_u16(5, c.skills[0])
	d.encode_u16(7, c.skills[1])
	d.encode_u16(9, c.intervalo[1])
	d.encode_u16(11, c.skills[2])
	d.encode_u16(13, c.intervalo[2])
	d.encode_u16(15, c.buff_intervalo)
	for i in 3:
		d.encode_u16(17 + 2 * i, c.buffs[i])
	d[23] = (int(c.pocao_pct / 10) & 15) | ((int(c.cura_pct / 10) & 15) << 4)
	d[24] = (int(c.grupo_pct / 10) & 15) | ((int(c.drenar_pct / 10) & 15) << 4)
	d[25] = int(c.pocao) | (int(c.cura) << 1) | (int(c.drenar) << 2) | (int(c.contra_longe) << 3) \
		| (int(c.voltar) << 4) | (int(c.combo) << 5) | (int(c.grupo) << 6) | (int(c.cura_grupo) << 7)
	d[26] = int(c.buff_grupo) | (int(c.corvo) << 1) | (int(c.buff_duracao) << 2) | (int(c.por_tempo[1]) << 3) \
		| (int(c.por_condicao[1]) << 4) | (int(c.atacando[1]) << 5) | ((int(c.quantos[1]) & 3) << 6)
	d[27] = int(c.por_tempo[2]) | (int(c.por_condicao[2]) << 1) | (int(c.atacando[2]) << 2) \
		| ((int(c.quantos[2]) & 3) << 3) | (int(c.reparar) << 5) | (int(c.pegar_tudo) << 6) | (int(c.pegar_escolhidos) << 7)
	d[28] = int(c.corvo_modo)
	d[29] = int(c.defesa) | (int(c.amigo) << 1) | (int(c.guilda) << 2) | (int(c.golpe_comum) << 3)
	for i in mini(c.extras.size(), 12):
		var b: PackedByteArray = String(c.extras[i]).to_utf8_buffer().slice(0, 14)
		for j in b.size():
			d[65 + 15 * i + j] = b[j]
	return d


func desserializar(d: PackedByteArray) -> void:
	if d.size() < 245:
		return
	var vazio := true
	for b in d.slice(0, 65):
		if b != 0:
			vazio = false
	c = padrao()
	if vazio:
		return   # nunca salvou: fica o padrao
	c.joia = d[1] & 8 != 0
	c.set = d[1] & 16 != 0
	c.exc = d[1] & 32 != 0
	c.zen = d[1] & 64 != 0
	c.extra = d[1] & 128 != 0
	c.caca = d[2] & 15
	c.pegar = d[2] >> 4
	c.segundos_longe = d.decode_u16(3)
	c.skills = [d.decode_u16(5), d.decode_u16(7), d.decode_u16(11)]
	c.intervalo = [0, d.decode_u16(9), d.decode_u16(13)]
	c.buff_intervalo = d.decode_u16(15)
	c.buffs = [d.decode_u16(17), d.decode_u16(19), d.decode_u16(21)]
	c.pocao_pct = (d[23] & 15) * 10
	c.cura_pct = (d[23] >> 4) * 10
	c.grupo_pct = (d[24] & 15) * 10
	c.drenar_pct = (d[24] >> 4) * 10
	var b := d[25]
	c.pocao = b & 1 != 0
	c.cura = b & 2 != 0
	c.drenar = b & 4 != 0
	c.contra_longe = b & 8 != 0
	c.voltar = b & 16 != 0
	c.combo = b & 32 != 0
	c.grupo = b & 64 != 0
	c.cura_grupo = b & 128 != 0
	b = d[26]
	c.buff_grupo = b & 1 != 0
	c.corvo = b & 2 != 0
	c.buff_duracao = b & 4 != 0
	c.por_tempo = [false, b & 8 != 0, d[27] & 1 != 0]
	c.por_condicao = [false, b & 16 != 0, d[27] & 2 != 0]
	c.atacando = [false, b & 32 != 0, d[27] & 4 != 0]
	c.quantos = [0, b >> 6, (d[27] >> 3) & 3]
	c.reparar = d[27] & 32 != 0
	c.pegar_tudo = d[27] & 64 != 0
	c.pegar_escolhidos = d[27] & 128 != 0
	c.corvo_modo = d[28]
	c.defesa = d[29] & 1 != 0
	c.amigo = d[29] & 2 != 0
	c.guilda = d[29] & 4 != 0
	c.golpe_comum = d[29] & 8 != 0
	c.extras = []
	for i in 12:
		var nome := d.slice(65 + 15 * i, 80 + 15 * i).get_string_from_utf8().strip_edges()
		if nome != "":
			c.extras.append(nome)


# --- ligar e desligar ------------------------------------------------------------

# Home ou o botao do HUD: pede pro servidor; o helper anda quando ele confirmar
func alternar() -> void:
	if ligado:
		jogo.cli.helper(false)
		parar("")
		return
	if jogo.mundo.zona_segura(jogo.eu.tile.x, jogo.eu.tile.y):
		jogo._msg("[color=#e8b04a]O MU Helper nao liga na zona segura.[/color]")
		return
	pedindo = true
	jogo.cli.helper(true)


# C1 BF 51 do servidor
func estado(pausado: bool, consumiu: bool, zen: int) -> void:
	if consumiu:
		zen_gasto += zen
		jogo._msg("[color=#9ad0ff]MU Helper: %s zen pelos ultimos 5 minutos.[/color]" % ItemChao._milhar(zen))
		return
	pedindo = false
	if not pausado:
		comecar()
	elif ligado:
		parar("O servidor desligou o MU Helper.")


func comecar() -> void:
	if ligado:
		return
	ligado = true
	_segundos = 0
	_longe = 0
	_laco = 0
	_combo = 0
	_alvo = -1
	_item = -1
	_buff_i = 0
	_buff_t.clear()
	_tentados.clear()
	_atacando.clear()
	_voltando = false
	_origem = jogo.eu.tile
	jogo._msg("[color=#9fe0a0]MU Helper ligado (Home ou o botao de novo desliga).[/color]")
	print("TESTE helper ligado em %s" % _origem)
	mudou.emit(true)


func parar(motivo: String) -> void:
	if not ligado:
		return
	ligado = false
	if jogo.alvo_id >= 0 and jogo.entidades.has(jogo.alvo_id):
		jogo.entidades[jogo.alvo_id].destacar(false)
	jogo.alvo_id = -1
	jogo.item_alvo = -1
	jogo.skill_numero = -1
	jogo._msg("[color=#e8b04a]MU Helper desligado.%s[/color]" % ((" " + motivo) if motivo != "" else ""))
	print("TESTE helper desligado (%s)" % motivo)
	mudou.emit(false)


# --- o que chega do jogo ---------------------------------------------------------

func me_atacou(quem: int) -> void:
	if ligado:
		_atacando[quem] = _segundos
		if c.defesa and _alvo < 0:
			_alvo = quem


func efeito(ativo: bool, quem: int, e: int) -> void:
	if quem != jogo.cli.meu_id:
		return
	if ativo:
		_efeitos[e] = true
		if _esperando_buff > 0:
			_buff_efeito[_esperando_buff] = e
			_esperando_buff = -1
	else:
		_efeitos.erase(e)


func morreu(id: int) -> void:
	_atacando.erase(id)
	if id == _alvo:
		_alvo = -1
		mortos += 1


# --- o laco ------------------------------------------------------------------------

func _process(dt: float) -> void:
	_pocao_t -= dt
	_item_t -= dt
	if not ligado or jogo.eu == null:
		return
	_t -= dt
	if _t > 0.0:
		return
	_t = LACO
	var eu: Entidade = jogo.eu
	if jogo.mundo.zona_segura(eu.tile.x, eu.tile.y):
		jogo.cli.helper(false)
		parar("Entrou na zona segura.")
		return
	if not eu.morto:
		_trabalhar()
	_laco += 1
	if _laco >= 5:
		_laco = 0
		_segundos += 1
		_longe = _longe + 1 if _dist(eu.tile, _origem) > 1 else 0


func _trabalhar() -> void:
	# a skill ou o item de antes ainda estao indo: espera
	if jogo.skill_numero >= 0 or jogo.npc_alvo >= 0:
		return
	if not _buff():
		return
	if not _curar():
		return
	if not _pegar():
		return
	if not _voltar():
		return
	_atacar()


static func _dist(a: Vector2i, b: Vector2i) -> int:
	var d := a - b
	return int(ceil(sqrt(d.x * d.x + d.y * d.y)))


static func _distancia_por_alcance(r: int) -> int:
	return int(ceil(sqrt(2.0 * r * r)))


func _tenho(n: int) -> bool:
	return n > 0 and n in jogo.minhas_skills.values()


func _pode(n: int) -> bool:
	var info: Array = jogo._info_skill(n)
	return _tenho(n) and jogo.barra_mu.mana >= int(info[4]) and jogo.barra_mu.ag >= int(info[5])


func _soltar(n: int, alvo: int) -> void:
	if jogo.alvo_id >= 0 and jogo.entidades.has(jogo.alvo_id):
		jogo.entidades[jogo.alvo_id].destacar(false)
	jogo.alvo_id = -1
	jogo.skill_numero = n
	jogo.skill_alvo = alvo
	jogo.skill_ponto = Vector2i(-1, -1)


func _vida_pct() -> int:
	var b: HudMu = jogo.barra_mu
	return int(ceil(b.vida * 100.0 / maxf(b.vida_max, 1)))


# buff ativo: o efeito que ele pos em mim continua (sem efeito visto, 60 s)
func _buff_ativo(n: int) -> bool:
	if not _buff_t.has(n):
		return false
	if _buff_efeito.has(n):
		return _efeitos.has(_buff_efeito[n])
	return _segundos - int(_buff_t[n]) < 60


func _buff() -> bool:
	var lista: Array = c.buffs.filter(func(n): return _tenho(n))
	if lista.is_empty():
		return true
	if not c.buff_duracao and c.buff_intervalo > 0 and _segundos > 0 and _segundos % c.buff_intervalo == 0 and _laco == 0:
		_buff_timer = true
	_buff_i %= lista.size()
	var n: int = lista[_buff_i]
	_buff_i += 1
	if _buff_i >= lista.size():
		_buff_i = 0
	if (not _buff_ativo(n) or _buff_timer) and _pode(n):
		if _buff_i == 0:
			_buff_timer = false
		_buff_t[n] = _segundos
		_esperando_buff = n
		print("TESTE helper buff %d" % n)
		_soltar(n, jogo.cli.meu_id)
		return false
	if _buff_i == 0:
		_buff_timer = false
	return true


func _curar() -> bool:
	var pct := _vida_pct()
	if c.cura and pct <= c.cura_pct:
		for n in CURAR:
			if _pode(n):
				print("TESTE helper cura %d com %d%%" % [n, pct])
				_soltar(n, jogo.cli.meu_id)
				return false
	if c.drenar and pct <= c.drenar_pct:
		var alvo := _mais_perto()
		for n in DRENAR:
			if alvo >= 0 and _pode(n):
				_alvo = alvo
				_soltar(n, alvo)
				return false
	if c.pocao and pct <= c.pocao_pct and _pocao_t <= 0.0 and not jogo.barra_mu.pocoes[0][0].is_empty():
		_pocao_t = 1.0
		print("TESTE helper pocao com %d%%" % pct)
		jogo._usar_pocao(0)
	return true


# --- itens ---------------------------------------------------------------------------

func _quero(it: ItemChao) -> bool:
	var d := it.dados
	if c.pegar_tudo:
		return true
	if not c.pegar_escolhidos:
		return false
	if d.has("zen"):
		return c.zen
	if c.joia and TextosMU._joia(d):
		return true
	if c.set and int(d.get("anc", 0)) > 0:
		return true
	if c.exc and int(d.get("exc", 0)) & 63:
		return true
	if c.extra:
		for nome in c.extras:
			if nome != "" and it.nome.to_lower().contains(String(nome).to_lower()):
				return true
	return false


func _pegar() -> bool:
	var eu: Entidade = jogo.eu
	if _item >= 0:
		if not jogo.itens.has(_item) or _item_t <= 0.0:
			_tentados[_item] = true
			_item = -1
		elif jogo.item_alvo >= 0 or eu.andando():
			return false
		else:
			# o jogo ja mandou pegar: se nao sumiu, nao insiste
			_tentados[_item] = true
			_item = -1
	var longe := _distancia_por_alcance(c.pegar)
	var melhor: ItemChao = null
	for it: ItemChao in jogo.itens.values():
		if _tentados.has(it.id) or not _quero(it):
			continue
		var d := _dist(it.tile, eu.tile)
		if d <= longe and (melhor == null or d < _dist(melhor.tile, eu.tile)):
			melhor = it
	if melhor == null:
		return true
	_item = melhor.id
	_item_t = 6.0
	print("TESTE helper pegando %s em %s" % [melhor.nome, melhor.tile])
	if jogo.alvo_id >= 0 and jogo.entidades.has(jogo.alvo_id):
		jogo.entidades[jogo.alvo_id].destacar(false)
	jogo.pegar_item(melhor.id)
	return false


# --- voltar pro lugar ------------------------------------------------------------

func _voltar() -> bool:
	var eu: Entidade = jogo.eu
	if _voltando:
		if eu.andando():
			return false
		_voltando = false
		_longe = 0
		if _dist(eu.tile, _origem) > 1:
			return true   # nao achou caminho: segue cacando aqui
	if c.voltar and _longe > c.segundos_longe and _dist(eu.tile, _origem) > 1:
		print("TESTE helper voltando pra %s" % _origem)
		_alvo = -1
		_combo = 0
		jogo.alvo_id = -1
		jogo.andar_ate(_origem)
		_voltando = true
		return false
	return true


# --- ataque -----------------------------------------------------------------------

func _monstro_ok(id: int) -> bool:
	var e: Entidade = jogo.entidades.get(id)
	return e != null and is_instance_valid(e) and e.tipo == "monstro" and not e.morto \
		and not jogo.mundo.zona_segura(e.tile.x, e.tile.y)


# os monstros que o helper ve: dentro do alcance (ou me batendo, com contra-ataque de longe)
func _alvos() -> Array:
	var longe := _distancia_por_alcance(c.caca)
	var l := []
	for id in _atacando.keys():
		if not _monstro_ok(id) or _segundos - int(_atacando[id]) > 5:
			_atacando.erase(id)
	for e: Entidade in jogo.entidades.values():
		if is_instance_valid(e) and _monstro_ok(e.id):
			if _dist(e.tile, jogo.eu.tile) <= longe or (c.contra_longe and _atacando.has(e.id)):
				l.append(e.id)
	return l


func _mais_perto() -> int:
	var melhor := -1
	var perto := _distancia_por_alcance(c.caca) + 1
	for id in _alvos():
		var d := _dist(jogo.entidades[id].tile, jogo.eu.tile)
		if d < perto:
			perto = d
			melhor = id
	return melhor


func _escolher_skill(alvos: Array) -> int:
	for i in [1, 2]:
		var n: int = c.skills[i]
		if not _pode(n):
			continue
		if c.por_tempo[i] and c.intervalo[i] > 0 and _segundos > 0 and _segundos % c.intervalo[i] == 0:
			return n
		if c.por_condicao[i]:
			var quantos: int = _atacando.size() if c.atacando[i] else alvos.size()
			if quantos >= 2 + int(c.quantos[i]):
				return n
	return c.skills[0] if _pode(c.skills[0]) else -1


func _atacar() -> void:
	var alvos := _alvos()
	if _alvo >= 0 and not _monstro_ok(_alvo):
		_alvo = -1
	if _alvo < 0:
		if alvos.is_empty():
			_combo = 0
			return
		if c.contra_longe:
			var longe := -1
			for id in _atacando:
				var d := _dist(jogo.entidades[id].tile, jogo.eu.tile)
				if d > longe:
					longe = d
					_alvo = id
		if _alvo < 0:
			_alvo = _mais_perto()
		if _alvo < 0:
			return
		print("TESTE helper alvo %s (%d)" % [jogo.entidades[_alvo].nome, _alvo])
	if c.combo and c.skills.all(func(n): return _tenho(n)):
		var n: int = c.skills[_combo]
		if _pode(n):
			_combo = (_combo + 1) % 3
			_soltar(n, _alvo)
			return
	else:
		var n := _escolher_skill(alvos)
		if n > 0:
			_soltar(n, _alvo)
			return
	if c.golpe_comum and jogo.alvo_id != _alvo:
		jogo.mirar(_alvo)
