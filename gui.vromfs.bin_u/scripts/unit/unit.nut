local { blkFromPath } = require("sqStdLibs/helpers/datablockUtils.nut")
local { isDataBlock, isString, isArray, isTable, isFunction, isEmpty } = require("sqStdLibs/helpers/u.nut")
local time = require("scripts/time.nut")
local contentPreview = require("scripts/customization/contentPreview.nut")
local shopSearchCore = require("scripts/shop/shopSearchCore.nut")
local stdMath = require("std/math.nut")
local platform = require("scripts/clientState/platform.nut")
local { getLastWeapon,
        isWeaponEnabled,
        isWeaponVisible } = require("scripts/weaponry/weaponryInfo.nut")
local { unitClassType, getUnitClassTypeByExpClass } = require("scripts/unit/unitClassType.nut")
local unitTypes = require("scripts/unit/unitTypesList.nut")
local { isModClassExpendable } = require("scripts/weaponry/modificationInfo.nut")

local MOD_TIERS_COUNT = 4

//!!FIX ME: better to convert weapons and modifications to class
local weaponProperties = [
  "reqRank", "reqExp", "mass_per_sec", "mass_per_sec_diff",
  "repairCostCoef", "repairCostCoefArcade", "repairCostCoefHistorical", "repairCostCoefSimulation",
  "caliber", "deactivationIsAllowed", "isTurretBelt", "bulletsIconParam"
]
local reqNames = ["reqWeapon", "reqModification"]
local upgradeNames = ["weaponUpgrade1", "weaponUpgrade2", "weaponUpgrade3", "weaponUpgrade4"]

local defaultAvailableWeapons = {
  hasRocketDistanceFuse = false
  hasBombs = false
  bombsNbr = -1
  hasDepthCharges = false
  hasMines = false
  hasTorpedoes = false
  hasCountermeasures = false
}

local Unit = class
{
   name = ""
   rank = 0
   shopCountry = ""
   isInited = false //is inited by wpCost, warpoints, and unitTags

   expClass = unitClassType.UNKNOWN
   unitType = unitTypes.INVALID
   esUnitType = ::ES_UNIT_TYPE_INVALID
   isPkgDev = false

   cost = 0
   costGold = 0
   reqExp = 0
   expMul = 1.0
   gift = null //""
   giftParam = null //""
   premPackAir = false
   repairCost = 0
   repairTimeHrsArcade = 0
   repairTimeHrsHistorical = 0
   repairTimeHrsSimulation = 0
   freeRepairs = 0
   trainCost = 0
   train2Cost = 0
   train3Cost_gold = 0
   train3Cost_exp = 0
   gunnersCount = 0
   hasDepthCharge = false

   isInShop = false
   reqAir = null //name of unit required by shop tree
   group = null //name of units group in shop
   fakeReqUnits = null //[] or null when no required fake units
   showOnlyWhenBought = false
   showOnlyWhenResearch = false
   showOnlyIfPlayerHasUnlock = null //"" or null
   hideForLangs = null //[] or null when no lang restrictions
   reqFeature = null //"" or null
   hideFeature = null //"" or null
   reqUnlock = null //"" or null

   customImage = null //""
   customClassIco = null //""
   customTooltipImage = null //""

   tags = null //[]
   weapons = null //[]
   modifications = null //[]
   skins = null //[]
   skinsBlocks = null //{}
   previewSkinId = null //""
   weaponUpgrades = null //[]
   spare = null //{} or null
   needBuyToOpenNextInTier = null //[]

   commonWeaponImage = "#ui/gameuiskin#weapon"
   primaryBullets = null //{}
   secondaryBullets = null //{}
   bulletsIconParam = 0

   availableWeaponsByWeaponName = null

   shop = null //{} - unit params table for shop unit info
   info = null //{} - tank params info

   testFlight = ""

   isToStringForDebug = true

   //!!FIX ME: params below are still set from outside of unit
   modificatorsRequestTime = -1
   modificators = null //{} or null
   modificatorsBase = null //{} or null
   minChars = null //{} or null
   maxChars = null //{} or null
   primaryWeaponMods = null //[] or null
   secondaryWeaponMods = null //{} or null
   bulGroups = -1
   bulModsGroups = -1
   bulletsSets = null //{}
   primaryBulletsInfo = null //[] or null
   shopReq = true //used in shop, but look like shop can get it from other sources than from unit.
   researchType = null
   marketplaceItemdefId = null

   defaultWeaponPreset = null
   disableFlyout       = false
   hideBrForVehicle    = false

  //unit table generated by native function gather_and_build_aircrafts_list
  constructor(unitTbl)
  {
    //!!FIX ME: Is it really required? we can init units by unittags self without native code
    foreach(key, value in unitTbl)
      if (key in this)
        this[key] = value

    foreach(key in ["tags", "weapons", "modifications", "skins", "weaponUpgrades", "needBuyToOpenNextInTier"])
      if (!isArray(this[key]))
        this[key] = []
    foreach(key in ["shop", "info", "primaryBullets", "secondaryBullets", "bulletsSets", "skinsBlocks"])
      if (!isTable(this[key]))
        this[key] = {}
  }

  function setFromUnit(unit)
  {
    foreach(key, value in unit)
      if (!isFunction(value)
        && (key in this)
        && !isFunction(this[key])
      )
        this[key] = value
    return this
  }

  function initOnce()
  {
    if (isInited)
      return null
    isInited = true
    local errorsTextArray = []

    local warpoints = ::get_warpoints_blk()
    local uWpCost = getUnitWpCostBlk()
    if (!isDataBlock(uWpCost))
      uWpCost = ::DataBlock() //units list generated by airtags blk, so they can be missing in warpoints.blk

    local expClassStr = uWpCost?.unitClass
    expClass = getUnitClassTypeByExpClass(expClassStr)
    esUnitType = expClass.unitTypeCode
    unitType = unitTypes.getByEsUnitType(esUnitType)

    foreach(p in [
      "costGold", "rank", "reqExp",
      "repairCost", "repairTimeHrsArcade", "repairTimeHrsHistorical", "repairTimeHrsSimulation",
      "train2Cost", "train3Cost_gold", "train3Cost_exp",
      "gunnersCount", "bulletsIconParam"
    ])
      this[p] = uWpCost?[p] ?? 0

    cost                      = uWpCost?.value || 0
    freeRepairs               = uWpCost?.freeRepairs ?? warpoints?.freeRepairs ?? 0
    expMul                    = uWpCost?.expMul ?? 1.0
    shopCountry               = uWpCost?.country ?? ""
    trainCost                 = uWpCost?.trainCost ?? warpoints?.trainCostByRank?["rank"+rank] ?? 0
    gift                      = uWpCost?.gift
    giftParam                 = uWpCost?.giftParam
    premPackAir               = uWpCost?.premPackAir ?? false
    hasDepthCharge            = uWpCost?.hasDepthCharge ?? false
    commonWeaponImage         = uWpCost?.commonWeaponImage ?? commonWeaponImage
    customClassIco            = uWpCost?.customClassIco
    customTooltipImage        = uWpCost?.customTooltipImage
    isPkgDev                  = ::is_dev_version && (uWpCost?.pkgDev ?? false)
    researchType              = uWpCost?.researchType
    hideBrForVehicle          = tags.contains("hideBrForVehicle")

    foreach (weapon in weapons)
      weapon.type <- ::g_weaponry_types.WEAPON.type

    if (isDataBlock(uWpCost?.weapons))
    {
      foreach (weapon in weapons)
        initWeaponry(weapon, uWpCost.weapons?[weapon.name])
      initWeaponryUpgrades(this, uWpCost)
    }

    if (isDataBlock(uWpCost?.modifications))
      foreach(modName, modBlk in uWpCost.modifications)
      {
        local mod = { name = modName, type = ::g_weaponry_types.MODIFICATION.type }
        modifications.append(mod)
        initWeaponry(mod, modBlk)
        initWeaponryUpgrades(mod, modBlk)
        if (isModClassExpendable(mod))
          mod.type = ::g_weaponry_types.EXPENDABLES.type

        if (modBlk?.maxToRespawn)
          mod.maxToRespawn <- modBlk.maxToRespawn

        //validate prevModification. it used in gui only.
        if (("prevModification" in mod) && !(uWpCost?.modifications[mod.prevModification]))
          errorsTextArray.append(format("Not exist prevModification '%s' for '%s' (%s)",
                                 delete mod.prevModification, modName, name))
      }

    if (isDataBlock(uWpCost?.spare))
    {
      spare = {
        name = "spare"
        type = ::g_weaponry_types.SPARE.type
        cost = uWpCost?.spare?.value || 0
        image = ::get_weapon_image(esUnitType, ::get_modifications_blk()?.modifications?.spare, uWpCost?.spare)
      }
      if (uWpCost?.spare?.costGold != null)
        spare.costGold <- uWpCost.spare.costGold
    }

    for(local i = 1; i <= MOD_TIERS_COUNT; i++)
      needBuyToOpenNextInTier.append(uWpCost?["needBuyToOpenNextInTier" + i] || 0)

    customImage = uWpCost?.customImage ?? ::get_unit_preset_img(name)
    if (!customImage && ::is_tencent_unit_image_reqired(this))
      customImage = ::get_tomoe_unit_icon(name)
    if (customImage && !::isInArray(customImage.slice(0, 1), ["#", "!"]))
      customImage = ::get_unit_icon_by_unit(this, customImage)
    availableWeaponsByWeaponName = {}
    shopSearchCore.cacheUnitSearchTokens(this)

    return errorsTextArray
  }

  function hasPlatformFromBlkStr(blk, fieldName, defValue = false, separator = "; ")
  {
    local listStr = blk?[fieldName]
    if (!isString(listStr))
      return defValue
    return ::isInArray(::target_platform, ::split(listStr, separator))
  }

  function applyShopBlk(shopUnitBlk, prevShopUnitName, unitGroupName = null)
  {
    isInShop = true
    reqAir = prevShopUnitName
    group = unitGroupName
    if ("fakeReqUnitType" in shopUnitBlk)
      fakeReqUnits = shopUnitBlk % "fakeReqUnitType"

    local isVisibleUnbought = !shopUnitBlk?.showOnlyWhenBought
      && hasPlatformFromBlkStr(shopUnitBlk, "showByPlatform", true)
      && !hasPlatformFromBlkStr(shopUnitBlk, "hideByPlatform", false)

    showOnlyWhenBought = !isVisibleUnbought
    showOnlyWhenResearch = shopUnitBlk?.showOnlyWhenResearch ?? false

    if (isVisibleUnbought && isString(shopUnitBlk?.hideForLangs))
      hideForLangs = ::split(shopUnitBlk?.hideForLangs, "; ")

    foreach(key in ["reqFeature", "hideFeature", "showOnlyIfPlayerHasUnlock", "reqUnlock"])
      if (!isEmpty(shopUnitBlk?[key]))
        this[key] = shopUnitBlk[key]

    gift = shopUnitBlk?.gift //we already got it from wpCost. is we still need it here?
    giftParam = shopUnitBlk?.giftParam
    marketplaceItemdefId = shopUnitBlk?.marketplaceItemdefId
    disableFlyout = shopUnitBlk?.disableFlyout ?? false
  }

  isAir                 = @() esUnitType == ::ES_UNIT_TYPE_AIRCRAFT
  isTank                = @() esUnitType == ::ES_UNIT_TYPE_TANK
  isShip                = @() esUnitType == ::ES_UNIT_TYPE_SHIP
  isBoat                = @() esUnitType == ::ES_UNIT_TYPE_BOAT
  isShipOrBoat          = @() esUnitType == ::ES_UNIT_TYPE_SHIP || esUnitType == ::ES_UNIT_TYPE_BOAT
  isSubmarine           = @() esUnitType == ::ES_UNIT_TYPE_SHIP && tags.indexof("submarine") != null
  isHelicopter          = @() esUnitType == ::ES_UNIT_TYPE_HELICOPTER
  //



  getUnitWpCostBlk      = @() ::get_wpcost_blk()?[name] ?? ::DataBlock()
  isBought              = @() ::shop_is_aircraft_purchased(name)
  isUsable              = @() ::shop_is_player_has_unit(name)
  isRented              = @() ::shop_is_unit_rented(name)
  isBroken              = @() ::isUnitBroken(this)
  isResearched          = @() ::isUnitResearched(this)
  isInResearch          = @() ::isUnitInResearch(this)
  getRentTimeleft       = @() ::rented_units_get_expired_time_sec(name)
  getRepairCost         = @() ::Cost(::wp_get_repair_cost(name))
  getCrewTotalCount     = @() getUnitWpCostBlk()?.crewTotalCount || 1
  getCrewUnitType       = @() unitType.crewUnitType
  getExp                = @() ::getUnitExp(this)

  _isRecentlyReleased = null
  function isRecentlyReleased()
  {
    if (_isRecentlyReleased != null)
      return _isRecentlyReleased

    local res = false
    local releaseDate = ::get_unittags_blk()?[name]?.releaseDate
    if (releaseDate)
    {
      local recentlyReleasedUnitsDays = ::configs.GUI.get()?.markRecentlyReleasedUnitsDays ?? 0
      if (recentlyReleasedUnitsDays)
      {
        local releaseTime = time.getTimestampFromStringUtc(releaseDate)
        res = releaseTime + time.daysToSeconds(recentlyReleasedUnitsDays) > ::get_charserver_time_sec()
      }
    }

    _isRecentlyReleased = res
    return _isRecentlyReleased
  }

  _operatorCountry = null
  function getOperatorCountry()
  {
    if (_operatorCountry)
      return _operatorCountry
    local res = ::get_unittags_blk()?[name].operatorCountry ?? ""
    _operatorCountry = res != "" && ::get_country_icon(res) != "" ? res : shopCountry
    return _operatorCountry
  }

  function getEconomicRank(ediff)
  {
    return ::get_unit_blk_economic_rank_by_mode(getUnitWpCostBlk(), ediff)
  }

  function getBattleRating(ediff)
  {
    if (!::CAN_USE_EDIFF)
      ediff = ediff % EDIFF_SHIFT
    local mrank = getEconomicRank(ediff)
    return ::calc_battle_rating_from_rank(mrank)
  }

  function getWpRewardMulList(difficulty = ::g_difficulty.ARCADE)
  {
    local warpoints = ::get_warpoints_blk()
    local uWpCost = getUnitWpCostBlk()
    local mode = difficulty.getEgdName()

    local premPart = ::isUnitSpecial(this) ? warpoints?.rewardMulVisual?.premRewardMulVisualPart ?? 0.5 : 0.0
    local mul = (uWpCost?["rewardMul" + mode] ?? 1.0) *
      (warpoints?.rewardMulVisual?["rewardMulVisual" + mode] ?? 1.0)

    return {
      wpMul   = stdMath.round_by_value(mul * (1.0 - premPart), 0.1)
      premMul = stdMath.round_by_value(1.0 / (1.0 - premPart), 0.1)
    }
  }

  function _tostring()
  {
    return "Unit( " + name + " )"
  }

  function canAssignToCrew(country)
  {
    return ::getUnitCountry(this) == country && canUseByPlayer()
  }

  function canUseByPlayer()
  {
    return isUsable() && isVisibleInShop() && unitType.isAvailable()
  }

  function isVisibleInShop()
  {
    if (!isInShop || !unitType.isVisibleInShop())
      return false
    if (::is_debug_mode_enabled || isUsable())
      return true
    if (showOnlyWhenBought)
      return false
    if (hideForLangs && hideForLangs.indexof(::g_language.getLanguageName()) != null)
      return false
    if (showOnlyIfPlayerHasUnlock && !::is_unlocked_scripted(-1, showOnlyIfPlayerHasUnlock))
      return false
    if (showOnlyWhenResearch && !isInResearch() && getExp() <= 0)
      return false
    if (hideFeature != null && ::has_feature(hideFeature))
      return false
    if (::isUnitGift(this) && !platform.canSpendRealMoney())
      return false
    return true
  }

  /*************************************************************************************************/
  /************************************PRIVATE FUNCTIONS *******************************************/
  /*************************************************************************************************/

  //!!FIX ME: better to convert weapons and modifications to class
  function initWeaponry(weaponry, blk)
  {
    local weaponBlk = ::get_modifications_blk()?.modifications?[weaponry.name]
    if (blk?.value != null)
      weaponry.cost <- blk.value
    if (blk?.costGold)
    {
      weaponry.costGold <- blk.costGold
      weaponry.cost <- 0
    }
    weaponry.tier <- blk?.tier? blk.tier.tointeger() : 1
    weaponry.modClass <- blk?.modClass || weaponBlk?.modClass || ""
    weaponry.image <- ::get_weapon_image(esUnitType, weaponBlk, blk)
    weaponry.requiresModelReload <- weaponBlk?.requiresModelReload ?? false
    weaponry.isHidden <- blk?.isHidden ?? weaponBlk?.isHidden ?? false
    weaponry.weaponmask <- blk?.weaponmask ?? 0

    if (weaponry.name == "tank_additional_armor")
      weaponry.requiresModelReload <- true

    foreach(p in weaponProperties)
    {
      local val = blk?[p] ?? weaponBlk?[p]
      if (val != null)
        weaponry[p] <- val
    }

    foreach (param in ["prevModification", "reqInstalledModification"])
    {
      local val = blk?[param] || weaponBlk?[param]
      if (isString(val) && val.len())
        weaponry[param] <- val
    }

    if (isDataBlock(blk))
      foreach(rp in reqNames)
      {
        local reqData = []
        foreach (req in (blk % rp))
          if (isString(req) && req.len())
            reqData.append(req)
        if (reqData.len() > 0)
          weaponry[rp] <- reqData
      }
  }

  function initWeaponryUpgrades(upgradesTarget, blk)
  {
    foreach(upgradeName in upgradeNames)
    {
      if (blk?[upgradeName] == null)
        break

      if (!("weaponUpgrades" in upgradesTarget))
        upgradesTarget.weaponUpgrades <- []
      upgradesTarget.weaponUpgrades.append(::split(blk[upgradeName], "/"))
    }
  }

  function resetSkins()
  {
    skins = []
    skinsBlocks = {}
  }

  function getSkins()
  {
    if (skins.len() == 0)
      skins = ::get_skins_for_unit(name) //always returns at least one entry
    return skins
  }

  function getSkinBlockById(skinId)
  {
    if (!skinsBlocks.len()) //Will be default skin at least.
      foreach (skin in getSkins())
        skinsBlocks[skin.name] <- skin

    return skinsBlocks?[skinId]
  }

  function getPreviewSkinId()
  {
    if (!previewSkinId)
    {
      previewSkinId = ""
      foreach (skin in getSkins())
        if (::g_decorator.getDecorator(name + "/" + skin.name, ::g_decorator_type.SKINS)?.blk?.useByDefault)
          previewSkinId = skin.name
    }
    return previewSkinId
  }

  getSpawnScore = @(weaponName = null) ::shop_get_spawn_score(name, weaponName || getLastWeapon(name), [])

  function getMinimumSpawnScore()
  {
    local res = -1
    foreach (weapon in weapons)
      if (isWeaponVisible(this, weapon) && isWeaponEnabled(this, weapon))
      {
        local spawnScore = getSpawnScore(weapon.name)
        if (res < 0 || res > spawnScore)
          res = spawnScore
      }
    return ::max(res, 0)
  }

  function invalidateModificators()
  {
    if (modificatorsRequestTime > 0)
    {
      ::remove_calculate_modification_effect_jobs()
      modificatorsRequestTime = -1
    }
    modificators = null
  }

  function canPreview()
  {
    return isInShop
  }

  function doPreview()
  {
    if (canPreview())
      contentPreview.showUnitSkin(name)
  }

  isDepthChargeAvailable = @() hasDepthCharge || shop_is_modification_enabled(name, "ship_depth_charge")

  function getDefaultWeapon() {
    if (defaultWeaponPreset)
      return defaultWeaponPreset

    local unitBlk = ::get_full_unit_blk(name)
    if (!unitBlk)
      return null

    if (unitBlk?.weapon_presets != null)
      foreach(block in (unitBlk.weapon_presets % "preset")) {
        if (block.name.indexof("default") != null) {
          defaultWeaponPreset = block.name
          return defaultWeaponPreset
        }
        if (block?.tags?.free) {
          defaultWeaponPreset = block.name
          return defaultWeaponPreset
        }
      }
    return null
  }

  function getAvailableSecondaryWeapons()
  {
    local secondaryWep = getLastWeapon(name)
    if (secondaryWep == "")
      return defaultAvailableWeapons

    local availableWeapons = availableWeaponsByWeaponName?[secondaryWep]
    if (availableWeapons)
      return availableWeapons

    local unitBlk = ::get_full_unit_blk(name)
    if (!unitBlk)
      return defaultAvailableWeapons

    local weaponDataBlock = null
    local weaponsBlkArray = []
    availableWeapons = clone defaultAvailableWeapons

    if (unitBlk?.weapon_presets != null)
    {
      foreach (block in (unitBlk.weapon_presets % "preset"))
        if (block.name == secondaryWep)
        {
          weaponDataBlock = blkFromPath(block.blk)
          local nbrBomb = 0
          dagor.debug("check unit weapon :")
          foreach (weap in (weaponDataBlock % "Weapon"))
          {
            if (!weap?.blk || weap?.dummy || ::isInArray(weap.blk, weaponsBlkArray))
              continue

            if (weap?.trigger == "mines")
              availableWeapons.hasMines = true
            else if (weap?.trigger == "countermeasures")
              availableWeapons.hasCountermeasures = true

            local weapBlk = blkFromPath(weap.blk)
            if (weapBlk?.bomb)
            {
              availableWeapons.hasBombs = true
              nbrBomb++
            }
            if (weapBlk?.rocket && (weapBlk.rocket?.distanceFuse ?? true))
              availableWeapons.hasRocketDistanceFuse = true
            if (weapBlk?.bomb.isDepthCharge)
              availableWeapons.hasDepthCharges = true
            if (weapBlk?.torpedo != null)
              availableWeapons.hasTorpedoes = true

            if (!weapBlk?.bomb)
              weaponsBlkArray.append(weap.blk)
          }
          availableWeapons.bombsNbr = nbrBomb
          break
        }
    }

    availableWeaponsByWeaponName[secondaryWep] <- availableWeapons
    return availableWeapons
  }

  function getEntitlements()
  {
    if (gift == null)
      return []

    return ::OnlineShopModel.searchEntitlementsByUnit(name)
  }

  function getUnlockImage()
  {
    if (isAir())
      return "#ui/gameuiskin#blueprint_items_aircraft"
    if (isTank())
      return "#ui/gameuiskin#blueprint_items_tank"
    if (isShipOrBoat())
      return "#ui/gameuiskin#blueprint_items_ship"

    return "#ui/gameuiskin#blueprint_items_aircraft"
  }

  isSquadronVehicle       = @() researchType == "clanVehicle"
  getOpenCost             = @() ::Cost(0, ::clan_get_unit_open_cost_gold(name))
}

::u.registerClass("Unit", Unit, @(u1, u2) u1.name == u2.name, @(unit) !unit.name.len())

return Unit