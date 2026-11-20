#include "stdafx.h"
#include "UI/Estudo/QuestsMainWindow.h"
#include "UI/Core/WindowSystem.h"
#include "UI/Core/WindowCommon.h"
#include "Audio/DSPlaySound.h"
#include "Engine/Object/ZzzCharacter.h"
#include "Engine/Object/ZzzInfomation.h"
#include "Network/Server/WSclient.h"
#include "Scenes/SceneCore.h"
#include "UI/RmlBridge/RmlDocumentVisibility.h"

#include "json.hpp"

#include <RmlUi/Core/DataModelHandle.h>
#include <RmlUi/Core/ElementDocument.h>
#include <RmlUi/Core/Event.h>

#include <algorithm>
#include <fstream>
#include <map>

using namespace mu::ui::window;

namespace
{
constexpr const char* DataFile = "Data/Interface/RmlUi/dados/quests_main.json";
constexpr std::uint8_t PacketCode = 0xFB;
constexpr std::uint8_t CommandState = 0x30;  // C1 pede; C2 o estado
constexpr std::uint8_t CommandAccept = 0x31; // C1 [cadeia] aceita; servidor: C1 [cadeia] abriu o Zoak
constexpr std::uint8_t CommandDeliver = 0x32; // C1 [cadeia] entrega; servidor: C1 [cadeia, ativa, mortes] morte contada
constexpr std::uint8_t CommandAbandon = 0x33;

constexpr int ActionNone = 0;
constexpr int ActionPick = 1;
constexpr int ActionAccept = 2;
constexpr int ActionDeliver = 3;
constexpr int ActionAbandon = 4;
constexpr int ActionClose = 5;

std::vector<QuestMainChain> g_Chains;
bool g_Loaded = false;
std::map<int, QuestMainState> g_State;
bool g_Received = false;
std::uint32_t g_Version = 1;
bool g_ZoakMode = false;
int g_Zoak = 0;          // cadeia do Zoak aberto
int g_OpenRequest = 0;   // 1 = abrir na lista, 2 = abrir no Zoak (vem do pacote ou do rastreio)

void QmLoad()
{
    if (g_Loaded)
        return;
    g_Loaded = true;
    std::ifstream file(DataFile);
    if (!file)
        return;
    const nlohmann::json j = nlohmann::json::parse(file, nullptr, false);
    if (j.is_discarded() || !j.is_array())
        return;
    for (const auto& c : j)
    {
        QuestMainChain chain;
        chain.id = c.value("id", 0);
        chain.name = c.value("nome", std::string());
        if (c.contains("mapas") && c["mapas"].is_array())
            for (const auto& m : c["mapas"])
                chain.maps.push_back(m.get<int>());
        if (c.contains("quests") && c["quests"].is_array())
        {
            for (const auto& q : c["quests"])
            {
                QuestMainQuest quest;
                quest.name = q.value("nome", std::string());
                quest.monster = q.value("monstro", std::string());
                quest.amount = q.value("quantidade", 0);
                quest.exp = q.value("exp", 0LL);
                quest.zen = q.value("zen", 0LL);
                quest.points = q.value("pontos", 0);
                quest.story = q.value("historia", std::string());
                chain.quests.push_back(std::move(quest));
            }
        }
        if (chain.id > 0)
            g_Chains.push_back(std::move(chain));
    }
}

void QmSendRaw(BYTE* packet, int size)
{
    if (SocketClient != nullptr)
        SocketClient->Send(packet, static_cast<int32_t>(size));
}

std::uint32_t QmLe32(const std::uint8_t* p)
{
    return p[0] | (p[1] << 8) | (p[2] << 16) | (static_cast<std::uint32_t>(p[3]) << 24);
}
} // namespace

CQuestsMainWindow::CQuestsMainWindow() = default;

CQuestsMainWindow::~CQuestsMainWindow()
{
    Release();
}

bool CQuestsMainWindow::Create(CManager* pNewUIMng)
{
    if (pNewUIMng == nullptr)
        return false;
    m_pNewUIMng = pNewUIMng;
    m_pNewUIMng->AddUIObj(INTERFACE_QUESTS_MAIN, this);
    QmLoad();
    m_RmlView.Ensure();
    Show(false);
    return true;
}

void CQuestsMainWindow::Release()
{
    if (m_pNewUIMng)
    {
        m_pNewUIMng->RemoveUIObj(this);
        m_pNewUIMng = nullptr;
    }
    m_RmlView.Release();
}

void CQuestsMainWindow::Show(bool bShow)
{
    CObject::Show(bShow);
    m_Confirm = false;
    if (!bShow)
        g_ZoakMode = false; // fechou: a T e o F10 abrem na lista, só o Zoak abre no Zoak
    if (bShow)
    {
        SendState();
        m_Dirty = true;
    }
}

const std::vector<QuestMainChain>& CQuestsMainWindow::Chains()
{
    QmLoad();
    return g_Chains;
}

const QuestMainChain* CQuestsMainWindow::FindChain(int id)
{
    for (const auto& c : Chains())
        if (c.id == id)
            return &c;
    return nullptr;
}

const QuestMainQuest* CQuestsMainWindow::FindQuest(int id, int n)
{
    const QuestMainChain* c = FindChain(id);
    if (c == nullptr || n < 1 || n > static_cast<int>(c->quests.size()))
        return nullptr;
    return &c->quests[static_cast<size_t>(n - 1)];
}

QuestMainState CQuestsMainWindow::StateOf(int id)
{
    const auto it = g_State.find(id);
    return it != g_State.end() ? it->second : QuestMainState{};
}

std::vector<int> CQuestsMainWindow::ActiveChains()
{
    std::vector<int> list;
    for (const auto& c : Chains())
    {
        const QuestMainState s = StateOf(c.id);
        if (s.active > 0 && s.active <= static_cast<int>(c.quests.size()))
            list.push_back(c.id);
    }
    return list;
}

std::string CQuestsMainWindow::MapMark(int map)
{
    if (!g_Received)
        return {};
    for (const auto& c : Chains())
    {
        if (std::find(c.maps.begin(), c.maps.end(), map) == c.maps.end())
            continue;
        const QuestMainState s = StateOf(c.id);
        if (s.active > 0)
        {
            const QuestMainQuest* q = FindQuest(c.id, s.active);
            return q != nullptr && s.kills >= q->amount ? "quest_pronta" : "quest_andando";
        }
        return s.done < static_cast<int>(c.quests.size()) ? "quest_nova" : "";
    }
    return {};
}

std::uint32_t CQuestsMainWindow::Version()
{
    return g_Version;
}

void CQuestsMainWindow::OpenList()
{
    g_OpenRequest = 1;
}

std::string CQuestsMainWindow::Thousands(long long value)
{
    std::string digits = std::to_string(value < 0 ? -value : value);
    for (int i = static_cast<int>(digits.size()) - 3; i > 0; i -= 3)
        digits.insert(static_cast<size_t>(i), ".");
    return value < 0 ? "-" + digits : digits;
}

void CQuestsMainWindow::ReceivePacket(const std::uint8_t* packet, int size)
{
    if (packet == nullptr || size < 4)
        return;
    if (packet[0] == 0xC2 && size >= 6 && packet[3] == PacketCode && packet[4] == CommandState)
    {
        g_State.clear();
        int o = 6;
        for (int i = 0; i < packet[5] && o + 7 <= size; ++i, o += 7)
            g_State[packet[o]] = QuestMainState{packet[o + 1], packet[o + 2], static_cast<int>(QmLe32(packet + o + 3))};
        g_Received = true;
        ++g_Version;
    }
    else if (packet[0] == 0xC1 && size >= 5 && packet[2] == PacketCode && packet[3] == CommandAccept)
    {
        g_Zoak = packet[4];
        g_OpenRequest = 2;
        ++g_Version;
    }
    else if (packet[0] == 0xC1 && size >= 10 && packet[2] == PacketCode && packet[3] == CommandDeliver)
    {
        QuestMainState& s = g_State[packet[4]];
        if (s.active != packet[5])
            s.done = std::max(0, packet[5] - 1);
        s.active = packet[5];
        s.kills = static_cast<int>(QmLe32(packet + 6));
        ++g_Version;
    }
}

void CQuestsMainWindow::SendState()
{
    BYTE packet[] = {0xC1, 4, PacketCode, CommandState};
    QmSendRaw(packet, static_cast<int>(sizeof(packet)));
}

void CQuestsMainWindow::SendAction(int command, int chain)
{
    BYTE packet[] = {0xC1, 5, PacketCode, static_cast<BYTE>(command), static_cast<BYTE>(chain)};
    QmSendRaw(packet, static_cast<int>(sizeof(packet)));
}

bool CQuestsMainWindow::UpdateMouseEvent()
{
    // Aberta, segura o mouse (tudo e do RmlUi).
    return false;
}

bool CQuestsMainWindow::UpdateKeyEvent()
{
    if (IsVisible() && IsPress(VK_ESCAPE))
    {
        if (m_Confirm)
        {
            m_Confirm = false;
            m_Dirty = true;
        }
        else
            g_pNewUISystem->Hide(INTERFACE_QUESTS_MAIN);
        PlayBuffer(SOUND_CLICK01);
        return false;
    }
    return true;
}

bool CQuestsMainWindow::Update()
{
    const bool inGame = SceneFlag == MAIN_SCENE && Hero != nullptr;
    if (inGame && !m_InGame)
        SendState(); // o rastreio precisa do estado logo ao entrar
    if (!inGame && m_InGame)
    {
        // escolha de personagem: o proximo pede de novo, sem o estado do anterior
        g_State.clear();
        g_Received = false;
        g_OpenRequest = 0;
        ++g_Version;
        g_pNewUISystem->Hide(INTERFACE_QUESTS_MAIN);
    }
    m_InGame = inGame;

    if (inGame && g_OpenRequest != 0)
    {
        g_ZoakMode = g_OpenRequest == 2;
        g_OpenRequest = 0;
        m_Confirm = false;
        if (!IsVisible())
            g_pNewUISystem->Show(INTERFACE_QUESTS_MAIN);
        m_Dirty = true;
    }

    RunPending();
    m_RmlView.Ensure();
    Rml::ElementDocument* document = m_RmlView.Document();
    if (document == nullptr)
        return true;
    UI::RmlBridge::SyncDocumentVisibilityInFront(document, IsVisible() && inGame);
    if (!IsVisible() || !inGame)
        return true;

    if (m_SeenVersion != g_Version)
    {
        m_SeenVersion = g_Version;
        m_Dirty = true;
    }
    if (m_Dirty)
        Rebuild();
    return true;
}

bool CQuestsMainWindow::Render()
{
    return true;
}

void CQuestsMainWindow::RunPending()
{
    const int action = m_PendingAction;
    m_PendingAction = ActionNone;
    if (action == ActionNone)
        return;
    switch (action)
    {
    case ActionPick:
        m_Selected = m_PendingChain;
        m_Confirm = false;
        break;
    case ActionAccept:
        SendAction(CommandAccept, g_Zoak);
        break;
    case ActionDeliver:
        SendAction(CommandDeliver, g_Zoak);
        break;
    case ActionAbandon:
        if (m_Selected > 0 && m_Confirm)
        {
            SendAction(CommandAbandon, m_Selected);
            m_Confirm = false;
        }
        else if (m_Selected > 0)
            m_Confirm = true;
        break;
    case ActionClose:
        g_pNewUISystem->Hide(INTERFACE_QUESTS_MAIN);
        break;
    default:
        break;
    }
    PlayBuffer(SOUND_CLICK01);
    m_Dirty = true;
}

void CQuestsMainWindow::BindRmlModel(Rml::DataModelConstructor& c, QuestsMainRmlModel& model)
{
    auto row = c.RegisterStruct<QuestsMainRow>();
    row.RegisterMember("text", &QuestsMainRow::text);
    row.RegisterMember("chain", &QuestsMainRow::chain);
    row.RegisterMember("header", &QuestsMainRow::header);
    row.RegisterMember("selected", &QuestsMainRow::selected);
    row.RegisterMember("ready", &QuestsMainRow::ready);
    c.RegisterArray<std::vector<QuestsMainRow>>();

    c.Bind("title", &model.title);
    c.Bind("zoak", &model.zoak);
    c.Bind("rows", &model.rows);
    c.Bind("empty", &model.empty);
    c.Bind("summary", &model.summary);
    c.Bind("heading", &model.heading);
    c.Bind("has_detail", &model.hasDetail);
    c.Bind("all_done", &model.allDone);
    c.Bind("done_title", &model.doneTitle);
    c.Bind("done_text", &model.doneText);
    c.Bind("name", &model.name);
    c.Bind("story", &model.story);
    c.Bind("objective", &model.objective);
    c.Bind("monster", &model.monster);
    c.Bind("progress", &model.progress);
    c.Bind("bar", &model.bar);
    c.Bind("exp", &model.exp);
    c.Bind("zen", &model.zen);
    c.Bind("points", &model.points);
    c.Bind("hint", &model.hint);
    c.Bind("can_accept", &model.canAccept);
    c.Bind("can_deliver", &model.canDeliver);
    c.Bind("can_abandon", &model.canAbandon);
    c.Bind("confirm", &model.confirm);

    auto one = [this](int action)
    {
        return [this, action](Rml::DataModelHandle, Rml::Event&, const Rml::VariantList& arguments)
        {
            m_PendingAction = action;
            m_PendingChain = arguments.size() >= 1 ? arguments[0].Get<int>(0) : 0;
        };
    };
    c.BindEventCallback("qm_pick", one(ActionPick));
    c.BindEventCallback("qm_accept", one(ActionAccept));
    c.BindEventCallback("qm_deliver", one(ActionDeliver));
    c.BindEventCallback("qm_abandon", one(ActionAbandon));
    c.BindEventCallback("qm_close", one(ActionClose));
    m_Dirty = true;
}

// a ficha da missao: nome, historia, objetivo, progresso e premio
void CQuestsMainWindow::FillDetail(QuestsMainRmlModel& model, int id, int n, int kills, bool withProgress)
{
    const QuestMainQuest* q = FindQuest(id, n);
    model.hasDetail = q != nullptr;
    if (q == nullptr)
        return;
    const int shown = withProgress ? kills : 0;
    model.name = q->name;
    model.story = q->story;
    model.objective = "Objetivo: derrote " + Thousands(q->amount) + " " + q->monster + " (em qualquer mapa).";
    model.monster = q->monster;
    model.progress = Thousands(shown) + " / " + Thousands(q->amount);
    const int percent = q->amount > 0 ? std::clamp(shown * 100 / q->amount, 0, 100) : 0;
    model.bar = std::to_string(percent) + "%";
    model.exp = "Experiência: " + Thousands(q->exp);
    model.zen = "Zen: " + Thousands(q->zen);
    model.points = "Pontos de atributo: " + std::to_string(q->points);
}

void CQuestsMainWindow::Rebuild()
{
    m_Dirty = false;
    QuestsMainRmlModel& model = m_RmlView.GetModel();
    model.rows.clear();
    model.hasDetail = model.allDone = model.canAccept = model.canDeliver = model.canAbandon = false;
    model.empty = false;
    model.hint.clear();
    model.heading.clear();
    model.summary.clear();
    model.zoak = g_ZoakMode;
    model.confirm = m_Confirm;

    if (g_ZoakMode)
    {
        model.title = "Zoak";
        const QuestMainChain* c = FindChain(g_Zoak);
        if (c == nullptr)
        {
            model.allDone = true;
            model.doneTitle = "Não tenho missões neste mapa.";
            model.doneText = "Procure o Zoak de outro mapa.";
        }
        else
        {
            const QuestMainState s = StateOf(g_Zoak);
            const int total = static_cast<int>(c->quests.size());
            model.heading = "Missões de " + c->name + ": " + std::to_string(std::min(s.done, total)) + " de " +
                            std::to_string(total) + " feitas";
            if (s.active == 0 && s.done >= total)
            {
                model.allDone = true;
                model.doneTitle = "Você completou todas as missões de " + c->name + ".";
                model.doneText = "Não há mais missão principal neste mapa. Procure o Zoak de outro mapa.";
            }
            else if (s.active > 0)
            {
                FillDetail(model, g_Zoak, s.active, s.kills, true);
                const QuestMainQuest* q = FindQuest(g_Zoak, s.active);
                if (q != nullptr && s.kills >= q->amount)
                    model.canDeliver = true;
                else if (q != nullptr)
                    model.hint = "Faltam " + Thousands(q->amount - s.kills) + " " + q->monster + ". Volte aqui quando terminar.";
            }
            else
            {
                FillDetail(model, g_Zoak, s.done + 1, 0, false);
                model.canAccept = true;
            }
        }
    }
    else
    {
        model.title = "Missões (T)";
        const std::vector<int> active = ActiveChains();
        if (std::find(active.begin(), active.end(), m_Selected) == active.end())
            m_Selected = active.empty() ? 0 : active.front();
        for (int id : active)
        {
            const QuestMainChain* c = FindChain(id);
            const QuestMainState s = StateOf(id);
            const QuestMainQuest* q = FindQuest(id, s.active);
            model.rows.push_back(QuestsMainRow{c->name, id, true, false, false});
            model.rows.push_back(QuestsMainRow{"[Main] " + q->name, id, false, id == m_Selected, s.kills >= q->amount});
        }
        model.empty = active.empty();
        int done = 0;
        int total = 0;
        for (const auto& c : Chains())
        {
            total += static_cast<int>(c.quests.size());
            done += std::min(StateOf(c.id).done, static_cast<int>(c.quests.size()));
        }
        model.summary = !g_Received ? std::string("Carregando...")
                                    : "Ativas: " + std::to_string(active.size()) + "   Feitas: " + std::to_string(done) +
                                          " de " + std::to_string(total);
        if (m_Selected > 0)
        {
            const QuestMainState s = StateOf(m_Selected);
            FillDetail(model, m_Selected, s.active, s.kills, true);
            model.canAbandon = true;
        }
    }

    for (const char* field : {"title", "zoak", "rows", "empty", "summary", "heading", "has_detail", "all_done", "done_title",
                              "done_text", "name", "story", "objective", "monster", "progress", "bar", "exp", "zen", "points",
                              "hint", "can_accept", "can_deliver", "can_abandon", "confirm"})
        m_RmlView.MarkDirty(field);
}

float CQuestsMainWindow::GetLayerDepth()
{
    return 10.62f;
}

float CQuestsMainWindow::GetKeyEventOrder()
{
    return 10.f;
}
