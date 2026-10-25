class_name ClienteMU
extends Node
# Conversa com o OpenMU no protocolo do Season 6 (cliente 1.04d, versao 10404):
# connect server (lista e endereco) -> game server (login, personagens, mundo).
# Os pacotes e campos sao os de openmu/src/Network/Packets/*.xml.

signal estado_mudou(estado: String, texto: String)
signal servidores(lista: Array)
signal personagens(lista: Array)
signal criou(ok: bool, motivo: int, info: Dictionary)   # F3 01: motivo 0 nome recusado, 2 sem vaga
signal apagou(resultado: int)   # F3 02: 0 nao apagou, 1 apagou, 2 senha errada
signal entrou(info: Dictionary)
signal objeto_entrou(o: Dictionary)
signal objeto_saiu(id: int)
signal objeto_andou(id: int, x: int, y: int, passos: Array)
signal objeto_moveu(id: int, x: int, y: int)
signal objeto_morreu(id: int)
signal morte(id: int, matador: int)   # C1 17 com quem matou (o Chaos Castle conta monstros e jogadores)
signal mapa_mudou(mapa: int, x: int, y: int)
signal vida(atual: int)
signal golpe(id: int, dano: int, tipo: int, escudo: int)
signal ataque(id: int, alvo: int)
signal mensagem(texto: String)
signal mana(atual: int)
signal sd(atual: int)
signal ag(atual: int)
signal maximo(qual: String, v: int)
signal experiencia(morto: int, ganho: int)
signal nivel(info: Dictionary)
signal master(info: Dictionary)          # F3 50: ao entrar com classe master (nivel, exp, pontos, maximos)
signal master_subiu(info: Dictionary)    # F3 51: subiu nivel master
signal master_skills(lista: Array)       # F3 53: skills master aprendidas (indice na arvore, nivel, valor, proximo)
signal master_skill(info: Dictionary)    # F3 52: a skill master subiu (pontos que sobraram, indice, skill, nivel, valores)
signal magia_acabou(skill: int, alvo: int)          # C1 1B: o efeito dessa skill acabou no alvo
signal item_efeito(tipo: int, segundos: int)        # C3 29: bebeu Ale (0), Remedy of Love (1) ou Potion of Soul (77)
signal fruta(resultado: int, pontos: int, atributo: int)   # C1 2C: 0 somou, 1 falhou, 3 tirou...; atributo 0 ene 1 vit 2 agi 3 for 4 com
signal efeito_item(info: Dictionary)                # C1 2D: buff de item com tempo (origem, tipo, acao 0 poe 1 tira 2 troca, segundos, efeito)
signal mostrar_efeito(quem: int, efeito: int)       # C1 48: 3 pocao de SD, 16 subiu de nivel, 17 perdeu o SD
signal veneno(dano: int, sd: int)                   # F3 07: dano do veneno em mim e o SD que ficou
signal fogos(tipo: int, x: int, y: int)             # F3 40: 0 fogos, 59 fogos de natal, 2 fanfarra
signal redemoinho(alvo: int)                        # F3 40 com tipo 58: o redemoinho da caixa que caiu
signal itens_cairam(lista: Array)
signal itens_sumiram(ids: Array)
signal pegou(slot: int, item: Dictionary)
signal nao_pegou(motivo: int)
signal zen(valor: int)
signal inventario(itens: Dictionary)
signal item_movido(slot: int, item: Dictionary, armazem: int)   # armazem: 0 inventario, 2 bau, 3 maquina do caos
signal item_nao_moveu
signal item_removido(slot: int)
signal durabilidade(slot: int, valor: int)
signal largou(ok: bool, slot: int)
signal nao_consumiu
signal item_melhorado(slot: int, item: Dictionary)   # F3 14: joia usada no item, o item como ficou
signal skills(lista: Array)
signal skill_nova(indice: int, numero: int)
signal skill_saiu(indice: int, numero: int)
signal skill_animacao(skill: int, quem: int, alvo: int)
signal area_animacao(skill: int, quem: int, x: int, y: int, giro: int)
signal efeito(ativo: bool, quem: int, efeito: int)
signal aparencia_mudou(quem: int, slot: int, chave: String, nivel: int)
signal janela_npc(tipo: int)
signal dialogo_npc(npc: int, contribuicao: int)   # C3 F9 01: NPC de conversa (Elf Soldier, Gens), numero do monstro e a contribuicao no Gens
signal loja(itens: Dictionary, tipo: int)   # tipo 0 normal (loja ou bau), 3 maquina do caos
signal bau_zen(no_bau: int, na_mochila: int)
signal mistura(resultado: int, item: Dictionary)   # 0 falhou, 1 deu certo, 2 falta zen, 3 itens demais...
signal comprou(slot: int, item: Dictionary)
signal compra_falhou
signal vendeu(ok: bool, zen: int)
signal amigos(lista: Array, cartas: int)
signal amigo_novo(nome: String, servidor: int)
signal amigo_saiu(nome: String)
signal amigo_estado(nome: String, servidor: int)
signal pedido_amizade(nome: String)
signal caixa_cartas(quantas: int, maximo: int)        # C2 C0: cartas guardadas e o maximo
signal amigo_resultado(resultado: int, nome: String)  # C1 C1 que nao foi 1 (nao existe, ja tem, lista cheia...)
signal amigo_nao_apagou(nome: String)                 # C1 C3 00
signal fala(nome: String, texto: String)              # C1 00 sem "@" (o "~", "@@", "$" e "#" vem junto)
signal cochicho(nome: String, texto: String)          # C1 02
signal cochicho_falhou()                              # C1 0C: ninguem com esse nome
signal carta(info: Dictionary)                        # C3 C6: indice, de, data, titulo, estado (0 lida, 1 nao, 2 nova)
signal carta_enviada(resultado: int, id: int)         # C1 C5
signal carta_aberta(info: Dictionary)                 # C4 C7: indice, texto, aparencia, giro, animacao
signal carta_apagada(ok: bool, indice: int)           # C1 C8
signal sala_chat(info: Dictionary)                    # C3 CA: ip, sala, token, tipo, amigo, ok (0 nao deu, 1 ok, 2 sem servidor)
signal convite_sala(ok: int, pedido: int)             # C3 CB
signal saiu(tipo: int)
signal pedido_grupo(id: int)                       # C1 40: alguem chamou pro grupo
signal grupo(lista: Array)                         # C1 42: quem esta no grupo (nome, indice, mapa, x, y, vida, vida_max)
signal heroi(id: int, estado: int)                 # C1 F3 08: estado de heroi mudou (0 novo .. 6 PK)
signal bau_trava(estado: int)                       # C1 83: 0 sem senha, 1 trancado, 10 senha errada, 11 nao criou, 12 aberto, 13 senha da conta errada
signal rage_alvos(skill: int, alvos: Array)          # C1 4B: os alvos do Dark Side (ate 5)
signal vida_invocacao(porcento: int)               # C1 F3 20: vida do bicho invocado (o OpenMU nao manda)
signal grupo_saiu                                   # C1 43: sai do grupo (fui tirado, sai ou o grupo acabou)
signal grupo_vida(lista: Array)                     # C1 44: [[indice, 0..10]] a vida de cada membro em decimos
signal pedido_duelo(id: int, nome: String)          # C1 AA 02: alguem chamou pro duelo
signal duelo(resultado: int, id: int, nome: String) # C1 AA 01: 0 comecou, outro numero recusado
signal ponto(ok: bool, atributo: int, maximo_dep: int, sd_max: int, ag_max: int)   # F3 06: ponto distribuido
# troca (C1 36 a 3D)
signal pedido_troca(nome: String)                   # C3 36: alguem quer trocar comigo
signal troca_resposta(aceita: bool, nome: String, nivel: int, guilda: int)   # C1 37: abriu (ou recusou)
signal troca_item_dele(slot: int, item: Dictionary)  # C1 39: o outro pos um item
signal troca_item_dele_saiu(slot: int)               # C1 38: o outro tirou
signal troca_zen_dele(valor: int)                    # C1 3B
signal troca_zen_ok                                  # C1 3A 01: o servidor aceitou o meu zen
signal troca_botao_dele(estado: int)                 # C1 3C: 0 solto, 1 apertado, 2 algo mudou (solta o meu)
signal troca_fim(resultado: int)                     # C1 3D: 0 cancelou, 1 trocou, 2 mochila cheia, 3 tempo, 4 item que nao troca
# loja pessoal (3F)
signal lojas(lista: Array)                           # C2 3F 00: [{id, titulo}] de quem esta com loja aberta
signal loja_fechou(id: int)                          # C1 3F 03
signal loja_itens(id: int, nome: String, titulo: String, itens: Dictionary, atualizacao: bool)   # C2 3F 05 e 3F 13
signal loja_preco(resultado: int, slot: int)         # C3 3F 01: 1 deu certo
signal loja_aberta(ok: bool)                         # C1 3F 02
signal loja_compra(resultado: int, vendedor: int, item: Dictionary, slot: int)   # C1 3F 06: 1 comprou
signal loja_vendeu(slot: int, comprador: String)    # C1 3F 08: vendi um item da minha loja
signal loja_dialogo_fechou(id: int)                  # C1 3F 12: a loja que eu olhava fechou
# MU Helper
signal helper_estado(pausado: bool, consumiu: bool, zen: int)   # C1 BF 51
signal helper_dados(dados: PackedByteArray)          # C2 AE: as 257 bytes guardadas no servidor
# quests antigas (troca de classe): o estado de cada quest vem em 2 bits, 4 por byte
signal quest_lista(quantas: int, estados: PackedByteArray)   # C1 A0
signal quest_npc(quest: int, estados: int)           # C1 A1: abriu o NPC da quest
signal quest_mudou(quest: int, resultado: int, estados: int)   # C1 A2: 0 deu certo
signal quest_premio(id: int, tipo: int, valor: int)  # C1 A3: 200 pontos, 201 2a classe, 202, 203 combo, 204 3a classe
signal quest_mortes(quest: int, mortes: Array)       # C1 A4 00: [[monstro, mortes] x5]
signal fala_objeto(id: int, texto: String)           # C1 01: fala em cima de um objeto (NPC sem quest)
# quests novas do S6 (F6): cada quest e (grupo << 16) | passo; o passo diz a fala (QuestProgress.bmd)
signal quests_do_npc(npc: int, lista: Array)         # F6 0A: [[numero, grupo]] que o NPC oferece
signal quest_passo(indice: int)                      # F6 0B: mostra a fala desse passo
signal quest_progresso(indice: int, info: Dictionary, do_npc: bool)   # F6 0C (do NPC) e F6 1B (janela T)
signal quest_concluiu(indice: int, resultado: int)   # F6 0D: 1 concluiu, 2 limite de zen, 3 mochila cheia
signal quest_desistiu(grupo: int)                    # F6 0F
signal quests_ativas(lista: Array)                   # F6 1A: [indice] em andamento
# guilda (rodada 7)
signal guilda_pedido_entrar(id: int)                 # C1 50: alguem quer entrar na minha guilda
signal guilda_resposta(resultado: int)               # C1 51: 0 recusou, 1 entrou, 2 cheia, 3 saiu do jogo, 4 nao e mestre, 5 ja tem guilda, 6 ocupado, 7 nivel
signal guilda_lista(info: Dictionary)                # C2 52: em_guilda, pontos, rival, membros [{nome, servidor, online, cargo}]
signal guilda_saiu(resultado: int)                   # C1 53: 0 senha errada, 1 saiu, 2 so o mestre desfaz, 3 falhou, 4 desfeita, 5 tirou o membro
signal guilda_criar_janela()                         # C1 54: mostra a janela de criar guilda
signal guilda_criada(ok: bool, erro: int)            # C1 56
signal guilda_jogador_saiu(id: int, mestre: bool)    # C1 5D: tirar a guilda desse jogador
signal guilda_jogadores(lista: Array)                # C2 65: [{guilda, cargo, tipo, relacao, id, novo}]
signal guilda_info(info: Dictionary)                 # C1 66: id, tipo, alianca, nome, logo (32 bytes)
signal chat_guilda(nome: String, texto: String)      # C1 00 com "@" na frente
signal relacao_pedido(tipo: int, pedido: int, id: int)            # C1 E5: tipo 1 alianca, 2 rival; pedido 1 entrar, 2 sair
signal relacao_resultado(tipo: int, pedido: int, resultado: int, id: int)   # C1 E6
signal alianca_lista(ok: bool, rivais: int, aliadas: int, guildas: Array)  # C2 E9: [{membros, logo, nome}]
signal alianca_tirou(resultado: int, pedido: int, tipo: int)      # C1 EB 01
signal guerra_resultado(resultado: int)              # C1 60: 0 nao achou, 1 pedido, 2 mestre off, 3 sem guilda, 4 falhou, 5 nao e mestre, 6 ja em guerra
signal guerra_pedido(guilda: String, tipo: int)      # C1 61: tipo 0 guerra, 1 Battle Soccer
signal guerra_comecou(guilda: String, tipo: int, time: int)       # C1 62
signal guerra_fim(resultado: int, guilda: String)    # C1 63: 0 perdeu, 1 ganhou, 2 o outro mestre cancelou, 3 cancelada
signal guerra_placar(meu: int, dele: int, tipo: int) # C1 64
signal futebol_placar(vermelho: String, gols_v: int, azul: String, gols_a: int)  # C1 F3 23: gols_v 255 tira o placar
signal gens_entrou(resultado: int, gens: int)        # F8 02: 0 entrou, 1 ja tem, 2 saiu ha pouco, 3 nivel, 4 guilda em outro, 5 mestre sem Gens, 6 grupo, 7 alianca
signal gens_saiu(resultado: int)                     # F8 04: 0 saiu, 1 sem Gens, 2 mestre nao sai, 3 NPC do outro Gens
signal gens_premio(resultado: int)                   # F8 0A: 0 entregue, 1 fora do periodo, 2 sem direito, 3 mochila cheia, 4 ja pegou, 5 outro Gens, 6 sem Gens
signal gens_info(info: Dictionary)                   # F8 07: gens (1 Duprian, 2 Vanert), posicao, titulo (1 a 14), contribuicao, falta
signal gens_jogadores(lista: Array)                  # C2 F8 05: [{id, gens, posicao, titulo, contribuicao}]
signal pet_modo(tipo: int, modo: int, alvo: int)     # C1 A7: ordem do corvo aceita (0 normal, 1 aleatorio, 2 com o dono, 3 alvo; alvo 0xFFFF = nenhum)
signal pet_ataque(tipo: int, ataque: int, dono: int, alvo: int)   # C1 A8: o corvo de "dono" ataca (0 um alvo, 1 luz em area)
signal pet_info(info: Dictionary)                    # C1 A9: tipo (0 corvo, 1 cavalo), armazem (254 subiu, 255 desceu), slot, nivel, exp, vida
signal evento_entrada(evento: String, resultado: int)   # C1 90 (Devil Square) e C1 9A (Blood Castle): 0 entrou, 1 sem convite...
signal evento_abre(tipo: int, minutos: int, gente: int, minutos_baixo: int)   # C1 91: falta pra abrir (1 DS, 2 BC, 4 CC, 5 IT)
signal evento_contagem(estado: int)                    # C1 92: a contagem de 30 s (0 a 2 DS, 3 a 7 BC, 10 a 13 CC)
signal ds_placar(minha_pos: int, lista: Array)         # C1 93: [{nome, pontos, exp, zen}] do Devil Square
signal bc_resultado(ok: bool, nome: String, pontos: int, exp: int, zen: int)   # C1 93 com 0xFF no [4]
signal bc_estado(estado: int, segundos: int, maximo: int, mortos: int, dono: int, item: int)   # C1 9B
signal terreno(atributo: int, tirar: bool, areas: Array)   # C1 46: [[x1, y1, x2, y2]] (portao e ponte do Blood Castle)
signal texto_servidor(numero: int)                     # C1 F3 40 com 1, 3 ou 4: caixa com o texto numero (falas do Charon e do Archangel)

const VERSAO := [0x31, 0x30, 0x34, 0x30, 0x34]
const SERIAL := "k1Pk2jcET48mxL3b"
# direcao do pacote (0..7) -> passo em x, y (GameLogic/DirectionExtensions.cs)
const PASSOS := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0),
	Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0)]

var con: Conexao
var estado := "parado"
var usuario := ""
var senha := ""
var meu_id := -1
var liberadas := 0   # F3 00: classes liberadas na conta (1 Summoner, 2 DL, 4 MG, 8 RF)
var host := ""
var _ping := 0.0
var _depurar := OS.get_environment("MU_DEBUG") != ""


func log_rede(t: String) -> void:
	print("REDE ", t)


func _mudar(e: String, texto := "") -> void:
	estado = e
	log_rede("%s %s" % [e, texto])
	estado_mudou.emit(e, texto)


# 1) connect server
func conectar(h: String, porta: int) -> void:
	host = h
	_fechar()
	con = Conexao.new()
	con.abrir(h, porta)
	_mudar("conectando", "%s:%d" % [h, porta])


func pedir_servidor(id: int) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0xF4, 0x03, id & 0xFF, (id >> 8) & 0xFF]))
	_mudar("pedindo_endereco", str(id))


func entrar(u: String, s: String) -> void:
	usuario = u
	senha = s
	if estado == "esperando_login":
		_mandar_login()


func escolher(nome: String) -> void:
	var p := PackedByteArray([0xC1, 0, 0xF3, 0x03])
	p.append_array(_texto(nome, 10))
	con.enviar(p)
	_mudar("entrando", nome)


# anda pelos passos (direcoes 0..7) a partir de (x, y); ate 15 por pacote
func andar(x: int, y: int, dirs: Array) -> void:
	var n := mini(dirs.size(), 15)
	var rot: int = dirs[n - 1] if n > 0 else 0
	var p := PackedByteArray([0xC1, 0, 0xD4, x, y, (rot << 4) | n])
	for i in range(0, n, 2):
		var a: int = dirs[i]
		var b: int = dirs[i + 1] if i + 1 < n else 0
		p.append((a << 4) | b)
	con.enviar(p)


# ataque sem skill: alvo, acao que o boneco toca e pra onde olha (indice de PASSOS)
func atacar(alvo: int, acao: int, direcao: int) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0x11, (alvo >> 8) & 0xFF, alvo & 0xFF, acao & 0xFF, direcao & 0x07]))


func pegar(item: int) -> void:
	con.enviar(PackedByteArray([0xC3, 0, 0x22, (item >> 8) & 0xFF, item & 0xFF]))


# itens: inventario e 0 (equipamento 0..11, mochila 12..75), bau 2 (0..119), maquina do caos 3 (0..31)
func mover_item(de: int, para: int, dados: PackedByteArray, de_arm := 0, para_arm := 0) -> void:
	var p := PackedByteArray([0xC3, 0, 0x24, de_arm, de])
	p.append_array(dados)
	p.append_array(PackedByteArray([para_arm, para]))
	con.enviar(p)


# uso: so a fruta (0 soma pontos, 1 tira)
func usar_item(slot: int, alvo := 0, uso := 0) -> void:
	con.enviar(PackedByteArray([0xC3, 0, 0x26, slot, alvo, uso]))


func largar_item(x: int, y: int, slot: int) -> void:
	con.enviar(PackedByteArray([0xC3, 0, 0x23, x, y, slot]))


# skill num alvo (ataque, cura, buff; o alvo pode ser eu mesmo)
func skill_alvo(skill: int, alvo: int) -> void:
	con.enviar(PackedByteArray([0xC3, 0, 0x19, (skill >> 8) & 0xFF, skill & 0xFF, (alvo >> 8) & 0xFF, alvo & 0xFF]))


# Rage Fighter: C3 4A avisa os outros do golpe (a animacao); o dano vem do C3 19 que segue
func skill_rage(skill: int, alvo: int) -> void:
	con.enviar(PackedByteArray([0xC3, 0, 0x4A, (skill >> 8) & 0xFF, skill & 0xFF, 0, (alvo >> 8) & 0xFF, alvo & 0xFF]))


# C1 4B: Dark Side; o servidor escolhe ate 5 alvos perto, responde com eles e ja bate
func skill_rage_area(skill: int, alvo: int) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0x4B, (skill >> 8) & 0xFF, skill & 0xFF, (alvo >> 8) & 0xFF, alvo & 0xFF]))


# skill de area: centro (x, y), giro 0..255 e o contador de animacao (1..50, um por pedido)
var _contador := 1


func skill_area(skill: int, x: int, y: int, giro: int, extra := 0) -> int:
	var c := _contador
	_contador = 1 if _contador >= 0x32 else _contador + 1
	con.enviar(PackedByteArray([0xC3, 0, 0x1E, (skill >> 8) & 0xFF, skill & 0xFF, x, y, giro & 0xFF, 0, 0,
		(extra >> 8) & 0xFF, extra & 0xFF, c]))
	return c


# acertos de uma skill de area que o cliente escolhe (AreaSkillExplicitHits)
func skill_acertos(skill: int, x: int, y: int, anim: int, alvos: Array) -> void:
	var c := _contador
	_contador = 1 if _contador >= 0x32 else _contador + 1
	var p := PackedByteArray([0xC3, 0, 0xDB, (skill >> 8) & 0xFF, skill & 0xFF, x, y, c, alvos.size()])
	for a in alvos:
		p.append_array(PackedByteArray([(a >> 8) & 0xFF, a & 0xFF, anim]))
	con.enviar(p)


# --- mover de mapa --------------------------------------------------------------

# pisou num portal (EnterGate do mapa): o servidor confere nivel e posicao e manda MapChanged
# Teleport (skill 6): o mesmo pedido do portal, com portao 0 e o tile de destino
func teleporte(x: int, y: int) -> void:
	con.enviar(PackedByteArray([0xC3, 0, 0x1C, 0, 0, 0, x & 0xFF, y & 0xFF]))


# Teleport Ally (skill 15): id do aliado em little endian e o tile perto de mim
func teleporte_aliado(alvo: int, x: int, y: int) -> void:
	con.enviar(PackedByteArray([0xC3, 0, 0xB0, alvo & 0xFF, (alvo >> 8) & 0xFF, x & 0xFF, y & 0xFF]))


func entrar_portal(numero: int) -> void:
	con.enviar(PackedByteArray([0xC3, 0, 0x1C, 0, numero & 0xFF, (numero >> 8) & 0xFF, 0, 0]))


# janela Move (M): indice da lista do servidor (WarpInfo); paga o zen se puder ir
func mover_para(indice: int) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0x8E, 0x02, 0, 0, 0, 0, indice & 0xFF, (indice >> 8) & 0xFF]))


# --- NPC, loja ------------------------------------------------------------------

func falar_npc(id: int) -> void:
	con.enviar(PackedByteArray([0xC3, 0, 0x30, (id >> 8) & 0xFF, id & 0xFF]))


func buff_npc() -> void:
	# F6 31 (NpcBuffRequest): a resposta 902 da conversa da Elf Soldier
	con.enviar(PackedByteArray([0xC1, 0, 0xF6, 0x31]))


# --- quests novas do S6 (F6; numero e grupo em LE) ---------------------------------

func _f6(sub: int, numero := -1, grupo := 0, extra := []) -> void:
	var p := PackedByteArray([0xC1, 0, 0xF6, sub])
	if numero >= 0:
		p.append_array(PackedByteArray([numero & 0xFF, numero >> 8, grupo & 0xFF, grupo >> 8]))
	p.append_array(PackedByteArray(extra))
	con.enviar(p)


func quests_disponiveis() -> void:          # resposta 901 da conversa
	_f6(0x30)


func quest_escolher(numero: int, grupo: int, linha: int) -> void:
	_f6(0x0A, numero, grupo, [linha])


func quest_seguir(numero: int, grupo: int, acao: int) -> void:   # 1 aceita, 2 recusa
	_f6(0x0B, numero, grupo, [acao])


func quest_concluir(numero: int, grupo: int) -> void:
	_f6(0x0D, numero, grupo)


func quest_desistir(numero: int, grupo: int) -> void:
	_f6(0x0F, numero, grupo)


func quest_pedir_estado(numero: int, grupo: int) -> void:
	_f6(0x1B, numero, grupo)


func pedir_quests_ativas() -> void:
	_f6(0x1A)


# F6 0C / 1B: pedidos (tipo, id, quantos, feitos, item) e premios (tipo, id, quanto, item).
# C1 (o S6): pedidos de 26 bytes a partir do 11, premios de 22 a partir do 141;
# C2 (cliente novo, "Extended"): contagens antes do numero, pedidos de 28 a partir do 12, premios de 24 a partir do 152.
static func _quest_info(p: PackedByteArray, c: int) -> Dictionary:
	var ext := p[0] == 0xC2
	var num: int
	var grupo: int
	var nc: int
	var nr: int
	var oc: int
	var orw: int
	if ext:
		nc = p[c + 2]
		nr = p[c + 3]
		num = p[c + 5] | (p[c + 6] << 8)
		grupo = p[c + 7] | (p[c + 8] << 8)
		oc = 12
		orw = 152
	else:
		num = p[c + 2] | (p[c + 3] << 8)
		grupo = p[c + 4] | (p[c + 5] << 8)
		nc = p[c + 6]
		nr = p[c + 7]
		oc = 11
		orw = 141
	var tc := 28 if ext else 26
	var tr := 24 if ext else 22
	var di := 2 if ext else 4   # onde comeca o id dentro de cada um
	var pedidos := []
	for i in mini(nc, 5):
		var o := oc + i * tc
		if o + tc > p.size():
			break
		var d := {"tipo": p[o], "id": p[o + di] | (p[o + di + 1] << 8), "quantos": _ler_le(p, o + di + 2),
			"feitos": _ler_le(p, o + di + 6)}
		if d.tipo == 4:
			d.item = item_de(p, o + di + 10)
		pedidos.append(d)
	var premios := []
	for i in mini(nr, 5):
		var o := orw + i * tr
		if o + tr > p.size():
			break
		var d := {"tipo": p[o], "id": p[o + di] | (p[o + di + 1] << 8), "quanto": _ler_le(p, o + di + 2)}
		if d.tipo & 0x1F == 4:
			d.item = item_de(p, o + di + 6)
		premios.append(d)
	return {"numero": num, "grupo": grupo, "pedidos": pedidos, "premios": premios}


static func _lista_quests(p: PackedByteArray, o: int, n: int) -> Array:
	var l := []
	for i in n:
		if o + i * 4 + 4 > p.size():
			break
		l.append([p[o + i * 4] | (p[o + i * 4 + 1] << 8), p[o + i * 4 + 2] | (p[o + i * 4 + 3] << 8)])
	return l


# C1 A0: pede o estado das quests antigas (o S6 pede ao entrar no mundo)
func pedir_quests() -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0xA0]))


# C1 A2: estado novo da quest (1 ativa: aceitar ou entregar, 2 concluida, 3 desistir)
func quest_estado(quest: int, estado: int) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0xA2, quest & 0xFF, estado & 0xFF]))


func fechar_npc() -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0x31]))


# C1 90: entrar no Devil Square pelo Charon (nivel 0 a 6; o cliente manda 0xFF no lugar do convite
# e o servidor procura na mochila)
func entrar_devil(nivel: int) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0x90, nivel, 0xFF]))


# C1 9A: entrar no Blood Castle pelo Messenger of Archangel (castelo 1 a 8)
func entrar_blood(castelo: int) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0x9A, castelo, 0xFF]))


# C1 AF 01: entrar no Chaos Castle com a Armor of Guardsman (nivel da armadura e a casa dela na mochila)
func entrar_caos(nivel: int, slot: int) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0xAF, 0x01, nivel, slot]))


# C1 91: quanto falta pra abrir o evento (clique direito no convite ou na capa)
func perguntar_evento(tipo: int, nivel: int) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0x91, tipo, nivel]))


func comprar(slot: int) -> void:
	con.enviar(PackedByteArray([0xC3, 0, 0x32, slot]))


func vender(slot: int) -> void:
	con.enviar(PackedByteArray([0xC3, 0, 0x33, slot]))


# zen do bau: direcao 0 guarda (mochila -> bau), 1 tira
func zen_bau(direcao: int, valor: int) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0x81, direcao, valor & 0xFF, (valor >> 8) & 0xFF, (valor >> 16) & 0xFF, (valor >> 24) & 0xFF]))


func fechar_bau() -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0x82]))


# combinar sem dizer a receita (C1 03 86): o OpenMU acha a receita pelos itens da maquina
func misturar() -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0x86]))


func fechar_mistura() -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0x87]))


# --- amigos ----------------------------------------------------------------------

func _nome10(nome: String) -> PackedByteArray:
	var b := nome.to_utf8_buffer().slice(0, 10)
	b.resize(10)
	return b


# chat publico (C1 00: meu nome em 10 bytes e o texto com o zero do fim); "/comando" vira comando no OpenMU
func dizer(meu_nome: String, texto: String) -> void:
	var p := PackedByteArray([0xC1, 0, 0x00])
	p.append_array(_nome10(meu_nome))
	var t := texto.to_utf8_buffer().slice(0, 89)
	t.append(0)
	p.append_array(t)
	con.enviar(p)


func adicionar_amigo(nome: String) -> void:
	var p := PackedByteArray([0xC1, 0, 0xC1])
	p.append_array(_nome10(nome))
	con.enviar(p)


func apagar_amigo(nome: String) -> void:
	var p := PackedByteArray([0xC1, 0, 0xC3])
	p.append_array(_nome10(nome))
	con.enviar(p)


func responder_amizade(aceita: bool, nome: String) -> void:
	var p := PackedByteArray([0xC1, 0, 0xC2, 1 if aceita else 0])
	p.append_array(_nome10(nome))
	con.enviar(p)


# cochicho (C1 02): nome de quem recebe em 10 bytes e o texto
func cochichar(para: String, texto: String) -> void:
	var p := PackedByteArray([0xC1, 0, 0x02])
	p.append_array(_nome10(para))
	var t := texto.to_utf8_buffer().slice(0, 89)
	t.append(0)
	p.append_array(t)
	con.enviar(p)


# C1 C4: "Refuse Chat" manda 0, aceitar manda 1 (o OpenMU so olha o bit 1: com 2 o personagem some como offline)
func estado_chat(estado: int) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0xC4, estado]))


# C4 C5 (SendLetter): id da janela, quem recebe, titulo de 60, giro e pose da foto, tamanho e o texto
func enviar_carta(id: int, para: String, titulo: String, texto: String, giro: int, animacao: int) -> void:
	var p := PackedByteArray([0xC4, 0, 0, 0xC5])
	p.append_array(PackedByteArray([id & 0xFF, (id >> 8) & 0xFF, (id >> 16) & 0xFF, (id >> 24) & 0xFF]))
	p.append_array(_nome10(para))
	p.append_array(_texto(titulo, 60))
	p.append_array(PackedByteArray([giro & 0xFF, animacao & 0xFF]))
	var t := texto.to_utf8_buffer().slice(0, 1000)
	p.append_array(PackedByteArray([t.size() & 0xFF, t.size() >> 8]))
	p.append_array(t)
	if t.is_empty():
		p.append(0)
	con.enviar(p)


# C1 A7: ordem pro corvo (tipo 0 Dark Raven); alvo so no modo 3 (0xFFFF nos outros)
func comando_pet(tipo: int, modo: int, alvo := 0xFFFF) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0xA7, tipo, modo, (alvo >> 8) & 0xFF, alvo & 0xFF]))


# C1 A9: ficha do pet (tipo 0 corvo, 1 cavalo) no armazem (0 mochila, 1 bau, 2 e 3 troca, 4 caos, 6 loja do NPC) e slot
func pedir_info_pet(tipo: int, armazem: int, slot: int) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0xA9, tipo, armazem, slot]))


func ler_carta(indice: int) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0xC7, 0, indice & 0xFF, indice >> 8]))


func apagar_carta(indice: int) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0xC8, 0, indice & 0xFF, indice >> 8]))


# C1 CA: abre uma sala de chat com o amigo (os dois online e amigos um do outro)
func abrir_sala(amigo: String) -> void:
	var p := PackedByteArray([0xC1, 0, 0xCA])
	p.append_array(_nome10(amigo))
	con.enviar(p)


# C1 CB: chama o amigo pra sala aberta; sala e pedido vao em big endian
func convidar_sala(amigo: String, sala: int, pedido: int) -> void:
	var p := PackedByteArray([0xC1, 0, 0xCB])
	p.append_array(_nome10(amigo))
	p.append_array(PackedByteArray([sala >> 8, sala & 0xFF, (pedido >> 24) & 0xFF, (pedido >> 16) & 0xFF,
		(pedido >> 8) & 0xFF, pedido & 0xFF]))
	con.enviar(p)


# --- sair: 0 fecha o jogo, 1 volta pra escolha de personagem, 2 pra de servidor ----

func sair_para(tipo: int) -> void:
	con.enviar(PackedByteArray([0xC3, 0, 0xF1, 0x02, tipo]))


# C1 F3 01: classe no numero do servidor (0 DW, 4 DK, 8 Elf, 12 MG, 16 DL, 20 Sum, 24 RF)
func criar_personagem(nome: String, classe: int) -> void:
	var p := PackedByteArray([0xC1, 0, 0xF3, 0x01])
	p.append_array(_texto(nome, 10))
	p.append(classe << 2)
	con.enviar(p)


# C1 F3 02: nome e o codigo de seguranca (o OpenMU aceita a senha da conta)
func apagar_personagem(nome: String, codigo: String) -> void:
	var p := PackedByteArray([0xC1, 0, 0xF3, 0x02])
	p.append_array(_texto(nome, 10))
	p.append_array(_texto(codigo, 10))
	con.enviar(p)


func pedir_personagens() -> void:
	_mudar("logado")
	_pedir_lista()


# --- comandos (janela D) -----------------------------------------------------------

func chamar_grupo(id: int) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0x40, (id >> 8) & 0xFF, id & 0xFF]))


func responder_grupo(aceito: bool, id: int) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0x41, 1 if aceito else 0, (id >> 8) & 0xFF, id & 0xFF]))


# C1 83: 00 destranca o bau (senha de 4 digitos), 01 cria a senha (com a senha da conta), 02 tira a senha
func senha_bau(sub: int, pin: int, senha := "") -> void:
	var p := PackedByteArray([0xC1, 0, 0x83, sub, pin & 0xFF, (pin >> 8) & 0xFF])
	if sub == 0:
		p.append(0)   # o pacote do OpenMU tem 7 bytes
	else:
		p.append_array(_texto(senha, 20))
		p.append(0)
	con.enviar(p)


# --- guilda ---------------------------------------------------------------------

# C1 50: pede pra entrar na guilda do mestre com esse id
func pedir_entrar_guilda(id: int) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0x50, (id >> 8) & 0xFF, id & 0xFF]))


func responder_guilda(aceito: bool, id: int) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0x51, 1 if aceito else 0, (id >> 8) & 0xFF, id & 0xFF]))


func pedir_lista_guilda() -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0x52]))


# C1 53: tira esse nome da guilda; o proprio nome sai, o mestre tirando a si mesmo desfaz
func tirar_da_guilda(nome: String, senha := "") -> void:
	var p := PackedByteArray([0xC1, 0, 0x53])
	p.append_array(_nome10(nome))
	p.append_array(_texto(senha, 20))
	con.enviar(p)


# C1 54: resposta ao Guild Master (1 abre a criacao, 0 fecha)
func responder_mestre_guilda(criar: bool) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0x54, 1 if criar else 0]))


# C1 55: nome de 8 e a marca de 64 cores em 32 bytes (a primeira no nibble alto)
func criar_guilda(nome: String, marca: PackedByteArray) -> void:
	var p := PackedByteArray([0xC1, 0, 0x55, 0])
	p.append_array(_texto(nome, 8))
	for i in 32:
		p.append(((marca[i * 2] & 0x0F) << 4) | (marca[i * 2 + 1] & 0x0F))
	con.enviar(p)


func cancelar_criar_guilda() -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0x57]))


func pedir_info_guilda(guilda: int) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0x66, 0, guilda & 0xFF, (guilda >> 8) & 0xFF, (guilda >> 16) & 0xFF, (guilda >> 24) & 0xFF]))


# C1 E1: tipo 1 nomeia, 2 troca, 3 tira o cargo; cargo 32 Battle Master, 64 assistente
func cargo_guilda(tipo: int, cargo: int, nome: String) -> void:
	var p := PackedByteArray([0xC1, 0, 0xE1, tipo, cargo])
	p.append_array(_nome10(nome))
	con.enviar(p)


# C1 E5: tipo 1 alianca, 2 rival; pedido 1 entrar, 2 sair; o alvo e o mestre da outra guilda
func pedir_relacao(tipo: int, pedido: int, id: int) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0xE5, tipo, pedido, (id >> 8) & 0xFF, id & 0xFF]))


func responder_relacao(tipo: int, pedido: int, ok: bool, id: int) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0xE6, tipo, pedido, 1 if ok else 0, (id >> 8) & 0xFF, id & 0xFF]))


func pedir_alianca() -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0xE9]))


# C1 EB 01: o mestre da alianca tira uma guilda dela
func tirar_da_alianca(guilda: String) -> void:
	var p := PackedByteArray([0xC1, 0, 0xEB, 0x01])
	p.append_array(_texto(guilda, 8))
	con.enviar(p)


func responder_guerra(ok: bool) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0x61, 1 if ok else 0]))


# Gens: F8 01 entrar (1 Duprian, 2 Vanert), F8 03 sair, F8 09 premio, F8 0B info (janela B)
func gens_entrar(gens: int) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0xF8, 0x01, gens]))


func gens_sair() -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0xF8, 0x03]))


func gens_pedir_premio(gens: int) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0xF8, 0x09, gens]))


func gens_pedir_info() -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0xF8, 0x0B]))


func pedir_grupo() -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0x42]))


# C1 43: o lider tira quem quiser; cada um tira a si mesmo (sai do grupo)
func tirar_do_grupo(indice: int) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0x43, indice]))


func chamar_duelo(id: int, nome: String) -> void:
	var p := PackedByteArray([0xC1, 0, 0xAA, 0x01, (id >> 8) & 0xFF, id & 0xFF])
	p.append_array(_nome10(nome))
	con.enviar(p)


func responder_duelo(aceito: bool, id: int, nome: String) -> void:
	var p := PackedByteArray([0xC1, 0, 0xAA, 0x02, 1 if aceito else 0, id & 0xFF, (id >> 8) & 0xFF])
	p.append_array(_nome10(nome))
	con.enviar(p)


# C1 F3 06: 1 ponto no atributo (0 forca, 1 agilidade, 2 vitalidade, 3 energia, 4 comando)
func adicionar_ponto(atributo: int) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0xF3, 0x06, atributo]))


# C1 F3 52: 1 ponto master na skill (aprende no primeiro); o servidor responde F3 52 ou nada
func subir_master(skill: int) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0xF3, 0x52, skill & 0xFF, skill >> 8]))


# --- troca --------------------------------------------------------------------------

func pedir_troca(id: int) -> void:
	con.enviar(PackedByteArray([0xC3, 0, 0x36, (id >> 8) & 0xFF, id & 0xFF]))


func responder_troca(aceita: bool) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0x37, 1 if aceita else 0]))


func zen_troca(valor: int) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0x3A, 0, valor & 0xFF, (valor >> 8) & 0xFF, (valor >> 16) & 0xFF, (valor >> 24) & 0xFF]))


func botao_troca(apertado: bool) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0x3C, 1 if apertado else 0]))


func cancelar_troca() -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0x3D]))


# --- loja pessoal (o item da loja mora na mochila, slots 204 a 235) ------------------

func preco_loja(slot: int, preco: int) -> void:
	con.enviar(PackedByteArray([0xC3, 0, 0x3F, 0x01, slot, preco & 0xFF, (preco >> 8) & 0xFF, (preco >> 16) & 0xFF, (preco >> 24) & 0xFF]))


func abrir_loja(titulo: String) -> void:
	var p := PackedByteArray([0xC3, 0, 0x3F, 0x02])
	p.append_array(_texto(titulo, 26))
	con.enviar(p)


func fechar_loja() -> void:
	con.enviar(PackedByteArray([0xC3, 0, 0x3F, 0x03]))


func ver_loja(id: int, nome: String) -> void:
	var p := PackedByteArray([0xC3, 0, 0x3F, 0x05, (id >> 8) & 0xFF, id & 0xFF])
	p.append_array(_nome10(nome))
	con.enviar(p)


func comprar_loja(id: int, nome: String, slot: int) -> void:
	var p := PackedByteArray([0xC3, 0, 0x3F, 0x06, (id >> 8) & 0xFF, id & 0xFF])
	p.append_array(_nome10(nome))
	p.append(slot)
	con.enviar(p)


func sair_loja(id: int, nome: String) -> void:
	var p := PackedByteArray([0xC3, 0, 0x3F, 0x07, (id >> 8) & 0xFF, id & 0xFF])
	p.append_array(_nome10(nome))
	con.enviar(p)


# --- MU Helper: o servidor so liga, desliga e cobra o zen; quem caca e o cliente ----

func helper(ligar: bool) -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0xBF, 0x51, 0 if ligar else 1]))


func salvar_helper(dados: PackedByteArray) -> void:
	var p := PackedByteArray([0xC2, 0, 0, 0xAE])
	var d := dados.slice(0, 257)
	d.resize(257)
	p.append_array(d)
	con.enviar(p)


func pronto_no_mapa() -> void:
	con.enviar(PackedByteArray([0xC1, 0, 0xF3, 0x12]))


func _pedir_lista() -> void:
	for i in 5:
		await get_tree().create_timer(0.3 if i == 0 else 2.0).timeout
		if estado != "logado" or con == null:
			return
		con.enviar(PackedByteArray([0xC1, 0, 0xF3, 0x00, 0]))


func _fechar() -> void:
	if con:
		con.fechar()
	con = null


# true enquanto o mapa novo baixa (PacoteMapa): os pacotes ficam guardados, na ordem
var segurar := false
var _guardados: Array[PackedByteArray] = []


func _process(dt: float) -> void:
	if con == null:
		return
	var ok := con.atualizar()
	if con.erro != "":
		var e := con.erro
		_fechar()
		_mudar("erro", e)
		return
	if not ok:
		return
	var atual := con
	var lista: Array[PackedByteArray] = _guardados + con.pacotes()
	_guardados = []
	for p in lista:
		if con != atual:
			break  # trocou de servidor no meio: o resto era da conexao velha
		# o jogo esta baixando o mapa novo: o que chega espera ele ficar pronto
		if segurar:
			_guardados.append(p)
			continue
		if _depurar:
			log_rede("<- " + p.slice(0, 12).hex_encode() + (" (%d)" % p.size()))
		_tratar(p)
	if estado == "jogo":
		_ping += dt
		if _ping > 10.0:
			_ping = 0.0
			var t := Time.get_ticks_msec()
			con.enviar(PackedByteArray([0xC3, 0, 0x0E, 0x00, t & 0xFF, (t >> 8) & 0xFF, (t >> 16) & 0xFF, (t >> 24) & 0xFF, 0, 0, 0, 0]))


func _tratar(p: PackedByteArray) -> void:
	var c := Cripto.tamanho_cabecalho(p[0])
	var cod := p[c]
	var sub := p[c + 1] if p.size() > c + 1 else -1
	match [cod, sub]:
		[0x00, 0x01]:
			if p.size() == 4:
				# connect server mandou ola: pede a lista
				con.enviar(PackedByteArray([0xC1, 0, 0xF4, 0x06]))
				_mudar("lista")
				return
		[0xF4, 0x06]:
			var n := (p[c + 2] << 8) | p[c + 3]
			var lista := []
			for i in n:
				var o := c + 4 + i * 4
				lista.append({"id": p[o] | (p[o + 1] << 8), "carga": p[o + 2]})
			servidores.emit(lista)
			return
		[0xF4, 0x03]:
			var ip := _ler_texto(p, 4, 16)
			var porta := p[20] | (p[21] << 8)
			_fechar()
			# o servidor pode responder com o IP de dentro do docker; o host que a pessoa digitou vale mais
			con = Conexao.new()
			con.cripto.jogo = true
			con.abrir(host, porta)
			_mudar("conectando_jogo", "%s:%d (servidor disse %s)" % [host, porta, ip])
			return
		[0xF1, 0x00]:
			meu_id = ((p[5] << 8) | p[6]) & 0x7FFF
			_mudar("esperando_login")
			if usuario != "":
				_mandar_login()
			return
		[0xF1, 0x01]:
			var r := p[4]
			if r == 1:
				_mudar("logado")
				# o OpenMU ainda esta fechando o login quando a resposta sai; pedir
				# a lista na mesma hora as vezes cai antes e ele ignora. Pede e repete.
				_pedir_lista()
			else:
				var motivos := {0: "senha errada", 2: "conta nao existe", 3: "conta ja conectada", 4: "servidor cheio", 5: "conta bloqueada", 6: "versao do cliente recusada", 8: "muitas tentativas"}
				_mudar("erro_login", motivos.get(r, "recusado (%d)" % r))
			return
		[0xF3, 0x00]:
			var n := p[6]
			var lista := []
			for i in n:
				var o := 8 + i * 34
				if o + 34 > p.size():
					break
				lista.append({"slot": p[o], "nome": _ler_texto(p, o + 1, 10), "nivel": p[o + 12] | (p[o + 13] << 8),
					"estado": p[o + 14], "classe": p[o + 15] >> 3, "equip": aparencia(p.slice(o + 15, o + 33)),
					"guilda": p[o + 33] if o + 33 < p.size() else 255})
			liberadas = p[4]
			_mudar("personagens")
			personagens.emit(lista)
			return
		[0xF3, 0x01]:
			if p.size() >= 20 and p[4] == 1:
				criou.emit(true, 1, {"nome": _ler_texto(p, 5, 10), "slot": p[15], "nivel": p[16] | (p[17] << 8), "classe": p[18] >> 3,
					"estado": p[19], "guilda": 255, "equip": {}})   # personagem novo nasce sem item (o OpenMU manda a previa toda 0xFF)
			else:
				criou.emit(false, p[4] if p.size() > 4 else 0, {})
			return
		[0xF3, 0x02]:
			apagou.emit(p[4] if p.size() > 4 else 0)
			return
		[0xF3, 0x03]:
			if p[0] == 0xC3:
				var info := {"x": p[4], "y": p[5], "mapa": p[6] | (p[7] << 8),
					"exp": _ler_be(p, 8, 8), "exp_prox": _ler_be(p, 16, 8), "pontos": p[24] | (p[25] << 8),
					"zen": p[52] | (p[53] << 8) | (p[54] << 16) | (p[55] << 24),
					"vida": p[34] | (p[35] << 8), "vida_max": p[36] | (p[37] << 8),
					"mana": p[38] | (p[39] << 8), "mana_max": p[40] | (p[41] << 8),
					"sd": p[42] | (p[43] << 8), "sd_max": p[44] | (p[45] << 8),
					"ag": p[46] | (p[47] << 8), "ag_max": p[48] | (p[49] << 8),
					"forca": p[26] | (p[27] << 8), "agilidade": p[28] | (p[29] << 8), "vitalidade": p[30] | (p[31] << 8),
					"energia": p[32] | (p[33] << 8), "comando": p[62] | (p[63] << 8) if p.size() > 63 else 0,
					"heroi": p[56] if p.size() > 56 else 3}
				_mudar("jogo")
				entrou.emit(info)
				return
		[0xF3, 0x04]:
			mapa_mudou.emit(p[6], p[4], p[5])
			return
		[0x1C, 0x0F]:
			var mapa := (p[5] << 8) | p[6]
			mapa_mudou.emit(mapa, p[7], p[8])
			if p[4] != 0:
				pronto_no_mapa()
			return
		[0x26, 0xFF]:
			vida.emit((p[4] << 8) | p[5])
			if p.size() >= 9:
				sd.emit((p[7] << 8) | p[8])
			return
		[0x27, 0xFF]:
			mana.emit((p[4] << 8) | p[5])
			if p.size() >= 8:
				ag.emit((p[6] << 8) | p[7])
			return
		[0x26, 0xFE]:
			maximo.emit("vida", (p[4] << 8) | p[5])
			if p.size() >= 9:
				maximo.emit("sd", (p[7] << 8) | p[8])
			return
		[0x27, 0xFE]:
			maximo.emit("mana", (p[4] << 8) | p[5])
			if p.size() >= 8:
				maximo.emit("ag", (p[6] << 8) | p[7])
			return
		[0xF3, 0x06]:
			# CharacterStatIncreaseResponse: bit 4 deu certo, nibble de baixo o atributo; maximos em LE
			ponto.emit((p[4] & 0x10) != 0, p[4] & 0x0F, p[6] | (p[7] << 8) if p.size() > 7 else 0,
				p[8] | (p[9] << 8) if p.size() > 9 else 0, p[10] | (p[11] << 8) if p.size() > 11 else 0)
			return
		[0xF3, 0x50]:
			if p.size() >= 32:
				master.emit({"nivel": _le(p, 4), "exp": _ler_be(p, 6, 8), "exp_prox": _ler_be(p, 14, 8), "pontos": _le(p, 22),
					"vida_max": _le(p, 24), "mana_max": _le(p, 26), "sd_max": _le(p, 28), "ag_max": _le(p, 30)})
				return
		[0xF3, 0x51]:
			if p.size() >= 20:
				master_subiu.emit({"nivel": _le(p, 4), "ganhou": _le(p, 6), "pontos": _le(p, 8), "pontos_max": _le(p, 10),
					"vida_max": _le(p, 12), "mana_max": _le(p, 14), "sd_max": _le(p, 16), "ag_max": _le(p, 18)})
				return
		[0xF3, 0x52]:
			if p.size() >= 28 and p[4] != 0:
				master_skill.emit({"pontos": _le(p, 6), "indice": p[8], "skill": _le(p, 12), "nivel": p[16],
					"valor": p.decode_float(20), "prox": p.decode_float(24)})
				return
		[0xF3, 0x53]:
			var lista := []
			for i in p.decode_u32(8):
				var o := 12 + i * 12
				if o + 12 > p.size():
					break
				lista.append({"indice": p[o], "nivel": p[o + 1], "valor": p.decode_float(o + 4), "prox": p.decode_float(o + 8)})
			master_skills.emit(lista)
			return
		[0xF3, 0x07]:
			if p.size() >= 8:
				veneno.emit((p[4] << 8) | p[5], (p[6] << 8) | p[7])
				return
		[0xF3, 0x40]:
			if p.size() >= 7:
				if p[4] == 1:
					# ReceiveServerCommand: 1 = fala de evento (20 ou mais vira 830 + n - 20, senao 650 + n)
					texto_servidor.emit(830 + p[5] - 20 if p[5] >= 20 else 650 + p[5])
				elif p[4] == 3 or p[4] == 4:
					texto_servidor.emit((710 if p[4] == 3 else 725) + p[5])
				elif p[4] == 58:
					redemoinho.emit(((p[5] << 8) | p[6]) & 0x7FFF)
				else:
					fogos.emit(p[4], p[5], p[6])
				return
		[0xF3, 0x08]:
			if p.size() >= 7:
				heroi.emit(((p[4] << 8) | p[5]) & 0x7FFF, p[6])
			return
		[0xF3, 0x20]:
			if p.size() >= 5:
				vida_invocacao.emit(p[4])
			return
		[0xF3, 0x14]:
			if p.size() >= 17:
				item_melhorado.emit(p[4], item_de(p, 5))
			return
		[0xF3, 0x05]:
			nivel.emit({"nivel": p[4] | (p[5] << 8), "pontos": p[6] | (p[7] << 8),
				"vida_max": p[8] | (p[9] << 8), "mana_max": p[10] | (p[11] << 8)})
			return
		[0x22, 0xFE]:
			if p[0] == 0xC3:
				zen.emit(_ler_be(p, 4, 4))
				return
		[0xF3, 0x10]:
			# C4: tamanho em 2 bytes; quantidade e itens de 1 + 12 bytes
			var itens := {}
			for i in p[5]:
				var o := 6 + i * 13
				if o + 13 > p.size():
					break
				itens[p[o]] = item_de(p, o + 1)
			inventario.emit(itens)
			return
		[0xF3, 0x11]:
			if p[4] == 0xFE:
				skill_nova.emit(p[6], p[7] | (p[8] << 8))
			elif p[4] == 0xFF:
				skill_saiu.emit(p[6], p[7] | (p[8] << 8))
			else:
				var lista := []
				for i in p[4]:
					var o := 6 + i * 4
					if o + 4 > p.size():
						break
					lista.append({"indice": p[o], "numero": p[o + 1] | (p[o + 2] << 8), "nivel": p[o + 3]})
				skills.emit(lista)
			return
		[0x26, 0xFD]:
			nao_consumiu.emit()
			return
		[0xF1, 0x02]:
			if p[0] == 0xC3:
				saiu.emit(p[4])
				return
		[0x32, 0xFF]:
			if p.size() == 4:
				compra_falhou.emit()
				return
		[0xF6, 0x0A]:
			if p.size() >= c + 6:
				quests_do_npc.emit(p[c + 2] | (p[c + 3] << 8), _lista_quests(p, c + 6, p[c + 4] | (p[c + 5] << 8)))
				return
		[0xF6, 0x0B]:
			if p.size() >= c + 6:
				quest_passo.emit(((p[c + 4] | (p[c + 5] << 8)) << 16) | p[c + 2] | (p[c + 3] << 8))
				return
		[0xF6, 0x0C], [0xF6, 0x1B]:
			if p.size() >= c + 10:
				var q := _quest_info(p, c)
				quest_progresso.emit((q.grupo << 16) | q.numero, q, sub == 0x0C)
				return
		[0xF6, 0x0D]:
			if p.size() >= c + 7:
				quest_concluiu.emit(((p[c + 4] | (p[c + 5] << 8)) << 16) | p[c + 2] | (p[c + 3] << 8), p[c + 6])
				return
		[0xF6, 0x0F]:
			if p.size() >= c + 6:
				quest_desistiu.emit(p[c + 4] | (p[c + 5] << 8))
				return
		[0xF6, 0x1A]:
			if p.size() >= c + 3:
				quests_ativas.emit(_lista_quests(p, c + 3, p[c + 2]).map(func(q): return (q[1] << 16) | q[0]))
				return
		[0xF9, 0x01]:
			if p.size() >= c + 4:
				dialogo_npc.emit(p[c + 2] | (p[c + 3] << 8), _ler_le(p, c + 6) if p.size() >= c + 10 else 0)
				return
		[0xF8, 0x02]:
			if p.size() >= 6:
				gens_entrou.emit(p[4], p[5])
				return
		[0xF8, 0x04]:
			if p.size() >= 5:
				gens_saiu.emit(p[4])
				return
		[0xF8, 0x0A]:
			if p.size() >= 5:
				gens_premio.emit(p[4])
				return
		[0xF8, 0x07]:
			if p.size() >= 24:
				gens_info.emit({"gens": p[4], "posicao": _ler_le(p, 8), "titulo": _ler_le(p, 12), "contribuicao": _ler_le(p, 16),
					"falta": _ler_le(p, 20)})
				return
		[0xF8, 0x05]:
			if p[0] == 0xC2 and p.size() >= 6:
				var l := []
				for i in p[5]:
					var o := 6 + i * 16
					if o + 16 > p.size():
						break
					l.append({"gens": p[o], "id": ((p[o + 1] << 8) | p[o + 2]) & 0x7FFF, "posicao": _ler_le(p, o + 4),
						"titulo": _ler_le(p, o + 8), "contribuicao": _ler_le(p, o + 12)})
				gens_jogadores.emit(l)
				return
		[0xEB, 0x01]:
			if p.size() >= 7:
				alianca_tirou.emit(p[4], p[5], p[6])
				return
		[0xF3, 0x23]:
			if p.size() >= 22:
				futebol_placar.emit(_ler_texto(p, 4, 8), p[12], _ler_texto(p, 13, 8), p[21])
				return
	match cod:
		0x12:
			_ler_personagens(p)
		0x45:
			if p[0] == 0xC2:
				_ler_transformados(p)
		0xA0:
			quest_lista.emit(p[3], p.slice(4))
		0xA7:
			if p.size() >= 7:
				pet_modo.emit(p[3], p[4], (p[5] << 8) | p[6])
		0xA8:
			if p.size() >= 9:
				pet_ataque.emit(p[3], p[4], ((p[5] << 8) | p[6]) & 0x7FFF, ((p[7] << 8) | p[8]) & 0x7FFF)
		0xA9:
			if p.size() >= 13:
				pet_info.emit({"tipo": p[3], "armazem": p[4], "slot": p[5], "nivel": p[6], "exp": _ler_le(p, 8), "vida": p[12]})
		0xA1:
			if p.size() >= 5:
				quest_npc.emit(p[3], p[4])
		0xA2:
			if p.size() >= 6:
				quest_mudou.emit(p[3], p[4], p[5])
		0xA3:
			if p.size() >= 7:
				quest_premio.emit(((p[3] << 8) | p[4]) & 0x7FFF, p[5], p[6])
		0xA4:
			if sub == 0x00 and p.size() >= 48:
				var m := []
				for i in 5:
					m.append([_ler_le(p, 8 + i * 8), _ler_le(p, 12 + i * 8)])
				quest_mortes.emit(p[5], m)
		0x01:
			if p[0] == 0xC1 and p.size() > 5:
				fala_objeto.emit(((p[3] << 8) | p[4]) & 0x7FFF, _ler_texto(p, 5, p.size() - 5))
		0x13:
			_ler_npcs(p)
		0x1F:
			# C2 1F: monstro invocado (elfa, Dark Lord): id, tipo, x, y, destino, giro, dono (10) e efeitos
			if p[0] == 0xC2:
				var o := 5
				for i in p[4]:
					if o + 20 > p.size():
						break
					objeto_entrou.emit({"id": ((p[o] << 8) | p[o + 1]) & 0x7FFF, "tipo": "npc",
						"numero": ((p[o + 2] << 8) | p[o + 3]) & 0x0FFF, "x": p[o + 4], "y": p[o + 5],
						"ax": p[o + 6], "ay": p[o + 7], "dono": _ler_texto(p, o + 9, 10)})
					o += 20 + p[o + 19]
		0x14:
			for i in p[3]:
				objeto_saiu.emit(((p[4 + i * 2] << 8) | p[5 + i * 2]) & 0x7FFF)
		0xD4:
			# o OpenMU manda o destino; os passos podem vir vazios, o mundo acha o caminho
			objeto_andou.emit(((p[3] << 8) | p[4]) & 0x7FFF, p[5], p[6], [])
		0x11:
			if p.size() >= 10:
				golpe.emit(((p[3] << 8) | p[4]) & 0x7FFF, (p[5] << 8) | p[6], p[7], (p[8] << 8) | p[9])
		0x18:
			if p.size() >= 9:
				ataque.emit(((p[3] << 8) | p[4]) & 0x7FFF, ((p[7] << 8) | p[8]) & 0x7FFF)
		0x15:
			objeto_moveu.emit(((p[3] << 8) | p[4]) & 0x7FFF, p[5], p[6])
		0x17:
			objeto_morreu.emit(((p[3] << 8) | p[4]) & 0x7FFF)
			if p.size() >= 9:
				morte.emit(((p[3] << 8) | p[4]) & 0x7FFF, ((p[7] << 8) | p[8]) & 0x7FFF)
		0x16:
			experiencia.emit(((p[3] << 8) | p[4]) & 0x7FFF, (p[5] << 8) | p[6])
		0x20:
			if p[0] == 0xC2:
				_ler_itens(p)
		0x21:
			if p[0] == 0xC2:
				var ids := []
				for i in p[4]:
					ids.append(((p[5 + i * 2] << 8) | p[6 + i * 2]) & 0x7FFF)
				itens_sumiram.emit(ids)
		0x24:
			if p[3] == 0xFF:
				item_nao_moveu.emit()
			elif p.size() >= 17:
				item_movido.emit(p[4], item_de(p, 5), p[3])
		0x23:
			largou.emit(p[3] != 0, p[4])
		0x25:
			# C1 25: alguem trocou o que veste; byte 1 do item = slot << 4; item vazio e tudo FF
			if p.size() >= 17:
				var it := p.slice(5, 17)
				var vazio := it[0] == 0xFF and it[5] == 0xFF
				var g: int = 0 if vazio else it[1] & 0x0F
				aparencia_mudou.emit(((p[3] << 8) | p[4]) & 0x7FFF, it[1] >> 4,
					"" if vazio else "%d,%d" % [it[5] >> 4, it[0] | ((it[3] & 0x80) << 1)], g * 2 + 1 if g > 0 else 0)
		0x28:
			item_removido.emit(p[3])
		0x2A:
			durabilidade.emit(p[3], p[4])
		0x19:
			if p.size() >= 9:
				skill_animacao.emit((p[3] << 8) | p[4], ((p[5] << 8) | p[6]) & 0x7FFF, ((p[7] << 8) | p[8]) & 0x7FFF)
		0x1E:
			if p.size() >= 10:
				area_animacao.emit((p[3] << 8) | p[4], ((p[5] << 8) | p[6]) & 0x7FFF, p[7], p[8], p[9])
		0x07:
			if p.size() >= 7:
				efeito.emit(p[3] != 0, ((p[4] << 8) | p[5]) & 0x7FFF, p[6])
		0x1B:
			if p.size() >= 7:
				magia_acabou.emit((p[3] << 8) | p[4], ((p[5] << 8) | p[6]) & 0x7FFF)
		0x29:
			if p.size() >= 6:
				item_efeito.emit(p[3], p[4] | (p[5] << 8))
		0x2C:
			if p.size() >= 7:
				fruta.emit(p[3], p[4] | (p[5] << 8), p[6])
		0x2D:
			if p.size() >= 17:
				efeito_item.emit({"origem": p[4], "tipo": p[6], "acao": p[8], "segundos": p.decode_u32(12), "efeito": p[16]})
		0x48:
			if p.size() >= 6:
				mostrar_efeito.emit(((p[3] << 8) | p[4]) & 0x7FFF, p[5])
		0x22:
			if p.size() == 4:
				nao_pegou.emit(p[3])
			elif p.size() >= 4 + 12:
				pegou.emit(p[3], item_de(p, 4))
		0x0D:
			# aviso do servidor: tipo e 9 bytes de cabecalho do aviso antes do texto
			var ini := 13 if p.size() > 13 else 4
			mensagem.emit(_ler_texto(p, ini, p.size() - ini))
		0x00:
			if p[0] == 0xC1 and p.size() > 13:
				var t := _ler_texto(p, 13, p.size() - 13)
				if t.begins_with("@") and not t.begins_with("@@"):
					chat_guilda.emit(_ler_texto(p, 3, 10), t.trim_prefix("@"))
				else:
					fala.emit(_ler_texto(p, 3, 10), t)
		0x02:
			if p[0] == 0xC1 and p.size() > 13:
				cochicho.emit(_ler_texto(p, 3, 10), _ler_texto(p, 13, p.size() - 13))
		0x0C:
			if p[0] == 0xC1:
				cochicho_falhou.emit()
		0xC1:
			# C1 C1: resultado, nome e servidor; 1 = entrou na lista
			if p[0] == 0xC1 and p.size() >= 14:
				if p[3] == 1:
					amigo_novo.emit(_ler_texto(p, 4, 10), p[14] if p.size() > 14 else 0xFF)
				else:
					amigo_resultado.emit(p[3], _ler_texto(p, 4, 10))
		0xC3:
			if p[0] == 0xC1 and p.size() >= 14:
				if p[3] == 1:
					amigo_saiu.emit(_ler_texto(p, 4, 10))
				else:
					amigo_nao_apagou.emit(_ler_texto(p, 4, 10))
		0xC5:
			if p[0] == 0xC1 and p.size() >= 8:
				carta_enviada.emit(p[3], _ler_le(p, 4))
		0xC6:
			if p[0] == 0xC3 and p.size() >= 79:
				carta.emit({"indice": p[4] | (p[5] << 8), "de": _ler_texto(p, 6, 10), "data": _ler_texto(p, 16, 30),
					"titulo": _ler_texto(p, 46, 32), "estado": p[78]})
		0xC7:
			if p[0] == 0xC4 and p.size() >= 28:
				var n := p[6] | (p[7] << 8)
				carta_aberta.emit({"indice": p[4] | (p[5] << 8), "classe": p[8] >> 3, "aparencia": aparencia(p.slice(8, 26)), "giro": p[26],
					"animacao": p[27], "texto": _ler_texto(p, 28, mini(n, p.size() - 28))})
		0xC8:
			if p[0] == 0xC1 and p.size() >= 6:
				carta_apagada.emit(p[3] != 0, p[4] | (p[5] << 8))
		0xCA:
			if p[0] == 0xC3 and p.size() >= 36:
				sala_chat.emit({"ip": _ler_texto(p, 3, 15), "sala": p[18] | (p[19] << 8), "token": _ler_le(p, 20),
					"tipo": p[24], "amigo": _ler_texto(p, 25, 10), "ok": p[35]})
		0xCB:
			if p[0] == 0xC3 and p.size() >= 8:
				convite_sala.emit(p[3], (p[4] << 24) | (p[5] << 16) | (p[6] << 8) | p[7])
		0x50:
			if p[0] == 0xC1 and p.size() >= 5:
				guilda_pedido_entrar.emit(((p[3] << 8) | p[4]) & 0x7FFF)
		0x51:
			if p[0] == 0xC1 and p.size() >= 4:
				guilda_resposta.emit(p[3])
		0x52:
			if p[0] == 0xC2 and p.size() >= 24:
				var l := []
				for i in p[5]:
					var o := 24 + i * 13
					if o + 13 > p.size():
						break
					l.append({"nome": _ler_texto(p, o, 10), "servidor": p[o + 11] & 0x7F,
						"online": (p[o + 11] & 0x80) != 0, "cargo": p[o + 12]})
				guilda_lista.emit({"em_guilda": p[4] != 0, "pontos": _ler_le(p, 8), "pontos_atual": p[12],
					"rival": _ler_texto(p, 13, 8), "membros": l})
		0x53:
			if p[0] == 0xC1 and p.size() >= 4:
				guilda_saiu.emit(p[3])
		0x54:
			if p[0] == 0xC1:
				guilda_criar_janela.emit()
		0x56:
			if p[0] == 0xC1 and p.size() >= 5:
				guilda_criada.emit(p[3] != 0, p[4])
		0x5D:
			if p[0] == 0xC1 and p.size() >= 5:
				guilda_jogador_saiu.emit(((p[3] & 0x7F) << 8) | p[4], (p[3] & 0x80) != 0)
		0x65:
			if p[0] == 0xC2 and p.size() >= 5:
				var l := []
				for i in p[4]:
					var o := 5 + i * 12
					if o + 12 > p.size():
						break
					l.append({"guilda": _ler_le(p, o), "cargo": p[o + 4], "tipo": p[o + 5], "relacao": p[o + 6],
						"id": ((p[o + 7] & 0x7F) << 8) | p[o + 8], "novo": (p[o + 7] & 0x80) != 0})
				guilda_jogadores.emit(l)
		0x66:
			if p[0] == 0xC1 and p.size() >= 57:
				guilda_info.emit({"id": _ler_le(p, 4), "tipo": p[8], "alianca": _ler_texto(p, 9, 8),
					"nome": _ler_texto(p, 17, 8), "logo": p.slice(25, 57)})
		0xE5:
			if p[0] == 0xC1 and p.size() >= 7:
				relacao_pedido.emit(p[3], p[4], ((p[5] << 8) | p[6]) & 0x7FFF)
		0xE6:
			if p[0] == 0xC1 and p.size() >= 8:
				relacao_resultado.emit(p[3], p[4], p[5], ((p[6] << 8) | p[7]) & 0x7FFF)
		0xE9:
			if p[0] == 0xC2 and p.size() >= 8:
				var l := []
				for i in p[4]:
					var o := 8 + i * 41
					if o + 41 > p.size():
						break
					l.append({"membros": p[o], "logo": p.slice(o + 1, o + 33), "nome": _ler_texto(p, o + 33, 8)})
				alianca_lista.emit(p[5] != 0, p[6], p[7], l)
		0x60:
			if p[0] == 0xC1 and p.size() >= 4:
				guerra_resultado.emit(p[3])
		0x61:
			if p[0] == 0xC1 and p.size() >= 12:
				guerra_pedido.emit(_ler_texto(p, 3, 8), p[11])
		0x62:
			if p[0] == 0xC1 and p.size() >= 13:
				guerra_comecou.emit(_ler_texto(p, 3, 8), p[11], p[12])
		0x63:
			if p[0] == 0xC1 and p.size() >= 12:
				guerra_fim.emit(p[3], _ler_texto(p, 4, 8))
		0x64:
			if p[0] == 0xC1 and p.size() >= 6:
				guerra_placar.emit(p[3], p[4], p[5])
		0x71:
			con.enviar(PackedByteArray([0xC1, 0, 0x71]))
		0x30:
			if p[0] == 0xC3:
				janela_npc.emit(p[3])
		0x90:
			if p[0] == 0xC1 and p.size() >= 4:
				evento_entrada.emit("ds", p[3])
		0x9A:
			if p[0] == 0xC1 and p.size() >= 4:
				evento_entrada.emit("bc", p[3])
		0xAF:
			# C1 AF 01: resposta da entrada no Chaos Castle (o resultado no [4])
			if p[0] == 0xC1 and p.size() >= 5 and p[3] == 0x01:
				evento_entrada.emit("cc", p[4])
		0x91:
			if p[0] == 0xC1 and p.size() >= 7:
				evento_abre.emit(p[3], p[4], p[5], p[6])
		0x92:
			if p[0] == 0xC1 and p.size() >= 4:
				evento_contagem.emit(p[3])
		0x93:
			# placar: no Blood Castle [3] diz se deu certo e [4] vem 0xFF; no Devil Square [3] e a minha
			# posicao, [4] quantos e cada um com 24 bytes (nome 10, pontos, exp e zen em LE de 4 a partir do 12)
			if p[0] == 0xC1 and p.size() >= 5:
				if p[4] == 0xFF and p.size() >= 29:
					var pts := _ler_le(p, 17)
					# os pontos do castelo tem sinal (Blood Castle Point: %d; quem falha perde 300)
					bc_resultado.emit(p[3] != 0, _ler_texto(p, 5, 10), pts - 0x100000000 if pts >= 0x80000000 else pts, _ler_le(p, 21),
						_ler_le(p, 25))
				elif p[4] != 0xFF:
					var l := []
					for i in mini(p[4], 10):
						var o := 5 + i * 24
						if o + 24 > p.size():
							break
						l.append({"nome": _ler_texto(p, o, 10), "pontos": _ler_le(p, o + 12), "exp": _ler_le(p, o + 16),
							"zen": _ler_le(p, o + 20)})
					ds_placar.emit(p[3], l)
		0x9B:
			# estado, segundos, monstros pedidos e mortos (LE de 2), quem leva a arma e o nivel dela
			if p[0] == 0xC1 and p.size() >= 13:
				bc_estado.emit(p[3], p[4] | (p[5] << 8), p[6] | (p[7] << 8), p[8] | (p[9] << 8), p[10] | (p[11] << 8), p[12])
		0x46:
			if p[0] == 0xC1 and p.size() >= 7 and p[3] == 0:
				var l := []
				for i in p[6]:
					var o := 7 + i * 4
					if o + 4 > p.size():
						break
					l.append([p[o], p[o + 1], p[o + 2], p[o + 3]])
				terreno.emit(p[4], p[5] != 0, l)
		0x31:
			# C2 31: tipo da janela, quantidade e itens de 1 + 12 bytes (slot e item)
			if p[0] == 0xC2:
				var l := {}
				for i in p[5]:
					var o := 6 + i * 13
					if o + 13 > p.size():
						break
					l[p[o]] = item_de(p, o + 1)
				loja.emit(l, p[4])
		0x81:
			if p[0] == 0xC1 and p.size() >= 12:
				bau_zen.emit(_ler_le(p, 4), _ler_le(p, 8))
		0x86:
			if p[0] == 0xC1 and p.size() >= 4:
				mistura.emit(p[3], item_de(p, 4) if p.size() >= 16 else {})
		0x32:
			if p[0] == 0xC1 and p.size() >= 16:
				comprou.emit(p[3], item_de(p, 4))
		0x33:
			if p[0] == 0xC3 and p.size() >= 8:
				vendeu.emit(p[3] != 0, p[4] | (p[5] << 8) | (p[6] << 16) | (p[7] << 24))
		0xC0:
			# C2 C0: cartas, maximo de cartas, amigos (nome 10 + servidor; 0xFF fora)
			if p[0] == 0xC2:
				var l := []
				for i in p[6]:
					var o := 7 + i * 11
					if o + 11 > p.size():
						break
					l.append({"nome": _ler_texto(p, o, 10), "servidor": p[o + 10]})
				amigos.emit(l, p[4])
				caixa_cartas.emit(p[4], p[5])
		0x40:
			if p[0] == 0xC1 and p.size() >= 5:
				pedido_grupo.emit((p[3] << 8) | p[4])
		0x42:
			# C1 42: resultado, quantidade e membros de 24 bytes (nome 10, indice, mapa, x, y...)
			if p[0] == 0xC1 and p.size() >= 5:
				var l := []
				for i in p[4]:
					var o := 5 + i * 24
					if o + 24 > p.size():
						break
					l.append({"nome": _ler_texto(p, o, 10), "indice": p[o + 10], "mapa": p[o + 11], "x": p[o + 12],
						"y": p[o + 13], "vida": _ler_le(p, o + 16), "vida_max": _ler_le(p, o + 20)})
				grupo.emit(l)
		0x4A:
			if p.size() >= 9:
				skill_animacao.emit((p[3] << 8) | p[4], ((p[5] << 8) | p[6]) & 0x7FFF, ((p[7] << 8) | p[8]) & 0x7FFF)
		0x4B:
			if p[0] == 0xC1 and p.size() >= 16:
				var l := []
				for i in 5:
					var t := p[6 + i * 2] | (p[7 + i * 2] << 8)
					if t != 0x2710:
						l.append(t & 0x7FFF)
				rage_alvos.emit(p[4] | (p[5] << 8), l)
		0x83:
			if p[0] == 0xC1 and p.size() >= 4:
				bau_trava.emit(p[3])
		0x43:
			if p[0] == 0xC1:
				grupo_saiu.emit()
		0x44:
			if p[0] == 0xC1 and p.size() >= 4:
				var l := []
				for i in p[3]:
					if 4 + i < p.size():
						l.append([p[4 + i] >> 4, p[4 + i] & 0x0F])
				grupo_vida.emit(l)
		0xAA:
			if p[0] == 0xC1 and sub == 0x02 and p.size() >= 16:
				pedido_duelo.emit(p[4] | (p[5] << 8), _ler_texto(p, 6, 10))
			elif p[0] == 0xC1 and sub == 0x01 and p.size() >= 17:
				duelo.emit(p[4], (p[5] << 8) | p[6], _ler_texto(p, 7, 10))
		0xC2:
			if p[0] == 0xC1 and p.size() >= 13:
				pedido_amizade.emit(_ler_texto(p, 3, 10))
		0xC4:
			if p[0] == 0xC1 and p.size() >= 14:
				amigo_estado.emit(_ler_texto(p, 3, 10), p[13])
		0x36:
			if p[0] == 0xC3 and p.size() >= 13:
				pedido_troca.emit(_ler_texto(p, 3, 10))
		0x37:
			if p[0] == 0xC1 and p.size() >= 20:
				troca_resposta.emit(p[3] != 0, _ler_texto(p, 4, 10), (p[14] << 8) | p[15], _ler_le(p, 16))
		0x38:
			if p[0] == 0xC1 and p.size() >= 4:
				troca_item_dele_saiu.emit(p[3])
		0x39:
			if p[0] == 0xC1 and p.size() >= 16:
				troca_item_dele.emit(p[3], item_de(p, 4))
		0x3A:
			if p[0] == 0xC1:
				troca_zen_ok.emit()
		0x3B:
			if p[0] == 0xC1 and p.size() >= 8:
				troca_zen_dele.emit(_ler_le(p, 4))
		0x3C:
			if p[0] == 0xC1 and p.size() >= 4:
				troca_botao_dele.emit(p[3])
		0x3D:
			if p[0] == 0xC1 and p.size() >= 4:
				troca_fim.emit(p[3])
		0x3F:
			_ler_loja(p, sub)
		0xBF:
			if sub == 0x51 and p.size() >= 13:
				helper_estado.emit(p[12] != 0, p[4] != 0, _ler_le(p, 8))
		0xAE:
			if p[0] == 0xC2 and p.size() >= 4:
				helper_dados.emit(p.slice(4, 4 + 257))


# 3F: loja pessoal (o S6 manda as listas em C2, as respostas em C1 e o preco em C3)
func _ler_loja(p: PackedByteArray, sub: int) -> void:
	match sub:
		0x00:
			if p[0] == 0xC2:
				var l := []
				for i in p[5]:
					var o := 6 + i * 38
					if o + 38 > p.size():
						break
					l.append({"id": ((p[o] << 8) | p[o + 1]) & 0x7FFF, "titulo": _ler_texto(p, o + 2, 36)})
				lojas.emit(l)
		0x01:
			if p.size() >= 6:
				loja_preco.emit(p[4], p[5])
		0x02:
			if p.size() >= 5:
				loja_aberta.emit(p[4] != 0)
		0x03:
			if p.size() >= 7:
				loja_fechou.emit(((p[5] << 8) | p[6]) & 0x7FFF)
		0x05, 0x13:
			if p[0] == 0xC2 and p.size() >= 55:
				var l := {}
				for i in p[54]:
					var o := 55 + i * 20
					if o + 20 > p.size():
						break
					var it := item_de(p, o + 1)
					it.preco = _ler_le(p, o + 16)
					l[p[o]] = it
				loja_itens.emit(((p[6] << 8) | p[7]) & 0x7FFF, _ler_texto(p, 8, 10), _ler_texto(p, 18, 36), l, sub == 0x13)
		0x06:
			if p[0] == 0xC1 and p.size() >= 21:
				loja_compra.emit(p[4], ((p[5] << 8) | p[6]) & 0x7FFF, item_de(p, 7) if p[4] == 1 else {}, p[20])
			elif p[0] == 0xC1 and p.size() >= 5:
				loja_compra.emit(p[4], -1, {}, -1)
		0x08:
			if p.size() >= 15:
				loja_vendeu.emit(p[4], _ler_texto(p, 5, 10))
		0x12:
			if p.size() >= 6:
				loja_dialogo_fechou.emit(((p[4] << 8) | p[5]) & 0x7FFF)


# C2 12: personagens (Season 6: 36 bytes + 1 por efeito)
func _ler_personagens(p: PackedByteArray) -> void:
	var o := 5
	for i in p[4]:
		if o + 36 > p.size():
			break
		var id := ((p[o] << 8) | p[o + 1]) & 0x7FFF
		objeto_entrou.emit({"id": id, "tipo": "eu" if id == meu_id else "jogador",
			"nome": _ler_texto(p, o + 22, 10), "classe": p[o + 4] >> 3,
			"x": p[o + 2], "y": p[o + 3], "ax": p[o + 32], "ay": p[o + 33],
			"equip": aparencia(p.slice(o + 4, o + 22)), "efeitos": Array(p.slice(o + 36, o + 36 + p[o + 35])),
			"heroi": p[o + 34] & 0x0F})
		o += 36 + p[o + 35]


# C2 45: jogador transformado (anel): id, x, y, monstro (u16 BE), nome, destino, giro<<4|heroi, aparencia e efeitos
func _ler_transformados(p: PackedByteArray) -> void:
	var o := 5
	for i in p[4]:
		if o + 38 > p.size():
			break
		var id := ((p[o] << 8) | p[o + 1]) & 0x7FFF
		objeto_entrou.emit({"id": id, "tipo": "eu" if id == meu_id else "jogador", "skin": (p[o + 4] << 8) | p[o + 5],
			"nome": _ler_texto(p, o + 6, 10), "classe": p[o + 19] >> 3, "x": p[o + 2], "y": p[o + 3],
			"ax": p[o + 16], "ay": p[o + 17], "heroi": p[o + 18] & 0x0F, "equip": aparencia(p.slice(o + 19, o + 37)),
			"efeitos": Array(p.slice(o + 38, o + 38 + p[o + 37]))})
		o += 38 + p[o + 37]


# C2 20: itens no chao (S6: id, x, y e os 12 bytes do item; zen e o item 14/15 com o valor
# nos bytes 1..4, big endian: o OpenMU manda 00 00 00 1d pra 29 Zen)
# aparencia de 18 bytes do OpenMU (AppearanceSerializer, cliente S6): slot -> "grupo,numero"
const _ASAS := {4: {1: 0, 2: 1, 3: 2, 4: 41}, 8: {1: 3, 2: 4, 3: 5, 4: 6, 5: -30, 6: 42, 7: 49},
	12: {1: 36, 2: 37, 3: 38, 4: 39, 5: 40, 6: 43, 7: 50}}


static func aparencia(a: PackedByteArray) -> Dictionary:
	var e := {}
	if a.size() < 18:
		return e
	# armas: numero no byte 1 (mao direita) e 2 (esquerda), grupo nos 3 bits de cima do 12 e 13
	for i in 2:
		var g: int = a[12 + i] >> 5
		if a[1 + i] != 0xFF and g != 7:
			e[i] = "%d,%d" % [g, a[1 + i]]
	# armaduras: 4 bits + 1 bit no byte 9 + 4 bits (numero ate 511; tudo 1 = vazio)
	var partes := [[3, true, 0x80, 13, false], [3, false, 0x40, 14, true], [4, true, 0x20, 14, false],
		[4, false, 0x10, 15, true], [5, true, 0x08, 15, false]]
	for i in 5:
		var d: Array = partes[i]
		var baixo: int = (a[d[0]] >> 4) if d[1] else (a[d[0]] & 0x0F)
		var meio := 16 if a[9] & d[2] else 0
		var alto: int = (a[d[3]] >> 4) if d[4] else (a[d[3]] & 0x0F)
		var n: int = baixo + meio + alto * 32
		if n != 511:
			e[2 + i] = "%d,%d" % [7 + i, n]
	# asa: o tipo nos bits 2-3 do byte 5, qual nos 3 bits de baixo do 9 (as pequenas no 17)
	var tipo: int = a[5] & 0x0C
	var qual: int = a[9] & 0x07
	if _ASAS.has(tipo) and _ASAS[tipo].has(qual):
		var w: int = _ASAS[tipo][qual]
		e[7] = "13,30" if w == -30 else "12,%d" % w
	elif tipo == 12 and a[17] >> 5 > 0:
		e[7] = "12,%d" % (129 + (a[17] >> 5))
	# ajudante: 0 anjo, 1 imp, 2 unicornio; 3 = nenhum ou dinorant/cavalo/fenrir
	var pet: int = a[5] & 0x03
	if pet < 3:
		e[8] = "13,%d" % pet
	elif a[10] & 0x01:
		e[8] = "13,3"
	elif a[12] & 0x04:
		e[8] = "13,37"
		# cor do Fenrir: sem opcao vermelho; bit 0 do 16 preto, bit 1 azul, bit 0 do 17 dourado
		e["fenrir"] = "black" if a[16] & 0x01 else ("blue" if a[16] & 0x02 else ("gold" if a[17] & 0x01 else "red"))
	elif a[12] & 0x01:
		e[8] = "13,4"
	# nivel: 3 bits por slot (0 a 6) nos bytes 6-8, (nivel - 1) / 2; volta pro menor nivel da faixa
	var bits: int = (a[6] << 16) | (a[7] << 8) | a[8]
	var niveis := {}
	for i in 7:
		var g := (bits >> (i * 3)) & 7
		if g > 0 and e.has(i):
			niveis[i] = g * 2 + 1
	e["niveis"] = niveis
	return e


func _ler_itens(p: PackedByteArray) -> void:
	var lista := []
	var o := 5
	for i in p[4]:
		if o + 16 > p.size():
			break
		var it := item_de(p, o + 4)
		it.id = ((p[o] << 8) | p[o + 1]) & 0x7FFF
		it.novo = (p[o] & 0x80) != 0
		it.x = p[o + 2]
		it.y = p[o + 3]
		if it.grupo == 14 and (it.numero & 0xFF) == 15:
			it.zen = _ler_be(p, o + 5, 4)
		lista.append(it)
		o += 16
	itens_cairam.emit(lista)


# os 12 bytes de um item (GameServer/RemoteView/ItemSerializer.cs)
static func item_de(p: PackedByteArray, o: int) -> Dictionary:
	return {"numero": p[o] | ((p[o + 3] & 0x80) << 1), "grupo": p[o + 5] >> 4, "nivel": (p[o + 1] >> 3) & 0x0F,
		"sorte": (p[o + 1] & 0x04) != 0, "skill": (p[o + 1] & 0x80) != 0, "exc": p[o + 3] & 0x3F,
		"durabilidade": p[o + 2], "opcao": (p[o + 1] & 0x03) | ((p[o + 3] & 0x40) >> 4), "anc": p[o + 4],
		"bytes": p.slice(o, o + 12)}


static func _le(p: PackedByteArray, o: int) -> int:
	return p[o] | (p[o + 1] << 8)


static func _ler_be(p: PackedByteArray, o: int, n: int) -> int:
	var v := 0
	for i in n:
		v = (v << 8) | p[o + i]
	return v


# C2 13: npcs e monstros (Season 6: 10 bytes cada)
func _ler_npcs(p: PackedByteArray) -> void:
	for i in p[4]:
		var o := 5 + i * 10
		if o + 10 > p.size():
			break
		objeto_entrou.emit({"id": ((p[o] << 8) | p[o + 1]) & 0x7FFF, "tipo": "npc",
			"numero": ((p[o + 2] << 8) | p[o + 3]) & 0x0FFF,
			"x": p[o + 4], "y": p[o + 5], "ax": p[o + 6], "ay": p[o + 7]})


func _mandar_login() -> void:
	var longa := senha.to_utf8_buffer().size() > 10
	var p := PackedByteArray([0xC3, 0, 0xF1, 0x01])
	p.append_array(Cripto.xor3(_texto(usuario, 10)))
	p.append_array(Cripto.xor3(_texto(senha, 20 if longa else 10)))
	var t := Time.get_ticks_msec()
	p.append_array(PackedByteArray([(t >> 24) & 0xFF, (t >> 16) & 0xFF, (t >> 8) & 0xFF, t & 0xFF]))
	p.append_array(PackedByteArray(VERSAO))
	p.append_array(SERIAL.to_ascii_buffer())
	con.enviar(p)
	_mudar("login", usuario)


static func _texto(s: String, n: int) -> PackedByteArray:
	var b := s.to_utf8_buffer()
	b.resize(n)
	return b


static func _ler_texto(p: PackedByteArray, ini: int, n: int) -> String:
	var b := p.slice(ini, mini(ini + n, p.size()))
	var z := b.find(0)
	if z >= 0:
		b = b.slice(0, z)
	return b.get_string_from_utf8()


static func _ler_le(p: PackedByteArray, o: int) -> int:
	return p[o] | (p[o + 1] << 8) | (p[o + 2] << 16) | (p[o + 3] << 24)
