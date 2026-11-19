#pragma once

// MuToDog (MU Estudo, rodada 11): Horário dos eventos (tecla H), no jeito do cliente Godot (godot/scripts/janela_eventos.gd,
// o "Events Timer" da MuDream): um cartão por evento com a arte, o nome, a contagem até abrir (ou até fechar, se está
// aberto), o próximo horário em Brasília e a faixa de nível com o cadeado (dourado = seu nível entra). 4 cartões por
// página, setas embaixo. C1 FB 20 pede e o servidor responde C2 FB 20 [n] + n x [tipo, duração LE16, nível mín LE16,
// nível máx LE16, n horas, horas LE16 (minutos do dia, UTC)] (GameLogic/AgendaEventos.cs, o mesmo Timetable do site).

#include "UI/Core/WindowManager.h"
#include "UI/RmlBridge/RmlThemedView.h"

#include <RmlUi/Core/Types.h>

#include <cstdint>
#include <ctime>
#include <string>
#include <vector>

namespace mu::ui::window
{
struct EventosCard
{
    Rml::String name;
    Rml::String art; // "image(ev-<arte>)"
    Rml::String about;
    Rml::String count; // "Abre em 01 : 02 : 03"
    Rml::String next;  // "20:00, 15 min"
    Rml::String level; // "Nível 15 a 80" ou "Todos os níveis"
    bool open = false;
    bool enter = false;
};

struct EventosRmlModel
{
    Rml::String clock;
    Rml::String status;
    std::vector<EventosCard> cards;
    Rml::String page;
    bool canPrev = false;
    bool canNext = false;
};

class CEventosWindow : public CObject
{
public:
    CEventosWindow();
    ~CEventosWindow() override;

    bool Create(CManager* pNewUIMng);
    void Release();

    bool UpdateMouseEvent() override;
    bool UpdateKeyEvent() override;
    bool Update() override;
    bool Render() override;

    float GetLayerDepth() override;
    float GetKeyEventOrder() override;

    void Show(bool bShow) override;

    // C2 FB 20 (WSclient.cpp ProcessPacket).
    static void ReceivePacket(const std::uint8_t* packet, int size);

private:
    void BindRmlModel(Rml::DataModelConstructor& c, EventosRmlModel& model);
    void RunPending();
    void Rebuild();
    static void SendRequest();

    CManager* m_pNewUIMng = nullptr;
    int m_PendingAction = 0;
    int m_Page = 0;
    bool m_Dirty = true;
    bool m_InGame = false;
    std::uint32_t m_SeenVersion = 0;
    std::time_t m_SeenSecond = 0;
    std::time_t m_AskedAt = 0;

    UI::RmlBridge::ThemedView<EventosRmlModel> m_RmlView{"eventos",
        [this](Rml::DataModelConstructor& c, EventosRmlModel& model) { BindRmlModel(c, model); },
        {{"Data/Interface/RmlUi/eventos.rml"}}};
};
} // namespace mu::ui::window
