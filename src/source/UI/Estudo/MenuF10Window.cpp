#include "stdafx.h"
#include "UI/Estudo/MenuF10Window.h"
#include "UI/Core/WindowSystem.h"
#include "UI/Core/WindowCommon.h" // ShowSystemMenuDialog, g_pNewKeyInput
#include "Audio/DSPlaySound.h"
#include "Camera/CameraManager.h"
#include "Core/Input/KeyState.h"
#include "UI/RmlBridge/RmlDocumentVisibility.h"

#include <RmlUi/Core/DataModelHandle.h>
#include <RmlUi/Core/ElementDocument.h>
#include <RmlUi/Core/Event.h>

#include <iterator>

using namespace mu::ui::window;

namespace
{
// O que a casa faz quando nao e uma tecla do jogo.
constexpr int ActionReset = -1;
constexpr int ActionSystemMenu = -2;
constexpr int ActionColecoes = -3;
constexpr int ActionAlma = -4;
constexpr int ActionMercado = -5;
constexpr int ActionBauJoias = -6;

struct MenuF10Entry
{
    int key; // tecla do jogo (VK_* ou letra) ou uma das Action*
    const char* keyLabel;
    const char* name;
    const char* hint;
    const char* icon; // Data/Interface/RmlUi/menu_f10/<icon>.tga
};

// Os atalhos do cliente Godot que o MuMain tem (janela_atalhos.gd, mesma ordem e mesmos textos).
constexpr MenuF10Entry kEntries[] = {
    {'I', "I", "Inventário", "Itens, equipamento e zen. Arraste pra vestir.", "inventario"},
    {'C', "C", "Personagem", "Pontos de força, agilidade, vida e energia.", "personagem"},
    {'T', "T", "Missões", "As missões do Zoak de cada mapa e o que falta.", "quests"},
    {ActionReset, "", "Reset", "Reset e grand reset: o que falta e o prêmio.", "reset"},
    {ActionColecoes, "", "Coleções", "Entregue sets de armadura e ganhe bônus pra sempre.", "colecoes"},
    {ActionAlma, "", "Alma", "Pontos de alma de cada reset em 16 bônus.", "alma"},
    {ActionMercado, "", "Mercado", "Venda itens pra outros jogadores. A compra é no site.", "mercado"},
    {ActionBauJoias, "", "Baú de joias", "As joias guardadas da conta. Ctrl + botão direito guarda.", "bau_joias"},
    {'M', "M", "Mover de mapa", "Viajar pra outro mapa pagando zen.", "mover"},
    {VK_TAB, "Tab", "Minimapa", "O mapa do lugar onde você está.", "minimapa"},
    {'J', "J", "Comandos do chat", "Os comandos de barra (/) que o chat aceita.", "comandos_chat"},
    {'D', "D", "Comandos", "Troca, grupo, duelo e guilda com outro jogador.", "comandos"},
    {'F', "F", "Amigos", "Lista de amigos e cartas.", "amigos"},
    {'G', "G", "Guilda", "A sua guilda e os membros.", "guilda"},
    {'H', "H", "Eventos", "Horário dos eventos e quanto falta pra abrir.", "eventos"},
    {'K', "K", "Log de caça", "Dano, zen e exp por minuto e o dano no Boneco de Treino.", "log_caca"},
    {'B', "B", "Gens", "Duprian ou Vanert: a guerra das famílias.", "gens"},
    {'X', "X", "Loja de cash", "Itens da loja do jogo.", "cash"},
    {'Z', "Z", "MU Helper", "Configurar o que o helper caça e pega.", "helper"},
    {VK_HOME, "Home", "Ligar o Helper", "Liga e desliga a caça automática.", "ligar_helper"},
    {ActionSystemMenu, "Esc", "Menu do jogo", "Opções, trocar personagem e sair.", "menu_jogo"},
    {VK_F1, "F1", "Ajuda", "Todos os atalhos de mouse e teclado.", "ajuda"},
};
constexpr int kEntryCount = static_cast<int>(std::size(kEntries));
constexpr const char* kIdleHint = "Passe o mouse num ícone pra ver pra que serve. Ctrl+F10 solta o zoom da câmera.";
} // namespace

CMenuF10Window::CMenuF10Window() = default;

CMenuF10Window::~CMenuF10Window()
{
    Release();
}

bool CMenuF10Window::Create(CManager* pNewUIMng)
{
    if (pNewUIMng == nullptr)
        return false;

    m_pNewUIMng = pNewUIMng;
    m_pNewUIMng->AddUIObj(INTERFACE_MENU_F10, this);
    m_RmlView.Ensure();
    Show(false);
    return true;
}

void CMenuF10Window::Release()
{
    if (m_pNewUIMng)
    {
        m_pNewUIMng->RemoveUIObj(this);
        m_pNewUIMng = nullptr;
    }
    m_RmlView.Release();
}

bool CMenuF10Window::UpdateMouseEvent()
{
    // Casas e Fechar sao do RmlUi; aberto, segura o mouse pra nada atras disparar.
    return false;
}

bool CMenuF10Window::UpdateKeyEvent()
{
    // A tecla da casa clicada no quadro anterior: o CHotKey (ordem 1) le depois desta janela (ordem 10).
    if (m_PendingKey != 0)
    {
        g_pNewKeyInput->SetKeyState(m_PendingKey, CNewKeyInput::KEY_PRESS);
        m_PendingKey = 0;
        return true;
    }

    if (IsPress(VK_F10))
    {
        if (Core::Input::IsKeyDown(VK_CONTROL))
            return true; // Ctrl+F10 e o zoom (Winmain.cpp)
        g_pNewUISystem->Toggle(INTERFACE_MENU_F10);
        PlayBuffer(SOUND_CLICK01);
        return false;
    }

    if (IsVisible() && IsPress(VK_ESCAPE))
    {
        g_pNewUISystem->Hide(INTERFACE_MENU_F10);
        PlayBuffer(SOUND_CLICK01);
        return false;
    }
    return true;
}

bool CMenuF10Window::Update()
{
    SyncRmlModel();
    if (m_PendingCell == -1)
        return true;

    const int cell = m_PendingCell;
    m_PendingCell = -1;
    if (IsVisible())
        RunCell(cell);
    return true;
}

bool CMenuF10Window::Render()
{
    return true;
}

void CMenuF10Window::RunCell(int index)
{
    g_pNewUISystem->Hide(INTERFACE_MENU_F10);
    PlayBuffer(SOUND_CLICK01);
    if (index == kEntryCount)
        return; // Fechar
    if (index < 0 || index > kEntryCount)
        return;

    const int key = kEntries[index].key;
    if (key == ActionReset)
        g_pNewUISystem->Show(INTERFACE_RESET_SYSTEM);
    else if (key == ActionColecoes)
        g_pNewUISystem->Show(INTERFACE_COLECOES);
    else if (key == ActionAlma)
        g_pNewUISystem->Show(INTERFACE_ALMA);
    else if (key == ActionMercado)
        g_pNewUISystem->Show(INTERFACE_MERCADO);
    else if (key == ActionBauJoias)
    {
        // a mochila do lado: guardar é Ctrl + botão direito nela
        g_pNewUISystem->Show(INTERFACE_INVENTORY);
        g_pNewUISystem->Show(INTERFACE_BAU_JOIAS);
    }
    else if (key == ActionSystemMenu)
        ShowSystemMenuDialog();
    else
        m_PendingKey = key;
}

void CMenuF10Window::SetHint(int index)
{
    Rml::String hint = kIdleHint;
    if (index >= 0 && index < kEntryCount)
    {
        const MenuF10Entry& entry = kEntries[index];
        hint = entry.name;
        if (entry.keyLabel[0] != '\0')
            hint += Rml::String(" (") + entry.keyLabel + ")";
        hint += Rml::String(": ") + entry.hint;
    }

    MenuF10RmlModel& model = m_RmlView.GetModel();
    if (model.hint == hint)
        return;
    model.hint = hint;
    m_RmlView.MarkDirty("hint");
}

void CMenuF10Window::BindRmlModel(Rml::DataModelConstructor& c, MenuF10RmlModel& model)
{
    auto cell = c.RegisterStruct<MenuF10Cell>();
    cell.RegisterMember("name", &MenuF10Cell::name);
    cell.RegisterMember("key", &MenuF10Cell::key);
    cell.RegisterMember("icon", &MenuF10Cell::icon);
    cell.RegisterMember("index", &MenuF10Cell::index);
    c.RegisterArray<std::vector<MenuF10Cell>>();
    c.Bind("cells", &model.cells);
    c.Bind("hint", &model.hint);

    c.BindEventCallback("menuf10_click",
                        [this](Rml::DataModelHandle, Rml::Event&, const Rml::VariantList& arguments)
                        {
                            if (arguments.size() == 1)
                                m_PendingCell = arguments[0].Get<int>(-1);
                        });
    c.BindEventCallback("menuf10_close", [this](Rml::DataModelHandle, Rml::Event&, const Rml::VariantList&)
                        { m_PendingCell = kEntryCount; });
    c.BindEventCallback("menuf10_hover",
                        [this](Rml::DataModelHandle, Rml::Event&, const Rml::VariantList& arguments)
                        { SetHint(arguments.size() == 1 ? arguments[0].Get<int>(-1) : -1); });

    model.cells.clear();
    for (int i = 0; i < kEntryCount; ++i)
        model.cells.push_back({kEntries[i].name, kEntries[i].keyLabel, kEntries[i].icon, i});
    model.hint = kIdleHint;
}

void CMenuF10Window::SyncRmlModel()
{
    m_RmlView.Ensure();
    UI::RmlBridge::SyncDocumentVisibilityInFront(m_RmlView.Document(), IsVisible());
}

float CMenuF10Window::GetLayerDepth()
{
    return 10.62f;
}

float CMenuF10Window::GetKeyEventOrder()
{
    return 10.f;
}
