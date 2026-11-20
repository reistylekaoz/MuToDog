#pragma once

// MuToDog (MU Estudo, rodada 14): o ícone de cada NPC, no jeito do cliente Godot (godot/scripts/icones_npc.gd, pedido do
// Murilo em 12/11, como na MuDream): em cima da cabeça, com o nome sempre à mostra (NomesNpcWindow), e no minimapa
// (MiniMap). O tipo sai do nome (vale pro nome do Monsters.json e pro do Minimap_WorldN.bmd); quem dá missão (Zoak)
// mostra o estado da missão do mapa: "!" pra pegar, V apagado em andamento, V aceso pra entregar.
// Os desenhos: themes/modern/npc/<tipo>.ozt (tools/obsidiana_theme/icones_npc.py traz do Godot).

#include <string>

namespace mu::ui::window::IconesNpc
{
// "" pra objeto do mapa (portão de Kalima, altares do Crywolf, coroa e alavancas do castelo, árvore e bonecos de
// evento); senão o tipo (quest, loja, pocao, ..., guarda, conversa). number = -1 quando não se sabe (marca do bmd).
std::string Tipo(const std::wstring& name, int number = -1);
// o ícone que vale agora: o Zoak troca pela marca da missão do mapa atual (CQuestsMainWindow::MapMark)
std::string Agora(const std::string& tipo);
// o caminho do desenho a partir de um documento em themes/<tema>/ ("" sem ícone)
std::string Source(const std::string& icone);
} // namespace mu::ui::window::IconesNpc
