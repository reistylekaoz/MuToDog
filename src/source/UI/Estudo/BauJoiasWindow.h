#pragma once

// MuToDog (MU Estudo, rodada 16): Baú de joias, no jeito do cliente Godot (godot/scripts/janela_bau_joias.gd). O saldo
// é da conta (o mesmo da loja do site): uma linha por joia com a quantidade e Retirar (sai em pilhas de até 255), a TDC
// só pra ver. Guardar é Ctrl + botão direito na joia da mochila (InventoryActionController.cpp), a pilha inteira entra.
// Separar tira parte de uma pilha da mochila; Agrupar junta as pilhas soltas. Abre pelo F10 (Baú de joias).
// Servidor: GameLogic/BancoJoias.cs e BancoJoiasHandlerPlugIn.cs. Pedidos C1 FB 00 pede o saldo; C1 FB 01 [slot]
// guarda; C1 FB 02 [grupo, numero LE16, qtd LE32] retira; C1 FB 03 [slot, qtd] separa; C1 FB 04 agrupa. Depois de
// 00, 01 e 02 vem C1 FB 00 [n] + n x [grupo, numero LE16, qtd LE32] (a última linha é a TDC, 255,255).

#include "UI/Core/WindowManager.h"
#include "UI/RmlBridge/RmlThemedView.h"

#include <RmlUi/Core/Types.h>

#include <cstdint>
#include <string>
#include <vector>

namespace mu::ui::window
{
struct BauJoiasRow
{
    Rml::String name;
    Rml::String qty;
    Rml::String decorator;
    bool can = false; // tem e não é a TDC: mostra o Retirar
    bool tdc = false;
    int index = 0;
};

struct BauJoiasBagRow
{
    Rml::String name;
    Rml::String qty;
    Rml::String decorator;
    int slot = 0;
};

struct BauJoiasRmlModel
{
    int mode = 0; // 0 o saldo, 1 quantas retirar, 2 escolher a pilha, 3 quantas separar
    std::vector<BauJoiasRow> rows;
    std::vector<BauJoiasBagRow> bag;
    Rml::String pickName;
    Rml::String pickDecorator;
    Rml::String qtyText;
    Rml::String help;
    Rml::String note;
};

class CBauJoiasWindow : public CObject
{
public:
    CBauJoiasWindow();
    ~CBauJoiasWindow() override;

    bool Create(CManager* pNewUIMng);
    void Release();

    bool UpdateMouseEvent() override;
    bool UpdateKeyEvent() override;
    bool Update() override;
    bool Render() override;

    float GetLayerDepth() override;
    float GetKeyEventOrder() override;

    void Show(bool bShow) override;

    // C1 FB 00 (WSclient.cpp ProcessPacket).
    static void ReceivePacket(const std::uint8_t* packet, int size);

    // Uma das 15 joias que o baú guarda (Type = grupo * MAX_ITEM_INDEX + numero).
    static bool IsBankJewel(int type);
    // Ctrl + botão direito na joia da mochila: manda a pilha pro baú e abre a janela.
    static void Deposit(int slot);

private:
    void BindRmlModel(Rml::DataModelConstructor& c, BauJoiasRmlModel& model);
    void RunPending();
    void Rebuild();
    std::string BagSignature() const;

    CManager* m_pNewUIMng = nullptr;
    int m_Mode = 0;
    int m_Pick = -1; // a joia (mode 1) ou a casa da mochila (mode 3)
    int m_PendingAction = 0;
    int m_PendingArg = 0;
    bool m_Dirty = true;
    std::uint32_t m_SeenVersion = 0;
    std::string m_BagKey;

    UI::RmlBridge::ThemedView<BauJoiasRmlModel> m_RmlView{"bau_joias",
        [this](Rml::DataModelConstructor& c, BauJoiasRmlModel& model) { BindRmlModel(c, model); },
        {{"Data/Interface/RmlUi/bau_joias.rml"}}};
};
} // namespace mu::ui::window
