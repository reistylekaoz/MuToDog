#include "stdafx.h"
#include "UI/Estudo/MercadoWindow.h"
#include "UI/Core/WindowSystem.h"
#include "UI/Core/WindowCommon.h"
#include "Audio/DSPlaySound.h"
#include "Core/Text/Utf8.h"
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
#include <SDL3/SDL_misc.h>

#include <algorithm>
#include <array>
#include <cctype>
#include <fstream>
#include <set>

using namespace mu::ui::window;

namespace
{
constexpr std::uint8_t PacketCode = 0xFB;
constexpr std::uint8_t CommandSell = 0x10;
constexpr std::uint8_t CommandCancel = 0x11;
constexpr std::uint8_t CommandList = 0x12;
constexpr std::uint8_t CommandRetire = 0x13;
constexpr std::uint8_t CommandPass = 0x14;
constexpr int MaxOffers = 30;
constexpr const char* IconsFile = "Data/Interface/RmlUi/dados/itens_icones.json";
constexpr const char* SiteUrl = "https://mu-estudo.integraction.com.br/mercado/?passe=";

constexpr int ActionNone = 0;
constexpr int ActionSellOpen = 1;
constexpr int ActionBag = 2;
constexpr int ActionCoin = 3;
constexpr int ActionSell = 4;
constexpr int ActionBack = 5;
constexpr int ActionCancel = 6;
constexpr int ActionRetire = 7;
constexpr int ActionSite = 8;
constexpr int ActionClose = 9;

// as moedas aceitas, na ordem do servidor (MercadoJoias.Moedas): as 15 joias do baú e a TDC (255,255)
constexpr std::array<std::array<int, 2>, 16> kCoins = {{{14, 13}, {14, 14}, {14, 16}, {14, 22}, {14, 31}, {14, 41},
                                                        {14, 42}, {12, 15}, {14, 43}, {14, 44}, {14, 151}, {14, 152},
                                                        {14, 153}, {14, 156}, {14, 157}, {255, 255}}};

struct Offer
{
    int id = 0;
    int coinGroup = 0;
    int coinNumber = 0;
    std::uint32_t price = 0;
    std::array<std::uint8_t, 12> item{};
};

struct Delivery
{
    int id = 0;
    int reason = 0; // 1 comprado, 2 devolvido
    std::array<std::uint8_t, 12> item{};
};

std::vector<Offer> g_Offers;
std::vector<Delivery> g_Deliveries;
bool g_Received = false;
std::uint32_t g_Version = 1;
std::string g_Note;

std::uint32_t ReadLe32(const std::uint8_t* p)
{
    return static_cast<std::uint32_t>(p[0]) | (static_cast<std::uint32_t>(p[1]) << 8) |
           (static_cast<std::uint32_t>(p[2]) << 16) | (static_cast<std::uint32_t>(p[3]) << 24);
}

void WriteLe32(BYTE* p, std::uint32_t v)
{
    for (int i = 0; i < 4; ++i)
        p[i] = static_cast<BYTE>((v >> (8 * i)) & 0xFF);
}

const std::set<std::string>& IconKeys()
{
    static std::set<std::string> keys;
    static bool loaded = false;
    if (!loaded)
    {
        loaded = true;
        std::ifstream file(IconsFile);
        if (file)
        {
            const nlohmann::json list = nlohmann::json::parse(file, nullptr, false);
            if (list.is_array())
                for (const auto& k : list)
                    if (k.is_string())
                        keys.insert(k.get<std::string>());
        }
    }
    return keys;
}

std::string Sprite(int group, int number)
{
    const std::string key = std::to_string(group) + "," + std::to_string(number);
    if (IconKeys().count(key) == 0)
        return {};
    return "image(item-" + std::to_string(group) + "-" + std::to_string(number) + ")";
}

std::string ItemName(int group, int number)
{
    const int type = group * MAX_ITEM_INDEX + number;
    if (ItemAttribute == nullptr || group < 0 || number < 0 || type >= MAX_ITEM)
        return "Item " + std::to_string(group) + "," + std::to_string(number);
    return Core::Text::ToUtf8(ItemAttribute[type].Name);
}

std::string CoinName(int group, int number)
{
    if (group == 255 && number == 255)
        return "TDC";
    std::string name = ItemName(group, number);
    for (const char* prefix : {"Jewel of ", "Jewel Of "})
        if (name.rfind(prefix, 0) == 0)
            name = name.substr(std::char_traits<char>::length(prefix));
    return name;
}

std::string Thousands(std::uint32_t v)
{
    std::string digits = std::to_string(v);
    for (int i = static_cast<int>(digits.size()) - 3; i > 0; i -= 3)
        digits.insert(static_cast<size_t>(i), ".");
    return digits;
}

// os 12 bytes do item no formato do S6 (o servidor grava o mercado sempre assim)
struct ItemBytes
{
    int group = 0;
    int number = 0;
    int level = 0;
    bool luck = false;
    bool skill = false;
    int excellent = 0;
};

ItemBytes Decode(const std::array<std::uint8_t, 12>& b)
{
    ItemBytes it;
    it.number = b[0] | ((b[3] & 0x80) != 0 ? 256 : 0);
    it.level = (b[1] & 0x78) >> 3;
    it.luck = (b[1] & 4) != 0;
    it.skill = (b[1] & 0x80) != 0;
    it.excellent = b[3] & 0x3F;
    it.group = b[5] >> 4;
    return it;
}

std::string ItemLabel(int group, int number, int level, bool excellent)
{
    std::string name = ItemName(group, number);
    if (excellent)
        name = "Excellent " + name;
    if (level > 0)
        name += " +" + std::to_string(level);
    return name;
}

std::string ItemLabel(const ItemBytes& it)
{
    return ItemLabel(it.group, it.number, it.level, it.excellent != 0);
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

void SendWithId(std::uint8_t command, int id)
{
    BYTE packet[8] = {0xC1, 8, PacketCode, command};
    WriteLe32(packet + 4, static_cast<std::uint32_t>(id));
    SendRaw(packet, static_cast<int>(sizeof(packet)));
}

void SendSell(int slot, int coin, std::uint32_t price)
{
    BYTE packet[12] = {0xC1, 12, PacketCode, CommandSell, static_cast<BYTE>(slot),
                       static_cast<BYTE>(kCoins[static_cast<size_t>(coin)][0])};
    const int number = kCoins[static_cast<size_t>(coin)][1];
    packet[6] = static_cast<BYTE>(number & 0xFF);
    packet[7] = static_cast<BYTE>((number >> 8) & 0xFF);
    WriteLe32(packet + 8, price);
    SendRaw(packet, static_cast<int>(sizeof(packet)));
}

// "1.500" ou "1500" vira 1500; 0 quando não é número ou passa do que cabe em 32 bits
std::uint32_t ParsePrice(const std::string& text)
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
} // namespace

CMercadoWindow::CMercadoWindow() = default;

CMercadoWindow::~CMercadoWindow()
{
    Release();
}

bool CMercadoWindow::Create(CManager* pNewUIMng)
{
    if (pNewUIMng == nullptr)
        return false;

    m_pNewUIMng = pNewUIMng;
    m_pNewUIMng->AddUIObj(INTERFACE_MERCADO, this);
    m_RmlView.Ensure();
    Show(false);
    return true;
}

void CMercadoWindow::Release()
{
    if (m_pNewUIMng)
    {
        m_pNewUIMng->RemoveUIObj(this);
        m_pNewUIMng = nullptr;
    }
    m_RmlView.Release();
}

void CMercadoWindow::Show(bool bShow)
{
    CObject::Show(bShow);
    if (bShow)
    {
        m_Mode = 0;
        m_PickSlot = -1;
        m_Coin = -1;
        g_Note.clear();
        SendSimple(CommandList);
        m_Dirty = true;
    }
}

void CMercadoWindow::ReceivePacket(const std::uint8_t* packet, int size)
{
    if (packet == nullptr || size < 5)
        return;
    if (packet[0] == 0xC2 && size >= 7 && packet[3] == PacketCode && packet[4] == 0x10)
    {
        const int offers = packet[5];
        const int deliveries = packet[6];
        if (size < 7 + offers * 23 + deliveries * 17)
            return;
        g_Offers.clear();
        g_Deliveries.clear();
        const std::uint8_t* p = packet + 7;
        for (int i = 0; i < offers; ++i, p += 23)
        {
            Offer o;
            o.id = static_cast<int>(ReadLe32(p));
            o.coinGroup = p[4];
            o.coinNumber = p[5] | (p[6] << 8);
            o.price = ReadLe32(p + 7);
            std::copy(p + 11, p + 23, o.item.begin());
            g_Offers.push_back(o);
        }
        for (int i = 0; i < deliveries; ++i, p += 17)
        {
            Delivery d;
            d.id = static_cast<int>(ReadLe32(p));
            d.reason = p[4];
            std::copy(p + 5, p + 17, d.item.begin());
            g_Deliveries.push_back(d);
        }
        g_Received = true;
        g_Note.clear();
        ++g_Version;
        return;
    }
    if (packet[0] == 0xC1 && size >= 4 && packet[2] == PacketCode && packet[3] == CommandPass)
    {
        std::string pass;
        for (int i = 4; i < size && i < packet[1]; ++i)
            if (packet[i] >= '0' && packet[i] < 127 && std::isalnum(packet[i]))
                pass += static_cast<char>(packet[i]);
        if (pass.empty())
            return;
        const std::string url = SiteUrl + pass;
        g_Note = SDL_OpenURL(url.c_str()) ? "O mercado abriu no navegador (o passe vale 2 minutos)."
                                          : "Não deu pra abrir o navegador: " + url;
        ++g_Version;
    }
}

bool CMercadoWindow::UpdateMouseEvent()
{
    // Aberta, segura o mouse (tudo é do RmlUi).
    return false;
}

bool CMercadoWindow::UpdateKeyEvent()
{
    if (IsVisible() && IsPress(VK_ESCAPE))
    {
        m_PendingAction = m_Mode > 0 ? ActionBack : ActionClose;
        PlayBuffer(SOUND_CLICK01);
        return false;
    }
    return true;
}

bool CMercadoWindow::Update()
{
    const bool inGame = SceneFlag == MAIN_SCENE && Hero != nullptr;
    if (!inGame && g_Received)
    {
        // escolha de personagem: o próximo pede de novo
        g_Offers.clear();
        g_Deliveries.clear();
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

    const std::string bag = m_Mode == 1 ? BagSignature() : std::string();
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

bool CMercadoWindow::Render()
{
    return true;
}

float CMercadoWindow::GetLayerDepth()
{
    return 10.64f;
}

float CMercadoWindow::GetKeyEventOrder()
{
    return 10.0f;
}

std::string CMercadoWindow::BagSignature() const
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

void CMercadoWindow::RunPending()
{
    const int action = m_PendingAction;
    m_PendingAction = ActionNone;
    if (action == ActionNone)
        return;
    MercadoRmlModel& model = m_RmlView.GetModel();
    switch (action)
    {
    case ActionSellOpen:
        if (static_cast<int>(g_Offers.size()) >= MaxOffers)
        {
            g_Note = "Já são 30 itens à venda: cancele um pra pôr outro.";
            break;
        }
        m_Mode = 1;
        m_PickSlot = -1;
        m_Coin = -1;
        model.priceText.clear();
        m_RmlView.MarkDirty("price");
        g_Note.clear();
        break;
    case ActionBag:
        if (UI::Inventory::FindPlayerItem(m_PendingArg) != nullptr)
        {
            m_PickSlot = m_PendingArg;
            m_Mode = 2;
        }
        break;
    case ActionCoin:
        if (m_PendingArg >= 0 && m_PendingArg < static_cast<int>(kCoins.size()))
        {
            m_Coin = m_PendingArg;
            m_Mode = 3;
        }
        break;
    case ActionSell:
    {
        const std::uint32_t price = ParsePrice(model.priceText);
        if (m_PickSlot < 0 || m_Coin < 0 || UI::Inventory::FindPlayerItem(m_PickSlot) == nullptr)
        {
            m_Mode = 1;
            break;
        }
        if (price == 0)
        {
            g_Note = "Escreva o preço só com números, maior que zero.";
            break;
        }
        // o servidor tira o item da mochila e responde a lista nova (o erro chega em azul no chat)
        SendSell(m_PickSlot, m_Coin, price);
        g_Note = "Pondo à venda...";
        m_Mode = 0;
        m_PickSlot = -1;
        m_Coin = -1;
        break;
    }
    case ActionBack:
        m_Mode = m_Mode > 0 ? m_Mode - 1 : 0;
        g_Note.clear();
        break;
    case ActionCancel:
        SendWithId(CommandCancel, m_PendingArg);
        g_Note = "Cancelando: o item volta pela lista de retirar.";
        break;
    case ActionRetire:
        SendWithId(CommandRetire, m_PendingArg);
        g_Note = "Retirando...";
        break;
    case ActionSite:
        SendSimple(CommandPass);
        g_Note = "Pedindo o passe do site...";
        break;
    case ActionClose:
        g_pNewUISystem->Hide(INTERFACE_MERCADO);
        break;
    default:
        break;
    }
    PlayBuffer(SOUND_CLICK01);
    m_Dirty = true;
}

void CMercadoWindow::BindRmlModel(Rml::DataModelConstructor& c, MercadoRmlModel& model)
{
    auto row = c.RegisterStruct<MercadoRow>();
    row.RegisterMember("name", &MercadoRow::name);
    row.RegisterMember("info", &MercadoRow::info);
    row.RegisterMember("decorator", &MercadoRow::decorator);
    row.RegisterMember("good", &MercadoRow::good);
    row.RegisterMember("id", &MercadoRow::id);
    c.RegisterArray<std::vector<MercadoRow>>();
    auto bag = c.RegisterStruct<MercadoBagRow>();
    bag.RegisterMember("name", &MercadoBagRow::name);
    bag.RegisterMember("decorator", &MercadoBagRow::decorator);
    bag.RegisterMember("slot", &MercadoBagRow::slot);
    c.RegisterArray<std::vector<MercadoBagRow>>();
    auto coin = c.RegisterStruct<MercadoCoinRow>();
    coin.RegisterMember("name", &MercadoCoinRow::name);
    coin.RegisterMember("decorator", &MercadoCoinRow::decorator);
    coin.RegisterMember("index", &MercadoCoinRow::index);
    c.RegisterArray<std::vector<MercadoCoinRow>>();

    c.Bind("mode", &model.mode);
    c.Bind("loaded", &model.loaded);
    c.Bind("deliveries_title", &model.deliveriesTitle);
    c.Bind("offers_title", &model.offersTitle);
    c.Bind("deliveries", &model.deliveries);
    c.Bind("offers", &model.offers);
    c.Bind("bag", &model.bag);
    c.Bind("coins", &model.coins);
    c.Bind("pick_name", &model.pickName);
    c.Bind("pick_decorator", &model.pickDecorator);
    c.Bind("coin_name", &model.coinName);
    c.Bind("coin_decorator", &model.coinDecorator);
    c.Bind("price", &model.priceText);
    c.Bind("note", &model.note);

    auto one = [this](int action)
    {
        return [this, action](Rml::DataModelHandle, Rml::Event&, const Rml::VariantList& arguments)
        {
            m_PendingAction = action;
            m_PendingArg = arguments.size() >= 1 ? arguments[0].Get<int>(0) : 0;
        };
    };
    c.BindEventCallback("mer_sell_open", one(ActionSellOpen));
    c.BindEventCallback("mer_bag", one(ActionBag));
    c.BindEventCallback("mer_coin", one(ActionCoin));
    c.BindEventCallback("mer_sell", one(ActionSell));
    c.BindEventCallback("mer_back", one(ActionBack));
    c.BindEventCallback("mer_cancel", one(ActionCancel));
    c.BindEventCallback("mer_retire", one(ActionRetire));
    c.BindEventCallback("mer_site", one(ActionSite));
    c.BindEventCallback("mer_close", one(ActionClose));
    m_Dirty = true;
}

void CMercadoWindow::Rebuild()
{
    m_Dirty = false;
    MercadoRmlModel& model = m_RmlView.GetModel();
    model.mode = m_Mode;
    model.loaded = g_Received;
    model.note = g_Note;

    model.deliveries.clear();
    for (const Delivery& d : g_Deliveries)
    {
        const ItemBytes it = Decode(d.item);
        MercadoRow r;
        r.id = d.id;
        r.name = ItemLabel(it);
        r.decorator = Sprite(it.group, it.number);
        r.good = d.reason == 1;
        r.info = d.reason == 1 ? "comprado" : "devolvido";
        model.deliveries.push_back(r);
    }
    model.deliveriesTitle = "Para retirar (" + std::to_string(g_Deliveries.size()) + ")";

    model.offers.clear();
    for (const Offer& o : g_Offers)
    {
        const ItemBytes it = Decode(o.item);
        MercadoRow r;
        r.id = o.id;
        r.name = ItemLabel(it);
        r.decorator = Sprite(it.group, it.number);
        r.info = Thousands(o.price) + " " + CoinName(o.coinGroup, o.coinNumber);
        model.offers.push_back(r);
    }
    model.offersTitle = "À venda (" + std::to_string(g_Offers.size()) + " de " + std::to_string(MaxOffers) + ")";

    model.bag.clear();
    if (m_Mode == 1)
    {
        // FindPlayerItem acha o item em todas as casas que ele cobre: só a primeira entra
        std::set<const ITEM*> seen;
        for (int slot = MAX_EQUIPMENT_INDEX; slot < MAX_MY_INVENTORY_EX_INDEX; ++slot)
        {
            const ITEM* item = UI::Inventory::FindPlayerItem(slot);
            if (item == nullptr || item->Type < 0 || !seen.insert(item).second)
                continue;
            const int group = item->Type / MAX_ITEM_INDEX;
            const int number = item->Type % MAX_ITEM_INDEX;
            MercadoBagRow b;
            b.slot = slot;
            b.name = ItemLabel(group, number, item->Level, (item->ExcellentFlags & 63) != 0);
            b.decorator = Sprite(group, number);
            model.bag.push_back(b);
        }
    }

    if (model.coins.empty())
        for (size_t i = 0; i < kCoins.size(); ++i)
        {
            MercadoCoinRow coin;
            coin.index = static_cast<int>(i);
            coin.name = CoinName(kCoins[i][0], kCoins[i][1]);
            coin.decorator = Sprite(kCoins[i][0], kCoins[i][1]);
            model.coins.push_back(coin);
        }

    const ITEM* picked = m_PickSlot >= 0 ? UI::Inventory::FindPlayerItem(m_PickSlot) : nullptr;
    model.pickName.clear();
    model.pickDecorator.clear();
    if (picked != nullptr)
    {
        const int group = picked->Type / MAX_ITEM_INDEX;
        const int number = picked->Type % MAX_ITEM_INDEX;
        model.pickName = ItemLabel(group, number, picked->Level, (picked->ExcellentFlags & 63) != 0);
        model.pickDecorator = Sprite(group, number);
    }
    model.coinName.clear();
    model.coinDecorator.clear();
    if (m_Coin >= 0)
    {
        model.coinName = CoinName(kCoins[static_cast<size_t>(m_Coin)][0], kCoins[static_cast<size_t>(m_Coin)][1]);
        model.coinDecorator = Sprite(kCoins[static_cast<size_t>(m_Coin)][0], kCoins[static_cast<size_t>(m_Coin)][1]);
    }

    // o preço não: o campo é de quem digita (só zera ao abrir Vender item)
    for (const char* field : {"mode", "loaded", "deliveries_title", "offers_title", "deliveries", "offers", "bag", "coins",
                              "pick_name", "pick_decorator", "coin_name", "coin_decorator", "note"})
        m_RmlView.MarkDirty(field);
}
