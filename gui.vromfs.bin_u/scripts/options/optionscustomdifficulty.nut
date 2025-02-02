let { isGameModeCoop, isGameModeVersus } = require("%scripts/matchingRooms/matchingGameModesUtils.nut")
local { getCdOption, getCdBaseDifficulty } = ::require_native("guiOptions")

::gui_handlers.OptionsCustomDifficultyModal <- class extends ::gui_handlers.GenericOptionsModal
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/options/genericOptionsModal.blk"
  titleText = ::loc("profile/difficulty")

  options = null
  afterApplyFunc = null
  applyAtClose = false

  curBaseDifficulty = ::DIFFICULTY_ARCADE
  ignoreUiCallbacks = false

  function initScreen()
  {
    scene.findObject("header_name").setValue(titleText)
    options = ::get_custom_difficulty_options()
    base.initScreen()
    updateCurBaseDifficulty()
  }

  function reinitScreen()
  {
    let optListObj = scene.findObject(currentContainerName)
    if (!::checkObj(optListObj))
      return
    options = ::get_custom_difficulty_options()

    ignoreUiCallbacks = true
    foreach (o in options)
    {
      let option = ::get_option(o[0])
      let obj = optListObj.findObject(option.id)
      if (option.controlType == optionControlType.LIST && option.values[option.value] != getCdOption(option.type))
        ::dagor.assertf(false, "[ERROR] Custom difficulty param " + option.type + " (" + option.id + ") value '" + getCdOption(option.type) + "' is out of range.")
      if (::checkObj(obj))
        obj.setValue(option.value)
    }
    ignoreUiCallbacks = false

    updateCurBaseDifficulty()
  }

  function getNavbarTplView()
  {
    return {
      left = [
        {
          id = "btn_back"
          text = "#mainmenu/btnBack"
          shortcut = "B"
          funcName = "goBack"
          button = true
        },
        {
          id = "btn_reset"
          text = "#mainmenu/btnReset"
          shortcut = "Y"
          funcName = "onListCdPresets"
          button = true
        },
      ],
      right = [
        {
          id = "btn_apply"
          text = "#mainmenu/btnApply"
          shortcut = "X"
          funcName = "onApply"
          isToBattle = true
          button = true
          delayed = true
        },
      ]
    }
  }

  function updateButtons() {} //override from GenericOptionsModal

  function updateCurBaseDifficulty()
  {
    curBaseDifficulty = getCdBaseDifficulty()

    let obj = scene.findObject("info_text_top")
    if (!::checkObj(obj))
      return
    let text = ::loc("customdiff/value") + ::loc("difficulty" + curBaseDifficulty)
    obj.setValue(text)
  }

  function applyFunc()
  {
    ::reload_cd()
    if (afterApplyFunc)
      afterApplyFunc()
  }

  function onApply(obj)
  {
    // init custom difficulty by BaseDifficulty
    ::set_cd_preset(::get_cd_preset(curBaseDifficulty))
    base.onApply(obj)
  }

  function onCDChange(obj)
  {
    if (ignoreUiCallbacks)
      return
    let option = get_option_by_id(obj.id)
    if (!option)
      return
    ::set_option(option.type, obj.getValue(), option)
    updateCurBaseDifficulty()
  }

  function onListCdPresets(obj)
  {
    if (!::checkObj(obj))
      return

    if (::gui_handlers.ActionsList.hasActionsListOnObject(obj))
    {
      ::gui_handlers.ActionsList.removeActionsListFromObject(obj, true)
      return
    }

    let option = ::get_option(::USEROPT_DIFFICULTY)
    let menu = { handler = this, actions = [] }
    for (local i = 0; i < option.items.len(); i++)
    {
      if (option.diffCode[i] == ::DIFFICULTY_CUSTOM)
        continue
      let difficulty = ::g_difficulty.getDifficultyByDiffCode(option.diffCode[i])
      let cdPresetValue = difficulty.cdPresetValue
      menu.actions.append({
        actionName  = option.values[i]
        text        = option.items[i]
        icon        = difficulty.icon
        selected    = i == curBaseDifficulty
        action      = (@(cdPresetValue) function () {
          applyCdPreset(cdPresetValue)
        })(cdPresetValue)
      })
    }
    ::gui_handlers.ActionsList.open(obj, menu)
  }

  function applyCdPreset(cdValue)
  {
    ::set_cd_preset(cdValue)
    reinitScreen()
  }
}

//------------------------------------------------------------------------------

::get_custom_difficulty_options <- function get_custom_difficulty_options()
{
  let gm = ::get_game_mode()
  let canChangeTpsViews = isGameModeCoop(gm) || isGameModeVersus(gm) || gm == ::GM_TEST_FLIGHT

  return [
      [::USEROPT_CD_ENGINE],
      [::USEROPT_CD_GUNNERY],
      [::USEROPT_CD_DAMAGE],
      [::USEROPT_CD_STALLS],
      [::USEROPT_CD_BOMBS],
      [::USEROPT_CD_FLUTTER],
      [::USEROPT_CD_REDOUT],
      [::USEROPT_CD_MORTALPILOT],
      [::USEROPT_CD_BOOST],
      [::USEROPT_CD_TPS, null, canChangeTpsViews],
      [::USEROPT_CD_AIR_HELPERS],
      [::USEROPT_CD_ALLOW_CONTROL_HELPERS],
      [::USEROPT_CD_FORCE_INSTRUCTOR],
      [::USEROPT_CD_COLLECTIVE_DETECTION],
      [::USEROPT_CD_DISTANCE_DETECTION],
      [::USEROPT_CD_AIM_PRED],
      //[::USEROPT_CD_SPEED_VECTOR],
      [::USEROPT_CD_MARKERS],
      [::USEROPT_CD_ARROWS],
      [::USEROPT_CD_AIRCRAFT_MARKERS_MAX_DIST],
      [::USEROPT_CD_INDICATORS],
      [::USEROPT_CD_TANK_DISTANCE],
      [::USEROPT_CD_MAP_AIRCRAFT_MARKERS],
      [::USEROPT_CD_MAP_GROUND_MARKERS],
      [::USEROPT_CD_MARKERS_BLINK],
      [::USEROPT_CD_RADAR],
      [::USEROPT_CD_DAMAGE_IND],
      [::USEROPT_CD_LARGE_AWARD_MESSAGES],
      [::USEROPT_CD_WARNINGS],
    ]
}

//------------------------------------------------------------------------------

::gui_start_cd_options <- function gui_start_cd_options(afterApplyFunc, owner = null)
{
  dagor.debug("gui_start_cd_options called")
  if (::SessionLobby.isInRoom())
  {
    let curDiff = ::SessionLobby.getMissionParam("custDifficulty", null)
    if (curDiff)
      ::set_cd_preset(curDiff)
  }

  ::handlersManager.loadHandler(::gui_handlers.OptionsCustomDifficultyModal, {
    owner = owner
    afterApplyFunc = ::Callback(afterApplyFunc, owner)
  })
}

::get_custom_difficulty_tooltip_text <- function get_custom_difficulty_tooltip_text(custDifficulty)
{
  let wasDiff = ::get_cd_preset(::DIFFICULTY_CUSTOM)
  ::set_cd_preset(custDifficulty)

  local text = ""
  let options = ::get_custom_difficulty_options()
  foreach(o in options)
  {
    let opt = get_option(o[0])
    let valueText = opt.items ?
      ::loc(opt.items[opt.value]) :
      ::loc(opt.value ? "options/yes" : "options/no")
    text += (text!="")? "\n" : ""
    text += ::loc("options/" + opt.id) + ::loc("ui/colon") + ::colorize("userlogColoredText", valueText)
  }

  ::set_cd_preset(wasDiff)
  return text
}
