#pragma once

// MuToDog (MU Estudo, rodada 13): Missões (tecla T), no jeito do cliente Godot (godot/scripts/janela_quests_main.gd, o
// "Quest System" da MuDream). Duas caras:
// - lista (T): as missões ativas por mapa na esquerda; na direita a história, o objetivo, o progresso (monstro x/total)
//   e o prêmio (experiência, zen e pontos), com Abandonar (pede confirmação) e Fechar;
// - Zoak (falou com o NPC 905): a missão da vez daquele mapa, com Aceitar ou Entregar (ou o aviso de que acabou).
// As quests vêm de Data/Interface/RmlUi/dados/quests_main.json (o mesmo do Godot, ferramentas/quests_main.py); o estado
// vem do servidor (GameLogic/QuestsMain.cs): C1 FB 30 pede; C2 FB 30 [n] + n x [cadeia, ativa, feitas, mortes LE32];
// C1 FB 31 [cadeia] abriu o Zoak; C1 FB 32 [cadeia, ativa, mortes LE32] morte contada. Pedidos: C1 FB 31/32/33 [cadeia]
// aceita, entrega e abandona (o servidor responde com o estado de novo). O "My Quest" do S6 segue no botão da janela C.

#include "UI/Core/WindowManager.h"
#include "UI/RmlBridge/RmlThemedView.h"

#include <RmlUi/Core/Types.h>

#include <cstdint>
#include <string>
#include <vector>

namespace mu::ui::window
{
struct QuestMainQuest
{
    std::string name;
    std::string monster;
    int amount = 0;
    long long exp = 0;
    long long zen = 0;
    int points = 0;
    std::string story;
};

struct QuestMainChain
{
    int id = 0;
    std::string name;
    std::vector<int> maps;
    std::vector<QuestMainQuest> quests;
};

struct QuestMainState
{
    int active = 0; // a quest em andamento (1..n), 0 = nenhuma
    int done = 0;   // quantas já entregou
    int kills = 0;  // mortes da ativa
};

struct QuestsMainRow
{
    Rml::String text;
    int chain = 0;
    bool header = false;
    bool selected = false;
    bool ready = false;
};

struct QuestsMainRmlModel
{
    Rml::String title;
    bool zoak = false;
    std::vector<QuestsMainRow> rows;
    bool empty = false;
    Rml::String summary;
    Rml::String heading; // Zoak: "Missões de Lorencia: 1 de 7 feitas"
    bool hasDetail = false;
    bool allDone = false;
    Rml::String doneTitle;
    Rml::String doneText;
    Rml::String name;
    Rml::String story;
    Rml::String objective;
    Rml::String monster;
    Rml::String progress;
    Rml::String bar; // "45%"
    Rml::String exp;
    Rml::String zen;
    Rml::String points;
    Rml::String hint; // Zoak: "Faltam 12 Spider. Volte aqui quando terminar."
    bool canAccept = false;
    bool canDeliver = false;
    bool canAbandon = false;
    bool confirm = false;
};

class CQuestsMainWindow : public CObject
{
public:
    CQuestsMainWindow();
    ~CQuestsMainWindow() override;

    bool Create(CManager* pNewUIMng);
    void Release();

    bool UpdateMouseEvent() override;
    bool UpdateKeyEvent() override;
    bool Update() override;
    bool Render() override;

    float GetLayerDepth() override;
    float GetKeyEventOrder() override;

    void Show(bool bShow) override;

    // C2 FB 30, C1 FB 31 e C1 FB 32 (WSclient.cpp ProcessPacket).
    static void ReceivePacket(const std::uint8_t* packet, int size);

    // pro rastreio do canto (RastreioMissoesWindow): as cadeias com missão ativa, a quest e o estado
    static const std::vector<QuestMainChain>& Chains();
    static std::vector<int> ActiveChains();
    static const QuestMainChain* FindChain(int id);
    static const QuestMainQuest* FindQuest(int id, int n);
    static QuestMainState StateOf(int id);
    static std::uint32_t Version();
    // T e o clique no rastreio: abre na lista
    static void OpenList();
    static std::string Thousands(long long value);

private:
    void BindRmlModel(Rml::DataModelConstructor& c, QuestsMainRmlModel& model);
    void RunPending();
    void Rebuild();
    void FillDetail(QuestsMainRmlModel& model, int id, int n, int kills, bool withProgress);
    static void SendState();
    static void SendAction(int command, int chain);

    CManager* m_pNewUIMng = nullptr;
    int m_PendingAction = 0;
    int m_PendingChain = 0;
    int m_Selected = 0;
    bool m_Confirm = false;
    bool m_Dirty = true;
    bool m_InGame = false;
    std::uint32_t m_SeenVersion = 0;

    UI::RmlBridge::ThemedView<QuestsMainRmlModel> m_RmlView{"missoes",
        [this](Rml::DataModelConstructor& c, QuestsMainRmlModel& model) { BindRmlModel(c, model); },
        {{"Data/Interface/RmlUi/missoes.rml"}}};
};
} // namespace mu::ui::window
