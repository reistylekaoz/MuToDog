class_name Cripto
extends RefCounted
# Criptografia do protocolo do MU Season 6, igual a do OpenMU
# (Network/SimpleModulus e Network/Xor). No connect server nada e cifrado.
# No game server, do cliente pro servidor: Xor32 em todo pacote e, nos C3/C4,
# SimpleModulus por cima. Do servidor pro cliente: so SimpleModulus nos C3/C4.
# Os dois lados tem um contador por pacote C3/C4.

const XOR32 := [
	0xAB, 0x11, 0xCD, 0xFE, 0x18, 0x23, 0xC5, 0xA3,
	0xCA, 0x33, 0xC1, 0xCC, 0x66, 0x67, 0x21, 0xF3,
	0x32, 0x12, 0x15, 0x35, 0x29, 0xFF, 0xFE, 0x1D,
	0x44, 0xEF, 0xCD, 0x41, 0x26, 0x3C, 0x4E, 0x4D,
]
const XOR3 := [0xFC, 0xCF, 0xAB]

# chave que o cliente usa pra cifrar (o servidor decifra com a par dela)
const CIFRA_MOD := [128079, 164742, 70235, 106898]
const CIFRA_KEY := [23489, 11911, 19816, 13647]
const CIFRA_XOR := [48413, 46165, 15171, 37433]
# chave que o cliente usa pra decifrar o que o servidor cifrou
const DECIFRA_MOD := [73326, 109989, 98843, 171058]
const DECIFRA_KEY := [18035, 30340, 24701, 11141]
const DECIFRA_XOR := [62004, 64409, 35374, 64599]

const BLOCO := 8
const BLOCO_CIFRADO := 11

# no game server todo pacote do cliente leva Xor32 (C1 tambem); no connect server nada
var jogo := false
var contador_envio := 0
var contador_recebe := 0


static func tamanho_cabecalho(tipo: int) -> int:
	return 2 if tipo == 0xC1 or tipo == 0xC3 else 3


static func ler_tamanho(p: PackedByteArray) -> int:
	if p[0] == 0xC1 or p[0] == 0xC3:
		return p[1]
	return (p[1] << 8) | p[2]


static func gravar_tamanho(p: PackedByteArray) -> void:
	if p[0] == 0xC1 or p[0] == 0xC3:
		p[1] = p.size()
	else:
		p[1] = (p.size() >> 8) & 0xFF
		p[2] = p.size() & 0xFF


# usuario e senha do login vao com Xor3
static func xor3(dados: PackedByteArray) -> PackedByteArray:
	var r := dados.duplicate()
	for i in r.size():
		r[i] ^= XOR3[i % 3]
	return r


static func _inverte(v: int) -> int:
	return ((v & 0xFF) << 24) | ((v & 0xFF00) << 8) | ((v >> 8) & 0xFF00) | ((v >> 24) & 0xFF)


# pacote aberto (C1..C4) -> bytes pra mandar
func cifrar(pacote: PackedByteArray) -> PackedByteArray:
	if not jogo:
		return pacote
	var p := pacote.duplicate()
	var cab := tamanho_cabecalho(p[0])
	for i in range(cab + 1, p.size()):
		p[i] = p[i] ^ p[i - 1] ^ XOR32[i % 32]
	if p[0] < 0xC3:
		return p
	# o primeiro bloco leva o contador na frente
	var conteudo := PackedByteArray([contador_envio])
	conteudo.append_array(p.slice(cab))
	contador_envio = (contador_envio + 1) & 0xFF
	var blocos := (conteudo.size() + BLOCO - 1) / BLOCO
	var r := PackedByteArray()
	r.resize(cab + blocos * BLOCO_CIFRADO)
	r[0] = p[0]
	for b in blocos:
		var ini := b * BLOCO
		var n := mini(BLOCO, conteudo.size() - ini)
		var entrada := conteudo.slice(ini, ini + n)
		entrada.resize(BLOCO)
		var saida := _cifrar_bloco(entrada, n)
		for i in BLOCO_CIFRADO:
			r[cab + b * BLOCO_CIFRADO + i] = saida[i]
	gravar_tamanho(r)
	return r


func _cifrar_bloco(entrada: PackedByteArray, n: int) -> PackedByteArray:
	var res := [0, 0, 0, 0]
	for i in 4:
		var v := entrada[i * 2] | (entrada[i * 2 + 1] << 8)
		if i > 0:
			v ^= res[i - 1] & 0xFFFF
		res[i] = (((CIFRA_XOR[i] ^ v) * CIFRA_KEY[i]) & 0xFFFFFFFF) % CIFRA_MOD[i]
	for i in 3:
		res[i] = res[i] ^ CIFRA_XOR[i] ^ (res[i + 1] & 0xFFFF)
	var out := PackedByteArray()
	out.resize(BLOCO_CIFRADO)
	for i in 4:
		var bo := (i * 18) / 8
		var bit := (i * 18) % 8
		var inv := _inverte(res[i])
		out[bo] = out[bo] | ((inv >> (24 + bit)) & (0xFF >> bit))
		out[bo + 1] = (inv >> (16 + bit)) & 0xFF
		out[bo + 2] = (inv >> (8 + bit)) & (0xFF << (8 - bit)) & 0xFF
		var resto_mask := ((0xFF << (6 - bit)) & 0xFF) - ((0xFF << (8 - bit)) & 0xFF)
		out[bo + 2] = out[bo + 2] | (((res[i] >> 16) << (6 - bit)) & resto_mask)
	var soma := 0xF8
	for i in n:
		soma ^= entrada[i]
	out[9] = (n ^ 0x3D) ^ soma
	out[10] = soma
	return out


# bytes recebidos (um pacote inteiro) -> pacote aberto; vazio se der erro
func decifrar(pacote: PackedByteArray) -> PackedByteArray:
	if pacote[0] < 0xC3:
		return pacote
	var cab := tamanho_cabecalho(pacote[0])
	var corpo := pacote.slice(cab)
	if corpo.size() % BLOCO_CIFRADO != 0:
		push_warning("pacote cifrado com tamanho errado: %d" % pacote.size())
		return PackedByteArray()
	var conteudo := PackedByteArray()
	for b in corpo.size() / BLOCO_CIFRADO:
		var bloco := corpo.slice(b * BLOCO_CIFRADO, (b + 1) * BLOCO_CIFRADO)
		var n_saida := _decifrar_bloco(bloco)
		if n_saida.is_empty():
			return PackedByteArray()
		conteudo.append_array(n_saida)
	if conteudo.is_empty() or conteudo[0] != contador_recebe:
		push_warning("contador fora: veio %d, esperava %d" % [conteudo[0] if conteudo.size() else -1, contador_recebe])
	contador_recebe = (contador_recebe + 1) & 0xFF
	var r := PackedByteArray()
	r.resize(cab)
	r[0] = pacote[0]
	r.append_array(conteudo.slice(1))
	gravar_tamanho(r)
	return r


func _decifrar_bloco(entrada: PackedByteArray) -> PackedByteArray:
	var res := [0, 0, 0, 0]
	for i in 4:
		var bo := (i * 18) / 8
		var bit := (i * 18) % 8
		var v := ((entrada[bo] & (0xFF >> bit)) << (24 + bit)) & 0xFFFFFFFF
		v += (entrada[bo + 1] << (16 + bit)) & 0xFFFFFFFF
		v += ((entrada[bo + 2] & ((0xFF << (8 - bit)) & 0xFF)) << (8 + bit)) & 0xFFFFFFFF
		v = _inverte(v & 0xFFFFFFFF)
		var resto_mask := ((0xFF << (6 - bit)) & 0xFF) - ((0xFF << (8 - bit)) & 0xFF)
		var resto := entrada[bo + 2] & resto_mask
		v += (resto << 16) >> (6 - bit)
		res[i] = v & 0xFFFFFFFF
	for i in range(3, 0, -1):
		res[i - 1] = res[i - 1] ^ DECIFRA_XOR[i - 1] ^ (res[i] & 0xFFFF)
	var out := PackedByteArray()
	out.resize(BLOCO)
	for i in 4:
		var v: int = DECIFRA_XOR[i] ^ (((res[i] * DECIFRA_KEY[i]) & 0xFFFFFFFF) % DECIFRA_MOD[i])
		if i > 0:
			v ^= res[i - 1] & 0xFFFF
		out[i * 2] = v & 0xFF
		out[i * 2 + 1] = (v >> 8) & 0xFF
	var n := entrada[9] ^ entrada[10] ^ 0x3D
	var soma := 0xF8
	for i in BLOCO:
		soma ^= out[i]
	if n > BLOCO or soma != entrada[10]:
		push_warning("bloco com soma errada")
		return PackedByteArray()
	return out.slice(0, n)
