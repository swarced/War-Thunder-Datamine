require("%scripts/onlineShop/ingameConsoleStore.nut")

let seenList = require("%scripts/seen/seenList.nut").get(SEEN.EXT_XBOX_SHOP)
let shopData = require("%scripts/onlineShop/xboxShopData.nut")
let statsd = require("statsd")
let xboxSetPurchCb = require("%scripts/onlineShop/xboxPurchaseCallback.nut")


let sheetsArray = [
  {
    id = "xbox_game_content"
    locId = "itemTypes/xboxGameContent"
    getSeenId = @() "##xbox_item_sheet_" + mediaType
    mediaType = xboxMediaItemType.GameContent
    sortParams = [
      {param = "releaseDate", asc = false}
      {param = "releaseDate", asc = true}
      {param = "price", asc = false}
      {param = "price", asc = true}
      {param = "isBought", asc = false}
      {param = "isBought", asc = true}
    ]
    sortSubParam = "name"
    contentTypes = [null, ""]
  },
  {
    id = "xbox_game_consumation"
    locId = "itemTypes/xboxGameConsumation"
    getSeenId = @() "##xbox_item_sheet_" + mediaType
    mediaType = xboxMediaItemType.GameConsumable
    sortParams = [
      {param = "price", asc = false}
      {param = "price", asc = true}
    ]
    sortSubParam = "consumableQuantity"
    contentTypes = ["eagles"]
  }
]

foreach (sh in sheetsArray)
{
  let sheet = sh
  seenList.setSubListGetter(sheet.getSeenId(), @() (
    shopData.xboxProceedItems?[sheet.mediaType] ?? []).filter(@(it) !it.canBeUnseen()).map(@(it) it.getSeenId()))
}

::gui_handlers.XboxShop <- class extends ::gui_handlers.IngameConsoleStore
{
  function loadCurSheetItemsList()
  {
    itemsList = itemsCatalog?[curSheet.mediaType] ?? []
  }

  function onEventXboxSystemUIReturn(p)
  {
    curItem = getCurItem()
    if (!curItem)
      return

    let wasItemBought = curItem.isBought
    curItem.updateIsBoughtStatus()

    let wasPurchasePerformed = wasItemBought != curItem.isBought

    if (wasPurchasePerformed)
    {
      broadcastEvent("EntitlementStoreItemPurchased", {id = curItem.id})
      statsd.send_counter("sq.close_product.purchased", 1)
      ::add_big_query_record("close_product",
        ::save_to_json({
          itemId = curItem.id,
          action = "purchased"
        })
      )
      ::g_tasker.addTask(::update_entitlements_limited(),
        {
          showProgressBox = true
          progressBoxText = ::loc("charServer/checking")
        },
        ::Callback(function() {
          updateSorting()
          fillItemsList()
          ::g_discount.updateOnlineShopDiscounts()

          if (curItem.isMultiConsumable || wasPurchasePerformed)
            ::update_gamercards()
        }, this)
      )
    }
  }

  function goBack()
  {
    ::g_tasker.addTask(::update_entitlements_limited(),
      {
        showProgressBox = true
        progressBoxText = ::loc("charServer/checking")
      },
      ::Callback(function() {
        ::g_discount.updateOnlineShopDiscounts()
        ::update_gamercards()
      })
    )

    base.goBack()
  }
}

let openIngameStore = ::kwarg(
  function(chapter = null, curItemId = "", afterCloseFunc = null, statsdMetric = "unknown") {
    if (!::isInArray(chapter, [null, "", "eagles"]))
      return false

    if (shopData.canUseIngameShop())
    {
      shopData.requestData(
        false,
        @() ::handlersManager.loadHandler(::gui_handlers.XboxShop, {
          itemsCatalog = shopData.xboxProceedItems
          chapter = chapter
          curItem = curItemId != "" ? shopData.getShopItem(curItemId) : null
          afterCloseFunc = afterCloseFunc
          titleLocId = "topmenu/xboxIngameShop"
          storeLocId = "items/openIn/XboxStore"
          seenEnumId = SEEN.EXT_XBOX_SHOP
          seenList = seenList
          sheetsArray = sheetsArray
        }),
        true,
        statsdMetric
      )
      return true
    }

    ::queues.checkAndStart(::Callback(function() {
      xboxSetPurchCb(afterCloseFunc)
      ::get_gui_scene().performDelayed(::getroottable(),
        @() ::xbox_show_marketplace(chapter == "eagles")
      )
    }, this),
    null,
    "isCanUseOnlineShop")

    return true
  }
)

return shopData.__merge({
  openIngameStore = openIngameStore
  getEntStoreLocId = @() shopData.canUseIngameShop()? "#topmenu/xboxIngameShop" : "#msgbox/btn_onlineShop"
  getEntStoreIcon = @() shopData.canUseIngameShop()? "#ui/gameuiskin#xbox_store_icon.svg" : "#ui/gameuiskin#store_icon.svg"
  isEntStoreTopMenuItemHidden = @(...) !shopData.canUseIngameShop() || !::isInMenu()
  getEntStoreUnseenIcon = @() SEEN.EXT_XBOX_SHOP
  needEntStoreDiscountIcon = true
  openEntStoreTopMenuFunc = @(obj, handler) openIngameStore({statsdMetric = "topmenu"})
})