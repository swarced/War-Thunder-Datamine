let statsd = require("statsd")
let { animBgLoad } = require("%scripts/loading/animBg.nut")
let { setVersionText } = require("%scripts/viewUtils/objectTextUpdate.nut")
let exitGame = require("%scripts/utils/exitGame.nut")

::gui_handlers.LoginWndHandlerEpic <- class extends ::gui_handlers.LoginWndHandler
{
  sceneBlkName = "%gui/loginBoxSimple.blk"

  function initScreen()
  {
    animBgLoad()
    setVersionText()
    ::setProjectAwards(this)

    guiScene.performDelayed(this, function() { doLogin() })
  }

  function doLogin()
  {
    ::dagor.debug("Epic login: check_login_pass")
    statsd.send_counter("sq.game_start.request_login", 1, {login_type = "epic"})
    let ret = ::check_login_pass("", "", "epic", "epic", false, false)
    proceedAuthorizationResult(ret)
  }

  function proceedAuthorizationResult(result)
  {
    if (!::checkObj(scene)) //check_login_pass is not instant
      return

    switch (result)
    {
      case ::YU2_OK:
        ::set_login_pass("", "", 0)
        ::g_login.addState(LOGIN_STATE.AUTHORIZED)
        break
      default:
        ::error_message_box("yn1/connect_error", result,
        [
          ["exit", exitGame],
          ["tryAgain", ::Callback(doLogin, this)]
        ], "tryAgain", { cancel_fn = ::Callback(doLogin, this) })
    }
  }

  function goBack(obj) {}
}

