#include "stdafx.h"
#include "UI/Estudo/IconesNpc.h"
#include "UI/Estudo/QuestsMainWindow.h"
#include "Core/Utilities/StringUtils.h"
#include "World/MapInfra/MapManager.h"

#include <algorithm>
#include <cctype>
#include <utility>
#include <vector>

namespace
{
struct Regra
{
    std::vector<const char*> pedacos; // em minúsculo; o primeiro que bater vale
    const char* tipo;
};

// a mesma ordem do icones_npc.gd
const std::vector<Regra>& Regras()
{
    static const std::vector<Regra> regras = {
        {{"zoak"}, "quest"},
        {{"guardiao da dungeon"}, "evento"},
        {{"guild"}, "guilda"},
        {{"gens"}, "gens"},
        {{"vault", "safety guardian", "storage"}, "bau"},
        {{"chaos goblin", "chaos card", "osbourne", "lahap", "seed ", "jerridon", "elphis"}, "caos"},
        {{"potion", "barmaid", "supplier", "silvia"}, "pocao"},
        {{"weapons", "blacksmith", "craftsman", "zienna", "bolo", "rhea"}, "armas"},
        {{"mage", "wizard", "izabel", "marce", "lala", "priest", "sevina", "sebina", "devin", "oracle"}, "magia"},
        {{"elf soldier", "phantom soldier", "skill soldier", "leo the helper"}, "buff"},
        {{"charon", "archangel", "arch.", "gatekeeper", "titus", "mirage", "werewolf", "quarrel", "quarel", "lugard",
          "illusion", "jerint", "david", "gateway"},
         "evento"},
        {{"merchant", "goods", "moss", "thompson", "christine", "julia", "market", "jeweler", "delgado", "firecracker",
          "fireworks", "leina", "natasha", "alex"},
         "loja"},
        {{"guard"}, "guarda"},
    };
    return regras;
}

// números que são objeto do mapa e não gente: ficam como antes, sem ícone e com o nome só com o mouse em cima
constexpr std::pair<int, int> Objetos[] = {{152, 158}, {204, 222}, {451, 451}, {467, 477}};
} // namespace

std::string mu::ui::window::IconesNpc::Tipo(const std::wstring& name, int number)
{
    for (const auto& [de, ate] : Objetos)
        if (number >= de && number <= ate)
            return {};
    std::string n = StringUtils::WideToNarrow(name.c_str());
    std::transform(n.begin(), n.end(), n.begin(), [](unsigned char ch) { return static_cast<char>(std::tolower(ch)); });
    for (const Regra& r : Regras())
        for (const char* p : r.pedacos)
            if (n.find(p) != std::string::npos)
                return r.tipo;
    return "conversa";
}

std::string mu::ui::window::IconesNpc::Agora(const std::string& tipo)
{
    if (tipo != "quest")
        return tipo;
    const std::string marca = CQuestsMainWindow::MapMark(gMapManager.GetServerMap());
    return marca.empty() ? "conversa" : marca;
}

std::string mu::ui::window::IconesNpc::Source(const std::string& icone)
{
    return icone.empty() ? std::string() : "../modern/npc/" + icone + ".tga";
}
