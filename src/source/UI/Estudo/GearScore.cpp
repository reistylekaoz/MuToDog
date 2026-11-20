#include "stdafx.h"
#include "UI/Estudo/GearScore.h"

#include "Engine/Object/ZzzInfomation.h"
#include "Network/Server/WSclient.h"

#include "json.hpp"

#include <algorithm>
#include <array>
#include <cstdio>
#include <fstream>
#include <string>
#include <unordered_map>

namespace mu::ui::window
{
namespace
{
constexpr const char* DataFile = "Data/Interface/RmlUi/dados/gear_score_base.json";
constexpr std::uint8_t PacketCode = 0xFB;
constexpr std::uint8_t CommandAura = 0x70;

// os números do GearScore.cs (e do dica_item.gd)
constexpr std::array<int, 16> LevelScore = {0, 3, 6, 9, 12, 15, 18, 21, 24, 27, 35, 43, 52, 65, 80, 100};
constexpr std::array<int, 6> TierScore = {0, 6, 12, 20, 30, 45};
constexpr int TierSemTier = 3; // Raro: o tier não vem no protocolo do MuMain
constexpr int LuckScore = 15;
constexpr int SkillScore = 10;
constexpr int OptionScore = 5;
constexpr int AncientScore = 25;

int Key(int group, int number)
{
    return group * MAX_ITEM_INDEX + number;
}

const std::unordered_map<int, int>& BaseTable()
{
    static std::unordered_map<int, int> table;
    static bool loaded = false;
    if (loaded)
        return table;
    loaded = true;
    std::ifstream file(DataFile);
    if (!file)
        return table;
    const nlohmann::json j = nlohmann::json::parse(file, nullptr, false);
    if (j.is_discarded() || !j.is_object())
        return table;
    for (const auto& [k, v] : j.items())
    {
        const size_t comma = k.find(',');
        if (comma == std::string::npos || !v.is_number())
            continue;
        table[Key(std::stoi(k.substr(0, comma)), std::stoi(k.substr(comma + 1)))] = v.get<int>();
    }
    return table;
}

// geração da asa (GearScore.Wings1/2/3): 0 = não é asa
int WingGeneration(int type)
{
    static const std::array<int, 4> wings1 = {Key(12, 0), Key(12, 1), Key(12, 2), Key(12, 41)};
    static const std::array<int, 7> wings2 = {Key(12, 3), Key(12, 4), Key(12, 5), Key(12, 6), Key(12, 42), Key(12, 49), Key(13, 30)};
    static const std::array<int, 7> wings3 = {Key(12, 36), Key(12, 37), Key(12, 38), Key(12, 39), Key(12, 40), Key(12, 43), Key(12, 50)};
    if (std::find(wings1.begin(), wings1.end(), type) != wings1.end())
        return 1;
    if (std::find(wings2.begin(), wings2.end(), type) != wings2.end())
        return 2;
    if (std::find(wings3.begin(), wings3.end(), type) != wings3.end())
        return 3;
    return 0;
}

int g_ServerTotal = -1;
int g_ServerKey = -1;

// 1760 -> "17,60"
std::string Percent(int total)
{
    char text[32];
    std::snprintf(text, sizeof(text), "%d,%02d", total / 100, total % 100);
    return text;
}
} // namespace

bool CGearScore::Of(const ITEM& item, ItemScore& out)
{
    if (item.Type < 0)
        return false;
    const auto& table = BaseTable();
    const auto it = table.find(item.Type);
    if (it == table.end())
        return false;
    out.base = it->second;
    int score = out.base + LevelScore[std::clamp(item.Level, 0, 15)];
    const int generation = WingGeneration(item.Type);
    if (generation != 1)
    {
        // na asa só as 4 primeiras linhas (os bits de cima eram o número da opção alternativa)
        const int bits = item.ExcellentFlags & (generation > 0 ? 0x0F : 0x3F);
        for (int i = 0; i < 6; ++i)
            if (bits & (1 << i))
                score += TierScore[TierSemTier];
    }
    if (item.HasLuck)
        score += LuckScore;
    if (item.HasSkill)
        score += SkillScore;
    score += OptionScore * std::clamp(static_cast<int>(item.OptionLevel), 0, 7);
    if (item.AncientDiscriminator > 0)
        score += AncientScore;
    out.grade = score;
    return true;
}

int CGearScore::Total()
{
    if (g_ServerTotal >= 0 && g_ServerKey == HeroKey)
        return g_ServerTotal;
    if (CharacterMachine == nullptr)
        return 0;
    int total = 0;
    for (const ITEM& item : CharacterMachine->Equipment)
    {
        ItemScore s;
        if (item.Durability > 0 && Of(item, s))
            total += s.grade;
    }
    return total;
}

std::vector<UI::RmlBridge::Tooltip::Line> CGearScore::BonusTooltip()
{
    using UI::RmlBridge::Tooltip::Line;
    using UI::RmlBridge::Tooltip::LineColor;
    const int total = Total();
    std::vector<Line> lines;
    lines.push_back({"Bônus do Gear Score", LineColor::Orange, true});
    lines.push_back({"", LineColor::White, false, Line::Kind::HalfSpacer});
    lines.push_back({"Gear Score: " + std::to_string(total), LineColor::Yellow});
    // GS x 0,10 / 10 % = GS / 100 %; dano excelente GS x 0,10 x 15 = GS x 1,5; vida GS x 0,10 x 40 = GS x 4
    lines.push_back({"Defesa: +" + Percent(total) + "%", LineColor::Green});
    lines.push_back({"Dano: +" + Percent(total) + "%", LineColor::Green});
    lines.push_back({"Dano excelente: +" + std::to_string(total * 15 / 10), LineColor::Green});
    lines.push_back({"Vida máxima: +" + std::to_string(total * 4), LineColor::Green});
    lines.push_back({"Coeficiente: 0,10", LineColor::Yellow});
    return lines;
}

void CGearScore::ReceivePacket(const std::uint8_t* packet, int size)
{
    if (packet == nullptr || size < 9 || packet[0] != 0xC1 || packet[2] != PacketCode || packet[3] != CommandAura)
        return;
    const int id = ((packet[4] << 8) | packet[5]) & 0x7FFF;
    if (id != (HeroKey & 0x7FFF))
        return;
    g_ServerTotal = packet[7] | (packet[8] << 8);
    g_ServerKey = HeroKey;
}
} // namespace mu::ui::window
