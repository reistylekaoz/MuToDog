class_name Raklion
extends Node
# Evento do Raklion (CGM_Raklion do S6): o servidor manda o estado pelo C1 D1 10 a 12 (11 = detalhe, a fase
# do Selupan). O cliente so mexe em som, musica e efeito:
#   Notify1 (ovos acabando) e Standby (ovos acabaram): o vento (aWind) e, por 0,5 s e 1 s, gelo caindo em
#     volta do heroi (ice_stone00 a 03, CreateMapEffect a cada 2 quadros); no Standby a tela treme.
#   Ready: a fala do Selupan (Selupan_word1) e liga a musica do ninho (Raklion_Hatchery, mapa 58); End desliga.
#   detalhe 3, 4, 6 e 7 (padroes 2, 3, 5 e 6 do Selupan): o grito (Selupan_rage).
#   CanGoBossMap: do Notify3 pra frente (CloseDoor em diante) o ninho fecha.

const CIDADE := 57
const CHEFE := 58
const PASTA := "res://dados/mundo59/"
const EFEITOS := "res://dados/mundo58/efeitos/"
const DETALHE := 11
const NOTIFY1 := 1
const STANDBY := 2
const NOTIFY3 := 6
const READY := 4
const FIM := 10

var estado := 0
var detalhe := 0
var som: Som
var mundo: Node3D
var heroi: Node3D
var mapa_atual := -1
var _efeito := 0.0        # segundos que ainda caem gelo (m_Timer)
var _quadro := 0


static func no_raklion(m: int) -> bool:
	return m == CIDADE or m == CHEFE


func mapa(m: int, mundo_: Node3D = null) -> void:
	mapa_atual = m
	mundo = mundo_


func pode_ir_ao_ninho() -> bool:
	return estado <= NOTIFY3


# CGM_Raklion::SetState
func mudar(estado_: int, detalhe_: int) -> void:
	if estado_ == DETALHE:
		detalhe = detalhe_
		print("TESTE raklion detalhe %d" % detalhe)
		if detalhe in [3, 4, 6, 7] and som:
			som.tocar(PASTA + "sons/selupan_rage.wav")
		return
	estado = estado_
	print("TESTE raklion estado %d" % estado)
	if estado in [NOTIFY1, STANDBY]:
		if som:
			som.tocar("res://dados/mundo58/sons/vento.wav")
		_efeito = 0.5 if estado == NOTIFY1 else 1.0
	elif estado == READY:
		if som:
			som.tocar(PASTA + "sons/selupan_word1.wav")
			som.raklion_chefe = true
	elif estado == FIM and som:
		som.raklion_chefe = false


func _process(dt: float) -> void:
	if _efeito <= 0.0:
		return
	_efeito -= dt
	if estado > STANDBY:
		_efeito = 0.0
	_quadro += 1
	if mundo and is_instance_valid(mundo) and mundo.camera:
		mundo.camera.h_offset = randf_range(-0.05, 0.05) if estado == STANDBY and _efeito > 0.0 else 0.0
	if _quadro % 2 == 0 and no_raklion(mapa_atual):
		_gelo()


# CreateMapEffect: no Notify1 5 levas de gelo grande e pequeno a 6 m num quadrado de 16 tiles; no Standby um
# de cada, azulado, a 5 m num quadrado de 20
func _gelo() -> void:
	if not heroi or not is_instance_valid(heroi) or not mundo:
		return
	var e := EfeitoMU.criar(mundo)
	var h := heroi.global_position
	var levas := 5 if estado == NOTIFY1 else 1
	var lado := 8.0 if estado == NOTIFY1 else 10.0
	var cor := Color.WHITE if estado == NOTIFY1 else Color(0.3, 0.5, 1.0)
	for i in levas:
		for k in 2:
			var nome := "ice_stone0%d" % ((0 if k == 0 else 2) + (0 if estado == NOTIFY1 else 1))
			var p := h + Vector3(randf_range(-lado, lado), 6.0 - (1.0 if estado == STANDBY else 0.0) + randf(), randf_range(-lado, lado))
			var tam := (2.0 + randi() % 20 / 5.0) if k == 0 else (0.5 + randi() % 10 / 5.0)
			var cena: PackedScene = load(EFEITOS + nome + ".glb") if ResourceLoader.exists(EFEITOS + nome + ".glb") else null
			if cena == null:
				continue
			var m := cena.instantiate() as Node3D
			m.rotation_degrees = Vector3(-90, 180, 0)
			m.scale = Vector3.ONE * 0.01
			e.no_pronto(m, p, tam * 0.3, cor, 2.0, {"vel": Vector3(0, -2, 0), "acel": Vector3(0, -12, 0),
				"vgiro": randf_range(-3, 3), "solido": true})
