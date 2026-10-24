class_name FotoMU
extends Control
# A foto da carta (CUIPhotoViewer, 119 de largura): o personagem de corpo inteiro num mundo proprio, na pose
# escolhida. Com controle (UIPHOTOVIEWER_CANCONTROL): arrastar com o esquerdo gira, a roda aproxima, o direito
# volta ao padrao (angulo 90, zoom 1). Na carta vai o giro num byte: zoom em 2 bits ((zoom*100 - 80 + 5) / 10)
# e o angulo / 6 em 6 bits; a pose vai como AT_* - AT_ATTACK1. Carta da "webzen" mostra o webzenmail.

const POSES := [[122, "parado"], [131, "saudar"], [133, "aplaudir"], [134, "gesto"], [135, "apontar"], [139, "sem_jeito"],
	[137, "chorar"], [140, "olhar"], [138, "vibrar"], [136, "duvida"], [141, "vitoria"], [142, "sorrir"], [143, "dormir"],
	[144, "frio"], [145, "de_novo"], [146, "respeito"], [147, "continencia"], [132, "tchau"], [124, "anda"],
	[148, "investida"], [128, "sentar"], [129, "pose"], [130, "curando"], [120, "soco"]]
const AT_ATTACK1 := 120

var controle := true
var angulo := 90.0
var zoom := 1.0
var pose := 0                 # posicao em POSES
var webzen := false
var vp: SubViewport
var cam: Camera3D
var boneco: Boneco
var _raiz: Node3D
var _girando := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.size = Vector2i(357, 423)
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(vp)
	_raiz = Node3D.new()
	vp.add_child(_raiz)
	cam = Camera3D.new()
	cam.fov = 30
	vp.add_child(cam)
	var amb := WorldEnvironment.new()
	amb.environment = Environment.new()
	amb.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	amb.environment.ambient_light_color = Color(1, 1, 1)
	amb.environment.ambient_light_energy = 1.0
	vp.add_child(amb)


# classe do servidor (byte da aparencia >> 3) e o equip do ClienteMU.aparencia
func definir(classe: int, equip: Dictionary) -> void:
	if boneco:
		boneco.queue_free()
		boneco = null
	webzen = false
	boneco = Boneco.da_classe(classe)
	if boneco == null:
		return
	_raiz.add_child(boneco)
	var e := equip.duplicate()
	e.erase(8)          # a foto tira o bicho (DeleteParts)
	boneco.vestir(e)
	boneco.com_emotes()
	_por_pose()
	_enquadrar()


func mostrar_webzen() -> void:
	if boneco:
		boneco.queue_free()
		boneco = null
	webzen = true
	queue_redraw()


# byte de giro da carta <-> angulo e zoom
func giro_byte() -> int:
	var z := clampi(int((zoom * 100 - 80 + 5) / 10), 0, 3)
	return ((z << 6) & 0xC0) | (int(angulo / 6) & 0x3F)


func usar_giro(b: int) -> void:
	angulo = float(b & 0x3F) * 6.0
	zoom = 0.8 + float((b >> 6) & 3) * 0.1
	_enquadrar()


func animacao_byte() -> int:
	return POSES[pose][0] - AT_ATTACK1


func usar_animacao(b: int) -> void:
	pose = 0
	for i in POSES.size():
		if POSES[i][0] == b + AT_ATTACK1:
			pose = i
	_por_pose()


func proxima(passo: int) -> void:
	pose = posmod(pose + passo, POSES.size())
	_por_pose()


func _por_pose() -> void:
	if boneco:
		var a: String = POSES[pose][1]
		boneco.tocar(a, a)


func _enquadrar() -> void:
	if boneco:
		# angulo do MU: 90 olha pra camera (o modelo nasce de costas pra ela)
		boneco.rotation_degrees = Vector3(0, angulo + 90.0, 0)
	cam.look_at_from_position(Vector3(0, 1.0, 6.2 / zoom), Vector3(0, 0.95, 0))
	queue_redraw()


func _process(_dt: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0, 0, 0, 0.6))
	if webzen:
		draw_texture_rect_region(JanelaMU.tex.webzenmail, Rect2(20, 38, 80, 62), Rect2(0, 0, 119, 141 * 195.0 / 256.0))
		return
	draw_texture_rect(vp.get_texture(), r, false)
	if controle:
		draw_texture_rect(JanelaMU.tex.win_question, Rect2(1, size.y - 17, 16, 16), false)
		if Rect2(1, size.y - 17, 16, 16).has_point(get_local_mouse_position()):
			var f := get_theme_default_font()
			var y := size.y - 3 * 14
			for t in [DicaItem.t(997), DicaItem.t(998), DicaItem.t(999)]:
				draw_string_outline(f, Vector2(18, y + 10), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 2, Color.BLACK)
				draw_string(f, Vector2(18, y + 10), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
				y += 14


func _gui_input(ev: InputEvent) -> void:
	if not controle or webzen:
		return
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			_girando = ev.pressed
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
			angulo = 90.0
			zoom = 1.0
			_enquadrar()
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = minf(zoom + 0.1, 1.1)
			_enquadrar()
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = maxf(zoom - 0.1, 0.8)
			_enquadrar()
		accept_event()
	elif ev is InputEventMouseMotion and _girando:
		angulo = fposmod(angulo - ev.relative.x * 2.0, 360.0)
		_enquadrar()
		accept_event()
