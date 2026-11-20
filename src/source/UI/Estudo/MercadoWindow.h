#pragma once

// MuToDog (MU Estudo, rodada 15): Mercado de jogador pra jogador, no jeito do cliente Godot (godot/scripts/
// janela_mercado.gd, o market da MuDream). O item entra no mercado por aqui: Vender item lista a mochila, escolhe a
// moeda (uma das 15 joias do baú ou TDC) e o preço; a compra é no site (Comprar no site abre o mercado com um passe de
// 2 min) e quem comprou retira aqui. Cancelar devolve pela mesma lista de retirar. O dinheiro da venda cai no baú de
// joias. Abre pelo F10 (Mercado).
// Servidor: GameLogic/MercadoJoias.cs e BancoJoiasHandlerPlugIn.cs. Pedidos C1 FB 10 [slot, moeda g, moeda n LE16,
// preço LE32] vende; C1 FB 11 [id LE32] cancela; C1 FB 12 pede a lista; C1 FB 13 [id LE32] retira; C1 FB 14 pede o
// passe do site. Respostas: C2 FB 10 [n ofertas, n entregas] + ofertas de 23 bytes [id LE32, moeda g, moeda n LE16,
// preço LE32, item 12] + entregas de 17 [id LE32, motivo (1 comprado, 2 devolvido), item 12]; C1 FB 14 [passe ASCII].
// O item vem sempre nos 12 bytes do S6 (o servidor grava assim desde a rodada 15, seja qual for o cliente).

#include "UI/Core/WindowManager.h"
#include "UI/RmlBridge/RmlThemedView.h"

#include <RmlUi/Core/Types.h>

#include <cstdint>
#include <string>
#include <vector>

namespace mu::ui::window
{
struct MercadoRow
{
    Rml::String name;
    Rml::String info;      // preço e moeda, ou "comprado" / "devolvido"
    Rml::String decorator; // "image(item-<grupo>-<numero>)" ou ""
    bool good = false;     // comprado (verde)
    int id = 0;
};

struct MercadoBagRow
{
    Rml::String name;
    Rml::String decorator;
    int slot = 0;
};

struct MercadoCoinRow
{
    Rml::String name;
    Rml::String decorator;
    int index = 0;
};

struct MercadoRmlModel
{
    int mode = 0; // 0 a lista, 1 escolher o item, 2 a moeda, 3 o preço
    bool loaded = false;
    Rml::String deliveriesTitle;
    Rml::String offersTitle;
    std::vector<MercadoRow> deliveries;
    std::vector<MercadoRow> offers;
    std::vector<MercadoBagRow> bag;
    std::vector<MercadoCoinRow> coins;
    Rml::String pickName;
    Rml::String pickDecorator;
    Rml::String coinName;
    Rml::String coinDecorator;
    Rml::String priceText;
    Rml::String note;
};

class CMercadoWindow : public CObject
{
public:
    CMercadoWindow();
    ~CMercadoWindow() override;

    bool Create(CManager* pNewUIMng);
    void Release();

    bool UpdateMouseEvent() override;
    bool UpdateKeyEvent() override;
    bool Update() override;
    bool Render() override;

    float GetLayerDepth() override;
    float GetKeyEventOrder() override;

    void Show(bool bShow) override;

    // C2 FB 10 e C1 FB 14 (WSclient.cpp ProcessPacket).
    static void ReceivePacket(const std::uint8_t* packet, int size);

private:
    void BindRmlModel(Rml::DataModelConstructor& c, MercadoRmlModel& model);
    void RunPending();
    void Rebuild();
    std::string BagSignature() const;

    CManager* m_pNewUIMng = nullptr;
    int m_Mode = 0;
    int m_PickSlot = -1;
    int m_Coin = -1;
    int m_PendingAction = 0;
    int m_PendingArg = 0;
    bool m_Dirty = true;
    std::uint32_t m_SeenVersion = 0;
    std::string m_BagKey;

    UI::RmlBridge::ThemedView<MercadoRmlModel> m_RmlView{"mercado",
        [this](Rml::DataModelConstructor& c, MercadoRmlModel& model) { BindRmlModel(c, model); },
        {{"Data/Interface/RmlUi/mercado.rml"}}};
};
} // namespace mu::ui::window
