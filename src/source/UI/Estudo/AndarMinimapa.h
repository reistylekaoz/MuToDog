#pragma once

// MuToDog (MU Estudo): clicar com o botão direito no minimapa (Tab) anda até o ponto, como no cliente Godot
// (minimapa.gd ir_para + jogo.gd _andar_pelo_minimapa). O caminho do jogo (PathFinding2) só olha 500 casas e anda
// 15 passos por vez, então aqui o caminho sai de uma busca no mapa inteiro (TerrainWall) e o herói vai por ele em
// trechos de até 8 casas, pelo mesmo WalkTo do clique no chão; o próximo trecho só sai quando o anterior termina
// (o OpenMU corta caminho longo como speedhack). Para quando chega, quando troca de mapa, morre, ou quando a pessoa
// clica no chão ou ataca.

namespace mu::ui::window::AndarMinimapa
{
// Começa a andar até a casa (ou a casa livre mais perto dela, até 16 em volta). false: não dá pra chegar andando.
bool Ir(int tileX, int tileY);
// A cada quadro (MainScene, junto com o GolpeBoss).
void Update();
// O destino de agora, pra marca no minimapa. false sem destino.
bool Destino(int& tileX, int& tileY);
void Parar();
} // namespace mu::ui::window::AndarMinimapa
