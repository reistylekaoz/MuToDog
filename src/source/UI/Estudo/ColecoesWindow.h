#pragma once

// MuToDog (MU Estudo, rodada 8): Coleções, no jeito do cliente Godot (godot/scripts/janela_colecoes.gd) e pelo
// mesmo caminho do servidor (GameLogic/Colecoes.cs, BancoJoiasHandlerPlugIn): C1 FB 40 pede a lista e o servidor
// responde C2 FB 40 [n] + n x [colecao, mascara, pedido da peca 0..4]; C1 FB 41 [slot] entrega a peca da mochila e
// volta C1 FB 42 [ok, colecao, mascara] (mais a lista de novo). Set completo liga o bonus pra sempre no servidor.
// Os sets, os pedidos e os bonus vem de Data/Interface/RmlUi/dados/colecoes.json (o mesmo do servidor e do Godot).
// Abas Todos os itens e Sets, a caixinha + Adicionar item (a lista das pecas de set da mochila no lugar do arrastar)
// e o buff das colecoes na fila de buffs (CBuffStrip pergunta HasBonus e BonusTooltip).

#include "UI/Core/WindowManager.h"
#include "UI/RmlBridge/RmlThemedView.h"
#include "UI/RmlBridge/RmlTooltip.h"

#include <RmlUi/Core/Types.h>

#include <cstdint>
#include <string>
#include <vector>

namespace mu::ui::window
{
struct ColecoesPiece
{
    Rml::String name;
    Rml::String label;
    Rml::String decorator; // "image(it-<grupo>-<numero>)"
    Rml::String look;      // "dada", "mochila", "falta" ou "vazia"
    bool selected = false;
    int set = 0;
    int piece = 0;
    int index = 0;
};

struct ColecoesCard
{
    Rml::String name;
    Rml::String decorator;
    Rml::String count;
    bool open = false;
    bool done = false;
    int id = 0;
};

struct ColecoesBagRow
{
    Rml::String name;
    Rml::String info;
    Rml::String decorator;
    Rml::String look; // "ok", "falta" ou "ja", com " selected" na escolhida
    int slot = 0;
};

struct ColecoesRmlModel
{
    int tab = 0; // 0 todos os itens, 1 sets
    Rml::String partName;
    std::vector<ColecoesPiece> parts;
    std::vector<ColecoesPiece> cells;
    std::vector<ColecoesCard> cards;
    int setId = 1;
    Rml::String setName;
    std::vector<ColecoesPiece> slots;
    Rml::String setText;
    bool setDone = false;
    Rml::String setBonus;
    std::vector<Rml::String> active;
    Rml::String activeCount;
    bool addOpen = false;
    Rml::String addName;
    Rml::String addDecorator;
    Rml::String addMsg;
    Rml::String addLook;
    bool addCan = false;
    std::vector<ColecoesBagRow> bag;
};

class CColecoesWindow : public CObject
{
public:
    CColecoesWindow();
    ~CColecoesWindow() override;

    bool Create(CManager* pNewUIMng);
    void Release();

    bool UpdateMouseEvent() override;
    bool UpdateKeyEvent() override;
    bool Update() override;
    bool Render() override;

    float GetLayerDepth() override;
    float GetKeyEventOrder() override;

    void Show(bool bShow) override;

    // C2 FB 40 e C1 FB 42 (WSclient.cpp ProcessPacket).
    static void ReceivePacket(const std::uint8_t* packet, int size);
    // Algum set completo: o buff das colecoes aparece na fila de buffs.
    static bool HasBonus();
    // A dica do buff: os sets completos e a soma dos bonus.
    static std::vector<UI::RmlBridge::Tooltip::Line> BonusTooltip();

private:
    void BindRmlModel(Rml::DataModelConstructor& c, ColecoesRmlModel& model);
    void RunPending();
    void Rebuild();
    void BuildAll(ColecoesRmlModel& model);
    void BuildSets(ColecoesRmlModel& model);
    void BuildAdd(ColecoesRmlModel& model);
    void ClickPiece(int set, int piece);
    std::string BagSignature() const;
    static void SendList();
    static void SendGive(int slot);

    CManager* m_pNewUIMng = nullptr;
    int m_Part = 1;       // aba Todos os itens: 0 elmo ... 4 botas
    int m_AddSlot = -1;   // o slot da mochila na casa do Adicionar item
    bool m_Requested = false;
    // o que o clique pediu, feito no Update (fora do callback do RmlUi)
    int m_PendingAction = 0;
    int m_PendingA = 0;
    int m_PendingB = 0;
    bool m_Dirty = true;
    std::string m_BagKey;
    std::uint32_t m_SeenVersion = 0;

    UI::RmlBridge::ThemedView<ColecoesRmlModel> m_RmlView{"colecoes",
        [this](Rml::DataModelConstructor& c, ColecoesRmlModel& model) { BindRmlModel(c, model); },
        {{"Data/Interface/RmlUi/colecoes.rml"}}};
};
} // namespace mu::ui::window
