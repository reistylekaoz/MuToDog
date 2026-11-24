#include "stdafx.h"

#include "UI/Estudo/RfAPe.h"

#include "Engine/Object/ZzzCharacter.h"
#include "Engine/Object/ZzzObject.h"
#include "Character/CharacterManager.h"

#include <chrono>
#include <cstdint>
#include <unordered_map>

namespace mu::ui::window::RfAPe
{
namespace
{
// Quanto tempo ele fica a pé depois da última skill (o cliente Godot também espera 3 s).
constexpr std::uint32_t EsperaMs = 3000;

// A hora da última animação de skill de cada dono (o OBJECT do personagem).
std::unordered_map<const OBJECT*, std::uint32_t> g_ultimaSkill;

std::uint32_t Agora()
{
    using namespace std::chrono;
    return static_cast<std::uint32_t>(duration_cast<milliseconds>(steady_clock::now().time_since_epoch()).count());
}

bool NaSkillDoRf(const OBJECT* dono)
{
    return dono->CurrentAction >= PLAYER_SKILL_THRUST && dono->CurrentAction <= PLAYER_SKILL_HP_UP_OURFORCES;
}
} // namespace

// Passados os 3 s, ele volta pro lobo: parado ou andando, com a animação montada (a pé ficaria em pé em cima dele).
static void Voltar(const OBJECT* dono)
{
    for (int i = 0; i < MAX_CHARACTERS_CLIENT; ++i)
    {
        CHARACTER* c = &CharactersClient[i];
        if (&c->Object != dono)
        {
            continue;
        }
        if (c->Dead == 0)
        {
            if (c->Movement)
            {
                SetPlayerWalk(c, false);
            }
            else
            {
                SetPlayerStop(c, false);
            }
        }
        return;
    }
}

void Observar(const OBJECT* dono)
{
    if (dono == nullptr)
    {
        return;
    }
    if (NaSkillDoRf(dono))
    {
        g_ultimaSkill[dono] = Agora();
        return;
    }
    const auto it = g_ultimaSkill.find(dono);
    if (it != g_ultimaSkill.end() && Agora() - it->second >= EsperaMs)
    {
        g_ultimaSkill.erase(it);
        Voltar(dono);
    }
}

void Marcar(CHARACTER* c, int skill)
{
    if (c == nullptr || c->Object.Type != MODEL_PLAYER || c->Helper.Type != MODEL_HORN_OF_FENRIR ||
        gCharacterManager.GetBaseClass(c->Class) == CLASS_DARK_LORD)
    {
        return;
    }
    if (skill == AT_SKILL_PLASMA_STORM_FENRIR)
    {
        g_ultimaSkill.erase(&c->Object);
        return;
    }
    g_ultimaSkill[&c->Object] = Agora();
}

bool NoFenrir(const CHARACTER* c)
{
    return c->Helper.Type == MODEL_HORN_OF_FENRIR && !APe(&c->Object);
}

int Montaria(const CHARACTER* c)
{
    return c->Helper.Type == MODEL_HORN_OF_FENRIR && APe(&c->Object) ? -1 : c->Helper.Type;
}

bool APe(const OBJECT* dono)
{
    if (dono == nullptr)
    {
        return false;
    }
    if (NaSkillDoRf(dono))
    {
        return true;
    }
    const auto it = g_ultimaSkill.find(dono);
    if (it == g_ultimaSkill.end())
    {
        return false;
    }
    // Quem apaga a marca é o Observar (uma vez por quadro, pela montaria), que também devolve ele pro lobo.
    return Agora() - it->second < EsperaMs;
}
} // namespace mu::ui::window::RfAPe
