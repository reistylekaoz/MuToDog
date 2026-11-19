#include "stdafx.h"
#include "UI/Estudo/ColecoesWindow.h"
#include "UI/Core/WindowSystem.h"
#include "UI/Core/WindowCommon.h"
#include "Audio/DSPlaySound.h"
#include "Character/CharacterManager.h"
#include "Core/Text/Utf8.h"
#include "Data/GameData/ItemData/ItemModelSlots.h"
#include "Engine/Object/ItemTooltipSnapshot.h"
#include "Engine/Object/ZzzCharacter.h"
#include "Engine/Object/ZzzInfomation.h"
#include "GameLogic/Items/ItemOptions.h"
#include "Network/Server/WSclient.h"
#include "Scenes/SceneCore.h"
#include "UI/Inventory/InventoryContents.h"
#include "UI/RmlBridge/RmlDocumentVisibility.h"

#include "json.hpp"

#include <RmlUi/Core/DataModelHandle.h>
#include <RmlUi/Core/ElementDocument.h>
#include <RmlUi/Core/Event.h>

#include <algorithm>
#include <array>
#include <cmath>
#include <fstream>
#include <map>
#include <set>

using namespace mu::ui::window;

namespace
{
constexpr std::uint8_t PacketCode = 0xFB;
constexpr std::uint8_t CommandList = 0x40;
constexpr std::uint8_t CommandGive = 0x41;
constexpr std::uint8_t CommandResult = 0x42;
constexpr std::uint8_t CommandBuy = 0x43;
constexpr const char* DataFile = "Data/Interface/RmlUi/dados/colecoes.json";
// o giro e o zoom da vitrine, lidos a cada vez que a janela abre (da pra acertar sem compilar)
constexpr const char* VitrineFile = "Data/Interface/RmlUi/dados/vitrine.json";

constexpr int ActionNone = 0;
constexpr int ActionTab = 1;
constexpr int ActionPart = 2;
constexpr int ActionPartStep = 3;
constexpr int ActionSet = 4;
constexpr int ActionPiece = 5;
constexpr int ActionAddOpen = 6;
constexpr int ActionAddClose = 7;
constexpr int ActionBag = 8;
constexpr int ActionGive = 9;
constexpr int ActionClose = 10;
constexpr int ActionBuyOpen = 11;
constexpr int ActionBuyClose = 12;
constexpr int ActionBuy = 13;

constexpr const char* kColParts[5] = {"Elmo", "Armadura", "Calça", "Luvas", "Botas"};
// a ordem do CLASS_TYPE (e do RequireClass)
constexpr const char* kColClasses[7] = {"Dark Wizard", "Dark Knight", "Fairy Elf", "Magic Gladiator",
                                        "Dark Lord",   "Summoner",    "Rage Fighter"};

struct SetDef
{
    int id = 0;
    std::string name;
    std::vector<std::array<int, 2>> pieces; // [grupo, numero]
    std::string bonusType;
    double bonusValue = 0;
    double zen = 0;
};

struct ColecoesData
{
    bool loaded = false;
    std::vector<SetDef> sets;
    std::vector<std::array<int, 4>> requests; // [nivel, excelentes, luck, adicional]
    std::map<std::string, std::string> suffix;
    std::map<std::string, double> factor; // fator: nivel, excelente, adicional (o preco do carrinho)
};

// o nome do bonus na tela (o colecoes.json nao tem acento)
const std::map<std::string, std::string> kBonusName = {
    {"vel", "Velocidade de ataque"}, {"hp", "Vida máxima"},      {"def", "Defesa"},
    {"dano", "Dano"},                {"sd", "SD máximo"},         {"reducao", "Redução de dano"},
    {"exc", "Chance de dano excelente"}, {"ignora", "Ignorar defesa"}, {"reflete", "Refletir dano"},
    {"duplo", "Dano duplo"}};

ColecoesData g_Data;
std::map<int, int> g_Masks;                 // colecao -> pecas entregues
std::map<int, std::array<int, 5>> g_Asks;   // colecao -> indice do pedido de cada peca (deste personagem)
bool g_Received = false;
std::string g_LastResult;
bool g_LastOk = false;
bool g_BuyPending = false;
std::uint32_t g_Version = 1;

const ColecoesData& ColSets()
{
    if (g_Data.loaded)
        return g_Data;
    g_Data.loaded = true;
    std::ifstream file(DataFile);
    if (!file)
        return g_Data;
    const nlohmann::json j = nlohmann::json::parse(file, nullptr, false);
    if (j.is_discarded() || !j.is_object())
        return g_Data;
    for (const auto& c : j.value("colecoes", nlohmann::json::array()))
    {
        SetDef s;
        s.id = c.value("id", 0);
        s.name = c.value("nome", std::string());
        for (const auto& p : c.value("pecas", nlohmann::json::array()))
            if (p.is_array() && p.size() == 2)
                s.pieces.push_back({p[0].get<int>(), p[1].get<int>()});
        const auto bonus = c.value("bonus", nlohmann::json::object());
        s.bonusType = bonus.value("tipo", std::string());
        s.bonusValue = bonus.value("valor", 0.0);
        s.zen = c.value("zen", 0.0);
        g_Data.sets.push_back(std::move(s));
    }
    for (const auto& p : j.value("pedidos", nlohmann::json::array()))
        if (p.is_array() && p.size() == 4)
            g_Data.requests.push_back({p[0].get<int>(), p[1].get<int>(), p[2].get<int>(), p[3].get<int>()});
    const nlohmann::json types = j.value("tipos", nlohmann::json::object());
    for (auto it = types.begin(); it != types.end(); ++it)
        if (it.value().is_array() && it.value().size() == 2)
            g_Data.suffix[it.key()] = it.value()[1].get<std::string>();
    const nlohmann::json factor = j.value("fator", nlohmann::json::object());
    for (auto it = factor.begin(); it != factor.end(); ++it)
        if (it.value().is_number())
            g_Data.factor[it.key()] = it.value().get<double>();
    return g_Data;
}

const SetDef* ColFindSet(int id)
{
    for (const SetDef& s : ColSets().sets)
        if (s.id == id)
            return &s;
    return nullptr;
}

int ColMask(int id)
{
    const auto it = g_Masks.find(id);
    return it != g_Masks.end() ? it->second : 0;
}

int ColBits(int m)
{
    int n = 0;
    for (; m != 0; m >>= 1)
        n += m & 1;
    return n;
}

bool ColComplete(const SetDef& s)
{
    return !s.pieces.empty() && ColMask(s.id) == (1 << s.pieces.size()) - 1;
}

std::string ColNumber(double v)
{
    if (std::floor(v) == v)
        return std::to_string(static_cast<long long>(v));
    std::string t = std::to_string(std::round(v * 10) / 10);
    t = t.substr(0, t.find('.') + 2);
    t[t.find('.')] = ',';
    return t;
}

std::string ColBonusText(const std::string& type, double value)
{
    const auto name = kBonusName.find(type);
    const auto suffix = ColSets().suffix.find(type);
    return (name != kBonusName.end() ? name->second : type) + " +" + ColNumber(value) +
           (suffix != ColSets().suffix.end() ? suffix->second : std::string());
}

std::string ColSprite(int group, int number)
{
    return "image(it-" + std::to_string(group) + "-" + std::to_string(number) + ")";
}

std::string ColItemName(int group, int number)
{
    const int type = group * MAX_ITEM_INDEX + number;
    if (ItemAttribute == nullptr || type < 0 || type >= MAX_ITEM)
        return {};
    return Core::Text::ToUtf8(ItemAttribute[type].Name);
}

std::array<int, 4> ColRequest(int set, int piece)
{
    const auto it = g_Asks.find(set);
    const auto& list = ColSets().requests;
    if (it == g_Asks.end() || piece < 0 || piece >= 5 || it->second[static_cast<size_t>(piece)] >= static_cast<int>(list.size()))
        return {0, 0, 0, 0};
    return list[static_cast<size_t>(it->second[static_cast<size_t>(piece)])];
}

// o que o item nao tem do pedido ("" tem tudo), como o Colecoes.Falta do servidor
std::string ColMissing(const std::array<int, 4>& req, const ITEM& item)
{
    if (item.Level < req[0])
        return "+" + std::to_string(req[0]);
    if ((item.ExcellentFlags & 63 & req[1]) != req[1])
        return "as opções excelentes";
    if (req[2] != 0 && !item.HasLuck)
        return "luck";
    if (req[3] > 0 && GameLogic::Items::GetAdditionalOptionLevel(item) < req[3])
        return "adicional +" + std::to_string(req[3] * 4);
    return {};
}

// [colecao, peca] do item, ou nullptr
const SetDef* ColSetOfItem(const ITEM& item, int& piece)
{
    const int group = item.Type / MAX_ITEM_INDEX;
    const int number = item.Type % MAX_ITEM_INDEX;
    for (const SetDef& s : ColSets().sets)
        for (size_t i = 0; i < s.pieces.size(); ++i)
            if (s.pieces[i][0] == group && s.pieces[i][1] == number)
            {
                piece = static_cast<int>(i);
                return &s;
            }
    return nullptr;
}

// o slot da mochila com a peca que serve, ou -1
int ColBagSlotFor(const SetDef& s, int piece)
{
    const int type = s.pieces[static_cast<size_t>(piece)][0] * MAX_ITEM_INDEX + s.pieces[static_cast<size_t>(piece)][1];
    for (int slot = MAX_EQUIPMENT_INDEX; slot < MAX_MY_INVENTORY_EX_INDEX; ++slot)
    {
        const ITEM* item = UI::Inventory::FindPlayerItem(slot);
        if (item != nullptr && item->Type == type && ColMissing(ColRequest(s.id, piece), *item).empty())
            return slot;
    }
    return -1;
}

std::string ColLook(const SetDef& s, int piece)
{
    if ((ColMask(s.id) & (1 << piece)) != 0)
        return "dada";
    return ColBagSlotFor(s, piece) >= 0 ? "mochila" : "falta";
}

std::string ColItemLabel(const ITEM& item)
{
    std::string name = ColItemName(item.Type / MAX_ITEM_INDEX, item.Type % MAX_ITEM_INDEX);
    if (item.Level > 0)
        name += " +" + std::to_string(item.Level);
    return name;
}

double ColFactor(const char* name)
{
    const auto it = ColSets().factor.find(name);
    return it != ColSets().factor.end() ? it->second : 0.0;
}

// o zen do carrinho: o preco do item pedido, como o Colecoes.PrecoCompra do servidor (o luck nao conta;
// nearbyint arredonda o meio pro par, como o Math.Round do C#)
long long ColPrice(const SetDef& s, const std::array<int, 4>& req)
{
    return static_cast<long long>(std::nearbyint(s.zen * (1 + ColFactor("nivel") * req[0]) *
                                                 (1 + ColFactor("excelente") * ColBits(req[1])) *
                                                 (1 + ColFactor("adicional") * req[3])));
}

std::string ColZen(long long value)
{
    std::string digits = std::to_string(value < 0 ? -value : value);
    for (int i = static_cast<int>(digits.size()) - 3; i > 0; i -= 3)
        digits.insert(static_cast<size_t>(i), ".");
    return value < 0 ? "-" + digits : digits;
}

long long ColGold()
{
    return CharacterMachine != nullptr ? static_cast<long long>(CharacterMachine->Gold) : 0;
}

// o item que a peca pede deste personagem, como o servidor manda um item
ItemCreationParams ColRequestedItem(const SetDef& s, int piece, const std::array<int, 4>& req)
{
    const auto& p = s.pieces[static_cast<size_t>(piece)];
    ItemCreationParams params = Engine::Items::TooltipSnapshot::FullItemParameters(p[0], p[1]);
    params.Level = static_cast<BYTE>(std::clamp(req[0], 0, 15));
    params.WithLuck = req[2] != 0;
    if (req[3] > 0)
    {
        params.WithOption = true;
        params.OptionLevel = static_cast<BYTE>(req[3]);
    }
    if (req[1] > 0)
    {
        params.HasExcellentOption = true;
        params.ExcellentFlags = static_cast<BYTE>(req[1] & 63);
    }
    params.Durability = Engine::Items::TooltipSnapshot::FullDurability(params);
    return params;
}

// "Dragon Armor +9 · excelente · luck · adicional +8"
std::string ColRequestedName(const SetDef& s, int piece, const std::array<int, 4>& req)
{
    const auto& p = s.pieces[static_cast<size_t>(piece)];
    std::string name = ColItemName(p[0], p[1]);
    if (req[0] > 0)
        name += " +" + std::to_string(req[0]);
    if (req[1] != 0)
        name += " · excelente (" + std::to_string(ColBits(req[1])) + ")";
    if (req[2] != 0)
        name += " · luck";
    if (req[3] > 0)
        name += " · adicional +" + std::to_string(req[3] * 4);
    return name;
}

UI::RmlBridge::Tooltip::LineColor ColLineColor(int color)
{
    using LineColor = UI::RmlBridge::Tooltip::LineColor;
    switch (color)
    {
    case TEXT_COLOR_BLUE: return LineColor::Blue;
    case TEXT_COLOR_GRAY: return LineColor::Gray;
    case TEXT_COLOR_RED: return LineColor::Red;
    case TEXT_COLOR_YELLOW: return LineColor::Yellow;
    case TEXT_COLOR_GREEN: return LineColor::Green;
    case TEXT_COLOR_PURPLE: return LineColor::Purple;
    case TEXT_COLOR_REDPURPLE: return LineColor::RedPurple;
    case TEXT_COLOR_VIOLET: return LineColor::Violet;
    case TEXT_COLOR_ORANGE: return LineColor::Orange;
    case TEXT_COLOR_DARKRED: return LineColor::DarkRedHighlight;
    case TEXT_COLOR_DARKBLUE: return LineColor::DarkBlueHighlight;
    case TEXT_COLOR_DARKYELLOW: return LineColor::DarkYellowHighlight;
    case TEXT_COLOR_GREEN_BLUE: return LineColor::GreenBlueHighlight;
    case TEXT_COLOR_WHITE: default: return LineColor::White;
    }
}

// a dica da peca: o preco (ou ja entregue), se tem na mochila, e embaixo a dica inteira do item pedido
std::vector<UI::RmlBridge::Tooltip::Line> ColPieceTip(int set, int piece)
{
    using UI::RmlBridge::Tooltip::Line;
    using UI::RmlBridge::Tooltip::LineColor;
    std::vector<Line> lines;
    const SetDef* s = ColFindSet(set);
    if (s == nullptr || piece < 0 || piece >= static_cast<int>(s->pieces.size()))
        return lines;
    const std::array<int, 4> req = ColRequest(set, piece);
    if ((ColMask(set) & (1 << piece)) != 0)
    {
        lines.push_back({"Já está na coleção do " + s->name + ".", LineColor::Blue, true});
    }
    else
    {
        const long long price = ColPrice(*s, req);
        lines.push_back({"Preço de compra: " + ColZen(price) + " zen", LineColor::Yellow, true});
        if (ColGold() < price)
            lines.push_back({"Zen insuficiente.", LineColor::Red});
        if (ColBagSlotFor(*s, piece) >= 0)
            lines.push_back({"Você tem uma que serve na mochila: entrega sem zen.", LineColor::Green});
        else
            lines.push_back({"Ou entregue um igual a este (nível, opções, luck e adicional).", LineColor::Gray});
    }
    Line spacer;
    spacer.kind = Line::Kind::FullSpacer;
    lines.push_back(spacer);
    for (const ItemTooltipLine& row : Engine::Items::TooltipSnapshot::TooltipOfParameters(ColRequestedItem(*s, piece, req)))
    {
        Line line;
        if (row.text == L"\n")
            line.kind = Line::Kind::HalfSpacer;
        else if (row.text == L" ")
            line.kind = Line::Kind::FullSpacer;
        else
        {
            line.text = Core::Text::ToUtf8(row.text.c_str());
            line.color = ColLineColor(row.color);
            line.bold = row.bold;
        }
        lines.push_back(std::move(line));
    }
    return lines;
}

// a classe que veste o set na vitrine: a do personagem se veste, senao a primeira que veste (o MG so quando o set
// e so dele), como o classe_da_vitrine do Godot; pela armadura do set (ou a primeira peca)
int ColVitrineClass(const SetDef& s, int own)
{
    if (s.pieces.empty() || ItemAttribute == nullptr)
        return own;
    std::array<int, 2> piece = s.pieces.front();
    for (const auto& p : s.pieces)
        if (p[0] == 8)
            piece = p;
    const int type = piece[0] * MAX_ITEM_INDEX + piece[1];
    if (type < 0 || type >= MAX_ITEM)
        return own;
    const BYTE* classes = ItemAttribute[type].RequireClass;
    if (own >= 0 && own < 7 && classes[own] != 0)
        return own;
    for (int i = 0; i < 7; ++i)
        if (i != CLASS_DARK && classes[i] != 0)
            return i;
    return CLASS_DARK;
}

void ColSendRaw(BYTE* packet, int size)
{
    if (SocketClient != nullptr)
        SocketClient->Send(packet, static_cast<int32_t>(size));
}
} // namespace

CColecoesWindow::CColecoesWindow() = default;

CColecoesWindow::~CColecoesWindow()
{
    Release();
}

bool CColecoesWindow::Create(CManager* pNewUIMng)
{
    if (pNewUIMng == nullptr)
        return false;

    m_pNewUIMng = pNewUIMng;
    m_pNewUIMng->AddUIObj(INTERFACE_COLECOES, this);
    m_RmlView.Ensure();
    Show(false);
    return true;
}

void CColecoesWindow::Release()
{
    m_VitrineControl.Detach();
    m_Tip.Hide();
    m_TipShown = false;
    if (m_pNewUIMng)
    {
        m_pNewUIMng->RemoveUIObj(this);
        m_pNewUIMng = nullptr;
    }
    m_RmlView.Release();
}

void CColecoesWindow::Show(bool bShow)
{
    CObject::Show(bShow);
    if (bShow)
    {
        SendList();
        m_Dirty = true;
        m_VitrineSet = -1; // le o vitrine.json de novo
    }
}

void CColecoesWindow::ReceivePacket(const std::uint8_t* packet, int size)
{
    if (packet == nullptr || size < 5)
        return;
    if (packet[0] == 0xC2 && size >= 6 && packet[3] == PacketCode && packet[4] == CommandList)
    {
        const int count = packet[5];
        if (size < 6 + count * 7)
            return;
        g_Masks.clear();
        g_Asks.clear();
        for (int i = 0; i < count; ++i)
        {
            const std::uint8_t* e = packet + 6 + i * 7;
            g_Masks[e[0]] = e[1];
            g_Asks[e[0]] = {e[2], e[3], e[4], e[5], e[6]};
        }
        g_Received = true;
        ++g_Version;
        return;
    }
    if (packet[0] == 0xC1 && size >= 7 && packet[2] == PacketCode && packet[3] == CommandResult)
    {
        g_LastOk = packet[4] != 0;
        const bool bought = g_BuyPending;
        g_BuyPending = false;
        if (g_LastOk)
        {
            g_Masks[packet[5]] = packet[6];
            const SetDef* s = ColFindSet(packet[5]);
            if (s != nullptr && ColComplete(*s))
                g_LastResult = s->name + " completo: " + ColBonusText(s->bonusType, s->bonusValue) + " pra sempre.";
            else if (s != nullptr)
                g_LastResult = std::string(bought ? "Peça comprada no " : "Peça entregue no ") + s->name + " (" +
                               std::to_string(ColBits(packet[6])) + " de " + std::to_string(s->pieces.size()) + ").";
        }
        else
        {
            g_LastResult = bought ? "O servidor recusou a compra: o motivo está no chat."
                                  : "O servidor recusou a peça: o motivo está no chat.";
        }
        ++g_Version;
    }
}

bool CColecoesWindow::HasBonus()
{
    if (!g_Received)
        return false;
    for (const SetDef& s : ColSets().sets)
        if (ColComplete(s))
            return true;
    return false;
}

std::vector<UI::RmlBridge::Tooltip::Line> CColecoesWindow::BonusTooltip()
{
    using UI::RmlBridge::Tooltip::Line;
    using UI::RmlBridge::Tooltip::LineColor;
    std::vector<Line> lines;
    std::vector<const SetDef*> done;
    std::map<std::string, double> sum;
    for (const SetDef& s : ColSets().sets)
        if (ColComplete(s))
        {
            done.push_back(&s);
            sum[s.bonusType] += s.bonusValue;
        }
    lines.push_back({"Bônus das coleções", LineColor::Blue, true});
    lines.push_back({"Sets completos: " + std::to_string(done.size()) + " de " + std::to_string(ColSets().sets.size()),
                     LineColor::Yellow});
    for (const auto& [type, value] : sum)
        lines.push_back({ColBonusText(type, value), LineColor::Green});
    for (const SetDef* s : done)
        lines.push_back({s->name + ": " + ColBonusText(s->bonusType, s->bonusValue), LineColor::White});
    return lines;
}

void CColecoesWindow::SendList()
{
    BYTE packet[] = {0xC1, 4, PacketCode, CommandList};
    ColSendRaw(packet, static_cast<int>(sizeof(packet)));
}

void CColecoesWindow::SendGive(int slot)
{
    BYTE packet[] = {0xC1, 5, PacketCode, CommandGive, static_cast<BYTE>(slot)};
    ColSendRaw(packet, static_cast<int>(sizeof(packet)));
}

void CColecoesWindow::SendBuy(int set, int piece)
{
    BYTE packet[] = {0xC1, 6, PacketCode, CommandBuy, static_cast<BYTE>(set), static_cast<BYTE>(piece)};
    ColSendRaw(packet, static_cast<int>(sizeof(packet)));
}

bool CColecoesWindow::UpdateMouseEvent()
{
    // Aberta, segura o mouse (tudo e do RmlUi).
    return false;
}

bool CColecoesWindow::UpdateKeyEvent()
{
    if (IsVisible() && IsPress(VK_ESCAPE))
    {
        if (m_RmlView.GetModel().buyOpen)
            m_PendingAction = ActionBuyClose;
        else if (m_RmlView.GetModel().addOpen)
            m_PendingAction = ActionAddClose;
        else
            g_pNewUISystem->Hide(INTERFACE_COLECOES);
        PlayBuffer(SOUND_CLICK01);
        return false;
    }
    return true;
}

bool CColecoesWindow::Update()
{
    const bool inGame = SceneFlag == MAIN_SCENE && Hero != nullptr;
    if (!inGame)
    {
        // escolha de personagem: o proximo pede de novo, sem o estado do anterior
        if (m_Requested)
        {
            g_Masks.clear();
            g_Asks.clear();
            g_Received = false;
            g_LastResult.clear();
        }
        m_Requested = false;
    }
    else if (!m_Requested)
    {
        // o buff precisa do estado logo ao entrar
        m_Requested = true;
        SendList();
    }

    RunPending();
    m_RmlView.Ensure();
    Rml::ElementDocument* document = m_RmlView.Document();
    if (document == nullptr)
        return true;
    UI::RmlBridge::SyncDocumentVisibilityInFront(document, IsVisible() && inGame);
    if (!IsVisible() || !inGame)
    {
        SyncVitrine(false);
        SyncTip(false);
        return true;
    }

    const std::string bag = BagSignature();
    const auto gold = static_cast<unsigned long long>(ColGold());
    if (bag != m_BagKey || m_SeenVersion != g_Version || gold != m_SeenGold)
    {
        m_BagKey = bag;
        m_SeenVersion = g_Version;
        m_SeenGold = gold;
        m_Dirty = true;
    }
    if (m_Dirty)
        Rebuild();
    const ColecoesRmlModel& model = m_RmlView.GetModel();
    SyncVitrine(model.tab == 1);
    SyncTip(!model.addOpen && !model.buyOpen);
    return true;
}

bool CColecoesWindow::Render()
{
    return true;
}

std::string CColecoesWindow::BagSignature() const
{
    std::string key;
    for (int slot = MAX_EQUIPMENT_INDEX; slot < MAX_MY_INVENTORY_EX_INDEX; ++slot)
    {
        const ITEM* item = UI::Inventory::FindPlayerItem(slot);
        if (item != nullptr && item->Type >= 0)
            key += std::to_string(slot) + ':' + std::to_string(item->Type) + ':' + std::to_string(item->Level) + ',';
    }
    return key;
}

void CColecoesWindow::RunPending()
{
    const int action = m_PendingAction;
    m_PendingAction = ActionNone;
    if (action == ActionNone)
        return;
    ColecoesRmlModel& model = m_RmlView.GetModel();
    switch (action)
    {
    case ActionTab:
        model.tab = m_PendingA == 1 ? 1 : 0;
        model.addOpen = false;
        model.buyOpen = false;
        break;
    case ActionPart:
        m_Part = std::clamp(m_PendingA, 0, 4);
        break;
    case ActionPartStep:
        m_Part = (m_Part + m_PendingA + 5) % 5;
        break;
    case ActionSet:
        model.setId = m_PendingA;
        break;
    case ActionPiece:
        ClickPiece(m_PendingA, m_PendingB);
        break;
    case ActionAddOpen:
        model.buyOpen = false;
        model.addOpen = true;
        m_AddSlot = -1;
        g_LastResult.clear();
        break;
    case ActionAddClose:
        model.addOpen = false;
        m_AddSlot = -1;
        break;
    case ActionBag:
        m_AddSlot = m_PendingA;
        g_LastResult.clear();
        break;
    case ActionGive:
        if (model.addCan && m_AddSlot >= 0)
        {
            SendGive(m_AddSlot);
            m_AddSlot = -1;
            g_LastResult = "Entregando...";
        }
        break;
    case ActionClose:
        g_pNewUISystem->Hide(INTERFACE_COLECOES);
        break;
    case ActionBuyOpen:
        OpenBuy(m_PendingA, m_PendingB);
        break;
    case ActionBuyClose:
        model.buyOpen = false;
        break;
    case ActionBuy:
        // o servidor confere o zen de novo e responde FB 42 com a lista
        if (model.buyOpen && model.buyCan && m_BuySet >= 0 && m_BuyPiece >= 0)
        {
            SendBuy(m_BuySet, m_BuyPiece);
            g_BuyPending = true;
            g_LastResult = "Comprando...";
            g_LastOk = true;
            model.buyOpen = false;
        }
        break;
    default:
        break;
    }
    PlayBuffer(SOUND_CLICK01);
    m_Dirty = true;
}

// a peca de um set clicada: se esta na mochila e serve, abre a caixinha com ela na casa; senao mostra o set
void CColecoesWindow::ClickPiece(int set, int piece)
{
    const SetDef* s = ColFindSet(set);
    ColecoesRmlModel& model = m_RmlView.GetModel();
    if (s == nullptr || piece < 0 || piece >= static_cast<int>(s->pieces.size()))
        return;
    const int slot = (ColMask(set) & (1 << piece)) == 0 ? ColBagSlotFor(*s, piece) : -1;
    if (slot >= 0)
    {
        model.addOpen = true;
        m_AddSlot = slot;
        g_LastResult.clear();
        return;
    }
    model.tab = 1;
    model.setId = set;
}

// o carrinho da peca que falta: abre a confirmacao com o item pedido e o preco
void CColecoesWindow::OpenBuy(int set, int piece)
{
    const SetDef* s = ColFindSet(set);
    if (s == nullptr || piece < 0 || piece >= static_cast<int>(s->pieces.size()) || (ColMask(set) & (1 << piece)) != 0)
        return;
    ColecoesRmlModel& model = m_RmlView.GetModel();
    m_BuySet = set;
    m_BuyPiece = piece;
    model.addOpen = false;
    model.buyOpen = true;
    g_LastResult.clear();
}

void CColecoesWindow::BindRmlModel(Rml::DataModelConstructor& c, ColecoesRmlModel& model)
{
    auto piece = c.RegisterStruct<ColecoesPiece>();
    piece.RegisterMember("name", &ColecoesPiece::name);
    piece.RegisterMember("label", &ColecoesPiece::label);
    piece.RegisterMember("decorator", &ColecoesPiece::decorator);
    piece.RegisterMember("look", &ColecoesPiece::look);
    piece.RegisterMember("selected", &ColecoesPiece::selected);
    piece.RegisterMember("set", &ColecoesPiece::set);
    piece.RegisterMember("piece", &ColecoesPiece::piece);
    piece.RegisterMember("index", &ColecoesPiece::index);
    c.RegisterArray<std::vector<ColecoesPiece>>();
    auto card = c.RegisterStruct<ColecoesCard>();
    card.RegisterMember("name", &ColecoesCard::name);
    card.RegisterMember("decorator", &ColecoesCard::decorator);
    card.RegisterMember("count", &ColecoesCard::count);
    card.RegisterMember("open", &ColecoesCard::open);
    card.RegisterMember("done", &ColecoesCard::done);
    card.RegisterMember("id", &ColecoesCard::id);
    c.RegisterArray<std::vector<ColecoesCard>>();
    auto bag = c.RegisterStruct<ColecoesBagRow>();
    bag.RegisterMember("name", &ColecoesBagRow::name);
    bag.RegisterMember("info", &ColecoesBagRow::info);
    bag.RegisterMember("decorator", &ColecoesBagRow::decorator);
    bag.RegisterMember("look", &ColecoesBagRow::look);
    bag.RegisterMember("slot", &ColecoesBagRow::slot);
    c.RegisterArray<std::vector<ColecoesBagRow>>();
    c.RegisterArray<std::vector<Rml::String>>();

    c.Bind("tab", &model.tab);
    c.Bind("part_name", &model.partName);
    c.Bind("parts", &model.parts);
    c.Bind("cells", &model.cells);
    c.Bind("cards", &model.cards);
    c.Bind("set_id", &model.setId);
    c.Bind("set_name", &model.setName);
    c.Bind("slots", &model.slots);
    c.Bind("set_text", &model.setText);
    c.Bind("set_done", &model.setDone);
    c.Bind("set_bonus", &model.setBonus);
    c.Bind("active", &model.active);
    c.Bind("active_count", &model.activeCount);
    c.Bind("add_open", &model.addOpen);
    c.Bind("add_name", &model.addName);
    c.Bind("add_decorator", &model.addDecorator);
    c.Bind("add_msg", &model.addMsg);
    c.Bind("add_look", &model.addLook);
    c.Bind("add_can", &model.addCan);
    c.Bind("bag", &model.bag);
    c.Bind("set_help", &model.setHelp);
    c.Bind("vitrine_class", &model.vitrineClass);
    c.Bind("buy_open", &model.buyOpen);
    c.Bind("buy_name", &model.buyName);
    c.Bind("buy_decorator", &model.buyDecorator);
    c.Bind("buy_ask", &model.buyAsk);
    c.Bind("buy_have", &model.buyHave);
    c.Bind("buy_look", &model.buyLook);
    c.Bind("buy_can", &model.buyCan);

    auto one = [this](int action)
    {
        return [this, action](Rml::DataModelHandle, Rml::Event&, const Rml::VariantList& arguments)
        {
            m_PendingAction = action;
            m_PendingA = arguments.size() >= 1 ? arguments[0].Get<int>(0) : 0;
            m_PendingB = arguments.size() >= 2 ? arguments[1].Get<int>(0) : 0;
        };
    };
    c.BindEventCallback("col_tab", one(ActionTab));
    c.BindEventCallback("col_part", one(ActionPart));
    c.BindEventCallback("col_part_step", one(ActionPartStep));
    c.BindEventCallback("col_set", one(ActionSet));
    c.BindEventCallback("col_piece", one(ActionPiece));
    c.BindEventCallback("col_add_open", one(ActionAddOpen));
    c.BindEventCallback("col_add_close", one(ActionAddClose));
    c.BindEventCallback("col_bag", one(ActionBag));
    c.BindEventCallback("col_give", one(ActionGive));
    c.BindEventCallback("col_close", one(ActionClose));
    c.BindEventCallback("col_buy_close", one(ActionBuyClose));
    c.BindEventCallback("col_buy_ok", one(ActionBuy));
    // o carrinho fica dentro da peca: o clique nao sobe pro col_piece dela
    c.BindEventCallback("col_buy",
        [this](Rml::DataModelHandle, Rml::Event& event, const Rml::VariantList& arguments)
        {
            event.StopPropagation();
            m_PendingAction = ActionBuyOpen;
            m_PendingA = arguments.size() >= 1 ? arguments[0].Get<int>(0) : 0;
            m_PendingB = arguments.size() >= 2 ? arguments[1].Get<int>(0) : 0;
        });
    c.BindEventCallback("col_hover",
        [this](Rml::DataModelHandle, Rml::Event& event, const Rml::VariantList& arguments)
        {
            const int set = arguments.size() >= 1 ? arguments[0].Get<int>(0) : 0;
            const int piece = arguments.size() >= 2 ? arguments[1].Get<int>(-1) : -1;
            m_Tip.Enter(event, set * 8 + piece + 1);
        });
    c.BindEventCallback("col_leave",
        [this](Rml::DataModelHandle, Rml::Event& event, const Rml::VariantList&) { m_Tip.Leave(event); });
    m_Dirty = true;
}

void CColecoesWindow::Rebuild()
{
    m_Dirty = false;
    ++m_BuildCount;
    ColecoesRmlModel& model = m_RmlView.GetModel();
    BuildAll(model);
    BuildSets(model);
    BuildAdd(model);
    BuildBuy(model);
    for (const char* field : {"tab", "part_name", "parts", "cells", "cards", "set_id", "set_name", "slots", "set_text",
                              "set_done", "set_bonus", "active", "active_count", "add_open", "add_name",
                              "add_decorator", "add_msg", "add_look", "add_can", "bag", "set_help", "vitrine_class",
                              "buy_open", "buy_name", "buy_decorator", "buy_ask", "buy_have", "buy_look", "buy_can"})
        m_RmlView.MarkDirty(field);
}

void CColecoesWindow::BuildAll(ColecoesRmlModel& model)
{
    model.partName = kColParts[m_Part];
    model.parts.clear();
    for (int i = 0; i < 5; ++i)
    {
        ColecoesPiece p;
        p.decorator = ColSprite(7 + i, 29);
        p.selected = i == m_Part;
        p.index = i;
        model.parts.push_back(p);
    }
    model.cells.clear();
    for (const SetDef& s : ColSets().sets)
        for (size_t i = 0; i < s.pieces.size(); ++i)
            if (s.pieces[i][0] - 7 == m_Part)
            {
                ColecoesPiece p;
                p.name = ColItemName(s.pieces[i][0], s.pieces[i][1]);
                p.decorator = ColSprite(s.pieces[i][0], s.pieces[i][1]);
                p.look = ColLook(s, static_cast<int>(i));
                p.set = s.id;
                p.piece = static_cast<int>(i);
                model.cells.push_back(p);
            }
}

void CColecoesWindow::BuildSets(ColecoesRmlModel& model)
{
    const auto& sets = ColSets().sets;
    if (ColFindSet(model.setId) == nullptr && !sets.empty())
        model.setId = sets.front().id;
    model.cards.clear();
    std::map<std::string, double> sum;
    int done = 0;
    for (const SetDef& s : sets)
    {
        ColecoesCard card;
        card.name = s.name;
        card.decorator = s.pieces.size() > 1 ? ColSprite(s.pieces[1][0], s.pieces[1][1]) : Rml::String();
        for (const auto& p : s.pieces)
            if (p[0] == 8)
                card.decorator = ColSprite(p[0], p[1]);
        card.count = std::to_string(ColBits(ColMask(s.id))) + "/" + std::to_string(s.pieces.size());
        card.done = ColComplete(s);
        card.open = s.id == model.setId;
        card.id = s.id;
        model.cards.push_back(card);
        if (card.done)
        {
            ++done;
            sum[s.bonusType] += s.bonusValue;
        }
    }

    model.slots.clear();
    const SetDef* s = ColFindSet(model.setId);
    model.setName = s != nullptr ? s->name : Rml::String();
    model.setText.clear();
    model.setBonus.clear();
    model.setDone = false;
    if (s != nullptr)
    {
        for (int part = 0; part < 5; ++part)
        {
            ColecoesPiece p;
            p.label = kColParts[part];
            p.look = "vazia";
            p.piece = -1;
            for (size_t i = 0; i < s->pieces.size(); ++i)
                if (s->pieces[i][0] - 7 == part)
                {
                    p.name = ColItemName(s->pieces[i][0], s->pieces[i][1]);
                    p.decorator = ColSprite(s->pieces[i][0], s->pieces[i][1]);
                    p.look = ColLook(*s, static_cast<int>(i));
                    p.piece = static_cast<int>(i);
                }
            model.slots.push_back(p);
        }
        model.setDone = ColComplete(*s);
        model.setText = model.setDone ? "Set completo: o bônus já está ligado pra sempre."
                                      : "Se completar o set inteiro, você ganha pra sempre:";
        model.setBonus = "◆ " + ColBonusText(s->bonusType, s->bonusValue) + "   (" + std::to_string(ColBits(ColMask(s->id))) +
                         "/" + std::to_string(s->pieces.size()) + ")";
    }
    model.setHelp = !g_LastResult.empty() ? g_LastResult
                                          : "Clique na peça da mochila pra entregar, ou no carrinho pra comprar com zen.";
    const int own = Hero != nullptr ? static_cast<int>(gCharacterManager.GetBaseClass(Hero->Class)) : 0;
    const int shown = s != nullptr ? ColVitrineClass(*s, own) : own;
    model.vitrineClass = shown >= 0 && shown < 7 ? kColClasses[shown] : "";

    model.active.clear();
    for (const auto& [type, value] : sum)
        model.active.push_back(ColBonusText(type, value));
    model.activeCount = g_Received ? "Sets completos: " + std::to_string(done) + " de " + std::to_string(sets.size())
                                   : "Pedindo as coleções ao servidor...";
}

void CColecoesWindow::BuildAdd(ColecoesRmlModel& model)
{
    model.bag.clear();
    model.addName.clear();
    model.addDecorator.clear();
    model.addCan = false;
    model.addLook.clear();
    model.addMsg = g_LastResult;
    if (!g_LastResult.empty())
        model.addLook = g_LastOk ? "ok" : "falta";

    const ITEM* chosen = m_AddSlot >= 0 ? UI::Inventory::FindPlayerItem(m_AddSlot) : nullptr;
    if (chosen == nullptr)
        m_AddSlot = -1;
    // FindPlayerItem acha o item em todas as casas que ele cobre: a primeira (a de cima na esquerda) vale, as outras pulam
    std::set<const ITEM*> seen;
    for (int slot = MAX_EQUIPMENT_INDEX; slot < MAX_MY_INVENTORY_EX_INDEX; ++slot)
    {
        const ITEM* item = UI::Inventory::FindPlayerItem(slot);
        if (item == nullptr || !seen.insert(item).second)
            continue;
        int piece = -1;
        const SetDef* s = item != nullptr && item->Type >= 0 ? ColSetOfItem(*item, piece) : nullptr;
        if (s == nullptr)
            continue;
        ColecoesBagRow row;
        row.name = ColItemLabel(*item);
        row.decorator = ColSprite(item->Type / MAX_ITEM_INDEX, item->Type % MAX_ITEM_INDEX);
        row.slot = slot;
        std::string message;
        bool serves = false;
        if ((ColMask(s->id) & (1 << piece)) != 0)
        {
            row.look = "ja";
            row.info = "já entregue";
            message = "Essa peça do " + s->name + " já foi entregue.";
        }
        else if (const std::string missing = ColMissing(ColRequest(s->id, piece), *item); !missing.empty())
        {
            row.look = "falta";
            row.info = "pede " + missing;
            message = "Não serve: o " + s->name + " pede " + missing + ".";
        }
        else
        {
            row.look = "ok";
            row.info = "serve";
            message = "Serve no " + s->name + ": entrega sem zen.";
            serves = true;
        }
        if (slot == m_AddSlot)
        {
            row.look += " selected";
            model.addName = row.name;
            model.addDecorator = row.decorator;
            model.addMsg = message;
            model.addLook = serves ? "ok" : "falta";
            model.addCan = serves;
        }
        model.bag.push_back(row);
    }
    if (model.addMsg.empty())
        model.addMsg = "Escolha embaixo a peça da mochila que vai pra coleção.";
}

void CColecoesWindow::BuildBuy(ColecoesRmlModel& model)
{
    const SetDef* s = model.buyOpen ? ColFindSet(m_BuySet) : nullptr;
    if (s == nullptr || m_BuyPiece < 0 || m_BuyPiece >= static_cast<int>(s->pieces.size()) ||
        (ColMask(m_BuySet) & (1 << m_BuyPiece)) != 0)
    {
        model.buyOpen = false;
        model.buyCan = false;
        return;
    }
    const std::array<int, 4> req = ColRequest(m_BuySet, m_BuyPiece);
    const long long price = ColPrice(*s, req);
    const long long gold = ColGold();
    const auto& p = s->pieces[static_cast<size_t>(m_BuyPiece)];
    model.buyName = ColRequestedName(*s, m_BuyPiece, req);
    model.buyDecorator = ColSprite(p[0], p[1]);
    model.buyAsk = "Comprar pro " + s->name + " por " + ColZen(price) + " zen?";
    model.buyCan = g_Received && gold >= price;
    model.buyHave = model.buyCan ? "Você tem " + ColZen(gold) + " zen." : "Zen insuficiente: você tem " + ColZen(gold) + ".";
    model.buyLook = model.buyCan ? "ok" : "falta";
}

// a vitrine: o personagem da foto das cartas vestindo o set aberto, de frente; arrastar gira, o direito volta
void CColecoesWindow::SyncVitrine(bool shown)
{
    Rml::ElementDocument* document = m_RmlView.Document();
    if (!shown || document == nullptr || Hero == nullptr)
    {
        m_VitrineControl.Suspend();
        return;
    }
    if (!m_VitrineReady)
    {
        m_Vitrine.Init(0);
        m_Vitrine.SetCanControl(true);
        m_VitrineReady = true;
        m_VitrineSet = -1;
    }
    const ColecoesRmlModel& model = m_RmlView.GetModel();
    if (m_VitrineSet != model.setId)
        DressVitrine(model.setId);
    m_Vitrine.Update();
    m_VitrineControl.Attach(document, m_Vitrine);
    m_VitrineControl.Sync();
}

void CColecoesWindow::DressVitrine(int set)
{
    m_VitrineSet = set;
    const SetDef* s = ColFindSet(set);
    if (s == nullptr)
        return;
    float angle = 0.f;
    float zoom = 1.f;
    if (std::ifstream file(VitrineFile); file)
    {
        const nlohmann::json j = nlohmann::json::parse(file, nullptr, false);
        if (!j.is_discarded() && j.is_object())
        {
            angle = j.value("giro", angle);
            zoom = j.value("zoom", zoom);
        }
    }

    const int own = static_cast<int>(gCharacterManager.GetBaseClass(Hero->Class));
    const auto shown = static_cast<CLASS_TYPE>(ColVitrineClass(*s, own));
    CHARACTER* c = m_Vitrine.GetPhotoChar();
    DeleteCloth(c, nullptr, nullptr);
    c->SkinIndex = gCharacterManager.GetSkinModelIndex(shown);
    if (m_VitrineClass != static_cast<int>(shown))
    {
        m_VitrineClass = static_cast<int>(shown);
        m_Vitrine.SetClass(shown);
    }
    // sem a peca do set, a parte do corpo da classe (o MG sem elmo)
    const int bodies[5] = {static_cast<int>(MODEL_BODY_HELM), static_cast<int>(MODEL_BODY_ARMOR),
                           static_cast<int>(MODEL_BODY_PANTS), static_cast<int>(MODEL_BODY_GLOVES),
                           static_cast<int>(MODEL_BODY_BOOTS)};
    for (int part = 0; part < 5; ++part)
    {
        PART_t& body = c->BodyPart[BODYPART_HELM + part];
        body.Type = static_cast<short>(bodies[part] + static_cast<int>(c->SkinIndex));
        body.Level = 0;
        body.ExcellentFlags = 0;
        body.AncientDiscriminator = 0;
        for (const auto& p : s->pieces)
            if (p[0] - 7 == part)
            {
                // +15 excelente, com o brilho, como as pecas douradas da vitrine da MuDream
                body.Type = static_cast<short>(Data::Items::ToModelSlot(Data::Items::MakeItemType(p[0], p[1])));
                body.Level = 15;
                body.ExcellentFlags = 1;
            }
        body.m_pCloth[0] = nullptr;
        body.m_pCloth[1] = nullptr;
        body.m_byNumCloth = 0;
    }
    c->Weapon[0].Type = -1;
    c->Weapon[1].Type = -1;
    c->Wing.Type = -1;
    c->Helper.Type = -1;
    m_Vitrine.SetAnimation(AT_STAND1);
    m_Vitrine.SetAngle(angle);
    m_Vitrine.SetZoom(zoom);
}

void CColecoesWindow::SyncTip(bool shown)
{
    const int key = shown ? m_Tip.Hovered() : -1;
    if (key < 0)
    {
        if (m_TipShown)
            m_Tip.Hide();
        m_TipShown = false;
        m_TipKey = -1;
        return;
    }
    if (key != m_TipKey || m_TipVersion != m_BuildCount)
    {
        m_TipKey = key;
        m_TipVersion = m_BuildCount;
        m_TipLines = ColPieceTip(key / 8, key % 8 - 1);
    }
    UI::RmlBridge::ElementTooltip::Placement placement;
    m_Tip.Show(m_TipLines, placement);
    m_TipShown = true;
}

float CColecoesWindow::GetLayerDepth()
{
    return 10.62f;
}

float CColecoesWindow::GetKeyEventOrder()
{
    return 10.f;
}
