#include "stdafx.h"
#include "UI/Estudo/LogCacaWindow.h"
#include "UI/Core/WindowSystem.h"
#include "Data/GameConfig/GameConfig.h"
#include "Engine/Object/ZzzCharacter.h"
#include "Engine/Object/ZzzInfomation.h"
#include "Network/Server/WSclient.h"
#include "Scenes/SceneCore.h"
#include "UI/RmlBridge/RmlDocumentVisibility.h"
#include "UI/RmlBridge/RmlPointer.h"

#include <RmlUi/Core/DataModelHandle.h>
#include <RmlUi/Core/Element.h>
#include <RmlUi/Core/ElementDocument.h>
#include <RmlUi/Core/Event.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <filesystem>
#include <fstream>

using namespace mu::ui::window;

namespace
{
constexpr int TrainingDummy = 924; // Boneco de Treino da saída de Lorencia
constexpr float PanelWidth = 172.f; // v1.0.2: letra maior (era 150)
constexpr float CornerX = 640.f - PanelWidth - 4.f; // à direita, embaixo dos botões do topo e longe das mensagens do sistema
constexpr float CornerY = 34.f;
constexpr const char* PlaceFile = "log_caca.ini";

// as contas (tempo em ms do relógio do jogo)
struct Hunt
{
    long long start = -1;
    long long damage = 0;
    long long zen = 0;
    long long lastZen = 0;
    int levels = 0;
    long long exp = 0;
    long long lastExp = 0;
    int kills = 0;
    long long toNext = 0; // quanto falta pro próximo nível
    long long dummyHits = 0;
    long long dummyTotal = 0;
    long long dummyLast = 0;
    long long dummyMax = 0;
    long long dummyFirst = -1;
    long long dummyEnd = -1;
};

Hunt g_Hunt;
std::uint32_t g_Version = 1;
bool g_OpenRequest = false; // bateu no boneco com o painel fechado

long long LogNowMs()
{
    using namespace std::chrono;
    return duration_cast<milliseconds>(steady_clock::now().time_since_epoch()).count();
}

void LogStart()
{
    if (g_Hunt.start < 0)
        g_Hunt.start = LogNowMs();
}

double LogMinutes()
{
    return g_Hunt.start >= 0 ? std::max(1.0, static_cast<double>(LogNowMs() - g_Hunt.start) / 1000.0) / 60.0 : 1.0;
}

std::string LogHms(long long seconds)
{
    char text[32];
    std::snprintf(text, sizeof(text), "%02lld:%02lld:%02lld", seconds / 3600, (seconds / 60) % 60, seconds % 60);
    return text;
}

std::string LogThousands(long long value)
{
    std::string digits = std::to_string(value < 0 ? -value : value);
    for (int i = static_cast<int>(digits.size()) - 3; i > 0; i -= 3)
        digits.insert(static_cast<size_t>(i), ".");
    return value < 0 ? "-" + digits : digits;
}

// px da tela de referência em dp (a folha da janela é dp, tools/estudo_dp.py)
std::string LogDp(float v)
{
    return std::to_string(static_cast<int>(std::lround(v))) + "dp";
}

std::filesystem::path LogPlacePath()
{
    return GameConfig::GetInstance().GetConfigPath().parent_path() / PlaceFile;
}
} // namespace

CLogCacaWindow::CLogCacaWindow() = default;

CLogCacaWindow::~CLogCacaWindow()
{
    Release();
}

bool CLogCacaWindow::Create(CManager* pNewUIMng)
{
    if (pNewUIMng == nullptr)
        return false;
    m_pNewUIMng = pNewUIMng;
    m_pNewUIMng->AddUIObj(INTERFACE_LOG_CACA, this);
    m_RmlView.Ensure();
    LoadPlace();
    Show(false);
    return true;
}

void CLogCacaWindow::Release()
{
    if (m_pNewUIMng)
    {
        m_pNewUIMng->RemoveUIObj(this);
        m_pNewUIMng = nullptr;
    }
    m_RmlView.Release();
}

void CLogCacaWindow::OnHit(int damage, int number)
{
    if (damage <= 0)
        return;
    LogStart();
    g_Hunt.damage += damage;
    if (number == TrainingDummy)
    {
        const long long now = LogNowMs();
        if (g_Hunt.dummyFirst < 0)
            g_Hunt.dummyFirst = now;
        g_Hunt.dummyEnd = now;
        ++g_Hunt.dummyHits;
        g_Hunt.dummyTotal += damage;
        g_Hunt.dummyLast = damage;
        g_Hunt.dummyMax = std::max<long long>(g_Hunt.dummyMax, damage);
        g_OpenRequest = true;
    }
    ++g_Version;
}

void CLogCacaWindow::OnExp(std::int64_t previous, std::int64_t gained, bool master)
{
    if (gained <= 0)
        return;
    LogStart();
    g_Hunt.exp += gained;
    g_Hunt.lastExp = gained;
    ++g_Hunt.kills;
    const long long next = master ? static_cast<long long>(Master_Level_Data.lNext_MasterLevel_Experince)
                                  : (CharacterAttribute != nullptr ? static_cast<long long>(CharacterAttribute->NextExperience) : 0);
    g_Hunt.toNext = std::max(0LL, next - static_cast<long long>(previous + gained));
    ++g_Version;
}

bool CLogCacaWindow::UpdateMouseEvent()
{
    // So segura o mouse em cima do painel; fora dele o clique vai pro jogo.
    return !UI::RmlBridge::IsPointerOver(m_RmlView.Document());
}

bool CLogCacaWindow::UpdateKeyEvent()
{
    return true;
}

bool CLogCacaWindow::Update()
{
    const bool inGame = SceneFlag == MAIN_SCENE && Hero != nullptr && CharacterAttribute != nullptr;
    if (inGame && !m_InGame)
    {
        // personagem novo: o zen e o nível de agora são o ponto de partida
        m_LastGold = CharacterMachine != nullptr ? static_cast<unsigned long long>(CharacterMachine->Gold) : 0;
        m_LastLevel = static_cast<int>(CharacterAttribute->Level);
    }
    if (!inGame && m_InGame)
    {
        g_Hunt = Hunt{};
        g_OpenRequest = false;
        ++g_Version;
    }
    m_InGame = inGame;

    if (inGame)
    {
        const unsigned long long gold = CharacterMachine != nullptr ? static_cast<unsigned long long>(CharacterMachine->Gold) : 0;
        if (gold > m_LastGold && m_LastGold > 0)
        {
            LogStart();
            g_Hunt.lastZen = static_cast<long long>(gold - m_LastGold);
            g_Hunt.zen += g_Hunt.lastZen;
            ++g_Version;
        }
        m_LastGold = gold;
        const int level = static_cast<int>(CharacterAttribute->Level);
        if (m_LastLevel >= 0 && level > m_LastLevel)
        {
            LogStart();
            g_Hunt.levels += level - m_LastLevel;
            ++g_Version;
        }
        m_LastLevel = level;
        if (g_OpenRequest)
        {
            g_OpenRequest = false;
            if (!IsVisible())
                g_pNewUISystem->Show(INTERFACE_LOG_CACA);
        }
    }

    if (m_Reset)
    {
        m_Reset = false;
        g_Hunt = Hunt{};
        ++g_Version;
    }
    if (m_Home)
    {
        m_Home = false;
        m_OffsetX = m_OffsetY = 0.f;
        m_Save = true;
        m_Placed = false;
    }

    m_RmlView.Ensure();
    Rml::ElementDocument* document = m_RmlView.Document();
    if (document == nullptr)
        return true;
    UI::RmlBridge::SyncDocumentVisibility(document, IsVisible() && inGame);
    if (!IsVisible() || !inGame)
        return true;

    if (!m_Placed)
        Place();
    if (m_Save)
    {
        m_Save = false;
        SavePlace();
    }
    // o tempo corre na tela uma vez por segundo
    const long long second = g_Hunt.start >= 0 ? (LogNowMs() - g_Hunt.start) / 1000 : -1;
    if (second != m_SeenSecond || m_SeenVersion != g_Version)
    {
        m_SeenSecond = second;
        m_SeenVersion = g_Version;
        Rebuild();
    }
    return true;
}

bool CLogCacaWindow::Render()
{
    return true;
}

// põe o painel no canto mais o deslocamento, sem sair da tela
void CLogCacaWindow::Place()
{
    m_Placed = true;
    LogCacaRmlModel& model = m_RmlView.GetModel();
    float height = 200.f;
    if (Rml::ElementDocument* document = m_RmlView.Document())
    {
        if (Rml::Element* panel = document->GetElementById("panel"))
        {
            const float width = panel->GetClientWidth();
            if (width > 0.f)
            {
                m_Scale = width / PanelWidth;
                height = panel->GetClientHeight() / m_Scale;
            }
        }
    }
    const float x = std::clamp(CornerX + m_OffsetX, 0.f, std::max(0.f, 640.f - PanelWidth));
    const float y = std::clamp(CornerY + m_OffsetY, 0.f, std::max(0.f, 480.f - height));
    m_OffsetX = x - CornerX;
    m_OffsetY = y - CornerY;
    model.left = LogDp(x);
    model.top = LogDp(y);
    m_RmlView.MarkDirty("left");
    m_RmlView.MarkDirty("top");
}

void CLogCacaWindow::LoadPlace()
{
    std::ifstream file(LogPlacePath());
    float x = 0.f;
    float y = 0.f;
    if (file >> x >> y)
    {
        m_OffsetX = x;
        m_OffsetY = y;
    }
    m_Placed = false;
}

void CLogCacaWindow::SavePlace() const
{
    std::ofstream file(LogPlacePath(), std::ios::trunc);
    if (file)
        file << m_OffsetX << ' ' << m_OffsetY << '\n';
}

void CLogCacaWindow::BindRmlModel(Rml::DataModelConstructor& c, LogCacaRmlModel& model)
{
    auto row = c.RegisterStruct<LogCacaRow>();
    row.RegisterMember("label", &LogCacaRow::label);
    row.RegisterMember("value", &LogCacaRow::value);
    row.RegisterMember("kind", &LogCacaRow::kind);
    c.RegisterArray<std::vector<LogCacaRow>>();
    c.Bind("rows", &model.rows);
    c.Bind("left", &model.left);
    c.Bind("top", &model.top);

    // o arrastar vem do RmlUi (drag: drag no #panel), com o ponteiro em px da janela
    c.BindEventCallback("log_drag_start",
        [this](Rml::DataModelHandle, Rml::Event& event, const Rml::VariantList&)
        {
            if (Rml::Element* panel = event.GetCurrentElement(); panel != nullptr && panel->GetClientWidth() > 0.f)
                m_Scale = panel->GetClientWidth() / PanelWidth;
            m_DragX = event.GetParameter<float>("mouse_x", 0.f);
            m_DragY = event.GetParameter<float>("mouse_y", 0.f);
            m_DragOffsetX = m_OffsetX;
            m_DragOffsetY = m_OffsetY;
            m_Moved = false;
        });
    c.BindEventCallback("log_drag",
        [this](Rml::DataModelHandle, Rml::Event& event, const Rml::VariantList&)
        {
            const float dx = (event.GetParameter<float>("mouse_x", 0.f) - m_DragX) / m_Scale;
            const float dy = (event.GetParameter<float>("mouse_y", 0.f) - m_DragY) / m_Scale;
            if (!m_Moved && std::hypot(dx, dy) <= 3.f)
                return;
            m_Moved = true;
            m_OffsetX = m_DragOffsetX + dx;
            m_OffsetY = m_DragOffsetY + dy;
            m_Placed = false;
        });
    c.BindEventCallback("log_drag_end",
        [this](Rml::DataModelHandle, Rml::Event&, const Rml::VariantList&)
        {
            if (m_Moved)
                m_Save = true;
        });
    c.BindEventCallback("log_mouse_down",
        [this](Rml::DataModelHandle, Rml::Event& event, const Rml::VariantList&)
        {
            if (event.GetParameter<int>("button", 0) == 1)
                m_Home = true; // botão direito: volta pro canto
        });
    c.BindEventCallback("log_reset",
        [this](Rml::DataModelHandle, Rml::Event&, const Rml::VariantList&)
        {
            if (!m_Moved)
                m_Reset = true;
            m_Moved = false;
        });
}

void CLogCacaWindow::Rebuild()
{
    LogCacaRmlModel& model = m_RmlView.GetModel();
    const long long seconds = g_Hunt.start >= 0 ? (LogNowMs() - g_Hunt.start) / 1000 : 0;
    const double minutes = LogMinutes();
    const long long expPerMinute = static_cast<long long>(g_Hunt.exp / minutes);
    auto line = [](const char* label, const std::string& value) { return LogCacaRow{label, value, "linha"}; };
    const LogCacaRow gap{"", "", "vao"};

    model.rows = {
        line("Tempo de caça", LogHms(seconds)),
        gap,
        line("Dano por minuto", LogThousands(static_cast<long long>(g_Hunt.damage / minutes))),
        line("Zen por minuto", LogThousands(static_cast<long long>(g_Hunt.zen / minutes))),
        line("Último zen", LogThousands(g_Hunt.lastZen)),
        gap,
        line("Subiu de nível", std::to_string(g_Hunt.levels)),
        line("Exp por minuto", LogThousands(expPerMinute)),
        line("Exp por monstro", LogThousands(g_Hunt.exp / std::max(1, g_Hunt.kills))),
        line("Última exp", LogThousands(g_Hunt.lastExp)),
        line("Próximo nível em", expPerMinute > 0 && g_Hunt.toNext > 0 ? LogHms(g_Hunt.toNext * 60 / expPerMinute) : "--:--:--"),
    };
    if (g_Hunt.dummyHits > 0)
    {
        const double dummySeconds = std::max(1.0, static_cast<double>(g_Hunt.dummyEnd - g_Hunt.dummyFirst) / 1000.0);
        model.rows.push_back(gap);
        model.rows.push_back(LogCacaRow{"Boneco de Treino", "", "titulo"});
        model.rows.push_back(line("Golpes", LogThousands(g_Hunt.dummyHits)));
        model.rows.push_back(line("Dano total", LogThousands(g_Hunt.dummyTotal)));
        model.rows.push_back(line("Último golpe", LogThousands(g_Hunt.dummyLast)));
        model.rows.push_back(line("Maior golpe", LogThousands(g_Hunt.dummyMax)));
        model.rows.push_back(line("Média por golpe", LogThousands(g_Hunt.dummyTotal / g_Hunt.dummyHits)));
        model.rows.push_back(line("Dano por segundo", LogThousands(static_cast<long long>(g_Hunt.dummyTotal / dummySeconds))));
    }
    m_RmlView.MarkDirty("rows");
    // a altura mudou (o boneco entrou): confere se ainda cabe na tela
    m_Placed = false;
}

float CLogCacaWindow::GetLayerDepth()
{
    return 1.05f;
}

float CLogCacaWindow::GetKeyEventOrder()
{
    return 1.f;
}
