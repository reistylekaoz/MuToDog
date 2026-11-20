#include "stdafx.h"

#include "UI/Inventory/InventoryContents.h"

#include "GameLogic/Items/InventoryUtils.h"
#include "UI/Core/WindowSystem.h"
#include "UI/Inventory/InventoryCtrl.h"
#include "UI/Inventory/MyInventory.h"

namespace UI::Inventory
{
void ClearAllItems()
{
    g_pMyInventory->UnequipAllItems();
    g_pMyInventory->DeleteAllItems();
    g_pMyInventoryExt->DeleteAllItems();
    g_pMyShopInventory->DeleteAllItems();
}

void RemoveItem(int index)
{
    if (const int slot = mu::ui::window::EquipmentSlotOfServer(index); slot != -1)
        g_pMyInventory->UnequipItem(slot);
    else if (IsMainInventorySlot(index))
        g_pMyInventory->DeleteItem(index);
    else if (IsInventoryExtensionSlot(index))
        g_pMyInventoryExt->DeleteItem(index);
    else if (IsMyShopSlot(index))
        g_pMyShopInventory->DeleteItem(index);
}

void RemoveDroppedItem(int index)
{
    if (const int slot = mu::ui::window::EquipmentSlotOfServer(index); slot != -1)
        g_pMyInventory->UnequipItem(slot);
    else
        g_pMyInventory->DeleteItem(index);
}

bool InsertItem(int index, std::span<const std::uint8_t> itemData)
{
    // as casas do estudo (237..239) caem dentro das da loja pessoal: vêm antes dela
    if (const int slot = mu::ui::window::EquipmentSlotOfServer(index); slot != -1)
        return g_pMyInventory->EquipItem(slot, itemData);
    if (IsMainInventorySlot(index))
        return g_pMyInventory->InsertItem(index, itemData);
    if (IsInventoryExtensionSlot(index))
        return g_pMyInventoryExt->InsertItem(index, itemData);
    if (IsMyShopSlot(index))
        return g_pMyShopInventory->InsertItem(index, itemData);
    return false;
}

void DiscardPickedItem()
{
    mu::ui::window::CInventoryCtrl::DeletePickedItem();
}

void RestorePickedItem()
{
    mu::ui::window::CInventoryCtrl::BackupPickedItem();
}

int TransferSourceIndex()
{
    if (auto* pickedItem = mu::ui::window::CInventoryCtrl::GetPickedItem())
        return pickedItem->GetSourceLinealPos();

    return g_pMyShopInventory->GetSourceIndex();
}

bool ReceivePlayerTransfer(int index, std::span<const std::uint8_t> itemData)
{
    DiscardPickedItem();

    if (const int slot = mu::ui::window::EquipmentSlotOfServer(index); slot != -1)
    {
        g_pMyInventory->EquipItem(slot, itemData);
        return true;
    }

    if (IsPlayerInventorySlot(index))
    {
        g_pStorageInventory->ProcessStorageItemAutoMoveSuccess();
        g_pStorageInventoryExt->ProcessStorageItemAutoMoveSuccess();
        return InsertItem(index, itemData);
    }

    if (IsMyShopSlot(index))
        return g_pMyShopInventory->InsertItem(index, itemData);

    return true;
}

void RejectTransfer()
{
    RestorePickedItem();
    if (g_pStorageInventory->IsItemAutoMove())
        g_pStorageInventory->ProcessStorageItemAutoMoveFailure();
    if (g_pStorageInventoryExt->IsItemAutoMove())
        g_pStorageInventoryExt->ProcessStorageItemAutoMoveFailure();
}

bool HasPickedItem()
{
    return mu::ui::window::CInventoryCtrl::GetPickedItem() != nullptr;
}

ITEM* FindPlayerItem(int index)
{
    if (!IsPlayerInventorySlot(index))
        return nullptr;

    if (IsMainInventorySlot(index))
        return g_pMyInventory != nullptr ? g_pMyInventory->FindItem(index) : nullptr;

    return g_pMyInventoryExt != nullptr ? g_pMyInventoryExt->FindItem(index) : nullptr;
}

ITEM* FindMainInventoryItem(int index)
{
    return g_pMyInventory->FindItem(index);
}

void DeleteMainInventoryItem(int index)
{
    g_pMyInventory->DeleteItem(index);
}

ITEM* StandbyItem()
{
    return g_pMyInventory->GetStandbyItem();
}

int StandbyItemIndex()
{
    return g_pMyInventory->GetStandbyItemIndex();
}
} // namespace UI::Inventory
