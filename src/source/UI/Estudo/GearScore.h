#pragma once

// MuToDog (MU Estudo, rodada 12): gear score, no jeito do cliente Godot (dica_item.gd, gear_score; janela_buffs.gd, GS)
// e do servidor (GameLogic/GearScore.cs). Cada item vestido soma o seu Grade Score; o total dá um bônus fixo no
// servidor com o coeficiente c = 0,10: defesa e dano +GS x c / 10 %, dano excelente +GS x c x 15, vida +GS x c x 40.
// - O total vem do servidor: C1 0B FB 70 [id BE16] [degrau] [GS LE16] [0 0] (AuraForca.cs), mandado quando o
//   personagem entra na visão (ele mesmo incluso) e quando troca equipamento. Antes do primeiro, a conta daqui.
// - A caixa do item mostra Base Score e Grade Score (tabela dados/gear_score_base.json, a mesma do Godot, tirada do
//   banco do servidor por ferramentas/gear_score_tabela.py). O protocolo do MuMain (ItemSerializerExtended) não traz
//   o tier de cada linha excelente: aqui cada linha vale Raro, como o Godot faz quando o tier não veio.
// - O ícone do GS fica na frente da fila de buffs (CBuffStrip pergunta Total e BonusTooltip).

#include "UI/RmlBridge/RmlTooltip.h"

#include <cstdint>
#include <vector>

typedef struct tagITEM ITEM;

namespace mu::ui::window
{
class CGearScore
{
public:
    struct ItemScore
    {
        int base = 0;
        int grade = 0;
    };

    // Base e Grade Score do item; false se não é equipamento (joia, poção, pet).
    static bool Of(const ITEM& item, ItemScore& out);
    // O gear score do personagem: o do servidor, ou a soma do que está vestido enquanto ele não chegou.
    static int Total();
    // A caixa do ícone do GS: total e o que ele dá.
    static std::vector<UI::RmlBridge::Tooltip::Line> BonusTooltip();
    // C1 FB 70 (o GS de quem está na visão: só o meu interessa aqui).
    static void ReceivePacket(const std::uint8_t* packet, int size);
};
} // namespace mu::ui::window
