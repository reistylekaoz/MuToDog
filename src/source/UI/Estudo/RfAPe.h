#pragma once

// MuToDog (MU Estudo): o Rage Fighter no Fenrir solta as skills a pé, como no cliente Godot (pedido do Murilo, 24/11:
// "quando usar as skills, o jogo usar as animações sem o fenrir, mesmo com ele equipado"). Enquanto ele está numa
// animação de skill do RF (PLAYER_SKILL_THRUST até PLAYER_SKILL_HP_UP_OURFORCES) e até 3 s depois da última, o lobo
// some (como na zona segura) e parado, andando e no golpe ele usa as animações a pé. Vale pra qualquer RF na tela.

class OBJECT;

namespace mu::ui::window::RfAPe
{
// A cada quadro, pela montaria (MoveMount): marca o dono que está numa animação de skill do RF.
void Observar(const OBJECT* dono);
// Se o dono está a pé por causa de uma skill (na animação ou até 3 s depois dela).
bool APe(const OBJECT* dono);
} // namespace mu::ui::window::RfAPe
