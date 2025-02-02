let daguiFonts = require("%scripts/viewUtils/daguiFonts.nut")
let time = require("%scripts/time.nut")
let statsd = require("statsd")
let exitGame = require("%scripts/utils/exitGame.nut")

local authDataByTypes = {
  mail = {text = "#mainmenu/2step/confirmMail", img = "#ui/images/two_step_email"}
  ga = {text = "#mainmenu/2step/confirmGA", img = "#ui/images/two_step_phone_ga"}
  gp = {text = "#mainmenu/2step/confirmGP", img = "#ui/images/two_step_phone_gp"}
  unknown = {text = "#mainmenu/2step/confirmUnknown", img = ""}
}

::gui_handlers.twoStepModal <- class extends ::BaseGuiHandler
{
  wndType              = handlerType.MODAL
  sceneTplName         = "%gui/login/twoStepModal"
  loginScene           = null
  continueLogin        = null
  curTimeTimer         = null

  function getSceneTplView()
  {
    let isExt2StepAllowed = ::is_external_app_2step_allowed()
    let data = !isExt2StepAllowed && ::is_has_email_two_step_type_sync() ? authDataByTypes.mail
      : isExt2StepAllowed && ::is_has_wtassistant_two_step_type_sync() ? authDataByTypes.ga
      : isExt2StepAllowed && ::is_has_gaijin_pass_two_step_type_sync() ? authDataByTypes.gp
      : authDataByTypes.unknown

    return {
      verStatusText = data.text
      authTypeImg = data.img
      isShowRestoreLink = isExt2StepAllowed
      isRememberDevice = ::get_object_value(loginScene,"loginbox_code_remember_this_device", false)
      timerWidth = daguiFonts.getStringWidthPx("99:99:99", "fontNormal", guiScene)
    }
  }

  function initScreen()
  {
    reinitCurTimeTimer()
    ::select_editbox(getObj("loginbox_code"))
  }

  function reinitCurTimeTimer()
  {
    curTimeTimer = null
    let timerObj = scene.findObject("currTimeText")
    if (!::check_obj(timerObj))
      return

    let timerCb = @() timerObj.setValue(time.buildTimeStr(::get_charserver_time_sec(), true))
    curTimeTimer = ::Timer(timerObj, 1, timerCb, this, true)
    timerCb()
  }

  function onSubmit(obj)
  {
    ::disable_autorelogin_once <- false
    statsd.send_counter("sq.game_start.request_login", 1, {login_type = "regular"})
    ::dagor.debug("Login: check_login_pass")
    let result = ::check_login_pass(
      ::get_object_value(loginScene, "loginbox_username",""),
      ::get_object_value(loginScene, "loginbox_password", ""), "",
      ::get_object_value(scene, "loginbox_code", ""),
      ::get_object_value(scene, "loginbox_code_remember_this_device", false),
      true)
    proceedAuth(result)
  }

  function showErrorMsg()
  {
    let txtObj = scene.findObject("verStatus")
    if (!::check_obj(txtObj))
      return

    let errorText = "".concat(::loc("mainmenu/2step/wrongCode"), ::loc("ui/colon"))
    let errorTimerCb = @() txtObj.setValue(::colorize("badTextColor", "".concat(errorText,
        time.buildTimeStr(::get_charserver_time_sec(), true))))
    ::Timer(txtObj, 1, errorTimerCb, this, true)
    errorTimerCb()

    // Need this to make both timers tick synchronously
    reinitCurTimeTimer()
  }

  function proceedAuth(result)
  {
    switch (result)
    {
      case ::YU2_OK:
        continueLogin(::get_object_value(loginScene, "loginbox_username",""))
        break

      case ::YU2_2STEP_AUTH:
      case ::YU2_WRONG_2STEP_CODE:
        showErrorMsg()
        break

      default:
        ::error_message_box("yn1/connect_error", result,
        [
          ["exit", exitGame],
          ["tryAgain", null]
        ], "tryAgain", { cancel_fn = function() {}})
    }
  }
}

return {
  open = @(p) ::handlersManager.loadHandler(::gui_handlers.twoStepModal, p)
}