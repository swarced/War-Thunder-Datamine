let squadronUnitAction = require("%scripts/unit/squadronUnitAction.nut")
let daguiFonts = require("%scripts/viewUtils/daguiFonts.nut")
let time = require("%scripts/time.nut")

let PROGRESS_PARAMS = {
  type = "old"
  rotation = 0
  markerPos = 100
  progressDisplay = "show"
  markerDisplay = "show"
  textType = "activeText"
  textPos = "0.5pw - 0.5w"
  tooltip = ""
}

::gui_handlers.clanAverageActivityModal <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  clanData = null

  static function open(clanData)
  {
    ::gui_start_modal_wnd(
      ::gui_handlers.clanAverageActivityModal, { clanData = clanData })
  }

  function initScreen()
  {
    local view = {
      clan_activity_header_text = ::loc("clan/activity")
      clan_activity_description = ::loc("clan/activity/progress/desc_no_progress")
    }
    let maxMemberActivity = max(clanData.maxActivityPerPeriod, 1)
    if (clanData.maxClanActivity > 0)
    {
      let maxActivity = maxMemberActivity * clanData.members.len()
      let limitClanActivity = min(maxActivity, clanData.maxClanActivity)
      let myActivity = ::u.search(clanData.members,
        @(member) member.uid == ::my_user_id_str)?.curPeriodActivity ?? 0
      let clanActivity = getClanActivity()

      if (clanActivity > 0)
      {
        let percentMemberActivity = min(100.0 * myActivity / maxMemberActivity, 100)
        let percentClanActivity = min(100.0 * clanActivity / maxActivity, 100)
        let myExp = min(min(1, 1.0 * percentMemberActivity/percentClanActivity) * clanActivity,
          clanData.maxClanActivity)
        let roundMyExp = ::round(myExp)
        let limit = min(100.0 * limitClanActivity / maxActivity, 100)
        let isAllVehiclesResearched = squadronUnitAction.isAllVehiclesResearched()
        let expBoost = ::clan_get_exp_boost()/100.0
        let hasBoost = expBoost > 0
        let descrArray = clanData.nextRewardDayId != null
          ? [::loc("clan/activity_period_end", {date = ::colorize("activeTextColor",
              time.buildDateTimeStr(clanData.nextRewardDayId, false, false))}) + "\n"]
          : []
        if(hasBoost)
          descrArray.append(::loc("clan/activity_reward/nowBoost",
            {bonus = ::colorize("goodTextColor",
              "+" + ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(expBoost))}))
        descrArray.append(isAllVehiclesResearched
          ? ::loc("clan/activity/progress/desc_all_researched")
          : ::loc("clan/activity/progress/desc"))

        let markerPosMyExp = min(100 * myExp / limitClanActivity, 100)

        let pxCountToEdgeWnd = ::to_pixels((1-markerPosMyExp/100.0)
          + "*0.4@scrn_tgt + 1@tablePad + 5@blockInterval")
        let myExpTextSize = daguiFonts.getStringWidthPx(::getShortTextFromNum(roundMyExp)
            + (hasBoost ? (" + " + ::getShortTextFromNum((roundMyExp*expBoost).tointeger())) : ""),
          "fontNormal", guiScene)
        let offsetMyExpText = ::min(pxCountToEdgeWnd - myExpTextSize/2, 0)
        let myExpShortText= ::colorize("activeTextColor",
          ::getShortTextFromNum(roundMyExp) + (hasBoost ? (" + " + ::colorize("goodTextColor",
          ::getShortTextFromNum((roundMyExp*expBoost).tointeger()))) : ""))
        let myExpFullText= ::colorize("activeTextColor",
          roundMyExp + (hasBoost ? (" + " + ::colorize("goodTextColor",
            ::round((roundMyExp*expBoost).tointeger()))) : ""))

        view = {
          clan_activity_header_text = ::loc("clan/my_activity_in_period",
            {activity = myActivity.tostring() + ::loc("ui/slash") + maxMemberActivity.tostring()})
          clan_activity_description = ::g_string.implode(descrArray, "\n")
          rows = [
            {
              title = ::loc("clan/squadron_activity")
              progress = [
                PROGRESS_PARAMS.__merge({type = "new", markerDisplay = "hide"})
                PROGRESS_PARAMS.__merge({
                  type = "inactive"
                  value = percentClanActivity * 10
                  markerDisplay = "hide"
                })
                PROGRESS_PARAMS.__merge({
                  value = min(limit, percentClanActivity) * 10
                  markerPos = min(limit, percentClanActivity)
                  text = ::round(min(limit, percentClanActivity)) + "%"
                })
              ]
            }
            {
              title = ::loc("clan/activity_reward")
              widthPercent = limit
              progressDisplay = isAllVehiclesResearched ? "hide" : "show"
              progress = [
                PROGRESS_PARAMS.__merge({type = "new", markerDisplay = "hide"})
                PROGRESS_PARAMS.__merge({
                  text = ::getShortTextFromNum(limitClanActivity)
                  rotation = 180
                  tooltip = ::getShortTextFromNum(limitClanActivity) != limitClanActivity.tostring()
                    ? ::loc("leaderboards/exactValue") + ::loc("ui/colon") + limitClanActivity
                    : ""
                })
                PROGRESS_PARAMS.__merge({
                  value = min(100 * myExp / limitClanActivity, 100) * 10
                  markerPos = markerPosMyExp
                  textType = "textAreaCentered"
                  textPos = "0.5pw - 0.5w" + " + " + offsetMyExpText
                  text = myExpShortText
                  tooltip = myExpFullText != myExpShortText
                    ? ::loc("leaderboards/exactValue") + ::loc("ui/colon") + myExpFullText
                    : ""
                })
              ]
            }
            {
              title = ::loc("clan/my_activity"),
              progress = [
                PROGRESS_PARAMS.__merge({type = "new", markerDisplay = "hide"})
                PROGRESS_PARAMS.__merge({
                  type = "inactive"
                  value = percentMemberActivity * 10
                  markerDisplay = "hide"
                })
                PROGRESS_PARAMS.__merge({
                  value = min(limit, percentMemberActivity) * 10
                  markerPos = min(limit, percentMemberActivity)
                  text = ::round(min(limit, percentMemberActivity)) + "%"
                })
              ]
            }
          ]
        }
      }
    }

    let data = ::handyman.renderCached("%gui/clans/clanAverageActivityModal", view)
    guiScene.replaceContentFromText(scene, data, data.len(), this)
  }

  function getClanActivity()
  {
    local res = 0
    foreach (member in clanData.members)
      res += member.curPeriodActivity

    return res
  }
}
