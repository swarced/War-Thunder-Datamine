let { sortPresetLists, setFavoritePresets, getTierWeaponsParams,
  getWeaponryByPresetInfo, convertPresetToBlk, prepareWeaponsPresetForView,
  getCustomPresetWeaponry
} = require("%scripts/weaponry/weaponryPresetsParams.nut")
let { getLastWeapon, setLastWeapon, addWeaponsFromBlk,
  getWeaponDisabledMods } = require("%scripts/weaponry/weaponryInfo.nut")
let { getModificationName } = require("%scripts/weaponry/bulletsInfo.nut")
let { getItemAmount, getItemCost, getItemStatusTbl } = require("%scripts/weaponry/itemInfo.nut")
let { getWeaponItemViewParams } = require("%scripts/weaponry/weaponryVisual.nut")
let { getTierDescTbl, updateWeaponTooltip, getTierTooltipParams
} = require("%scripts/weaponry/weaponryTooltipPkg.nut")
let { weaponsPurchase, canBuyItem } = require("%scripts/weaponry/weaponsPurchase.nut")
let { placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { RESET_ID, openPopupFilter } = require("%scripts/popups/popupFilter.nut")
let { openPopupList } = require("%scripts/popups/popupList.nut")
let { appendOnce } = require("%sqStdLibs/helpers/u.nut")
let { TIERS_NUMBER, MAX_PRESETS_NUM, CHAPTER_ORDER, CHAPTER_NEW_IDX, CHAPTER_FAVORITE_IDX,
  CUSTOM_PRESET_PREFIX, isCustomPreset, createNewPreset, createNewTiers,
  getUnitWeapons, updateTiersActivity, createNameCustomPreset
} = require("%scripts/weaponry/weaponryPresets.nut")
let { getStringWidthPx } = require("%scripts/viewUtils/daguiFonts.nut")
let { addCustomPresets, deleteCustomPresets } = require("%scripts/unit/unitWeaponryCustomPresets.nut")
let { cutPrefix } = require("%sqstd/string.nut")

const MY_FILTERS = "weaponry_presets/filters"

let FILTER_OPTIONS = ["Favorite", "Available", 1, 2, 3, 4]

::gui_handlers.weaponryPresetsModal <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType              = handlerType.MODAL
  sceneTplName         = "%gui/weaponry/weaponryPresetsModal"
  unit                 = null
  chosenPresetIdx      = null
  curPresetIdx         = null
  curTierIdx           = -1
  presetsList          = null
  chooseMenuList       = null
  presets              = null
  presetsByRanks       = null
  lastWeapon           = null
  presetsMarkup        = null
  collapsedPresets     = []
  presetTextWidth      = 0
  onChangeValueCb      = null
  weaponItemParams     = null
  favoriteArr          = null
  chapterPos           = 0
  wndWidth             = 0
  initLastWeapon       = null
  presetIdxToChildIdx  = null
  isAllBuyProcess      = false
  totalCost            = null
  multiPurchaseList    = null
  curEdiff             = null
  weaponryByPresetInfo = null
  filterStates         = null
  filterTypes          = null
  filterObj            = null
  myFilters            = null
  chosenPresetName     = null

  customIdx            = 0
  isEditMode           = false
  presetNest           = null
  availableWeapons     = null

  function getSceneTplView()
  {
    let tiersWidth = ::to_pixels("".concat(TIERS_NUMBER, "@tierIconSize"))
    let iconWidth = ::show_console_buttons ? ::to_pixels("1@cIco") : 0
    let tiersAndDescWidth = ::to_pixels("".concat(
      "1@narrowTooltipWidth+4@blockInterval+2@scrollBarSize+2@frameHeaderPad"))
        + tiersWidth + iconWidth
    presetTextWidth = ::min(::to_pixels("1@srw") - tiersAndDescWidth,
      ::to_pixels("1@modPresetTextMaxWidth"))
    wndWidth = tiersAndDescWidth + presetTextWidth
    chapterPos = presetTextWidth + 0.5 * tiersWidth + iconWidth
    weaponryByPresetInfo = getWeaponryByPresetInfo(unit, chooseMenuList)
    presets = weaponryByPresetInfo.presets
    favoriteArr = weaponryByPresetInfo.favoriteArr
    presetsList = weaponryByPresetInfo.presetsList
    lastWeapon = initLastWeapon ?? getLastWeapon(unit.name)
    chosenPresetName = lastWeapon
    presetsMarkup = getPresetsMarkup(presets)
    return {
      headerText = "".concat(::loc("modification/category/secondaryWeapon"), " ",
        ::loc("ui/mdash"), " ", ::getUnitName(unit))
      wndWidth = wndWidth
      chapterPos = chapterPos
      presets = presetsMarkup
      isShowConsoleBtn = ::show_console_buttons
    }
  }

  function initScreen()
  {
    let chpn = chosenPresetName
    chosenPresetIdx = presetsList.findindex(@(w) w.name == chpn) ?? 0
    presetNest = scene.findObject("presetNest")
    selectPreset(chosenPresetIdx)
    customIdx = presets.filter(isCustomPreset).reduce(
      @(res, value) max(res, cutPrefix(value.id, CUSTOM_PRESET_PREFIX).tointeger()+1), 0)
    updatePresetsByRanks()
    updateMultiPurchaseList()
    ::move_mouse_on_obj(scene.findObject($"presetHeader_{chosenPresetIdx}"))

    filterObj = scene.findObject("filter_nest")
    myFilters = ::load_local_account_settings($"{MY_FILTERS}/{unit.name}", ::DataBlock())
    fillFilterTypesList()
    // No need to update items if no stored filters for current unit
    if (myFilters != null)
      updateAllByFilters()

    openPopupFilter({
      scene = filterObj
      onChangeFn = onFilterCbChange.bindenv(this)
      filterTypes = getFiltersView()
      isTop = true
    })
    availableWeapons = unit.hasWeaponSlots ? getUnitWeapons(::get_full_unit_blk(unit.name)) : null
  }

  function updatePresetsByRanks() {
    presetsByRanks = {}
    foreach(p in presets)
      presetsByRanks[p.rank] <- (presetsByRanks?[p.rank] ?? []).append(p)
  }

  function getPresetsMarkup(pList) {
    presetIdxToChildIdx = {}
    let res = []
    if (pList == null)
      return res
    local curChapterOrd = 0
    foreach (preset in pList) {
      if (curChapterOrd != preset.chapterOrd) {
        curChapterOrd = preset.chapterOrd
        res.append({
          isCollapsable = true
          chapterName = ::loc($"weapons/purposeType/{CHAPTER_ORDER[curChapterOrd]}")
        })
      }

      let params = weaponItemParams ?
        weaponItemParams.__merge({visualDisabled = !preset.isEnabled}) : {}
      params.__update({
          collapsable = true
          showButtons = true
          actionBtnText = onChangeValueCb != null ? ::loc("mainmenu/btnSelect") : null
        })
      let idx = presets.findindex(@(p) p.id == preset.id)
      presetIdxToChildIdx[idx] <- res.len()
      let wpParams = getWeaponItemViewParams($"item_{idx}", unit, presetsList?[idx], params).__update({
        presetTextWidth = presetTextWidth
        isTypeNone = preset.purposeType == "NONE"
        tiers = presetsList[idx].tiers.map(@(t) {
          tierId        = t.tierId
          img           = t?.img ?? ""
          tierTooltipId = !::show_console_buttons ? t?.tierTooltipId : null
          isActive      = t?.isActive || "img" in t
        })
      })
      res.append({
        presetId  = idx
        chosen = idx == chosenPresetIdx ? "yes" : "no"
        weaponryItem = wpParams

      })
    }

    return res
  }

  function selectPreset(presetIdx, isForced = false) {
    if (curPresetIdx == presetIdx && !isForced)
      return

    if (!presetNest?.isValid())
      return

    local childIdx = presetIdxToChildIdx?[curPresetIdx]
    if (childIdx != null)
      presetNest.getChild(childIdx).selected = "no"

    let row = scene.findObject($"tiersNest_{curPresetIdx}")
    if (row?.isValid())
      row.setValue(-1)

    curPresetIdx = presetIdx
    childIdx = presetIdxToChildIdx?[presetIdx]
    if (childIdx != null) {
      let obj = presetNest.getChild(childIdx)
      obj.selected = "yes"
      obj.scrollToView()
    }

    updateDesc()
    updateButtons()
  }

  function selectTier(tierIdx) {
    curTierIdx = tierIdx
    updateTierDesc()
  }

  function getWeaponsPopupView(pos, tierId) {
    if (!unit.hasWeaponSlots)
      return null

    let buttons = []
    local weapons = {}
    let tierIdInt = tierId.tointeger()
    weapons = addWeaponsFromBlk(weapons, availableWeapons.filter(@(_) _?.tier == tierIdInt), unit)
    let params = getTierWeaponsParams(weapons, tierIdInt)
    let curTier = presets[curPresetIdx].tiers?[tierId.tointeger()]
    let curPresetId = curTier?.presetId ?? ""
    local maxWidth = 0
    foreach (p in params)
      maxWidth = ::max(maxWidth, getStringWidthPx(p.name, "fontMedium"))
    maxWidth += ::to_pixels("1@cIco")
    foreach (p in params)
      if (p.id != curPresetId)
        buttons.append({
          id = p.id
          holderId = tierId
          image = p.img
          funcName = "onItemClick"
          buttonClass = "image"
          visualStyle = "noFrame"
          text = p.name
          btnWidth = maxWidth
        })

    return {
      buttonsList = curTier == null ? buttons : buttons.append({
        id = "empty"
        holderId = tierId
        image = "#ui/gameuiskin#btn_close.svg"
        funcName = "onItemClick"
        buttonClass = "image"
        visualStyle = "noFrame"
        text = "#ui/empty"
        btnWidth = maxWidth
      })
      parentPos = pos
      onClickCb  = ::Callback(@(obj) onWeaponChoose(obj), this)
    }
  }

  function editPreset(obj) {
    let presetId = obj.presetId.tointeger()
    if (!isCustomPreset(presets[presetId]))
      return

    let value = obj.getValue()
    if (value < 0 || !presetNest?.isValid())
      return

    let presetObj = presetNest.findObject($"tiersNest_{presetId}")
    if (!presetObj?.isValid())
      return

    let tierObj = presetObj.getChild(value)
    if (!tierObj?.isValid())
      return

    if (value != 0) {// Preset tier
      let view = getWeaponsPopupView(tierObj.getPos(), tierObj.tierId)
      if (view)
        openPopupList(view)
    }
    else             // Preset header
      editPresetName(presetId)
  }

  function cancelPresetNameEdit(headerObj) {
    if (!headerObj?.isValid())
      return

    let editObj = ::showBtn("header_name_edit", false, headerObj)
    let name = editObj.getValue()
    let headerTextObj = ::showBtn("header_name_txt", true, headerObj)
    headerTextObj.setValue(name)
    let presetId = headerObj.presetId.tointeger()
    presetsList[presetId].customNameText <- name
  }

  function onCancelPresetNameEdit(obj) {
    cancelPresetNameEdit(obj.getParent())
  }

  function editPresetName(presetId) {
    let presetObj = presetNest.findObject($"tiersNest_{presetId}")
    if (!presetObj?.isValid())
      return

    let headerEditObj = ::showBtn("header_name_edit", true, presetObj)
    ::showBtn("header_name_txt", false, presetObj)
    headerEditObj.select()
  }

  function onWeaponChoose(obj) {
    let curListItem = presetsList[curPresetIdx]
    let curPreset = presets[curPresetIdx]
    let presetId = obj.id
    let tierId = obj.holderId.tointeger()
    if (presetId != "empty"){
      let wBlk = availableWeapons.findvalue(@(_) _.presetId == presetId && _.tier == tierId)
      curPreset.tiers[tierId] <- {slot = wBlk.slot, presetId = wBlk.presetId}
    }
    else
      delete curPreset.tiers[tierId]

    presets[curPresetIdx] = prepareWeaponsPresetForView(unit, curListItem,
      getCustomPresetWeaponry(convertPresetToBlk(curPreset) , unit), favoriteArr, availableWeapons)
    let presetIdx = curPresetIdx
    updateAllByFilters()
    selectPreset(presetIdx)
  }

  function onPresetSelect(obj) {
    selectPreset(obj.presetId.tointeger())
  }

  function onCellSelect(obj) {
    let presetId = obj.presetId.tointeger()
    let value = obj.getValue()
    if (value < 0) {
      if (presetId == curPresetIdx) {
        selectPreset(null)
        selectTier(null)
      }
      return
    }

    selectPreset(presetId)
    selectTier(value - 1)
    if (isEditMode)
      editPreset(obj)
  }

  function onPresetUnhover(obj) {
    if (::show_console_buttons)
      obj.setValue(-1)
  }

  function updateTierDesc()
  {
    local data = ""
    let descObj = scene.findObject("tierDesc")
    if (curTierIdx >= 0 && curPresetIdx != null)
    {
      let item = presetsList[curPresetIdx]
      let weaponry = item.tiers?[curTierIdx].weaponry
      data = weaponry ? ::handyman.renderCached(("%gui/weaponry/weaponTooltip"),
        getTierDescTbl(unit, getTierTooltipParams(weaponry, item.name, curTierIdx))) : ""
    }
    guiScene.replaceContentFromText(descObj, data, data.len())
  }

  function onModItemDblClick(obj)
  {
    let idx = curPresetIdx
    let params = ::u.search(presetsMarkup, @(i) i?.presetId == idx)
    if (params?.weaponryItem.actionBtnCanShow != "no")
      onModActionBtn()
  }

  function onModActionBtn(obj = null)
  {
    if (curPresetIdx == null)
      return

    doItemAction(presetsList[curPresetIdx])
  }

  function onAltModAction(obj)
  {
    if (curPresetIdx == null)
      return
    onBuy(presetsList[curPresetIdx])
  }

  function doItemAction(item)
  {
    guiScene.playSound("check")
    if (onChangeValueCb)
      onChangeValueCb(item)
    else
    {
      let amount = getItemAmount(unit, item)
      if(getLastWeapon(unit.name) == item.name || !amount)
      {
        if (item.cost <= 0)
          return
        return onBuy(item)
      }

      let disabledMods = getWeaponDisabledMods(unit, item)
      if (disabledMods.len() > 0)
      {
        showReqModsMsg(disabledMods)
        return
      }

      setLastWeapon(unit.name, item.name)
      ::check_secondary_weapon_mods_recount(unit)
      checkSaveBulletsAndDo()
    }
    guiScene.performDelayed(this, @()goBack())
  }

  function showReqModsMsg(disabledMods)
  {
    let aUnit = unit
    let modNames = disabledMods.map(@(n) ::colorize("userlogColoredText", getModificationName(aUnit, n)))
    let text = ::loc("weaponry/require_mod_install", {
      modNames = ::loc("ui/colon").join(modNames)
      numMods = disabledMods.len()
    })
    let onOk = ::Callback(@() installMods(disabledMods), this)
    ::scene_msg_box("activate_wager_message_box", null, text, [["yes", onOk], ["no"]], "yes")
  }

  function installMods(disabledMods)
  {
    let aUnit = unit
    let onSuccess = ::Callback(function() {
      disabledMods.each(@(n) ::updateAirAfterSwitchMod(aUnit, n))
      ::broadcastEvent("ModificationChanged")
    }, this)

    let taskId = enable_modifications(unit.name, disabledMods, true)
    ::g_tasker.addTask(taskId, { showProgressBox = true }, onSuccess)
  }

  function onBuy(item)
  {
    if (!::shop_is_weapon_available(unit.name, item.name, false, true))
      return
    checkSaveBulletsAndDo(::Callback((@(unit, item) function() {
      weaponsPurchase(unit, {modItem = item, open = false})
    })(unit, item), this))
  }

  function checkSaveBulletsAndDo(func = null)
  {
    local needSave = false
    if (lastWeapon != "" && lastWeapon != getLastWeapon(unit.name))
    {
      dagor.debug($"force cln_update due lastWeapon '{lastWeapon}' != {getLastWeapon(unit.name)}")
      needSave = true
      lastWeapon = getLastWeapon(unit.name)
    }

    if (needSave)
    {
      taskId = ::save_online_single_job(SAVE_WEAPON_JOB_DIGIT)
      if (taskId >= 0 && func)
      {
        let cb = ::u.isFunction(func) ? ::Callback(func, this) : func
        ::g_tasker.addTask(taskId, {showProgressBox = true}, cb)
      }
    }
    else if (func)
      func()
    return true
  }

  function updateDesc()
  {
    let descObj = scene.findObject("desc")
    if (curPresetIdx == null) {
      guiScene.replaceContentFromText(descObj, "", 0, this)
      return
    }
    updateWeaponTooltip(descObj, unit, presetsList[curPresetIdx], this, {
      curEdiff = curEdiff
      detail = INFO_DETAIL.FULL
    })
  }

  function updateButtons() {
    let haveSlots = unit.hasWeaponSlots && ::has_feature("WeaponryCustomPresets")
    let canCreatePreset = haveSlots && presets.filter(isCustomPreset).len() < MAX_PRESETS_NUM
    showSceneBtn("newPresetBtn", canCreatePreset)
    if (curPresetIdx == null)
    {
      showSceneBtn("actionBtn", false)
      showSceneBtn("altActionBtn", false)
      showSceneBtn("favoriteBtn", false)
      showSceneBtn("copyPresetBtn", false)
      showSceneBtn("editPresetBtn", false)
      showSceneBtn("deletePresetBtn", false)
      return
    }

    let isShowCustomPresetBtn = haveSlots && isCustomPreset(presets[curPresetIdx])
    showSceneBtn("copyPresetBtn", canCreatePreset)
    showSceneBtn("editPresetBtn", isShowCustomPresetBtn)
    showSceneBtn("deletePresetBtn", isShowCustomPresetBtn)

    let idx = curPresetIdx
    let params = ::u.search(presetsMarkup, @(i) i?.presetId == idx)
    let btnText = params?.weaponryItem.actionBtnText ?? ""
    let canBuy = presetsList[idx].cost > 0
    let actionBtnObj = showSceneBtn("actionBtn", btnText != ""
      && (idx != chosenPresetIdx || canBuy))
    if (btnText != "" && actionBtnObj?.isValid())
      actionBtnObj.setValue(btnText)
    let altBtnText = params?.weaponryItem.altBtnBuyText ?? ""
    let altActionBtnObj = showSceneBtn("altActionBtn", altBtnText != "")
    if (altBtnText != "" && altActionBtnObj?.isValid())
    {
      altActionBtnObj.setValue(altBtnText)
      altActionBtnObj.tooltip = params?.weaponryItem.altBtnTooltip ?? ""
    }
    let favoriteBtnObj = showSceneBtn("favoriteBtn", true)
    favoriteBtnObj.setValue(::loc(presetsList[curPresetIdx].chapterOrd != 1
      ? "mainmenu/btnFavorite" : "mainmenu/btnFavoriteUnmark"))
  }

  function updateAll(pList = null)
  {
    if (isAllBuyProcess)
      return

    if (!presetNest?.isValid())
      return

    presetsMarkup = getPresetsMarkup(pList ?? presets)
    let data = ::handyman.renderCached("%gui/weaponry/weaponryPreset", {
      chapterPos = chapterPos
      presets = presetsMarkup
      isShowConsoleBtn = ::show_console_buttons
    })
    guiScene.replaceContentFromText(presetNest, data, data.len(), this)
    // Select chosen or first preset
    local firstIdx = null
    foreach (idx, v in presetIdxToChildIdx){
      firstIdx = idx
      break
    }
    selectPreset(chosenPresetIdx in presetIdxToChildIdx ? chosenPresetIdx : firstIdx, true)

    // Enable/disable filter options depends on whether filtering result exist.
    let popupObj = filterObj.findObject("filter_popup")
    if (!popupObj?.isValid())
      return

    let fObj = popupObj.findObject("f_Favorite")
    let aObj = popupObj.findObject("f_Available")
    if (fObj?.isValid()) {
      fObj.setValue(isFavoritesExist() && filterStates.findindex(@(p) p == "f_Favorite") != null)
      fObj.enable(isFavoritesExist())
    }
    if (aObj?.isValid()) {
      aObj.setValue(isAvailablesExist() && filterStates.findindex(@(p) p == "f_Available") != null)
      aObj.enable(isAvailablesExist())
    }
  }

  function onEventWeaponPurchased(p) { updateAll(); updateMultiPurchaseList() }

  function onCollapse(obj)
  {
    let itemObj = obj?.collapse_header ? obj : obj.getParent()
    let listObj = itemObj?.isValid() ? itemObj.getParent() : null
    if (!listObj?.isValid() || !itemObj?.collapse_header)
      return

    itemObj.collapsing = "yes"
    let isShow = itemObj?.collapsed == "yes"
    let listLen = listObj.childrenCount()
    local selIdx = listObj.getValue()
    local headerIdx = -1
    local needReselect = false

    local found = false
    for (local i = 0; i < listLen; i++)
    {
      let child = listObj.getChild(i)
      if (!found)
      {
        if (child?.collapsing == "yes")
        {
          child.collapsing = "no"
          child.collapsed  = isShow ? "no" : "yes"
          headerIdx = i
          found = true
        }
      }
      else
      {
        if (child?.collapse_header)
          break
        child.show(isShow)
        child.enable(isShow)
        if (!isShow && i == selIdx)
          needReselect = true
      }
    }

    if (needReselect)
    {
      let indexes = []
      for (local i = selIdx + 1; i < listLen; i++)
        indexes.append(i)
      for (local i = selIdx - 1; i >= 0; i--)
        indexes.append(i)

      local newIdx = -1
      foreach (idx in indexes)
      {
        let child = listObj.getChild(idx)
        if (!child?.collapse_header && child.isEnabled())
        {
          newIdx = idx
          break
        }
      }
      selIdx = newIdx != -1 ? newIdx : headerIdx
      listObj.setValue(selIdx)
    }

    if (collapsedPresets && !::u.isEmpty(itemObj?.id))
    {
      let idx = ::find_in_array(collapsedPresets, itemObj.id)
      if (isShow && idx != -1)
        collapsedPresets.remove(idx)
      else if (!isShow && idx == -1)
        collapsedPresets.append(itemObj.id)
    }
  }

  function onChangeFavorite(obj)
  {
    let preset = presets[curPresetIdx]
    let isFavorite = preset.chapterOrd == CHAPTER_FAVORITE_IDX
    let chapterOrd = !isFavorite ? CHAPTER_FAVORITE_IDX
      : isCustomPreset(preset) ? CHAPTER_NEW_IDX
      : CHAPTER_ORDER.findindex(@(p) p == preset.purposeType)
    if (isFavorite)
    {
      let idx = favoriteArr.findindex(@(id) id == preset.id)
      if (idx != null)
        favoriteArr.remove(idx)
    }
    else
      favoriteArr.append(preset.id)
    setFavoritePresets(unit.name, favoriteArr)
    preset.chapterOrd = chapterOrd
    presetsList[curPresetIdx].chapterOrd = chapterOrd
    sortPresetLists([presets, presetsList])
    updateAllByFilters()
  }

  function getFiltersView() {
    let view = { checkbox = []}
    foreach(key, inst in filterTypes)
      view.checkbox.append({
        id = inst.id
        idx = inst.idx
        text = inst.text
        isDisable = inst.isDisable
        value = !inst.isDisable && filterStates.findindex(@(v) v == key) != null
      })
    view.checkbox.sort(@(a,b) a.idx <=> b.idx)
    return [view]
  }

  isFavoritesExist = @() favoriteArr.len() > 0
  isAvailablesExist = @() presets.filter(@(p) p.isEnabled).len() > 0

  function fillFilterTypesList() {
    filterStates = myFilters ? myFilters % "array" : []
    filterTypes = {}
    foreach(idx, key in FILTER_OPTIONS) {
      let isRank = typeof(key) != "string"
      if ((isRank && !presetsByRanks?[key]))
        continue

      let id = $"f_{key}"
      filterTypes[id] <- {
        id    = id
        idx   = idx
        isDisable = (key == FILTER_OPTIONS[0] && !isFavoritesExist())
          || (key == FILTER_OPTIONS[1] && !isAvailablesExist())
        text  = isRank ? $"{::loc("conditions/rank")} {::get_roman_numeral(key)}"
          : ::loc($"mainmenu/only{key}")
      }
    }
  }

  function updateAllByFilters() {
    local isFavorite = false
    local isAvailable = false
    local pList = []
    // All presets have been filtered by rank an placed into presetsByRanks
    // to avoid excess job by each checkbox choice.
    foreach (inst in filterStates) {
      if (inst != "f_Favorite" && inst != "f_Available") {
        let p = presetsByRanks?[inst.split("f_")[1].tointeger()]
        if (p != null)
         pList.extend(p)
      } else {
        isFavorite = inst == "f_Favorite" || isFavorite
        isAvailable = inst == "f_Available" || isAvailable
      }
    }

    if (pList.len() == 0 || !isFavorite || !isAvailable) {
      presets = weaponryByPresetInfo.presets
      presetsList = weaponryByPresetInfo.presetsList
      // Get all presets if no rank choosen
      pList = pList.len() == 0 ? presets : pList
    }
    if (isFavorite || isAvailable) {
      // Ignore filtering if stored filter has no result for current unit presets.
      let isExistFavorites = isFavoritesExist()
      let isExistAvailables = isAvailablesExist()
      let filterFunc = @(p)
        (!isFavorite || !isExistFavorites || p.chapterOrd == CHAPTER_FAVORITE_IDX)
          && (!isAvailable || !isExistAvailables || p.isEnabled)
      pList = pList.filter(filterFunc)
      presets = presets.filter(filterFunc)
      presetsList = presetsList.filter(filterFunc)
    }

    let chpn = chosenPresetName
    chosenPresetIdx = presetsList.findindex(@(w) w.name == chpn)
    updateAll(pList)
  }

  function onFilterCbChange(objId, tName, value) {
    let isReset = objId == RESET_ID
    foreach (key, inst in filterTypes)
    {
      if (!isReset && inst.id != objId)
        continue

      if (value)
        appendOnce(key, filterStates)
      else {
        let idx = filterStates.findindex(@(v) v == key)
        if (idx != null)
          filterStates.remove(idx)
      }
    }

    updateAllByFilters()
    ::save_local_account_settings($"{MY_FILTERS}/{unit.name}",
      ::build_blk_from_container(filterStates))
  }

  function onPresetNew(obj){
    let idx = customIdx++
    let newPreset = createNewPreset(idx)
    presets.append(newPreset)
    presetsList.append(newPreset.__merge({
      name = newPreset.id
      type = weaponsItem.weapon
      tiers = createNewTiers(availableWeapons)
    }))
    updateAllByFilters()
    switchEditMode(true)
    selectPreset(presets.len() - 1)
  }

  function onPresetCopy(obj){
    let idx = customIdx++
    let id = $"{CUSTOM_PRESET_PREFIX}{idx}"
    let customNameText = createNameCustomPreset(idx)
    presets.append(presets[curPresetIdx].__merge({id, customNameText, chapterOrd = CHAPTER_NEW_IDX}))
    local newListItem = ::u.copy(presetsList[curPresetIdx]).__update({
      name = id
      customNameText
    })
    updateTiersActivity(newListItem.tiers, availableWeapons)
    presetsList.append(newListItem)
    updateAllByFilters()
    switchEditMode(true)
    selectPreset(presets.len() - 1)
  }

  function onPresetDelete(obj) {
    let curPreset = presets?[curPresetIdx]
    if (curPreset == null)
      return

    let curUnit = unit
    let presetIdx = curPresetIdx
    msgBox("question_delete_preset",
      ::loc("msgbox/genericRequestDelete", { item = curPreset.customNameText }),
      [
        ["delete", function() {
          deleteCustomPresets(curUnit, curPreset.id)
          presets.remove(presetIdx)
          presetsList.remove(presetIdx)
          updateAllByFilters()
        }],
        ["cancel", function() {} ]
      ], "cancel")
  }

  function onPresetEdit(obj){
    switchEditMode(!isEditMode)
  }

  function switchEditMode(isEdit) {
    if (!isEdit) {
      cancelPresetNameEdit(scene.findObject($"presetHeader_{curPresetIdx}"))
      let curPreset = presets?[curPresetIdx]
      if (curPreset != null) {
        addCustomPresets(unit, curPreset.id, convertPresetToBlk(curPreset))
        if (curPresetIdx == chosenPresetIdx)
          ::hangar_force_reload_model()
      }
    }
    isEditMode = isEdit
    let editBtmObj = scene.findObject("editPresetBtn")
    editBtmObj.setValue(isEditMode ? ::loc("filesystem/btnSave") : ::loc("msgbox/btn_edit"))
  }

  // DEVELOPERS OPTION ONLY
  function updateBuyAllBtn()
  {
    let isShow = multiPurchaseList.len() > 0
    if (isShow)
      placePriceTextToButton(scene, "btn_buyAll", ::loc("mainmenu/btnBuyAll"), totalCost)

    showSceneBtn("btn_buyAll", isShow)
  }

  onBuyAll = @() buyAll()
  onEventProfileUpdated = @ (p) updateBuyAllBtn()

  function updateMultiPurchaseList()
  {
    multiPurchaseList = []
    if (isAllBuyProcess || !::has_feature("BuyAllPresets"))
      return

    totalCost = ::Cost()
    foreach (item in presetsList)
    {
      let statusTbl = getItemStatusTbl(unit, item)
      if (!::shop_is_weapon_available(unit.name, item.name, false, true) || !statusTbl.canBuyMore)
        continue

      multiPurchaseList.append(item)
      totalCost += getItemCost(unit, item).multiply(statusTbl.maxAmount - statusTbl.amount)
    }

    updateBuyAllBtn()
  }

  function buyAll()
  {
    if (!multiPurchaseList.len())
    {
      isAllBuyProcess = false
      ::save_online_single_job(SAVE_WEAPON_JOB_DIGIT)
      updateAll()
      updateMultiPurchaseList()
      return
    }

    if (!canBuyItem(totalCost, unit))
      return

    let item = multiPurchaseList.pop()
    let statusTbl = getItemStatusTbl(unit, item)
    totalCost -= getItemCost(unit, item).multiply(statusTbl.maxAmount - statusTbl.amount)
    isAllBuyProcess = true
    weaponsPurchase(unit, {modItem = item, open = false, silent = true, isAllPresetPurchase = true,
      afterSuccessfullPurchaseCb = ::Callback(@() buyAll(), this)})
  }
}

return {
  open = function(params)
  {
    ::handlersManager.loadHandler(::gui_handlers.weaponryPresetsModal, params)
  }
}