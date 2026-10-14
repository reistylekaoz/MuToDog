class_name MenuSistema
extends PanelContainer
# Menu do jogo (U ou o botao da barra), como o CNewUIOptionWindow e o "sair" do MU:
# volume da musica e dos efeitos, brilho, voltar pra escolha de personagem e sair.
# As opcoes ficam guardadas em user://opcoes.cfg.

signal musica(v: float)
signal efeitos(v: float)
signal brilho(v: float)
signal trocar_personagem
signal sair_jogo

const ARQ := "user://opcoes.cfg"
var vol_musica := 0.8
var vol_efeitos := 0.8
var _brilho: HSlider


func _ready() -> void:
	var c := ConfigFile.new()
	if c.load(ARQ) == OK:
		vol_musica = c.get_value("som", "musica", vol_musica)
		vol_efeitos = c.get_value("som", "efeitos", vol_efeitos)
	var e := StyleBoxFlat.new()
	e.bg_color = Color(0.05, 0.04, 0.03, 0.94)
	e.border_color = Color(0.55, 0.45, 0.25)
	e.set_border_width_all(1)
	e.set_corner_radius_all(4)
	e.set_content_margin_all(16)
	add_theme_stylebox_override("panel", e)
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(320, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	v.add_child(Amigos._rotulo("Menu", 18, Color(1, 0.86, 0.45)))
	v.add_child(_barra("Musica", vol_musica, 0.0, 1.0, func(x):
		vol_musica = x
		_guardar()
		musica.emit(x)))
	v.add_child(_barra("Efeitos e vento", vol_efeitos, 0.0, 1.0, func(x):
		vol_efeitos = x
		_guardar()
		efeitos.emit(x)))
	var b := _barra("Brilho (- e = tambem mudam)", 2.0, 0.5, 3.0, func(x): brilho.emit(x))
	_brilho = b.get_child(1)
	v.add_child(b)
	for par in [["Escolher outro personagem", trocar_personagem], ["Sair do jogo", sair_jogo]]:
		var bt := Button.new()
		bt.text = par[0]
		var sinal: Signal = par[1]
		bt.pressed.connect(func():
			visible = false
			sinal.emit())
		v.add_child(bt)
	var fechar := Button.new()
	fechar.text = "Voltar pro jogo (U ou Esc)"
	fechar.pressed.connect(func(): visible = false)
	v.add_child(fechar)
	visible = false


func alternar(brilho_atual: float) -> void:
	visible = not visible
	if visible:
		move_to_front()
		_brilho.set_value_no_signal(brilho_atual)
		# centro da tela (o tamanho so sai depois de montar)
		await get_tree().process_frame
		position = (get_viewport_rect().size - size) / 2.0


func _barra(nome: String, v: float, de: float, ate: float, ao_mudar: Callable) -> VBoxContainer:
	var caixa := VBoxContainer.new()
	caixa.add_child(Amigos._rotulo(nome, 13, Color(0.85, 0.85, 0.9)))
	var s := HSlider.new()
	s.min_value = de
	s.max_value = ate
	s.step = 0.05
	s.value = v
	s.custom_minimum_size = Vector2(280, 20)
	s.value_changed.connect(ao_mudar)
	caixa.add_child(s)
	return caixa


func _guardar() -> void:
	var c := ConfigFile.new()
	c.set_value("som", "musica", vol_musica)
	c.set_value("som", "efeitos", vol_efeitos)
	c.save(ARQ)
