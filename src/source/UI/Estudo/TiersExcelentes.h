#pragma once

// MuToDog (MU Estudo, rodada 18): tiers das linhas excelentes, as 2 linhas bônus do item excelente e o bônus de +13
// a +15, no jeito do cliente Godot (dica_item.gd) e do servidor (ExcellentTiers.cs, ExcellentBonus.cs,
// ItemLevelBonus.cs).
// - O tier de cada linha (1 Comum, 2 Incomum, 3 Raro, 4 Épico, 5 Lendário) vem no bloco do estudo do item
//   (ItemMng.h, EstudoBlockFlag); sem ele a linha vale Raro, como no servidor. O tier muda o valor da linha e a cor;
//   o nome do item fica na cor do melhor tier.
// - As 2 linhas bônus saem da semente que o servidor manda (a mesma conta dos 2 lados, como no Godot).

#include <string>

typedef struct tagITEM ITEM;

namespace mu::ui::window::TiersExcelentes
{
// O tier 1..5 da linha do bit `bit` (0..5) do byte excelente: o que o servidor mandou, ou Raro.
int TierLinha(const ITEM& item, int bit);
// O melhor tier entre as linhas excelentes do item; 0 se ele não tem linha excelente.
int MelhorTier(const ITEM& item);
// A cor da caixa do item pro tier (TEXT_COLOR_TIER1..5).
int Cor(int tier);
// O valor da linha excelente `attribute` (o nome do atributo no Excellent.json) no tier: troca `value`, ou
// `divisor` nas linhas por nível ("level/20"). False se o atributo não tem tier.
bool ValorDoTier(const ITEM& item, int bit, const std::string& attribute, int& value, int& divisor);
// Escreve na caixa do item (TextList) a partir de `row` as 2 linhas bônus do excelente e as do +13 a +15; devolve
// quantas linhas escreveu.
int EscreverLinhasBonus(const ITEM& item, int row, int rowLimit);
} // namespace mu::ui::window::TiersExcelentes
