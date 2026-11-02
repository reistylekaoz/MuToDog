extends SceneTree
# Foto com os pacotes HD montados como no PC: monta MU_PACOTES (PacoteMapa.montar_pc) e abre o visualizador.
# Uso: MU_PACOTES=$PWD/build/hd_pck DISPLAY=:77 $G --path . --rendering-driver opengl3 --script res://testes/foto_hd_pck.gd -- --mundo 1 ... --foto x.png


func _initialize() -> void:
	PacoteMapa.montar_pc()
	change_scene_to_file.call_deferred("res://main.tscn")
