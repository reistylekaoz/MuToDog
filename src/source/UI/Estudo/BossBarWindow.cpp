#include "stdafx.h"
#include "UI/Estudo/BossBarWindow.h"
#include "UI/Core/WindowSystem.h"
#include "Core/Text/Utf8.h"
#include "Data/GameData/MonsterData/MonsterDatabase.h"
#include "Engine/Object/ZzzCharacter.h"
#include "Scenes/SceneCore.h"
#include "UI/RmlBridge/RmlDocumentVisibility.h"

#include <RmlUi/Core/DataModelHandle.h>
#include <RmlUi/Core/ElementDocument.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <cwchar>
#include <map>

using namespace mu::ui::window;

namespace
{
constexpr int Layers = 10;              // toda barra de boss tem 10 (BARRAS do Godot)
constexpr float BarWidth = 240.f;       // px da tela de referência (boss_bar.rcss)
constexpr std::uint32_t HideMs = 2000;  // sem pacote há 2 s: saiu de perto
constexpr std::uint32_t EndMs = 6000;   // o texto do fim
constexpr std::uint32_t BlinkMs = 1200; // o líder mudou: pisca

// cor de cada barra, da 1 (a última, vermelha) pra cima (CORES do Godot)
constexpr const char* kColors[Layers] = {"#961018", "#c45c14", "#be9614", "#468c28", "#18827a",
                                         "#1e5aaa", "#5a32aa", "#96288c", "#1ea0c8", "#c8326e"};
// a mesma cor 35% mais escura, pro marcador
constexpr const char* kMarkerColors[Layers] = {"#610a10", "#7f3c0d", "#7b620d", "#2e5b1a", "#10554f",
                                               "#143a6e", "#3a206e", "#621a5b", "#146882", "#822048"};

// os nomes da casa (o jogo não tem esses monstros na tabela); os 7 reflexos do Kundun viram só "Kundun"
const std::map<int, std::string> kNames = {
    {900, "Séphora, Rainha das Cinzas"}, {916, "Rainha Larva"}, {919, "Lorde Arqueiro de Osso"},
    {923, "Rainha Górgona do Abismo"},   {161, "Kundun"},       {181, "Kundun"},
    {189, "Kundun"},                     {197, "Kundun"},       {267, "Kundun"},
    {338, "Kundun"},                     {275, "Kundun"},
};

struct BarState
{
    bool active = false;
    int id = -1;
    int number = 0;
    long long hp = 0;
    long long hpMax = 1;
    long long leaderDamage = 0;
    long long myDamage = 0;
    int position = 0;
    int count = 0;
    std::string leader;
    std::string leaderBefore;
    std::uint32_t lastMs = 0;
    std::uint32_t changedMs = 0;
    bool fresh = false; // boss novo: o rastro começa na vida de agora
    std::string end;
    std::uint32_t endMs = 0;
};

BarState g_Bar;

std::uint32_t BossNowMs()
{
    using namespace std::chrono;
    return static_cast<std::uint32_t>(duration_cast<milliseconds>(steady_clock::now().time_since_epoch()).count());
}

std::uint32_t BossLE32(const std::uint8_t* p)
{
    return p[0] | (p[1] << 8) | (p[2] << 16) | (static_cast<std::uint32_t>(p[3]) << 24);
}

std::string BossName10(const std::uint8_t* p)
{
    const void* zero = std::memchr(p, 0, 10);
    const size_t n = zero != nullptr ? static_cast<size_t>(static_cast<const std::uint8_t*>(zero) - p) : 10;
    return std::string(reinterpret_cast<const char*>(p), n);
}

std::string BossThousands(long long value)
{
    std::string digits = std::to_string(value < 0 ? -value : value);
    for (int i = static_cast<int>(digits.size()) - 3; i > 0; i -= 3)
        digits.insert(static_cast<size_t>(i), ".");
    return value < 0 ? "-" + digits : digits;
}

std::string BossName()
{
    const auto it = kNames.find(g_Bar.number);
    if (it != kNames.end())
        return it->second;
    // os dourados marcados como boss: o nome do monstro na tabela do jogo
    const wchar_t* name = GetMonsterName(g_Bar.number);
    if (name != nullptr && std::wcscmp(name, L"()") != 0 && name[0] != L'\0')
        return Core::Text::ToUtf8(name);
    return "Boss";
}

// o nome até a vírgula ("Séphora, Rainha das Cinzas" -> "Séphora")
std::string BossShortName()
{
    const std::string name = BossName();
    return name.substr(0, name.find(','));
}

float BossFraction()
{
    return std::clamp(static_cast<float>(g_Bar.hp) / static_cast<float>(std::max(1LL, g_Bar.hpMax)), 0.f, 1.f);
}

// em que barra a vida está (10 .. 1; 0 morto) e quanto dessa barra ainda tem (0..1)
void BossLayer(float f, int& layer, float& part)
{
    if (f <= 0.f)
    {
        layer = 0;
        part = 0.f;
        return;
    }
    layer = std::clamp(static_cast<int>(std::ceil(f * Layers - 0.000001f)), 1, Layers);
    part = std::clamp(f * Layers - static_cast<float>(layer - 1), 0.f, 1.f);
}

std::string BossPx(float v)
{
    return std::to_string(static_cast<int>(std::lround(v))) + "px";
}
} // namespace

CBossBarWindow::CBossBarWindow() = default;

CBossBarWindow::~CBossBarWindow()
{
    Release();
}

bool CBossBarWindow::Create(CManager* pNewUIMng)
{
    if (pNewUIMng == nullptr)
        return false;
    m_pNewUIMng = pNewUIMng;
    m_pNewUIMng->AddUIObj(INTERFACE_BOSS_BAR, this);
    m_RmlView.Ensure();
    // Fica sempre escondida pro gerente (nao pega mouse nem teclas); o Update mostra o documento quando tem boss.
    Show(false);
    return true;
}

void CBossBarWindow::Release()
{
    if (m_pNewUIMng)
    {
        m_pNewUIMng->RemoveUIObj(this);
        m_pNewUIMng = nullptr;
    }
    m_RmlView.Release();
}

void CBossBarWindow::ReceivePacket(const std::uint8_t* packet, int size)
{
    if (packet == nullptr || size < 4 || packet[0] != 0xC1 || packet[2] != 0xFA)
        return;
    const std::uint32_t now = BossNowMs();
    if (packet[3] == 0x01 && size >= 36)
    {
        const int id = packet[4] | (packet[5] << 8);
        const bool fresh = !g_Bar.active || g_Bar.id != id;
        g_Bar.active = true;
        g_Bar.id = id;
        g_Bar.number = static_cast<std::int16_t>(packet[6] | (packet[7] << 8));
        g_Bar.hp = static_cast<std::int32_t>(BossLE32(packet + 8));
        g_Bar.hpMax = std::max<long long>(1, static_cast<std::int32_t>(BossLE32(packet + 12)));
        g_Bar.leaderDamage = BossLE32(packet + 16);
        g_Bar.myDamage = BossLE32(packet + 20);
        g_Bar.position = packet[24];
        g_Bar.count = packet[25];
        g_Bar.leader = BossName10(packet + 26);
        g_Bar.lastMs = now;
        g_Bar.end.clear();
        if (fresh)
        {
            g_Bar.fresh = true;
            g_Bar.leaderBefore = g_Bar.leader;
        }
        if (g_Bar.leader != g_Bar.leaderBefore)
        {
            g_Bar.leaderBefore = g_Bar.leader;
            g_Bar.changedMs = now;
        }
    }
    else if (packet[3] == 0x02 && size >= 17)
    {
        const int id = packet[4] | (packet[5] << 8);
        if (!g_Bar.active || g_Bar.id != id)
            return;
        if (packet[6] == 0)
        {
            const std::string winner = BossName10(packet + 7);
            g_Bar.end = BossShortName() + " derrotada!" + (winner.empty() ? std::string() : " O drop é de " + winner);
            g_Bar.endMs = now;
            g_Bar.hp = 0;
        }
        else
        {
            g_Bar.active = false;
        }
    }
}

bool CBossBarWindow::UpdateMouseEvent()
{
    return true;
}

bool CBossBarWindow::UpdateKeyEvent()
{
    return true;
}

bool CBossBarWindow::Update()
{
    const bool inGame = SceneFlag == MAIN_SCENE && Hero != nullptr;
    const std::uint32_t now = BossNowMs();
    if (!inGame)
        g_Bar.active = false;
    else if (g_Bar.active && !g_Bar.end.empty() && now - g_Bar.endMs > EndMs)
        g_Bar.active = false;
    else if (g_Bar.active && g_Bar.end.empty() && now - g_Bar.lastMs > HideMs)
        g_Bar.active = false;

    m_RmlView.Ensure();
    Rml::ElementDocument* document = m_RmlView.Document();
    if (document == nullptr)
        return true;
    UI::RmlBridge::SyncDocumentVisibility(document, g_Bar.active);
    if (g_Bar.active)
        Rebuild(now);
    m_LastTick = now;
    return true;
}

bool CBossBarWindow::Render()
{
    return true;
}

void CBossBarWindow::BindRmlModel(Rml::DataModelConstructor& c, BossBarRmlModel& model)
{
    c.Bind("name", &model.name);
    c.Bind("under", &model.under);
    c.Bind("color", &model.color);
    c.Bind("fill", &model.fill);
    c.Bind("trail", &model.trail);
    c.Bind("marker", &model.marker);
    c.Bind("marker_color", &model.markerColor);
    c.Bind("hp", &model.hp);
    c.Bind("end", &model.end);
    c.Bind("leader", &model.leader);
    c.Bind("leader_look", &model.leaderLook);
    c.Bind("me", &model.me);
    c.Bind("contest", &model.contest);
}

void CBossBarWindow::Rebuild(std::uint32_t now)
{
    BossBarRmlModel& model = m_RmlView.GetModel();
    const float f = BossFraction();
    int layer = 0;
    float part = 0.f;
    BossLayer(f, layer, part);

    // o rastro desce no ritmo de uma barra (não da vida toda) e nunca passa do topo da barra de agora
    if (g_Bar.fresh)
    {
        m_Trail = f;
        g_Bar.fresh = false;
    }
    const float dt = std::clamp(static_cast<float>(now - m_LastTick) / 1000.f, 0.f, 0.25f);
    m_Trail = std::max(m_Trail, f);
    const float step = dt * 0.35f / Layers;
    m_Trail = m_Trail > f ? std::max(f, m_Trail - step) : f;
    m_Trail = std::min(m_Trail, static_cast<float>(layer) / Layers);
    const float trail = layer >= 1 ? std::clamp(m_Trail * Layers - static_cast<float>(layer - 1), 0.f, 1.f) : m_Trail;

    model.name = BossName();
    model.under = layer > 1 ? kColors[(layer - 2) % Layers] : "transparent";
    model.color = kColors[std::max(0, layer - 1) % Layers];
    model.fill = BossPx(BarWidth * (layer >= 1 ? part : 0.f));
    model.trail = BossPx(BarWidth * trail);
    model.marker = layer > 1 ? std::to_string(layer) + "X" : "";
    model.markerColor = kMarkerColors[std::max(0, layer - 1) % Layers];
    char percent[16];
    std::snprintf(percent, sizeof(percent), "%d%%", f > 0.f ? static_cast<int>(std::ceil(f * 100.f)) : 0);
    model.hp = BossThousands(g_Bar.hp) + " / " + BossThousands(g_Bar.hpMax) + "  (" + percent + ")";
    model.end = g_Bar.end;
    model.contest = g_Bar.end.empty() && !(g_Bar.leader.empty() && g_Bar.position == 0);
    const bool mine = g_Bar.position == 1;
    const bool blink = now - g_Bar.changedMs < BlinkMs && (now / 150) % 2 == 0;
    model.leaderLook = blink ? "pisca" : (mine ? "eu" : "outro");
    model.leader = "Direito ao drop: " + (mine ? std::string("você") : g_Bar.leader) + "  ·  " +
                   BossThousands(g_Bar.leaderDamage) + " de dano";
    model.me = g_Bar.position > 0 ? "Seu dano: " + BossThousands(g_Bar.myDamage) + "  ·  " + std::to_string(g_Bar.position) +
                                        "º de " + std::to_string(g_Bar.count)
                                  : "Você ainda não está na disputa: bata na " + BossShortName();

    for (const char* field : {"name", "under", "color", "fill", "trail", "marker", "marker_color", "hp", "end", "leader",
                              "leader_look", "me", "contest"})
        m_RmlView.MarkDirty(field);
}

float CBossBarWindow::GetLayerDepth()
{
    return 1.0f;
}

float CBossBarWindow::GetKeyEventOrder()
{
    return 1.f;
}
