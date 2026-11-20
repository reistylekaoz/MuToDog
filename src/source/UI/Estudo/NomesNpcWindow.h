#pragma once

// MuToDog (MU Estudo, rodada 14): nome e ícone em cima de cada NPC, sempre à mostra, no jeito do cliente Godot
// (godot/scripts/textos_mu.gd _nome_npc, a MuDream): o nome em azul claro com contorno, sem caixa, e o ícone do que ele
// faz em cima (IconesNpc), boiando devagar; o Zoak mostra o estado da missão do mapa (! pra pegar, V apagado, V aceso
// pulsando pra entregar). Guarda e objeto do mapa ficam como antes (nome só com o mouse em cima). Com o mouse em cima o
// nome clareia e a etiqueta do chat (NameWindow) não aparece por cima.
// Posição em px da janela (CameraProjection::WorldToWindowPixel), tamanho pela escala da letra (TypographyScale), pra o
// texto sair nítido em qualquer resolução.

#include "UI/Core/WindowManager.h"
#include "UI/RmlBridge/RmlThemedView.h"

#include <RmlUi/Core/Types.h>

#include <vector>


namespace mu::ui::window
{
struct NomeNpcRow
{
    Rml::String name;
    Rml::String icon; // caminho do desenho (IconesNpc::Source)
    Rml::String left; // px da janela
    Rml::String top;
    bool pulse = false; // ! e V aceso pulsam
    bool hot = false;   // mouse em cima

    bool operator==(const NomeNpcRow& o) const
    {
        return name == o.name && icon == o.icon && left == o.left && top == o.top && pulse == o.pulse && hot == o.hot;
    }
};

struct NomesNpcRmlModel
{
    std::vector<NomeNpcRow> rows;
    Rml::String fontSize;
    Rml::String iconSize;
};

class CNomesNpcWindow : public CObject
{
public:
    CNomesNpcWindow();
    ~CNomesNpcWindow() override;

    bool Create(CManager* pNewUIMng);
    void Release();

    bool UpdateMouseEvent() override;
    bool UpdateKeyEvent() override;
    bool Update() override;
    bool Render() override;
    void PrepareFrame() override;

    float GetLayerDepth() override;

    // o NPC tem nome e ícone desenhados aqui (a etiqueta do chat sai pra não ficar em dobro)
    static bool Draws(int characterIndex);

private:
    void BindRmlModel(Rml::DataModelConstructor& c, NomesNpcRmlModel& model);

    CManager* m_pNewUIMng = nullptr;

    UI::RmlBridge::ThemedView<NomesNpcRmlModel> m_RmlView{"nomes_npc",
        [this](Rml::DataModelConstructor& c, NomesNpcRmlModel& model) { BindRmlModel(c, model); },
        {{"Data/Interface/RmlUi/nomes_npc.rml"}}};
};
} // namespace mu::ui::window
