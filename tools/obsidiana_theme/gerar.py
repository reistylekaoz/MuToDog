#!/usr/bin/env python3
"""Gera o tema RmlUi "obsidiana" (Obsidiana e prata, o Tema 3 do MU Estudo) a partir do tema modern.

O que faz, sempre do zero (apaga e refaz themes/obsidiana):
- cada .rcss/.rml do modern passa por um mapa de cores: ferro e dourado viram obsidiana, prata e cobalto, com a
  mesma luminosidade; vermelho escuro de botao e faixa vira azul noite. Fica igual: preto, branco, as cores de
  recurso (vida, mana, AG, SD: linhas com gauge-fill ou resource-) e as cores com saturacao fora do quente
  (verde, azul, roxo de raridade). So entra no tema o arquivo que mudou; o resto vem do modern (theme.ini Base).
- tokens.ini: os do modern pelo mesmo mapa, por cima a paleta do Tema 3 e as fontes.
- base.rcss ganha no fim botao, moldura, campo e barra de rolar com as pecas do Meshy (tm_botao, jm_moldura,
  tm_campo, tm_rolar, 4x), convertidas pra OZT (TGA 32 bits com 4 bytes na frente) em arte/.
- folhas escritas a mao desta pasta (rodada 5: main_frame, buff_strip, chat_input; rodada 6: base, item_grid,
  my_inventory, character_info, generic_menu_dialog, option_window) vao no fim
  das folhas geradas, sem passar pelo mapa; fundo e frente da barra e o liquido das gemas viram OZT em arte/hud_*.
- fontes Spectral SC SemiBold (titulo) e Source Sans 3 SemiBold (texto), OFL, com o nome da familia acertado.

Uso: python3 tools/obsidiana_theme/gerar.py [pasta das pecas] [pasta das fontes]
     (padrao: ~/casa/trabalho/mu-online/godot/dados/hud/tema3 e ~/casa/trabalho/mu-online/godot/fontes)
"""
import colorsys
import re
import shutil
import struct
import sys
from pathlib import Path

from fontTools.ttLib import TTFont
from PIL import Image

AQUI = Path(__file__).resolve().parent
RAIZ = AQUI.parents[1]
TEMAS = RAIZ / "src/bin/Data/Interface/RmlUi/themes"
MODERN, SAIDA = TEMAS / "modern", TEMAS / "obsidiana"
CASA = Path.home() / "casa/trabalho/mu-online/godot"
DREAM = CASA / "dados/hud/dream"
PECAS = Path(sys.argv[1]) if len(sys.argv) > 1 else CASA / "dados/hud/tema3"
FONTES = Path(sys.argv[2]) if len(sys.argv) > 2 else CASA / "fontes"

COBALTO = 211 / 360  # #78bfff
NEUTRO = 216 / 360   # obsidiana #080a0e e prata #788291

COR = re.compile(r"(?<!&)#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b|rgba?\(\s*[0-9]+\s*,\s*[0-9]+\s*,\s*[0-9]+\s*(?:,\s*[0-9.]+\s*)?\)")


def mapear_rgb(r, g, b):
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    if (r, g, b) in ((0, 0, 0), (255, 255, 255)):
        return r, g, b
    grau = h * 360
    quente = 15 <= grau <= 75
    vermelho = grau < 15 or grau > 340
    if s < 0.30 or l < 0.10:
        # ferro e quase preto: mesmo claro, matiz da obsidiana com um pouco de azul
        h2, s2 = NEUTRO, min(0.22, 0.10 + s * 0.3)
    elif quente:
        # dourado de acento e texto: cobalto, um pouco mais claro que o ouro escuro (o cobalto e claro)
        h2, s2, l = COBALTO, min(1.0, s * 1.05), min(0.92, l * 1.08)
    elif vermelho and l < 0.45:
        # faixa e botao carmim: azul noite
        h2, s2 = COBALTO + 0.01, s * 0.55
    else:
        return r, g, b
    r2, g2, b2 = colorsys.hls_to_rgb(h2, l, s2)
    return round(r2 * 255), round(g2 * 255), round(b2 * 255)


def mapear_cor(texto):
    if texto.startswith("#"):
        hx = texto[1:]
        if len(hx) == 3:
            hx = "".join(c * 2 for c in hx)
        r, g, b = (int(hx[i:i + 2], 16) for i in (0, 2, 4))
        return "#%02x%02x%02x" % mapear_rgb(r, g, b)
    nums = [n.strip() for n in texto[texto.index("(") + 1:-1].split(",")]
    r, g, b = mapear_rgb(*(int(n) for n in nums[:3]))
    if len(nums) == 4:
        return f"rgba({r}, {g}, {b}, {nums[3]})"
    return f"rgb({r}, {g}, {b})"


# Cores com sentido no jogo ficam como estao: vida/mana/AG/SD, exp, zen por faixa, nivel, linhas de tooltip de item,
# opcao de set ativa, recompensa e requisito de quest, avisos, preco da loja de cash, nomes no balao.
PROTEGIDOS = ("gauge-fill", "resource-", "exp_fill", "gold-amount", "level-text", "tip-", "tt-", "option-label",
              "balloon-name", "quest-content-row", "qp-reward-row", "warning", "igs-", "#hero", "portrait2d",
              "hud-text", "tutorial-line", "#graph", "team", "temple", "duel-text", "room-vs", "wallet-coin")


def mapear_texto(fonte):
    """Troca as cores de cada linha, menos no bloco cujo seletor (ou a propria linha) e protegido."""
    linhas = []
    seletor = ""
    for linha in fonte.splitlines(keepends=True):
        if "{" in linha:
            seletor = linha.split("{")[0] or seletor
        if not any(p in seletor or p in linha for p in PROTEGIDOS):
            linha = COR.sub(lambda m: mapear_cor(m.group(0)), linha)
        if "}" in linha:
            seletor = ""
        linhas.append(linha)
    return "".join(linhas)


# Paleta do Tema 3 (ESTILO_HUD.md do MU Estudo, TemaJoia.paleta_tema(3)) por cima do mapa automatico.
TOKENS = {
    "surface-deep": "#04060a", "surface-recessed": "#04060a", "surface-panel": "#080a0e",
    "surface-raised": "#1e2228", "surface-tooltip": "rgba(8, 10, 14, 247)", "surface-backdrop": "rgba(4, 6, 10, 160)",
    "text-primary": "#e9edf3", "text-secondary": "#b9c1cd", "text-muted": "#7d8796", "text-warm": "#dae0ea",
    "text-disabled": "#4a515c",
    "accent-gold": "#78bfff", "accent-gold-hover": "#bfe0ff", "accent-steel": "#788291", "accent-steel-hover": "#aab4c3",
    "accent-crimson": "#1a4f93", "accent-crimson-hover": "#2f7fd6",
    "border-frame": "#3e4652", "border-hover": "#78bfff", "border-selected": "#78bfff", "border-inner": "#1e2228",
    "border-title": "#3e4652",
    "metal-title-face": "#0e1a2c", "metal-title-face-dark": "#060b14",
    "font-title": "Spectral SC", "font-body": "Source Sans 3",
    "server-button": "#bfe0ff", "server-button-gray": "#7d8796", "server-button-orange": "#78bfff",
}

BASE_MESHY = """
/* ---- Obsidiana e prata: pecas do Meshy (tools/obsidiana_theme/gerar.py). Pecas em 4x, por isso resolution 4x:
   a borda da peca sai com o mesmo tamanho em dp que tem no cliente Godot. ---- */
@spritesheet obsidiana-pecas-botao {
	src: arte/tm_botao.tga;
	resolution: 4x;
	ob-botao: 0px 0px 256px 96px;          ob-botao-in: 20px 20px 216px 56px;
	ob-botao-sob: 0px 96px 256px 96px;     ob-botao-sob-in: 20px 116px 216px 56px;
	ob-botao-apertado: 0px 192px 256px 96px; ob-botao-apertado-in: 20px 212px 216px 56px;
	ob-botao-off: 0px 288px 256px 96px;    ob-botao-off-in: 20px 308px 216px 56px;
}
@spritesheet obsidiana-pecas-janela {
	src: arte/jm_moldura.tga;
	resolution: 4x;
	ob-moldura: 0px 0px 256px 256px;       ob-moldura-in: 32px 32px 192px 192px;
}
@spritesheet obsidiana-pecas-placa {
	src: arte/jm_placa.tga;
	resolution: 4x;
	ob-placa: 36px 0px 488px 76px;         ob-placa-in: 60px 20px 440px 36px;
}
@spritesheet obsidiana-pecas-campo {
	src: arte/tm_campo.tga;
	resolution: 4x;
	ob-campo: 0px 0px 256px 72px;          ob-campo-in: 16px 16px 224px 40px;
	ob-campo-foco: 0px 72px 256px 72px;    ob-campo-foco-in: 16px 88px 224px 40px;
}

.btn, .btn-icon, .btn-ok, .btn-icon-primary {
	background-color: transparent;
	decorator: ninepatch(ob-botao, ob-botao-in, 1);
	border-width: 0;
	box-shadow: none;
	color: token(text-primary);
}
.btn:hover, .btn-icon:hover, .btn-ok:hover, .btn-icon-primary:hover {
	decorator: ninepatch(ob-botao-sob, ob-botao-sob-in, 1);
	color: #ffffff;
	box-shadow: none;
}
.btn:active, .btn-icon:active {
	decorator: ninepatch(ob-botao-apertado, ob-botao-apertado-in, 1);
	box-shadow: none;
}
.btn.disabled, .btn-icon.disabled, .btn-ok.disabled {
	background-color: transparent;
	decorator: ninepatch(ob-botao-off, ob-botao-off-in, 1);
	border-width: 0;
	color: token(text-muted);
	opacity: 1;
}
.btn-icon-label, .btn-icon-primary .btn-icon-label { color: token(text-primary); }

.modern-frame, .modern-frame-crimson {
	background-color: transparent;
	decorator: ninepatch(ob-moldura, ob-moldura-in, 1);
	border-width: 0;
}
.modern-panel, .modern-panel-crimson {
	background-color: rgba(4, 6, 10, 150);
	decorator: none;
	border-width: 1dp;
	border-color: #1e2228;
	border-radius: 0;
}

/* moldura de prata por fora das janelas do modern (o anel -3dp que cada janela ja poe como primeiro filho) */
.modern-shell-edge {
	decorator: ninepatch(ob-moldura, ob-moldura-in, 1);
	border-width: 0;
	box-shadow: none;
}
.modern-groove { border-color: #1e2228; box-shadow: inset 0 0 12dp rgba(0, 0, 0, 153); }

/* placa do titulo: a barra da peca do Meshy (os losangos das pontas sao os do modern, recoloridos), no lugar da faixa carmim e do trilho de ferro */
.modern-title-plate, .modern-header-rail {
	background-color: transparent;
	decorator: ninepatch(ob-placa, ob-placa-in, 1);
	border-width: 0;
	box-shadow: none;
}
.modern-header-accent { visibility: hidden; }
.label-server, .modern-header-title { color: token(text-warm); font-family: "token(font-title)"; }

/* botoes em pixel do inventario, loja, bau e troca */
.modern-btn-px, .modern-icon-btn-px {
	background-color: transparent;
	decorator: ninepatch(ob-botao, ob-botao-in, 1);
	border-width: 0;
	box-shadow: none;
}
.modern-btn-px:hover, .modern-icon-btn-px:hover { decorator: ninepatch(ob-botao-sob, ob-botao-sob-in, 1); color: #ffffff; }
.modern-btn-px:active { decorator: ninepatch(ob-botao-apertado, ob-botao-apertado-in, 1); }

/* poco dos campos de texto (login e afins) */
.modern-control-well {
	background-color: transparent;
	decorator: ninepatch(ob-campo, ob-campo-in, 1);
	border-width: 0;
	box-shadow: none;
}

.text-field {
	background-color: transparent;
	decorator: ninepatch(ob-campo, ob-campo-in, 1);
	border-width: 0;
}
.text-field:focus { decorator: ninepatch(ob-campo-foco, ob-campo-foco-in, 1); }
/* janelas do estudo em dp (tools/estudo_dp.py): o ninepatch ja multiplica pelo dp ratio, a escala 2 deixa a borda como era no .stage esticado */
.stage.dp .text-field { decorator: ninepatch(ob-campo, ob-campo-in, 2); }
.stage.dp .text-field:focus { decorator: ninepatch(ob-campo-foco, ob-campo-foco-in, 2); }
"""


def pecas_da_janela(texto):
    """Bloco do fim de cada folha de janela: a moldura e a placa do Meshy nas classes proprias dela (a folha da janela
    carrega depois da base.rcss, entao a regra tem que estar nela pra valer)."""
    bordas = sorted(set(re.findall(r"(?m)^\.([a-z0-9-]*shell-edge)\b", texto)) - {"modern-shell-edge"})
    placas = sorted(set(re.findall(r"(?m)^\.(rail-fill|docked-header-rail-fill)\b", texto)))
    bloco = ""
    if bordas:
        bloco += ", ".join("." + c for c in bordas) + (
            " { decorator: ninepatch(ob-moldura, ob-moldura-in, 1); border-width: 0; box-shadow: none; }\n")
    if placas:
        bloco += ", ".join("." + c for c in placas) + (
            " { background-color: transparent; decorator: ninepatch(ob-placa, ob-placa-in, 1);"
            " border-width: 0; box-shadow: none; }\n")
    return "\n/* Obsidiana e prata: pecas do Meshy (tools/obsidiana_theme/gerar.py) */\n" + bloco if bloco else ""


def ozt(png, destino):
    im = Image.open(png).convert("RGBA")
    w, h = im.size
    cab = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 8)
    r, g, b, a = im.transpose(Image.FLIP_TOP_BOTTOM).split()
    destino.write_bytes(b"\0\0\0\0" + cab + Image.merge("RGBA", (b, g, r, a)).tobytes())


def fonte(origem, familia, destino):
    t = TTFont(origem)
    for rec in t["name"].names:
        if rec.nameID in (1, 4, 16):
            rec.string = familia
        elif rec.nameID == 17:
            rec.string = "Regular"
    t.save(destino)


def hud():
    """Arte da barra de baixo (HUD dream do cliente Godot, Meshy): fundo e frente em 2x (1280 x 152, em duas metades) e o liquido das
    gemas de vida, mana e veneno (104 x 112 cada, lado a lado), no gradiente do hud_mu.gd (_gema)."""
    for nome in ("fundo", "frente"):
        im = Image.open(DREAM / f"{nome}.png").convert("RGBA").resize((1280, 152), Image.LANCZOS)
        # o loader do jogo para em 1024 de largura (kBitmapMaximumWidth): vai em duas metades de 640
        for lado, x in (("e", 0), ("d", 640)):
            tmp = SAIDA / "arte" / f"hud_{nome}_{lado}.png"
            im.crop((x, 0, x + 640, 152)).save(tmp)
            ozt(tmp, tmp.with_suffix(".ozt"))
            tmp.unlink()
    w, h, gx, gy = 104, 112, 52.0, 56.0  # meia largura e meia altura do losango (GRX 26, GRY 28 em 2x)
    cores = [((255, 86, 70), (70, 4, 8)), ((90, 175, 255), (4, 18, 70)), ((120, 235, 100), (10, 60, 16))]
    folha = Image.new("RGBA", (w * 3, h))
    px = folha.load()
    for i, (claro, escuro) in enumerate(cores):
        for y in range(h):
            t = min(max(1.0 - (y + 0.5) / h, 0.0), 1.0) * 0.9 + 0.1
            cor = tuple(round(e + (c - e) * t) for c, e in zip(claro, escuro))
            for x in range(w):
                d = abs(x + 0.5 - gx) / gx + abs(y + 0.5 - gy) / gy
                if d <= 1.0:
                    a = 255 if d <= 0.97 else round(255 * (1.0 - d) / 0.03)
                    px[i * w + x, y] = cor + (a,)
    folha.save(SAIDA / "arte" / "hud_gemas.png")
    ozt(SAIDA / "arte" / "hud_gemas.png", SAIDA / "arte" / "hud_gemas.ozt")
    (SAIDA / "arte" / "hud_gemas.png").unlink()


def icones():
    """Icones desenhados aqui (nao ha glifo nas fontes do jogo), em prata com a face em cobalto: martelo do consertar
    (64 x 64, 4x de 16) e dois martelos do consertar tudo (80 x 64)."""
    from PIL import ImageDraw

    def martelo(d, dx, escala):
        def p(x, y):
            return (dx + x * escala, y * escala)
        for cor, k in (((10, 12, 16, 220), 8), ((200, 208, 220, 255), 0)):
            d.line([p(70 + k, 200 + k), p(165 + k, 105 + k)], fill=cor, width=round(30 * escala))
            d.polygon([p(x + k, y + k) for x, y in ((112, 72), (160, 24), (232, 96), (184, 144))], fill=cor)
        d.polygon([p(150, 48), p(168, 30), p(214, 76), p(196, 94)], fill=(120, 191, 255, 255))

    for nome, w, marcas in (("ico_reparo", 256, [(0, 1.0)]), ("ico_reparo_tudo", 320, [(0, 0.85), (100, 0.85)])):
        im = Image.new("RGBA", (w, 256))
        d = ImageDraw.Draw(im)
        for dx, escala in marcas:
            martelo(d, dx, escala)
        tmp = SAIDA / "arte" / f"{nome}.png"
        im.resize((w // 4, 64), Image.LANCZOS).save(tmp)
        ozt(tmp, tmp.with_suffix(".ozt"))
        tmp.unlink()


def main():
    # estudo/ (pecas com arte do S6, da camada dream do launcher; fora do git) fica
    for velho in SAIDA.glob("*") if SAIDA.exists() else []:
        if velho.name != "estudo":
            shutil.rmtree(velho) if velho.is_dir() else velho.unlink()
    (SAIDA / "arte").mkdir(parents=True)
    (SAIDA / "fontes").mkdir()
    mudados = 0
    for arq in sorted(MODERN.iterdir()):
        if arq.suffix not in (".rcss", ".rml"):
            continue
        texto = arq.read_text()
        novo = mapear_texto(texto)
        if arq.name == "base.rcss":
            novo += BASE_MESHY
        elif arq.suffix == ".rcss":
            novo += pecas_da_janela(texto)
        if (AQUI / arq.name).exists():
            # a HUD dream escrita a mao (main_frame, buff_strip) vai por cima, sem passar pelo mapa de cores
            novo += "\n" + (AQUI / arq.name).read_text()
        if novo != texto:
            (SAIDA / arq.name).write_text(novo)
            mudados += 1
    tokens = []
    for linha in (MODERN / "tokens.ini").read_text().splitlines():
        m = re.match(r"([a-z0-9-]+)=(.*)", linha)
        if m and not m.group(1).startswith(("resource-", "semantic-", "font-")):
            valor = TOKENS.get(m.group(1), mapear_texto(m.group(2)))
            tokens.append(f"{m.group(1)}={valor}")
        elif m:
            tokens.append(f"{m.group(1)}={TOKENS.get(m.group(1), m.group(2))}")
        elif not linha.startswith(";"):
            tokens.append(linha)
    (SAIDA / "tokens.ini").write_text(
        "; Obsidiana e prata (gerado por tools/obsidiana_theme/gerar.py; nao edite a mao, mude o gerador)\n"
        + "\n".join(tokens) + "\n")
    (SAIDA / "theme.ini").write_text(
        "; Obsidiana e prata: o Tema 3 do MU Estudo (obsidiana no fundo, prata na moldura, cobalto no acento).\n"
        "; Gerado por tools/obsidiana_theme/gerar.py a partir do modern; o que nao muda vem dele.\n"
        "[Theme]\nBase=modern\n\n"
        "[Fonts]\nSpectralSC=fontes/SpectralSC-SemiBold.ttf\nSourceSans3=fontes/SourceSans3-SemiBold.ttf\n\n"
        "[Meta]\nDisplayName=Obsidiana e prata\n")
    for nome in ("tm_botao", "jm_moldura", "tm_campo", "tm_rolar", "jm_x", "jm_placa", "inv_casa", "cha_caixa", "cha_mais"):
        ozt(PECAS / f"{nome}.png", SAIDA / "arte" / f"{nome}.ozt")
    hud()
    icones()
    fonte(FONTES / "SpectralSC-SemiBold.ttf", "Spectral SC", SAIDA / "fontes/SpectralSC-SemiBold.ttf")
    fonte(FONTES / "SourceSans3-SemiBold.ttf", "Source Sans 3", SAIDA / "fontes/SourceSans3-SemiBold.ttf")
    for lic in ("OFL-SpectralSC.txt", "OFL-SourceSans3.txt"):
        shutil.copy(FONTES / lic, SAIDA / "fontes" / lic)
    print(f"obsidiana: {mudados} arquivos do modern recoloridos, tokens, 9 pecas, HUD, 2 fontes")


if __name__ == "__main__":
    main()
