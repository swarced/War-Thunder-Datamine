let time = require("%scripts/time.nut")


::gui_handlers.ChatThreadsListView <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/chat/chatThreadsList.blk"
  backFunc = null
  updateInactiveList = false

  roomId = ""

  listObj = null
  curListUid = -1

  function initScreen()
  {
    listObj = scene.findObject("threads_list")
    scene.findObject("threads_list_timer").setUserData(this)

    updateAll(true)
    updateLangsButton()
    updateCategoriesButton()
  }

  function remove()
  {
    scene = null
  }

  function onSceneShow()
  {
    updateAll()
  }

  function updateAll(forceUpdate = false)
  {
    updateList(forceUpdate)
    updateRefreshButton()
  }

  function updateList(forceUpdate = false)
  {
    if (!forceUpdate && ::g_chat_latest_threads.isListNewest(curListUid))
      return

    if (!::checkObj(listObj))
      return

    let selThread = getThreadByObj()

    curListUid = ::g_chat_latest_threads.curListUid
    let list = ::g_chat_latest_threads.getList()
    let isWaiting = !list.len() && ::g_chat_latest_threads.getUpdateState() == chatUpdateState.IN_PROGRESS
    if (isWaiting)
      return

    let view = {
      isGamepadMode = ::show_console_buttons
      threads = list
    }

    let data = ::handyman.renderCached("%gui/chat/chatThreadsListRows", view)
    guiScene.replaceContentFromText(listObj, data, data.len(), this)

    if (list.len())
      listObj.setValue(::find_in_array(list, selThread, 0))
  }

  function markListChanged()
  {
    curListUid = -1
  }

  function updateRefreshButton()
  {
    let btnObj = scene.findObject("btn_refresh")
    let isWaiting = ::g_chat_latest_threads.getUpdateState() == chatUpdateState.IN_PROGRESS

    btnObj.findObject("btn_refresh_img").show(!isWaiting)
    btnObj.findObject("btn_refresh_wait_anim").show(isWaiting)

    let canRefresh = !isWaiting && ::g_chat_latest_threads.canRefresh()
    btnObj.enable(canRefresh)

    local tooltip = ::loc("mainmenu/btnRefresh")
    let timeLeft = ::g_chat_latest_threads.getTimeToRefresh()
    if (timeLeft > 0)
      tooltip += " (" + time.secondsToString(0.001 * timeLeft, true, true) + ")"
    btnObj.tooltip = tooltip
    guiScene.updateTooltip(btnObj)
  }

  function updateLangsButton()
  {
    let show = ::g_chat.canChooseThreadsLang()
    let langsBtn = showSceneBtn("threads_search_langs_btn", show)
    if (!show)
      return

    let langs = ::g_chat_latest_threads.getSearchLangsList()
    let view = {
      countries = ::u.map(langs, function (l) { return { countryIcon = l.icon } })
    }
    let data = ::handyman.renderCached("%gui/countriesList", view)
    guiScene.replaceContentFromText(langsBtn, data, data.len(), this)
  }

  function updateCategoriesButton()
  {
    let show = ::g_chat_categories.isEnabled()
    showSceneBtn("buttons_separator", !show)
    let catBtn = showSceneBtn("btn_categories_filter", show)
    if (!show)
      return

    local text = ""
    if (::g_chat_categories.isSearchAnyCategory())
      text = ::loc("chat/allCategories")
    else
    {
      let textsList = ::u.map(::g_chat_categories.getSearchCategoriesLList(),
                                function(cName) { return ::g_chat_categories.getCategoryNameText(cName) })
      text = ::g_string.implode(textsList, ", ")
    }
    catBtn.setValue(text)
  }

  function onEventChatLatestThreadsUpdate(p)
  {
    if (isSceneActive() || updateInactiveList)
    {
      updateAll(updateInactiveList)
      updateInactiveList = false
    }
  }

  function onEventCrossNetworkChatOptionChanged(p)
  {
    updateInactiveList = true
  }

  function onEventContactsBlockStatusUpdated(p) {
    updateInactiveList = true
  }

  function onUpdate(obj, dt)
  {
    if (isSceneActive())
      updateAll()
  }

  function getThreadByObj(obj = null)
  {
    let rId = obj?.roomId
    if (rId && rId.len())
      return ::g_chat.getThreadInfo(rId)

    if (!::checkObj(listObj))
      return null

    let value = listObj.getValue() || 0
    if (value >= 0 && value < listObj.childrenCount())
      return ::g_chat.getThreadInfo(listObj.getChild(value).roomId)
    return null
  }

  function onJoinThread(obj)
  {
    let actionThread = getThreadByObj(obj)
    if (actionThread)
      actionThread.join()
  }

  function onUserInfo(obj)
  {
    let actionThread = getThreadByObj(obj)
    if (actionThread)
      actionThread.showOwnerMenu(null)
  }

  function onEditThread(obj)
  {
    let actionThread = getThreadByObj(obj)
    if (actionThread)
      ::g_chat.openModifyThreadWnd(actionThread)
  }

  function openThreadMenu()
  {
    let actionThread = getThreadByObj()
    if (!actionThread)
      return

    local pos = null
    let nameObj = listObj.findObject("ownerName_" + actionThread.roomId)
    if (::checkObj(nameObj))
    {
      pos = nameObj.getPosRC()
      pos[0] += nameObj.getSize()[0]
    }
    actionThread.showThreadMenu(pos)
  }

  function onCreateThread()
  {
    ::g_chat.openRoomCreationWnd()
  }

  function onRefresh()
  {
    ::g_chat_latest_threads.refresh()
    updateRefreshButton()
  }

  function onThreadsActivate(obj)
  {
    if (::show_console_buttons)
      openThreadMenu() //gamepad shortcut
    else
      onJoinThread(obj) //dblClick
  }

  function onThreadSelect()
  {
    //delayed callbac
    if (!::checkObj(listObj) || !listObj.childrenCount())
      return

    //sellImg is bigger than item, so for correct view while selecting by gamepad need to scroll to selImg
    let val = ::get_obj_valid_index(listObj)
    local childObj = listObj.getChild(val < 0? 0 : val)
    if (!::check_obj(childObj))
      childObj = listObj.getChild(0)

    let selImg = childObj.findObject("thread_row_sel_img")
    if (::checkObj(selImg))
      selImg.scrollToView()
  }

  function onLangsBtn(obj)
  {
    ::g_chat_latest_threads.openChooseLangsMenu("top", scene.findObject("threads_search_langs_btn"))
  }

  function onCategoriesBtn(obj)
  {
    ::g_chat_categories.openChooseCategoriesMenu("top", scene.findObject("btn_categories_filter"))
  }

  function updateRoomInList(room)
  {
    if (room && room.type == ::g_chat_room_type.THREAD)
      updateThreadInList(room.id)
  }

  function updateThreadInList(id)
  {
    if (!isSceneActive())
      return markListChanged()

    let threadInfo = ::g_chat.getThreadInfo(id)
    if (threadInfo)
      threadInfo.updateInfoObj(scene.findObject("room_" + id), !::show_console_buttons)
  }

  function goBack()
  {
    if (backFunc)
      backFunc()
  }

  function onEventChatRoomJoin(p)
  {
    updateRoomInList(::getTblValue("room", p))
  }

  function onEventChatRoomLeave(p)
  {
    updateRoomInList(::getTblValue("room", p))
  }

  function onEventChatFilterChanged(p)
  {
    markListChanged()
    if (isSceneActive())
    {
      //wait to apply all options before update scene.
      let cb = ::Callback(updateAll, this)
      guiScene.performDelayed(this, (@(cb) function() { cb() })(cb))
    }
  }

  function onEventChatThreadSearchLangChanged(p)
  {
    updateLangsButton()
  }

  function onEventChatSearchCategoriesChanged(p)
  {
    updateCategoriesButton()
  }
}
