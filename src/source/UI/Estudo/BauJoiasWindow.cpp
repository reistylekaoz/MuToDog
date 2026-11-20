#include "stdafx.h"
#include "UI/Estudo/BauJoiasWindow.h"
#include "UI/Estudo/MercadoWindow.h"
#include "UI/Core/WindowSystem.h"
#include "UI/Core/WindowCommon.h"
#include "Audio/DSPlaySound.h"
#include "Engine/Object/ZzzCharacter.h"
#include "Engine/Object/ZzzInfomation.h"
#include "Network/Server/WSclient.h"
#include "Scenes/SceneCore.h"
#include "UI/Inventory/InventoryContents.h"
#include "UI/RmlBridge/RmlDocumentVisibility.h"
#include "UI/RmlBridge/RmlPointer.h"

#include <RmlUi/Core/DataModelHandle.h>
#include <RmlUi/Core/ElementDocument.h>
#include <RmlUi/Core/Event.h>

#include <algorithm>
#include <array>
#include <map>
#include <set>

using namespace mu::ui::window;

namespace
{
constexpr std::uint8_t PacketCode = 0xFB;
constexpr std::uint8_t CommandBalance = 0x00;
constexpr std::uint8_t CommandDeposit = 0x01;
constexpr std::uint8_t CommandWithdraw = 0x02;
constexpr std::uint8_t CommandSplit = 0x03;
constexpr std::uint8_t CommandGroup = 0x04;
constexpr int Stack = 255;

constexpr int ActionNone = 0;
constexpr int ActionWithdrawOpen = 1;
constexpr int ActionWithdraw = 2;
constexpr int ActionSplitOpen = 3;
constexpr int ActionBag = 4;
constexpr int ActionSplit = 5;
constexpr int ActionGroup = 6;
constexpr int ActionBack = 7;
constexpr int ActionClose = 8;

// as joias do baú, na ordem do servidor (BancoJoias.Joias), e a TDC (255,255) no fim
constexpr std::array<std::array<int, 2>, 16> kRows = {{{14, 13}, {14, 14}, {14, 16}, {14, 22}, {14, 31}, {14, 41},
                                                       {14, 42}, {12, 15}, {14, 43}, {14, 44}, {14, 151}, {14, 152},
                                                       {14, 153}, {14, 156}, {14, 157}, {255, 255}}};
constexpr size_t kJewels = 15;

std::array<std::uint32_t, kRows.size()> g_Balance{};
bool g_Received = false;
std::uint32_t g_Version = 1;
std::string g_Note;

std::uint32_t ReadLe32(const std::uint8_t* p)
{
    return static_cast<std::uint32_t>(p[0]) | (static_cast<std::uint32_t>(p[1]) << 8) |
           (static_cast<std::uint32_t>(p[2]) << 16) | (static_cast<std::uint32_t>(p[3]) << 24);
}

std::string Thousands(std::uint32_t v)
{
    std::string digits = std::to_string(v);
    for (int i = static_cast<int>(digits.size()) - 3; i > 0; i -= 3)
        digits.insert(static_cast<size_t>(i), ".");
    return digits;
}

void SendRaw(BYTE* packet, int size)
{
    if (SocketClient != nullptr)
        SocketClient->Send(packet, static_cast<int32_t>(size));
}

void SendSimple(std::uint8_t command)
{
    BYTE packet[] = {0xC1, 4, PacketCode, command};
    SendRaw(packet, static_cast<int>(sizeof(packet)));
}

void SendWithdraw(size_t row, std::uint32_t qty)
{
    const int number = kRows[row][1];
    BYTE packet[11] = {0xC1, 11, PacketCode, CommandWithdraw, static_cast<BYTE>(kRows[row][0]),
                       static_cast<BYTE>(number & 0xFF), static_cast<BYTE>((number >> 8) & 0xFF)};
    for (int i = 0; i < 4; ++i)
        packet[7 + i] = static_cast<BYTE>((qty >> (8 * i)) & 0xFF);
    SendRaw(packet, static_cast<int>(sizeof(packet)));
}

// "1.500" ou "1500" vira 1500; 0 quando não é número ou passa do que cabe em 32 bits
std::uint32_t ParseQty(const std::string& text)
{
    std::uint64_t value = 0;
    bool any = false;
    for (const char ch : text)
    {
        if (ch == '.' || ch == ' ')
            continue;
        if (ch < '0' || ch > '9')
            return 0;
        value = value * 10 + static_cast<std::uint64_t>(ch - '0');
        any = true;
        if (value > 0xFFFFFFFFull)
            return 0;
    }
    return any ? static_cast<std::uint32_t>(value) : 0;
}

int RowOf(int type)
{
    for (size_t i = 0; i < kJewels; ++i)
        if (kRows[i][0] * MAX_ITEM_INDEX + kRows[i][1] == type)
            return static_cast<int>(i);
    return -1;
}

std::string RowName(size_t row)
{
    return CMercadoWindow::CoinLabel(kRows[row][0], kRows[row][1]);
}

// as pilhas de joia do baú na mochila (FindPlayerItem acha o item em todas as casas que ele cobre: só a primeira)
std::vector<std::pair<int, const ITEM*>> BagJewels()
{
    std::vector<std::pair<int, const ITEM*>> out;
    std::set<const ITEM*> seen;
    for (int slot = MAX_EQUIPMENT_INDEX; slot < MAX_MY_INVENTORY_EX_INDEX; ++slot)
    {
        const ITEM* item = UI::Inventory::FindPlayerItem(slot);
        if (item != nullptr && CBauJoiasWindow::IsBankJewel(item->Type) && seen.insert(item).second)
            out.emplace_back(slot, item);
    }
    return out;
}

int Count(const ITEM* item)
{
    return std::max(1, static_cast<int>(item->Durability));
}
} // namespace

CBauJoiasWindow::CBauJoiasWindow() = default;

CBauJoiasWindow::~CBauJoiasWindow()
{
    Release();
}

bool CBauJoiasWindow::Create(CManager* pNewUIMng)
{
    if (pNewUIMng == nullptr)
        return false;

    m_pNewUIMng = pNewUIMng;
    m_pNewUIMng->AddUIObj(INTERFACE_BAU_JOIAS, this);
    m_RmlView.Ensure();
    Show(false);
    return true;
}

void CBauJoiasWindow::Release()
{
    if (m_pNewUIMng)
    {
        m_pNewUIMng->RemoveUIObj(this);
        m_pNewUIMng = nullptr;
    }
    m_RmlView.Release();
}

void CBauJoiasWindow::Show(bool bShow)
{
    const bool was = IsVisible();
    CObject::Show(bShow);
    if (bShow && !was)
    {
        m_Mode = 0;
        m_Pick = -1;
        g_Note.clear();
        SendSimple(CommandBalance);
        m_Dirty = true;
    }
}

bool CBauJoiasWindow::IsBankJewel(int type)
{
    return RowOf(type) >= 0;
}

void CBauJoiasWindow::Deposit(int slot)
{
    const ITEM* item = UI::Inventory::FindPlayerItem(slot);
    if (item == nullptr || !IsBankJewel(item->Type))
        return;
    // o servidor tira da mochila e responde o saldo novo
    BYTE packet[] = {0xC1, 5, PacketCode, CommandDeposit, static_cast<BYTE>(slot)};
    SendRaw(packet, static_cast<int>(sizeof(packet)));
    g_pNewUISystem->Show(INTERFACE_BAU_JOIAS);
    g_Note = "Guardando " + std::to_string(Count(item)) + " " + RowName(static_cast<size_t>(RowOf(item->Type))) + "...";
    ++g_Version;
    PlayBuffer(SOUND_CLICK01);
}

void CBauJoiasWindow::ReceivePacket(const std::uint8_t* packet, int size)
{
    if (packet == nullptr || size < 5 || packet[0] != 0xC1 || packet[2] != PacketCode || packet[3] != CommandBalance)
        return;
    const int n = packet[4];
    if (size < 5 + n * 7)
        return;
    g_Balance.fill(0);
    for (int i = 0; i < n; ++i)
    {
        const std::uint8_t* p = packet + 5 + i * 7;
        const int group = p[0];
        const int number = p[1] | (p[2] << 8);
        for (size_t r = 0; r < kRows.size(); ++r)
            if (kRows[r][0] == group && kRows[r][1] == number)
                g_Balance[r] = ReadLe32(p + 3);
    }
    g_Received = true;
    g_Note.clear();
    ++g_Version;
}

bool CBauJoiasWindow::UpdateMouseEvent()
{
    // Só segura o mouse em cima do painel: a mochila do lado segue com o Ctrl + botão direito.
    return !UI::RmlBridge::IsPointerOver(m_RmlView.Document());
}

bool CBauJoiasWindow::UpdateKeyEvent()
{
    if (IsVisible() && IsPress(VK_ESCAPE))
    {
        m_PendingAction = m_Mode > 0 ? ActionBack : ActionClose;
        PlayBuffer(SOUND_CLICK01);
        return false;
    }
    return true;
}

bool CBauJoiasWindow::Update()
{
    const bool inGame = SceneFlag == MAIN_SCENE && Hero != nullptr;
    if (!inGame && g_Received)
    {
        // escolha de personagem: o próximo pede de novo
        g_Balance.fill(0);
        g_Received = false;
        ++g_Version;
    }

    RunPending();
    m_RmlView.Ensure();
    Rml::ElementDocument* document = m_RmlView.Document();
    if (document == nullptr)
        return true;
    UI::RmlBridge::SyncDocumentVisibilityInFront(document, IsVisible() && inGame);
    if (!IsVisible() || !inGame)
        return true;

    const std::string bag = m_Mode >= 2 ? BagSignature() : std::string();
    if (bag != m_BagKey || m_SeenVersion != g_Version)
    {
        m_BagKey = bag;
        m_SeenVersion = g_Version;
        m_Dirty = true;
    }
    if (m_Dirty)
        Rebuild();
    return true;
}

bool CBauJoiasWindow::Render()
{
    return true;
}

float CBauJoiasWindow::GetLayerDepth()
{
    return 10.64f;
}

float CBauJoiasWindow::GetKeyEventOrder()
{
    return 10.0f;
}

std::string CBauJoiasWindow::BagSignature() const
{
    std::string key;
    for (const auto& [slot, item] : BagJewels())
        key += std::to_string(slot) + ':' + std::to_string(item->Type) + ':' + std::to_string(Count(item)) + ',';
    return key;
}

void CBauJoiasWindow::RunPending()
{
    const int action = m_PendingAction;
    m_PendingAction = ActionNone;
    if (action == ActionNone)
        return;
    BauJoiasRmlModel& model = m_RmlView.GetModel();
    switch (action)
    {
    case ActionWithdrawOpen:
        if (m_PendingArg >= 0 && m_PendingArg < static_cast<int>(kJewels) && g_Balance[static_cast<size_t>(m_PendingArg)] > 0)
        {
            m_Pick = m_PendingArg;
            m_Mode = 1;
            model.qtyText = std::to_string(std::min<std::uint32_t>(g_Balance[static_cast<size_t>(m_Pick)], Stack));
            m_RmlView.MarkDirty("qty");
            g_Note.clear();
        }
        break;
    case ActionWithdraw:
    {
        if (m_Pick < 0 || m_Pick >= static_cast<int>(kJewels))
        {
            m_Mode = 0;
            break;
        }
        const std::uint32_t has = g_Balance[static_cast<size_t>(m_Pick)];
        const std::uint32_t qty = ParseQty(model.qtyText);
        if (qty == 0 || qty > has)
        {
            g_Note = "Escreva um número de 1 a " + Thousands(has) + ".";
            break;
        }
        // o que não couber na mochila volta pro baú (o servidor avisa em azul no chat)
        SendWithdraw(static_cast<size_t>(m_Pick), qty);
        g_Note = "Retirando " + Thousands(qty) + " " + RowName(static_cast<size_t>(m_Pick)) + "...";
        m_Mode = 0;
        m_Pick = -1;
        break;
    }
    case ActionSplitOpen:
        m_Mode = 2;
        m_Pick = -1;
        g_Note.clear();
        break;
    case ActionBag:
    {
        const ITEM* item = UI::Inventory::FindPlayerItem(m_PendingArg);
        if (item != nullptr && IsBankJewel(item->Type) && Count(item) >= 2)
        {
            m_Pick = m_PendingArg;
            m_Mode = 3;
            model.qtyText = "1";
            m_RmlView.MarkDirty("qty");
        }
        break;
    }
    case ActionSplit:
    {
        const ITEM* item = m_Pick >= 0 ? UI::Inventory::FindPlayerItem(m_Pick) : nullptr;
        if (item == nullptr || !IsBankJewel(item->Type) || Count(item) < 2)
        {
            m_Mode = 2;
            break;
        }
        const std::uint32_t qty = ParseQty(model.qtyText);
        if (qty == 0 || qty >= static_cast<std::uint32_t>(Count(item)))
        {
            g_Note = "Escreva um número de 1 a " + std::to_string(Count(item) - 1) + ".";
            break;
        }
        BYTE packet[] = {0xC1, 6, PacketCode, CommandSplit, static_cast<BYTE>(m_Pick), static_cast<BYTE>(qty)};
        SendRaw(packet, static_cast<int>(sizeof(packet)));
        g_Note = "Separando " + std::to_string(qty) + " " + RowName(static_cast<size_t>(RowOf(item->Type))) + ".";
        m_Mode = 0;
        m_Pick = -1;
        break;
    }
    case ActionGroup:
    {
        // só pede quando tem 2 pilhas da mesma joia com espaço (senão não muda nada)
        std::map<int, int> open;
        bool any = false;
        for (const auto& [slot, item] : BagJewels())
            if (Count(item) < Stack && ++open[item->Type] >= 2)
                any = true;
        if (any)
        {
            SendSimple(CommandGroup);
            g_Note = "Joias agrupadas em pilhas de até 255.";
        }
        else
            g_Note = "Nada pra agrupar: as joias já estão juntas.";
        break;
    }
    case ActionBack:
        m_Mode = m_Mode == 3 ? 2 : 0;
        m_Pick = -1;
        g_Note.clear();
        break;
    case ActionClose:
        g_pNewUISystem->Hide(INTERFACE_BAU_JOIAS);
        break;
    default:
        break;
    }
    PlayBuffer(SOUND_CLICK01);
    m_Dirty = true;
}

void CBauJoiasWindow::BindRmlModel(Rml::DataModelConstructor& c, BauJoiasRmlModel& model)
{
    auto row = c.RegisterStruct<BauJoiasRow>();
    row.RegisterMember("name", &BauJoiasRow::name);
    row.RegisterMember("qty", &BauJoiasRow::qty);
    row.RegisterMember("decorator", &BauJoiasRow::decorator);
    row.RegisterMember("can", &BauJoiasRow::can);
    row.RegisterMember("tdc", &BauJoiasRow::tdc);
    row.RegisterMember("index", &BauJoiasRow::index);
    c.RegisterArray<std::vector<BauJoiasRow>>();
    auto bag = c.RegisterStruct<BauJoiasBagRow>();
    bag.RegisterMember("name", &BauJoiasBagRow::name);
    bag.RegisterMember("qty", &BauJoiasBagRow::qty);
    bag.RegisterMember("decorator", &BauJoiasBagRow::decorator);
    bag.RegisterMember("slot", &BauJoiasBagRow::slot);
    c.RegisterArray<std::vector<BauJoiasBagRow>>();

    c.Bind("mode", &model.mode);
    c.Bind("rows", &model.rows);
    c.Bind("bag", &model.bag);
    c.Bind("pick_name", &model.pickName);
    c.Bind("pick_decorator", &model.pickDecorator);
    c.Bind("qty", &model.qtyText);
    c.Bind("help", &model.help);
    c.Bind("note", &model.note);

    auto one = [this](int action)
    {
        return [this, action](Rml::DataModelHandle, Rml::Event&, const Rml::VariantList& arguments)
        {
            m_PendingAction = action;
            m_PendingArg = arguments.size() >= 1 ? arguments[0].Get<int>(0) : 0;
        };
    };
    c.BindEventCallback("bau_withdraw_open", one(ActionWithdrawOpen));
    c.BindEventCallback("bau_withdraw", one(ActionWithdraw));
    c.BindEventCallback("bau_split_open", one(ActionSplitOpen));
    c.BindEventCallback("bau_bag", one(ActionBag));
    c.BindEventCallback("bau_split", one(ActionSplit));
    c.BindEventCallback("bau_group", one(ActionGroup));
    c.BindEventCallback("bau_back", one(ActionBack));
    c.BindEventCallback("bau_close", one(ActionClose));
    m_Dirty = true;
}

void CBauJoiasWindow::Rebuild()
{
    m_Dirty = false;
    BauJoiasRmlModel& model = m_RmlView.GetModel();
    model.mode = m_Mode;
    model.note = g_Note;

    model.rows.clear();
    for (size_t i = 0; i < kRows.size(); ++i)
    {
        BauJoiasRow r;
        r.index = static_cast<int>(i);
        r.tdc = i >= kJewels;
        r.name = RowName(i);
        r.qty = g_Received ? Thousands(g_Balance[i]) : "...";
        r.decorator = CMercadoWindow::ItemSprite(kRows[i][0], kRows[i][1]);
        r.can = !r.tdc && g_Balance[i] > 0;
        model.rows.push_back(r);
    }

    model.bag.clear();
    if (m_Mode == 2)
        for (const auto& [slot, item] : BagJewels())
        {
            if (Count(item) < 2)
                continue;
            const int r = RowOf(item->Type);
            BauJoiasBagRow b;
            b.slot = slot;
            b.name = RowName(static_cast<size_t>(r));
            b.qty = "x " + std::to_string(Count(item));
            b.decorator = CMercadoWindow::ItemSprite(kRows[static_cast<size_t>(r)][0], kRows[static_cast<size_t>(r)][1]);
            model.bag.push_back(b);
        }

    model.pickName.clear();
    model.pickDecorator.clear();
    model.help.clear();
    if (m_Mode == 1 && m_Pick >= 0)
    {
        const size_t r = static_cast<size_t>(m_Pick);
        model.pickName = RowName(r) + " (tem " + Thousands(g_Balance[r]) + ")";
        model.pickDecorator = CMercadoWindow::ItemSprite(kRows[r][0], kRows[r][1]);
        model.help = "De 1 a " + Thousands(g_Balance[r]) +
                     ". Sai em pilhas de até 255; o que não couber na mochila volta pro baú.";
    }
    const ITEM* picked = m_Mode == 3 && m_Pick >= 0 ? UI::Inventory::FindPlayerItem(m_Pick) : nullptr;
    if (picked != nullptr && IsBankJewel(picked->Type))
    {
        const size_t r = static_cast<size_t>(RowOf(picked->Type));
        model.pickName = RowName(r) + " (pilha de " + std::to_string(Count(picked)) + ")";
        model.pickDecorator = CMercadoWindow::ItemSprite(kRows[r][0], kRows[r][1]);
        model.help = "De 1 a " + std::to_string(Count(picked) - 1) + ". A parte separada vai pra uma casa livre da mochila.";
    }

    // a quantidade não: o campo é de quem digita (só muda ao abrir Retirar ou Separar)
    for (const char* field : {"mode", "rows", "bag", "pick_name", "pick_decorator", "help", "note"})
        m_RmlView.MarkDirty(field);
}
