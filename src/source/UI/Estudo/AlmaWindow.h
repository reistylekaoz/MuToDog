#pragma once

// MuToDog (MU Estudo, rodada 10): Alma (Soul System), no jeito do cliente Godot (godot/scripts/janela_alma.gd) e pelo
// mesmo caminho do servidor (GameLogic/Alma.cs, BancoJoiasHandlerPlugIn): cada reset da pontos de alma, que vao em
// 16 elementos (4 abas de 4: Ataque, Defesa, Suporte, Diversos), ate 100 em cada. Cada ponto soma o bonus do elemento
// e aos 40, 70 e 100 pontos liga um bonus extra (vale o maior alcancado). Refazer devolve tudo e custa zen ou Jewel of
// Bless da mochila. C1 FB 50 pede o estado e o servidor responde C2 FB 50 [total LE16, livres LE16, 16 x pontos];
// C1 FB 51 [elemento, qtd] poe pontos; C1 FB 52 [0 zen, 1 joias] refaz (o servidor avisa o erro no chat e manda o
// estado de novo). Os numeros vem de Data/Interface/RmlUi/dados/alma.json (o mesmo do servidor e do Godot).

#include "UI/Core/WindowManager.h"
#include "UI/RmlBridge/RmlThemedView.h"

#include <RmlUi/Core/Types.h>

#include <cstdint>
#include <string>
#include <vector>

namespace mu::ui::window
{
struct AlmaMark
{
    Rml::String label; // "40 pontos"
    Rml::String value; // "+100"
    Rml::String look;  // "vale" (o maior alcancado), "aceso" ou "apagado"
    Rml::String top;   // a altura na barra, "123px"
};

struct AlmaCard
{
    Rml::String name;
    Rml::String icon; // "image(al-<n>)"
    Rml::String now;  // o que da agora (ou o do ponto, "por ponto")
    Rml::String points;
    Rml::String bar;  // a altura do que esta cheio, "54px"
    Rml::String markName;
    bool lit = false;
    bool full = false;
    bool canAdd = false;
    int element = 0;
    std::vector<AlmaMark> marks;
};

struct AlmaRmlModel
{
    int tab = 0;
    std::vector<Rml::String> tabs;
    Rml::String free;
    bool freeLit = false;
    std::vector<AlmaCard> cards;
    Rml::String foot;
    bool canRedo = false;
    bool confirm = false;
    Rml::String payZen;
    bool payZenOk = false;
    Rml::String payJewel;
    bool payJewelOk = false;
};

class CAlmaWindow : public CObject
{
public:
    CAlmaWindow();
    ~CAlmaWindow() override;

    bool Create(CManager* pNewUIMng);
    void Release();

    bool UpdateMouseEvent() override;
    bool UpdateKeyEvent() override;
    bool Update() override;
    bool Render() override;

    float GetLayerDepth() override;
    float GetKeyEventOrder() override;

    void Show(bool bShow) override;

    // C2 FB 50 (WSclient.cpp ProcessPacket).
    static void ReceivePacket(const std::uint8_t* packet, int size);

private:
    void BindRmlModel(Rml::DataModelConstructor& c, AlmaRmlModel& model);
    void RunPending();
    void Rebuild();
    std::string Signature() const;
    static void SendState();
    static void SendAdd(int element, int amount);
    static void SendRedo(bool jewels);

    CManager* m_pNewUIMng = nullptr;
    int m_PendingAction = 0;
    int m_PendingA = 0;
    int m_PendingB = 0;
    bool m_Dirty = true;
    bool m_InGame = false;
    std::uint32_t m_SeenVersion = 0;
    std::string m_SeenKey;

    UI::RmlBridge::ThemedView<AlmaRmlModel> m_RmlView{"alma",
        [this](Rml::DataModelConstructor& c, AlmaRmlModel& model) { BindRmlModel(c, model); },
        {{"Data/Interface/RmlUi/alma.rml"}}};
};
} // namespace mu::ui::window
