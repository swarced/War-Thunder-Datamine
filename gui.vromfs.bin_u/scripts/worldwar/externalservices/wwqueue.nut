let { getMyClanOperation, isMyClanInQueue
} = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { actionWithGlobalStatusRequest } = require("%scripts/worldWar/operations/model/wwGlobalStatus.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")

::WwQueue <- class
{
  map = null
  data = null

  myClanCountries = null
  myClanQueueTime = -1
  cachedClanId = -1 //need to update clan data if clan changed

  constructor(_map, _data = null)
  {
    map = _map
    data = _data
  }

  function isMapActive()
  {
    return map.isActive() || map.getOpGroup().hasActiveOperations()
  }

  function getArmyGroupsByCountry(country, defValue = null)
  {
    return ::getTblValue(country, data, defValue)
  }

  function isMyClanJoined(country = null)
  {
    let countries = getMyClanCountries()
    return country ? ::isInArray(country, countries) : countries.len() != 0
  }

  function getMyClanCountries()
  {
    gatherMyClanDataOnce()
    return myClanCountries || []
  }

  function getMyClanQueueJoinTime()
  {
    gatherMyClanDataOnce()
    return ::max(0, myClanQueueTime)
  }

  function resetCache()
  {
    myClanCountries = null
    myClanQueueTime = -1
    cachedClanId = -1
  }

  function gatherMyClanDataOnce()
  {
    let myClanId = ::clan_get_my_clan_id().tointeger()
    if (myClanId == cachedClanId)
      return

    cachedClanId = myClanId
    if (!data)
      return

    myClanCountries = []
    foreach(country in shopCountriesList)
    {
      let groups = getArmyGroupsByCountry(country)
      let myGroup = groups && ::u.search(groups, (@(myClanId) function(ag) { return ::getTblValue("clanId", ag) == myClanId })(myClanId) )
      if (myGroup)
      {
        myClanCountries.append(country)
        myClanQueueTime = ::max(myClanQueueTime, ::getTblValue("at", myGroup, -1))
      }
    }

    if (!myClanCountries.len())
    {
      myClanCountries = null
      myClanQueueTime = -1
    }
  }

  function getArmyGroupsAmountByCountries()
  {
    let res = {}
    foreach(country in shopCountriesList)
    {
      let groups = getArmyGroupsByCountry(country)
      res[country] <- groups ? groups.len() : 0
    }
    return res
  }

  function getClansNumberInQueueText()
  {
    let clansInQueue = {}
    foreach(country in shopCountriesList)
    {
      let groups = getArmyGroupsByCountry(country)
      if (groups)
        foreach (memberData in groups)
          clansInQueue[memberData.clanId] <- true
    }
    let clansInQueueNumber = clansInQueue.len()
    return !clansInQueueNumber ? "" :
      ::loc("worldwar/clansInQueueTotal", {number = clansInQueueNumber})
  }

  function getArmyGroupsAmountTotal()
  {
    local res = 0
    foreach(country in shopCountriesList)
    {
      let groups = getArmyGroupsByCountry(country)
      if (groups)
        res += groups.len()
    }
    return res
  }

  function getNameText()
  {
    return map.getNameText()
  }

  function getGeoCoordsText()
  {
    return  map.getGeoCoordsText()
  }

  function getCountriesByTeams()
  {
    return map.getCountriesByTeams()
  }

  function getCantJoinQueueReasonData(country = null)
  {
    let res = getCantJoinAnyQueuesReasonData()
    if (! res.canJoin)
      return res

    res.canJoin = false

    if (country && !map.canJoinByCountry(country))
      res.reasonText = ::loc("worldWar/chooseAvailableCountry")
    else
      res.canJoin = true

    return res
  }

  static function getCantJoinAnyQueuesReasonData()
  {
    let res = {
      canJoin = false
      reasonText = ""
      hasRestrictClanRegister = false
    }

    if (getMyClanOperation())
      res.reasonText = ::loc("worldwar/squadronAlreadyInOperation")
    else if (isMyClanInQueue())
      res.reasonText = ::loc("worldwar/mapStatus/yourClanInQueue")
    else if (!::g_clans.hasRightsToQueueWWar())
      res.reasonText = ::loc("worldWar/onlyLeaderCanQueue")
    else
    {
      let myClanType = ::g_clans.getMyClanType()
      if (!::clan_can_register_to_ww())
      {
        res.reasonText = ::loc("clan/wwar/lacksMembers", {
          clanType = myClanType.getTypeNameLoc()
          count = myClanType.getMinMemberCountToWWar()
          minRankRequired = ::get_roman_numeral(::g_world_war.getSetting("minCraftRank", 0))
        })
        res.hasRestrictClanRegister = true
      }
      else
        res.canJoin = true
    }

    return res
  }

  function joinQueue(country, isSilence = true)
  {
    let cantJoinReason = getCantJoinQueueReasonData(country)
    if (!cantJoinReason.canJoin)
    {
      if (!isSilence)
        ::showInfoMsgBox(cantJoinReason.reasonText)
      return false
    }

    return _joinQueue(country)
  }

  function _joinQueue(country)
  {
    let requestBlk = ::DataBlock()
    requestBlk.mapName = map.name
    requestBlk.country = country
    actionWithGlobalStatusRequest("cln_clan_register_ww_army_group", requestBlk, { showProgressBox = true })
  }

  function getCantLeaveQueueReasonData()
  {
    let res = {
      canLeave = false
      reasonText = ""
    }

    if (!::g_clans.hasRightsToQueueWWar())
      res.reasonText = ::loc("worldWar/onlyLeaderCanQueue")
    else if (!isMyClanJoined())
      res.reasonText = ::loc("matching/SERVER_ERROR_NOT_IN_QUEUE")
    else
      res.canLeave = true

    return res
  }

  function leaveQueue(isSilence = true)
  {
    let cantLeaveReason = getCantLeaveQueueReasonData()
    if (!cantLeaveReason.canLeave)
    {
      if (!isSilence)
        ::showInfoMsgBox(cantLeaveReason.reasonText)
      return false
    }

    return _leaveQueue()
  }

  function _leaveQueue()
  {
    let requestBlk = ::DataBlock()
    requestBlk.mapName = map.name
    actionWithGlobalStatusRequest("cln_clan_unregister_ww_army_group", requestBlk, { showProgressBox = true })
  }

  function getMapChangeStateTimeText()
  {
    return map.getMapChangeStateTimeText()
  }

  function getMinClansCondition()
  {
    return map.getMinClansCondition()
  }

  function getClansConditionText()
  {
    return map.getClansConditionText()
  }

  getId = @() map.getId()
}
