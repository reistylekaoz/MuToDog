#pragma once

// MuToDog (MU Estudo, rodada 17): uso das 5 joias da casa na mochila (arrastar em cima de outro item).
// Mesmas regras dos plug-ins do servidor (Shimmer, Luck, Skill, Excellent e Corruption): o cliente libera o
// destaque verde na grade (DropActsOn) e manda o pedido de uso (SendRequestUse) pro servidor decidir a chance.

typedef struct tagITEM ITEM;

namespace mu::ui::window::JoiasCasa
{
// True pras 5 joias da casa (14,151 Shimmer, 14,152 Luck, 14,153 Skill, 14,156 Excellent, 14,157 Corruption).
bool EhJoia(int itemType);
// True se a joia da casa pode ser aplicada em cima do item alvo.
bool PodeAplicar(const ITEM* joia, const ITEM* alvo);
} // namespace mu::ui::window::JoiasCasa
