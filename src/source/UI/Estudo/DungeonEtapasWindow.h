#pragma once

// MuToDog (MU Estudo, 24/11): a Dungeon das 3 etapas no MuMain, no jeito do cliente Godot (janela_dungeon.gd,
// painel_dungeon.gd, minimapa.gd) e com os mesmos pacotes do servidor (DungeonEtapasContext.cs):
// - C1 FA 21 [lider]: falou com o Guardião (NPC 913). O líder (ou quem está sozinho) escolhe a dificuldade e Confirmar
//   manda "/dungeon <dificuldade>" no chat; quem é da party só entra na do líder ("/dungeon").
// - C1 FA 20 [estado, segundos LE16, vivos LE16, etapa, chefes mortos, chefes do andar, lider, dificuldade], a cada
//   segundo: o painel no canto inferior direito (esperando a party com "Iniciar agora" pro líder, jogando com "m de t"
//   chefes, e o fim). Some 3 s depois do último.
// - C2 FA 22 [quantos, (x, y, tipo) ...]: o que está na parte revelada (0 horda, 1 subchefe, 2 boss, 3 portal), pro
//   minimapa (Tab).
// - C1 FA 25 [etapa de destino]: pisou ou clicou no portal (24/11); a caixa pergunta e "Ir agora" manda
//   "/dungeon portal". No fim (estado 2 do FA 20) os segundos são o que falta pra ir pra Lorencia.
// - C2 FA 24 [andar, 512 bytes]: a névoa da party, 64 x 64 casas de 4 x 4 tiles, bit (y/4)*64 + x/4 = revelada. Vira
//   uma textura de 64 x 64 (FogSource) que o minimapa põe por cima do mapa.

#include "UI/Core/WindowManager.h"
#include "UI/RmlBridge/RmlThemedView.h"

#include <RmlUi/Core/Types.h>

#include <cstdint>
#include <string>
#include <vector>

namespace mu::ui::window
{
struct DungeonDifficultyRow
{
    Rml::String name;
    Rml::String note;
    int index = 0;
};

struct DungeonEtapasRmlModel
{
    bool panel = false;    // o painel do canto (chegou FA 20 há menos de 3 s)
    int state = 0;         // 0 esperando a party, 1 jogando, 2 fim
    Rml::String title;     // "Dungeon · Normal"
    Rml::String line;      // "Etapa 2 de 3 · 40 monstros"
    Rml::String big;       // "1:45" ou "2 de 3"
    Rml::String hint;
    bool startButton = false;

    bool guard = false;    // o diálogo do Guardião
    bool leader = true;
    int choice = 1;
    std::vector<DungeonDifficultyRow> difficulties;
    Rml::String confirm;   // "Confirmar (Normal)"

    bool portal = false;   // a caixa do portal (C1 FA 25)
    Rml::String portalText; // "Ir para a Etapa 2 de 3?"
};

class CDungeonEtapasWindow : public CObject
{
public:
    struct Point
    {
        int x = 0;
        int y = 0;
        int type = 0; // 0 horda, 1 subchefe, 2 boss, 3 portal
    };

    CDungeonEtapasWindow();
    ~CDungeonEtapasWindow() override;

    bool Create(CManager* pNewUIMng);
    void Release();

    bool UpdateMouseEvent() override;
    bool UpdateKeyEvent() override;
    bool Update() override;
    bool Render() override;

    float GetLayerDepth() override;
    float GetKeyEventOrder() override;

    void Show(bool bShow) override;

    // C1 FA 20, C1 FA 21, C2 FA 22 e C2 FA 24 (WSclient.cpp ProcessPacket).
    static void ReceivePacket(const std::uint8_t* packet, int size);

    // Pro minimapa: dentro da dungeon (painel vivo no mapa 90)?
    static bool Active();
    // As marcas do último FA 22 (vazio fora da dungeon).
    static const std::vector<Point>& Points();
    // "estudo:nevoa-dungeon" com a névoa pronta na textura, "" sem névoa. Chamar do quadro (sobe a textura).
    static Rml::String FogSource();
    // Pro RmlUiRenderInterface (RmlRuntimeHooks.cpp): se `source` é a névoa, e a textura por trás dela.
    static bool IsFogSource(const Rml::String& source);
    static void* ResolveFog(int& width, int& height);

private:
    void BindRmlModel(Rml::DataModelConstructor& c, DungeonEtapasRmlModel& model);
    void RunPending();
    void Rebuild();
    static void SendChat(const char* text);

    CManager* m_pNewUIMng = nullptr;
    int m_PendingAction = 0;
    int m_PendingChoice = -1;
    std::string m_BuiltKey;

    UI::RmlBridge::ThemedView<DungeonEtapasRmlModel> m_RmlView{"dungeon_etapas",
        [this](Rml::DataModelConstructor& c, DungeonEtapasRmlModel& model) { BindRmlModel(c, model); },
        {{"Data/Interface/RmlUi/dungeon_etapas.rml"}}};
};
} // namespace mu::ui::window
