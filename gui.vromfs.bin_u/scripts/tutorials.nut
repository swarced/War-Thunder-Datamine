let { tryOpenNextTutorialHandler } = require("%scripts/tutorials/nextTutorialHandler.nut")
let { checkTutorialsList } = require("%scripts/tutorials/tutorialsData.nut")
let { getShowedUnit } = require("%scripts/slotbar/playerCurUnit.nut")

::getReserveAircraftName <- function getReserveAircraftName(paramsTable)
{
  let preferredCrew = ::getTblValue("preferredCrew", paramsTable, null)

  // Trained level by unit name.
  let trainedSpec = ::getTblValue("trainedSpec", preferredCrew, {})

  foreach (unitName, unitSpec in trainedSpec)
  {
    let unit = ::getAircraftByName(unitName)
    if (unit != null && checkReserveUnit(unit, paramsTable))
      return unit.name
  }

  foreach (unit in ::all_units)
    if (checkReserveUnit(unit, paramsTable))
      return unit.name

  return ""
}

::checkReserveUnit <- function checkReserveUnit(unit, paramsTable)
{
  let country = ::getTblValue("country", paramsTable, "")
  let unitType = ::getTblValue("unitType", paramsTable, ::ES_UNIT_TYPE_AIRCRAFT)
  let ignoreUnits = ::getTblValue("ignoreUnits", paramsTable, [])
  let ignoreSlotbarCheck = ::getTblValue("ignoreSlotbarCheck", paramsTable, false)

  return (unit.shopCountry == country &&
         (::get_es_unit_type(unit) == unitType || unitType == ::ES_UNIT_TYPE_INVALID) &&
         !::isInArray(unit.name, ignoreUnits) &&
         ::is_default_aircraft(unit.name) &&
         unit.isBought() &&
         unit.isVisibleInShop() &&
         (ignoreSlotbarCheck || !::isUnitInSlotbar(unit)))
}

::check_tutorial_on_start <- function check_tutorial_on_start()
{
  local tutorial = "fighter"

  let curUnit = getShowedUnit()
  if (curUnit?.isTank() && ::has_feature("Tanks"))
    tutorial = "lightTank"
  else if (curUnit?.isBoat() && ::has_feature("Ships"))
    tutorial = "boat"
  else if (curUnit?.isShip() && ::has_feature("Ships"))
    tutorial = "ship"

  if (!tryOpenNextTutorialHandler(tutorial))
  {
    foreach(t in checkTutorialsList)
    {
      let func = ::getTblValue("isNeedAskInMainmenu", t)
      if (!func || !func())
        continue

      if (tryOpenNextTutorialHandler(t.id))
        return
    }
  }
}
