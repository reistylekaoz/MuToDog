#include "stdafx.h"
#include "UI/Estudo/NomesNpcWindow.h"
#include "UI/Estudo/IconesNpc.h"
#include "Camera/CameraProjection.h"
#include "Camera/CameraState.h"
#include "Engine/Object/ZzzCharacter.h"
#include "Engine/Object/ZzzInterface.h"
#include "Scenes/SceneCore.h"
#include "UI/RmlBridge/RmlDocumentVisibility.h"
#include "UI/Scaling/UITransform.h"
#include "Core/Utilities/StringUtils.h"

#include <RmlUi/Core/DataModelHandle.h>
#include <RmlUi/Core/ElementDocument.h>

#include <array>
#include <cmath>
#include <string>

using namespace mu::ui::window;

namespace
{
// tipo do ícone por personagem, guardado pelo número do monstro (o nome não muda com o mesmo número)
std::array<std::string, MAX_CHARACTERS_CLIENT> g_Tipo;
std::array<int, MAX_CHARACTERS_CLIENT> g_TipoDe{};
std::array<bool, MAX_CHARACTERS_CLIENT> g_Desenha{};

std::string NpcPx(float v)
{
    return std::to_string(static_cast<int>(std::lround(v))) + "px";
}

const std::string& TipoDe(int i)
{
    const CHARACTER* c = &CharactersClient[i];
    const int numero = static_cast<int>(c->MonsterIndex);
    if (g_TipoDe[i] != numero + 1)
    {
        g_TipoDe[i] = numero + 1;
        g_Tipo[i] = IconesNpc::Tipo(c->ID, numero);
    }
    return g_Tipo[i];
}
} // namespace

CNomesNpcWindow::CNomesNpcWindow() = default;

CNomesNpcWindow::~CNomesNpcWindow()
{
    Release();
}

bool CNomesNpcWindow::Create(CManager* pNewUIMng)
{
    if (pNewUIMng == nullptr)
        return false;
    m_pNewUIMng = pNewUIMng;
    m_pNewUIMng->AddUIObj(INTERFACE_NOMES_NPC, this);
    m_RmlView.Ensure();
    Show(true);
    return true;
}

void CNomesNpcWindow::Release()
{
    if (m_pNewUIMng)
    {
        m_pNewUIMng->RemoveUIObj(this);
        m_pNewUIMng = nullptr;
    }
    m_RmlView.Release();
}

bool CNomesNpcWindow::UpdateMouseEvent()
{
    return true; // só desenha: o clique passa pro NPC
}

bool CNomesNpcWindow::UpdateKeyEvent()
{
    return true;
}

bool CNomesNpcWindow::Update()
{
    if (!IsVisible())
        CObject::Show(true); // um "esconder tudo" não tira os nomes
    return true;
}

bool CNomesNpcWindow::Render()
{
    return true;
}

bool CNomesNpcWindow::Draws(int characterIndex)
{
    return characterIndex >= 0 && characterIndex < MAX_CHARACTERS_CLIENT && g_Desenha[characterIndex];
}

// com a câmera e a seleção deste quadro, antes das janelas desenharem (como o NameWindow)
void CNomesNpcWindow::PrepareFrame()
{
    m_RmlView.Ensure();
    Rml::ElementDocument* document = m_RmlView.Document();
    const bool inGame = SceneFlag == MAIN_SCENE && Hero != nullptr && g_Camera.TopViewEnable == false;
    std::vector<NomeNpcRow> rows;
    g_Desenha.fill(false);
    if (inGame)
    {
        const float scale = UI::Scaling::TypographyScale(static_cast<int>(WindowWidth), static_cast<int>(WindowHeight));
        for (int i = 0; i < MAX_CHARACTERS_CLIENT; i++)
        {
            const CHARACTER* c = &CharactersClient[i];
            const OBJECT* o = &c->Object;
            if (!o->Live || !o->Visible || o->Kind != KIND_NPC || o->Alpha <= 0.f)
                continue;
            const std::string& tipo = TipoDe(i);
            if (tipo.empty() || tipo == "guarda")
                continue; // objeto do mapa e guarda: como antes
            vec3_t pos;
            Vector(o->Position[0], o->Position[1], o->Position[2] + o->BoundingBoxMax[2] + 30.f, pos);
            float x = 0.f;
            float y = 0.f;
            if (!CameraProjection::WorldToWindowPixel(g_Camera, pos, &x, &y))
                continue;
            if (x < -100.f || y < -100.f || x > WindowWidth + 100.f || y > WindowHeight + 100.f)
                continue;
            g_Desenha[i] = true;
            NomeNpcRow row;
            row.name = StringUtils::WideToNarrow(c->ID);
            const std::string icone = IconesNpc::Agora(tipo);
            row.icon = IconesNpc::Source(icone);
            row.pulse = icone == "quest_nova" || icone == "quest_pronta";
            row.hot = SelectedNpc == i;
            row.left = NpcPx(x);
            row.top = NpcPx(y);
            rows.push_back(std::move(row));
        }
        NomesNpcRmlModel& model = m_RmlView.GetModel();
        const std::string font = NpcPx(9.f * scale);
        const std::string icon = NpcPx(24.f * scale);
        if (model.fontSize != font || model.iconSize != icon)
        {
            model.fontSize = font;
            model.iconSize = icon;
            m_RmlView.MarkDirty("font_size");
            m_RmlView.MarkDirty("icon_size");
        }
    }
    NomesNpcRmlModel& model = m_RmlView.GetModel();
    if (model.rows != rows)
    {
        model.rows = std::move(rows);
        m_RmlView.MarkDirty("rows");
    }
    if (document != nullptr)
        UI::RmlBridge::SyncDocumentVisibility(document, inGame && !model.rows.empty());
}

void CNomesNpcWindow::BindRmlModel(Rml::DataModelConstructor& c, NomesNpcRmlModel& model)
{
    auto row = c.RegisterStruct<NomeNpcRow>();
    row.RegisterMember("name", &NomeNpcRow::name);
    row.RegisterMember("icon", &NomeNpcRow::icon);
    row.RegisterMember("left", &NomeNpcRow::left);
    row.RegisterMember("top", &NomeNpcRow::top);
    row.RegisterMember("pulse", &NomeNpcRow::pulse);
    row.RegisterMember("hot", &NomeNpcRow::hot);
    c.RegisterArray<std::vector<NomeNpcRow>>();
    c.Bind("rows", &model.rows);
    c.Bind("font_size", &model.fontSize);
    c.Bind("icon_size", &model.iconSize);
}

float CNomesNpcWindow::GetLayerDepth()
{
    return 1.02f;
}
