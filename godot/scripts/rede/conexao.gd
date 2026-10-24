class_name Conexao
extends RefCounted
# Uma conexao com o servidor do MU: junta os bytes que chegam em pacotes
# (C1/C2/C3/C4), decifra e cifra. Por padrao e TCP. Nos testes daqui
# (a caixa nao abre TCP nem pra ela mesma) o transporte e um processo ponte
# que fala com o OpenMU por socket Unix: MU_PONTE=<programa> MU_SOCKETS=<pasta>.
# No navegador (export web) o transporte e WebSocket: wss://<o site>/ws/<porta>,
# a ponte do servidor (mu-estudo-ponte) liga isso no OpenMU. O host e ignorado.
# No PC aberto pelo launcher (MU_SITE e MU_CHAVE no ambiente) e o mesmo WebSocket,
# com a chave do launcher no cabecalho X-Mu-Chave (web/auth.php do mu-estudo).

var tcp: StreamPeerTCP
var wsp: WebSocketPeer
var ponte: Dictionary = {}
var cripto := Cripto.new()
var buffer := PackedByteArray()
var aberta := false
var erro := ""
var _desde := 0

# gravacao: MU_GRAVAR=<arquivo> grava cada pacote recebido (ms e hex, um por
# linha). Com Conexao.tocar(<arquivo>), as conexoes passam a entregar a gravacao
# no mesmo ritmo e o que o cliente manda vai pro nada (foto de tela sem servidor).
static var _gravar := OS.get_environment("MU_GRAVAR")
static var _t0 := -1
static var _fita: Array = []
static var _tocando := false   # tocando gravacao: mesmo com a fita no fim, nao abre rede de verdade
static var _parada_desde := -1  # a fita para enquanto o mapa carrega (o navegador demora mais que a gravacao)
static var _visto := -1         # ultima vez que alguem leu a fita: quadro lento ou fita sem leitor nao contam


static func tocar(arquivo: String) -> void:
	_fita = []
	for linha in FileAccess.get_file_as_string(arquivo).split("\n", false):
		var c := linha.split(" ")
		_fita.append([int(c[0]), c[1].hex_decode()])
	_t0 = Time.get_ticks_msec()
	_visto = _t0
	_tocando = true


# a fita anda no tempo do jogo: o que passar de 150 ms entre duas leituras (carga de modelo, quadro
# travado do navegador) nao conta, senao a gravacao corre na frente do roteiro
static func _andar() -> void:
	var agora := Time.get_ticks_msec()
	if agora - _visto > 150 and _parada_desde < 0:
		_t0 += agora - _visto - 150
	_visto = agora


# relogio da fita em ms (parado enquanto segura); -1 fora da gravacao
static func relogio() -> int:
	if not _tocando:
		return -1
	_andar()
	return (_parada_desde if _parada_desde >= 0 else Time.get_ticks_msec()) - _t0


# segura a fita (o relogio dela nao anda) ate soltar; fora da gravacao nao faz nada
static func segurar(parar: bool) -> void:
	if not _tocando:
		return
	if parar and _parada_desde < 0:
		_parada_desde = Time.get_ticks_msec()
	elif not parar and _parada_desde >= 0:
		_t0 += Time.get_ticks_msec() - _parada_desde
		_parada_desde = -1
		_visto = Time.get_ticks_msec()


func abrir(host: String, porta: int) -> void:
	if _tocando:
		aberta = true
		return
	var prog := OS.get_environment("MU_PONTE")
	if prog != "":
		var alvo := OS.get_environment("MU_SOCKETS").path_join(str(porta))
		ponte = OS.execute_with_pipe(prog, [alvo], false)
		if ponte.is_empty():
			erro = "nao abriu a ponte %s" % prog
			return
		aberta = true
		return
	_desde = Time.get_ticks_msec()
	var site := OS.get_environment("MU_SITE")
	if OS.has_feature("web") or site != "":
		wsp = WebSocketPeer.new()
		wsp.inbound_buffer_size = 1 << 20
		if site == "":
			site = str(JavaScriptBridge.eval("location.host"))
		else:
			# a ponte so aceita o Origin do proprio site (sem ele responde 403)
			wsp.handshake_headers = PackedStringArray(["X-Mu-Chave: " + OS.get_environment("MU_CHAVE"),
				"Origin: https://" + site])
		var url := "wss://%s/ws/%d" % [site, porta]
		var ew := wsp.connect_to_url(url)
		if ew != OK:
			erro = "nao conectou em %s (erro %d)" % [url, ew]
		return
	tcp = StreamPeerTCP.new()
	tcp.set_no_delay(true)
	var e := tcp.connect_to_host(host, porta)
	if e != OK:
		erro = "nao conectou em %s:%d (erro %d)" % [host, porta, e]


func fechar() -> void:
	if wsp:
		wsp.close()
	if tcp:
		tcp.disconnect_from_host()
	if not ponte.is_empty():
		ponte.stdio.close()
		OS.kill(ponte.pid)
		ponte = {}
	aberta = false


# true quando ja da pra mandar; chame todo quadro
func atualizar() -> bool:
	if _tocando or (aberta and tcp == null and wsp == null and ponte.is_empty()):
		return aberta
	if wsp:
		wsp.poll()
		var sw := wsp.get_ready_state()
		if sw == WebSocketPeer.STATE_OPEN:
			aberta = true
			while wsp.get_available_packet_count() > 0:
				buffer.append_array(wsp.get_packet())
		elif sw == WebSocketPeer.STATE_CONNECTING and Time.get_ticks_msec() - _desde > 8000:
			erro = "o servidor nao respondeu em 8 s"
		elif sw == WebSocketPeer.STATE_CLOSED:
			if erro == "":
				erro = "a conexao caiu" if aberta else "a ponte recusou (%d)" % wsp.get_close_code()
			aberta = false
	elif tcp:
		tcp.poll()
		var st := tcp.get_status()
		if st == StreamPeerTCP.STATUS_CONNECTED:
			aberta = true
			var n := tcp.get_available_bytes()
			if n > 0:
				var r := tcp.get_partial_data(n)
				if r[0] == OK:
					buffer.append_array(r[1])
		elif st == StreamPeerTCP.STATUS_CONNECTING and Time.get_ticks_msec() - _desde > 8000:
			erro = "o servidor nao respondeu em 8 s"
		elif st == StreamPeerTCP.STATUS_ERROR or (st == StreamPeerTCP.STATUS_NONE and aberta):
			if erro == "":
				erro = "a conexao caiu"
			aberta = false
	elif not ponte.is_empty():
		var f: FileAccess = ponte.stdio
		var r := f.get_buffer(65536)
		if r.size() > 0:
			buffer.append_array(r)
		if not OS.is_process_running(ponte.pid) and r.is_empty():
			if erro == "":
				erro = "a ponte fechou"
			aberta = false
	return aberta


# pacotes que ja chegaram inteiros, abertos
func pacotes() -> Array[PackedByteArray]:
	var lista: Array[PackedByteArray] = []
	if _tocando or (aberta and tcp == null and wsp == null and ponte.is_empty()):
		_andar()
		if _parada_desde >= 0:
			return lista
		var agora := Time.get_ticks_msec() - _t0
		while not _fita.is_empty() and _fita[0][0] <= agora:
			lista.append(_fita.pop_front()[1])
		return lista
	while buffer.size() >= 3:
		var t := buffer[0]
		if t < 0xC1 or t > 0xC4:
			erro = "byte de cabecalho invalido: %X" % t
			buffer.clear()
			break
		var n := Cripto.ler_tamanho(buffer)
		if n < 3:
			erro = "tamanho invalido"
			buffer.clear()
			break
		if buffer.size() < n:
			break
		var p := cripto.decifrar(buffer.slice(0, n))
		buffer = buffer.slice(n)
		if not p.is_empty():
			lista.append(p)
			if _gravar != "":
				if _t0 < 0:
					_t0 = Time.get_ticks_msec()
				var f := FileAccess.open(_gravar, FileAccess.READ_WRITE if FileAccess.file_exists(_gravar) else FileAccess.WRITE)
				f.seek_end()
				f.store_line("%d %s" % [Time.get_ticks_msec() - _t0, p.hex_encode()])
				f.close()
	return lista


func enviar(pacote: PackedByteArray) -> void:
	if tcp == null and wsp == null and ponte.is_empty():
		return
	Cripto.gravar_tamanho(pacote)
	var dados := cripto.cifrar(pacote)
	if wsp:
		wsp.put_packet(dados)
	elif tcp:
		tcp.put_data(dados)
	elif not ponte.is_empty():
		ponte.stdio.store_buffer(dados)
		ponte.stdio.flush()
