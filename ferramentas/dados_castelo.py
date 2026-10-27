"""Rodada 21 (Castle Siege 1): texturas das janelas do Guardsman (CNewUIGuardWindow) e do Senior
(CNewUICastleWindow) pra godot/dados/hud/castelo. Uso: python3 ferramentas/dados_castelo.py"""
import os, subprocess, sys

AQUI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(AQUI, "s6", "cliente", "MU Client 1.04d - Season 6E3", "Data")
SAIDA = os.path.join(AQUI, "godot", "dados", "hud", "castelo")
os.makedirs(SAIDA, exist_ok=True)
pares = ["senatusmap=mapa", "gate_button1=portao_sel", "gate_button2=portao", "suho_button1=estatua_sel",
         "suho_button2=estatua", "newui_item_money2=zen", "newui_myquest_Line=linha",
         "newui_item_table03(Up)=tabela_c", "newui_item_table03(Dw)=tabela_b", "newui_item_table03(L)=tabela_e",
         "newui_item_table03(R)=tabela_d", "newui_item_table01(L)=tabela_ce", "newui_item_table01(R)=tabela_cd",
         "newui_item_table02(L)=tabela_be", "newui_item_table02(R)=tabela_bd", "newui_btn_empty_very_small=botao",
         "newui_guild_tab04=aba", "newui_Bt_scroll_up=seta_cima", "newui_Bt_scroll_dn=seta_baixo"]
subprocess.run([sys.executable, os.path.join(AQUI, "ferramentas", "interface.py"), os.path.join(DATA, "Interface"), SAIDA] + pares, check=True)
