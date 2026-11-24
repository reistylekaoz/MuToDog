#pragma once

// MuToDog (MU Estudo): no Fenrir as skills saem a pé, como no cliente Godot. Começou no Rage Fighter (pedido do
// Murilo, 24/11: "quando usar as skills, o jogo usar as animações sem o fenrir, mesmo com ele equipado") e vale pra
// todas as classes menos o Dark Lord ("Consegue fazer o mesmo processo do fenrir com todos os personagens exceto o
// DL?"). Quando ele solta a skill e até 3 s depois, o lobo some (como na zona segura) e as animações (skill, parado,
// andando, golpe) são as de quem está a pé; passados os 3 s ele monta de novo. Vale pra qualquer jogador na tela.
// A Plasma Storm (a skill do próprio Fenrir) continua montada.

class OBJECT;
class CHARACTER;

namespace mu::ui::window::RfAPe
{
// Quem soltou a skill (o herói ao usar, os outros pelo pacote da skill): fica a pé por 3 s se estiver no Fenrir.
// Não vale pro Dark Lord nem pra Plasma Storm (essa devolve ele pro lobo na hora).
void Marcar(CHARACTER* c, int skill);
// A cada quadro, pela montaria (MoveMount): marca o RF na animação de skill e devolve pro lobo quem passou dos 3 s.
void Observar(const OBJECT* dono);
// Se o dono está a pé por causa de uma skill (na animação do RF ou até 3 s depois da última).
bool APe(const OBJECT* dono);
// Se ele está montado no Fenrir agora (equipado e não a pé por causa de uma skill).
bool NoFenrir(const CHARACTER* c);
// A montaria que vale pras animações: a do equipamento, ou nenhuma (-1) com o Fenrir guardado pela skill.
int Montaria(const CHARACTER* c);
} // namespace mu::ui::window::RfAPe
