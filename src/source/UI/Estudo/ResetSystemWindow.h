#pragma once

// MuToDog (MU Estudo, rodada 7): Reset System e Grand Reset System, no jeito do cliente Godot
// (godot/scripts/janela_reset.gd) e pelo mesmo caminho: C1 FB 34 pede o estado (o servidor responde C1 FB 34 com os
// numeros, GrandResetAction.EnviarEstadoAsync), FB 35 faz o reset e FB 36 o grand reset. O servidor confere tudo
// de novo e, dando certo, leva pra escolha de personagem.
// O documento tambem traz os icones da barra (agenda e reset, do lado da agenda): o do reset pisca quando o reset
// ou o grand reset libera e abre esta janela.

#include "UI/Core/WindowManager.h"
#include "UI/RmlBridge/RmlThemedView.h"

#include <RmlUi/Core/Types.h>

#include <cstdint>
#include <string>
#include <vector>

namespace mu::ui::window
{
struct ResetSystemRow
{
    Rml::String label;
    Rml::String value;
    Rml::String look; // "secao", "ok", "falta" ou "premio"
};

struct ResetSystemRmlModel
{
    bool open = false;
    int tab = 0;      // 0 reset, 1 grand reset
    int ready = 0;    // 0 nada, 1 o reset liberou, 2 o grand reset
    bool enabled = false;
    Rml::String title;
    Rml::String message;
    Rml::String note;
    std::vector<ResetSystemRow> rows;
    Rml::String action;
    bool canAct = false;
};

// O ultimo C1 FB 34 do servidor.
struct ResetSystemState
{
    bool received = false;
    bool enabled = false;
    int resets = 0;
    int limit = 0;
    int level = 0;
    std::uint32_t zen = 0;
    std::uint32_t points = 0;
    int grand = 0;
    int grandLimit = 0;
    int grandResets = 0;
    std::uint32_t grandZen = 0;
    std::uint32_t grandPoints = 0;
};

class CResetSystemWindow : public CObject
{
public:
    CResetSystemWindow();
    ~CResetSystemWindow() override;

    bool Create(CManager* pNewUIMng);
    void Release();

    bool UpdateMouseEvent() override;
    bool UpdateKeyEvent() override;
    bool Update() override;
    bool Render() override;

    float GetLayerDepth() override;
    float GetKeyEventOrder() override;

    void Show(bool bShow) override;

    // C1 FB 34 (WSclient.cpp ProcessPacket): guarda o estado pra janela e o icone.
    static void ReceiveState(const std::uint8_t* packet, int size);

private:
    void BindRmlModel(Rml::DataModelConstructor& c, ResetSystemRmlModel& model);
    void SyncRmlModel(bool inGame);
    void RequestStateIfDue();
    void RunPending();
    void RebuildModel();
    void BuildResetTab(ResetSystemRmlModel& model, int level, std::uint32_t zen) const;
    void BuildGrandTab(ResetSystemRmlModel& model, int level, std::uint32_t zen) const;
    static void SendCommand(std::uint8_t command);

    CManager* m_pNewUIMng = nullptr;
    int m_PendingAction = 0;
    std::uint64_t m_NextRequestMs = 0;
    std::string m_BuiltKey;

    UI::RmlBridge::ThemedView<ResetSystemRmlModel> m_RmlView{"reset_system",
        [this](Rml::DataModelConstructor& c, ResetSystemRmlModel& model) { BindRmlModel(c, model); },
        {{"Data/Interface/RmlUi/reset_system.rml"}}};
};
} // namespace mu::ui::window
