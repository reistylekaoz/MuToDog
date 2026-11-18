#pragma once

// MuToDog (MU Estudo, rodada 7): o menu do F10 em grade, no jeito do cliente Godot (godot/scripts/janela_atalhos.gd):
// uma casa por atalho, a tecla no canto e o nome embaixo. Clicar faz o mesmo que apertar a tecla: a tecla vai pro
// teclado do jogo no quadro seguinte (CNewKeyInput::SetKeyState), antes do CHotKey ler. O Reset abre a janela do
// reset (CResetSystemWindow), que nao tem tecla. Ctrl+F10 segue soltando o zoom da camera.

#include "UI/Core/WindowManager.h"
#include "UI/RmlBridge/RmlThemedView.h"

#include <RmlUi/Core/Types.h>

#include <vector>

namespace mu::ui::window
{
struct MenuF10Cell
{
    Rml::String name;
    Rml::String key;
    Rml::String icon;
    int index = 0;
};

struct MenuF10RmlModel
{
    std::vector<MenuF10Cell> cells;
    Rml::String hint;
};

class CMenuF10Window : public CObject
{
public:
    CMenuF10Window();
    ~CMenuF10Window() override;

    bool Create(CManager* pNewUIMng);
    void Release();

    bool UpdateMouseEvent() override;
    bool UpdateKeyEvent() override;
    bool Update() override;
    bool Render() override;

    float GetLayerDepth() override;
    float GetKeyEventOrder() override;

private:
    void BindRmlModel(Rml::DataModelConstructor& c, MenuF10RmlModel& model);
    void SyncRmlModel();
    void RunCell(int index);
    void SetHint(int index);

    CManager* m_pNewUIMng = nullptr;
    int m_PendingCell = -1;
    int m_PendingKey = 0;

    UI::RmlBridge::ThemedView<MenuF10RmlModel> m_RmlView{"menu_f10",
        [this](Rml::DataModelConstructor& c, MenuF10RmlModel& model) { BindRmlModel(c, model); },
        {{"Data/Interface/RmlUi/menu_f10.rml"}}};
};
} // namespace mu::ui::window
