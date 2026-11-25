#pragma once

#include <RmlUi/Core/Types.h>

#include <vector>

namespace mu::ui::window
{
// A rectangle of the window, physical px: one of the regions the map may paint (see
// CMiniMap::SyncClips()).
struct MiniMapClipEntry
{
    float left = 0.f, top = 0.f, width = 0.f, height = 0.f;
    // -left / -top: .world's offset back to window coordinates (the data expressions have no
    // unary minus).
    float worldLeft = 0.f, worldTop = 0.f;
};

struct MiniMapMarkerEntry
{
    bool portal = false;   // MINI_MAP::Kind 2 (a gate), else an NPC
    float size = 15.f;     // the icon's side, physical px (the original never scaled it)
    Rml::String transform; // CSS matrix() placing the icon element
    Rml::String icon;      // MuToDog: o ícone do NPC (IconesNpc::Source), "" = o ponto de sempre
    int dg = -1;           // MuToDog (24/11): marca da Dungeon das 3 etapas (0 horda, 1 subchefe, 2 boss, 3 portal, 4 o destino do clique)
    int spot = -1;         // MuToDog (25/11): spot de monstro, a cor pelo nível perto do meu (0 verde, 1 amarelo, 2 vermelho)
    bool lit = false;      // MuToDog (25/11): o spot com o mouse em cima
};

struct MiniMapRmlModel
{
    float textPx = 0.f; // native text size in physical px (RmlNativeTextSize.h)

    std::vector<MiniMapClipEntry> clips;

    Rml::String mapSource;    // the world's mini_map texture, relative to the document
    Rml::String mapTransform; // CSS matrix() placing the 800x800 map element
    Rml::String fogSource;    // MuToDog (24/11): a névoa da Dungeon das 3 etapas, no mesmo lugar do mapa ("" sem)
    std::vector<MiniMapMarkerEntry> markers;
    std::vector<Rml::String> sideLines; // CSS matrix() of each left/right border tile
    Rml::String closeHint;

    // The hovered marker's name (CMiniMap::Check_Btn()), physical px.
    bool hintVisible = false;
    Rml::String hintText;
    float hintLeft = 0.f, hintTop = 0.f, hintWidth = 0.f, hintHeight = 0.f;

    // MuToDog: a linha de ajuda embaixo do mapa (botão direito anda até lá), physical px
    float helpTop = 0.f, helpWidth = 0.f;
};
} // namespace mu::ui::window
