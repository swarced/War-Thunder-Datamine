let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let activityFeedPostFunc = require("%scripts/social/activityFeed/activityFeedPostFunc.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")

let facebookPostWallMessage = persist("facebookPostWallMessage", @() ::Watched(false))

subscriptions.addListenersWithoutEnv({
  FacebookFeedPostValueChange = function(p) {
    facebookPostWallMessage(p?.value ?? false)
  }
  UnitBought = function(p) {
    let unit = ::getAircraftByName(p?.unitName)
    if (!unit)
      return

    let config = {
      locId = "purchase_unit"
      subType = ps4_activity_feed.PURCHASE_UNIT
      backgroundPost = true
    }

    let customFeedParams = {
      requireLocalization = ["unitName", "country"]
      unitNameId = unit.name
      unitName = unit.name + "_shop"
      rank = ::get_roman_numeral(unit?.rank ?? -1)
      country = ::getUnitCountry(unit)
      link = ::format(::loc("url/wiki_objects"), unit.name)
    }

    local reciever = facebookPostWallMessage.value? bit_activity.FACEBOOK : bit_activity.NONE
    if (isPlatformSony)
      reciever = reciever == bit_activity.NONE? bit_activity.PS4_ACTIVITY_FEED : bit_activity.ALL

    activityFeedPostFunc(config, customFeedParams, reciever)
  }
})