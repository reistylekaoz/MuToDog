# Rodadas até o cliente S6 completo

Medido em 22/10/2026 com `python3 ferramentas/medir.py`: 94 de 273 pacotes do servidor tratados,
23 de 46 cenários do cliente. Cada rodada termina no ar (navegador e launcher do PC) e testada
contra o OpenMU daqui. Marque `[x]` com a data e o commit ao fechar.

## Evolução do personagem
1. [x] 22/10/2026 · 64dd67e · Quests de troca de classe (sistema antigo, A0 a A4): Sevina, Marlon e Apóstolo Devin; janela da quest no NPC, aceitar, entregar, recompensa, contagem de monstros e troca de classe. Testado no OpenMU daqui: quest1Dk vira Blade Knight, quest1Elf vira Muse Elf (+10 pontos em cada quest). Sem teste: Marlon (fica fora de Devias) e a contagem de monstros (A4, quest 5 em Balgass, pede 400 e as quests 2 a 4 feitas).
2. [x] 22/10/2026 · e98b27f · Quests novas do S6 (F6): lista de quests na Elf Soldier, janela do passo (falas, respostas, pedidos e prêmios, OK), janela T (tecla T ou botão de quest da janela C) com as abas Quest, Change Class e Castle/Temple, desistir com confirmação. Testado no OpenMU daqui com test1Dk: Spider Hunt aceita, desistida, aceita de novo, 2 aranhas contadas pelo MU Helper e concluída (+2000 de exp; as 8 que faltavam entraram pelo banco local, o helper demorava). Sem teste: quest que não vem de NPC (botão abrir da janela T; o OpenMU não manda nenhuma) e a contagem do Blood Castle e do Illusion Temple (o OpenMU não responde o C1 9F: a aba diz que o servidor não informa).
3. [ ] Master level 1: nível master, pontos, barra de exp master, subida de nível master.
4. [ ] Master level 2: árvore de skills master (janela A), aprender e subir skill.

## Acabamento do que já existe
5. [ ] Efeitos e consumo: buff que acaba (MagicEffectCancelled), itens com efeito (selos, poções especiais), frutas, veneno, ShowEffect, fogos e fanfarra.
6. [ ] Grupo, baú e classes: sair do grupo, vida dos membros, senha do baú, ataques do Rage Fighter, vida das invocações, transformações (anéis), estado de herói, foco, upgrade de item no inventário.

## Social
7. [ ] Guilda 1: criar (com logo), convidar, entrar, sair, expulsar, lista, janela G, logo e nome sobre o personagem.
8. [ ] Guilda 2: aliança, hostilidade, guerra de guilda com placar, Battle Soccer.
9. [ ] Gens: entrar e sair (Duprian e Vanert), nome com a cor e o título, recompensa.
10. [ ] Cartas e chat: correio (escrever, ler, apagar), salas de chat e convite de amigo.
11. [ ] Pets do Dark Lord: Dark Raven e Dark Horse (comandos, ataque, informação).

## Eventos
12. [ ] Devil Square: mapa, entrada pelo Charon, placar no fim.
13. [ ] Blood Castle: mapa, entrada pelo Messenger, portão, estátua, placar.
14. [ ] Chaos Castle: mapa, entrada, placar.
15. [ ] Kalima, Santa Village e Arena de duelo: os três mapas e o que cada um tem.
16. [ ] Illusion Temple: mapa, entrada, skills do templo, relíquia, placar.
17. [ ] Doppelganger: os mapas, entrada, monstros do caminho, resultado.
18. [ ] Imperial Fortress: os mapas, entrada, tempo, resultado.
19. [ ] Kanturu: refúgio e chefe (Maya e Nightmare), estado do evento, entrada, tempo.
20. [ ] Raklion (Selupan), Balgass (quartel e refúgio) e o evento de Crywolf (estátua, altar, contrato, ranking).

## Castle Siege
21. [ ] Castle Siege 1: inscrição, marcas, lista de guildas, NPCs, impostos, portões fora da batalha.
22. [ ] Castle Siege 2: a batalha (coroa, interruptores, máquinas, lados, minimapa, tempo).

## Fim
23. [ ] Loja de cash (In-Game Shop): pontos, vitrine, comprar, presentear, depósito.
24. [ ] Tela de login do S6 (cenários de login) e o que sobrar no `medir.py`.
