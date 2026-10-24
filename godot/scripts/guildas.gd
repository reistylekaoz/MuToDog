class_name Guildas
extends RefCounted
# Guildas que o cliente ja conhece (o GuildMark do cliente S6): id -> nome, alianca e marca.
# A marca e uma grade de 8x8 com 16 cores (CreateGuildMark em ZzzInventory.cpp); a cor 0 e transparente.

const CORES := [Color8(0, 0, 0, 0), Color8(0, 0, 0), Color8(128, 128, 128), Color8(255, 255, 255),
	Color8(255, 0, 0), Color8(255, 128, 0), Color8(255, 255, 0), Color8(128, 255, 0),
	Color8(0, 255, 0), Color8(0, 255, 128), Color8(0, 255, 255), Color8(0, 128, 255),
	Color8(0, 0, 255), Color8(128, 0, 255), Color8(255, 0, 255), Color8(255, 0, 128)]

static var info := {}       # id -> {nome, alianca, tipo, logo (32 bytes), tex}


static func guardar(i: Dictionary) -> void:
	var d := i.duplicate()
	d.tex = textura(cores_da_logo(i.logo))
	info[i.id] = d


static func nome(id: int) -> String:
	return str(info[id].nome) if info.has(id) else ""


static func tex(id: int) -> Texture2D:
	return info[id].tex if info.has(id) else null


# 32 bytes (o nibble alto primeiro) -> 64 indices de cor
static func cores_da_logo(logo: PackedByteArray) -> PackedByteArray:
	var c := PackedByteArray()
	c.resize(64)
	for i in mini(logo.size(), 32):
		c[i * 2] = logo[i] >> 4
		c[i * 2 + 1] = logo[i] & 0x0F
	return c


static func textura(cores: PackedByteArray) -> ImageTexture:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for i in 64:
		img.set_pixel(i % 8, i / 8, CORES[cores[i] & 0x0F] if i < cores.size() else CORES[0])
	return ImageTexture.create_from_image(img)


static func vazia(cores: PackedByteArray) -> bool:
	for c in cores:
		if c != 0:
			return false
	return true


# cargo (GuildMemberRole) -> texto do cliente
static func cargo(c: int) -> String:
	match c:
		128: return DicaItem.t(1300)
		64: return DicaItem.t(1301)
		32: return DicaItem.t(1302)
	return ""
