
#if !defined(AFX_NEWUIMYINVENTORY_H__74DA6D7A_CF5A_46E9_8C72_9D38F0DC95EC__INCLUDED_)
#define AFX_NEWUIMYINVENTORY_H__74DA6D7A_CF5A_46E9_8C72_9D38F0DC95EC__INCLUDED_

#pragma once

#include "Render/RmlUi/RmlUiRuntime.h"
#include "UI/Core/WindowObject.h"
#include "UI/Inventory/InventoryCtrl.h"
#include "UI/Dialogs/MessageBox.h"
#include "UI/Core/WindowManager.h"
#include "UI/Inventory/InventoryActionController.h"
#include "GameLogic/Items/IInventoryActionContext.h"
#include "Data/GameData/ItemData/ItemTagSet.h"
#include "UI/RmlBridge/RmlThemedView.h"
#include "UI/Inventory/ItemCameraTarget.h"
#include "UI/Inventory/ItemGridModel.h"
#include <span>
#include <vector>
#include "Core/Globals/_enum.h"

namespace Rml { class ElementDocument; }

namespace mu::ui::window
{
    // MuToDog (MU Estudo, rodada 18): as 3 casas do estudo depois das 12 do MuMain, brinco direito (237 no
    // servidor), brinco esquerdo (238) e pet (239). Na janela elas são as casas 12, 13 e 14; o item guarda o número
    // do servidor (lineal_pos) e só ele vai e volta pela rede.
    inline constexpr int EQUIPMENT_EARRING_RIGHT = MAX_EQUIPMENT_INDEX;
    inline constexpr int EQUIPMENT_EARRING_LEFT = MAX_EQUIPMENT_INDEX + 1;
    inline constexpr int EQUIPMENT_PET = MAX_EQUIPMENT_INDEX + 2;
    inline constexpr int MAX_EQUIPMENT_SLOTS = MAX_EQUIPMENT_INDEX + 3;
    inline constexpr int SERVER_SLOT_EARRING_RIGHT = 237;
    inline constexpr int SERVER_SLOT_PET = 239;
    // A casa da janela -> o número do servidor (as 12 do MuMain ficam iguais).
    constexpr int ServerEquipmentSlot(int slot)
    {
        return slot >= MAX_EQUIPMENT_INDEX ? SERVER_SLOT_EARRING_RIGHT + slot - MAX_EQUIPMENT_INDEX : slot;
    }
    // O número do servidor -> a casa da janela; -1 se não é casa de equipamento.
    constexpr int EquipmentSlotOfServer(int index)
    {
        if (index >= 0 && index < MAX_EQUIPMENT_INDEX)
            return index;
        if (index >= SERVER_SLOT_EARRING_RIGHT && index <= SERVER_SLOT_PET)
            return MAX_EQUIPMENT_INDEX + index - SERVER_SLOT_EARRING_RIGHT;
        return -1;
    }

    class CMyInventory
        : public CObject
        , public SEASON3B::IInventoryActionContext
    {
    public:
        enum IMAGE_LIST
        {
            IMAGE_INVENTORY_MYSHOP_OPEN_BTN = BITMAP_MYSHOPINTERFACE_NEW_PERSONALINVENTORY_BEGIN + 1,
            IMAGE_INVENTORY_MYSHOP_CLOSE_BTN = BITMAP_MYSHOPINTERFACE_NEW_PERSONALINVENTORY_BEGIN + 2,
            IMAGE_INVENTORY_BACK = CMessageBoxMng::IMAGE_MSGBOX_BACK,
            IMAGE_INVENTORY_BACK_TOP = BITMAP_INTERFACE_NEW_PERSONALINVENTORY_BEGIN,	//"newui_item_back01.tga"
            IMAGE_INVENTORY_BACK_TOP2,	//"newui_item_back04.tga"
            IMAGE_INVENTORY_BACK_LEFT,	//"newui_item_back02-L.tga"
            IMAGE_INVENTORY_BACK_RIGHT,	//"newui_item_back02-R.tga"
            IMAGE_INVENTORY_BACK_BOTTOM,	//"newui_item_back03.tga"
            IMAGE_INVENTORY_ITEM_BOOT,	//"newui_item_boots.tga"
            IMAGE_INVENTORY_ITEM_HELM,	//"newui_item_cap.tga"
            IMAGE_INVENTORY_ITEM_FAIRY,	//"newui_item_fairy.tga"
            IMAGE_INVENTORY_ITEM_WING,	//"newui_item_wing.tga"
            IMAGE_INVENTORY_ITEM_RIGHT,	//"newui_item_weapon(L).tga"
            IMAGE_INVENTORY_ITEM_LEFT,	//"newui_item_weapon(R).tga"
            IMAGE_INVENTORY_ITEM_ARMOR,	//"newui_item_upper.tga"
            IMAGE_INVENTORY_ITEM_GLOVES,	//"newui_item_gloves.tga"
            IMAGE_INVENTORY_ITEM_PANTS,	//"newui_item_lower.tga"
            IMAGE_INVENTORY_ITEM_RING,	//"newui_item_ring.tga"
            IMAGE_INVENTORY_ITEM_NECKLACE,	//"newui_item_necklace.tga"
            IMAGE_INVENTORY_MONEY,	//"newui_item_money.tga"
            IMAGE_INVENTORY_EXIT_BTN, //"newui_exit_00.tga"
            IMAGE_INVENTORY_REPAIR_BTN, //"newui_repair_00.tga"
            IMAGE_INVENTORY_EXPAND_BTN, //"newui_expansion_btn.tga"
        };

        enum MYSHOP_MODE
        {
            MYSHOP_MODE_OPEN = 0,
            MYSHOP_MODE_CLOSE,
        };

    private:

        typedef struct tagEQUIPMENT_ITEM
        {
            // The theme's slot and its #<slot>_item, where they are drawn (window pixels).
            float x, y;
            float width, height;
            DWORD dwBgImage;
            float itemX, itemY;
            float itemWidth, itemHeight;
        } EQUIPMENT_ITEM;

        CManager* m_pNewUIMng;
        CInventoryCtrl* m_pNewInventoryCtrl;
        CInventoryActionController m_ActionController;


        EQUIPMENT_ITEM m_EquipmentSlots[MAX_EQUIPMENT_SLOTS];
        // Os itens das casas do estudo (brincos e pet); as 12 do MuMain ficam em CharacterMachine->Equipment.
        ITEM m_ExtraEquipment[MAX_EQUIPMENT_SLOTS - MAX_EQUIPMENT_INDEX]{};
        int	m_iPointedSlot;

        MYSHOP_MODE m_MyShopMode;
        SEASON3B::REPAIR_MODE m_RepairMode;
        DWORD m_dwStandbyItemKey;

        bool m_bRepairEnableLevel;
        bool m_bMyShopOpen;
        bool m_bMyShopLocked = false;

        // The whole window is RmlUi: the equipped and the grid's items are live 3D, drawn into the
        // document's #item_view (m_ItemTarget).
        struct MyInventoryRmlModel
        {
            // Shared transform group for this document, sourced from UI::Scaling::GetActiveTransform()
            // since this window is movable (SetPos()), not HUD-anchored.
            float textPx = 0.f; // UI::RmlBridge::SyncNativeTextSize()

            Rml::String title;
            Rml::String goldText;
            Rml::String goldTier; // UI::RmlBridge::GoldTierKey() of the amount

            bool repairVisible = false;
            Rml::String repairTooltip;

            bool myShopVisible = false;
            bool myShopModeOpen = true;
            bool myShopLocked = false;
            Rml::String myShopTooltip;

            Rml::String exitTooltip;
            Rml::String expandTooltip;

            // Set/Socket option header labels. The shared hover tooltip itself is
            // UI::RmlBridge::Tooltip, not part of this model -- see SyncRmlModel().
            Rml::String setOptionLabel;
            Rml::String socketOptionLabel;
            bool setOptionActive = false;    // IsAncientSetEquipped() -- label color
            bool socketOptionActive = false; // IsSocketSetOptionEnabled() -- label color
            bool setOptionHovered = false;
            bool socketOptionHovered = false;

            // Per EQUIPMENT_* slot: "no-art", or its tint ("broken", "durability-20/30/50",
            // "unequipable"), and "refused" while the item on the cursor cannot go in.
            std::vector<Rml::String> slotStates = std::vector<Rml::String>(MAX_EQUIPMENT_SLOTS);
            UI::Items::ItemGridCells gridCells;
        };
        void BindRmlModel(Rml::DataModelConstructor& c, MyInventoryRmlModel& model);
        void OnRmlBuilt();
        UI::RmlBridge::ThemedView<MyInventoryRmlModel> m_RmlView{"my_inventory",
            [this](Rml::DataModelConstructor& c, MyInventoryRmlModel& model) { BindRmlModel(c, model); },
            {{"Data/Interface/RmlUi/my_inventory.rml"}},
            {.afterBuild = [this] { OnRmlBuilt(); }}};

        void BuildRmlUi();
        void SyncRmlModel();
        // The equipment slots' states and the grid's cells, into the model.
        void SyncSlotStates();

    public:
        CMyInventory();
        virtual ~CMyInventory();

        bool Create(CManager* pNewUIMng);
        void Release();

        // iIndex: a casa da janela (0..MAX_EQUIPMENT_SLOTS - 1).
        bool EquipItem(int iIndex, std::span<const BYTE> pbyItemPacket);
        void UnequipItem(int iIndex);
        // O item vestido na casa da janela (as 12 do MuMain e as 3 do estudo); nullptr fora delas.
        ITEM* GetEquippedItem(int slot);
        const ITEM* GetEquippedItem(int slot) const;
        // A casa do estudo do item (EQUIPMENT_EARRING_RIGHT, _LEFT ou EQUIPMENT_PET); -1 se ele não vai nelas.
        static int EstudoSlotOf(int type);
        // The center of an equipment slot in window pixels; false for a slot number outside the
        // equipment or one the theme does not draw.
        bool GetEquipmentSlotCenter(int slot, POINT& center) const;
        void UnequipAllItems();

        SEASON3B::REPAIR_MODE GetRepairMode() const override;
        bool IsEquipable(int iIndex, ITEM* pItem) const override;
        void ResetMouseRButton() override;
        void ResetMouseLButton() override;
        int  FindEmptySlot(ITEM* pItem) const override;
        bool IsRepairEnableLevel() const override;

        bool InsertItem(int iIndex, std::span<const BYTE> pbyItemPacket) const;
        void DeleteItem(int iIndex) const;
        void DeleteAllItems() const;

        // Moves the equipment slots and item grid to where the theme draws their anchors.
        void SyncNativeLayout();

        void SetRepairMode(bool bRepair);

#ifdef LJH_ADD_SYSTEM_OF_EQUIPPING_ITEM_FROM_INVENTORY
        BOOL IsInvenItem(const short sType);
#endif

        bool UpdateMouseEvent() override;
        bool UpdateKeyEvent() override;
        bool Update() override;
        bool Render() override;
        Rml::ElementDocument* GetPlacedDocument() const override { return m_RmlView.Document(); }
        void Render3D();

        bool IsVisible() const override;

        void OpenningProcess();
        void ClosingProcess();

        float GetLayerDepth() override;

        CInventoryCtrl* GetInventoryCtrl() const;

        ITEM* FindItem(int iLinealPos) const;
        ITEM* FindItemByKey(DWORD dwKey) const;
        int   FindItemIndex(short int siType, int iLevel = -1) const;
        int   FindItemReverseIndex(short sType, int iLevel = -1) const;
        int   FindEmptySlot(IN int cx, IN int cy) const;
        int   FindEmptySlotIncludingExtensions(IN int cx, IN int cy) const;
        int   FindEmptySlotIncludingExtensions(ITEM* pItem) const;
        bool  IsItem(short int siType, bool bcheckPick = false) const;
        int   GetNumItemByKey(DWORD dwItemKey) const;
        int   GetNumItemByType(short sItemType) const;
        BYTE  GetDurabilityPointedItem() const;
        int   GetPointedItemIndex() const;
        int   FindManaItemIndex() const;
        int   FindHealingItemIndex() const;

        void  SetStandbyItemKey(DWORD dwItemKey);
        DWORD GetStandbyItemKey() const;
        int   GetStandbyItemIndex() const;
        ITEM* GetStandbyItem() const;

        void SetRepairEnableLevel(bool bOver);

        void ChangeMyShopButtonStateOpen();
        void ChangeMyShopButtonStateClose();
        void LockMyShopButtonOpen();
        void UnlockMyShopButtonOpen();

        void CreateEquippingEffect(ITEM* pItem);

        static bool CanRegisterItemHotKey(int iType);
        static bool HandleInventoryActions(CInventoryCtrl* targetControl);

        // Public to allow refresh when resolution changes
        void SetEquipmentSlotInfo();

    protected:
        void DeleteEquippingEffect();
        void DeleteEquippingEffectBug(ITEM* pItem);

    private:
        void LoadImages() const;
        void UnloadImages();

        // The inventory index of an item with the tag, in the order the game takes them
        // (ItemDatabase::GetItemTypesWithTagInUseOrder); -1 if there is none.
        int FindItemIndexWithTagInUseOrder(Data::Items::ItemTag tag) const;

        bool EquipmentWindowProcess();
        // The pointer over the drawn panel.
        bool IsPointerOverPanel() const;
        // Whether the item in equipmentSlot may be taken off here; tells the
        // player why not.
        bool CheckTakeOff(int equipmentSlot) const;
        bool InventoryProcess() const;
        bool WindowProcess();

        void RenderItemToolTip(int iSlotIndex) const;
        bool CanOpenMyShopInterface();
        void ToggleRepairMode();

        // The equipped and the grid's items, into the document's #item_view. Last, so it is
        // destroyed first.
        UI::Items::ItemCameraTarget m_ItemTarget{[this](const Rml::Vector2f&, const Rml::Vector2f&) { Render3D(); }};
    };

} // namespace mu::ui::window

#endif // !defined(AFX_NEWUIMYINVENTORY_H__74DA6D7A_CF5A_46E9_8C72_9D38F0DC95EC__INCLUDED_)
