#include "stdafx.h"
#include "UI/Estudo/ResetSystemWindow.h"
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
#include <chrono>

using namespace mu::ui::window;

namespace
{
// C1 FB <comando>: o grupo livre do servidor do MU Estudo (BancoJoiasHandlerPlugIn.cs).
constexpr std::uint8_t PacketHead = 0xC1;
constexpr std::uint8_t PacketCode = 0xFB;
constexpr std::uint8_t CommandState = 0x34;
constexpr std::uint8_t CommandReset = 0x35;
constexpr std::uint8_t CommandGrandReset = 0x36;
constexpr int StatePacketSize = 31;
// O estado chega de novo a cada tanto: o icone pisca quando o nivel chega no do reset.
constexpr std::uint64_t RequestIntervalMs = 15000;

constexpr int ActionNone = 0;
constexpr int ActionTabReset = 1;
constexpr int ActionTabGrand = 2;
constexpr int ActionDo = 3;
constexpr int ActionClose = 4;
constexpr int ActionIcon = 5;

ResetSystemState g_State;

std::uint64_t NowMs()
{
    using namespace std::chrono;
    return static_cast<std::uint64_t>(duration_cast<milliseconds>(steady_clock::now().time_since_epoch()).count());
}

int ReadU16(const std::uint8_t* p, int at)
{
    return p[at] | (p[at + 1] << 8);
}

std::uint32_t ReadU32(const std::uint8_t* p, int at)
{
    return static_cast<std::uint32_t>(p[at]) | (static_cast<std::uint32_t>(p[at + 1]) << 8) |
           (static_cast<std::uint32_t>(p[at + 2]) << 16) | (static_cast<std::uint32_t>(p[at + 3]) << 24);
}

// 1000000 -> "1.000.000", como o BarraBoss.milhar do Godot.
Rml::String Thousands(std::uint64_t value)
{
    std::string digits = std::to_string(value);
    std::string out;
    const int count = static_cast<int>(digits.size());
    for (int i = 0; i < count; ++i)
    {
        if (i > 0 && (count - i) % 3 == 0)
            out += '.';
        out += digits[static_cast<size_t>(i)];
    }
    return out;
}

Rml::String Fraction(int have, int need)
{
    return std::to_string(std::min(have, need)) + " / " + std::to_string(need);
}

bool CanReset(const ResetSystemState& s, int level, std::int64_t zen)
{
    if (!s.enabled || s.resets >= s.limit || level < s.level)
        return false;
    return zen < 0 || zen >= static_cast<std::int64_t>(s.zen);
}

bool CanGrand(const ResetSystemState& s, int level, std::int64_t zen)
{
    if (!s.enabled || s.grandLimit <= 0 || s.grand >= s.grandLimit)
        return false;
    if (s.resets < s.grandResets || level < s.level)
        return false;
    return zen < 0 || zen >= static_cast<std::int64_t>(s.grandZen);
}

int HeroLevel()
{
    return CharacterAttribute != nullptr ? CharacterAttribute->Level : 0;
}

std::uint32_t HeroZen()
{
    return CharacterMachine != nullptr ? static_cast<std::uint32_t>(CharacterMachine->Gold) : 0;
}
} // namespace

CResetSystemWindow::CResetSystemWindow() = default;

CResetSystemWindow::~CResetSystemWindow()
{
    Release();
}

bool CResetSystemWindow::Create(CManager* pNewUIMng)
{
    if (pNewUIMng == nullptr)
        return false;

    m_pNewUIMng = pNewUIMng;
    m_pNewUIMng->AddUIObj(INTERFACE_RESET_SYSTEM, this);
    m_RmlView.Ensure();
    Show(false);
    return true;
}

void CResetSystemWindow::Release()
{
    if (m_pNewUIMng)
    {
        m_pNewUIMng->RemoveUIObj(this);
        m_pNewUIMng = nullptr;
    }
    m_RmlView.Release();
}

void CResetSystemWindow::Show(bool bShow)
{
    CObject::Show(bShow);
    if (bShow)
    {
        SendCommand(CommandState);
        m_BuiltKey.clear();
    }
}

void CResetSystemWindow::ReceiveState(const std::uint8_t* packet, int size)
{
    if (packet == nullptr || size < StatePacketSize || packet[0] != PacketHead || packet[3] != CommandState)
        return;

    ResetSystemState s;
    s.received = true;
    s.enabled = packet[4] != 0;
    s.resets = ReadU16(packet, 5);
    s.limit = ReadU16(packet, 7);
    s.level = ReadU16(packet, 9);
    s.zen = ReadU32(packet, 11);
    s.points = ReadU32(packet, 15);
    s.grand = packet[19];
    s.grandLimit = packet[20];
    s.grandResets = ReadU16(packet, 21);
    s.grandZen = ReadU32(packet, 23);
    s.grandPoints = ReadU32(packet, 27);
    g_State = s;
}

void CResetSystemWindow::SendCommand(std::uint8_t command)
{
    if (SocketClient == nullptr)
        return;
    BYTE packet[] = {PacketHead, 4, PacketCode, command};
    SocketClient->Send(packet, static_cast<int32_t>(sizeof(packet)));
}

bool CResetSystemWindow::UpdateMouseEvent()
{
    // Aberta, segura o mouse (abas e botoes sao do RmlUi).
    return false;
}

bool CResetSystemWindow::UpdateKeyEvent()
{
    if (IsVisible() && IsPress(VK_ESCAPE))
    {
        g_pNewUISystem->Hide(INTERFACE_RESET_SYSTEM);
        PlayBuffer(SOUND_CLICK01);
        return false;
    }
    return true;
}

bool CResetSystemWindow::Update()
{
    const bool inGame = SceneFlag == MAIN_SCENE && Hero != nullptr;
    if (!inGame)
        m_NextRequestMs = 0; // volta da escolha de personagem: pede de novo na hora
    else
        RequestStateIfDue();

    RunPending();
    SyncRmlModel(inGame);
    return true;
}

bool CResetSystemWindow::Render()
{
    return true;
}

void CResetSystemWindow::RequestStateIfDue()
{
    const std::uint64_t now = NowMs();
    if (now < m_NextRequestMs)
        return;
    m_NextRequestMs = now + RequestIntervalMs;
    SendCommand(CommandState);
}

void CResetSystemWindow::RunPending()
{
    const int action = m_PendingAction;
    m_PendingAction = ActionNone;
    switch (action)
    {
    case ActionTabReset:
    case ActionTabGrand:
        m_RmlView.GetModel().tab = action == ActionTabGrand ? 1 : 0;
        m_BuiltKey.clear();
        PlayBuffer(SOUND_CLICK01);
        break;
    case ActionDo:
    {
        const bool grand = m_RmlView.GetModel().tab == 1;
        const bool can = grand ? CanGrand(g_State, HeroLevel(), HeroZen()) : CanReset(g_State, HeroLevel(), HeroZen());
        if (!can)
            break;
        SendCommand(grand ? CommandGrandReset : CommandReset);
        g_pNewUISystem->Hide(INTERFACE_RESET_SYSTEM);
        PlayBuffer(SOUND_CLICK01);
        break;
    }
    case ActionClose:
        g_pNewUISystem->Hide(INTERFACE_RESET_SYSTEM);
        PlayBuffer(SOUND_CLICK01);
        break;
    case ActionIcon:
        // o grand reset liberado abre na aba dele
        if (!IsVisible())
            m_RmlView.GetModel().tab = CanGrand(g_State, HeroLevel(), -1) ? 1 : 0;
        g_pNewUISystem->Toggle(INTERFACE_RESET_SYSTEM);
        m_BuiltKey.clear();
        PlayBuffer(SOUND_CLICK01);
        break;
    default:
        break;
    }
}

void CResetSystemWindow::BindRmlModel(Rml::DataModelConstructor& c, ResetSystemRmlModel& model)
{
    auto row = c.RegisterStruct<ResetSystemRow>();
    row.RegisterMember("label", &ResetSystemRow::label);
    row.RegisterMember("value", &ResetSystemRow::value);
    row.RegisterMember("look", &ResetSystemRow::look);
    c.RegisterArray<std::vector<ResetSystemRow>>();

    c.Bind("open", &model.open);
    c.Bind("tab", &model.tab);
    c.Bind("ready", &model.ready);
    c.Bind("enabled", &model.enabled);
    c.Bind("title", &model.title);
    c.Bind("message", &model.message);
    c.Bind("note", &model.note);
    c.Bind("rows", &model.rows);
    c.Bind("action", &model.action);
    c.Bind("can_act", &model.canAct);

    c.BindEventCallback("reset_tab",
                        [this](Rml::DataModelHandle, Rml::Event&, const Rml::VariantList& arguments)
                        {
                            if (arguments.size() == 1)
                                m_PendingAction = arguments[0].Get<int>(0) == 1 ? ActionTabGrand : ActionTabReset;
                        });
    c.BindEventCallback("reset_do", [this](Rml::DataModelHandle, Rml::Event&, const Rml::VariantList&)
                        { m_PendingAction = ActionDo; });
    c.BindEventCallback("reset_close", [this](Rml::DataModelHandle, Rml::Event&, const Rml::VariantList&)
                        { m_PendingAction = ActionClose; });
    c.BindEventCallback("reset_icon_click", [this](Rml::DataModelHandle, Rml::Event&, const Rml::VariantList&)
                        { m_PendingAction = ActionIcon; });
}

void CResetSystemWindow::SyncRmlModel(bool inGame)
{
    m_RmlView.Ensure();
    Rml::ElementDocument* document = m_RmlView.Document();
    if (document == nullptr)
        return;

    // o documento fica a mostra no jogo pelos icones da barra; a janela e o "open"
    UI::RmlBridge::SyncDocumentVisibilityInFront(document, inGame);
    if (!inGame)
        return;
    RebuildModel();
}

void CResetSystemWindow::RebuildModel()
{
    const int level = HeroLevel();
    const std::uint32_t zen = HeroZen();
    ResetSystemRmlModel& model = m_RmlView.GetModel();
    const int ready = CanGrand(g_State, level, -1) ? 2 : (CanReset(g_State, level, -1) ? 1 : 0);
    const std::string key = std::to_string(IsVisible()) + ',' + std::to_string(model.tab) + ',' +
                            std::to_string(ready) + ',' + std::to_string(level) + ',' + std::to_string(zen) + ',' +
                            std::to_string(g_State.resets) + ',' + std::to_string(g_State.grand) + ',' +
                            std::to_string(g_State.received) + ',' + std::to_string(g_State.zen);
    if (key == m_BuiltKey)
        return;
    m_BuiltKey = key;

    model.open = IsVisible();
    model.ready = ready;
    model.enabled = g_State.enabled;
    model.rows.clear();
    model.message.clear();
    model.note.clear();
    model.title.clear();
    model.action.clear();
    model.canAct = false;
    if (!g_State.enabled)
        model.message = g_State.received ? "O reset está desligado neste servidor." : "Pedindo os números do reset ao servidor...";
    else if (model.tab == 1)
        BuildGrandTab(model, level, zen);
    else
        BuildResetTab(model, level, zen);

    for (const char* field : {"open", "tab", "ready", "enabled", "title", "message", "note", "rows", "action", "can_act"})
        m_RmlView.MarkDirty(field);
}

void CResetSystemWindow::BuildResetTab(ResetSystemRmlModel& model, int level, std::uint32_t zen) const
{
    const ResetSystemState& s = g_State;
    model.title = "Reset:  " + std::to_string(s.resets) + " / " + std::to_string(s.limit);
    model.action = "Fazer reset";
    model.canAct = CanReset(s, level, zen);
    if (s.resets >= s.limit)
    {
        model.message = "Você chegou no máximo de resets.";
        if (s.grand < s.grandLimit)
            model.message += " Agora é o grand reset (aba ao lado).";
        return;
    }
    model.rows.push_back({"Para o reset", "", "secao"});
    model.rows.push_back({"Nível", Fraction(level, s.level), level >= s.level ? "ok" : "falta"});
    model.rows.push_back({"Zen", Thousands(s.zen), zen >= s.zen ? "ok" : "falta"});
    model.rows.push_back({"Prêmio do reset", "", "secao"});
    model.rows.push_back({"Pontos", Thousands(s.points), "premio"});
    model.note = "Os status voltam pra base e o nível pro 10.";
}

void CResetSystemWindow::BuildGrandTab(ResetSystemRmlModel& model, int level, std::uint32_t zen) const
{
    const ResetSystemState& s = g_State;
    model.title = "Grand Reset:  " + std::to_string(s.grand) + " / " + std::to_string(s.grandLimit);
    model.action = "Fazer grand reset";
    model.canAct = CanGrand(s, level, zen);
    if (s.grand >= s.grandLimit)
    {
        model.message = "Você chegou no máximo de grand resets.";
        return;
    }
    model.rows.push_back({"Para o grand reset", "", "secao"});
    model.rows.push_back({"Nível", Fraction(level, s.level), level >= s.level ? "ok" : "falta"});
    model.rows.push_back({"Resets", Fraction(s.resets, s.grandResets), s.resets >= s.grandResets ? "ok" : "falta"});
    model.rows.push_back({"Zen", Thousands(s.grandZen), zen >= s.grandZen ? "ok" : "falta"});
    model.rows.push_back({"Prêmio do grand reset", "", "secao"});
    model.rows.push_back({"Pontos pra sempre", Thousands(s.grandPoints), "premio"});
    model.note = "Os resets voltam pra 0.";
}

float CResetSystemWindow::GetLayerDepth()
{
    return 10.62f;
}

float CResetSystemWindow::GetKeyEventOrder()
{
    return 10.f;
}
