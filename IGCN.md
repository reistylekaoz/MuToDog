# IGCN x6 (S6E3) como referência do que falta no OpenMU

Pacote gratuito da IGCN (2017), baixado do MEGA do tópico do DarksTeam em 27/10/2026.
Fica em `igcn/` (fora do git). Só os dados foram extraídos (`igcn/dados`, 437 arquivos:
xml, lua, ini, txt, sql, dat, att, bmd) por `ferramentas/rar/dados.mjs`. Nenhum .exe ou .dll
foi gravado nem roda: os GameServers chamam um IP de fora (158.69.204.41) e o
EssentialTools vem empacotado (Themida). Uso: só leitura, pra entender como o IGCN faz.

## Onde mora cada coisa

- `Files/IGCData/IGC_BuffEffectManager.xml`: número do buff (o mesmo do BuffEffect do
  cliente e do nosso `dados/buffs.json`), qual item liga ele (ItemType, ItemIndex).
- `Files/IGCData/Items/IGC_ItemOptionManager.xml`: o que cada item faz (até 2 opções com
  valor) e a duração em segundos. Itens da mesma Section não somam (o novo troca o velho).
  Time="0": a duração vem da loja de cash. Time="-10": vale enquanto o item está na mochila
  (amuleto, figurinha).
- `Files/IGCData/CashShop/512.2014.124/IGC_CashItem_*.xml`: loja de cash. Duration em minutos
  (1440 = 1 dia, 10080 = 7, 43200 = 30).
- `Files/<GameServer>/IGC_VipSettings.xml` e `IGC_Common.ini`: VIP. Banco: tabela
  `T_VIPList (AccountID, Date, Type)` e o procedimento `IGC_VipAdd` em
  `Database/1. Scripts/MuOnline/MuOnline.sql`.

## Selos e scrolls (item, buff, efeito, duração)

Opções do ItemOptionManager: 1 velocidade de ataque, 2 dano, 3 defesa, 4 HP máx, 5 mana máx,
6 XP +%, 7 drop +%, 8 sem XP, 9 a 13 força, agilidade, vitalidade, energia, comando,
14 ataque, 15 magia, 16 warp do M livre, 53 recupera HP %, 54 recupera mana %, 55 dano
crítico %, 56 dano excelente %, 60 XP % (só normal), 62 morrer sem perder, 63 item não gasta,
64 zen %, 68 XP do grupo %, 87 XP % (normal e master).

```
item     buff  nome                          efeito                        tempo
13,43    29    Seal of Ascension             XP +50%                       loja
13,44    30    Seal of Wealth                XP +100%, drop +50%           loja
13,45    31    Seal of Sustenance            sem XP                        loja
13,59    43    Seal of Mobility              warp do M livre               loja
13,62    87    Seal of Healing               XP +50%, HP 5%                30 min
13,63    88    Seal of Divinity              drop +50%, mana 5%            30 min
13,93    101   Master Seal of Ascension      XP +50%                       30 min
13,94    102   Master Seal of Wealth         XP +100%, drop +50%           30 min
13,96    104   Seal of Strength              dano +50, defesa +60          30 min
13,103   112   Party EXP Scroll              XP do grupo, valor 10 (buff: até 170%) 30 min
14,72    44    Scroll of Quickness           velocidade +15                loja
14,73    45    Scroll of Defense             defesa +60                    loja
14,74    46    Scroll of Wrath               ataque +30                    loja
14,75    47    Scroll of Wizardry            magia +30                     loja
14,76    48    Scroll of Health              HP +200                       loja
14,77    49    Scroll of Mana                mana +300                     loja
14,97    89    Scroll of Battle              crítico +20%                  30 min
14,98    90    Scroll of Strength            excelente +20%                30 min
14,140   121   Scroll of Healing             HP 3%, HP +100                30 min
14,78-82 50-54 Elixires                      +50 no status                 10 dias
13,81    99    Talisman of Guardian          morrer sem perder             30 min
13,82    100   Talisman of Item Protection   item não gasta                30 min
```

Na loja: Seal of Ascension e Wealth em 1, 3, 7 e 30 dias; scrolls em 1 e 7 dias.
Leitura dos valores: no XP (opção 6) o valor soma (50 = +50%, o texto original diz "150%", a
taxa final); no drop (opção 7) o valor já é a taxa final (150 = 1,5 vezes = +50%), igual ao
texto do Seal of Divinity. Os textos que o jogador vê foram trocados pra mostrar sempre o
que soma ("EXP +50%", "Item drop +50%"): ferramentas/dados_buff.py, TEXTOS.

## VIP

- 4 tipos de exemplo: Bronze, Silver, Gold, Platinum (Type 1 a 4), cada um com taxa de dia
  e de noite (noite das 22h às 7h30): ExpBonus, DropBonus, ExcDropBonus e os mesmos pra
  master, somados à taxa do servidor. Também: preço de compra e venda nas lojas, nível
  mínimo do monstro pra XP master, pontos por reset.
- O VIP vale por conta, até uma data (T_VIPList). Entra pelo Gold Channel Ticket (13,124)
  da loja: nível 1 a 4 define o tipo e soma dias; nível 0 só soma dias.
- O servidor pode ser "Gold" (só VIP entra, LevelType) e o ServerList.bmd do cliente marca
  o servidor como Gold (código 2 ou 3).
- Outras portas pelo VIP: Mu Bot (NeedVIPLevel no IGC_Common.ini).

## O que o OpenMU S6 daqui já tem e o que falta

- Tem: Stats.ExperienceRate e BonusExperienceRate (por personagem), Stats.IsVip (só libera
  comando de chat), loja de cash com os nomes (CashShopInitializer.cs), buff com tempo
  (MagicEffect com duração), números dos efeitos dos scrolls (MagicEffectNumber.cs).
- Falta: as ItemDefinition dos selos e scrolls (13,43 etc. não existem no banco), o "usar
  item liga buff com tempo" pra eles, a soma de drop, os buffs que duram dias e sobrevivem
  ao sair do jogo, o VIP com taxa e data, e o Gold Channel Ticket.
