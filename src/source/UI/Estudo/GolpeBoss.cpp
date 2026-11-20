#include "stdafx.h"
#include "UI/Estudo/GolpeBoss.h"

#include "Core/Text/Utf8.h"
#include "Data/GameData/MonsterData/MonsterDatabase.h"
#include "Engine/AI/ZzzAI.h"
#include "Engine/Object/ZzzCharacter.h"
#include "Engine/Object/ZzzObject.h"
#include "Render/Terrain/ZzzLodTerrain.h"
#include "Render/Textures/ZzzOpenglUtil.h"
#include "Scenes/SceneCore.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cwchar>
#include <random>
#include <vector>

namespace mu::ui::window::GolpeBoss
{
namespace
{
constexpr int Sephora = 900;
constexpr float Tile = TERRAIN_SCALE;
constexpr float Pi = 3.14159265f;
constexpr size_t MaxPieces = 400; // perto dela o PC do Murilo já caiu a 8 fps no Godot: pouca peça de cada vez
constexpr float Red[3] = {1.f, 0.18f, 0.04f};
constexpr float Blue[3] = {0.3f, 0.75f, 1.f};
constexpr float Ember[3] = {1.f, 0.35f, 0.08f};

const char* const Names[] = {"", "Chuva de Cinzas", "Coroa de Chamas", "Eclipse"};
const char* const Hints[] = {"", "saia do círculo vermelho", "cole nela ou fuja pra longe", "entre numa poça azul"};

struct Area
{
    float x = 0.f; // centro no mundo
    float y = 0.f;
    float inner = 0.f; // raios em tiles
    float outer = 0.f;
    bool safe = false;
};

struct Strike
{
    int id = 0;
    int kind = 1;
    float wait = 3.f;
    float age = 0.f;
    bool exploded = false;
    float sinceImpact = 0.f;
    std::string boss;
    std::vector<Area> areas;
};

// uma peça em sprite: anda, cresce ou encolhe e apaga até o fim da vida (mistura aditiva: apagar é escurecer)
struct Piece
{
    int texture = 0;
    float pos[3] = {};
    float vel[3] = {};
    float gravity = 0.f;
    float size0 = 100.f;
    float size1 = 100.f;
    float color[3] = {1.f, 1.f, 1.f};
    float delay = 0.f;
    float life = 1.f;
    float age = 0.f;
    float rotation = 0.f;
    float spin = 0.f;
    int frames = 0; // explosão: quadros da folha 4 x 4
    bool fadeIn = false;
};

struct Wave
{
    float x = 0.f;
    float y = 0.f;
    float age = 0.f;
};

std::vector<Strike> g_Strikes;
std::vector<Piece> g_Pieces;
std::vector<Wave> g_Waves;
float g_Shake = 0.f;
float g_EmberClock = 0.f;
float g_WaveClock = 2.f;
float g_Time = 0.f;
int g_AuraIndex = -1; // a Séphora na tela neste quadro
std::uint32_t g_LastMs = 0;
std::mt19937 g_Random{20112026u};

float Rand(float a, float b)
{
    return std::uniform_real_distribution<float>(a, b)(g_Random);
}

std::uint32_t NowMs()
{
    using namespace std::chrono;
    return static_cast<std::uint32_t>(duration_cast<milliseconds>(steady_clock::now().time_since_epoch()).count());
}

float Ground(float x, float y)
{
    return RequestTerrainHeight(x, y);
}

Piece& Add(int texture, float x, float y, float z, float size0, float size1, const float color[3], float life,
           float delay = 0.f)
{
    if (g_Pieces.size() >= MaxPieces)
        g_Pieces.erase(g_Pieces.begin());
    Piece& p = g_Pieces.emplace_back();
    p.texture = texture;
    p.pos[0] = x;
    p.pos[1] = y;
    p.pos[2] = z;
    p.size0 = size0;
    p.size1 = size1;
    std::copy(color, color + 3, p.color);
    p.life = life;
    p.delay = delay;
    p.rotation = Rand(0.f, 360.f);
    return p;
}

void Explosion(float x, float y, float radius, float delay)
{
    const float z = Ground(x, y);
    const float white[3] = {1.f, 1.f, 1.f};
    Piece& e = Add(BITMAP_EXPLOTION, x, y, z + radius * Tile * 0.5f, radius * Tile * 2.2f, radius * Tile * 2.4f, white,
                   0.8f, delay);
    e.frames = 10;
    e.rotation = 0.f;
    Add(BITMAP_LIGHT, x, y, z + Tile, radius * Tile * 3.f, radius * Tile * 1.f, Red, 0.35f, delay);
    const float spark[3] = {1.f, 0.6f, 0.2f};
    for (int i = 0; i < 8; ++i)
    {
        const float a = Rand(0.f, 2.f * Pi);
        const float s = Rand(200.f, 500.f);
        Piece& p = Add(BITMAP_SPARK, x, y, z + 40.f, 50.f, 20.f, spark, Rand(0.7f, 1.2f), delay);
        p.vel[0] = std::cos(a) * s;
        p.vel[1] = std::sin(a) * s;
        p.vel[2] = Rand(300.f, 700.f);
        p.gravity = 1400.f;
    }
    const float smoke[3] = {0.35f, 0.12f, 0.05f};
    Piece& s = Add(BITMAP_SMOKE, x + Rand(-60.f, 60.f), y + Rand(-60.f, 60.f), z + 80.f, radius * Tile,
                   radius * Tile * 1.8f, smoke, 1.6f, delay + 0.2f);
    s.vel[2] = 60.f;
}

void Meteor(const Area& a)
{
    const float z = Ground(a.x, a.y);
    constexpr float Fall = 0.45f;
    constexpr float Height = 1400.f;
    Piece& head = Add(BITMAP_LIGHT, a.x, a.y, z + Height, 300.f, 260.f, Red, Fall);
    head.vel[2] = -Height / Fall;
    const float fire[3] = {1.f, 0.6f, 0.2f};
    for (int i = 0; i < 6; ++i)
    {
        Piece& f = Add(BITMAP_FIRE, a.x, a.y, z + Height + i * 60.f, 220.f - i * 25.f, 120.f, fire, Fall);
        f.vel[2] = -Height / Fall;
        f.spin = 480.f;
    }
    Explosion(a.x, a.y, std::max(a.outer, 1.5f), Fall);
}

void Crown(const Area& a)
{
    const float flame[3] = {1.f, 0.45f, 0.1f};
    for (int i = 0; i < 28; ++i)
    {
        const float ang = Rand(0.f, 2.f * Pi);
        const float r = Rand(a.inner + 0.5f, a.outer) * Tile;
        const float x = a.x + std::cos(ang) * r;
        const float y = a.y + std::sin(ang) * r;
        const float z = Ground(x, y);
        const float delay = Rand(0.f, 0.3f);
        Piece& f = Add(BITMAP_FIRE, x, y, z + 50.f, 180.f, 70.f, flame, 1.1f, delay);
        f.vel[2] = Rand(250.f, 420.f);
        Piece& g = Add(BITMAP_FLAME, x, y, z + 150.f, 250.f, 400.f, Red, 0.9f, delay);
        g.vel[2] = 400.f;
        if (i % 4 == 0)
            Explosion(x, y, 2.f, delay);
    }
    Wave& w = g_Waves.emplace_back();
    w.x = a.x;
    w.y = a.y;
}

void Eclipse(const Strike& s)
{
    const Area& big = s.areas.front();
    const float flare[3] = {1.f, 0.4f, 0.15f};
    Add(BITMAP_LIGHT, big.x, big.y, Ground(big.x, big.y) + 500.f, 3000.f, 600.f, flare, 0.5f);
    for (int i = 0, made = 0; i < 80 && made < 26; ++i)
    {
        const float ang = Rand(0.f, 2.f * Pi);
        const float r = std::sqrt(Rand(0.f, 1.f)) * big.outer * Tile;
        const float x = big.x + std::cos(ang) * r;
        const float y = big.y + std::sin(ang) * r;
        bool inPool = false;
        for (const Area& a : s.areas)
        {
            if (a.safe && std::hypot(x - a.x, y - a.y) <= (a.outer + 0.5f) * Tile)
                inPool = true;
        }
        if (inPool)
            continue;
        Explosion(x, y, Rand(1.5f, 2.2f), Rand(0.f, 0.6f));
        ++made;
    }
    for (const Area& a : s.areas)
    {
        if (a.safe)
            Add(BITMAP_LIGHT, a.x, a.y, Ground(a.x, a.y) + 100.f, 400.f, 100.f, Blue, 1.f);
    }
}

void Explode(Strike& s)
{
    if (s.exploded)
        return;
    s.exploded = true;
    s.sinceImpact = 0.f;
    g_Shake = 0.6f;
    if (s.kind == 1)
    {
        for (const Area& a : s.areas)
            Meteor(a);
    }
    else if (s.kind == 2 && !s.areas.empty())
    {
        Crown(s.areas.front());
    }
    else if (!s.areas.empty())
    {
        Eclipse(s);
    }
}

std::string ShortName(int number)
{
    const wchar_t* name = ::Data::Monsters::GetMonsterName(number);
    if (name == nullptr || name[0] == L'\0' || std::wcscmp(name, L"()") == 0)
        return "Boss";
    const std::string text = ::Core::Text::ToUtf8(name);
    return text.substr(0, text.find(','));
}

// a marca de uma área: a cor por baixo e o enchimento até a hora do golpe
void RenderArea(const Strike& s, const Area& a)
{
    const float size = 2.f * (a.outer + 0.5f);
    const float progress = std::clamp(s.age / std::max(s.wait, 0.1f), 0.f, 1.f);
    const float fade = s.exploded ? std::clamp(1.f - s.sinceImpact / 0.5f, 0.f, 1.f) : 1.f;
    const float pulse = 0.8f + 0.2f * std::sin(g_Time * 8.f);
    const float* color = a.safe ? Blue : Red;
    const bool ring = a.inner > 0.f && !a.safe;
    const int texture = ring ? BITMAP_ESTUDO_GOLPE_ANEL : BITMAP_ESTUDO_GOLPE_DISCO;
    vec3_t light;
    const float base = (a.safe ? 0.7f : 0.4f) * pulse * fade;
    Vector(color[0] * base, color[1] * base, color[2] * base, light);
    RenderTerrainAlphaBitmap(texture, a.x, a.y, size, size, light, g_Time * 20.f);
    if (a.safe || s.exploded)
        return;
    // enchendo: o disco cresce até a borda, o anel acende
    const float fill = ring ? 0.3f + 0.6f * progress : 0.6f;
    const float fillSize = ring ? size : std::max(0.2f, size * progress);
    Vector(color[0] * fill, color[1] * fill, color[2] * fill, light);
    RenderTerrainAlphaBitmap(texture, a.x, a.y, fillSize, fillSize, light, -g_Time * 20.f);
}

void UpdateAura(float dt)
{
    g_AuraIndex = -1;
    const int index = FindCharacterIndexByMonsterIndex(Sephora);
    if (index >= MAX_CHARACTERS_CLIENT)
        return;
    CHARACTER* c = &CharactersClient[index];
    OBJECT* o = &c->Object;
    if (!o->Live || !o->Visible || c->Dead > 0.f || o->CurrentAction == MONSTER01_DIE)
        return;
    g_AuraIndex = index;
    const float x = o->Position[0];
    const float y = o->Position[1];
    const float flicker = 0.75f + 0.25f * std::sin(g_Time * 13.f) * std::sin(g_Time * 7.f);
    vec3_t light;
    Vector(Ember[0] * flicker, Ember[1] * flicker, Ember[2] * flicker, light);
    AddTerrainLight(x, y, light, 5, PrimaryTerrainLight);

    // brasas subindo em volta
    g_EmberClock -= dt;
    while (g_EmberClock <= 0.f)
    {
        g_EmberClock += 0.06f;
        const float a = Rand(0.f, 2.f * Pi);
        const float r = Rand(0.5f, 4.f) * Tile;
        const float px = x + std::cos(a) * r;
        const float py = y + std::sin(a) * r;
        Piece& p = Add(BITMAP_LIGHT, px, py, Ground(px, py) + Rand(20.f, 120.f), Rand(25.f, 45.f), 8.f, Ember,
                       Rand(1.f, 1.8f));
        p.vel[0] = Rand(-30.f, 30.f);
        p.vel[1] = Rand(-30.f, 30.f);
        p.vel[2] = Rand(90.f, 180.f);
        p.fadeIn = true;
    }
    // onda de choque a cada 4 s
    g_WaveClock -= dt;
    if (g_WaveClock <= 0.f)
    {
        g_WaveClock = 4.f;
        Wave& w = g_Waves.emplace_back();
        w.x = x;
        w.y = y;
    }
}
} // namespace

void ReceivePacket(const std::uint8_t* packet, int size)
{
    if (packet == nullptr || size < 9 || packet[0] != 0xC1 || packet[2] != 0xFA)
        return;
    if (packet[3] != 0x03 && packet[3] != 0x04)
        return;
    const int id = packet[4] | (packet[5] << 8);
    if (packet[3] == 0x04)
    {
        for (Strike& s : g_Strikes)
        {
            if (s.id == id)
                Explode(s);
        }
        return;
    }
    const int count = packet[8];
    if (size < 9 + count * 5)
        return;
    std::erase_if(g_Strikes, [id](const Strike& s) { return s.id == id; });
    Strike& s = g_Strikes.emplace_back();
    s.id = id;
    s.kind = std::clamp<int>(packet[6], 1, 3);
    s.wait = std::max(0.5f, packet[7] / 10.f);
    for (int i = 0; i < count; ++i)
    {
        const std::uint8_t* p = packet + 9 + i * 5;
        Area a;
        a.x = (p[0] + 0.5f) * Tile;
        a.y = (p[1] + 0.5f) * Tile;
        a.inner = p[2];
        a.outer = p[3];
        a.safe = p[4] != 0;
        s.areas.push_back(a);
    }
    s.boss = "Boss";
    const int index = FindCharacterIndex(id);
    if (index >= 0 && index < MAX_CHARACTERS_CLIENT)
    {
        CHARACTER* c = &CharactersClient[index];
        s.boss = ShortName(c->MonsterIndex);
        // ela levanta o cetro (a magia) na hora do aviso, como no Godot
        SetAction(&c->Object, MONSTER01_ATTACK2);
    }
    // poça segura: luz azul subindo enquanto espera
    for (const Area& a : s.areas)
    {
        if (!a.safe)
            continue;
        for (float t = 0.f; t < s.wait; t += 0.12f)
        {
            const float ang = Rand(0.f, 2.f * Pi);
            const float r = Rand(0.f, a.outer * 0.8f) * Tile;
            const float x = a.x + std::cos(ang) * r;
            const float y = a.y + std::sin(ang) * r;
            Piece& p = Add(BITMAP_LIGHT, x, y, Ground(x, y) + 10.f, 60.f, 10.f, Blue, 1.2f, t);
            p.vel[2] = Rand(200.f, 400.f);
        }
    }
}

void Update()
{
    const std::uint32_t now = NowMs();
    const float dt = g_LastMs == 0 ? 0.f : std::clamp((now - g_LastMs) / 1000.f, 0.f, 0.1f);
    g_LastMs = now;
    g_Time += dt;
    if (SceneFlag != MAIN_SCENE || Hero == nullptr)
    {
        g_Strikes.clear();
        g_Pieces.clear();
        g_Waves.clear();
        g_AuraIndex = -1;
        return;
    }
    for (Strike& s : g_Strikes)
    {
        s.age += dt;
        if (s.exploded)
            s.sinceImpact += dt;
        // o impacto do servidor não chegou (pacote perdido): explode do mesmo jeito
        else if (s.age >= s.wait + 0.8f)
            Explode(s);
    }
    std::erase_if(g_Strikes, [](const Strike& s) { return s.exploded && s.sinceImpact > 3.f; });
    for (Piece& p : g_Pieces)
    {
        p.age += dt;
        if (p.age < p.delay)
            continue;
        for (int k = 0; k < 3; ++k)
            p.pos[k] += p.vel[k] * dt;
        p.vel[2] -= p.gravity * dt;
        p.rotation += p.spin * dt;
    }
    std::erase_if(g_Pieces, [](const Piece& p) { return p.age >= p.delay + p.life; });
    for (Wave& w : g_Waves)
        w.age += dt;
    std::erase_if(g_Waves, [](const Wave& w) { return w.age > 0.9f; });
    UpdateAura(dt);
    if (g_Shake > 0.f)
    {
        g_Shake -= dt;
        EarthQuake = Rand(-1.f, 1.f) * 0.6f * std::clamp(g_Shake / 0.6f, 0.f, 1.f);
    }
}

void RenderGround()
{
    if (g_Strikes.empty() && g_Waves.empty() && g_AuraIndex < 0)
        return;
    EnableAlphaBlend();
    if (g_AuraIndex >= 0)
    {
        const OBJECT* o = &CharactersClient[g_AuraIndex].Object;
        const float pulse = 0.75f + 0.25f * std::sin(g_Time * 3.f);
        vec3_t light;
        Vector(0.9f * pulse, 0.12f * pulse, 0.05f * pulse, light);
        RenderTerrainAlphaBitmap(BITMAP_MAGIC, o->Position[0], o->Position[1], 9.f, 9.f, light, g_Time * 25.f);
        Vector(Ember[0] * pulse, Ember[1] * pulse, Ember[2] * pulse, light);
        RenderTerrainAlphaBitmap(BITMAP_MAGIC + 2, o->Position[0], o->Position[1], 11.f, 11.f, light, -g_Time * 40.f);
    }
    for (const Wave& w : g_Waves)
    {
        const float f = w.age / 0.9f;
        const float size = 2.f + 12.f * f;
        const float k = 0.8f * (1.f - f);
        vec3_t light;
        Vector(Ember[0] * k, Ember[1] * k, Ember[2] * k, light);
        RenderTerrainAlphaBitmap(BITMAP_ESTUDO_GOLPE_ANEL, w.x, w.y, size, size, light, 0.f);
    }
    for (const Strike& s : g_Strikes)
    {
        for (const Area& a : s.areas)
            RenderArea(s, a);
    }
    DisableAlphaBlend();
}

void RenderSprites()
{
    if (g_Pieces.empty())
        return;
    EnableAlphaBlend();
    for (const Piece& p : g_Pieces)
    {
        if (p.age < p.delay)
            continue;
        const float t = std::clamp((p.age - p.delay) / p.life, 0.f, 1.f);
        float k = 1.f - t;
        if (p.fadeIn)
            k = std::min(k, t * 5.f);
        const float size = p.size0 + (p.size1 - p.size0) * t;
        vec3_t position = {p.pos[0], p.pos[1], p.pos[2]};
        vec3_t light = {p.color[0] * k, p.color[1] * k, p.color[2] * k};
        if (p.frames > 0)
        {
            const int frame = std::min(p.frames - 1, static_cast<int>(t * p.frames));
            RenderSprite(p.texture, position, size, size, light, p.rotation, (frame % 4) * 0.25f, (frame / 4) * 0.25f,
                         0.25f, 0.25f);
        }
        else
        {
            RenderSprite(p.texture, position, size, size, light, p.rotation);
        }
    }
    DisableAlphaBlend();
}

std::string Warning()
{
    for (const Strike& s : g_Strikes)
    {
        if (!s.exploded)
            return s.boss + ": " + Names[s.kind] + "! (" + Hints[s.kind] + ")";
    }
    return {};
}
} // namespace mu::ui::window::GolpeBoss
