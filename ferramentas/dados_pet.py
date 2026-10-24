"""Rodada 11 (pets do Dark Lord): texturas da janela do pet (CNewUIPetInfoWindow) e os sons do Dark Raven
pra godot/dados. O modelo do corvo sai do conversor: conversor personagens <Data> godot/dados/personagens corvo.
Uso: python3 ferramentas/dados_pet.py"""
import os, shutil, subprocess, sys

AQUI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(AQUI, "s6", "cliente", "MU Client 1.04d - Season 6E3", "Data")
# newui_command e newui_msgbox_back ja estao em hud como skill3 e inv_fundo
pares = ["newui_pet_lifebar01=pet_vida_fundo", "newui_pet_lifebar02=pet_vida", "newui_guild_tab04=pet_aba"]
subprocess.run([sys.executable, os.path.join(AQUI, "ferramentas", "interface.py"), os.path.join(DATA, "Interface"),
                os.path.join(AQUI, "godot", "dados", "hud")] + pares, check=True)
# SOUND_DSPIRIT_SHOUT (grito no voo), _RUSH (mergulho no alvo) e _MISSILE (ataque de luz)
for orig, novo in (("DSpirit_Shout.wav", "corvo_grito.wav"), ("DSpirit_Rush.wav", "corvo_ataque.wav"),
                   ("DSpirit_Missile.wav", "corvo_magia.wav")):
    shutil.copy(os.path.join(DATA, "Sound", orig), os.path.join(AQUI, "godot", "dados", "sons", novo))
    print(novo)
