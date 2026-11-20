#include "stdafx.h"
#include "UI/Estudo/TiersExcelentes.h"

#include "Data/GameData/ItemData/ItemDatabase.h"
#include "Engine/Object/ZzzInventory.h"
#include "GameLogic/Items/ItemOptions.h"

#include "json.hpp"

#include <algorithm>
#include <array>
#include <cstdarg>
#include <cstdint>
#include <cstdio>
#include <fstream>
#include <unordered_map>
#include <vector>

namespace mu::ui::window::TiersExcelentes
{
namespace
{
constexpr const char* BonusFile = "Data/Interface/RmlUi/dados/itens_bonus.json";
constexpr int Rare = 3;

int Key(int group, int number)
{
    return group * MAX_ITEM_INDEX + number;
}

// o valor de cada tier (Comum a Lendário) por atributo, o ExcellentTiers.Excellent do servidor
const std::unordered_map<std::string, std::array<int, 5>>& TierValues()
{
    static const std::unordered_map<std::string, std::array<int, 5>> values = {
        {"manaAfterMonsterKillMultiplier", {16, 12, 8, 6, 4}},
        {"healthAfterMonsterKillMultiplier", {16, 12, 8, 6, 4}},
        {"attackSpeedAny", {15, 20, 25, 30, 40}},
        {"physicalBaseDmgIncrease", {5, 6, 7, 8, 10}},
        {"wizardryBaseDmgIncrease", {5, 6, 7, 8, 10}},
        {"physicalBaseDmg", {40, 30, 20, 15, 10}},
        {"wizardryBaseDmg", {40, 30, 20, 15, 10}},
        {"excellentDamageChance", {5, 6, 7, 8, 10}},
        {"moneyAmountRate", {5, 10, 15, 20, 25}},
        {"defenseRatePvm", {1, 2, 3, 4, 5}},
        {"damageReflection", {1, 2, 3, 4, 5}},
        {"armorDamageDecrease", {1, 2, 3, 4, 5}},
        {"maximumMana", {1, 2, 3, 4, 5}},
        {"maximumHealth", {1, 2, 3, 4, 5}},
    };
    return values;
}

// --- as 2 linhas bônus (ExcellentBonus.cs; dica_item.gd, bonus_da_semente) ---
constexpr std::array<std::array<int, 2>, 5> BonusRange = {{{25, 50}, {50, 100}, {75, 150}, {125, 250}, {150, 300}}};
constexpr std::array<std::array<int, 2>, 5> BonusRangeAll = {{{5, 15}, {15, 30}, {25, 50}, {35, 75}, {50, 100}}};
constexpr std::array<int, 5> TierChances = {50, 28, 15, 6, 1};
constexpr std::array<const wchar_t*, 6> BonusStatus = {L"Strength", L"Agility", L"Vitality", L"Energy", L"Command",
                                                       L"All Stats"};
constexpr int StatusCommand = 4;
constexpr int StatusAll = 5;

std::uint32_t HashBonus(std::uint32_t seed, std::uint32_t i)
{
    std::uint32_t x = seed * 0x9E3779B1u + i * 0x85EBCA77u;
    x ^= x >> 15;
    x *= 0x2C1B3C6Du;
    x ^= x >> 12;
    x *= 0x297A2D39u;
    x ^= x >> 15;
    return x;
}

struct BonusLine
{
    int status = 0;
    int tier = 0;
    int value = 0;
};

std::vector<BonusLine> BonusFromSeed(std::uint32_t seed, bool doubled, bool darkLord)
{
    std::vector<int> status = {0, 1, 2, 3};
    if (darkLord)
        status.push_back(StatusCommand);
    status.push_back(StatusAll);
    std::vector<BonusLine> lines;
    for (std::uint32_t k = 0; k < 2; ++k)
    {
        BonusLine line;
        const auto pick = status.begin() + HashBonus(seed, k) % status.size();
        line.status = *pick;
        status.erase(pick);
        int x = static_cast<int>(HashBonus(seed, 2 + k) % 100);
        line.tier = static_cast<int>(TierChances.size());
        for (size_t i = 0; i < TierChances.size(); ++i)
        {
            x -= TierChances[i];
            if (x < 0)
            {
                line.tier = static_cast<int>(i) + 1;
                break;
            }
        }
        const auto& range = (line.status == StatusAll ? BonusRangeAll : BonusRange)[line.tier - 1];
        const int m = doubled ? 2 : 1;
        const int low = range[0] * m;
        const int high = range[1] * m;
        line.value = low + static_cast<int>(HashBonus(seed, 4 + k) % static_cast<std::uint32_t>(high - low + 1));
        lines.push_back(line);
    }
    return lines;
}

// item -> [x1 ou x2, Dark Lord equipa] (dados/itens_bonus.json, o mesmo do Godot)
const std::unordered_map<int, std::array<int, 2>>& BonusItems()
{
    static std::unordered_map<int, std::array<int, 2>> table;
    static bool loaded = false;
    if (loaded)
        return table;
    loaded = true;
    std::ifstream file(BonusFile);
    if (!file)
        return table;
    const nlohmann::json j = nlohmann::json::parse(file, nullptr, false);
    if (j.is_discarded() || !j.is_object())
        return table;
    for (const auto& [k, v] : j.items())
    {
        const size_t comma = k.find(',');
        if (comma == std::string::npos || !v.is_array() || v.size() < 2)
            continue;
        table[Key(std::stoi(k.substr(0, comma)), std::stoi(k.substr(comma + 1)))] = {v[0].get<int>(), v[1].get<int>()};
    }
    return table;
}

// --- bônus de +13, +14 e +15 (ItemLevelBonus.cs; dica_item.gd, BONUS_NIVEL) ---
using LevelLines = std::array<const wchar_t*, 3>;

const LevelLines* LevelBonusOf(int type)
{
    static const LevelLines gloves = {L"Max HP +600", L"Defense +500", L"Reflect damage +3%"};
    static const LevelLines boots = {L"Defense +300", L"All stats +200", L"Damage +4%"};
    static const LevelLines pants = {L"Excellent damage rate +4%", L"Double damage rate +1%",
                                     L"Ignore defense rate +1%"};
    static const LevelLines armor = {L"Attack speed +40", L"Critical damage rate +5%", L"Damage reduction +2%"};
    static const LevelLines helm = {L"Max HP +600", L"Defense +500", L"Max SD +8%"};
    static const LevelLines shield = {L"Critical damage resistance +10%", L"Excellent damage resistance +10%",
                                      L"Return damage rate +2%"};
    static const LevelLines weapon = {L"Excellent damage rate +5%", L"Ignore defense rate +3%", L"Damage +8%"};
    static const LevelLines earring = {L"Defense +300", L"Excellent damage rate +3%", L"Damage reduction +3%"};
    static const LevelLines ring = {L"Max HP +300", L"Defense +300", L"Damage reduction +2%"};
    static const LevelLines pendant = {L"Excellent damage rate +2%", L"Ignore defense rate +1%",
                                       L"Double damage rate +1%"};
    static const LevelLines wings = {L"Max HP +500", L"Damage +4%", L"PvP damage +500"};

    // a mesma ordem do KindOf do servidor: brinco, asa, anel, pendente, depois o grupo
    if (type == Key(12, 449) || type == Key(12, 457))
        return &earring;
    switch (g_ItemDatabase.GetSlot(type))
    {
    case Data::Items::ItemSlot::Wings: return &wings;
    case Data::Items::ItemSlot::Ring: return &ring;
    case Data::Items::ItemSlot::Pendant: return &pendant;
    default: break;
    }
    switch (type / MAX_ITEM_INDEX)
    {
    case 0: case 1: case 2: case 3: case 4: case 5: return &weapon;
    case 6: return &shield;
    case 7: return &helm;
    case 8: return &armor;
    case 9: return &pants;
    case 10: return &gloves;
    case 11: return &boots;
    default: return nullptr;
    }
}

bool WriteRow(int& row, int rowLimit, int color, const wchar_t* format, ...)
{
    if (row >= rowLimit || row >= MaxTextListRows)
        return false;
    va_list args;
    va_start(args, format);
    std::vswprintf(TextList[row], std::size(TextList[row]), format, args);
    va_end(args);
    TextListColor[row] = color;
    TextBold[row] = false;
    ++row;
    return true;
}
} // namespace

int TierLinha(const ITEM& item, int bit)
{
    if (bit < 0 || bit >= 6)
        return Rare;
    const int tier = item.ExcTier[bit];
    return tier >= 1 && tier <= 5 ? tier : Rare;
}

int MelhorTier(const ITEM& item)
{
    // asa: o byte excelente são as opções de asa, não linhas com tier aqui
    if (g_ItemDatabase.GetSlot(item.Type) == Data::Items::ItemSlot::Wings ||
        !GameLogic::Items::HasExcellentOptions(item))
        return 0;
    int best = 0;
    for (int i = 0; i < 6; ++i)
        if (item.ExcellentFlags & (1 << i))
            best = std::max(best, TierLinha(item, i));
    return best;
}

int Cor(int tier)
{
    return TEXT_COLOR_TIER1 + std::clamp(tier, 1, 5) - 1;
}

bool ValorDoTier(const ITEM& item, int bit, const std::string& attribute, int& value, int& divisor)
{
    const auto& values = TierValues();
    const auto it = values.find(attribute);
    if (it == values.end())
        return false;
    const int v = it->second[TierLinha(item, bit) - 1];
    if (divisor > 0)
        divisor = v;
    else
        value = v;
    return true;
}

int EscreverLinhasBonus(const ITEM& item, int row, int rowLimit)
{
    const int first = row;
    if (item.ExcBonus > 0 && item.ExcellentFlags != 0)
    {
        const auto& table = BonusItems();
        if (const auto it = table.find(item.Type); it != table.end())
        {
            WriteRow(row, rowLimit, TEXT_COLOR_GREEN, L"Excellent Bonus Options");
            for (const BonusLine& line : BonusFromSeed(item.ExcBonus - 1u, it->second[0] == 2, it->second[1] == 1))
                WriteRow(row, rowLimit, Cor(line.tier), L"Increases %ls +%d", BonusStatus[line.status], line.value);
        }
    }
    if (item.Level >= 13)
    {
        if (const LevelLines* lines = LevelBonusOf(item.Type))
        {
            for (int level = 13; level <= std::min(item.Level, 15); ++level)
                WriteRow(row, rowLimit, TEXT_COLOR_RED, L"+%d %ls", level, (*lines)[level - 13]);
        }
    }
    return row - first;
}
} // namespace mu::ui::window::TiersExcelentes
