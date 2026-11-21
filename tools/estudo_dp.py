#!/usr/bin/env python3
"""MU Estudo: janelas do estudo em dp, com o texto desenhado no tamanho da tela.

Num .stage o RmlUi monta a janela em px da tela de 640 x 480 e estica tudo com transform: scale(--ui-scale) (2 em
1920x1080): a letra sai rasterizada em 8 ou 9 px e ampliada como imagem, borrada e com espaço torto entre as letras.
Com a classe .stage.dp (base.rcss) o palco tem 640 x 480 dp sem transform, e as folhas destas janelas passam de px
pra dp: o --ui-scale e o dp ratio são o mesmo número (TypographyScale), então nada muda de lugar e a fonte é
rasterizada já no tamanho final. font-effect fica em px (o RmlUi lê o número cru, 1dp seria 1 também).
O ninepatch já multiplica a borda pelo dp ratio, e o esticão dobrava de novo: nas peças do Meshy destas janelas a
escala vai de 1 pra 2, e a moldura e os botões ficam com a mesma espessura de antes em 1920x1080.

Painel encaixado em dp (só no obsidiana, que usa o RML do modern sem .counter-scaled): a janela C é um #panel que o
slot do workspace estica com transform: scale(--root-scale), e o texto de 10 a 12 px saía ampliado 2x, borrado. No
fim da folha dela entra uma cópia em dp da base, do docked_panel_frame e dela mesma (só afeta o documento dela, e
vem depois, então ganha regra por regra) e o #panel perde o transform. Sem @spritesheet na cópia (as coordenadas são
da textura e já estão definidas acima).

Uso: python3 tools/estudo_dp.py   (converte os temas modern, legacy, obsidiana e as sobreposições do obsidiana;
rodar de novo não muda nada; depois do tools/obsidiana_theme/gerar.py, rode este de novo)
"""
import re
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
TEMAS = RAIZ / "src/bin/Data/Interface/RmlUi/themes"
JANELAS = ("missoes", "rastreio_missoes", "colecoes", "alma", "eventos", "log_caca", "bau_joias", "mercado",
           "menu_f10", "reset_system", "boss_bar")
PX = re.compile(r"(?<![\w.#-])(-?\d+(?:\.\d+)?)px\b")
EFEITO = re.compile(r"font-effect\s*:[^;}]*")
NINEPATCH = re.compile(r"(ninepatch\([\w-]+, [\w-]+), 1\)")
PAINEIS = ("character_info",)
MARCA = "/* ---- MU Estudo: painel em dp (tools/estudo_dp.py; gerado, nao edite daqui pra baixo) ---- */"
ARROBA = re.compile(r"@[\w-]+[^{]*\{[^{}]*\}")


def converter(texto):
    partes, ultimo = [], 0
    for m in EFEITO.finditer(texto):
        partes.append(PX.sub(r"\1dp", texto[ultimo:m.start()]))
        partes.append(m.group(0))
        ultimo = m.end()
    partes.append(PX.sub(r"\1dp", texto[ultimo:]))
    return NINEPATCH.sub(r"\1, 2)", "".join(partes))


def painel_dp(nome):
    pasta = TEMAS / "obsidiana"
    arq = pasta / f"{nome}.rcss"
    propria = arq.read_text().split("\n" + MARCA)[0]
    copia = "\n".join(ARROBA.sub("", converter(texto)) for texto in (
        (pasta / "base.rcss").read_text(), (pasta / "docked_panel_frame.rcss").read_text(), propria))
    novo = (propria + "\n" + MARCA + "\n" + copia
            + "\n#panel, #panel.slot-placed { transform: none; }\n")
    if novo != arq.read_text():
        arq.write_text(novo)
        return 1
    return 0


def main():
    pastas = [TEMAS / t for t in ("modern", "legacy", "obsidiana")] + [RAIZ / "tools/obsidiana_theme"]
    mudados = 0
    for pasta in pastas:
        for nome in JANELAS:
            arq = pasta / f"{nome}.rcss"
            if not arq.exists():
                continue
            texto = arq.read_text()
            novo = converter(texto)
            if novo != texto:
                arq.write_text(novo)
                mudados += 1
    rml = RAIZ / "src/bin/Data/Interface/RmlUi"
    for nome in JANELAS:
        arq = rml / f"{nome}.rml"
        texto = arq.read_text()
        novo = texto.replace('<div id="screen" class="stage">', '<div id="screen" class="stage dp">')
        if novo != texto:
            arq.write_text(novo)
            mudados += 1
    mudados += sum(painel_dp(nome) for nome in PAINEIS)
    print(f"{mudados} arquivos em dp")


if __name__ == "__main__":
    main()
