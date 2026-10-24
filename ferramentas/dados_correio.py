"""Texturas das janelas antigas do cliente S6 (amigos, cartas, sala de chat: CUIBaseWindow) e da caixa de chat
(CNewUIChatInputBox) pra godot/dados/hud. Uso: python3 ferramentas/dados_correio.py"""
import os, subprocess, sys

AQUI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(AQUI, "s6", "cliente", "MU Client 1.04d - Season 6E3", "Data")
nomes = ["win_titlebar", "win_button", "win_size", "win_resize", "win_scrollbar", "win_check", "win_mail", "win_mark",
         "win_letter", "win_man", "win_push", "win_question", "webzenmail"]
chat = ["back", "btn_alpha", "btn_size", "chat_on", "frame_on", "gens_on", "guild_on", "main(s)=chat_main", "normal_on",
        "party_on", "system_on", "whisper_on", "whisper"]
pares = [n + "=" + n for n in nomes]
for c in chat:
    o, _, novo = c.partition("=")
    pares.append("newui_chat_" + o + "=" + (novo or "chat_" + o))
subprocess.run([sys.executable, os.path.join(AQUI, "ferramentas", "interface.py"), os.path.join(DATA, "Interface"),
                os.path.join(AQUI, "godot", "dados", "hud")] + pares, check=True)
# sons do mensageiro: carta nova (iFMailAlert) e pedido de amizade / amigo entrou (iFLogInAlert)
import shutil
for orig, novo in (("iFMailAlert.wav", "carta.wav"), ("iFLogInAlert.wav", "amigo.wav")):
    shutil.copy(os.path.join(DATA, "Sound", orig), os.path.join(AQUI, "godot", "dados", "sons", novo))
    print(novo)
