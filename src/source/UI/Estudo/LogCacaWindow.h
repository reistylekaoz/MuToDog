#pragma once

// MuToDog (MU Estudo, rodada 11): Log de caça (tecla K), no jeito do cliente Godot (godot/scripts/log_caca.gd, o
// "Instant Hunting Log" da MuDream): painel no canto de cima à direita com o tempo, dano, zen e exp por minuto e quando
// chega o próximo nível; embaixo o dano no Boneco de Treino da saída de Lorencia (monstro 924): golpes, total, último,
// maior, média e por segundo. Tudo sai do que o cliente já recebe: o golpe dado (C1 11, WSclient.cpp
// ReceiveAttackDamageExtended), a exp de monstro (UI::Hud::ShowExperienceGain), o zen e o nível (lidos a cada quadro).
// Arrasta segurando (o lugar fica em log_caca.ini, do lado do config.ini), botão direito volta pro canto, "Zerar"
// começa de novo. Bater no boneco abre o painel sozinho.

#include "UI/Core/WindowManager.h"
#include "UI/RmlBridge/RmlThemedView.h"

#include <RmlUi/Core/Types.h>

#include <cstdint>
#include <string>
#include <vector>

namespace mu::ui::window
{
struct LogCacaRow
{
    Rml::String label;
    Rml::String value;
    Rml::String kind; // "linha", "vao" ou "titulo"
};

struct LogCacaRmlModel
{
    std::vector<LogCacaRow> rows;
    Rml::String left; // a posição, "4px"
    Rml::String top;
};

class CLogCacaWindow : public CObject
{
public:
    CLogCacaWindow();
    ~CLogCacaWindow() override;

    bool Create(CManager* pNewUIMng);
    void Release();

    bool UpdateMouseEvent() override;
    bool UpdateKeyEvent() override;
    bool Update() override;
    bool Render() override;

    float GetLayerDepth() override;
    float GetKeyEventOrder() override;

    // golpe que eu dei num monstro (numero = CHARACTER::MonsterIndex)
    static void OnHit(int damage, int number);
    // exp de monstro (previous = a exp antes do ganho)
    static void OnExp(std::int64_t previous, std::int64_t gained, bool master);

private:
    void BindRmlModel(Rml::DataModelConstructor& c, LogCacaRmlModel& model);
    void Rebuild();
    void Place();
    void LoadPlace();
    void SavePlace() const;

    CManager* m_pNewUIMng = nullptr;
    bool m_InGame = false;
    bool m_Placed = false;
    float m_OffsetX = 0.f; // o quanto saiu do canto (4, 30), px da tela de referência
    float m_OffsetY = 0.f;
    float m_DragX = 0.f;   // onde o arrastar começou (px da janela) e o deslocamento de então
    float m_DragY = 0.f;
    float m_DragOffsetX = 0.f;
    float m_DragOffsetY = 0.f;
    float m_Scale = 1.f;
    bool m_Moved = false;
    bool m_Save = false;
    bool m_Reset = false;
    bool m_Home = false;
    unsigned long long m_LastGold = 0;
    int m_LastLevel = -1;
    std::uint32_t m_SeenVersion = 0;
    long long m_SeenSecond = -1;

    UI::RmlBridge::ThemedView<LogCacaRmlModel> m_RmlView{"log_caca",
        [this](Rml::DataModelConstructor& c, LogCacaRmlModel& model) { BindRmlModel(c, model); },
        {{"Data/Interface/RmlUi/log_caca.rml"}}};
};
} // namespace mu::ui::window
