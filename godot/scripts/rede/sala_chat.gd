class_name SalaChat
extends Node
# Uma sala de chat do mensageiro (CUIChatWindow::ConnectToChatServer): conexao propria com o servidor de chat
# (45980 no OpenMU), que o C3 CA do jogo manda abrir com a sala e o token. O cliente cifra como no jogo (Xor32);
# o servidor responde em C1/C2 aberto. Entrar: C1 00 00 com a sala (LE) e o token em texto decimal de 10 bytes
# com Xor3 a partir do byte 6. Mensagem nos dois sentidos: C1 04, indice de quem fala, tamanho e o texto com
# Xor3 a partir do byte 5. O servidor manda C1 01 00 (entrou), C1 01 01 (saiu) e C2 02 (quem esta na sala).

signal entrou(indice: int, nome: String)
signal saiu_da_sala(indice: int, nome: String)
signal membros(lista: Array)                 # [{indice, nome}]
signal falou(indice: int, nome: String, texto: String)
signal caiu(motivo: String)

const PORTA := 45980

var sala := 0
var amigo := ""            # com quem a sala foi aberta (CheckChatRoomDuplication)
var con: Conexao
var nomes := {}            # indice -> nome
var _vivo := 0.0


func conectar(host: String, sala_id: int, token: int, porta := PORTA) -> void:
	sala = sala_id
	con = Conexao.new()
	con.canal = "sala"
	con.cripto.jogo = true
	con.abrir(host, porta)
	_mandar_entrada(token)


static func pacote_entrada(sala_id: int, token: int) -> PackedByteArray:
	var p := PackedByteArray([0xC1, 16, 0x00, 0x00, sala_id & 0xFF, (sala_id >> 8) & 0xFF])
	var t := str(token).to_ascii_buffer()
	t.resize(10)
	p.append_array(Cripto.xor3(t))
	return p


static func pacote_mensagem(texto: String, indice := 0) -> PackedByteArray:
	var t := texto.to_utf8_buffer().slice(0, 100)
	var p := PackedByteArray([0xC1, 5 + t.size(), 0x04, indice, t.size()])
	p.append_array(Cripto.xor3(t))
	return p


func _mandar_entrada(token: int) -> void:
	# a ponte (teste) e o WebSocket so mandam depois de abrir: espera ate 8 s
	for i in 160:
		if con == null:
			return
		if con.atualizar():
			con.enviar(pacote_entrada(sala, token))
			return
		if con.erro != "":
			break
		await get_tree().create_timer(0.05).timeout
	caiu.emit(con.erro if con else "")


func dizer(texto: String) -> void:
	if con and con.aberta:
		con.enviar(pacote_mensagem(texto))


func sair() -> void:
	if con:
		if con.aberta:
			con.enviar(PackedByteArray([0xC1, 3, 0x01]))
		con.fechar()
	con = null


func _process(dt: float) -> void:
	if con == null:
		return
	con.atualizar()
	if con.erro != "":
		var e := con.erro
		con.fechar()
		con = null
		caiu.emit(e)
		return
	for p in con.pacotes():
		tratar(p)
	_vivo += dt
	if _vivo > 30.0 and con.aberta:
		_vivo = 0.0
		con.enviar(PackedByteArray([0xC1, 3, 0x05]))


func tratar(p: PackedByteArray) -> void:
	var c := Cripto.tamanho_cabecalho(p[0])
	if p.size() <= c:
		return
	match p[c]:
		0x01:
			if p.size() >= 15:
				var i := p[4]
				var n := ClienteMU._ler_texto(p, 5, 10)
				if p[3] == 0:
					nomes[i] = n
					entrou.emit(i, n)
				else:
					nomes.erase(i)
					saiu_da_sala.emit(i, n)
		0x02:
			if p[0] == 0xC2 and p.size() >= 8:
				var l := []
				for k in p[6]:
					var o := 8 + k * 11
					if o + 11 > p.size():
						break
					nomes[p[o]] = ClienteMU._ler_texto(p, o + 1, 10)
					l.append({"indice": p[o], "nome": nomes[p[o]]})
				membros.emit(l)
		0x04:
			if p.size() >= 5:
				var n := mini(p[4], p.size() - 5)
				var t := Cripto.xor3(p.slice(5, 5 + n)).get_string_from_utf8()
				falou.emit(p[3], nomes.get(p[3], "?"), t)
