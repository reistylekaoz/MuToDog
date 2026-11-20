#pragma once

// MuToDog (MU Estudo, rodada 20): o golpe especial e a aura da Séphora, no jeito do cliente Godot (golpe_boss.gd,
// aura_sephora.gd).
// - Golpe: o servidor (GameLogic/NPC/GolpeBoss.cs) decide quem morre e manda C1 FA 03 (aviso) e C1 FA 04 (impacto)
//   [id LE16, tipo, espera em décimos de segundo, quantas áreas, cada área (x, y, raio de dentro, raio de fora,
//   1 se for segura)]. Aqui só se desenha: a marca no chão enchendo até a hora do golpe (vermelha; a poça segura
//   azul), o aviso na barra do boss e, no impacto, 1 Chuva de Cinzas (um meteoro em cada círculo), 2 Coroa de Chamas
//   (fogo no anel em volta dela) e 3 Eclipse (tudo explode, menos as poças), com tremor da tela. Sem o pacote de
//   impacto, explode do mesmo jeito 0,8 s depois da hora.
// - Aura (o monstro 900 vivo na tela): círculo de magia no chão girando com um anel ao contrário, luz de fogo no chão,
//   brasas subindo e uma onda de choque a cada 4 s.

#include <cstdint>
#include <string>

namespace mu::ui::window::GolpeBoss
{
// C1 FA 03 e C1 FA 04 (WSclient.cpp, junto com a barra do boss).
void ReceivePacket(const std::uint8_t* packet, int size);
// A cada quadro, com os monstros (MainScene: depois das partículas).
void Update();
// As marcas no chão (MainScene: depois dos efeitos, fora do BeginSprite).
void RenderGround();
// As peças em sprite (MainScene: dentro do BeginSprite, depois das partículas).
void RenderSprites();
// O aviso do golpe que está pra cair ("Séphora: Eclipse! (entre numa poça azul)"), vazio sem golpe.
std::string Warning();
} // namespace mu::ui::window::GolpeBoss
