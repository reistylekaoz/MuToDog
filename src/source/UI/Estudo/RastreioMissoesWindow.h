#pragma once

// MuToDog (MU Estudo, rodada 13): rastreio das missões no canto direito da tela, no jeito do cliente Godot
// (godot/scripts/rastreio_quests.gd, o "Show quests in this map" da MuDream): o nome de cada main quest ativa e a barra
// do monstro (x / total), verde quando já pode entregar no Zoak. Some sem missão ativa. Clique abre as Missões (T);
// segurar arrasta (o lugar fica em rastreio_missoes.ini, do lado do config.ini) e o botão direito volta pro canto.
// O estado vem da janela das Missões (CQuestsMainWindow), que pede ao servidor ao entrar no jogo.

#include "UI/Core/WindowManager.h"
#include "UI/RmlBridge/RmlThemedView.h"

#include <RmlUi/Core/Types.h>

#include <cstdint>
#include <vector>

namespace mu::ui::window
{
struct RastreioRow
{
    Rml::String name;
    Rml::String label; // o monstro ou "Entregar no Zoak"
    Rml::String count; // "12/20"
    Rml::String bar;   // "60%"
    bool ready = false;
};

struct RastreioRmlModel
{
    std::vector<RastreioRow> rows;
    Rml::String left;
    Rml::String top;
};

class CRastreioMissoesWindow : public CObject
{
public:
    CRastreioMissoesWindow();
    ~CRastreioMissoesWindow() override;

    bool Create(CManager* pNewUIMng);
    void Release();

    bool UpdateMouseEvent() override;
    bool UpdateKeyEvent() override;
    bool Update() override;
    bool Render() override;

    float GetLayerDepth() override;
    float GetKeyEventOrder() override;

private:
    void BindRmlModel(Rml::DataModelConstructor& c, RastreioRmlModel& model);
    void Rebuild();
    void Place();
    void LoadPlace();
    void SavePlace() const;

    CManager* m_pNewUIMng = nullptr;
    bool m_Placed = false;
    bool m_HasRows = false;
    float m_OffsetX = 0.f; // o quanto saiu do canto, px da tela de referência
    float m_OffsetY = 0.f;
    float m_DragX = 0.f;
    float m_DragY = 0.f;
    float m_DragOffsetX = 0.f;
    float m_DragOffsetY = 0.f;
    float m_Scale = 1.f;
    float m_LivreDireita = -1.f; // UncoveredWorldRight() da última Place, px da tela
    bool m_Moved = false;
    bool m_Save = false;
    bool m_Home = false;
    bool m_Open = false;
    std::uint32_t m_SeenVersion = 0;

    UI::RmlBridge::ThemedView<RastreioRmlModel> m_RmlView{"rastreio_missoes",
        [this](Rml::DataModelConstructor& c, RastreioRmlModel& model) { BindRmlModel(c, model); },
        {{"Data/Interface/RmlUi/rastreio_missoes.rml"}}};
};
} // namespace mu::ui::window
