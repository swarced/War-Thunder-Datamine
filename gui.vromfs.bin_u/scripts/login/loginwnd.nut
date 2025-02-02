let statsd = require("statsd")
let { animBgLoad } = require("%scripts/loading/animBg.nut")
let showTitleLogo = require("%scripts/viewUtils/showTitleLogo.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let { setVersionText } = require("%scripts/viewUtils/objectTextUpdate.nut")
let twoStepModal = require("%scripts/login/twoStepModal.nut")
let exitGame = require("%scripts/utils/exitGame.nut")
let { setFocusToNextObj } = require("%sqDagui/daguiUtil.nut")
let loginWndBlkPath = require("%scripts/login/loginWndBlkPath.nut")
local { setGuiOptionsMode } = ::require_native("guiOptions")
let { havePlayerTag } = require("scripts/user/userUtils.nut")
let { getDistr } = require("auth_wt")

const MAX_GET_2STEP_CODE_ATTEMPTS = 10


::gui_handlers.LoginWndHandler <- class extends ::BaseGuiHandler
{
  sceneBlkName = loginWndBlkPath.value

  check2StepAuthCode = false
  availableCircuitsBlockName = "multipleAvailableCircuits"
  paramName = "circuit"
  shardItems = null
  localizationInfo = null

  initial_autologin = false
  stoken = "" //note: it's safe to keep it here even if it's dumped to log
  was_using_stoken = false
  isLoginRequestInprogress = false
  requestGet2stepCodeAtempt = 0
  isSteamAuth = false

  defaultSaveLoginFlagVal = false
  defaultSavePasswordFlagVal = false
  defaultSaveAutologinFlagVal = false

  tabFocusArray = [
    "loginbox_username",
    "loginbox_password"
  ]

  function initScreen()
  {
    animBgLoad()
    setVersionText()
    ::setProjectAwards(this)
    showTitleLogo(scene, 128)
    initLanguageSwitch()
    checkShardingCircuits()
    setGuiOptionsMode(::OPTIONS_MODE_GAMEPLAY)

    ::enable_keyboard_layout_change_tracking(true)
    ::enable_keyboard_locks_change_tracking(true)

    let bugDiscObj = scene.findObject("browser_bug_disclaimer")
    if (::checkObj(bugDiscObj))
      bugDiscObj.show(::target_platform == "linux64" && ::is_steam_big_picture()) //STEAM_OS

    let lp = ::get_login_pass()
    let isVietnamese = ::is_vietnamese_version()
    if (isVietnamese)
      lp.autoSave = lp.autoSave & ::AUTO_SAVE_FLG_LOGIN

    let disableSSLCheck = lp.autoSave & ::AUTO_SAVE_FLG_NOSSLCERT

    let unObj = scene.findObject("loginbox_username")
    if (::checkObj(unObj))
      unObj.setValue(lp.login)

    let psObj = scene.findObject("loginbox_password")
    if (::checkObj(psObj)) {
      psObj["password-smb"] = ::loc("password_mask_char", "*")
      psObj.setValue(lp.password)
    }

    let alObj = scene.findObject("loginbox_autosave_login")
    if (::checkObj(alObj))
      alObj.setValue(lp.autoSave & ::AUTO_SAVE_FLG_LOGIN)

    let spObj = scene.findObject("loginbox_autosave_password")
    if (::checkObj(spObj))
    {
      spObj.show(!isVietnamese)
      spObj.setValue(lp.autoSave & ::AUTO_SAVE_FLG_PASS)
      spObj.enable((lp.autoSave & ::AUTO_SAVE_FLG_LOGIN) != 0 && !isVietnamese)
      local text = ::loc("mainmenu/savePassword")
      if (!::is_platform_shield_tv())
        text += " " + ::loc("mainmenu/savePassword/unsecure")
      spObj.findObject("loginbox_autosave_password_text").setValue(text)
    }

    setDisableSslCertBox(disableSSLCheck)
    let isSteamRunning = ::steam_is_running()
    let showSteamLogin = isSteamRunning
    let showWebLogin = !isSteamRunning && ::webauth_start(this, onSsoAuthorizationComplete)
    showSceneBtn("secondary_auth_block", showSteamLogin || showWebLogin)
    showSceneBtn("steam_login_action_button", showSteamLogin)
    showSceneBtn("sso_login_action_button", showWebLogin)
    showSceneBtn("btn_signUp_link", !showSteamLogin)

    initial_autologin = ::is_autologin_enabled()

    let saveLoginAndPassMask = ::AUTO_SAVE_FLG_LOGIN | ::AUTO_SAVE_FLG_PASS
    let autoLoginEnable = (lp.autoSave & saveLoginAndPassMask) == saveLoginAndPassMask
    local autoLogin = (initial_autologin && autoLoginEnable) || ::need_force_autologin()
    let autoLoginObj = scene.findObject("loginbox_autologin")
    if (::checkObj(autoLoginObj))
    {
      autoLoginObj.show(!isVietnamese)
      autoLoginObj.enable(autoLoginEnable)
      autoLoginObj.setValue(autoLogin)
    }

    showSceneBtn("links_block", !::is_platform_shield_tv())

    if ("dgs_get_argv" in ::getroottable())
    {
      let s = ::dgs_get_argv("stoken")
      if (!::u.isEmpty(s))
        lp.stoken <- s
    }
    else if ("dgs_argc" in ::getroottable())
      for (local i = 1; i < ::dgs_argc(); i++)
      {
        let str = ::dgs_argv(i);
        let idx = str.indexof("-stoken:")
        if (idx != null)
          lp.stoken <- str.slice(idx+8)
      }

    if (("stoken" in lp) && lp.stoken != null && lp.stoken != "")
    {
      stoken = lp.stoken
      doLoginDelayed()
      return
    }

    if ("disable_autorelogin_once" in ::getroottable())
      autoLogin = autoLogin && !disable_autorelogin_once
    if (autoLogin)
    {
      doLoginDelayed()
      return
    }

    ::select_editbox(scene.findObject(tabFocusArray[ lp.login != "" ? 1 : 0 ]))
  }

  function onDestroy()
  {
    ::webauth_stop()
    ::enable_keyboard_layout_change_tracking(false)
    ::enable_keyboard_locks_change_tracking(false)
  }

  function setDisableSslCertBox(value)
  {
    let dcObj = showSceneBtn("loginbox_disable_ssl_cert", value)
    if (::checkObj(dcObj))
      dcObj.setValue(value)
  }

  function checkShardingCircuits()
  {
    local defValue = 0
    let networkBlk = ::get_network_block()
    let avCircuits = networkBlk.getBlockByName(availableCircuitsBlockName)

    let configCircuitName = ::get_cur_circuit_name()
    shardItems = [{
                    item = configCircuitName
                    text = ::loc("circuit/" + configCircuitName)
                 }]

    if (avCircuits && avCircuits.paramCount() > 0)
    {
      local defaultCircuit = ::loc("default_circuit", "")
      if (defaultCircuit == "")
        defaultCircuit = configCircuitName

      shardItems = []
      for(local i = 0; i < avCircuits.paramCount(); ++i)
      {
        let param = avCircuits.getParamName(i)
        let value = avCircuits.getParamValue(i)
        if (param == paramName && typeof(value) == "string")
        {
          if (value == defaultCircuit)
            defValue = i

          shardItems.append({
                              item = value
                              text = ::loc("circuit/" + value)
                           })
        }
      }
    }

    let show = shardItems.len() > 1
    let shardObj = showSceneBtn("sharding_block", show)
    if (show && ::checkObj(shardObj))
    {
      let dropObj = shardObj.findObject("sharding_dropright_block")
      let shardData = ::create_option_combobox("sharding_list", shardItems, defValue, null, true)
      guiScene.replaceContentFromText(dropObj, shardData, shardData.len(), this)
    }
  }

  function onChangeAutosave()
  {
    if (!isValid())
      return

    let remoteCompObj = scene.findObject("loginbox_remote_comp")
    let rememberDeviceObj = scene.findObject("loginbox_code_remember_this_device")
    let savePassObj = scene.findObject("loginbox_autosave_password")
    let saveLoginObj = scene.findObject("loginbox_autosave_login")
    let autoLoginObj = scene.findObject("loginbox_autologin")
    let disableCertObj = scene.findObject("loginbox_disable_ssl_cert")

    if (rememberDeviceObj.isVisible())
      remoteCompObj.setValue(!rememberDeviceObj.getValue())
    else
      rememberDeviceObj.setValue(!remoteCompObj.getValue())

    let isRemoteComp = remoteCompObj.getValue()
    let isAutosaveLogin = saveLoginObj.getValue()
    let isAutosavePass = savePassObj.getValue()

    setDisableSslCertBox(disableCertObj.getValue())

    saveLoginObj.enable(!isRemoteComp)
    savePassObj.enable(!isRemoteComp && isAutosaveLogin && !::is_vietnamese_version())
    autoLoginObj.enable(!isRemoteComp && isAutosaveLogin && isAutosavePass)

    if (isRemoteComp)
      saveLoginObj.setValue(false)
    if (isRemoteComp || !isAutosaveLogin)
      savePassObj.setValue(false)
    if (isRemoteComp || !isAutosavePass || !isAutosaveLogin)
      autoLoginObj.setValue(false)
  }

  function initLanguageSwitch()
  {
    let canSwitchLang = ::canSwitchGameLocalization()
    showSceneBtn("language_selector", canSwitchLang)
    if (!canSwitchLang)
      return

    localizationInfo = localizationInfo || ::g_language.getGameLocalizationInfo()
    let curLangId = ::get_current_language()
    local lang = localizationInfo[0]
    foreach (l in localizationInfo)
      if (l.id == curLangId)
        lang = l

    let objLangLabel = scene.findObject("label_language")
    if (::checkObj(objLangLabel))
    {
      local title = ::loc("profile/language")
      let titleEn = ::loc("profile/language/en")
      title += (title == titleEn ? "" : ::loc("ui/parentheses/space", { text = titleEn })) + ":"
      objLangLabel.setValue(title)
    }
    let objLangIcon = scene.findObject("btn_language_icon")
    if (::checkObj(objLangIcon))
      objLangIcon["background-image"] = lang.icon
    let objLangName = scene.findObject("btn_language_text")
    if (::checkObj(objLangName))
      objLangName.setValue(lang.title)
  }

  function onPopupLanguages(obj)
  {
    if (::gui_handlers.ActionsList.hasActionsListOnObject(obj))
      return onClosePopups()

    localizationInfo = localizationInfo || ::g_language.getGameLocalizationInfo()
    if (!::checkObj(obj) || localizationInfo.len() < 2)
      return

    let curLangId = ::get_current_language()
    let menu = {
      handler = this
      closeOnUnhover = true
      actions = []
    }
    for (local i = 0; i < localizationInfo.len(); i++)
    {
      let lang = localizationInfo[i]
      menu.actions.append({
        actionName  = lang.id
        text        = lang.title
        icon        = lang.icon
        action      = (@(lang) function () { onChangeLanguage(lang.id) })(lang)
        selected    = lang.id == curLangId
      })
    }
    ::gui_handlers.ActionsList.open(obj, menu)
  }

  function onClosePopups()
  {
    let obj = scene.findObject("btn_language")
    if (::checkObj(obj))
      ::gui_handlers.ActionsList.removeActionsListFromObject(obj, true)
  }

  function onChangeLanguage(langId)
  {
    let no_dump_login = scene.findObject("loginbox_username").getValue() || ""
    let no_dump_pass = scene.findObject("loginbox_password").getValue() || ""
    let isRemoteComp = scene.findObject("loginbox_remote_comp").getValue()
    let code_remember_this_device = scene.findObject("loginbox_code_remember_this_device").getValue()
    let isAutosaveLogin = scene.findObject("loginbox_autosave_login").getValue()
    let isAutosavePass = scene.findObject("loginbox_autosave_password").getValue()
    let autologin = scene.findObject("loginbox_autologin").getValue()
    let shardingListObj = scene.findObject("sharding_list")
    let shard = shardingListObj ? shardingListObj.getValue() : -1

    ::g_language.setGameLocalization(langId, true, true)

    let handler = ::handlersManager.findHandlerClassInScene(::gui_handlers.LoginWndHandler)
    scene = handler ? handler.scene : null
    if (!::checkObj(scene))
      return

    scene.findObject("loginbox_username").setValue(no_dump_login)
    scene.findObject("loginbox_password").setValue(no_dump_pass)
    scene.findObject("loginbox_remote_comp").setValue(isRemoteComp)
    scene.findObject("loginbox_code_remember_this_device").setValue(code_remember_this_device)
    scene.findObject("loginbox_autosave_login").setValue(isAutosaveLogin)
    scene.findObject("loginbox_autosave_password").setValue(isAutosavePass)
    scene.findObject("loginbox_autologin").setValue(autologin)
    handler.onChangeAutosave()
    if (shardingListObj)
      shardingListObj.setValue(shard)
  }

  function requestLogin(no_dump_login)
  {
    return requestLoginWithCode(no_dump_login, "");
  }

  function requestLoginWithCode(no_dump_login, code)
  {
    statsd.send_counter("sq.game_start.request_login", 1, {login_type = "regular"})
    ::dagor.debug("Login: check_login_pass")
    return ::check_login_pass(no_dump_login,
                              ::get_object_value(scene, "loginbox_password", ""),
                              check2StepAuthCode ? "" : stoken, //after trying use stoken it's set to "", but to be sure - use "" for 2stepAuth
                              code,
                              check2StepAuthCode
                                ? ::get_object_value(scene, "loginbox_code_remember_this_device", false)
                                : !::get_object_value(scene, "loginbox_disable_ssl_cert", false),
                              ::get_object_value(scene, "loginbox_remote_comp", false)
                             )
  }

  function continueLogin(no_dump_login)
  {
    if (shardItems)
    {
      if (shardItems.len() == 1)
        ::set_network_circuit(shardItems[0].item)
      else if (shardItems.len() > 1)
        ::set_network_circuit(shardItems[scene.findObject("sharding_list").getValue()].item)
    }

    let autoSaveLogin = ::get_object_value(scene, "loginbox_autosave_login", defaultSaveLoginFlagVal)
    let autoSavePassword = ::get_object_value(scene, "loginbox_autosave_password", defaultSavePasswordFlagVal)
    let disableSSLCheck = ::get_object_value(scene, "loginbox_disable_ssl_cert", false)
    local autoSave = (autoSaveLogin     ? ::AUTO_SAVE_FLG_LOGIN     : 0) |
                     (autoSavePassword  ? ::AUTO_SAVE_FLG_PASS      : 0) |
                     (disableSSLCheck   ? ::AUTO_SAVE_FLG_NOSSLCERT : 0)

    if (was_using_stoken || isSteamAuth)
      autoSave = autoSave | ::AUTO_SAVE_FLG_DISABLE

    ::set_login_pass(no_dump_login.tostring(), ::get_object_value(scene, "loginbox_password", ""), autoSave)
    if (!::checkObj(scene)) //set_login_pass start onlineJob
      return

    let autoLogin = (autoSaveLogin && autoSavePassword) ?
                ::get_object_value(scene, "loginbox_autologin", defaultSaveAutologinFlagVal)
                : false
    ::set_autologin_enabled(autoLogin)
    if (initial_autologin != autoLogin)
      ::save_profile(false)

    ::g_login.addState(LOGIN_STATE.AUTHORIZED)
  }

  function onOk()
  {
    if (!isLoginEditsFilled())
      return

    isLoginRequestInprogress = true
    requestGet2stepCodeAtempt = MAX_GET_2STEP_CODE_ATTEMPTS
    doLoginWaitJob()
  }

  function doLoginDelayed()
  {
    isLoginRequestInprogress = true
    guiScene.performDelayed(this, doLoginWaitJob)
  }

  function doLoginWaitJob()
  {
    ::disable_autorelogin_once <- false
    let no_dump_login = ::get_object_value(scene, "loginbox_username", "")
    local result = requestLogin(no_dump_login)
    proceedAuthorizationResult(result, no_dump_login)
  }

  function onSteamAuthorization(steamSpecCode = null)
  {
    isSteamAuth = true
    steamSpecCode = steamSpecCode || "steam"
    isLoginRequestInprogress = true
    ::disable_autorelogin_once <- false
    statsd.send_counter("sq.game_start.request_login", 1, {login_type = "steam"})
    ::dagor.debug("Steam Login: check_login_pass with code " + steamSpecCode)
    let result = ::check_login_pass("", "", "steam", steamSpecCode, false, false)
    proceedAuthorizationResult(result, "")
  }

  function onSsoAuthorization()
  {
    let no_dump_login = ::get_object_value(scene, "loginbox_username", "")
    let no_dump_url = ::webauth_get_url(no_dump_login)
    openUrl(no_dump_url)
    ::browser_set_external_url(no_dump_url)
  }

  function onSsoAuthorizationComplete(params)
  {
    ::close_browser_modal()

    if (params.success)
    {
      let no_dump_login = ::get_object_value(scene, "loginbox_username", "")
      continueLogin(no_dump_login);
    }
  }

  function onEventProceedGetTwoStepCode(data)
  {
    if (!isValid() || isLoginRequestInprogress)
    {
      return
    }

    let result = data.status
    let code = data.code
    let no_dump_login = ::get_object_value(scene, "loginbox_username", "")

    if (result == ::YU2_TIMEOUT && requestGet2stepCodeAtempt-- > 0)
    {
      doLoginDelayed()
      return
    }

    if (result == ::YU2_OK)
    {
      isLoginRequestInprogress = true
      let loginResult = requestLoginWithCode(no_dump_login, code)
      proceedAuthorizationResult(loginResult, no_dump_login)
    }
  }

  function needTrySteamLink()
  {
    return ::steam_is_running()
           && ::has_feature("AllowSteamAccountLinking")
           && ::load_local_shared_settings(USE_STEAM_LOGIN_AUTO_SETTING_ID) == null
  }

  function proceedAuthorizationResult(result, no_dump_login)
  {
    isLoginRequestInprogress = false
    if (!::checkObj(scene)) //check_login_pass is not instant
      return

    was_using_stoken = (stoken != "")
    stoken = ""
    switch (result)
    {
      case ::YU2_OK:
        if (::steam_is_running()
            && !::has_feature("AllowSteamAccountLinking")
            && !havePlayerTag("steam"))
        {
          msgBox("steam_relogin_request",
            ::loc("mainmenu/login/steamRelogin"),
          [
            ["ok", ::restart_without_steam],
            ["cancel"]
          ],
          "ok", { cancel_fn = @() null })
          return
        }

        if (needTrySteamLink())
        {
          let isRemoteComp = ::get_object_value(scene, "loginbox_remote_comp", false)
          statsd.send_counter("sq.game_start.request_login", 1, {login_type = "steam_link"})
          ::dagor.debug("Steam Link Login: check_login_pass")
          let res = ::check_login_pass("", "", "steam", "steam", true, isRemoteComp)
          ::dagor.debug("Steam Link Login: link existing account, result = " + res)
          if (res == ::YU2_OK)
            ::save_local_shared_settings(USE_STEAM_LOGIN_AUTO_SETTING_ID, true)
          else if (res == ::YU2_ALREADY)
            ::save_local_shared_settings(USE_STEAM_LOGIN_AUTO_SETTING_ID, false)
        }
        else if (::steam_is_running() && !::has_feature("AllowSteamAccountLinking"))
          ::save_local_shared_settings(USE_STEAM_LOGIN_AUTO_SETTING_ID, isSteamAuth)

        continueLogin(no_dump_login)
        break

      case ::YU2_2STEP_AUTH: //error, received if user not logged, because he have 2step authorization activated
        {
          check2StepAuthCode = true
          showSceneBtn("loginbox_code_remember_this_device", true)
          showSceneBtn("loginbox_remote_comp", false)
          twoStepModal.open({
            loginScene           = scene,
            continueLogin        = continueLogin.bindenv(this)
          })
          onChangeAutosave()
          guiScene.performDelayed(this, (@(scene) function() {
            if (!::checkObj(scene))
              return

            if ("get_two_step_code_async2" in getroottable())
              ::get_two_step_code_async2("ProceedGetTwoStepCode")
            else
              ::get_two_step_code_async(this, onEventProceedGetTwoStepCode)
          })(scene))
        }
        break

      case ::YU2_PSN_RESTRICTED:
        {
          msgBox("psn_restricted", ::loc("yn1/login/PSN_RESTRICTED"),
             [["exit", exitGame ]], "exit")
        }
        break;

      case ::YU2_WRONG_LOGIN:
      case ::YU2_WRONG_PARAMETER:
        if (was_using_stoken)
          return;
        ::error_message_box("yn1/connect_error", result, // auth error
        [
          ["recovery", function() {openUrl(::loc("url/recovery"), false, false, "login_wnd")}],
          ["exit", exitGame],
          ["tryAgain", ::Callback(onLoginErrorTryAgain, this)]
        ], "tryAgain", { cancel_fn = ::Callback(onLoginErrorTryAgain, this) })
        break

      case ::YU2_SSL_CACERT:
        if (was_using_stoken)
          return;
        ::error_message_box("yn1/connect_error", result,
        [
          ["disableSSLCheck", ::Callback(function() { setDisableSslCertBox(true) }, this)],
          ["exit", exitGame],
          ["tryAgain", ::Callback(onLoginErrorTryAgain, this)]
        ], "tryAgain", { cancel_fn = ::Callback(onLoginErrorTryAgain, this) })
        break

      case ::YU2_DOI_INCOMPLETE:
        ::showInfoMsgBox(::loc("yn1/login/DOI_INCOMPLETE"), "verification_email_to_complete")
        break

      default:
        if (was_using_stoken)
          return;
        ::error_message_box("yn1/connect_error", result,
        [
          ["exit", exitGame],
          ["tryAgain", ::Callback(onLoginErrorTryAgain, this)]
        ], "tryAgain", { cancel_fn = ::Callback(onLoginErrorTryAgain, this) })
    }
  }

  function onLoginErrorTryAgain() {}

  function onKbdWrapDown()
  {
    setFocusToNextObj(scene, tabFocusArray, 1)
  }

  function onEventKeyboardLayoutChanged(params)
  {
    let layoutIndicator =
      scene.findObject("loginbox_password_layout_indicator")

    if (!::checkObj(layoutIndicator))
      return

    local layoutCode = params.layout.toupper()
    if (layoutCode.len() > 2)
      layoutCode = layoutCode.slice(0, 2)

    layoutIndicator.setValue(layoutCode)
  }

  function onEventKeyboardLocksChanged(params)
  {
    let capsIndicator = scene.findObject("loginbox_password_caps_indicator")
    if (::check_obj(capsIndicator))
      capsIndicator.show((params.locks & 1) == 1)
  }

  function onSignUp()
  {
    local urlLocId
    if (::steam_is_running())
      urlLocId = "url/signUpSteam"
    else if (::is_platform_shield_tv())
      urlLocId = "url/signUpShieldTV"
    else
      urlLocId = "url/signUp"

    openUrl(::loc(urlLocId, {distr = getDistr()}), false, false, "login_wnd")
  }

  function onForgetPassword()
  {
    openUrl(::loc("url/recovery"), false, false, "login_wnd")
  }

  function onChangeLogin(obj)
  {
    //Don't save value to local, so it doens't appear in logs.
    let res = !::g_string.validateEmail(obj.getValue()) && (stoken == "")
    obj.warning = res? "yes" : "no"
    obj.warningText = res? "yes" : "no"
    obj.tooltip = res? ::loc("tooltip/invalidEmail/possibly") : ""
    setLoginBtnState()
  }

  function onDoneEnter()
  {
    if (!check2StepAuthCode)
      doLoginWaitJob()
  }

  function onDoneCode()
  {
    doLoginWaitJob()
  }

  function onExit()
  {
    msgBox("login_question_quit_game", ::loc("mainmenu/questionQuitGame"),
      [
        ["yes", exitGame],
        ["no", @() null]
      ], "no", { cancel_fn = @() null})
  }

  isLoginEditsFilled = @() ::get_object_value(scene, "loginbox_username", "") != ""
    && ::get_object_value(scene, "loginbox_password", "") != ""

  function setLoginBtnState ()
  {
    let loginBtnObj = scene.findObject("login_action_button")
    if (!::check_obj(loginBtnObj))
      return false

    loginBtnObj.enable = isLoginEditsFilled() ? "yes" : "no"
  }

  function goBack()
  {
    onExit()
  }
}
