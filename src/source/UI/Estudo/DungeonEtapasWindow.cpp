#include "stdafx.h"
#include "UI/Estudo/DungeonEtapasWindow.h"
#include "UI/Core/WindowSystem.h"
#include "UI/Core/WindowCommon.h"
#include "Audio/DSPlaySound.h"
#include "Core/Text/Utf8.h"
#include "Engine/Object/ZzzCharacter.h"
#include "Network/Server/WSclient.h"
#include "Render/Renderer/MuRenderer.h"
#include "Scenes/SceneCore.h"
#include "UI/RmlBridge/RmlDocumentVisibility.h"
#include "World/MapInfra/MapManager.h"

#include <RmlUi/Core/DataModelHandle.h>
#include <RmlUi/Core/ElementDocument.h>
#include <RmlUi/Core/Event.h>

#include <algorithm>
#include <array>
#include <chrono>
#include <cstdio>
#include <cstring>

using namespace mu::ui::window;

namespace
{
constexpr std::uint8_t PacketCode = 0xFA;
constexpr std::uint32_t HideMs = 3000; // sem FA 20 há 3 s: saiu da dungeon
constexpr int FogSide = 64;            // casas de 4 x 4 tiles
constexpr int FogBytes = FogSide * FogSide / 8;
constexpr char kFogSource[] = "estudo:nevoa-dungeon";

constexpr int ActionNone = 0;
constexpr int ActionChoose = 1;
constexpr int ActionConfirm = 2;
constexpr int ActionEnter = 3;
constexpr int ActionClose = 4;
constexpr int ActionStart = 5;
constexpr int ActionPortalGo = 6;
constexpr int ActionPortalStay = 7;

struct Difficulty
{
    const char* name;
    const char* note;
    const char* command;
};
// as mesmas da janela_dungeon.gd (DIF)
constexpr std::array<Difficulty, 5> kDifficulties = {{
    {"Fácil", "Monstros 0,5x · sem Box of Necklace", "facil"},
    {"Normal", "Monstros 1x · as caixas de sempre", "normal"},
    {"Difícil", "Monstros 2x · 1 caixa a mais em cada boss", "dificil"},
    {"Infernal", "Monstros 4x · caixa a mais e 1 brinco no boss final", "infernal"},
    {"Hardcore", "Monstros 4x · morreu, saiu · golpe do boss mata · par de brincos", "hardcore"},
}};

struct PanelState
{
    std::uint32_t lastMs = 0;
    bool received = false;
    int state = 0;
    int seconds = 0;
    int alive = 0;
    int stage = 1;
    int bossesDead = 0;
    int bossesTotal = 0;
    bool leader = true;
    int difficulty = 1;
};

struct FogState
{
    std::array<std::uint8_t, FogBytes> bits{};
    int floor = 0;
    int version = 0;   // sobe a cada FA 24 que mudou alguma casa
    int uploaded = -1; // a versão que está na textura
    std::uint32_t texture = 0;
};

PanelState g_Panel;
FogState g_Fog;
std::vector<CDungeonEtapasWindow::Point> g_Points;
bool g_GuardLeader = true;
bool g_GuardPending = false;
bool g_PortalPending = false;
int g_PortalStage = 2;

std::uint32_t NowMs()
{
    using namespace std::chrono;
    return static_cast<std::uint32_t>(duration_cast<milliseconds>(steady_clock::now().time_since_epoch()).count());
}

bool PanelAlive()
{
    return g_Panel.received && NowMs() - g_Panel.lastMs <= HideMs;
}

bool InDungeonMap()
{
    return gMapManager.WorldActive == WD_90DUNGEON_ETAPAS;
}

void ClearDungeon()
{
    g_Panel.received = false;
    g_Points.clear();
    if (g_Fog.floor != 0)
    {
        g_Fog.floor = 0;
        g_Fog.bits.fill(0);
        ++g_Fog.version;
    }
}

// a névoa em RGBA 64 x 64, pré-multiplicada (o RmlUi compõe assim). A imagem do minimapa tem o x no y do mundo
// (CMiniMap::SyncMap: heroX = PositionY), então o pixel (coluna u, linha v) é a casa cx = v, cy = u.
void UploadFog()
{
    if (g_Fog.uploaded == g_Fog.version && g_Fog.texture != 0)
        return;
    std::array<std::uint8_t, FogSide * FogSide * 4> pixels{};
    for (int v = 0; v < FogSide; ++v)
    {
        for (int u = 0; u < FogSide; ++u)
        {
            const int bit = u * FogSide + v; // cy * 64 + cx
            const bool revealed = (g_Fog.bits[static_cast<size_t>(bit >> 3)] >> (bit & 7)) & 1;
            std::uint8_t* p = &pixels[static_cast<size_t>((v * FogSide + u) * 4)];
            if (!revealed)
            {
                // (0,02 0,02 0,035) a 0,96, como o minimapa.gd, já multiplicado pelo alfa
                p[0] = 5;
                p[1] = 5;
                p[2] = 8;
                p[3] = 245;
            }
        }
    }
    auto& renderer = mu::GetRenderer();
    if (g_Fog.texture == 0)
        g_Fog.texture = renderer.CreateTexture(FogSide, FogSide, pixels.data());
    else
        renderer.QueueTextureUpdate(g_Fog.texture, pixels.data(), FogSide, FogSide);
    g_Fog.uploaded = g_Fog.version;
}

Rml::String TimeText(int seconds)
{
    char buffer[16];
    std::snprintf(buffer, sizeof(buffer), "%d:%02d", seconds / 60, seconds % 60);
    return buffer;
}
} // namespace

CDungeonEtapasWindow::CDungeonEtapasWindow() = default;

CDungeonEtapasWindow::~CDungeonEtapasWindow()
{
    Release();
}

bool CDungeonEtapasWindow::Create(CManager* pNewUIMng)
{
    if (pNewUIMng == nullptr)
        return false;

    m_pNewUIMng = pNewUIMng;
    m_pNewUIMng->AddUIObj(INTERFACE_DUNGEON_ETAPAS, this);
    m_RmlView.Ensure();
    Show(false);
    return true;
}

void CDungeonEtapasWindow::Release()
{
    if (m_pNewUIMng)
    {
        m_pNewUIMng->RemoveUIObj(this);
        m_pNewUIMng = nullptr;
    }
    m_RmlView.Release();
}

void CDungeonEtapasWindow::Show(bool bShow)
{
    CObject::Show(bShow);
    m_BuiltKey.clear();
}

void CDungeonEtapasWindow::ReceivePacket(const std::uint8_t* packet, int size)
{
    if (packet == nullptr || size < 5)
        return;
    const bool c2 = packet[0] == 0xC2;
    const int at = c2 ? 3 : 2; // onde está o FA
    if (packet[at] != PacketCode)
        return;
    const std::uint8_t sub = packet[at + 1];
    const std::uint8_t* d = packet + at + 2;
    const int length = size - (at + 2);

    if (!c2 && sub == 0x20 && length >= 10)
    {
        g_Panel.received = true;
        g_Panel.lastMs = NowMs();
        g_Panel.state = d[0];
        g_Panel.seconds = d[1] | (d[2] << 8);
        g_Panel.alive = d[3] | (d[4] << 8);
        g_Panel.stage = d[5];
        g_Panel.bossesDead = d[6];
        g_Panel.bossesTotal = d[7];
        g_Panel.leader = d[8] != 0;
        g_Panel.difficulty = std::clamp(static_cast<int>(d[9]), 0, static_cast<int>(kDifficulties.size()) - 1);
    }
    else if (!c2 && sub == 0x21 && length >= 1)
    {
        g_GuardLeader = d[0] != 0;
        g_GuardPending = true;
    }
    else if (!c2 && sub == 0x25 && length >= 1)
    {
        g_PortalStage = d[0];
        g_PortalPending = true;
    }
    else if (c2 && sub == 0x22 && length >= 1)
    {
        const int count = std::min(static_cast<int>(d[0]), (length - 1) / 3);
        g_Points.clear();
        for (int i = 0; i < count; ++i)
            g_Points.push_back({d[1 + i * 3], d[2 + i * 3], d[3 + i * 3]});
    }
    else if (c2 && sub == 0x24 && length >= 1 + FogBytes)
    {
        const int floor = d[0];
        if (floor != g_Fog.floor || std::memcmp(g_Fog.bits.data(), d + 1, FogBytes) != 0)
        {
            g_Fog.floor = floor;
            std::memcpy(g_Fog.bits.data(), d + 1, FogBytes);
            ++g_Fog.version;
        }
    }
}

bool CDungeonEtapasWindow::Active()
{
    return PanelAlive() && InDungeonMap();
}

const std::vector<CDungeonEtapasWindow::Point>& CDungeonEtapasWindow::Points()
{
    static const std::vector<Point> empty;
    return Active() && g_Panel.state == 1 ? g_Points : empty;
}

Rml::String CDungeonEtapasWindow::FogSource()
{
    if (!Active() || g_Panel.state != 1 || g_Fog.floor == 0)
        return {};
    UploadFog();
    return g_Fog.texture != 0 ? Rml::String(kFogSource) : Rml::String();
}

bool CDungeonEtapasWindow::IsFogSource(const Rml::String& source)
{
    return source.find(kFogSource) != Rml::String::npos;
}

void* CDungeonEtapasWindow::ResolveFog(int& width, int& height)
{
    if (g_Fog.texture == 0)
        return nullptr;
    width = FogSide;
    height = FogSide;
    return mu::GetRenderer().GetRawTexture(g_Fog.texture);
}

void CDungeonEtapasWindow::SendChat(const char* text)
{
    if (SocketClient == nullptr || Hero == nullptr)
        return;
    const std::wstring wide = Core::Text::FromUtf8(text);
    SocketClient->ToGameServer()->SendPublicChatMessage(MU_C16(Hero->ID), MU_C16(wide.c_str()));
}

bool CDungeonEtapasWindow::UpdateMouseEvent()
{
    // o diálogo aberto (ou a caixa do portal) segura o mouse (os botões são do RmlUi)
    return !IsVisible() && !m_RmlView.GetModel().portal;
}

bool CDungeonEtapasWindow::UpdateKeyEvent()
{
    DungeonEtapasRmlModel& model = m_RmlView.GetModel();
    if (model.portal && IsPress(VK_ESCAPE))
    {
        m_PendingAction = ActionPortalStay;
        return false;
    }
    if (IsVisible() && IsPress(VK_ESCAPE))
    {
        g_pNewUISystem->Hide(INTERFACE_DUNGEON_ETAPAS);
        PlayBuffer(SOUND_CLICK01);
        return false;
    }
    return true;
}

bool CDungeonEtapasWindow::Update()
{
    const bool inGame = SceneFlag == MAIN_SCENE && Hero != nullptr;
    if (!inGame || (g_Panel.received && !PanelAlive()))
        ClearDungeon();

    if (g_GuardPending && inGame)
    {
        g_GuardPending = false;
        DungeonEtapasRmlModel& model = m_RmlView.GetModel();
        model.leader = g_GuardLeader;
        model.choice = 1;
        g_pNewUISystem->Show(INTERFACE_DUNGEON_ETAPAS);
        PlayBuffer(SOUND_CLICK01);
    }

    if (g_PortalPending && inGame)
    {
        // 24/11 (Murilo): pisou ou clicou no portal, a caixa confirma antes de ir pra etapa seguinte
        g_PortalPending = false;
        DungeonEtapasRmlModel& model = m_RmlView.GetModel();
        model.portal = true;
        model.portalText = "Ir para a Etapa " + std::to_string(g_PortalStage) + " de 3?";
        m_BuiltKey.clear();
        PlayBuffer(SOUND_CLICK01);
    }
    if (!Active() && m_RmlView.GetModel().portal)
    {
        m_RmlView.GetModel().portal = false;
        m_BuiltKey.clear();
    }

    RunPending();

    m_RmlView.Ensure();
    Rml::ElementDocument* document = m_RmlView.Document();
    if (document == nullptr)
        return true;
    const bool visible = inGame && (IsVisible() || PanelAlive() || m_RmlView.GetModel().portal);
    UI::RmlBridge::SyncDocumentVisibilityInFront(document, visible);
    if (visible)
        Rebuild();
    return true;
}

bool CDungeonEtapasWindow::Render()
{
    return true;
}

void CDungeonEtapasWindow::RunPending()
{
    const int action = m_PendingAction;
    m_PendingAction = ActionNone;
    DungeonEtapasRmlModel& model = m_RmlView.GetModel();
    switch (action)
    {
    case ActionChoose:
        if (model.leader && m_PendingChoice >= 0 && m_PendingChoice < static_cast<int>(kDifficulties.size()))
        {
            model.choice = m_PendingChoice;
            m_BuiltKey.clear();
            PlayBuffer(SOUND_CLICK01);
        }
        break;
    case ActionConfirm:
        if (model.leader)
        {
            const std::string command = std::string("/dungeon ") + kDifficulties[static_cast<size_t>(model.choice)].command;
            SendChat(command.c_str());
            g_pNewUISystem->Hide(INTERFACE_DUNGEON_ETAPAS);
            PlayBuffer(SOUND_CLICK01);
        }
        break;
    case ActionEnter:
        SendChat("/dungeon");
        g_pNewUISystem->Hide(INTERFACE_DUNGEON_ETAPAS);
        PlayBuffer(SOUND_CLICK01);
        break;
    case ActionClose:
        g_pNewUISystem->Hide(INTERFACE_DUNGEON_ETAPAS);
        PlayBuffer(SOUND_CLICK01);
        break;
    case ActionStart:
        if (PanelAlive() && g_Panel.state == 0 && g_Panel.leader)
        {
            SendChat("/dungeon iniciar");
            PlayBuffer(SOUND_CLICK01);
        }
        break;
    case ActionPortalGo:
        if (model.portal)
        {
            SendChat("/dungeon portal");
            model.portal = false;
            m_BuiltKey.clear();
            PlayBuffer(SOUND_CLICK01);
        }
        break;
    case ActionPortalStay:
        if (model.portal)
        {
            model.portal = false;
            m_BuiltKey.clear();
            PlayBuffer(SOUND_CLICK01);
        }
        break;
    default:
        break;
    }
    m_PendingChoice = -1;
}

void CDungeonEtapasWindow::BindRmlModel(Rml::DataModelConstructor& c, DungeonEtapasRmlModel& model)
{
    auto row = c.RegisterStruct<DungeonDifficultyRow>();
    row.RegisterMember("name", &DungeonDifficultyRow::name);
    row.RegisterMember("note", &DungeonDifficultyRow::note);
    row.RegisterMember("index", &DungeonDifficultyRow::index);
    c.RegisterArray<std::vector<DungeonDifficultyRow>>();

    c.Bind("panel", &model.panel);
    c.Bind("state", &model.state);
    c.Bind("title", &model.title);
    c.Bind("line", &model.line);
    c.Bind("big", &model.big);
    c.Bind("hint", &model.hint);
    c.Bind("start_button", &model.startButton);
    c.Bind("guard", &model.guard);
    c.Bind("leader", &model.leader);
    c.Bind("choice", &model.choice);
    c.Bind("difficulties", &model.difficulties);
    c.Bind("confirm", &model.confirm);
    c.Bind("portal", &model.portal);
    c.Bind("portal_text", &model.portalText);

    c.BindEventCallback("dg_choose",
                        [this](Rml::DataModelHandle, Rml::Event&, const Rml::VariantList& arguments)
                        {
                            if (arguments.size() == 1)
                            {
                                m_PendingChoice = arguments[0].Get<int>(-1);
                                m_PendingAction = ActionChoose;
                            }
                        });
    c.BindEventCallback("dg_confirm", [this](Rml::DataModelHandle, Rml::Event&, const Rml::VariantList&)
                        { m_PendingAction = ActionConfirm; });
    c.BindEventCallback("dg_enter", [this](Rml::DataModelHandle, Rml::Event&, const Rml::VariantList&)
                        { m_PendingAction = ActionEnter; });
    c.BindEventCallback("dg_close", [this](Rml::DataModelHandle, Rml::Event&, const Rml::VariantList&)
                        { m_PendingAction = ActionClose; });
    c.BindEventCallback("dg_start", [this](Rml::DataModelHandle, Rml::Event&, const Rml::VariantList&)
                        { m_PendingAction = ActionStart; });
    c.BindEventCallback("dg_portal_go", [this](Rml::DataModelHandle, Rml::Event&, const Rml::VariantList&)
                        { m_PendingAction = ActionPortalGo; });
    c.BindEventCallback("dg_portal_stay", [this](Rml::DataModelHandle, Rml::Event&, const Rml::VariantList&)
                        { m_PendingAction = ActionPortalStay; });
}

void CDungeonEtapasWindow::Rebuild()
{
    DungeonEtapasRmlModel& model = m_RmlView.GetModel();
    const bool panel = PanelAlive();
    const std::string key = std::to_string(IsVisible()) + ',' + std::to_string(model.leader) + ',' +
                            std::to_string(model.choice) + ',' + std::to_string(panel) + ',' +
                            std::to_string(g_Panel.state) + ',' + std::to_string(g_Panel.seconds) + ',' +
                            std::to_string(g_Panel.alive) + ',' + std::to_string(g_Panel.stage) + ',' +
                            std::to_string(g_Panel.bossesDead) + ',' + std::to_string(g_Panel.bossesTotal) + ',' +
                            std::to_string(g_Panel.leader) + ',' + std::to_string(g_Panel.difficulty) + ',' +
                            std::to_string(model.portal);
    if (key == m_BuiltKey)
        return;
    m_BuiltKey = key;

    model.guard = IsVisible();
    if (model.difficulties.empty())
    {
        for (size_t i = 0; i < kDifficulties.size(); ++i)
            model.difficulties.push_back({kDifficulties[i].name, kDifficulties[i].note, static_cast<int>(i)});
    }
    model.confirm = std::string("Confirmar (") + kDifficulties[static_cast<size_t>(model.choice)].name + ")";

    model.panel = panel;
    model.state = g_Panel.state;
    model.title = std::string("Dungeon · ") + kDifficulties[static_cast<size_t>(g_Panel.difficulty)].name;
    model.startButton = false;
    if (g_Panel.state == 0)
    {
        model.line = "A party tem até 2 minutos pra entrar";
        model.big = TimeText(g_Panel.seconds);
        model.startButton = g_Panel.leader;
        model.hint = g_Panel.leader ? "" : "O líder da party inicia";
    }
    else if (g_Panel.state == 1)
    {
        // 24/11: chefes em pontos sorteados do andar; o portal abre onde cai o último
        const int total = g_Panel.bossesTotal;
        const int dead = std::min(g_Panel.bossesDead, total);
        model.line = "Etapa " + std::to_string(g_Panel.stage) + " de 3  ·  " + std::to_string(g_Panel.alive) + " monstros";
        model.big = std::to_string(dead) + " de " + std::to_string(total);
        model.hint = "chefes derrotados · procure no mapa (Tab)";
        if (total > 0 && dead >= total)
            model.hint = g_Panel.stage < 3 ? "portal aberto: entre nele" : "todos os chefes derrotados";
    }
    else
    {
        // 24/11: os segundos são o que falta pra ir pra Lorencia
        model.line = g_Panel.seconds > 0 ? "Dungeon concluída" : "";
        model.big = g_Panel.seconds > 0 ? TimeText(g_Panel.seconds) : "Dungeon concluída";
        model.hint = g_Panel.seconds > 0 ? "Pegue as caixas: depois disso, Lorencia" : "Pegue as caixas antes de sair";
    }

    for (const char* field : {"panel", "state", "title", "line", "big", "hint", "start_button", "guard", "leader",
                              "choice", "difficulties", "confirm", "portal", "portal_text"})
        m_RmlView.MarkDirty(field);
}

float CDungeonEtapasWindow::GetLayerDepth()
{
    return 10.62f;
}

float CDungeonEtapasWindow::GetKeyEventOrder()
{
    return 10.f;
}
