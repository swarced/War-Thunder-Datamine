let { is_seen_nuclear_event,
        is_seen_main_nuclear_event,
        need_show_after_streak } = require("hangarEventCommand")
let airRaidWndScene = require("%scripts/wndLib/airRaidWnd.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")

let newClientVersionEvent = persist("newClientVersionEvent ", @() {
  hasMessage = false
})

let function onNewClientVersion(params) {
  newClientVersionEvent.hasMessage = true
  if (!::is_in_flight())
    ::broadcastEvent("NewClientVersion", params)

  return { result = "ok" }
}

let function checkNuclearEvent(params = {}) {
  let needShowNuclearEventAfterStreak = need_show_after_streak()
  if (needShowNuclearEventAfterStreak) {
    airRaidWndScene({hasVisibleNuclearTimer = false})
    return
  }

  let isSeenMainNuclearEvent = is_seen_main_nuclear_event()
  if (isSeenMainNuclearEvent)
    return

  let isSeenNuclearEvent = is_seen_nuclear_event()
  let isNewClient = ::is_version_equals_or_newer("2.0.0.0")
  let isForceNewClientVersionEvent = isSeenNuclearEvent && isNewClient
  if (!isForceNewClientVersionEvent && !newClientVersionEvent.hasMessage)
    return

  newClientVersionEvent.hasMessage = false
  if (isSeenNuclearEvent && !isNewClient)
    return

  airRaidWndScene({hasVisibleNuclearTimer = params?.showTimer ?? !isNewClient})
}

let function bigQuerryForNuclearEvent() {
  if (!::g_login.isProfileReceived())
    return

  let needSendStatistic = ::load_local_account_settings("sendNuclearStatistic", true)
  if (!needSendStatistic)
    return

  ::add_big_query_record("nuclear_event", ::save_to_json({
    user = ::my_user_id_str,
    seenInOldClient = is_seen_nuclear_event(),
    seenInNewClient = is_seen_main_nuclear_event()}))
  ::save_local_account_settings("sendNuclearStatistic", false)
}

addListenersWithoutEnv({
  ProfileReceived = @(p) bigQuerryForNuclearEvent()
})

::web_rpc.register_handler("new_client_version", onNewClientVersion)

return {
  checkNuclearEvent
}
