#pragma once

// MuToDog (MU Estudo, rodada 21): desempenho, no jeito do cliente Godot (jogo.gd, _qualidade_auto).
// - Corte automático: FPS abaixo de 25 por 6 s seguidos desliga o antisserrilhado (MSAA); se continuar baixo, as
//   sombras. Cada passo uma vez, gravado na config ([Render] Antialiasing e DisableBodyShadows), e o Option liga de
//   novo. Não conta os 10 s depois de entrar num mapa (o carregamento derruba o FPS) nem com o jogo sem foco.
//   Desliga pelo Option ([Render] AutoQualidade=0).
// - MU_PERF=1 no ambiente: escreve o FPS médio a cada 5 s na saída ("PERF mapa=.. fps=.. min=.. ..."), pra medir.

namespace mu::ui::window::Desempenho
{
// A cada quadro do jogo (MainScene, junto com o golpe da Séphora).
void Update();
} // namespace mu::ui::window::Desempenho
