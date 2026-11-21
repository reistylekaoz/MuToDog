#include "stdafx.h"
#include "UI/Estudo/Desempenho.h"
#include "App/Platform/Windows/Winmain.h"
#include "Data/GameConfig/GameConfig.h"
#include "Engine/Object/ZzzCharacter.h"
#include "Render/Renderer/MuRenderer.h"
#include "Render/Textures/ZzzOpenglUtil.h"
#include "Scenes/MainScene.h"
#include "UI/Core/WindowSystem.h"
#include "UI/HUD/ChatLogWindow.h"
#include "World/MapInfra/MapManager.h"
#include <algorithm>
#include <chrono>
#include <cstdio>
#include <SDL3/SDL_stdinc.h>

namespace
{
constexpr double kFpsBaixo = 25.0;
constexpr int kSegundosBaixo = 6;
constexpr double kEsperaMapa = 10.0;

using Relogio = std::chrono::steady_clock;

int s_mapa = -2;
Relogio::time_point s_espera_ate{};
Relogio::time_point s_proximo_segundo{};
int s_baixo = 0;
int s_quadros = 0;

// MU_PERF=1: FPS médio, mínimo e máximo por janela de 5 s.
bool s_perf = false;
bool s_perf_lido = false;
Relogio::time_point s_perf_inicio{};
int s_perf_quadros = 0;
double s_perf_min = 1e9;
double s_perf_max = 0.0;

void Aviso(const wchar_t* texto)
{
    if (g_pSystemLogBox)
        g_pSystemLogBox->AddText(texto, mu::ui::window::TYPE_SYSTEM_MESSAGE);
}

int ContarPersonagens()
{
    int n = 0;
    for (int i = 0; i < MAX_CHARACTERS_CLIENT; ++i)
    {
        const CHARACTER* c = &CharactersClient[i];
        if (c->Object.Live && c->Object.Kind == KIND_PLAYER)
            ++n;
    }
    return n;
}

void MedirPerf(Relogio::time_point agora)
{
    if (!s_perf_lido)
    {
        const char* v = SDL_getenv("MU_PERF");
        s_perf = v && v[0] == '1';
        s_perf_lido = true;
        s_perf_inicio = agora;
    }
    if (!s_perf)
        return;
    ++s_perf_quadros;
    s_perf_min = std::min(s_perf_min, FPS);
    s_perf_max = std::max(s_perf_max, FPS);
    const double seg = std::chrono::duration<double>(agora - s_perf_inicio).count();
    if (seg < 5.0)
        return;
    std::printf("PERF mapa=%d fps=%.1f min=%.1f max=%.1f jogadores=%d msaa=%d sombras=%d auto=%d\n",
                gMapManager.WorldActive, s_perf_quadros / seg, s_perf_min, s_perf_max, ContarPersonagens(),
                mu::GetRenderer().GetAntialiasingSamples(), GameConfig::GetInstance().GetDisableBodyShadows() ? 0 : 1,
                GameConfig::GetInstance().GetAutoQualidade() ? 1 : 0);
    std::fflush(stdout);
    s_perf_inicio = agora;
    s_perf_quadros = 0;
    s_perf_min = 1e9;
    s_perf_max = 0.0;
}
} // namespace

void mu::ui::window::Desempenho::Update()
{
    const Relogio::time_point agora = Relogio::now();
    MedirPerf(agora);

    if (gMapManager.WorldActive != s_mapa)
    {
        s_mapa = gMapManager.WorldActive;
        s_espera_ate = agora + std::chrono::duration_cast<Relogio::duration>(std::chrono::duration<double>(kEsperaMapa));
        s_baixo = 0;
        s_quadros = 0;
        s_proximo_segundo = s_espera_ate + std::chrono::seconds(1);
    }
    GameConfig& config = GameConfig::GetInstance();
    if (!config.GetAutoQualidade() || agora < s_espera_ate)
        return;
    // Sem foco o Windows segura os quadros: não conta (o teste daqui, MU_PERF=1, conta sempre).
    if (!s_perf && GetFocus() != g_hWnd)
    {
        s_baixo = 0;
        s_quadros = 0;
        s_proximo_segundo = agora + std::chrono::seconds(1);
        return;
    }
    ++s_quadros;
    if (agora < s_proximo_segundo)
        return;
    const double seg = 1.0 + std::chrono::duration<double>(agora - s_proximo_segundo).count();
    const double fps = s_quadros / seg;
    s_quadros = 0;
    s_proximo_segundo = agora + std::chrono::seconds(1);
    s_baixo = fps < kFpsBaixo ? s_baixo + 1 : 0;
    if (s_baixo < kSegundosBaixo)
        return;
    s_baixo = 0;
    if (mu::GetRenderer().GetAntialiasingSamples() > 1)
    {
        MuSetAntialiasingPreference(0);
        Aviso(L"FPS baixo: desliguei o antisserrilhado. Pra ligar de novo: Option > Graphics > Antisserrilhado (MSAA).");
        std::printf("TESTE qualidade auto: msaa desligado (%.1f fps)\n", fps);
        std::fflush(stdout);
    }
    else if (!config.GetDisableBodyShadows())
    {
        SetDisableBodyShadows(true);
        config.SetDisableBodyShadows(true);
        config.Save();
        Aviso(L"FPS baixo: desliguei as sombras. Pra voltar: Option > Graphics > Sombras e desempenho, desmarque Desligar as sombras.");
        std::printf("TESTE qualidade auto: sombras desligadas (%.1f fps)\n", fps);
        std::fflush(stdout);
    }
}
