#include "stdafx.h"
#include "UI/Estudo/JoiasCasa.h"

#include "Core/Globals/_enum.h"
#include "Core/Globals/_struct.h"
#include "Data/GameData/ItemData/ItemDatabase.h"
#include "Data/GameData/ItemData/ItemType.h"
#include "Engine/Object/ZzzInfomation.h"
#include "GameLogic/Items/ItemCategories.h"
#include "GameLogic/Items/ItemOptions.h"

#include <algorithm>
#include <array>
#include <bit>

namespace mu::ui::window::JoiasCasa
{
namespace
{
using Data::Items::ItemOptionType;
using Data::Items::ItemSlot;
using Data::Items::MakeItemType;

constexpr int kGroupWeaponMax = 5;
constexpr int kShimmerMaxLevel = 15;
constexpr int kExcellentMaxLines = 4;
constexpr unsigned int kExcellentOptionMask = 0x3Fu;

constexpr int kJewelOfShimmer = MakeItemType(14, 151);
constexpr int kJewelOfLuck = MakeItemType(14, 152);
constexpr int kJewelOfSkill = MakeItemType(14, 153);
constexpr int kJewelOfExcellent = MakeItemType(14, 156);
constexpr int kJewelOfCorruption = MakeItemType(14, 157);

// Brincos do servidor (rodada 18: 12,449 esquerdo e 12,457 direito).
constexpr std::array<int, 2> kEarrings = {MakeItemType(12, 449), MakeItemType(12, 457)};

// Aneis de transformacao e joias cujo nivel escolhe variante (ShimmerJewelConsumeHandlerPlugIn.ExcludedItems).
constexpr std::array<int, 10> kShimmerExcluded = {
    MakeItemType(13, 10), MakeItemType(13, 20), MakeItemType(13, 38), MakeItemType(13, 39),  MakeItemType(13, 40),
    MakeItemType(13, 41), MakeItemType(13, 42), MakeItemType(13, 68), MakeItemType(13, 76), MakeItemType(13, 122),
};

bool EhJoiaParaShimmer(const ITEM& alvo)
{
    if (alvo.Level >= kShimmerMaxLevel)
    {
        return false;
    }
    if (std::ranges::find(kShimmerExcluded, alvo.Type) != kShimmerExcluded.end())
    {
        return false;
    }
    if (std::ranges::find(kEarrings, alvo.Type) != kEarrings.end())
    {
        return true;
    }
    const ItemSlot slot = g_ItemDatabase.GetSlot(alvo.Type);
    return slot == ItemSlot::Pendant || slot == ItemSlot::Ring;
}

bool PodeReceberSkill(const ITEM& alvo)
{
    if (alvo.HasSkill || Data::Items::GetItemGroup(alvo.Type) > kGroupWeaponMax)
    {
        return false;
    }
    if (GameLogic::Items::IsAmmunition(&alvo) || ItemAttribute == nullptr)
    {
        return false;
    }
    return ItemAttribute[alvo.Type].m_wSkillIndex != 0;
}

int ContarOpcoesExcelentes(BYTE excellentFlags)
{
    return std::popcount(static_cast<unsigned int>(excellentFlags) & kExcellentOptionMask);
}
} // namespace

bool EhJoia(int itemType)
{
    return itemType == kJewelOfShimmer || itemType == kJewelOfLuck || itemType == kJewelOfSkill ||
           itemType == kJewelOfExcellent || itemType == kJewelOfCorruption;
}

bool PodeAplicar(const ITEM* joia, const ITEM* alvo)
{
    if (joia == nullptr || alvo == nullptr)
    {
        return false;
    }
    if (!Data::Items::IsValidItemType(alvo->Type) || GameLogic::Items::IsLuckyItemType(alvo->Type))
    {
        return false;
    }

    switch (joia->Type)
    {
    case kJewelOfShimmer:
        return EhJoiaParaShimmer(*alvo);
    case kJewelOfLuck:
        return !alvo->HasLuck && GameLogic::Items::LinksOptionType(alvo->Type, ItemOptionType::Luck);
    case kJewelOfSkill:
        return PodeReceberSkill(*alvo);
    case kJewelOfExcellent:
        return GameLogic::Items::HasExcellentOptions(*alvo) &&
               ContarOpcoesExcelentes(alvo->ExcellentFlags) < kExcellentMaxLines;
    case kJewelOfCorruption:
        return GameLogic::Items::HasExcellentOptions(*alvo);
    default:
        return false;
    }
}
} // namespace mu::ui::window::JoiasCasa
