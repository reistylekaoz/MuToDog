#include "stdafx.h"
#include "UI/Estudo/AndarMinimapa.h"
#include "Engine/Object/ZzzCharacter.h"
#include "GameLogic/Automation/Movement.h"
#include "Render/Terrain/ZzzLodTerrain.h"
#include "UI/Core/WindowSystem.h"
#include "UI/HUD/ChatLogWindow.h"
#include "World/MapInfra/MapManager.h"

#include <algorithm>
#include <chrono>
#include <cstdlib>
#include <vector>

namespace
{
constexpr int kLado = 256;
constexpr int kTrecho = 8;        // casas por trecho (o Godot manda 7 por pacote)
constexpr int kRaioLivre = 16;    // casa bloqueada: procura a livre mais perto até 16 em volta
constexpr double kSemAndar = 4.0; // parado há 4 s sem chegar: desiste

using Relogio = std::chrono::steady_clock;

bool s_ativo = false;
int s_mapa = -1;
std::vector<int> s_rota; // índices y * 256 + x, do herói (exclusive) até o destino
int s_i = 0;             // a casa da rota onde o herói está (ou a última que passou)
int s_alvoX = -1, s_alvoY = -1;  // o fim do trecho que mandei
bool s_mandei = false;   // o último trecho saiu andando
bool s_enviou = false;   // já mandei algum trecho (antes disso o MovementType ainda é o do que ele fazia)
int s_ultimaX = -1, s_ultimaY = -1;
Relogio::time_point s_mexeu{};

void Aviso(const wchar_t* texto)
{
    if (g_pSystemLogBox)
        g_pSystemLogBox->AddText(texto, mu::ui::window::TYPE_SYSTEM_MESSAGE);
}

bool Anda(int x, int y)
{
    if (x < 0 || y < 0 || x >= kLado || y >= kLado)
        return false;
    const WORD w = TerrainWall[y * kLado + x];
    return (w & (TW_NOMOVE | TW_NOGROUND)) == 0;
}

// busca em largura com 8 vizinhos, do herói até o destino
bool Caminho(int sx, int sy, int tx, int ty, std::vector<int>& rota)
{
    static std::vector<int> antes(kLado * kLado);
    std::fill(antes.begin(), antes.end(), -1);
    std::vector<int> fila;
    fila.reserve(kLado * kLado);
    const int inicio = sy * kLado + sx, fim = ty * kLado + tx;
    antes[inicio] = inicio;
    fila.push_back(inicio);
    static constexpr int kDx[8] = {1, -1, 0, 0, 1, 1, -1, -1};
    static constexpr int kDy[8] = {0, 0, 1, -1, 1, -1, 1, -1};
    for (size_t k = 0; k < fila.size() && antes[fim] < 0; ++k)
    {
        const int x = fila[k] % kLado, y = fila[k] / kLado;
        for (int d = 0; d < 8; ++d)
        {
            const int nx = x + kDx[d], ny = y + kDy[d];
            if (!Anda(nx, ny) || antes[ny * kLado + nx] >= 0)
                continue;
            antes[ny * kLado + nx] = fila[k];
            fila.push_back(ny * kLado + nx);
        }
    }
    if (antes[fim] < 0)
        return false;
    rota.clear();
    for (int p = fim; p != inicio; p = antes[p])
        rota.push_back(p);
    std::reverse(rota.begin(), rota.end());
    return true;
}

bool PerdeuOControle()
{
    if (!s_enviou)
        return false;
    // atacou, pegou item, falou com NPC ou usou skill: a pessoa assumiu
    if (Hero->MovementType != MOVEMENT_MOVE)
        return true;
    // clicou no chão em outro lugar: o caminho do herói não termina no meu trecho
    if (s_mandei && GameLogic::Automation::IsWalkInProgress())
    {
        const PATH_t& p = Hero->Path;
        const int n = p.PathNum;
        if (n > 1 && (std::abs(p.PathX[n - 1] - s_alvoX) > 1 || std::abs(p.PathY[n - 1] - s_alvoY) > 1))
            return true;
    }
    return false;
}
} // namespace

namespace mu::ui::window::AndarMinimapa
{
bool Ir(int tileX, int tileY)
{
    Parar();
    if (Hero == nullptr || Hero->Dead > 0)
        return false;
    tileX = std::clamp(tileX, 0, kLado - 1);
    tileY = std::clamp(tileY, 0, kLado - 1);
    // a casa livre mais perto do clique, anel por anel (o Godot faz igual)
    int lx = -1, ly = -1;
    for (int r = 0; r <= kRaioLivre && lx < 0; ++r)
        for (int dy = -r; dy <= r && lx < 0; ++dy)
            for (int dx = -r; dx <= r && lx < 0; ++dx)
                if (std::max(std::abs(dx), std::abs(dy)) == r && Anda(tileX + dx, tileY + dy))
                {
                    lx = tileX + dx;
                    ly = tileY + dy;
                }
    std::vector<int> rota;
    if (lx < 0 || !Caminho(Hero->PositionX, Hero->PositionY, lx, ly, rota))
    {
        Aviso(L"Não dá pra chegar até aí andando.");
        return false;
    }
    if (rota.empty())
        return true; // já está lá
    s_rota = std::move(rota);
    s_i = -1;
    s_ativo = true;
    s_mapa = gMapManager.WorldActive;
    s_mandei = false;
    s_enviou = false;
    s_ultimaX = Hero->PositionX;
    s_ultimaY = Hero->PositionY;
    s_mexeu = Relogio::now();
    return true;
}

void Parar()
{
    s_ativo = false;
    s_rota.clear();
    s_mandei = false;
}

bool Destino(int& tileX, int& tileY)
{
    if (!s_ativo || s_rota.empty())
        return false;
    tileX = s_rota.back() % kLado;
    tileY = s_rota.back() / kLado;
    return true;
}

void Update()
{
    if (!s_ativo)
        return;
    if (Hero == nullptr || Hero->Dead > 0 || gMapManager.WorldActive != s_mapa || PerdeuOControle())
    {
        Parar();
        return;
    }

    const int hx = Hero->PositionX, hy = Hero->PositionY;
    const Relogio::time_point agora = Relogio::now();
    if (hx != s_ultimaX || hy != s_ultimaY)
    {
        s_ultimaX = hx;
        s_ultimaY = hy;
        s_mexeu = agora;
    }

    // onde estou na rota: a casa mais adiante a até 1 de mim (o passo lógico corre na frente do boneco)
    for (int k = static_cast<int>(s_rota.size()) - 1; k > s_i; --k)
    {
        const int x = s_rota[k] % kLado, y = s_rota[k] / kLado;
        if (std::abs(x - hx) <= 1 && std::abs(y - hy) <= 1)
        {
            s_i = k;
            break;
        }
    }
    const int ultimo = static_cast<int>(s_rota.size()) - 1;
    if (s_i >= ultimo && !GameLogic::Automation::IsWalkInProgress())
    {
        Parar(); // chegou
        return;
    }
    if (GameLogic::Automation::IsWalkInProgress())
        return;
    if (std::chrono::duration<double>(agora - s_mexeu).count() > kSemAndar)
    {
        Parar(); // algo no caminho (outro jogador, monstro parado em porta estreita)
        return;
    }

    // o próximo trecho; se o caminho do jogo não acha (alguém em pé ali), tenta mais curto
    for (int passo : {kTrecho, 4, 2})
    {
        const int k = std::min(std::max(s_i, 0) + passo, ultimo);
        const int x = s_rota[k] % kLado, y = s_rota[k] / kLado;
        const GameLogic::Automation::MoveResult r = GameLogic::Automation::WalkTo(x, y);
        if (r == GameLogic::Automation::MoveResult::NoPath)
            continue;
        s_alvoX = x;
        s_alvoY = y;
        s_mandei = r == GameLogic::Automation::MoveResult::Walking;
        s_enviou = s_enviou || s_mandei;
        if (r == GameLogic::Automation::MoveResult::Arrived)
            s_i = std::max(s_i, k - 1);
        return;
    }
}
} // namespace mu::ui::window::AndarMinimapa
