#pragma once

// MuToDog (MU Estudo, rodada 11): barra do boss no topo da tela, no jeito do cliente Godot (godot/scripts/barra_boss.gd,
// a barra da MuDream): o nome, a vida em 10 barras de cor (a de baixo aparece na cor da próxima, o marcador 10X ... 2X,
// a última vermelha sem marcador) com o rastro claro do dano, e embaixo a disputa de dano: quem tem o direito ao drop
// (pisca quando troca) e o meu dano e a minha posição. O servidor (GameLogic/NPC/DisputaDano.cs) manda C1 FA 01 a cada
// meio segundo pra quem está a até 20 tiles do boss [id LE16, número LE16, vida LE32, vida máx LE32, dano do líder
// LE32, meu dano LE32, minha posição, quantos, nome do líder (10)] e C1 FA 02 no fim [id LE16, resultado (0 morreu,
// 1 ninguém mais na disputa), vencedor (10)]. Some 2 s depois do último pacote; o texto do fim fica 6 s. Não pega o
// mouse nem as teclas.

#include "UI/Core/WindowManager.h"
#include "UI/RmlBridge/RmlThemedView.h"

#include <RmlUi/Core/Types.h>

#include <cstdint>
#include <string>

namespace mu::ui::window
{
struct BossBarRmlModel
{
    Rml::String name;
    Rml::String under;      // a cor da barra de baixo, "none" se é a última
    Rml::String color;      // a cor da barra de agora
    Rml::String fill;       // a largura da barra de agora, "123px"
    Rml::String trail;      // a largura do rastro claro
    Rml::String marker;     // "10X" ... "2X", vazio na última
    Rml::String markerColor;
    Rml::String hp;         // "1.234 / 150.000.000  (1%)"
    Rml::String end;        // "Séphora derrotada! O drop é de Fulano"
    Rml::String leader;     // "Direito ao drop: você · 1.234 de dano"
    Rml::String leaderLook; // "eu", "outro" ou "pisca"
    Rml::String me;
    bool contest = false;   // tem disputa (os bosses da Dungeon das 3 etapas só mostram a vida)
    bool bar = false;       // a barra (some quando só o aviso do golpe está na tela)
    Rml::String golpe;      // o aviso do golpe especial (GolpeBoss.cpp), vazio sem golpe
};

class CBossBarWindow : public CObject
{
public:
    CBossBarWindow();
    ~CBossBarWindow() override;

    bool Create(CManager* pNewUIMng);
    void Release();

    bool UpdateMouseEvent() override;
    bool UpdateKeyEvent() override;
    bool Update() override;
    bool Render() override;

    float GetLayerDepth() override;
    float GetKeyEventOrder() override;

    // C1 FA 01 e C1 FA 02 (WSclient.cpp ProcessPacket).
    static void ReceivePacket(const std::uint8_t* packet, int size);

private:
    void BindRmlModel(Rml::DataModelConstructor& c, BossBarRmlModel& model);
    void Rebuild(std::uint32_t now);

    CManager* m_pNewUIMng = nullptr;
    std::uint32_t m_LastTick = 0;
    float m_Trail = 1.f;

    UI::RmlBridge::ThemedView<BossBarRmlModel> m_RmlView{"boss_bar",
        [this](Rml::DataModelConstructor& c, BossBarRmlModel& model) { BindRmlModel(c, model); },
        {{"Data/Interface/RmlUi/boss_bar.rml"}}};
};
} // namespace mu::ui::window
