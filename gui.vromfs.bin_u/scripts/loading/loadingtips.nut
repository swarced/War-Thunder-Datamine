let stdMath = require("%sqstd/math.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { doesLocTextExist = @(k) true } = require("dagor.localize")
let { showedUnit } = require("%scripts/slotbar/playerCurUnit.nut")

const GLOBAL_LOADING_TIP_BIT = 0x8000
const MISSING_TIPS_IN_A_ROW_ALLOWED = 3
const TIP_LOC_KEY_PREFIX = "loading/"

::g_script_reloader.loadOnce("%scripts/loading/bhvLoadingTip.nut")

::g_tips <- {
  TIP_LIFE_TIME_MSEC = 10000

  tipsKeys = { [GLOBAL_LOADING_TIP_BIT] = [] }
  existTipsMask = GLOBAL_LOADING_TIP_BIT

  curTip = ""
  curTipIdx = -1
  curTipUnitTypeMask = -1
  curNewbieUnitTypeMask = 0
  nextTipTime = -1

  isTipsValid = false

  function getAllTips() {
    let tipsKeysByUnitType = {}
    tipsKeysByUnitType[GLOBAL_LOADING_TIP_BIT] <- loadTipsKeysByUnitType(null, false)

    foreach(unitType in unitTypes.types)
    {
      if (unitType == unitTypes.INVALID)
        continue
      let keys = loadTipsKeysByUnitType(unitType, false)
      if (!keys.len())
        continue
      tipsKeysByUnitType[unitType.bit] <- keys
    }

    let tipsArray = []
    foreach(unitTypeBit, keys in tipsKeysByUnitType) {
      tipsArray.extend(keys.map(function(tipKey) {
        local tip = ::loc($"{TIP_LOC_KEY_PREFIX}{tipKey}")
        if (unitTypeBit != GLOBAL_LOADING_TIP_BIT) {
          let icon = unitTypes.getByBit(unitTypeBit).fontIcon
          tip = $"{::colorize("fadedTextColor", icon)} {tip}"
        }
        return tip
      }))
    }

    return tipsArray
  }

  function onEventProfileReceived(p) { isTipsValid = false }
}

g_tips.getTip <- function getTip(unitTypeMask = 0)
{
  if (unitTypeMask != curTipUnitTypeMask || nextTipTime <= ::dagor.getCurTime())
    genNewTip(unitTypeMask)
  return curTip
}

g_tips.resetTipTimer <- function resetTipTimer()
{
  nextTipTime = -1
}

g_tips.validate <- function validate()
{
  if (isTipsValid)
    return
  isTipsValid = true

  tipsKeys.clear()
  tipsKeys[GLOBAL_LOADING_TIP_BIT] <- loadTipsKeysByUnitType(null, false)
  existTipsMask = GLOBAL_LOADING_TIP_BIT
  curNewbieUnitTypeMask = getNewbieUnitTypeMask()

  foreach(unitType in unitTypes.types)
  {
    if (unitType == unitTypes.INVALID)
      continue
    let isMeNewbie = isMeNewbieOnUnitType(unitType.esUnitType)
    local keys = loadTipsKeysByUnitType(unitType, isMeNewbie)
    if (!keys.len() && isMeNewbie)
      keys = loadTipsKeysByUnitType(unitType, false)
    if (!keys.len())
      continue
    tipsKeys[unitType.bit] <- keys
    existTipsMask = existTipsMask | unitType.bit
  }
}

//for global tips typeName = null
g_tips.getKeyFormat <- function getKeyFormat(typeName, isNewbie)
{
  let path = typeName ? [ typeName.tolower() ] : []
  if (isNewbie)
    path.append("newbie")
  path.append("tip%d")
  return ::g_string.implode(path, "/")
}

//for global tips unitType = null
g_tips.loadTipsKeysByUnitType <- function loadTipsKeysByUnitType(unitType, isNeedOnlyNewbieTips)
{
  let res = []

  let configs = []
  foreach (isNewbieTip in [ true, false ])
    configs.append({
      isNewbieTip = isNewbieTip
      keyFormat   = getKeyFormat(unitType?.name, isNewbieTip)
      isShow      = !isNeedOnlyNewbieTips || isNewbieTip
    })

  local notExistInARow = 0
  for(local idx = 0; notExistInARow <= MISSING_TIPS_IN_A_ROW_ALLOWED; idx++) // warning disable: -mismatch-loop-variable
  {
    local isShow = false
    local key = ""
    local tip = ""
    foreach (cfg in configs)
    {
      isShow = cfg.isShow
      key = ::format(cfg.keyFormat, idx)
      let locId = $"{TIP_LOC_KEY_PREFIX}{key}"
      tip = doesLocTextExist(locId) ? ::loc(locId, "") : "" // Using doesLocTextExist() to avoid warnings spam in log.
      if (tip != "")
        break
    }

    if (tip == "")
    {
      notExistInARow++
      continue
    }
    notExistInARow = 0

    if (isShow && (::g_login.isLoggedIn() || tip.indexof("{{") == null)) // Not show tip with shortcuts while not profile recived
      res.append(key)
  }
  return res
}

g_tips.isMeNewbieOnUnitType <- function isMeNewbieOnUnitType(esUnitType)
{
  return ("my_stats" in ::getroottable()) && ::my_stats.isMeNewbieOnUnitType(esUnitType)
}

g_tips.getNewbieUnitTypeMask <- function getNewbieUnitTypeMask()
{
  local mask = 0
  foreach(unitType in unitTypes.types)
  {
    if (unitType == unitTypes.INVALID)
      continue
    if (isMeNewbieOnUnitType(unitType.esUnitType))
      mask = mask | unitType.bit
  }
  return mask
}

g_tips.getDefaultUnitTypeMask <- function getDefaultUnitTypeMask()
{
  if (!::g_login.isLoggedIn() || ::isInMenu())
    return existTipsMask

  local res = 0
  let gm = ::get_game_mode()
  if (gm == ::GM_DOMINATION || gm == ::GM_SKIRMISH)
    res = ::SessionLobby.getRequiredUnitTypesMask() || ::SessionLobby.getUnitTypesMask()
  else if (gm == ::GM_TEST_FLIGHT)
  {
    if (showedUnit.value)
      res = showedUnit.value.unitType.bit
  }
  else if (::isInArray(gm, [::GM_SINGLE_MISSION, ::GM_CAMPAIGN, ::GM_DYNAMIC, ::GM_BUILDER, ::GM_DOMINATION]))
    res = unitTypes.AIRCRAFT.bit
  else // keep this check last
    res = ::get_mission_allowed_unittypes_mask(::get_mission_meta_info(::current_campaign_mission || ""))

  return (res & existTipsMask) || existTipsMask
}

g_tips.genNewTip <- function genNewTip(unitTypeMask = 0)
{
  nextTipTime = ::dagor.getCurTime() + TIP_LIFE_TIME_MSEC

  if (curNewbieUnitTypeMask && curNewbieUnitTypeMask != getNewbieUnitTypeMask())
    isTipsValid = false

  if (!isTipsValid || curTipUnitTypeMask != unitTypeMask)
  {
    curTipIdx = -1
    curTipUnitTypeMask = unitTypeMask
  }

  validate()

  if (!(unitTypeMask & existTipsMask))
    unitTypeMask = getDefaultUnitTypeMask()

  local totalTips = 0
  foreach(unitTypeBit, keys in tipsKeys)
    if (unitTypeBit & unitTypeMask)
      totalTips += keys.len()
  if (totalTips == 0)
  {
    curTip = ""
    curTipIdx = -1
    return
  }

  //choose new tip
  local newTipIdx = 0
  if (totalTips > 1)
  {
    local tipsToChoose = totalTips
    if (curTipIdx >= 0)
      tipsToChoose--
    newTipIdx = ::math.rnd() % tipsToChoose
    if (curTipIdx >= 0 && curTipIdx <= newTipIdx)
      newTipIdx++
  }
  curTipIdx = newTipIdx

  //get lang for chosen tip
  local tipIdx = curTipIdx
  foreach(unitTypeBit, keys in tipsKeys)
  {
    if (!(unitTypeBit & unitTypeMask))
      continue
    if (tipIdx >= keys.len())
    {
      tipIdx -= keys.len()
      continue
    }

    //found tip
    curTip = ::loc(TIP_LOC_KEY_PREFIX + keys[tipIdx])

    //add unit type icon if needed
    if (unitTypeBit != GLOBAL_LOADING_TIP_BIT && stdMath.number_of_set_bits(unitTypeMask) > 1)
    {
      let icon = unitTypes.getByBit(unitTypeBit).fontIcon
      curTip = ::colorize("fadedTextColor", icon) + " " + curTip
    }

    break
  }
}

g_tips.onEventLoginComplete <- function onEventLoginComplete(p) { isTipsValid = false }
g_tips.onEventGameLocalizationChanged <- function onEventGameLocalizationChanged(p) { isTipsValid = false }
g_tips.onEventSignOut <- function onEventSignOut(p) { isTipsValid = false }

::subscribe_handler(::g_tips, ::g_listener_priority.DEFAULT_HANDLER)