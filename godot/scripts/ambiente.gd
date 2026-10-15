class_name Ambiente
extends Node3D
# O que da vida ao mapa, no jeito do cliente S6 (ZzzLodTerrain, ZzzObject, ZzzEffect):
# - grama: um "cartao" em pe em cada tile de grama sem mistura, balancando no vento
#   (textura do proprio mapa, camada 1 = 0, 1 ou 2: TileGrass01..03.tga);
# - fogo e fumaca nos objetos que o cliente acende (tocha, fogueira, ponte, portao, lareira);
# - luz do fogo pintada no chao (AddTerrainLight, raio de 4 tiles), piscando;
# - a bica d'agua da praca com a textura correndo;
# - a malha que o cliente soma (BlendMesh: janela, cristal, flor que brilha) e a textura
#   que corre (agua, cachoeira);
# - Devias: neve caindo, porta que abre quando o personagem chega perto, portal;
# - Noria: folhas no vento e o portal.
# - Lost Tower: blocos de fogo com a textura correndo e a luz girando em cima, chama no chao;
# - Atlans: agua do chao em 32 quadros (terreno.gdshader), bolhas subindo dos pontos do mapa
#   e de quem anda fora da cidade, luzes que pulsam e o po brilhante na agua.
# - Tarkan: lava e cristal somados que pulsam e pintam o chao de laranja, areia que corre,
#   brilho (Impack03) nas pedras 63 e 64, fumaca dos buracos e o geiser (70, 76, 83).
# - Noria: luz azul presa nos ossos das plantas e postes (CreateSprite BITMAP_LIGHT no osso);
# - Icarus: sem chao, fundo azul escuro e as nuvens nos pontos do mapa;
# - bichos em volta do heroi (bichos.gd): passaro, morcego, borboleta, rato, peixe, besouro.
# A agua do chao corre no proprio shader do terreno (terreno.gdshader).

const PASTA := "res://dados/ambiente/"
const TILES := 256

# objeto -> [[tipo, x, y, z]] em unidades do MU, relativo ao objeto (CreateFire do cliente)
# tipo 0 = fogo, 1 e 2 = fumaca
const FOGOS := {
	1: {
		"light01": [[0, 0, 0, 0]], "light02": [[1, 0, 0, 0]], "light03": [[2, 0, 0, 0]],
		"bridge01": [[0, 90, -200, 30], [0, 90, 200, 30]],
		"doungeongate01": [[0, -150, -150, 140], [0, 150, -150, 140]],
		"firelight01": [[0, 0, 0, 200]], "firelight02": [[0, 0, -30, 60]], "bonfire01": [[0, 0, 0, 60]],
	},
	# Devias: lareira (30, fogo e fumaca a 160) e tocha (66, CreateFire a 50)
	3: {"object31": [[0, 0, 0, 160], [1, 0, 0, 160]], "object67": [[0, 0, 0, 50]]},
}
# luz que nao e fogo: poste e vela (cor media do cliente e raio em tiles)
const LUZES := {
	1: {"streetlight01": [Color(0.65, 0.52, 0.39), 3], "candle01": [Color(0.45, 0.27, 0.09), 3]},
}
# mapas novos (Arena ate Karutan, mundo 7 e 31 em diante), tirados do CreateObject, MoveObject e
# RenderObject de cada GM*.cpp: escondido inclui o 67, que o codigo do Loren Market some em quase
# todo mapa; na soma, malha -1 = o objeto inteiro, lista = varias malhas, 3o valor = luz da malha
# objeto que o cliente nao desenha (HiddenMesh = -2): marcador de pose e de som (tipo do .obj)
const ESCONDER := {3: [91, 100], 4: [38], 5: [24, 25], 8: [22, 39], 9: [60, 63, 64, 70, 76, 83],
	7: [38, 67],
	31: [0, 4, 11, 37, 39, 41, 42, 43, 44, 45, 46, 47, 48, 52, 53, 54, 66, 67, 68, 69, 71, 72, 73, 74, 75, 76, 88],
	32: [1, 3, 42, 44, 45, 53, 67],
	34: [56, 57, 58, 59, 60, 62, 63, 67, 70],
	35: [57, 71, 72, 73, 74, 77, 78, 81, 82, 83, 84],
	38: [37, 59, 60, 61, 62, 81, 82, 83, 97, 107, 108],
	39: [45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 65],
	52: [0, 54, 58, 59, 60, 61, 62, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147],
	57: [57, 67, 71, 72, 73, 74, 77, 78],
	58: [67, 70, 80],
	64: [0, 1, 2, 3, 4, 5, 6, 67],
	80: [54, 55, 56, 57, 58, 67],
	81: [67, 113, 114, 115, 116, 118],
	82: [67, 113, 114, 115, 116, 118],
}
# brilho do mapa sobre o escolhido (a neve de Devias estoura com o 2,0 da Lorencia; a luz
# pintada da Lost Tower e bem mais escura que a da Lorencia e o chao some; a areia de Tarkan
# estoura no 2,0)
const BRILHO_MAPA := {3: 0.5, 5: 1.3, 9: 0.65}
# tipo -> [malha somada (BlendMesh), rolagem da textura em U e V por segundo]
# (CreateObject e MoveObject do ZzzObject.cpp; a Lorencia segue como foi aprovada)
const SOMA := {
	3: {19: [0, Vector2.ZERO], 92: [0, Vector2.ZERO], 93: [0, Vector2.ZERO], 54: [1, Vector2.ZERO],
		56: [1, Vector2.ZERO], 78: [3, Vector2.ZERO]},
	4: {1: [1, Vector2.ZERO], 9: [3, Vector2.ZERO], 17: [0, Vector2.ZERO], 37: [0, Vector2.ZERO],
		19: [0, Vector2.ZERO], 18: [2, Vector2(0, 1)], 39: [1, Vector2.ZERO], 41: [0, Vector2(0, 0.5)]},
	5: {18: [1, Vector2.ZERO], 23: [1, Vector2.ZERO], 19: [4, Vector2(-1, 0)], 20: [4, Vector2(-1, 0)]},
	8: {23: [0, Vector2.ZERO], 32: [1, Vector2.ZERO], 34: [1, Vector2.ZERO], 38: [0, Vector2.ZERO], 40: [0, Vector2.ZERO]},
	9: {2: [0, Vector2(-1, 0)], 7: [0, Vector2.ZERO], 61: [1, Vector2(0, -1)], 65: [1, Vector2(0, -1)],
		66: [1, Vector2(0, -1)], 72: [0, Vector2(0, -0.2)], 82: [0, Vector2.ZERO]},
	7: {21: [3, Vector2(0.0, -1.0)]},
	31: {19: [-1, Vector2.ZERO], 51: [-1, Vector2(-0.2, 0.0)], 66: [-1, Vector2(0.0, 1.0)], 81: [1, Vector2(0.0, 0.2)], 83: [1, Vector2(0.0, -0.4)]},
	34: {41: [0, Vector2.ZERO]},
	35: {81: [0, Vector2.ZERO]},
	38: {76: [0, Vector2(-0.01, 0.0)], 85: [3, Vector2.ZERO], 95: [0, Vector2.ZERO], 103: [1, Vector2.ZERO], 105: [1, Vector2.ZERO]},
	39: {1: [1, Vector2.ZERO], 2: [1, Vector2.ZERO], 8: [1, Vector2.ZERO], 10: [2, Vector2.ZERO], 12: [0, Vector2(1.0, 1.0)], 27: [2, Vector2(0.0, -1.0)], 31: [0, Vector2.ZERO], 35: [1, Vector2.ZERO], 36: [1, Vector2.ZERO], 76: [0, Vector2.ZERO]},
	52: {56: [0, Vector2.ZERO], 73: [-1, Vector2.ZERO], 78: [0, Vector2.ZERO], 79: [0, Vector2.ZERO], 104: [4, Vector2.ZERO], 110: [[0, 1, 2], Vector2.ZERO], 113: [9, Vector2.ZERO], 114: [9, Vector2.ZERO], 121: [1, Vector2.ZERO]},
	58: {20: [1, Vector2.ZERO], 68: [0, Vector2.ZERO], 69: [0, Vector2.ZERO], 71: [0, Vector2.ZERO]},
	64: {16: [0, Vector2.ZERO], 67: [0, Vector2(0.0, 0.1), 0.2], 68: [0, Vector2(0.0, 0.1), 0.2]},
	80: {8: [[0, 1], Vector2(0.0, -1.0), 0.3]},
	81: {1: [0, Vector2.ZERO], 54: [0, Vector2.ZERO], 55: [0, Vector2(0.0, 0.1)], 57: [0, Vector2(0.0, 0.1)], 58: [[1, 2], Vector2.ZERO], 63: [[0, 2], Vector2.ZERO], 66: [1, Vector2.ZERO], 119: [1, Vector2.ZERO]},
	82: {1: [0, Vector2.ZERO], 54: [0, Vector2.ZERO], 55: [0, Vector2(0.0, 0.1)], 57: [0, Vector2(0.0, 0.1)], 58: [[1, 2], Vector2.ZERO], 63: [[0, 2], Vector2.ZERO], 66: [1, Vector2.ZERO], 119: [1, Vector2.ZERO]},
}
# Atlans: malha somada que pulsa (BlendMeshLight = sin(WorldTime * f) * a + b): tipo -> [f por segundo, a, b]
const PULSA := {8: {23: [2.0, 0.3, 0.5], 32: [4.0, 0.5, 0.5], 34: [4.0, 0.5, 0.5], 40: [4.0, 0.3, 0.5]},
	9: {7: [2.0, 0.35, 0.65]},
	31: {66: [1.0, 0.2, 0.3]},
	38: {103: [2.0, 0.5, 0.5]},
	39: {1: [2.0, 0.5, 0.5], 2: [2.0, 0.5, 0.5], 10: [1.5, 0.4, 0.5]},
	52: {56: [3.0, 0.3, 0.5], 104: [2.0, 0.5, 0.5], 121: [2.0, 0.5, 0.5]},
	58: {68: [1.0, 0.5, 0.8], 69: [1.0, 0.5, 0.8], 71: [1.0, 0.5, 0.8]},
	64: {16: [2.0, 0.5, 0.5]},
	81: {54: [2.0, 0.5, 1.25], 58: [1.0, 0.5, 0.5], 63: [1.0, 0.5, 0.5], 119: [1.0, 0.5, 0.5]},
	82: {54: [2.0, 0.5, 1.25], 58: [1.0, 0.5, 0.5], 63: [1.0, 0.5, 0.5], 119: [1.0, 0.5, 0.5]},
}
# Tarkan: luz laranja no chao em volta da lava (AddTerrainLight com a media do pulso): tipo -> raio
const LUZ_TIPO := {9: {7: 3, 61: 2, 65: 2, 66: 2}}
const COR_LAVA := Color(0.65, 0.39, 0.13)
# Tarkan 63 e 64: brilho Impack03 pulsando na pedra (63 azulado, 64 vermelho)
const BRILHO := {9: {63: Color(1 / 1.7, 1, 1), 64: Color(1, 0.32, 0.32)}}
# Tarkan: fumaca dos pontos escondidos: tipo -> [por segundo, segundos ligada a cada ciclo, ciclo]
# (70 solta 1 a cada 5 quadros; 76 meio segundo a cada 5; 83 o geiser, meio segundo a cada 10)
const FUMACA_TIPO := {9: {70: [5.0, 0.0, 0.0], 76: [25.0, 0.5, 5.0], 83: [25.0, 0.5, 10.0]}}
# Lost Tower: luz girando em cima do bloco de fogo (19 vermelha, 20 azul; Magic_Ground2 e lightning2)
const GIRA := {5: {19: ["magic_ground2", Color(1, 0.2, 0)], 20: ["lightning2", Color(0.4, 0.8, 1)]}}
# tipo -> [malha, rolagem] da textura que corre sem somar (StreamMesh: a agua da Noria)
const CORRE := {4: {42: [0, Vector2(-2, 0)], 43: [0, Vector2(2, 0)]}, 5: {3: [1, Vector2(-1, 0)], 4: [1, Vector2(-1, 0)]},
	9: {11: [0, Vector2(0, -0.2)], 13: [0, Vector2(0, -0.2)], 73: [0, Vector2(0, -0.2)], 75: [0, Vector2(0, -0.2)],
		79: [0, Vector2(0, -0.2)], 12: [0, Vector2(-0.05, -0.05)]},
	31: {17: [0, Vector2(0.0, 0.2)]},
	34: {65: [0, Vector2(-0.05, 0.0)], 66: [0, Vector2(-0.05, 0.0)], 77: [0, Vector2(0.2, 0.0)], 78: [0, Vector2(0.2, 0.0)]},
	38: {96: [0, Vector2(0.0, -0.05)]},
	39: {13: [1, Vector2(0.0, -1.0)], 14: [1, Vector2(0.0, -1.0)], 15: [3, Vector2(0.0, -1.0)], 16: [3, Vector2(0.0, -1.0)]},
	64: {15: [0, Vector2(0.0, -0.1)]},
}
# portal (MODEL_WARP do MapManager.cpp): posicao em unidades do MU e altura das pecas
const PORTAL := {3: [Vector2(53 * 100 + 50, 92 * 100 + 20), 360.0], 4: [Vector2(223 * 100, 30 * 100), 350.0]}
# Devias: porta que corre (86) e porta que gira (20, 65, 88) quando o heroi chega a 2 tiles
const PORTAS := {3: [86, 20, 65, 88]}
# Noria: luz (flare01) no osso do objeto, cor (0,4 0,7 1) x Luminosity sorteada 0,7..1,0 a cada
# quadro: tipo -> [[ossos], escala]; 39 ainda tem duas lightning2 girando no osso 57
const LUZ_OSSO := {4: {1: [[2, 4, 6], 0.5], 9: [[1], 1.5], 17: [[4, 7, 10, 13], 1.0], 35: [[3], 1.5],
	39: [[61, 62, 63, 64, 65], 1.0]}}
const COR_FOGO := Color(0.85, 0.51, 0.34)   # Luminosity media 0,85 x (1, 0,6, 0,4)
# cor do fundo (SetWorldClearColor) e mapa sem chao desenhado (Icarus: so ilhas no ceu)
const CEU := {11: Color8(3, 25, 44), 52: Color8(178, 178, 178)}
const SEM_CHAO := [11]
# Icarus: objeto 0 a 5 nao aparece; vira 20 nuvens (BITMAP_CLOUD, Effect/clouds.jpg) somadas
# em volta dele, a +-250 unidades, 20 a 40 acima, do tamanho da textura x 1,8 a 2,0
const NUVENS := {11: [0, 1, 2, 3, 4, 5]}

var mundo: Node3D
var _bica: Array[ShaderMaterial] = []
var _correm: Array = []        # [material, rolagem por segundo, parametro]
var _piscam: Array[ShaderMaterial] = []
var _pulsam: Array = []        # [material, f, a, b]
var _agua: Array = []          # materiais da agua de Atlans (textura troca 25 vezes por segundo)
var _quadros_agua: Array[Texture2D] = []
var _giram: Array = []         # [sprite, sentido]
var _brilhos: Array = []       # [material, cor, fase]
var _luz_osso: Array[ShaderMaterial] = []
var _portal_mats: Array[ShaderMaterial] = []
var _fumacas: Array = []       # [particulas, segundos ligada, ciclo, fase]
var _bolhas: CPUParticles3D    # Atlans: dos pontos do mapa (tipo 22)
var _portas: Array = []        # [no, tipo, posicao original, giro original (graus), aberta]
var _portal: Node3D
var _cai: CPUParticles3D       # neve (Devias) ou folhas (Noria) em volta do heroi
var _cai2: CPUParticles3D
var som_porta: AudioStreamPlayer
var _t := 0.0
var fogos := 0
var gramas := 0


func montar(m: Node3D, mapa: Image, luz: Image, objetos: Array) -> void:
	mundo = m
	var extra := PackedFloat32Array()
	extra.resize(TILES * TILES * 3)
	var tex_fogo := load(PASTA + "fogo.png") as Texture2D
	var tex_fumaca := load(PASTA + "fumaca.png") as Texture2D
	var fogos_mapa: Dictionary = FOGOS.get(m.numero, {})
	var luzes_mapa: Dictionary = LUZES.get(m.numero, {})
	var luz_tipo: Dictionary = LUZ_TIPO.get(m.numero, {})
	var brilho: Dictionary = BRILHO.get(m.numero, {})
	var fumaca_tipo: Dictionary = FUMACA_TIPO.get(m.numero, {})
	for o in objetos:
		var p := Vector3(o.p[0], o.p[1], o.p[2])
		var b := Basis(Quaternion(o.q[0], o.q[1], o.q[2], o.q[3]))
		for f in fogos_mapa.get(o.m, []):
			var pos: Vector3 = p + b * Vector3(f[1], f[2], f[3])
			if f[0] == 0:
				_luz(extra, pos, COR_FOGO, 4)
				add_child(_fogo(tex_fogo, pos))
			else:
				add_child(_fumaca(tex_fumaca, pos))
			fogos += 1
		if luzes_mapa.has(o.m):
			_luz(extra, p, luzes_mapa[o.m][0], luzes_mapa[o.m][1])
		if o.m == "waterspout01":
			_bica_agua(o)
		var t := int(o.t)
		if luz_tipo.has(t):
			_luz(extra, p, COR_LAVA, luz_tipo[t])
		if brilho.has(t):
			_brilho(p, brilho[t], (o.q[2] if o.q.size() > 2 else 0.0))
		if fumaca_tipo.has(t):
			var ft: Array = fumaca_tipo[t]
			var c := _fumaca(tex_fumaca, p)
			c.amount = maxi(int(ft[0] * c.lifetime), 2)
			c.scale_amount_min *= 2.0
			c.scale_amount_max *= 2.5
			c.lifetime *= 2.0
			c.amount *= 2
			add_child(c)
			if ft[2] > 0.0:
				c.emitting = false
				_fumacas.append([c, ft[1], ft[2], randf() * ft[2]])
			fogos += 1
	_malhas_especiais(m)
	_montar_portal(m)
	_queda(m)
	_luzes_nos_ossos(m)
	var bi := Bichos.new()
	bi.name = "Bichos"
	bi.mundo = m
	add_child(bi)
	_luzes_girando(m, objetos)
	_bolhas_do_mapa(m, objetos)
	_nuvens(m, objetos)
	if m.numero == 5:
		# Lost Tower 24: chama no chao de vez em quando (CreateEffect BITMAP_FLAME, 1 em 64 quadros)
		for o in objetos:
			if int(o.t) == 24:
				var c := _fogo(tex_fogo, Vector3(o.p[0], o.p[1], o.p[2]))
				c.amount = 3
				c.lifetime = 1.6
				add_child(c)
				fogos += 1
	var img := Image.create_from_data(TILES, TILES, false, Image.FORMAT_RGBF, extra.to_byte_array())
	var tex_extra := ImageTexture.create_from_image(img)
	var terreno := m.mu.get_node_or_null("Terreno") as MeshInstance3D
	if terreno:
		terreno.material_override.set_shader_parameter("luz_extra", tex_extra)
	for mat: ShaderMaterial in m.materiais.values():
		mat.set_shader_parameter("luz_extra", tex_extra)
	_grama(mapa, luz, img)
	print("TESTE ambiente %d · somadas %d · correm %d · portas %d · portal %s · queda %s" % [m.numero, _somadas, _correm.size(), _portas.size(), _portal != null, _cai != null])


func _nuvens(m: Node3D, objetos: Array) -> void:
	var tipos: Array = NUVENS.get(m.numero, [])
	if tipos.is_empty() or not ResourceLoader.exists(m.pasta + "nuvem.png"):
		return
	var pontos: Array[Vector3] = []
	for o in objetos:
		if int(o.t) in tipos:
			var p := Vector3(o.p[0], o.p[1], o.p[2])
			for i in 20:
				pontos.append(p + Vector3(randf_range(-250, 250), randf_range(-250, 250), randf_range(20, 40)))
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 2.56
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = load(m.pasta + "nuvem.png")
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.disable_fog = true   # somada: a neblina pintava o quadrado inteiro de azul
	q.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = q
	mm.instance_count = pontos.size()
	for i in pontos.size():
		var esc := randf_range(1.8, 2.0)
		var b := Basis(Vector3.BACK, randf() * TAU).scaled(Vector3.ONE * esc)
		mm.set_instance_transform(i, Transform3D(b, _no_mundo(pontos[i])))
		mm.set_instance_color(i, Color(0.12, 0.12, 0.12))
	var mi := MultiMeshInstance3D.new()
	mi.name = "Nuvens"
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	fogos += pontos.size()


# CreateSprite BITMAP_IMPACT em cima da pedra: escala e luz = sin(t * 2 + fase) * 0,3 + 0,7
func _brilho(pos_mu: Vector3, cor: Color, fase: float) -> void:
	var sp := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 0.64 * 1.5
	sp.mesh = q
	sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = EfeitoMU.SHADER
	mat.set_shader_parameter("tex", EfeitoMU.textura("impack03"))
	mat.set_shader_parameter("modo", 0)
	sp.material_override = mat
	sp.position = _no_mundo(pos_mu + Vector3(0, 0, 40))
	add_child(sp)
	_brilhos.append([mat, cor, fase, sp])


# AddTerrainLight: soma a luz nos vertices em volta, caindo em linha reta ate o raio
func _luz(buf: PackedFloat32Array, pos: Vector3, cor: Color, raio: int) -> void:
	var xf := pos.x / 100.0
	var yf := pos.y / 100.0
	var xi := int(xf)
	var yi := int(yf)
	for y in range(yi - raio, yi + raio + 1):
		for x in range(xi - raio, xi + raio + 1):
			var lf := (raio - Vector2(xf - x, yf - y).length()) / raio
			if lf <= 0.0:
				continue
			var i := ((y & 255) * TILES + (x & 255)) * 3
			buf[i] += cor.r * lf
			buf[i + 1] += cor.g * lf
			buf[i + 2] += cor.b * lf


func _no_mundo(pos_mu: Vector3) -> Vector3:
	return mundo.mu.transform * pos_mu


static func _material_particula(tex: Texture2D, quadros: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.particles_anim_h_frames = quadros
	mat.particles_anim_v_frames = 1
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = tex
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.disable_fog = true
	return mat


# BITMAP_FIRE subtipo 0: 24 quadros de vida, 4 desenhos da tira, encolhe e apaga subindo
func _fogo(tex: Texture2D, pos_mu: Vector3) -> CPUParticles3D:
	var c := fogo(tex)
	c.position = _no_mundo(pos_mu)
	return c


static func fogo(tex: Texture2D) -> CPUParticles3D:
	var c := CPUParticles3D.new()
	c.amount = 12
	c.lifetime = 0.96
	c.preprocess = 1.0
	c.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	c.emission_box_extents = Vector3(0.08, 0.08, 0.08)
	c.direction = Vector3.UP
	c.spread = 8.0
	c.initial_velocity_min = 0.3
	c.initial_velocity_max = 0.5
	c.gravity = Vector3(0, 0.25, 0)
	c.scale_amount_min = 1.28
	c.scale_amount_max = 1.92
	c.scale_amount_curve = _curva(1.0, 0.4)
	c.anim_speed_min = 1.0
	c.anim_speed_max = 1.0
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.6, 0.4))
	g.set_color(1, Color(0, 0, 0))
	c.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2(0.64, 0.64)
	q.material = _material_particula(tex, 4)
	c.mesh = q
	return c


# BITMAP_SMOKE: 16 quadros de vida, cresce, sobe acelerando e apaga
func _fumaca(tex: Texture2D, pos_mu: Vector3) -> CPUParticles3D:
	var c := fumaca(tex)
	c.position = _no_mundo(pos_mu)
	return c


static func fumaca(tex: Texture2D) -> CPUParticles3D:
	var c := CPUParticles3D.new()
	c.amount = 8
	c.lifetime = 0.64
	c.preprocess = 1.0
	c.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	c.emission_box_extents = Vector3(0.08, 0.08, 0.08)
	c.direction = Vector3.UP
	c.spread = 10.0
	c.initial_velocity_min = 0.1
	c.initial_velocity_max = 0.2
	c.gravity = Vector3(0, 1.2, 0)
	c.angle_min = 0.0
	c.angle_max = 360.0
	c.scale_amount_min = 0.48
	c.scale_amount_max = 0.8
	c.scale_amount_curve = _curva(1.0, 2.2)
	var g := Gradient.new()
	g.set_color(0, Color(0.45, 0.45, 0.45))
	g.set_color(1, Color(0, 0, 0))
	c.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2(0.64, 0.64)
	var mat := _material_particula(tex, 1)
	mat.billboard_keep_scale = true
	q.material = mat
	c.mesh = q
	return c


static func _curva(de: float, ate: float) -> Curve:
	var cv := Curve.new()
	cv.max_value = maxf(de, ate)
	cv.add_point(Vector2(0, de))
	cv.add_point(Vector2(1, ate))
	return cv


# a bica da praca: a malha 3 (a agua) corre pra baixo, uma volta por segundo
func _bica_agua(o: Dictionary) -> void:
	for n in mundo.mu.get_node("Objetos").get_children():
		if not n.transform.origin.is_equal_approx(Vector3(o.p[0], o.p[1], o.p[2])):
			continue
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var malha := (mi as MeshInstance3D).mesh
			if malha == null or malha.get_surface_count() < 4:
				continue
			var mat := (mi as MeshInstance3D).get_surface_override_material(3)
			if mat is ShaderMaterial:
				var copia := mat.duplicate() as ShaderMaterial
				(mi as MeshInstance3D).set_surface_override_material(3, copia)
				_bica.append(copia)


# TERRAIN_MAP_GRASS: em cada tile de grama (camada 1 = 0, 1 ou 2, com a textura
# TileGrass01..03 do mapa) sem mistura, um cartao em pe na borda de baixo do tile,
# altura = 2x a da textura, topo puxado -50 em X, textura com deslocamento sorteado
# por linha. O vento mexe o topo no shader.
func _grama(mapa: Image, luz: Image, extra: Image) -> void:
	var texs := {}
	for i in 3:
		var c: String = mundo.pasta + "grama/%d.png" % i
		if ResourceLoader.exists(c):
			texs[i] = load(c)
	if texs.is_empty() and mundo.numero == 1 and ResourceLoader.exists(PASTA + "grama.png"):
		texs[0] = load(PASTA + "grama.png")
	var desloc := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for y in TILES:
		desloc.append(float(rng.randi() % 4) / 4.0)
	for camada in texs:
		var tex: Texture2D = texs[camada]
		var alto := float(tex.get_height()) * 2.0
		var largura := 64.0 / float(tex.get_width())
		var vs := PackedVector3Array()
		var uvs := PackedVector2Array()
		var cores := PackedColorArray()
		var idx := PackedInt32Array()
		for y in TILES - 1:
			for x in TILES - 1:
				if int(round(mapa.get_pixel(x, y).r * 255.0)) != camada:
					continue
				if mapa.get_pixel(x, y).b > 0.0 or mapa.get_pixel(x + 1, y).b > 0.0 \
						or mapa.get_pixel(x, y + 1).b > 0.0 or mapa.get_pixel(x + 1, y + 1).b > 0.0:
					continue
				# sem chao (TW_NOGROUND) o cliente nem desenha o tile
				if mundo.atributos.size() > 0 and int(round(mapa.get_pixel(x, y).a * 255.0)) & 0x08:
					continue
				var su := x * largura + desloc[y]
				var b0 := Vector3(x * 100.0, (y + 1) * 100.0, mundo.altura_em(x, y + 1))
				var b1 := Vector3((x + 1) * 100.0, (y + 1) * 100.0, mundo.altura_em(x + 1, y + 1))
				var n := vs.size()
				vs.append(b0 + Vector3(-50, 0, alto))
				vs.append(b1 + Vector3(-50, 0, alto))
				vs.append(b1)
				vs.append(b0)
				uvs.append(Vector2(su, 0))
				uvs.append(Vector2(su + largura, 0))
				uvs.append(Vector2(su + largura, 1))
				uvs.append(Vector2(su, 1))
				# luz do vertice: a do mapa mais a do fogo (o cliente usa a do tile e do vizinho)
				for c in [Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x + 1, y + 1), Vector2i(x, y + 1)]:
					var l := luz.get_pixel(c.x, c.y) + extra.get_pixel(c.x, c.y)
					cores.append(Color(minf(l.r, 1.0), minf(l.g, 1.0), minf(l.b, 1.0)))
				idx.append_array([n, n + 1, n + 2, n, n + 2, n + 3])
		if vs.is_empty():
			continue
		gramas += vs.size() / 4
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = vs
		arr[Mesh.ARRAY_TEX_UV] = uvs
		arr[Mesh.ARRAY_COLOR] = cores
		arr[Mesh.ARRAY_INDEX] = idx
		var malha := ArrayMesh.new()
		malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mat := ShaderMaterial.new()
		mat.shader = load("res://scripts/grama.gdshader")
		mat.set_shader_parameter("textura", tex)
		mat.set_shader_parameter("brilho", mundo.brilho_mapa())
		var mi := MeshInstance3D.new()
		mi.name = "Grama" if camada == 0 else "Grama%d" % camada
		mi.mesh = malha
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mundo.mu.add_child(mi)


var _somadas := 0


# BlendMesh: a malha n do objeto vai somada (RENDER_BRIGHT), sem a luz do chao;
# StreamMesh: a textura corre. Um material por textura do modelo, como no mundo.gd.
func _malhas_especiais(m: Node3D) -> void:
	var soma: Dictionary = SOMA.get(m.numero, {})
	var corre: Dictionary = CORRE.get(m.numero, {})
	var portas: Array = PORTAS.get(m.numero, [])
	var feitos := {}
	for par in m.nos_objetos:
		var n: Node3D = par[0]
		var t := int(par[1].t)
		if t in portas:
			var q: Array = par[1].q
			var giro := fposmod(rad_to_deg(2.0 * atan2(q[2], q[3])), 360.0)
			_portas.append([n, t, n.transform.origin, roundf(giro), false])
		if not soma.has(t) and not corre.has(t):
			continue
		var info: Array = soma[t] if soma.has(t) else corre[t]
		var somar := soma.has(t)
		var i := 0
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null:
				continue
			for s in mi.mesh.get_surface_count():
				var alvo = info[0]
				if (alvo is Array and i in alvo) or (alvo is int and (alvo == -1 or i == alvo)):
					var orig := mi.mesh.surface_get_material(s) as BaseMaterial3D
					if orig == null:
						continue
					var chave := [orig, somar]
					if not feitos.has(chave):
						feitos[chave] = _material_especial(m, orig, somar, info[1], t)
						if somar and info.size() > 2:
							feitos[chave].set_shader_parameter("cor", Color(info[2], info[2], info[2]))
					mi.set_surface_override_material(s, feitos[chave])
					_somadas += 1 if somar else 0
				i += 1


func _material_especial(m: Node3D, orig: BaseMaterial3D, somar: bool, rolagem: Vector2, t: int) -> ShaderMaterial:
	var mat: ShaderMaterial
	if somar:
		mat = ShaderMaterial.new()
		mat.shader = EfeitoMU.SHADER
		mat.set_shader_parameter("tex", orig.albedo_texture)
		mat.set_shader_parameter("modo", 1)
		mat.set_shader_parameter("cor", Color(1, 1, 1))
		if rolagem != Vector2.ZERO:
			_correm.append([mat, rolagem, "uv_desl"])
		# Devias 78: a luz da malha somada pisca 0,4..0,7 (BlendMeshLight sorteado a cada quadro)
		if m.numero == 3 and t == 78:
			_piscam.append(mat)
		var pulsa: Dictionary = PULSA.get(m.numero, {})
		if pulsa.has(t):
			_pulsam.append([mat] + pulsa[t])
		# Atlans 23: a agua do modelo (wt00) troca de quadro como a do chao
		if m.numero == 8 and t == 23:
			_agua.append(mat)
	else:
		mat = (m.materiais[orig] as ShaderMaterial).duplicate()
		m.materiais[orig.duplicate()] = mat   # segue o brilho (teclas - e =)
		_correm.append([mat, rolagem, "rolagem"])
	return mat


# MODEL_WARP: tres discos somados um atras do outro (warp01, warp02, warp03), girando
func _montar_portal(m: Node3D) -> void:
	if not PORTAL.has(m.numero) or not ResourceLoader.exists(m.pasta + "warp01.glb"):
		return
	var xy: Vector2 = PORTAL[m.numero][0]
	var z: float = m.altura_em(xy.x / 100.0, xy.y / 100.0) + PORTAL[m.numero][1]
	_portal = Node3D.new()
	_portal.name = "Portal"
	add_child(_portal)
	_portal.position = _no_mundo(Vector3(xy.x, xy.y, z))
	_portal.rotation_degrees.y = 10.0   # Angle (0, 0, 10) do cliente
	# Devias: warp01, 02, 03 a 0, 4 e 20 de Y; Noria: 01, 02, 01, 02, 03 a 0, 4, 8, 12 e 20
	var pecas: Array = [[1, 0.0], [2, 4.0], [3, 20.0]] if m.numero == 3 else [[1, 0.0], [2, 4.0], [1, 8.0], [2, 12.0], [3, 20.0]]
	var rng := RandomNumberGenerator.new()
	rng.seed = m.numero
	for p in pecas:
		var cena := load(m.pasta + "warp0%d.glb" % p[0]) as PackedScene
		var no: Node3D = cena.instantiate()
		no.rotation_degrees = Vector3(-90, 180, 0)
		var base := Node3D.new()
		base.position = Vector3(0, 0, -p[1] / 100.0)
		# o cliente sorteia o tamanho (1,3..1,8) e a velocidade de cada peca
		var esc := 1.3 + rng.randf() * 0.5
		base.scale = Vector3.ONE * 0.01 * esc
		# Move_MODEL_WARP3: gira (4 + Gravity) graus por quadro, Gravity sorteado 0..8
		base.set_meta("vel", (4.0 + rng.randf() * 8.0) * 25.0 * (1.0 if p[0] != 2 else -1.0))
		base.add_child(no)
		_portal.add_child(base)
		for mi: MeshInstance3D in no.find_children("*", "MeshInstance3D", true, false):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for s in mi.mesh.get_surface_count():
				var orig := mi.get_active_material(s) as BaseMaterial3D
				var mat := ShaderMaterial.new()
				mat.shader = EfeitoMU.SHADER
				mat.set_shader_parameter("tex", orig.albedo_texture if orig else null)
				mat.set_shader_parameter("modo", 1)
				mat.set_shader_parameter("cor", Color(0.8, 0.8, 0.8))
				mi.set_surface_override_material(s, mat)
				_portal_mats.append(mat)


func _luzes_nos_ossos(m: Node3D) -> void:
	var tabela: Dictionary = LUZ_OSSO.get(m.numero, {})
	if tabela.is_empty() or not FileAccess.file_exists(m.pasta + "ossos.json"):
		return
	var ossos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(m.pasta + "ossos.json"))
	var tex := EfeitoMU.textura("flare01")
	var raio := EfeitoMU.textura("lightning2")
	for par in m.nos_objetos:
		var t := int(par[1].t)
		if not tabela.has(t) or not ossos.has(par[1].m):
			continue
		var pose: Array = ossos[par[1].m]
		var o: Dictionary = par[1]
		var tr := Transform3D(Basis(Quaternion(o.q[0], o.q[1], o.q[2], o.q[3])) * float(o.s), Vector3(o.p[0], o.p[1], o.p[2]))
		var lista: Array = tabela[t][0].duplicate()
		var esc: float = tabela[t][1]
		if m.numero == 4 and t == 39:
			lista.append(57)
		for i: int in lista:
			if i >= pose.size():
				continue
			var p := _no_mundo(tr * Vector3(pose[i][0], pose[i][1], pose[i][2]))
			var girando: bool = m.numero == 4 and t == 39 and i == 57
			for sentido in ([1.0, -1.0] if girando else [0.0]):
				var t2 := raio if girando else tex
				var sp := MeshInstance3D.new()
				var q := QuadMesh.new()
				q.size = Vector2(t2.get_width(), t2.get_height()) * esc * 0.01
				sp.mesh = q
				sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var mat := ShaderMaterial.new()
				mat.shader = EfeitoMU.SHADER
				mat.set_shader_parameter("tex", t2)
				mat.set_shader_parameter("modo", 0)
				mat.set_shader_parameter("cor", Color(0.4, 0.8, 1) if girando else Color(0.34, 0.6, 0.85))
				sp.material_override = mat
				add_child(sp)
				sp.global_position = p
				if girando:
					_giram.append([mat, sentido])
				else:
					_luz_osso.append(mat)


# Lost Tower 19 e 20: duas luzes girando em sentidos contrarios em cima do bloco de fogo
# (CreateSprite com Rotation = WorldTime * 0,1 graus). O cliente poe nos ossos 15, 19 e 21
# do modelo; aqui a maior (1,5) vai no topo do modelo.
func _luzes_girando(m: Node3D, _objetos: Array) -> void:
	var gira: Dictionary = GIRA.get(m.numero, {})
	if gira.is_empty():
		return
	for par in m.nos_objetos:
		var t := int(par[1].t)
		if not gira.has(t):
			continue
		var n: Node3D = par[0]
		var caixa := AABB()
		var primeira := true
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			var c := mi.global_transform * mi.get_aabb()
			caixa = c if primeira else caixa.merge(c)
			primeira = false
		if primeira:
			continue
		var topo := caixa.get_center() + Vector3(0, caixa.size.y * 0.5, 0)
		for sentido in [1.0, -1.0]:
			var sp := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2.ONE * 0.64 * 1.5   # sprite de 64 px na escala 1,5
			sp.mesh = q
			sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var mat := ShaderMaterial.new()
			mat.shader = EfeitoMU.SHADER
			mat.set_shader_parameter("tex", EfeitoMU.textura(gira[t][0]))
			mat.set_shader_parameter("cor", gira[t][1])
			mat.set_shader_parameter("modo", 0)
			sp.material_override = mat
			add_child(sp)
			sp.global_position = topo
			_giram.append([mat, sentido])


# Atlans 22: ponto escondido que solta bolha metade do tempo (Timer de 0 a 10, solta acima de 5)
func _bolhas_do_mapa(m: Node3D, objetos: Array) -> void:
	if m.numero != 8 or not ResourceLoader.exists(m.pasta + "bolha.png"):
		return
	var pontos := PackedVector3Array()
	for o in objetos:
		if int(o.t) == 22:
			pontos.append(_no_mundo(Vector3(o.p[0], o.p[1], o.p[2])) - global_position)
	if pontos.is_empty():
		return
	_bolhas = bolhas(m, 600)
	_bolhas.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	_bolhas.emission_points = pontos
	add_child(_bolhas)


# BITMAP_BUBBLE: drop01 em 3x3 quadros, vive 30..40 quadros (1,2..1,6 s), sobe 25..75 por
# quadro na escala 0,12..0,27 e treme pros lados; somada
static func bolhas(m: Node3D, n: int) -> CPUParticles3D:
	var img := (load(m.pasta + "bolha.png") as Texture2D).get_image()
	img = img.get_region(Rect2i(0, 0, 48, 48))
	var c := CPUParticles3D.new()
	c.amount = n
	c.lifetime = 1.4
	c.local_coords = false
	c.direction = Vector3.UP
	c.spread = 20.0
	c.initial_velocity_min = 1.0
	c.initial_velocity_max = 3.0
	c.gravity = Vector3.ZERO
	c.scale_amount_min = 0.6
	c.scale_amount_max = 1.4
	c.anim_offset_max = 1.0
	c.anim_speed_min = 0.0
	c.anim_speed_max = 0.0
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.particles_anim_h_frames = 3
	mat.particles_anim_v_frames = 3
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	q.material = mat
	c.mesh = q
	return c


# Devias: neve (leaf01 e, 1 em 10, leaf02 maior) caindo inclinada em volta do heroi
# (CreateDeviasSnow: 8..23 por quadro de 1/25 s, angulo -30 em X); Noria: folhas
# soltas no vento pra -X (CreateAtlanseLeaf). 80 de cada vez, como o cliente.
func _queda(m: Node3D) -> void:
	if not m.modo_jogo or not ResourceLoader.exists(m.pasta + "folha1.png"):
		_chuva(m)
		return
	if m.numero == 3:
		_cai = _particulas(load(m.pasta + "folha1.png"), 72, 0.08, true)
		if ResourceLoader.exists(m.pasta + "folha2.png"):
			_cai2 = _particulas(load(m.pasta + "folha2.png"), 8, 0.16, true)
	elif m.numero == 4:
		_cai = _particulas(load(m.pasta + "folha1.png"), 80, 0.14, false)
	elif m.numero == 8:
		# Atlans: o mesmo vento da Noria (CreateAtlanseLeaf), com o po brilhante somado
		_cai = _particulas(load(m.pasta + "folha1.png"), 80, 0.14, false)
		var mat := (_cai.mesh as QuadMesh).material as StandardMaterial3D
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	elif m.numero == 58:
		# Raklion (CGM_Raklion::CreateSnow): neve de 3 a 12 de escala caindo a 30..50 por quadro,
		# inclinada 50 a 80 graus
		_cai = _particulas(load(m.pasta + "folha1.png"), 120, 0.1, true)
		_cai.initial_velocity_min = 7.5
		_cai.initial_velocity_max = 12.5
		_cai.direction = Vector3(0, -1, 0).rotated(Vector3.RIGHT, deg_to_rad(65))
		_cai.spread = 15.0
		_cai.lifetime = 0.6
	_chuva(m)


# chuva (CreateHeavenRain em Icarus, CreateRain no Mercado de Loren): rain01.tga do World1 em
# pe, de 2 a 4 m acima do heroi, caindo a 20..43 por quadro inclinada 30 graus; faisca de
# Vulcanus (CGM_PK_Field::CreateFireSpark): FireSnuff somado voando de lado
func _chuva(m: Node3D) -> void:
	if not m.modo_jogo:
		return
	if m.numero in [11, 80] and ResourceLoader.exists(m.pasta + "chuva.png"):
		var c := _particulas(load(m.pasta + "chuva.png"), 110, 0.05, true)
		var q := c.mesh as QuadMesh
		q.size = Vector2(0.04, 0.5)
		(q.material as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		c.initial_velocity_min = 5.0
		c.initial_velocity_max = 10.75
		c.lifetime = 0.6
		c.preprocess = c.lifetime
		_cai2 = c
	elif m.numero == 64 and ResourceLoader.exists(m.pasta + "faisca.png"):
		var c := _particulas(load(m.pasta + "faisca.png"), 60, 0.12, false)
		var mat := (c.mesh as QuadMesh).material as StandardMaterial3D
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		mat.albedo_color = Color(1, 0.35, 0.1)
		c.emission_box_extents = Vector3(8, 1.5, 7)
		c.initial_velocity_min = 1.6
		c.initial_velocity_max = 3.2
		c.gravity = Vector3(0, 0.1, 0)
		c.lifetime = 3.0
		c.preprocess = c.lifetime
		_cai2 = c


func _particulas(tex: Texture2D, n: int, tam: float, neve: bool) -> CPUParticles3D:
	var c := CPUParticles3D.new()
	c.amount = n
	c.local_coords = false
	c.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	var q := QuadMesh.new()
	q.size = Vector2(tam, tam)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = tex
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_fog = true
	q.material = mat
	c.mesh = q
	var g := Gradient.new()
	if neve:
		# cai de 2 a 4 m acima do heroi a 2..5,75 m/s e apaga no chao
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		c.lifetime = 1.4
		c.emission_box_extents = Vector3(8, 1, 7)
		c.direction = Vector3(0, -1, 0).rotated(Vector3.RIGHT, deg_to_rad(30))
		c.spread = 4.0
		c.initial_velocity_min = 2.0
		c.initial_velocity_max = 5.75
		c.gravity = Vector3.ZERO
		g.set_color(0, Color(1, 1, 1, 1))
		g.add_point(0.75, Color(1, 1, 1, 1))
		g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	else:
		# folha: voa pra -X a 1,6..3,2 m/s, sobe e desce devagar e gira
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		c.lifetime = 6.0
		c.emission_box_extents = Vector3(8, 1.5, 7)
		c.direction = Vector3(-1, 0, 0)
		c.spread = 15.0
		c.initial_velocity_min = 1.6
		c.initial_velocity_max = 3.2
		c.gravity = Vector3(0, -0.15, 0)
		c.angular_velocity_min = -180.0
		c.angular_velocity_max = 180.0
		c.angle_min = 0.0
		c.angle_max = 360.0
		mat.particles_anim_h_frames = 1
		g.set_color(0, Color(1, 1, 1, 0))
		g.add_point(0.1, Color(1, 1, 1, 1))
		g.add_point(0.85, Color(1, 1, 1, 1))
		g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	c.color_ramp = g
	c.preprocess = c.lifetime
	add_child(c)
	return c


# porta de Devias (MoveObject): a 200 do heroi a de correr anda (200 - d) * 2 pro lado
# que ela aponta; a de girar vai pra 30 - (200 - d) * 0,5 graus (ou o equivalente do lado
# dela). Longe, volta: o giro pelo TurnAngle2 de 10 graus e a posicao 20% por quadro.
func _mexer_portas(dt: float) -> void:
	var heroi: Node3D = mundo.seguir
	if heroi == null or not is_instance_valid(heroi):
		return
	var hp := Vector2(heroi.global_position.x, -heroi.global_position.z) * 100.0
	var k := minf(dt * 25.0, 1.0)
	for p in _portas:
		var n: Node3D = p[0]
		var orig: Vector3 = p[2]
		var giro0: float = p[3]
		var d := hp.distance_to(Vector2(orig.x, orig.y))
		var b := n.transform.basis
		var esc := b.get_scale().x
		if d < 200.0:
			if not p[4]:
				p[4] = true
				_tocar_porta(p[1] == 86)
			if p[1] == 86:
				var desl := {90.0: Vector3(0, 1, 0), 270.0: Vector3(0, -1, 0), 0.0: Vector3(1, 0, 0), 180.0: Vector3(-1, 0, 0)}
				n.transform.origin = orig + desl.get(giro0, Vector3.ZERO) * (200.0 - d) * 2.0
			else:
				var alvo := {90.0: 30.0 - (200.0 - d) * 0.5, 270.0: 330.0 + (200.0 - d) * 0.5,
					0.0: 300.0 - (200.0 - d) * 0.5, 180.0: 240.0 + (200.0 - d) * 0.5}
				n.transform.basis = Basis(Vector3(0, 0, 1), deg_to_rad(alvo.get(giro0, giro0))) * esc
		else:
			p[4] = false
			n.transform.origin = n.transform.origin.lerp(orig, 0.2 * k)
			if p[1] != 86:
				var atual := fposmod(rad_to_deg(2.0 * atan2(n.quaternion.z, n.quaternion.w)), 360.0)
				var dif := wrapf(giro0 - atual, -180.0, 180.0)
				var passo := clampf(dif, -10.0 * k, 10.0 * k)
				n.transform.basis = Basis(Vector3(0, 0, 1), deg_to_rad(atual + passo)) * esc


func _tocar_porta(correr: bool) -> void:
	if som_porta == null:
		som_porta = AudioStreamPlayer.new()
		som_porta.volume_db = -10.0
		add_child(som_porta)
	var c := PASTA + ("porta_castelo.wav" if correr else "porta.wav")
	if ResourceLoader.exists(c):
		som_porta.stream = load(c)
		som_porta.play()


func _process(dt: float) -> void:
	_t += dt
	for m in _bica:
		m.set_shader_parameter("rolagem", Vector2(0, -fmod(_t, 1.0)))
	for c in _correm:
		var r: Vector2 = c[1] * _t
		(c[0] as ShaderMaterial).set_shader_parameter(c[2], Vector2(fposmod(r.x, 1.0), fposmod(r.y, 1.0)))
	if not _piscam.is_empty():
		var l := randf_range(0.4, 0.8)
		for m in _piscam:
			m.set_shader_parameter("cor", Color(l, l, l))
	for p in _pulsam:
		var l: float = sin(_t * p[1]) * p[2] + p[3]
		(p[0] as ShaderMaterial).set_shader_parameter("cor", Color(l, l, l))
	if not _agua.is_empty():
		if _quadros_agua.is_empty():
			for i in 32:
				_quadros_agua.append(load(mundo.pasta + "agua/%d.png" % i))
		var q := _quadros_agua[int(_t * 25.0) % 32]
		for m in _agua:
			m.set_shader_parameter("tex", q)
	for b in _brilhos:
		var l: float = sin(_t * 2.0 + b[2]) * 0.3 + 0.7
		(b[0] as ShaderMaterial).set_shader_parameter("cor", Color(b[1].r * l, b[1].g * l, b[1].b * l))
		(b[3] as Node3D).scale = Vector3.ONE * l
	for f in _fumacas:
		(f[0] as CPUParticles3D).emitting = fmod(_t + f[3], f[2]) < f[1]
	if not _luz_osso.is_empty():
		var l := randf_range(0.7, 1.0)
		for mt in _luz_osso:
			mt.set_shader_parameter("cor", Color(0.4 * l, 0.7 * l, l))
	for g in _giram:
		(g[0] as ShaderMaterial).set_shader_parameter("giro", deg_to_rad(fmod(_t * 100.0, 360.0)) * g[1])
	if not _portas.is_empty():
		_mexer_portas(dt)
	if _portal:
		for b: Node3D in _portal.get_children():
			b.rotate_object_local(Vector3(0, 0, 1), deg_to_rad(float(b.get_meta("vel"))) * dt)
		# a luz do portal passeia entre as cores (sin de 1,1, 1,7 e 1,3 por segundo em cada canal)
		var cor := Color(0.25 + 0.55 * (sin(_t * 1.1) * 0.5 + 0.5), 0.25 + 0.55 * (sin(_t * 1.7) * 0.5 + 0.5), 0.25 + 0.55 * (sin(_t * 1.3) * 0.5 + 0.5))
		for mt in _portal_mats:
			mt.set_shader_parameter("cor", cor)
	# a neve e as folhas nascem em volta do heroi: de -8 a +8 m em X, de -5 a +9 m em Y do MU
	if (_cai or _cai2) and mundo.seguir and is_instance_valid(mundo.seguir):
		var h: Vector3 = mundo.seguir.global_position
		var alto := 3.0 if mundo.numero in [3, 11, 80] else 2.0
		for c in [_cai, _cai2]:
			if c:
				c.global_position = h + Vector3(0, alto, -2.0)
