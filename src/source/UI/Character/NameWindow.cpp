
#include "stdafx.h"
#include "UI/Scaling/UITransform.h"
#include "UI/Chat/Chat.h"
#include "UI/Character/NameWindow.h"
#include "Render/Models/ZzzBMD.h"
#include "Engine/Object/ZzzObject.h"
#include "Engine/Object/ZzzCharacter.h"
#include "Engine/Object/ZzzInterface.h"
#include "Engine/Object/ZzzInventory.h"
#include "GameLogic/Events/CSChaosCastle.h"
#include "GameLogic/Items/PersonalShopTitleImp.h"
#include "GameLogic/Events/MatchEvent.h"
#include "World/MapInfra/MapManager.h"
#include "Camera/CameraProjection.h"
#include "Camera/CameraState.h"
#include "UI/Combat/MonsterHealthBar.h"
#include "UI/HUD/HudStatus.h"
#include "World/GameMaps/GMBattleCastle.h"
#include "World/GameMaps/GMHellas.h"
#include "World/GameMaps/GM_Kanturu_3rd.h"
#include "Render/Text/CUIRenderText.h"
#include "UI/Estudo/NomesNpcWindow.h"
#include "UI/Estudo/BossBarWindow.h"

#include <algorithm>
#include <chrono>
#include <cmath>

// DevEditor forward declarations (must be at global scope)
#ifdef _EDITOR
extern "C" bool DevEditor_ShouldRenderItemLabels();
#endif

using namespace SEASON3B;
using namespace mu::ui::window;

namespace
{

// Draws a segmented monster HP bar centered on centerX/topY; steps sets segment count, scale compresses width.
void DrawHealthBar(int centerX, int topY, float health, int steps, float scale)
{
    const float borderHeight = 2.f;                  // vertical inset (unscaled)
    const float borderWidth = 2.f * scale;           // horizontal inset
    const float stepSeparatorWidth = 1.f * scale;    // gap between segments
    const float segmentSpan = 80.f * scale;          // total span of the segment track
    const float widthPerStep = segmentSpan / steps;  // derived: fewer steps -> wider segments
    const float stepsWidth = segmentSpan - 2.f * stepSeparatorWidth;
    const float totalWidth = stepsWidth + borderWidth * 2.f;

    const int x = centerX - (int)(totalWidth / 2);
    const int y = topY;

    // Drop shadow.
    EnableAlphaTest();
    RenderColorQuadARGB((float)(x + 1), (float)(y + 1), totalWidth, 5.f, 0x80000000u);

    // Dark backing.
    EnableAlphaBlend();
    RenderColorQuadARGB((float)x, (float)y, totalWidth, 5.f, 0xFF330000u);

    // Inner track.
    RenderColorQuadARGB((float)(x + borderWidth), (float)(y + borderHeight), stepsWidth, 1.f,
        0xFF320A00u);

    // HealthStatus < 0 is the "unknown HP" sentinel; render a full bar for it instead of empty.
    const float clampedHealth = (health < 0.f) ? 1.f : health;
    const int stepHP = (int)(clampedHealth * steps);

    // Filled health segments.
    for (int k = 0; k < stepHP; ++k)
    {
        RenderColorQuadARGB(
            (float)(x + borderWidth + (k * widthPerStep)),
            (float)(y + borderHeight),
            widthPerStep - stepSeparatorWidth,
            2.f,
            0xFFFA0A00u);
    }
    DisableAlphaBlend();
}

// MuToDog (MU Estudo): a barra de vida na cabeça no jeito do cliente Godot (textos_mu.gd _vida): 68 x 7 px numa tela
// de 720 de altura, contorno preto, fundo vinho, a vida vermelha com o brilho no terço de cima e o rastro claro do
// dano descendo 0,6 da barra por segundo. Desenhada na tela de referência esticada (640 x 480), por isso a conta em px.
void DrawHeadHealthBar(float centerX, float bottomY, float health, float trail)
{
    const float pxX = 640.f / std::max(1.f, static_cast<float>(WindowWidth));  // 1 px da tela em unidades
    const float pxY = 480.f / std::max(1.f, static_cast<float>(WindowHeight));
    const float k = static_cast<float>(WindowHeight) / 720.f;
    const float w = std::round(68.f * k) * pxX;
    const float h = std::max(std::round(7.f * k), 4.f) * pxY;
    const float x = centerX - w / 2.f;
    const float y = bottomY - h;

    EnableAlphaTest();
    RenderColorQuadARGB(x - pxX, y - pxY, w + 2.f * pxX, h + 2.f * pxY, 0xBF000000u);
    RenderColorQuadARGB(x, y, w, h, 0xE6290808u);
    const float ix = x + pxX, iy = y + pxY, iw = w - 2.f * pxX, ih = h - 2.f * pxY;
    if (trail > health)
        RenderColorQuadARGB(ix + iw * health, iy, iw * (trail - health), ih, 0xD9FFD999u);
    if (health > 0.f)
    {
        RenderColorQuadARGB(ix, iy, iw * health, ih, 0xFFC7120Du);
        RenderColorQuadARGB(ix, iy, iw * health, std::ceil(ih / pxY * 0.4f) * pxY, 0x8CFF614Du);
    }
}
}

//////////////////////////////////////////////////////////////////////
// Construction/Destruction
//////////////////////////////////////////////////////////////////////

mu::ui::window::CNameWindow::CNameWindow()
{
    m_pNewUIMng = NULL;

    m_bShowItemName = false;
    m_bShowMonsterHealthBar = true; // MuToDog: a barra na cabeça já vem ligada, como no Godot (F8 esconde)
}

mu::ui::window::CNameWindow::~CNameWindow()
{
    Release();
}

bool mu::ui::window::CNameWindow::Create(CManager* pNewUIMng)
{
    if (NULL == pNewUIMng)
        return false;

    m_pNewUIMng = pNewUIMng;
    m_pNewUIMng->AddUIObj(mu::ui::window::INTERFACE_NAME_WINDOW, this);

    m_labelLayer.Create();

    Show(true);

    return true;
}

void mu::ui::window::CNameWindow::Release()
{
    m_labelLayer.Release();
    m_statusTexts.Release();
    m_matchStatus.Release();

    if (m_pNewUIMng)
    {
        m_pNewUIMng->RemoveUIObj(this);
        m_pNewUIMng = NULL;
    }
}

bool mu::ui::window::CNameWindow::UpdateMouseEvent()
{
    return true;
}

bool mu::ui::window::CNameWindow::UpdateKeyEvent()
{
    if (mu::ui::window::IsPress(VK_MENU) == true)
    {
        m_bShowItemName = !m_bShowItemName;
    }

    if (mu::ui::window::IsPress(VK_F8) == true)
    {
        m_bShowMonsterHealthBar = !m_bShowMonsterHealthBar;
    }

    return true;
}

bool mu::ui::window::CNameWindow::Update()
{
    RefreshNameTags();
    return true;
}

// The chat shows the selected NPC's or player's name (every player's, for a GM observing) while this keeps its tag.
void mu::ui::window::CNameWindow::RefreshNameTags()
{
    if (g_bGMObservation == true)
    {
        for (int i = 0; i < MAX_CHARACTERS_CLIENT; i++)
        {
            CHARACTER* c = &CharactersClient[i];
            if (c->Object.Live && c->Object.Kind == KIND_PLAYER && IsShopTitleVisible(c) == false)
            {
                UI::Chat::CreateChat(c->ID, L"", c);
            }
        }
    }

#ifndef GUILD_WAR_EVENT
    if (gMapManager.InChaosCastle() == true && (SelectedNpc != -1 || SelectedCharacter != -1))
    {
        return;
    }
#endif // GUILD_WAR_EVENT

    if (SelectedItem != -1 || SelectedNpc != -1 || SelectedCharacter != -1)
    {
        if (SelectedNpc != -1)
        {
            // MuToDog: o NPC com nome e ícone sempre à mostra (NomesNpcWindow) não ganha a etiqueta em dobro
            CHARACTER* c = &CharactersClient[SelectedNpc];
            if (!CNomesNpcWindow::Draws(SelectedNpc))
                UI::Chat::CreateChat(c->ID, L"", c);
        }
        else if (SelectedCharacter != -1)
        {
            CHARACTER* c = &CharactersClient[SelectedCharacter];
            if (c->Object.Kind != KIND_MONSTER
#ifdef ASG_ADD_GENS_SYSTEM
#ifndef PBG_MOD_STRIFE_GENSMARKRENDER
                && (!::IsStrifeMap(World) || Hero->m_byGensInfluence == c->m_byGensInfluence)
#endif // PBG_MOD_STRIFE_GENSMARKRENDER
#endif // ASG_ADD_GENS_SYSTEM
                && IsShopTitleVisible(c) == false)
            {
                UI::Chat::CreateChat(c->ID, L"", c);
            }
        }
    }
}

void mu::ui::window::CNameWindow::Show(bool bShow)
{
    CObject::Show(bShow);
    if (!bShow)
    {
        m_labelLayer.Hide();
        m_statusTexts.Hide();
        m_matchStatus.Hide();
    }
}

void mu::ui::window::CNameWindow::PrepareFrame()
{
    m_statusTexts.Sync(IsVisible(), g_Camera.TopViewEnable == false);
    m_matchStatus.Sync(IsVisible());

    // Recorded before the windows render, with this frame's camera and selection; the document
    // sits under every window, as the original's depth-1.0 window did.
    if (!m_labelLayer.Create())
        return;

    m_labelLayer.BeginFrame();
    {
        // Everything here stands over the world, in the original's screen stretched over the window.
        const UI::Scaling::ScopedScreenStretch screen(static_cast<int>(WindowWidth), static_cast<int>(WindowHeight));
        Render::Renderer::Overlay2DRecordScope record(&m_labelLayer);
        // The main scene's overlays first, in its order: the original drew the Kalima object
        // labels and then RenderInterface()'s overlays (top view off only) before this window's
        // labels.
        RenderObjectDescription();
        if (g_Camera.TopViewEnable == false)
        {
            RenderPartyHP();
            battleCastle::RenderBuildTimes();
            M39Kanturu3rd::RenderKanturu3rdinterface();
        }
        RenderLabels();
    }
    m_labelLayer.EndFrame();
}

bool mu::ui::window::CNameWindow::RecordsInterfaceOverlays() const
{
    return IsVisible() && m_labelLayer.IsAvailable();
}

bool mu::ui::window::CNameWindow::Render()
{
    if (!m_labelLayer.IsAvailable())
        RenderLabels();
    return true;
}

void mu::ui::window::CNameWindow::RenderLabels()
{
    // Names and bars stand over the characters, in the original's screen stretched over the window.
    const UI::Scaling::ScopedScreenStretch screen(static_cast<int>(WindowWidth), static_cast<int>(WindowHeight));
    EnableAlphaTest();
    RenderName();
    matchEvent::RenderMatchTimes();
    UI::Chat::RenderBooleans();
    RenderMonsterHealthBars();
    DrawPersonalShopTitleImp();
    DisableAlphaBlend();
}

void mu::ui::window::CNameWindow::RenderName()
{
#ifndef GUILD_WAR_EVENT
    if (gMapManager.InChaosCastle() == true && (SelectedNpc != -1 || SelectedCharacter != -1))
    {
        return;
    }
#endif//GUILD_WAR_EVENT

    // The selected NPC's and player's names are chat tags (RefreshNameTags); a monster's is drawn here.
    if (SelectedNpc == -1 && SelectedCharacter != -1)
    {
        const CHARACTER* c = &CharactersClient[SelectedCharacter];
        if (c->Object.Kind == KIND_MONSTER)
        {
            g_pRenderText->SetTextColor(255, 230, 200, 255);
            g_pRenderText->SetBgColor(100, 0, 0, 255);
            g_pRenderText->RenderText(320, 2, c->ID, 0, 0, RT3_WRITE_CENTER);

            if (UI::Combat::HealthBar::ShouldRenderSelected(c->HealthStatus))
            {
                // Full-width bar centered under the selected monster's name.
                DrawHealthBar(320, 15, c->HealthStatus, 20, 1.f);
            }
        }
    }
    else if (SelectedNpc == -1 && SelectedItem != -1)
    {
#ifdef _EDITOR
        if (DevEditor_ShouldRenderItemLabels())
#endif
            RenderItemName(SelectedItem, &Items[SelectedItem].Object, &Items[SelectedItem].Item, false);
    }

    if (m_bShowItemName || mu::ui::window::IsRepeat(VK_MENU))
    {
#ifdef _EDITOR
        bool renderLabels = DevEditor_ShouldRenderItemLabels();
#else
        bool renderLabels = true;
#endif

        if (renderLabels)
        {
            for (int i = 0; i < MAX_ITEMS; i++)
            {
                const OBJECT* o = &Items[i].Object;
                if (o->Live)
                {
                    if (o->Visible && i != SelectedItem)
                    {
                        RenderItemName(i, o, &Items[i].Item, true);
                    }
                }
            }
        }
    }
}

void mu::ui::window::CNameWindow::RenderMonsterHealthBars()
{
    if (!m_bShowMonsterHealthBar)
        return;

    // o rastro claro de cada monstro (Key pra saber quando a casa trocou de monstro)
    static float s_Trail[MAX_CHARACTERS_CLIENT];
    static int s_TrailKey[MAX_CHARACTERS_CLIENT];
    static bool s_Started = false;
    if (!s_Started)
    {
        std::fill(std::begin(s_TrailKey), std::end(s_TrailKey), -1);
        s_Started = true;
    }
    using Clock = std::chrono::steady_clock;
    static Clock::time_point s_Last = Clock::now();
    const Clock::time_point now = Clock::now();
    const float dt = std::clamp(std::chrono::duration<float>(now - s_Last).count(), 0.f, 0.25f);
    s_Last = now;

    const int bossId = CBossBarWindow::ShownId();
    for (int i = 0; i < MAX_CHARACTERS_CLIENT; i++)
    {
        const CHARACTER* c = &CharactersClient[i];
        const OBJECT* o = &c->Object;

        if (!o->Live || !o->Visible || o->Alpha <= 0.f || c->Dead > 0 || o->Kind != KIND_MONSTER)
            continue;
        // o boss com a barra do topo não ganha outra na cabeça (Godot: _barra_na_cabeca)
        if (bossId >= 0 && c->Key == bossId)
            continue;

        // HealthStatus vem do servidor a cada golpe (1/250 da vida); -1 = ainda não apanhou, barra cheia
        const float health = c->HealthStatus < 0.f ? 1.f : std::clamp(c->HealthStatus, 0.f, 1.f);
        if (s_TrailKey[i] != c->Key)
        {
            s_TrailKey[i] = c->Key;
            s_Trail[i] = health;
        }
        s_Trail[i] = std::max(health, s_Trail[i] - dt * 0.6f);

        // 35 cm acima da cabeça, como o Godot (altura + 0,35)
        vec3_t Position;
        Vector(o->Position[0], o->Position[1], o->Position[2] + o->BoundingBoxMax[2] + 35.f, Position);

        int ScreenX, ScreenY;
        vec3_t transformPos;
        VectorTransform(Position, g_Camera.Matrix, transformPos);
        if (transformPos[2] >= 0)
            continue;

        CameraProjection::WorldToScreen(g_Camera, Position, &ScreenX, &ScreenY);

        if (ScreenX < -100 || ScreenY < -100
            || ScreenX > (REFERENCE_WIDTH + 100)
            || ScreenY > (REFERENCE_HEIGHT + 100))
            continue;

        DrawHeadHealthBar(static_cast<float>(ScreenX), static_cast<float>(ScreenY), health, s_Trail[i]);
    }
    DisableAlphaBlend();
}

float mu::ui::window::CNameWindow::GetLayerDepth()
{
    return 1.0f;
}
