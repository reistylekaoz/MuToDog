"""Rodada 23 (In-Game Shop do S6): texturas da janela (Data/Interface/InGameShop), as caixas e o banner pra
godot/dados/hud/loja, e os scripts da loja (Data/InGameShopScript/512.2012.084: IBSCategory, IBSPackage e IBSProduct,
texto cp1252 com campos separados por @) pra godot/dados/loja.json, so com o que a janela usa.
Uso: python3 ferramentas/dados_loja.py"""
import json, os, subprocess, sys

AQUI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(AQUI, "s6", "cliente", "MU Client 1.04d - Season 6E3", "Data")
SAIDA = os.path.join(AQUI, "godot", "dados", "hud", "loja")
VERSAO = "512.2012.084"
BANNER = "583.2011.001"
os.makedirs(SAIDA, exist_ok=True)
pares = ["Ingame_Shopback=fundo", "ingame_Bt01=bt_categoria", "ingame_Deco_Center=deco_centro", "ingame_Deco_Dn=deco_pe",
         "ingame_Tab01=aba_deposito", "ingame_Tab02=aba_presente", "ingame_Tab_Up=aba_zona", "ingame_Bt_Gift=bt_presente",
         "ingame_Bt_Cash=bt_cash", "ingame_Bt_Reset=bt_atualizar", "ingame_Bt03=bt", "ingame_itembox_logo=logo",
         "ingame_Bt_page_L=pag_esq", "ingame_Bt_page_R=pag_dir", "IGS_Storage_Page=dep_pag", "IGS_Storage_Page_Left=dep_esq",
         "IGS_Storage_Page_Right=dep_dir", "ingame_pack_back01=caixa_pacote", "ingame_pack_back03=caixa_variante",
         "ingame_gift_back01=caixa_presente", "ingame_gift_icon=presente_icone", "ingame_gift_namebox=presente_nome",
         "ingame_Box_List_A=caixa_info", "ingame_Box_List_B=caixa_info_presente", "ingame_Box=caixa_texto",
         "ingame_pack_check=radio"]
subprocess.run([sys.executable, os.path.join(AQUI, "ferramentas", "interface.py"), os.path.join(DATA, "Interface", "InGameShop"),
                SAIDA] + pares, check=True)
subprocess.run([sys.executable, os.path.join(AQUI, "ferramentas", "interface.py"), os.path.join(DATA, "Interface"), SAIDA,
                "newui_msgbox_back=msg_fundo", "newui_option_top=msg_topo", "newui_item_back03=msg_baixo",
                "newui_option_back06(L)=msg_esq", "newui_option_back06(R)=msg_dir", "newui_exit_00=sair",
                "newui_menu_Bt05=bt_barra"], check=True)
subprocess.run([sys.executable, os.path.join(AQUI, "ferramentas", "interface.py"), os.path.join(DATA, "InGameShopBanner", BANNER),
                SAIDA, "20110314VG0RO1MJ5IMOVFML=banner"], check=True)


def ler(nome):
    raw = open(os.path.join(DATA, "InGameShopScript", VERSAO, nome), "rb").read()
    enc = "utf-8-sig" if raw[:3] == b"\xef\xbb\xbf" else ("utf-16" if raw[:2] == b"\xff\xfe" else "cp1252")
    return [l.split("@") for l in raw.decode(enc).replace("\r", "").split("\n") if l.strip()]


def num(v):
    try:
        return int(v)
    except ValueError:
        return 0


# categorias: so entra o filho cujo pai ja apareceu antes no arquivo (ShopCategoryList)
cats, vistos = [], set()
for f in ler("IBSCategory.txt"):
    seq, pai, raiz = num(f[0]), num(f[4]), num(f[6])
    if raiz == 1 or pai in vistos:
        vistos.add(seq)
        cats.append({"seq": seq, "nome": f[1], "evento": num(f[2]) == 199, "pai": pai, "ordem": num(f[5]), "raiz": raiz == 1})
cats.sort(key=lambda c: c["seq"])
pacotes, usados = [], set()
for f in ler("IBSPackage.txt"):
    prods = [num(x) for x in f[19].split("|") if x]
    precos = [num(x) for x in f[23].split("|") if x]
    usados.update(precos)
    pacotes.append({"cat": num(f[0]), "ordem": num(f[1]), "seq": num(f[2]), "nome": f[3], "preco": num(f[5]),
                    "descricao": f[6], "venda": num(f[8]) == 182, "presente": num(f[9]) == 184, "unidade": f[15],
                    "apagado": num(f[16]) == 180, "evento": num(f[17]) == 199, "item": num(f[20]), "produtos": prods,
                    "precos": precos, "moeda": num(f[25])})
produtos = []
for f in ler("IBSProduct.txt"):
    if num(f[6]) in usados:
        produtos.append({"seq": num(f[0]), "nome": f[1], "propriedade": f[2], "valor": f[3], "unidade": f[4],
                         "preco": num(f[5]), "preco_seq": num(f[6]), "prop_seq": num(f[14]), "tipo_unidade": num(f[16]),
                         "item": num(f[13])})
json.dump({"versao": VERSAO, "categorias": cats, "pacotes": pacotes, "produtos": produtos},
          open(os.path.join(AQUI, "godot", "dados", "loja.json"), "w"), ensure_ascii=False, indent=0)
print("categorias", len(cats), "pacotes", len(pacotes), "linhas de produto", len(produtos))
