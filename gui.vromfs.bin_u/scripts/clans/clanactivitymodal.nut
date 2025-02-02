let u = require("%sqStdLibs/helpers/u.nut")
let time = require("%scripts/time.nut")
let platformModule = require("%scripts/clientState/platform.nut")

::gui_start_clan_activity_wnd <- function gui_start_clan_activity_wnd(uid = null, clanData = null)
{
  if (!uid || !clanData)
    return

  let memberData = u.search(clanData.members, @(member) member.uid == uid)
  if (!memberData)
    return

  ::gui_start_modal_wnd(::gui_handlers.clanActivityModal,
  {
    clanData = clanData
    memberData = memberData
  })
}

::gui_handlers.clanActivityModal <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType           = handlerType.MODAL
  sceneBlkName      = "%gui/clans/clanActivityModal.blk"
  clanData          = null
  memberData        = null
  hasClanExperience = null

  function initScreen()
  {
    let maxActivityPerDay = clanData.rewardPeriodDays > 0
      ? ::round(1.0 * clanData.maxActivityPerPeriod / clanData.rewardPeriodDays)
      : 0
    let isShowPeriodActivity = ::has_feature("ClanVehicles")
    hasClanExperience  = isShowPeriodActivity && ::clan_get_my_clan_id() == clanData.id
    let history = isShowPeriodActivity ? memberData.expActivity : memberData.activityHistory
    let headerTextObj = scene.findObject("clan_activity_header_text")
    headerTextObj.setValue(::format("%s - %s", ::loc("clan/activity"),
      platformModule.getPlayerName(memberData.nick)))

    let maxActivityToday = [(isShowPeriodActivity ? memberData.curPeriodActivity : memberData.curActivity).tostring()]
    if (maxActivityPerDay > 0)
      maxActivityToday.append((isShowPeriodActivity ? clanData.maxActivityPerPeriod : maxActivityPerDay).tostring())
    scene.findObject("clan_activity_today_value").setValue(::g_string.implode(maxActivityToday, " / "))
    scene.findObject("clan_activity_total_value").setValue(::format("%d",
      isShowPeriodActivity ? memberData.totalPeriodActivity : memberData.totalActivity))

    fillActivityHistory(history)
  }

  function fillActivityHistory(history)
  {
    let historyArr = []
    foreach (day, data in history)
    {
      historyArr.append({day = day.tointeger(), data = data})
    }
    historyArr.sort(function(left, right)
    {
      return right.day - left.day
    })

    let tableHeaderObj = scene.findObject("clan_member_activity_history_table_header");
    local rowIdx = 1
    local rowBlock = ""
    let rowHeader = [
      {
        id       = "clan_activity_history_col_day",
        text     = ::loc("clan/activity/day"),
        active   = false
      },
      {
        id       = "clan_activity_history_col_value",
        text     = ::loc("clan/activity"),
        active   = false
      }
    ];

    if (hasClanExperience)
      rowHeader.append(
        {
          id       = "clan_activity_exp_col_value",
          text     = ::loc("reward"),
          active   = false
        }
      )

    rowBlock += ::buildTableRowNoPad("row_header", rowHeader, null,
        "inactive:t='yes'; commonTextColor:t='yes'; bigIcons:t='yes'; style:t='height:0.05sh;'; ")

    guiScene.replaceContentFromText(tableHeaderObj, rowBlock, rowBlock.len(), this)

    let tableObj = scene.findObject("clan_member_activity_history_table");

    rowBlock = ""
    /*body*/
    foreach(entry in historyArr)
    {
      let rowParams = [
        { text = time.buildDateStr(time.daysToSeconds(entry.day)) },
        { text = (::u.isInteger(entry.data) ? entry.data : entry.data?.activity ?? 0).tostring() }
      ]

      if (hasClanExperience)
      {
        let exp = entry.data?.exp ?? 0
        local expText = exp.tostring()
        let boost = (entry.data?.expBoost ?? 0)/100.0
        let hasBoost = boost > 0
        if (hasBoost && exp > 0)
        {
          let baseExp = entry.data?.expRewardBase ?? ::round(exp/(1 + boost))
          expText = ::colorize("activeTextColor",baseExp.tostring()
            + ::colorize("goodTextColor", " + " + (exp - baseExp).tostring()))
        }

        rowParams.append({ text = expText
          textType = hasBoost ? "textAreaCentered" : "activeText"
          textRawParam = "width:t='pw'; text-align:t='center'"
          tooltip = hasBoost
            ? ::loc("clan/activity_reward/wasBoost",
              { bonus = ::colorize("activeTextColor",
                "+" + ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(boost))})
            : ""
        })
      }
      rowBlock += ::buildTableRowNoPad("row_" + rowIdx, rowParams, null, "")
      rowIdx++
    }
    guiScene.replaceContentFromText(tableObj, rowBlock, rowBlock.len(), this)
  }
}
