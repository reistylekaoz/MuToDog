#include "stdafx.h"
#include "UI/Estudo/AlmaWindow.h"
#include "UI/Core/WindowSystem.h"
#include "UI/Core/WindowCommon.h"
#include "Audio/DSPlaySound.h"
#include "Engine/Object/ZzzCharacter.h"
#include "Engine/Object/ZzzInfomation.h"
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
#include <cstdio>
#include <fstream>
#include <map>
#include <set>

using namespace mu::ui::window;

namespace
{
constexpr std::uint8_t PacketCode = 0xFB;
constexpr std::uint8_t CommandState = 0x50;
constexpr std::uint8_t CommandAdd = 0x51;
constexpr std::uint8_t CommandRedo = 0x52;
constexpr const char* DataFile = "Data/Interface/RmlUi/dados/alma.json";

constexpr int ActionNone = 0;
constexpr int ActionTab = 1;
constexpr int ActionAdd = 2;
constexpr int ActionRedo = 3;
constexpr int ActionRedoZen = 4;
constexpr int ActionRedoJewel = 5;
constexpr int ActionCancel = 6;
constexpr int ActionClose = 7;

// a barra de cada carta: de 142 a 250 (px da carta), 100 pontos em cima, como a do Godot
constexpr float kBarTop = 142.f;
constexpr float kBarBottom = 250.f;

struct Mark
{
    int points = 0;
    std::string type;
    double value = 0;
};

struct Element
{
    std::string name;
    std::string type;
    double perPoint = 0;
    std::vector<Mark> marks;
};

struct AlmaData
{
    bool loaded = false;
    int perReset = 10;
    int maximum = 100;
    long long redoZen = 100000000;
    int redoJewels = 10;
    std::array<int, 2> jewel{14, 13}; // Jewel of Bless
    std::vector<std::string> trees{"Ataque", "Defesa", "Suporte", "Diversos"};
    std::map<std::string, std::array<std::string, 2>> types; // tipo -> [nome, unidade]
    std::vector<Element> elements;
};

AlmaData g_Data;
int g_Total = 0;
int g_Free = 0;
std::vector<int> g_Points;
bool g_Received = false;
std::uint32_t g_Version = 1;

const AlmaData& AlmaSets()
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
    g_Data.perReset = j.value("pontos_por_reset", g_Data.perReset);
    g_Data.maximum = std::max(1, j.value("maximo", g_Data.maximum));
    const auto redo = j.value("refazer", nlohmann::json::object());
    g_Data.redoZen = redo.value("zen", g_Data.redoZen);
    g_Data.redoJewels = redo.value("joias", g_Data.redoJewels);
    const auto jewel = redo.value("joia", nlohmann::json::array());
    if (jewel.is_array() && jewel.size() == 2)
        g_Data.jewel = {jewel[0].get<int>(), jewel[1].get<int>()};
    const auto trees = j.value("arvores", nlohmann::json::array());
    if (trees.is_array() && trees.size() == 4)
        for (size_t i = 0; i < 4; ++i)
            g_Data.trees[i] = trees[i].get<std::string>();
    const nlohmann::json types = j.value("tipos", nlohmann::json::object());
    for (auto it = types.begin(); it != types.end(); ++it)
        if (it.value().is_array() && it.value().size() == 2)
            g_Data.types[it.key()] = {it.value()[0].get<std::string>(), it.value()[1].get<std::string>()};
    for (const auto& e : j.value("elementos", nlohmann::json::array()))
    {
        Element element;
        element.name = e.value("nome", std::string());
        element.type = e.value("tipo", std::string());
        element.perPoint = e.value("por_ponto", 0.0);
        for (const auto& m : e.value("marcos", nlohmann::json::array()))
            if (m.is_array() && m.size() == 3)
                element.marks.push_back({m[0].get<int>(), m[1].get<std::string>(), m[2].get<double>()});
        g_Data.elements.push_back(std::move(element));
    }
    return g_Data;
}

std::string AlmaThousands(long long value)
{
    std::string digits = std::to_string(value < 0 ? -value : value);
    for (int i = static_cast<int>(digits.size()) - 3; i > 0; i -= 3)
        digits.insert(static_cast<size_t>(i), ".");
    return value < 0 ? "-" + digits : digits;
}

// 12, 0,1, 0,025: sem zero sobrando, virgula no decimal (o numero() do Godot)
std::string AlmaNumber(double v)
{
    if (std::fabs(v - std::round(v)) < 1e-6)
        return AlmaThousands(static_cast<long long>(std::llround(v)));
    char text[32];
    std::snprintf(text, sizeof(text), "%.3f", v);
    std::string s = text;
    while (!s.empty() && s.back() == '0')
        s.pop_back();
    std::replace(s.begin(), s.end(), '.', ',');
    return s;
}

std::string AlmaUnit(const std::string& type)
{
    const auto it = AlmaSets().types.find(type);
    return it != AlmaSets().types.end() ? it->second[1] : std::string();
}

// "Dano mín. e máx. +480" ou "Chance de dano excelente +2,5%"
std::string AlmaBonusText(const std::string& type, double value)
{
    const auto it = AlmaSets().types.find(type);
    const std::string name = it != AlmaSets().types.end() ? it->second[0] : type;
    return name + " +" + AlmaNumber(value) + AlmaUnit(type);
}

int AlmaPoints(int element)
{
    return element >= 0 && element < static_cast<int>(g_Points.size()) ? g_Points[static_cast<size_t>(element)] : 0;
}

int AlmaUsed()
{
    int used = 0;
    for (int p : g_Points)
        used += p;
    return used;
}

long long AlmaGold()
{
    return CharacterMachine != nullptr ? static_cast<long long>(CharacterMachine->Gold) : 0;
}

// as Jewel of Bless da mochila (uma pilha conta a durabilidade, como o joias() do Godot)
int AlmaJewels()
{
    const auto& jewel = AlmaSets().jewel;
    const int type = jewel[0] * MAX_ITEM_INDEX + jewel[1];
    int count = 0;
    std::set<const ITEM*> seen;
    for (int slot = MAX_EQUIPMENT_INDEX; slot < MAX_MY_INVENTORY_EX_INDEX; ++slot)
    {
        const ITEM* item = UI::Inventory::FindPlayerItem(slot);
        if (item != nullptr && item->Type == type && seen.insert(item).second)
            count += std::max(1, static_cast<int>(item->Durability));
    }
    return count;
}

// px da tela de referência em dp (a folha da janela é dp, tools/estudo_dp.py)
std::string AlmaDp(float v)
{
    return std::to_string(static_cast<int>(std::lround(v))) + "dp";
}

void AlmaSendRaw(BYTE* packet, int size)
{
    if (SocketClient != nullptr)
        SocketClient->Send(packet, static_cast<int32_t>(size));
}
} // namespace

CAlmaWindow::CAlmaWindow() = default;

CAlmaWindow::~CAlmaWindow()
{
    Release();
}

bool CAlmaWindow::Create(CManager* pNewUIMng)
{
    if (pNewUIMng == nullptr)
        return false;
    m_pNewUIMng = pNewUIMng;
    m_pNewUIMng->AddUIObj(INTERFACE_ALMA, this);
    m_RmlView.Ensure();
    Show(false);
    return true;
}

void CAlmaWindow::Release()
{
    if (m_pNewUIMng)
    {
        m_pNewUIMng->RemoveUIObj(this);
        m_pNewUIMng = nullptr;
    }
    m_RmlView.Release();
}

void CAlmaWindow::Show(bool bShow)
{
    CObject::Show(bShow);
    if (bShow)
    {
        SendState();
        m_RmlView.GetModel().confirm = false;
        m_Dirty = true;
    }
}

void CAlmaWindow::ReceivePacket(const std::uint8_t* packet, int size)
{
    if (packet == nullptr || size < 9 || packet[0] != 0xC2 || packet[3] != PacketCode || packet[4] != CommandState)
        return;
    g_Total = packet[5] | (packet[6] << 8);
    g_Free = packet[7] | (packet[8] << 8);
    g_Points.assign(packet + 9, packet + std::min(size, 9 + 16));
    g_Received = true;
    ++g_Version;
}

void CAlmaWindow::SendState()
{
    BYTE packet[] = {0xC1, 4, PacketCode, CommandState};
    AlmaSendRaw(packet, static_cast<int>(sizeof(packet)));
}

void CAlmaWindow::SendAdd(int element, int amount)
{
    BYTE packet[] = {0xC1, 6, PacketCode, CommandAdd, static_cast<BYTE>(element), static_cast<BYTE>(amount)};
    AlmaSendRaw(packet, static_cast<int>(sizeof(packet)));
}

void CAlmaWindow::SendRedo(bool jewels)
{
    BYTE packet[] = {0xC1, 5, PacketCode, CommandRedo, static_cast<BYTE>(jewels ? 1 : 0)};
    AlmaSendRaw(packet, static_cast<int>(sizeof(packet)));
}

bool CAlmaWindow::UpdateMouseEvent()
{
    // Aberta, segura o mouse (tudo e do RmlUi).
    return false;
}

bool CAlmaWindow::UpdateKeyEvent()
{
    if (IsVisible() && IsPress(VK_ESCAPE))
    {
        if (m_RmlView.GetModel().confirm)
            m_PendingAction = ActionCancel;
        else
            g_pNewUISystem->Hide(INTERFACE_ALMA);
        PlayBuffer(SOUND_CLICK01);
        return false;
    }
    return true;
}

bool CAlmaWindow::Update()
{
    const bool inGame = SceneFlag == MAIN_SCENE && Hero != nullptr;
    if (!inGame && m_InGame)
    {
        // escolha de personagem: o proximo pede de novo, sem o estado do anterior
        g_Points.clear();
        g_Total = g_Free = 0;
        g_Received = false;
        ++g_Version;
    }
    m_InGame = inGame;

    RunPending();
    m_RmlView.Ensure();
    Rml::ElementDocument* document = m_RmlView.Document();
    if (document == nullptr)
        return true;
    UI::RmlBridge::SyncDocumentVisibilityInFront(document, IsVisible() && inGame);
    if (!IsVisible() || !inGame)
        return true;

    const std::string key = Signature();
    if (key != m_SeenKey || m_SeenVersion != g_Version)
    {
        m_SeenKey = key;
        m_SeenVersion = g_Version;
        m_Dirty = true;
    }
    if (m_Dirty)
        Rebuild();
    return true;
}

bool CAlmaWindow::Render()
{
    return true;
}

// o zen e as joias da mochila mudam os botoes de refazer
std::string CAlmaWindow::Signature() const
{
    return std::to_string(AlmaGold()) + ':' + std::to_string(AlmaJewels());
}

void CAlmaWindow::RunPending()
{
    const int action = m_PendingAction;
    m_PendingAction = ActionNone;
    if (action == ActionNone)
        return;
    AlmaRmlModel& model = m_RmlView.GetModel();
    switch (action)
    {
    case ActionTab:
        model.tab = std::clamp(m_PendingA, 0, 3);
        break;
    case ActionAdd:
        if (!model.confirm && g_Free > 0 && AlmaPoints(m_PendingA) < AlmaSets().maximum && m_PendingB > 0)
            SendAdd(m_PendingA, m_PendingB); // o servidor manda o estado de volta
        break;
    case ActionRedo:
        if (AlmaUsed() > 0)
            model.confirm = true;
        break;
    case ActionRedoZen:
        if (model.confirm && model.payZenOk)
        {
            SendRedo(false);
            model.confirm = false;
        }
        break;
    case ActionRedoJewel:
        if (model.confirm && model.payJewelOk)
        {
            SendRedo(true);
            model.confirm = false;
        }
        break;
    case ActionCancel:
        model.confirm = false;
        break;
    case ActionClose:
        g_pNewUISystem->Hide(INTERFACE_ALMA);
        break;
    default:
        break;
    }
    PlayBuffer(SOUND_CLICK01);
    m_Dirty = true;
}

void CAlmaWindow::BindRmlModel(Rml::DataModelConstructor& c, AlmaRmlModel& model)
{
    auto mark = c.RegisterStruct<AlmaMark>();
    mark.RegisterMember("label", &AlmaMark::label);
    mark.RegisterMember("value", &AlmaMark::value);
    mark.RegisterMember("look", &AlmaMark::look);
    mark.RegisterMember("top", &AlmaMark::top);
    c.RegisterArray<std::vector<AlmaMark>>();
    auto card = c.RegisterStruct<AlmaCard>();
    card.RegisterMember("name", &AlmaCard::name);
    card.RegisterMember("icon", &AlmaCard::icon);
    card.RegisterMember("now", &AlmaCard::now);
    card.RegisterMember("points", &AlmaCard::points);
    card.RegisterMember("bar", &AlmaCard::bar);
    card.RegisterMember("mark_name", &AlmaCard::markName);
    card.RegisterMember("lit", &AlmaCard::lit);
    card.RegisterMember("full", &AlmaCard::full);
    card.RegisterMember("can_add", &AlmaCard::canAdd);
    card.RegisterMember("element", &AlmaCard::element);
    card.RegisterMember("marks", &AlmaCard::marks);
    c.RegisterArray<std::vector<AlmaCard>>();
    c.RegisterArray<std::vector<Rml::String>>();

    c.Bind("tab", &model.tab);
    c.Bind("tabs", &model.tabs);
    c.Bind("free", &model.free);
    c.Bind("free_lit", &model.freeLit);
    c.Bind("cards", &model.cards);
    c.Bind("foot", &model.foot);
    c.Bind("can_redo", &model.canRedo);
    c.Bind("confirm", &model.confirm);
    c.Bind("pay_zen", &model.payZen);
    c.Bind("pay_zen_ok", &model.payZenOk);
    c.Bind("pay_jewel", &model.payJewel);
    c.Bind("pay_jewel_ok", &model.payJewelOk);

    auto one = [this](int action)
    {
        return [this, action](Rml::DataModelHandle, Rml::Event&, const Rml::VariantList& arguments)
        {
            m_PendingAction = action;
            m_PendingA = arguments.size() >= 1 ? arguments[0].Get<int>(0) : 0;
            m_PendingB = arguments.size() >= 2 ? arguments[1].Get<int>(0) : 0;
        };
    };
    c.BindEventCallback("alma_tab", one(ActionTab));
    c.BindEventCallback("alma_add", one(ActionAdd));
    c.BindEventCallback("alma_redo", one(ActionRedo));
    c.BindEventCallback("alma_redo_zen", one(ActionRedoZen));
    c.BindEventCallback("alma_redo_jewel", one(ActionRedoJewel));
    c.BindEventCallback("alma_cancel", one(ActionCancel));
    c.BindEventCallback("alma_close", one(ActionClose));
    m_Dirty = true;
}

void CAlmaWindow::Rebuild()
{
    m_Dirty = false;
    const AlmaData& data = AlmaSets();
    AlmaRmlModel& model = m_RmlView.GetModel();

    model.tabs.assign(data.trees.begin(), data.trees.end());
    model.free = g_Received ? "Pontos livres: " + AlmaThousands(g_Free) + " de " + AlmaThousands(g_Total)
                            : "Pedindo a alma ao servidor...";
    model.freeLit = g_Free > 0;
    model.cards.clear();
    const float barHeight = kBarBottom - kBarTop;
    for (int k = 0; k < 4; ++k)
    {
        const int index = model.tab * 4 + k;
        if (index >= static_cast<int>(data.elements.size()))
            break;
        const Element& e = data.elements[static_cast<size_t>(index)];
        const int p = AlmaPoints(index);
        AlmaCard card;
        card.name = e.name;
        card.icon = "image(al-" + std::to_string(index) + ")";
        card.lit = p > 0;
        card.now = p > 0 ? AlmaBonusText(e.type, e.perPoint * p) : AlmaBonusText(e.type, e.perPoint) + " por ponto";
        card.points = std::to_string(p) + " / " + std::to_string(data.maximum);
        card.full = p >= data.maximum;
        card.canAdd = g_Free > 0 && p < data.maximum;
        card.element = index;
        card.bar = AlmaDp(barHeight * std::clamp(p, 0, data.maximum) / static_cast<float>(data.maximum));
        int best = -1;
        for (size_t j = 0; j < e.marks.size(); ++j)
            if (p >= e.marks[j].points)
                best = static_cast<int>(j);
        for (size_t j = 0; j < e.marks.size(); ++j)
        {
            const Mark& m = e.marks[j];
            AlmaMark row;
            row.label = std::to_string(m.points) + " pontos";
            row.value = "+" + AlmaNumber(m.value) + AlmaUnit(m.type);
            row.look = static_cast<int>(j) == best ? "vale" : (p >= m.points ? "aceso" : "apagado");
            // a linha do marco no meio da casa de 26 px
            row.top = AlmaDp(kBarBottom - barHeight * m.points / static_cast<float>(data.maximum) - 13.f);
            card.marks.push_back(row);
        }
        if (!e.marks.empty())
        {
            const auto it = data.types.find(e.marks.front().type);
            card.markName = it != data.types.end() ? it->second[0] : e.marks.front().type;
        }
        model.cards.push_back(card);
    }
    model.foot = "Cada reset dá " + std::to_string(data.perReset) +
                 " pontos. Aos 40, 70 e 100 pontos liga um bônus extra (vale o maior).";
    model.canRedo = AlmaUsed() > 0;
    if (!model.canRedo)
        model.confirm = false;
    const int jewels = AlmaJewels();
    model.payZen = "Pagar " + AlmaThousands(data.redoZen) + " zen";
    model.payZenOk = AlmaGold() >= data.redoZen;
    model.payJewel = "Pagar " + std::to_string(data.redoJewels) + " Jewel of Bless (tem " + std::to_string(jewels) + ")";
    model.payJewelOk = jewels >= data.redoJewels;

    for (const char* field : {"tab", "tabs", "free", "free_lit", "cards", "foot", "can_redo", "confirm", "pay_zen",
                              "pay_zen_ok", "pay_jewel", "pay_jewel_ok"})
        m_RmlView.MarkDirty(field);
}

float CAlmaWindow::GetLayerDepth()
{
    return 10.62f;
}

float CAlmaWindow::GetKeyEventOrder()
{
    return 10.f;
}
