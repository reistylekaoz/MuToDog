#include "stdafx.h"
#include "UI/Estudo/EventosWindow.h"
#include "UI/Core/WindowSystem.h"
#include "UI/Core/WindowCommon.h"
#include "Audio/DSPlaySound.h"
#include "Engine/Object/ZzzCharacter.h"
#include "Engine/Object/ZzzInfomation.h"
#include "Network/Server/WSclient.h"
#include "Scenes/SceneCore.h"
#include "UI/RmlBridge/RmlDocumentVisibility.h"

#include <RmlUi/Core/DataModelHandle.h>
#include <RmlUi/Core/ElementDocument.h>
#include <RmlUi/Core/Event.h>

#include <algorithm>
#include <cstdio>
#include <iterator>

using namespace mu::ui::window;

namespace
{
constexpr std::uint8_t PacketCode = 0xFB;
constexpr std::uint8_t CommandList = 0x20;

constexpr int ActionNone = 0;
constexpr int ActionPrev = 1;
constexpr int ActionNext = 2;
constexpr int ActionClose = 3;

constexpr int PerPage = 4;
constexpr int Brasilia = -3 * 3600;
constexpr std::time_t AskAgainSeconds = 60; // o servidor guarda a lista 60 s

struct EventInfo
{
    const char* name;
    const char* art;
    const char* about;
};

// tipo -> nome, arte (themes/modern/eventos, ev-<arte>) e o que é; a mesma ordem do AgendaEventos.cs
constexpr EventInfo kEvents[] = {
    {"Blood Castle", "bc", "Leve a arma ao Arcanjo."},
    {"Devil Square", "ds", "Ondas de monstros na arena."},
    {"Chaos Castle", "cc", "Todos contra todos."},
    {"Happy Hour", "hh", "Experiência x1,5 no mundo."},
    {"Invasão Dourada", "dourado", "Dourados com caixas."},
    {"Dragão Vermelho", "dragao", "Dragões atacam as cidades."},
    {"Mago Branco", "mago", "O Mago invade uma cidade."},
    {"Torre de Kanturu", "kanturu", "Maya e Nightmare na Torre."},
    {"Invasão dos Goblins", "goblins", "Goblins do baú no Deep Dungeon."},
};

struct Event
{
    int type = 0;
    int duration = 0; // minutos
    int levelMin = 0;
    int levelMax = 0;
    std::vector<int> starts; // minutos do dia, UTC
};

std::vector<Event> g_Events;
bool g_Received = false;
std::uint32_t g_Version = 1;

struct Situation
{
    bool open = false;
    long long left = 0; // segundos pra fechar (aberto) ou pra abrir
    long long next = 0; // o próximo início (unix, UTC)
};

// aberto agora? quanto falta e o próximo início (situacao() do Godot)
Situation EvSituation(const Event& e, long long now)
{
    const long long day = now - now % 86400;
    const long long sec = now % 86400;
    for (int h : e.starts)
    {
        const long long start = h * 60LL;
        if (sec >= start && sec < start + e.duration * 60LL)
            return {true, start + e.duration * 60LL - sec, day + start};
    }
    long long next = -1;
    for (int h : e.starts)
    {
        if (h * 60LL > sec)
        {
            next = day + h * 60LL;
            break;
        }
    }
    if (next < 0 && !e.starts.empty())
        next = day + 86400 + e.starts.front() * 60LL;
    return {false, std::max(0LL, next - now), next};
}

std::string EvClock(long long s)
{
    char text[32];
    std::snprintf(text, sizeof(text), "%02lld : %02lld : %02lld", s / 3600, (s / 60) % 60, s % 60);
    return text;
}

// a hora do dia de um instante unix, em Brasília
std::string EvTimeOfDay(long long unix, bool seconds)
{
    long long s = (unix + Brasilia) % 86400;
    if (s < 0)
        s += 86400;
    char text[16];
    if (seconds)
        std::snprintf(text, sizeof(text), "%02lld:%02lld:%02lld", s / 3600, (s / 60) % 60, s % 60);
    else
        std::snprintf(text, sizeof(text), "%02lld:%02lld", s / 3600, (s / 60) % 60);
    return text;
}

int EvPages()
{
    return std::max(1, static_cast<int>((g_Events.size() + PerPage - 1) / PerPage));
}
} // namespace

CEventosWindow::CEventosWindow() = default;

CEventosWindow::~CEventosWindow()
{
    Release();
}

bool CEventosWindow::Create(CManager* pNewUIMng)
{
    if (pNewUIMng == nullptr)
        return false;
    m_pNewUIMng = pNewUIMng;
    m_pNewUIMng->AddUIObj(INTERFACE_EVENTOS, this);
    m_RmlView.Ensure();
    Show(false);
    return true;
}

void CEventosWindow::Release()
{
    if (m_pNewUIMng)
    {
        m_pNewUIMng->RemoveUIObj(this);
        m_pNewUIMng = nullptr;
    }
    m_RmlView.Release();
}

void CEventosWindow::Show(bool bShow)
{
    CObject::Show(bShow);
    if (bShow)
    {
        const std::time_t now = std::time(nullptr);
        if (!g_Received || now - m_AskedAt >= AskAgainSeconds)
        {
            m_AskedAt = now;
            SendRequest();
        }
        m_Dirty = true;
    }
}

void CEventosWindow::ReceivePacket(const std::uint8_t* packet, int size)
{
    if (packet == nullptr || size < 6 || packet[0] != 0xC2 || packet[3] != PacketCode || packet[4] != CommandList)
        return;
    std::vector<Event> list;
    int o = 6;
    for (int i = 0; i < packet[5] && o + 8 <= size; ++i)
    {
        Event e;
        e.type = packet[o];
        e.duration = packet[o + 1] | (packet[o + 2] << 8);
        e.levelMin = packet[o + 3] | (packet[o + 4] << 8);
        e.levelMax = packet[o + 5] | (packet[o + 6] << 8);
        const int hours = packet[o + 7];
        o += 8;
        for (int h = 0; h < hours && o + 2 <= size; ++h, o += 2)
            e.starts.push_back(packet[o] | (packet[o + 1] << 8));
        std::sort(e.starts.begin(), e.starts.end());
        list.push_back(std::move(e));
    }
    g_Events = std::move(list);
    g_Received = true;
    ++g_Version;
}

void CEventosWindow::SendRequest()
{
    BYTE packet[] = {0xC1, 4, PacketCode, CommandList};
    if (SocketClient != nullptr)
        SocketClient->Send(packet, static_cast<int32_t>(sizeof(packet)));
}

bool CEventosWindow::UpdateMouseEvent()
{
    // Aberta, segura o mouse (tudo e do RmlUi).
    return false;
}

bool CEventosWindow::UpdateKeyEvent()
{
    if (IsVisible() && IsPress(VK_ESCAPE))
    {
        g_pNewUISystem->Hide(INTERFACE_EVENTOS);
        PlayBuffer(SOUND_CLICK01);
        return false;
    }
    return true;
}

bool CEventosWindow::Update()
{
    const bool inGame = SceneFlag == MAIN_SCENE && Hero != nullptr;
    if (!inGame && m_InGame)
        g_pNewUISystem->Hide(INTERFACE_EVENTOS);
    m_InGame = inGame;

    RunPending();
    m_RmlView.Ensure();
    Rml::ElementDocument* document = m_RmlView.Document();
    if (document == nullptr)
        return true;
    UI::RmlBridge::SyncDocumentVisibilityInFront(document, IsVisible() && inGame);
    if (!IsVisible() || !inGame)
        return true;

    // a contagem anda de segundo em segundo
    const std::time_t now = std::time(nullptr);
    if (now != m_SeenSecond || m_SeenVersion != g_Version)
    {
        m_SeenSecond = now;
        m_SeenVersion = g_Version;
        m_Dirty = true;
    }
    if (m_Dirty)
        Rebuild();
    return true;
}

bool CEventosWindow::Render()
{
    return true;
}

void CEventosWindow::RunPending()
{
    const int action = m_PendingAction;
    m_PendingAction = ActionNone;
    if (action == ActionNone)
        return;
    switch (action)
    {
    case ActionPrev:
        m_Page = std::max(0, m_Page - 1);
        break;
    case ActionNext:
        m_Page = std::min(EvPages() - 1, m_Page + 1);
        break;
    case ActionClose:
        g_pNewUISystem->Hide(INTERFACE_EVENTOS);
        break;
    default:
        break;
    }
    PlayBuffer(SOUND_CLICK01);
    m_Dirty = true;
}

void CEventosWindow::BindRmlModel(Rml::DataModelConstructor& c, EventosRmlModel& model)
{
    auto card = c.RegisterStruct<EventosCard>();
    card.RegisterMember("name", &EventosCard::name);
    card.RegisterMember("art", &EventosCard::art);
    card.RegisterMember("about", &EventosCard::about);
    card.RegisterMember("count", &EventosCard::count);
    card.RegisterMember("next", &EventosCard::next);
    card.RegisterMember("level", &EventosCard::level);
    card.RegisterMember("open", &EventosCard::open);
    card.RegisterMember("enter", &EventosCard::enter);
    c.RegisterArray<std::vector<EventosCard>>();

    c.Bind("clock", &model.clock);
    c.Bind("status", &model.status);
    c.Bind("cards", &model.cards);
    c.Bind("page", &model.page);
    c.Bind("can_prev", &model.canPrev);
    c.Bind("can_next", &model.canNext);

    auto one = [this](int action)
    {
        return [this, action](Rml::DataModelHandle, Rml::Event&, const Rml::VariantList&) { m_PendingAction = action; };
    };
    c.BindEventCallback("ev_prev", one(ActionPrev));
    c.BindEventCallback("ev_next", one(ActionNext));
    c.BindEventCallback("ev_close", one(ActionClose));
    m_Dirty = true;
}

void CEventosWindow::Rebuild()
{
    m_Dirty = false;
    EventosRmlModel& model = m_RmlView.GetModel();
    const long long now = static_cast<long long>(std::time(nullptr));
    const int level = CharacterAttribute != nullptr ? static_cast<int>(CharacterAttribute->Level) : 1;

    m_Page = std::clamp(m_Page, 0, EvPages() - 1);
    model.clock = "Hora de Brasília: " + EvTimeOfDay(now, true);
    model.status = !g_Received ? "Carregando os horários..."
                               : (g_Events.empty() ? "Nenhum evento com horário no servidor agora." : "");
    model.cards.clear();
    for (int i = 0; i < PerPage; ++i)
    {
        const size_t k = static_cast<size_t>(m_Page * PerPage + i);
        if (k >= g_Events.size())
            break;
        const Event& e = g_Events[k];
        const bool known = e.type >= 0 && e.type < static_cast<int>(std::size(kEvents));
        const Situation s = EvSituation(e, now);
        EventosCard card;
        card.name = known ? kEvents[e.type].name : "Evento";
        card.art = known ? std::string("image(ev-") + kEvents[e.type].art + ")" : "none";
        card.about = known ? kEvents[e.type].about : "";
        card.open = s.open;
        card.count = (s.open ? "Fecha em " : "Abre em ") + EvClock(s.left);
        card.next = (s.next > 0 ? EvTimeOfDay(s.next, false) : std::string("--:--")) + ", " + std::to_string(e.duration) + " min";
        card.enter = e.levelMax <= 0 || (level >= e.levelMin && level <= e.levelMax);
        card.level = e.levelMax <= 0 ? std::string("Todos os níveis")
                                     : "Nível " + std::to_string(e.levelMin) + " a " + std::to_string(e.levelMax);
        model.cards.push_back(card);
    }
    model.page = "Página " + std::to_string(m_Page + 1) + " de " + std::to_string(EvPages());
    model.canPrev = m_Page > 0;
    model.canNext = m_Page < EvPages() - 1;

    for (const char* field : {"clock", "status", "cards", "page", "can_prev", "can_next"})
        m_RmlView.MarkDirty(field);
}

float CEventosWindow::GetLayerDepth()
{
    return 10.62f;
}

float CEventosWindow::GetKeyEventOrder()
{
    return 10.f;
}
