#include "stdafx.h"
#include "UI/Estudo/RastreioMissoesWindow.h"
#include "UI/Estudo/QuestsMainWindow.h"
#include "UI/Core/WindowSystem.h"
#include "Audio/DSPlaySound.h"
#include "Data/GameConfig/GameConfig.h"
#include "Engine/Object/ZzzCharacter.h"
#include "Scenes/SceneCore.h"
#include "UI/RmlBridge/RmlDocumentVisibility.h"
#include "UI/RmlBridge/RmlPointer.h"

#include <RmlUi/Core/DataModelHandle.h>
#include <RmlUi/Core/Element.h>
#include <RmlUi/Core/ElementDocument.h>
#include <RmlUi/Core/Event.h>

#include <algorithm>
#include <cmath>
#include <filesystem>
#include <fstream>

using namespace mu::ui::window;

namespace
{
constexpr float PanelWidth = 128.f;
constexpr float CornerX = 640.f - PanelWidth - 4.f; // a borda direita, como no Godot
constexpr float CornerY = 118.f;
constexpr const char* PlaceFile = "rastreio_missoes.ini";

std::string RastreioPx(float v)
{
    return std::to_string(static_cast<int>(std::lround(v))) + "px";
}

std::filesystem::path RastreioPlacePath()
{
    return GameConfig::GetInstance().GetConfigPath().parent_path() / PlaceFile;
}
} // namespace

CRastreioMissoesWindow::CRastreioMissoesWindow() = default;

CRastreioMissoesWindow::~CRastreioMissoesWindow()
{
    Release();
}

bool CRastreioMissoesWindow::Create(CManager* pNewUIMng)
{
    if (pNewUIMng == nullptr)
        return false;
    m_pNewUIMng = pNewUIMng;
    m_pNewUIMng->AddUIObj(INTERFACE_RASTREIO_MISSOES, this);
    m_RmlView.Ensure();
    LoadPlace();
    Show(true); // fica sempre ligado: aparece sozinho quando tem missao ativa
    return true;
}

void CRastreioMissoesWindow::Release()
{
    if (m_pNewUIMng)
    {
        m_pNewUIMng->RemoveUIObj(this);
        m_pNewUIMng = nullptr;
    }
    m_RmlView.Release();
}

bool CRastreioMissoesWindow::UpdateMouseEvent()
{
    // So segura o mouse em cima do painel; fora dele o clique vai pro jogo.
    const bool inGame = SceneFlag == MAIN_SCENE && Hero != nullptr;
    return !(inGame && m_HasRows && UI::RmlBridge::IsPointerOver(m_RmlView.Document()));
}

bool CRastreioMissoesWindow::UpdateKeyEvent()
{
    return true;
}

bool CRastreioMissoesWindow::Update()
{
    const bool inGame = SceneFlag == MAIN_SCENE && Hero != nullptr;
    if (!IsVisible())
        CObject::Show(true); // um "esconder tudo" nao tira o rastreio (sem ele o arrastar nao chega)
    if (m_Open)
    {
        m_Open = false;
        CQuestsMainWindow::OpenList();
        PlayBuffer(SOUND_CLICK01);
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
    if (inGame && m_SeenVersion != CQuestsMainWindow::Version())
    {
        m_SeenVersion = CQuestsMainWindow::Version();
        Rebuild();
    }
    UI::RmlBridge::SyncDocumentVisibility(document, inGame && m_HasRows);
    if (!inGame || !m_HasRows)
        return true;

    if (!m_Placed)
        Place();
    if (m_Save)
    {
        m_Save = false;
        SavePlace();
    }
    return true;
}

bool CRastreioMissoesWindow::Render()
{
    return true;
}

void CRastreioMissoesWindow::Rebuild()
{
    RastreioRmlModel& model = m_RmlView.GetModel();
    model.rows.clear();
    for (int id : CQuestsMainWindow::ActiveChains())
    {
        const QuestMainState s = CQuestsMainWindow::StateOf(id);
        const QuestMainQuest* q = CQuestsMainWindow::FindQuest(id, s.active);
        if (q == nullptr)
            continue;
        RastreioRow row;
        row.ready = s.kills >= q->amount;
        row.name = q->name;
        row.label = row.ready ? std::string("Entregar no Zoak") : q->monster;
        row.count = CQuestsMainWindow::Thousands(s.kills) + "/" + CQuestsMainWindow::Thousands(q->amount);
        row.bar = std::to_string(q->amount > 0 ? std::clamp(s.kills * 100 / q->amount, 0, 100) : 0) + "%";
        model.rows.push_back(row);
    }
    m_HasRows = !model.rows.empty();
    m_RmlView.MarkDirty("rows");
    // a altura mudou: confere se ainda cabe na tela
    m_Placed = false;
}

// põe o painel no canto mais o deslocamento, sem sair da tela
void CRastreioMissoesWindow::Place()
{
    m_Placed = true;
    RastreioRmlModel& model = m_RmlView.GetModel();
    float height = 14.f + 28.f * static_cast<float>(model.rows.size());
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
    model.left = RastreioPx(x);
    model.top = RastreioPx(y);
    m_RmlView.MarkDirty("left");
    m_RmlView.MarkDirty("top");
}

void CRastreioMissoesWindow::LoadPlace()
{
    std::ifstream file(RastreioPlacePath());
    float x = 0.f;
    float y = 0.f;
    if (file >> x >> y)
    {
        m_OffsetX = x;
        m_OffsetY = y;
    }
    m_Placed = false;
}

void CRastreioMissoesWindow::SavePlace() const
{
    std::ofstream file(RastreioPlacePath(), std::ios::trunc);
    if (file)
        file << m_OffsetX << ' ' << m_OffsetY << '\n';
}

void CRastreioMissoesWindow::BindRmlModel(Rml::DataModelConstructor& c, RastreioRmlModel& model)
{
    auto row = c.RegisterStruct<RastreioRow>();
    row.RegisterMember("name", &RastreioRow::name);
    row.RegisterMember("label", &RastreioRow::label);
    row.RegisterMember("count", &RastreioRow::count);
    row.RegisterMember("bar", &RastreioRow::bar);
    row.RegisterMember("ready", &RastreioRow::ready);
    c.RegisterArray<std::vector<RastreioRow>>();
    c.Bind("rows", &model.rows);
    c.Bind("left", &model.left);
    c.Bind("top", &model.top);

    // o arrastar vem do RmlUi (drag: drag no #panel), com o ponteiro em px da janela
    c.BindEventCallback("rm_drag_start",
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
    c.BindEventCallback("rm_drag",
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
    c.BindEventCallback("rm_drag_end",
        [this](Rml::DataModelHandle, Rml::Event&, const Rml::VariantList&)
        {
            if (m_Moved)
                m_Save = true;
        });
    c.BindEventCallback("rm_mouse_down",
        [this](Rml::DataModelHandle, Rml::Event& event, const Rml::VariantList&)
        {
            if (event.GetParameter<int>("button", 0) == 1)
                m_Home = true; // botão direito: volta pro canto
        });
    c.BindEventCallback("rm_click",
        [this](Rml::DataModelHandle, Rml::Event&, const Rml::VariantList&)
        {
            if (!m_Moved)
                m_Open = true; // clique sem arrastar: abre as Missões
            m_Moved = false;
        });
}

float CRastreioMissoesWindow::GetLayerDepth()
{
    return 1.05f;
}

float CRastreioMissoesWindow::GetKeyEventOrder()
{
    return 1.f;
}
