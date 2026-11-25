
#include "stdafx.h"
#include "Core/Content/ContentStore.h"
#include "Data/DataHandler/DataFileIO.h"
#include "UI/Placement/WindowPlacement.h"
#include "I18N/All.h"

#include "UI/HUD/MiniMap.h"
#include "UI/Core/WindowSystem.h"
#include "UI/Dialogs/CommonMessageBox.h"
#include "UI/Dialogs/CustomMessageBox.h"
#include "Audio/DSPlaySound.h"

#include "Guild/GuildInfoWindow.h"
#include "UI/Inventory/MyInventory.h"
#include "GameLogic/Items/CSItemOption.h"
#include "World/MapInfra/MapManager.h"

#include "Core/Utilities/StringUtils.h"
#include "Render/RmlUi/RmlUiRuntime.h"
#include "UI/HUD/MiniMapLayout.h"
#include "UI/RmlBridge/RmlDocumentVisibility.h"
#include "UI/RmlBridge/RmlNativeTextSize.h"
#include "UI/RmlBridge/RmlTheme.h"
#include "Render/Text/CUIRenderText.h"
#include "UI/Estudo/IconesNpc.h"
#include "UI/Estudo/DungeonEtapasWindow.h"
#include "UI/Estudo/AndarMinimapa.h"
#include "Engine/Object/ZzzCharacter.h"
#include "Engine/Object/ZzzInfomation.h"
#include "json.hpp"

#include <RmlUi/Core/ElementDocument.h>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cwchar>
#include <fstream>
#include <map>
#include <string>
#include <vector>

extern BYTE m_OccupationState;

using namespace SEASON3B;
using namespace mu::ui::window;

namespace
{
// The part of the screen the original's mouse handler kept to itself.
constexpr int kMapAreaHeight = 430;
// Marker sizes, physical px (the original never scaled them).
constexpr float kNpcSize = 15.f;
constexpr float kPortalSize = 30.f;
// MuToDog: o NPC com ícone (IconesNpc), no mínimo
constexpr float kNpcIconSize = 24.f;
// The side border tiles: 35 x 6 reference units, 20 down each side, turned a quarter.
constexpr float kTileWidth = 35.f;
constexpr float kTileHeight = 6.f;
constexpr int kSideTiles = 20;
// .edge-side's element size in mini_map.rcss (the tile's texel rectangle).
constexpr float kSideElementWidth = 41.7f;
constexpr float kSideElementHeight = 8.f;

template <typename Model, typename T>
void Sync(RmlModelBinder<Model>& binder, T Model::* field, const char* name, T value)
{
    Model& model = binder.GetModel();
    if (model.*field == value)
        return;
    model.*field = std::move(value);
    binder.MarkDirty(name);
}

Rml::String MatrixText(const UI::MiniMap::CssMatrix& m)
{
    char buffer[192];
    std::snprintf(buffer, sizeof(buffer), "matrix(%.5f, %.5f, %.5f, %.5f, %.3f, %.3f)", m.a, m.b, m.c, m.d, m.e, m.f);
    return buffer;
}

// The original drew the map under the screen overlay's W/640 x H/480 stretch.
UI::Scaling::Transform OverlayTransform()
{
    return UI::Scaling::ScreenOverlayTransform(static_cast<int>(WindowWidth), static_cast<int>(WindowHeight));
}

UI::MiniMap::Screen CurrentScreen()
{
    const UI::Scaling::Transform transform = OverlayTransform();
    return {static_cast<float>(WindowWidth),
            static_cast<float>(WindowHeight),
            transform.scaleX,
            transform.scaleY,
            transform.offsetX,
            transform.offsetY};
}

// MuToDog: a casa do mapa debaixo do ponteiro (px da janela), o contrário do MapQuad. As marcas (e a seta do herói)
// saem 25 px à direita do mapa desde o original (kMarkerShift do MiniMapLayout.cpp) e é nelas que a pessoa mira,
// então o clique volta esses 25 px antes da conta.
bool TileUnderPointer(float windowX, float windowY, int& tileX, int& tileY)
{
    if (Hero == nullptr)
        return false;
    const float length = UI::MiniMap::MapLength;
    const float heroY = (static_cast<float>(Hero->PositionX) / 256.f) * length;
    const float heroX = (static_cast<float>(Hero->PositionY) / 256.f) * length;
    const UI::MiniMap::Quad q = UI::MiniMap::MapQuad(CurrentScreen(), heroX, heroY, length, UI::MiniMap::MapRotation);
    const float ux = q.topRight.x - q.topLeft.x, uy = q.topRight.y - q.topLeft.y;
    const float vx = q.bottomLeft.x - q.topLeft.x, vy = q.bottomLeft.y - q.topLeft.y;
    const float det = ux * vy - uy * vx;
    if (std::abs(det) < 1e-6f)
        return false;
    const float px = windowX - 25.f - q.topLeft.x, py = windowY - q.topLeft.y;
    const float u = (px * vy - py * vx) / det; // 0..1 na largura do mapa = o Y da casa
    const float v = (ux * py - uy * px) / det; // 0..1 na altura do mapa = o X da casa
    if (u < 0.f || v < 0.f || u >= 1.f || v >= 1.f)
        return false;
    tileX = static_cast<int>(v * 256.f);
    tileY = static_cast<int>(u * 256.f);
    return true;
}

// MuToDog (25/11): os spots de monstro do OpenMU no minimapa, como no cliente Godot (minimapa.gd, 08/11): um círculo
// por spot na cor do nível perto do meu, sem texto; com o mouse em cima ele acende e a dica diz o monstro, o nível e
// quantos tem. Dados: dados/spots_minimapa.json, mapa -> [x1, y1, x2, y2, [[nome, nível, quantos], ...]], o mesmo
// do Godot (ferramentas/dados_minimapa.py no mu-online).
struct Spot
{
    float cx = 0.f, cy = 0.f; // o centro em casas
    float tiles = 3.5f;       // o raio em casas
    int level = 0;            // o nível do último monstro da lista (a cor)
    std::string text;
};

struct SpotHit
{
    float x = 0.f, y = 0.f, radius = 0.f; // px da janela
    const Spot* spot = nullptr;
};

const std::vector<Spot>& SpotsOf(int world)
{
    static std::map<int, std::vector<Spot>> s_spots;
    static bool s_loaded = false;
    if (!s_loaded)
    {
        s_loaded = true;
        std::ifstream file("Data/Interface/RmlUi/dados/spots_minimapa.json");
        const nlohmann::json j = file ? nlohmann::json::parse(file, nullptr, false) : nlohmann::json();
        if (j.is_object())
        {
            for (auto it = j.begin(); it != j.end(); ++it)
            {
                std::vector<Spot>& list = s_spots[std::atoi(it.key().c_str())];
                for (const auto& e : it.value())
                {
                    if (!e.is_array() || e.size() < 5 || !e[4].is_array() || e[4].empty())
                        continue;
                    const int x1 = e[0].get<int>(), y1 = e[1].get<int>(), x2 = e[2].get<int>(), y2 = e[3].get<int>();
                    Spot spot;
                    // o spot de 6 (5 x 5 casas) dá um círculo de 3,5 casas; área grande fica com o que cabe nela
                    spot.cx = (x1 + x2 + 1) / 2.f;
                    spot.cy = (y1 + y2 + 1) / 2.f;
                    spot.tiles = std::max(3.5f, std::min(x2 - x1 + 1, y2 - y1 + 1) / 2.f);
                    for (const auto& m : e[4])
                    {
                        if (!m.is_array() || m.size() < 3)
                            continue;
                        if (!spot.text.empty())
                            spot.text += "  /  ";
                        spot.text += m[0].get<std::string>() + " · nível " + std::to_string(m[1].get<int>()) + " · " +
                                     std::to_string(m[2].get<int>()) + " monstros";
                        spot.level = m[1].get<int>();
                    }
                    list.push_back(std::move(spot));
                }
            }
        }
    }
    static const std::vector<Spot> s_none;
    const auto found = s_spots.find(world);
    return found != s_spots.end() ? found->second : s_none;
}

// o que está desenhado agora, pra dica (SyncHint)
std::vector<SpotHit> s_SpotHits;

// a cor pelo nível perto do meu (Godot _cor_nivel): vermelho acima de +10, amarelo de -5 a +10, verde abaixo
int SpotColor(int level)
{
    const int mine = CharacterAttribute != nullptr ? static_cast<int>(CharacterAttribute->Level) : 1;
    if (level > mine + 10)
        return 2;
    if (level > mine - 5)
        return 1;
    return 0;
}

// The marker the original drew: Kind 1 an NPC (hidden in Crywolf while it is occupied, but the
// one at 228/48), Kind 2 a gate.
bool MarkerDrawn(const MINI_MAP& data)
{
    if (data.Kind == 2)
        return true;
    return !(gMapManager.WorldActive == WD_34CRYWOLF_1ST && m_OccupationState > 0) ||
           (data.Location[0] == 228 && data.Location[1] == 48 && gMapManager.WorldActive == WD_34CRYWOLF_1ST);
}
} // namespace

mu::ui::window::CMiniMap::CMiniMap()
{
    m_pNewUIMng = NULL;
    m_bSuccess = false;
    for (auto& data : m_Mini_Map_Data)
        data.Kind = 0;
    for (auto& box : m_Btn_Loc)
        box[0] = box[1] = box[2] = box[3] = 0.f;
}

mu::ui::window::CMiniMap::~CMiniMap()
{
    Release();
}

bool mu::ui::window::CMiniMap::Create(CManager* pNewUIMng)
{
    if (NULL == pNewUIMng)
        return false;

    m_pNewUIMng = pNewUIMng;
    m_pNewUIMng->AddUIObj(mu::ui::window::INTERFACE_MINI_MAP, this);
    m_bSuccess = false;

    BuildRmlUi();
    return true;
}

void mu::ui::window::CMiniMap::ClosingProcess()
{
    SocketClient->ToGameServer()->SendCloseNpcRequest();
}

float mu::ui::window::CMiniMap::GetLayerDepth()
{
    return 8.1f;
}

void mu::ui::window::CMiniMap::OpenningProcess()
{
    m_PendingClose = false;
}

void mu::ui::window::CMiniMap::Release()
{
    if (m_pNewUIMng)
    {
        m_pNewUIMng->RemoveUIObj(this);
        m_pNewUIMng = NULL;
    }

    m_RmlView.Release();
}

void mu::ui::window::CMiniMap::SetBtnPos(int Num, float x, float y, float nx, float ny)
{
    m_Btn_Loc[Num][0] = x;
    m_Btn_Loc[Num][1] = y;
    m_Btn_Loc[Num][2] = nx;
    m_Btn_Loc[Num][3] = ny;
}

bool mu::ui::window::CMiniMap::UpdateKeyEvent()
{
    if (g_pNewUISystem->IsVisible(mu::ui::window::INTERFACE_MINI_MAP))
    {
        if (IsPress(VK_ESCAPE) == true || IsPress(VK_TAB) == true)
        {
            g_pNewUISystem->Hide(mu::ui::window::INTERFACE_MINI_MAP);
            PlayBuffer(SOUND_CLICK01);
            return false;
        }
    }
    return true;
}

bool mu::ui::window::CMiniMap::Render()
{
    // Nothing native left: the map, its markers, the frame and the hint are RmlUi. Kept because
    // CObject requires the override.
    return m_bSuccess;
}

bool mu::ui::window::CMiniMap::Update()
{
    SyncRmlModel();

    if (m_PendingClose)
    {
        m_PendingClose = false;
        if (IsVisible())
            g_pNewUISystem->Hide(mu::ui::window::INTERFACE_MINI_MAP);
    }
    return true;
}

void mu::ui::window::CMiniMap::LoadImages(const wchar_t* Filename)
{
    wchar_t Fname[300];
    int i = 0;
    mu_swprintf(Fname, L"Data\\%ls\\mini_map.ozt", Filename);
    if (Content::Probe(Fname) != Content::Found::File)
    {
        m_bSuccess = false;
        m_WorldName.clear();
        return;
    }
    else
    {
        m_bSuccess = true;
        // The texture itself is loaded by the document (mini_map.rml's .map).
        m_WorldName = Filename;
    }

    m_FixedCount = -1;
    mu_swprintf(Fname, L"Data\\Local\\%ls\\Minimap\\Minimap_%ls_%ls.bmd", g_strSelectedML.c_str(), Filename, g_strSelectedML.c_str());

    for (i = 0; i < MAX_MINI_MAP_DATA; i++)
    {
        m_Mini_Map_Data[i].Kind = 0;
    }

    const Content::Stream fp = Content::OpenIO(Fname);

    if (fp != nullptr)
    {
        int Size = sizeof(MINI_MAP_FILE);
        BYTE* Buffer = new BYTE[Size * MAX_MINI_MAP_DATA + 45];
        DWORD dwCheckSum;
        const bool complete = DataFileIO::ReadExact(fp.get(), Buffer, (Size * MAX_MINI_MAP_DATA) + 45) &&
                              DataFileIO::ReadExact(fp.get(), &dwCheckSum, sizeof(DWORD));

        if (!complete || dwCheckSum != GenerateCheckSum2(Buffer, (Size * MAX_MINI_MAP_DATA) + 45, 0x2BC1))
        {
            DataFileIO::ReportUnusableFile(Fname, L"File corrupted.");
        }
        else
        {
            BYTE* pSeek = Buffer;

            for (i = 0; i < MAX_MINI_MAP_DATA; i++)
            {
                BuxConvert(pSeek, Size);

                MINI_MAP_FILE current{ };
                auto target = &(m_Mini_Map_Data[i]);
                memcpy(&current, pSeek, Size);
                memcpy(target, pSeek, Size);

                CMultiLanguage::ConvertFromUtf8(target->Name, current.Name);
                pSeek += Size;
            }
        }

        delete[] Buffer;
    }
}

void mu::ui::window::CMiniMap::UnloadImages()
{
    m_WorldName.clear();
}

bool mu::ui::window::CMiniMap::UpdateMouseEvent()
{
    // The close button's click is RmlUi's (minimap_close); like the original, the pointer over the
    // top 430 rows goes to nothing behind the map.
    const UI::Scaling::Transform overlay = OverlayTransform();
    const float pointerY = UI::Scaling::LogicalY(overlay, g_fWindowMouseY);
    const bool overMap = pointerY >= 0.f && pointerY < static_cast<float>(kMapAreaHeight);
    return !overMap;
}

void mu::ui::window::CMiniMap::BindRmlModel(Rml::DataModelConstructor& c, MiniMapRmlModel& model)
{
    c.Bind("text_px", &model.textPx);
    c.Bind("close_hint", &model.closeHint);

    auto clip = c.RegisterStruct<MiniMapClipEntry>();
    clip.RegisterMember("left", &MiniMapClipEntry::left);
    clip.RegisterMember("top", &MiniMapClipEntry::top);
    clip.RegisterMember("width", &MiniMapClipEntry::width);
    clip.RegisterMember("height", &MiniMapClipEntry::height);
    clip.RegisterMember("world_left", &MiniMapClipEntry::worldLeft);
    clip.RegisterMember("world_top", &MiniMapClipEntry::worldTop);
    c.RegisterArray<std::vector<MiniMapClipEntry>>();
    c.Bind("clips", &model.clips);

    c.Bind("map_source", &model.mapSource);
    c.Bind("map_transform", &model.mapTransform);
    c.Bind("fog_source", &model.fogSource);

    auto marker = c.RegisterStruct<MiniMapMarkerEntry>();
    marker.RegisterMember("portal", &MiniMapMarkerEntry::portal);
    marker.RegisterMember("size", &MiniMapMarkerEntry::size);
    marker.RegisterMember("transform", &MiniMapMarkerEntry::transform);
    marker.RegisterMember("icon", &MiniMapMarkerEntry::icon); // MuToDog (rodada 14)
    marker.RegisterMember("dg", &MiniMapMarkerEntry::dg);     // MuToDog (24/11)
    marker.RegisterMember("spot", &MiniMapMarkerEntry::spot); // MuToDog (25/11)
    marker.RegisterMember("lit", &MiniMapMarkerEntry::lit);
    c.RegisterArray<std::vector<MiniMapMarkerEntry>>();
    c.Bind("markers", &model.markers);

    c.RegisterArray<std::vector<Rml::String>>();
    c.Bind("side_lines", &model.sideLines);
    c.RegisterArray<std::vector<float>>();

    c.Bind("hint_visible", &model.hintVisible);
    c.Bind("hint_text", &model.hintText);
    c.Bind("hint_left", &model.hintLeft);
    c.Bind("hint_top", &model.hintTop);
    c.Bind("hint_width", &model.hintWidth);
    c.Bind("hint_height", &model.hintHeight);
    c.Bind("help_top", &model.helpTop);
    c.Bind("help_width", &model.helpWidth);

    // MuToDog: botão direito no mapa anda até lá (UI/Estudo/AndarMinimapa.h), como no cliente Godot. O .hit do
    // mapa pega o mouse no RmlUi (o jogo não vê o clique), então o botão chega por aqui. O ponto vem do ponteiro do
    // jogo (px da janela, o mesmo da dica do NPC): o mouse_x/mouse_y do evento não está nessa medida.
    c.BindEventCallback("minimap_press", [](Rml::DataModelHandle, Rml::Event& event, const Rml::VariantList&)
                        {
                            if (event.GetParameter<int>("button", -1) != 1)
                                return;
                            int tileX = 0, tileY = 0;
                            if (TileUnderPointer(g_fWindowMouseX, g_fWindowMouseY, tileX, tileY) &&
                                mu::ui::window::AndarMinimapa::Ir(tileX, tileY))
                                PlayBuffer(SOUND_CLICK01);
                        });

    c.BindEventCallback("minimap_close", [this](Rml::DataModelHandle, Rml::Event&, const Rml::VariantList&)
                        { m_PendingClose = true; });
}

void mu::ui::window::CMiniMap::BuildRmlUi()
{
    m_RmlView.Ensure();
}

void mu::ui::window::CMiniMap::SyncRmlModel()
{
    BuildRmlUi();
    if (!m_RmlView.Document())
        return;

    const bool visible = IsVisible() && m_bSuccess && Hero != nullptr;
    // Over the location bar, the logs and the buff strip, under the bottom HUD: the stacking table
    // (UI/RmlBridge/RmlStackingOrder.cpp) orders it as the original's layer depths did.
    UI::RmlBridge::SyncDocumentVisibilityInFront(m_RmlView.Document(), visible);

    if (!visible)
        return;

    SyncScreen();
    SyncClips();
    SyncMap();
    SyncHint();
}

void mu::ui::window::CMiniMap::SyncScreen()
{
    UI::RmlBridge::SyncNativeTextSize(m_RmlView.Binder());
    Sync(m_RmlView.Binder(), &MiniMapRmlModel::closeHint, "close_hint", StringUtils::WideToNarrow(I18N::Game::Close388));
    // MuToDog: a ajuda fica logo acima da borda de baixo do mapa (430 da tela de referência)
    const UI::Scaling::Transform overlay = OverlayTransform();
    // (a barra de baixo da HUD cobre o fim do mapa em tela larga: a ajuda sobe pra cima dela)
    float helpTop = UI::Scaling::PositionY(overlay, static_cast<float>(kMapAreaHeight - 22));
    UI::Placement::PlacementParticipant::Box strip;
    if (UI::Placement::SlotBox("main_hud", strip))
        helpTop = std::min(helpTop, strip.top - m_RmlView.GetModel().textPx * 2.f);
    Sync(m_RmlView.Binder(), &MiniMapRmlModel::helpTop, "help_top", helpTop);
    Sync(m_RmlView.Binder(), &MiniMapRmlModel::helpWidth, "help_width", static_cast<float>(WindowWidth));

    // The border tiles depend on the screen alone: rebuilt when it changes, or when a theme reload
    // left the model empty.
    const UI::MiniMap::Screen screen = CurrentScreen();
    if (screen == m_SideLinesScreen && !m_RmlView.GetModel().sideLines.empty())
        return;
    m_SideLinesScreen = screen;
    std::vector<Rml::String> sideLines;
    sideLines.reserve(kSideTiles * 2);
    for (int i = 0; i < kSideTiles; ++i)
    {
        const float y = static_cast<float>(i) * (kTileWidth - 3.f);
        sideLines.push_back(MatrixText(UI::MiniMap::ElementToQuad(
            UI::MiniMap::RotatedQuad(screen, kTileHeight / 2.f, y, kTileWidth, kTileHeight, -90.f), kSideElementWidth,
            kSideElementHeight)));
        sideLines.push_back(MatrixText(UI::MiniMap::ElementToQuad(
            UI::MiniMap::RotatedQuad(screen, REFERENCE_WIDTH - kTileHeight / 2.f, y, kTileWidth, kTileHeight, 90.f),
            kSideElementWidth, kSideElementHeight)));
    }
    Sync(m_RmlView.Binder(), &MiniMapRmlModel::sideLines, "side_lines", std::move(sideLines));
}

void mu::ui::window::CMiniMap::SyncClips()
{
    // The original drew the bottom HUD strip over the map, so the map paints only outside it:
    // above the strip, and beside it down to the screen's bottom edge.
    const float width = static_cast<float>(WindowWidth);
    const float height = static_cast<float>(WindowHeight);
    UI::Placement::PlacementParticipant::Box strip;
    const bool hasStrip = UI::Placement::SlotBox("main_hud", strip);
    const float bandTop = hasStrip ? std::clamp(strip.top, 0.f, height) : height;
    const float bandBottom = hasStrip ? std::clamp(strip.top + strip.height, bandTop, height) : height;
    const float bandLeft = std::clamp(strip.left, 0.f, width);
    const float bandRight = std::clamp(strip.left + strip.width, bandLeft, width);

    std::vector<MiniMapClipEntry> clips;
    clips.push_back({0.f, 0.f, width, bandTop, 0.f, 0.f});
    if (bandLeft > 0.f && bandBottom > bandTop)
        clips.push_back({0.f, bandTop, bandLeft, bandBottom - bandTop, 0.f, -bandTop});
    if (bandRight < width && bandBottom > bandTop)
        clips.push_back({bandRight, bandTop, width - bandRight, bandBottom - bandTop, -bandRight, -bandTop});
    if (bandBottom < height)
        clips.push_back({0.f, bandBottom, width, height - bandBottom, 0.f, -bandBottom});

    MiniMapRmlModel& model = m_RmlView.GetModel();
    const bool same =
        model.clips.size() == clips.size() &&
        std::equal(clips.begin(), clips.end(), model.clips.begin(),
                   [](const MiniMapClipEntry& a, const MiniMapClipEntry& b)
                   { return a.left == b.left && a.top == b.top && a.width == b.width && a.height == b.height; });
    if (same)
        return;
    model.clips = std::move(clips);
    m_RmlView.MarkDirty("clips");
}

void mu::ui::window::CMiniMap::SyncMap()
{
    const UI::MiniMap::Screen screen = CurrentScreen();
    const float length = UI::MiniMap::MapLength;
    const float heroY = (static_cast<float>(Hero->PositionX) / 256.f) * length;
    const float heroX = (static_cast<float>(Hero->PositionY) / 256.f) * length;

    // Relative to the document: themes/<theme>/mini_map.rml -> Data/<World>/mini_map.tga.
    Rml::String source;
    if (!m_WorldName.empty())
        source = "../../../../" + StringUtils::WideToNarrow(m_WorldName.c_str()) + "/mini_map.tga";
    Sync(m_RmlView.Binder(), &MiniMapRmlModel::mapSource, "map_source", std::move(source));

    Sync(m_RmlView.Binder(), &MiniMapRmlModel::mapTransform, "map_transform",
         MatrixText(UI::MiniMap::ElementToQuad(
             UI::MiniMap::MapQuad(screen, heroX, heroY, length, UI::MiniMap::MapRotation), length, length)));

    AddLiveNpcs();
    std::vector<MiniMapMarkerEntry> markers;

    // MuToDog (25/11): os spots primeiro, por baixo dos NPCs e portais
    s_SpotHits.clear();
    {
        const float tilePx = length / 256.f * std::sqrt(screen.scaleX * screen.scaleY);
        for (const Spot& spot : SpotsOf(static_cast<int>(gMapManager.WorldActive)))
        {
            const float radius = std::max(spot.tiles * tilePx, 6.f * screen.scaleY);
            const float size = radius * 2.f;
            const float pointY = spot.cx / 256.f * length;
            const float pointX = spot.cy / 256.f * length;
            const UI::MiniMap::Marker marker =
                UI::MiniMap::MarkerQuad(screen, heroX, heroY, pointX, pointY, size, 0.f, length, UI::MiniMap::MapRotation, false);
            const float x = (marker.quad.topRight.x + marker.quad.bottomLeft.x) / 2.f;
            const float y = (marker.quad.topRight.y + marker.quad.bottomLeft.y) / 2.f;
            s_SpotHits.push_back({x, y, radius, &spot});
        }
        // acende o primeiro debaixo do ponteiro
        const SpotHit* lit = nullptr;
        for (const SpotHit& hit : s_SpotHits)
            if (!lit && std::hypot(g_fWindowMouseX - hit.x, g_fWindowMouseY - hit.y) <= hit.radius + 2.f)
                lit = &hit;
        for (const SpotHit& hit : s_SpotHits)
        {
            const float size = hit.radius * 2.f;
            // em pé na tela (o círculo não gira com o mapa): topLeft, topRight, bottomLeft
            const UI::MiniMap::Quad quad{{hit.x - hit.radius, hit.y - hit.radius},
                                         {hit.x + hit.radius, hit.y - hit.radius},
                                         {hit.x - hit.radius, hit.y + hit.radius}};
            MiniMapMarkerEntry entry{false, size, MatrixText(UI::MiniMap::ElementToQuad(quad, size, size)), {}, -1};
            entry.spot = SpotColor(hit.spot->level);
            entry.lit = &hit == lit;
            markers.push_back(std::move(entry));
        }
        if (lit)
            std::rotate(s_SpotHits.begin(), s_SpotHits.begin() + (lit - s_SpotHits.data()), s_SpotHits.begin() + (lit - s_SpotHits.data()) + 1);
    }
    for (int i = 0; i < MAX_MINI_MAP_DATA; i++)
    {
        const MINI_MAP& data = m_Mini_Map_Data[i];
        if (data.Kind <= 0)
            break;
        if (data.Kind != 1 && data.Kind != 2)
            continue;

        const bool portal = data.Kind == 2;
        // MuToDog (rodada 14): cada NPC com o ícone do que ele faz (os mesmos de cima da cabeça; o Zoak com o estado
        // da missão), em pé e maior que o ponto, como no cliente Godot (minimapa.gd)
        const std::string tipo = portal ? std::string() : mu::ui::window::IconesNpc::Tipo(data.Name);
        const std::string icon = mu::ui::window::IconesNpc::Source(mu::ui::window::IconesNpc::Agora(tipo));
        const float size = portal ? kPortalSize : !icon.empty() ? std::max(kNpcIconSize, 16.f * screen.scaleY) : kNpcSize;
        const float pointY = (static_cast<float>(data.Location[0]) / 256.f) * length;
        const float pointX = (static_cast<float>(data.Location[1]) / 256.f) * length;
        const UI::MiniMap::Marker marker =
            UI::MiniMap::MarkerQuad(screen, heroX, heroY, pointX, pointY, size, icon.empty() ? static_cast<float>(data.Rotation) : 0.f,
                                    length, UI::MiniMap::MapRotation, portal);
        if (!MarkerDrawn(data))
            continue;
        // The original stored the name hint's box of every marker it drew.
        SetBtnPos(i, marker.hitBox[0], marker.hitBox[1], marker.hitBox[2], marker.hitBox[3]);
        markers.push_back({portal, size, MatrixText(UI::MiniMap::ElementToQuad(marker.quad, size, size)), icon});
    }

    // MuToDog (24/11): Dungeon das 3 etapas, a névoa da party por cima do mapa e o que está na parte revelada
    // (C2 FA 22): horda, subchefe, boss e o portal pro próximo andar, como no minimapa.gd do Godot
    Sync(m_RmlView.Binder(), &MiniMapRmlModel::fogSource, "fog_source", CDungeonEtapasWindow::FogSource());
    for (const CDungeonEtapasWindow::Point& p : CDungeonEtapasWindow::Points())
    {
        static constexpr float kDungeonSizes[4] = {6.f, 10.f, 16.f, 20.f};
        const int type = std::clamp(p.type, 0, 3);
        const float size = kDungeonSizes[type] * std::max(1.f, screen.scaleY);
        const float pointY = (static_cast<float>(p.x) / 256.f) * length;
        const float pointX = (static_cast<float>(p.y) / 256.f) * length;
        const UI::MiniMap::Marker marker =
            UI::MiniMap::MarkerQuad(screen, heroX, heroY, pointX, pointY, size, 0.f, length, UI::MiniMap::MapRotation, false);
        markers.push_back({false, size, MatrixText(UI::MiniMap::ElementToQuad(marker.quad, size, size)), {}, type});
    }

    // MuToDog: para onde estou indo pelo clique no mapa (o ponto amarelo do minimapa.gd)
    int destX = 0, destY = 0;
    if (mu::ui::window::AndarMinimapa::Destino(destX, destY))
    {
        const float size = 12.f * std::max(1.f, screen.scaleY);
        const float pointY = (static_cast<float>(destX) + 0.5f) / 256.f * length;
        const float pointX = (static_cast<float>(destY) + 0.5f) / 256.f * length;
        const UI::MiniMap::Marker marker =
            UI::MiniMap::MarkerQuad(screen, heroX, heroY, pointX, pointY, size, 0.f, length, UI::MiniMap::MapRotation, false);
        markers.push_back({false, size, MatrixText(UI::MiniMap::ElementToQuad(marker.quad, size, size)), {}, 4});
    }

    MiniMapRmlModel& model = m_RmlView.GetModel();
    const bool same = model.markers.size() == markers.size() &&
                      std::equal(markers.begin(), markers.end(), model.markers.begin(),
                                 [](const MiniMapMarkerEntry& a, const MiniMapMarkerEntry& b)
                                 { return a.portal == b.portal && a.size == b.size && a.transform == b.transform && a.icon == b.icon && a.dg == b.dg &&
                                          a.spot == b.spot && a.lit == b.lit; });
    if (!same)
    {
        model.markers = std::move(markers);
        m_RmlView.MarkDirty("markers");
    }
}

// MuToDog (rodada 14): o NPC que está no mapa e o bmd não tem (os nossos, como o Zoak) entra depois das marcas do bmd,
// com o nome pra dica; NPC a até 3 casas de uma marca do bmd já está lá. Guarda e objeto do mapa ficam de fora.
void mu::ui::window::CMiniMap::AddLiveNpcs()
{
    if (m_FixedCount < 0)
    {
        m_FixedCount = 0;
        while (m_FixedCount < MAX_MINI_MAP_DATA && m_Mini_Map_Data[m_FixedCount].Kind > 0)
            ++m_FixedCount;
    }
    for (int i = m_FixedCount; i < MAX_MINI_MAP_DATA; i++)
        m_Mini_Map_Data[i].Kind = 0;
    int next = m_FixedCount;
    for (int k = 0; k < MAX_CHARACTERS_CLIENT && next < MAX_MINI_MAP_DATA; k++)
    {
        const CHARACTER* c = &CharactersClient[k];
        if (!c->Object.Live || c->Object.Kind != KIND_NPC)
            continue;
        const std::string tipo = mu::ui::window::IconesNpc::Tipo(c->ID, static_cast<int>(c->MonsterIndex));
        if (tipo.empty() || tipo == "guarda")
            continue;
        bool known = false;
        for (int i = 0; i < next && !known; i++)
        {
            const MINI_MAP& d = m_Mini_Map_Data[i];
            // o mesmo NPC = perto e com o mesmo ícone (o Zoak fica a menos de 3 casas de outro NPC da Lorencia)
            known = d.Kind == 1 && std::abs(d.Location[0] - c->PositionX) <= 3 && std::abs(d.Location[1] - c->PositionY) <= 3 &&
                    mu::ui::window::IconesNpc::Tipo(d.Name) == tipo;
        }
        if (known)
            continue;
        MINI_MAP& d = m_Mini_Map_Data[next++];
        d.Kind = 1;
        d.Location[0] = c->PositionX;
        d.Location[1] = c->PositionY;
        d.Rotation = 0;
        wcsncpy(d.Name, c->ID, MAX_MINIMAP_NAME - 1);
        d.Name[MAX_MINIMAP_NAME - 1] = L'\0';
    }
}

void mu::ui::window::CMiniMap::SyncHint()
{
    // Check_Btn(): the first marker whose stored box holds the pointer shows its name above that
    // box, white on RGBA(0, 0, 0, 180), in a box 6 units wider than the text, starting where the
    // text would be centred on the box (so the text sits 3 units right of centre).
    bool found = false;
    std::wstring name;
    float left = 0.f, top = 0.f, width = 0.f, height = 0.f;
    const UI::Scaling::Transform transform = OverlayTransform();
    // The names are measured in that stretch too.
    const UI::Scaling::ScopedScreenStretch screen(static_cast<int>(WindowWidth), static_cast<int>(WindowHeight));
    const float pointerX = UI::Scaling::LogicalX(transform, g_fWindowMouseX);
    const float pointerY = UI::Scaling::LogicalY(transform, g_fWindowMouseY);
    for (int i = 0; i < MAX_MINI_MAP_DATA && !found; i++)
    {
        if (m_Mini_Map_Data[i].Kind <= 0)
            break;
        const float* box = m_Btn_Loc[i];
        if (pointerX > box[0] && pointerX < (box[0] + box[2]) && pointerY > box[1] && pointerY < (box[1] + box[3]))
        {
            found = true;
            name = m_Mini_Map_Data[i].Name;
            g_pRenderText->SetFont(g_hFont);
            const SIZE size = g_pRenderText->MeasureText(name.c_str(), static_cast<int>(name.size()));
            // The original's int / float mix: the text half-width in whole units.
            const int x = static_cast<int>(box[0] + ((box[2] / 2) - static_cast<float>(size.cx / 2)));
            const int y = static_cast<int>(box[1] - static_cast<float>(size.cy + 2));
            left = UI::Scaling::PositionX(transform, static_cast<float>(x));
            top = UI::Scaling::PositionY(transform, static_cast<float>(y));
            width = UI::Scaling::SizeX(transform, static_cast<float>(size.cx + 6));
            height = UI::Scaling::SizeY(transform, static_cast<float>(size.cy));
        }
    }

    // MuToDog (25/11): sem NPC debaixo do ponteiro, o spot aceso (o primeiro de s_SpotHits) dá a dica, em cima do círculo
    if (!found && !s_SpotHits.empty() &&
        std::hypot(g_fWindowMouseX - s_SpotHits[0].x, g_fWindowMouseY - s_SpotHits[0].y) <= s_SpotHits[0].radius + 2.f)
    {
        const SpotHit& hit = s_SpotHits[0];
        found = true;
        name = StringUtils::NarrowToWide(hit.spot->text);
        g_pRenderText->SetFont(g_hFont);
        const SIZE size = g_pRenderText->MeasureText(name.c_str(), static_cast<int>(name.size()));
        width = UI::Scaling::SizeX(transform, static_cast<float>(size.cx + 6));
        height = UI::Scaling::SizeY(transform, static_cast<float>(size.cy));
        left = hit.x - width / 2.f;
        top = hit.y - hit.radius - height - 4.f;
    }

    Sync(m_RmlView.Binder(), &MiniMapRmlModel::hintVisible, "hint_visible", found);
    if (!found)
        return;
    Sync(m_RmlView.Binder(), &MiniMapRmlModel::hintText, "hint_text", StringUtils::WideToNarrow(name.c_str()));
    Sync(m_RmlView.Binder(), &MiniMapRmlModel::hintLeft, "hint_left", left);
    Sync(m_RmlView.Binder(), &MiniMapRmlModel::hintTop, "hint_top", top);
    Sync(m_RmlView.Binder(), &MiniMapRmlModel::hintWidth, "hint_width", width);
    Sync(m_RmlView.Binder(), &MiniMapRmlModel::hintHeight, "hint_height", height);
}
