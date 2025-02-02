let { clearBorderSymbols } = require("%sqstd/string.nut")
let playerContextMenu = require("%scripts/user/playerContextMenu.nut")
let platformModule = require("%scripts/clientState/platform.nut")
let crossplayModule = require("%scripts/social/crossplay.nut")
let { topMenuBorders } = require("%scripts/mainmenu/topMenuStates.nut")
let { isChatEnabled } = require("%scripts/chat/chatStates.nut")
let { showViralAcquisitionWnd } = require("%scripts/user/viralAcquisition.nut")
let { isAvailableFacebook } = require("%scripts/social/facebookStates.nut")

::contacts_prev_scenes <- [] //{ scene, show }
::last_contacts_scene_show <- false

::ContactsHandler <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  searchText = ""

  listNotPlayerChildsByGroup = null

  wndControlsAllowMask = CtrlsInGui.CTRL_ALLOW_FULL

  scene = null
  sceneChanged = true
  owner = null

  updateSizesTimer = 0.0
  updateSizesDelay = 1.0

  curGroup = ""
  curPlayer = null
  curHoverObjId = null

  searchGroup = ::EPLX_SEARCH
  maxSearchPlayers = 20
  searchInProgress = false
  searchShowNotFound = false
  searchShowDefaultOnReset = false
  searchGroupLastShowState = false


  constructor(gui_scene, params = {})
  {
    base.constructor(gui_scene, params)
    ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)
    listNotPlayerChildsByGroup = {}
  }

  function initScreen(obj, resetList = true)
  {
    if (::checkObj(scene) && scene.isEqual(obj))
      return

    foreach(group in ::contacts_groups)
      ::contacts[group].sort(::sortContacts)

    sceneShow(false)
    scene = obj
    sceneChanged = true
    if (resetList)
      ::friend_prev_scenes <- []
    sceneShow(true)
    closeSearchGroup()
  }

  function isValid()
  {
    return true
  }

  function getControlsAllowMask()
  {
    if (!isContactsWindowActive() || !scene.isEnabled())
      return CtrlsInGui.CTRL_ALLOW_FULL
    return wndControlsAllowMask
  }

  function updateControlsAllowMask()
  {
    if (!::last_contacts_scene_show)
      return

    local mask = CtrlsInGui.CTRL_ALLOW_FULL
    if (curHoverObjId != null)
      if (::show_console_buttons)
        mask = CtrlsInGui.CTRL_ALLOW_VEHICLE_FULL & ~CtrlsInGui.CTRL_ALLOW_VEHICLE_XINPUT
      else if (curHoverObjId == "search_edit_box")
        mask = CtrlsInGui.CTRL_ALLOW_VEHICLE_FULL & ~CtrlsInGui.CTRL_ALLOW_VEHICLE_KEYBOARD

    switchControlsAllowMask(mask)
  }

  function switchScene(obj, newOwner = null, onlyShow = false)
  {
    if (!::checkObj(obj) || (::checkObj(scene) && scene.isEqual(obj)))
    {
      if (!onlyShow || !::last_contacts_scene_show)
        sceneShow()
    } else
    {
      ::contacts_prev_scenes.append({ scene = scene, show = ::last_contacts_scene_show, owner = owner })
      owner = newOwner
      initScreen(obj, false)
    }
  }

  function goBack()
  {
    sceneShow(false)
  }

  function checkScene()
  {
    if (::checkObj(scene))
      return true

    for(local i=::contacts_prev_scenes.len()-1; i>=0; i--)
    {
      let prevScene = ::contacts_prev_scenes[i].scene
      if (::checkObj(prevScene)) {
        let handler = ::contacts_prev_scenes[i].owner
        if (!handler.isSceneActiveNoModals() || !prevScene.isVisible())
          continue
        scene = ::contacts_prev_scenes[i].scene
        owner = handler
        guiScene = scene.getScene()
        sceneChanged = true
        sceneShow(::contacts_prev_scenes[i].show || ::last_contacts_scene_show)
        return true
      } else
        ::contacts_prev_scenes.remove(i)
    }
    scene = null
    return false
  }

  function sceneShow(show=null)
  {
    if (!checkScene())
      return

    let wasVisible = scene.isVisible()
    if (show==null)
      show = !wasVisible
    if (!show)
      loadSizes()

    scene.show(show)
    scene.enable(show)
    ::last_contacts_scene_show = show
    if (show)
    {
      validateCurGroup()
      if (!reloadSceneData())
      {
        setSavedSizes()
        fillContactsList()
        closeSearchGroup()
      }
      let cgObj = scene.findObject("contacts_groups")
      ::move_mouse_on_child(cgObj, cgObj.getValue())
    }

    updateControlsAllowMask()
  }

  function loadSizes()
  {
    if (isContactsWindowActive())
    {
      ::contacts_sizes = {}
      let obj = scene.findObject("contacts_wnd")
      ::contacts_sizes.pos <- obj.getPosRC()
      ::contacts_sizes.size <- obj.getSize()

      saveLocalByScreenSize("contacts_sizes", save_to_json(::contacts_sizes))
    }
  }

  function setSavedSizes()
  {
    if (!::contacts_sizes)
    {
      let data = loadLocalByScreenSize("contacts_sizes")
      if (data)
      {
        ::contacts_sizes = ::parse_json(data)
        if (!("pos" in ::contacts_sizes) || !("size" in ::contacts_sizes))
          ::contacts_sizes = null
        else
        {
          ::contacts_sizes.pos[0] = ::contacts_sizes.pos[0].tointeger()
          ::contacts_sizes.pos[1] = ::contacts_sizes.pos[1].tointeger()
          ::contacts_sizes.size[0] = ::contacts_sizes.size[0].tointeger()
          ::contacts_sizes.size[1] = ::contacts_sizes.size[1].tointeger()
        }
      }
    }

    if (isContactsWindowActive() && ::contacts_sizes)
    {
      let obj = scene.findObject("contacts_wnd")
      if (!obj) return

      let rootSize = guiScene.getRoot().getSize()
      for(local i=0; i<=1; i++) //pos chat in screen
        if (::contacts_sizes.pos[i] < topMenuBorders[i][0]*rootSize[i])
          ::contacts_sizes.pos[i] = (topMenuBorders[i][0]*rootSize[i]).tointeger()
        else
          if (::contacts_sizes.pos[i]+::contacts_sizes.size[i] > topMenuBorders[i][1]*rootSize[i])
            ::contacts_sizes.pos[i] = (topMenuBorders[i][1]*rootSize[i] - ::contacts_sizes.size[i]).tointeger()

      obj.pos = ::contacts_sizes.pos[0] + ", " + ::contacts_sizes.pos[1]
      obj.size = ::contacts_sizes.size[0] + ", " + ::contacts_sizes.size[1]
    }
  }

  function reloadSceneData()
  {
    if (!checkScene())
      return false

    if (!scene.findObject("contacts_wnd"))
    {
      sceneChanged = true
      guiScene = scene.getScene()
      guiScene.replaceContent(scene, "%gui/contacts/contacts.blk", this)
      setSavedSizes()
      scene.findObject("contacts_update").setUserData(this)
      fillContactsList()
      return true
    }
    return false
  }

  function onUpdate(obj, dt)
  {
    if (::last_contacts_scene_show)
    {
      updateSizesTimer -= dt
      if (updateSizesTimer <= 0)
      {
        updateSizesTimer = updateSizesDelay
        loadSizes()
      }
    }
  }

  function needRebuildPlayersList(gName, listObj)
  {
    if (gName == ::EPLX_SEARCH)
      return true //this group often refilled by other objects
    let count = ::contacts[gName].len() + ::getTblValue(gName, listNotPlayerChildsByGroup, -100000)
    return listObj.childrenCount() != count
  }

  needShowContactHoverButtons = @() !::show_console_buttons

  function buildPlayersList(gName, showOffline=true)
  {
    let playerListView = {
      playerListItem = []
      playerButton = []
      needHoverButtons = needShowContactHoverButtons()
    }
    listNotPlayerChildsByGroup[gName] <- 0
    if (gName != searchGroup) {
      playerListView.searchAdviceID <- $"group_{gName}_search_advice"
      playerListView.totalContacts <- ::loc("contacts/total", {
        contactsCount = ::contacts[gName].len(),
        contactsCountMax = ::EPL_MAX_PLAYERS_IN_LIST
      })
      listNotPlayerChildsByGroup[gName] = 2
    }
    foreach(idx, contactData in ::contacts[gName])
    {
      playerListView.playerListItem.append({
        blockID = "player_" + gName + "_" + idx
        contactUID = contactData.uid
        pilotIcon = contactData.pilotIcon
      })
    }
    if (gName == ::EPL_FRIENDLIST && ::isInMenu())
    {
      if (::has_feature("Invites"))
        playerListView.playerButton.append(createPlayerButtonView("btnInviteFriend", "#ui/gameuiskin#btn_invite_friend", "onInviteFriend"))
      if (isAvailableFacebook())
        playerListView.playerButton.append(createPlayerButtonView("btnFacebookFriendsAdd", "#ui/gameuiskin#btn_facebook_friends_add", "onFacebookFriendsAdd"))
    }

    listNotPlayerChildsByGroup[gName] = listNotPlayerChildsByGroup[gName] + playerListView.playerButton.len()
    return ::handyman.renderCached(("%gui/contacts/playerList"), playerListView)
  }

  function createPlayerButtonView(gId, gIcon, callback)
  {
    if (!gId || gId == "")
      return {}

    let shortName = ::loc("mainmenu/" + gId + "Short", "")
    return {
      name = shortName == "" ? "#mainmenu/" + gId : shortName
      tooltip = "#mainmenu/" + gId
      icon = gIcon
      callback = callback
    }
  }

  function updatePlayersList(gName)
  {
    local sel = -1
    let selUid = (curPlayer && curGroup==gName)? curPlayer.uid : ""

    let gObj = scene.findObject("contacts_groups")
    foreach(fIdx, f in ::contacts[gName])
    {
      let obj = gObj.findObject("player_" + gName + "_" + fIdx)
      if (!::check_obj(obj))
        continue

      let fullName = ::g_contacts.getPlayerFullName(f.getName(), f.clanTag)
      let contactNameObj = obj.findObject("contactName")
      contactNameObj.setValue(fullName)
      let contactPresenceObj = obj.findObject("contactPresence")
      if (::checkObj(contactPresenceObj))
      {
        contactPresenceObj.setValue(f.getPresenceText())
        contactPresenceObj["color-factor"] = f.presence.iconTransparency
      }
      obj.findObject("tooltip").uid = f.uid
      if (selUid == f.uid)
        sel = fIdx

      let imgObj = obj.findObject("statusImg")
      imgObj["background-image"] = f.presence.getIcon()
      imgObj["background-color"] = f.presence.getIconColor()

      obj.findObject("pilotIconImg").setValue(f.pilotIcon)
    }
    return sel
  }

  function fillPlayersList(gName)
  {
    let listObj = scene.findObject("contacts_groups").findObject("group_" + gName)
    if (!listObj)
      return

    if (needRebuildPlayersList(gName, listObj))
    {
      let data = buildPlayersList(gName)
      guiScene.replaceContentFromText(listObj, data, data.len(), this)
    }
    updateContactButtonsForGroup(gName)
    applyContactFilter()
    return updatePlayersList(gName)
  }

  function updateContactButtonsForGroup(gName)
  {
    foreach (idx, contact in ::contacts[gName])
    {
      let contactObject = scene.findObject(::format("player_%s_%s", gName.tostring(), idx.tostring()))
      contactObject.contact_buttons_contact_uid = contact.uid

      let contactButtonsHolder = contactObject.findObject("contact_buttons_holder")
      if (!::check_obj(contactButtonsHolder))
        continue

      updateContactButtonsVisibility(contact, contactButtonsHolder)
    }
  }

  function updateContactButtonsVisibility(contact, contact_buttons_holder)
  {
    if (!checkScene())
      return

    let isFriend = contact? contact.isInFriendGroup() : false
    let isBlock = contact? contact.isInBlockGroup() : false
    let isMe = contact? contact.isMe() : false
    let contactName = contact?.name ?? ""

    let isPlayerFromXboxOne = platformModule.isPlayerFromXboxOne(contactName)
    let canBlock = !isPlayerFromXboxOne
    let canChat = contact? contact.canChat() : true
    let canInvite = contact? contact.canInvite() : true
    let canInteractCrossConsole = platformModule.canInteractCrossConsole(contactName)
    let canInteractCrossPlatform = crossplayModule.isCrossPlayEnabled()
                                     || platformModule.isPlayerFromPS4(contactName)
                                     || isPlayerFromXboxOne

    showBtn("btn_friendAdd", !isMe && !isFriend && !isBlock && canInteractCrossConsole, contact_buttons_holder)
    showBtn("btn_friendRemove", isFriend, contact_buttons_holder)
    showBtn("btn_blacklistAdd", !isMe && !isFriend && !isBlock && canBlock, contact_buttons_holder)
    showBtn("btn_blacklistRemove", isBlock && canBlock, contact_buttons_holder)
    showBtn("btn_message", owner
                           && !isBlock
                           && isChatEnabled()
                           && canChat, contact_buttons_holder)

    let showSquadInvite = ::has_feature("SquadInviteIngame")
      && !isMe
      && !isBlock
      && canInteractCrossConsole
      && canInteractCrossPlatform
      && ::g_squad_manager.canInviteMember(contact?.uid ?? "")
      && ::g_squad_manager.canInviteMemberByPlatform(contactName)
      && !::g_squad_manager.isPlayerInvited(contact?.uid ?? "", contactName)
      && canInvite
      && ::g_squad_utils.canSquad()

    let btnObj = showBtn("btn_squadInvite", showSquadInvite, contact_buttons_holder)
    if (btnObj && showSquadInvite && contact?.uidInt64)
      updateButtonInviteText(btnObj, contact.uidInt64)

    showBtn("btn_usercard", ::has_feature("UserCards"), contact_buttons_holder)
    showBtn("btn_facebookFriends", isAvailableFacebook() && !platformModule.isPlatformSony, contact_buttons_holder)
    showBtn("btn_squadInvite_bottom", false, contact_buttons_holder)
  }

  searchGroupActiveTextInclude = @"
    id:t='search_group_active_text';
    Button_close {
      id:t='close_search_group';
      on_click:t='onCloseSearchGroupClicked';
      smallIcon:t='yes'
    }"

  groupFormat = @"group {
    groupHeader {
      canBeClosed:t='yes';
      text:t='%s';
      %s
    }
    groupList {
      id:t='%s';
      %s
      on_select:t='onPlayerSelect';
      on_dbl_click:t='%s';
      on_cancel_edit:t='onPlayerCancel';
      on_hover:t='onContactsFocus';
      on_unhover:t='onContactsFocus';
      contacts_group_list:t='yes';
    }
  }"

  function getIndexOfGroup(group_name)
  {
    let contactsGroups = scene.findObject("contacts_groups")
    for (local idx = contactsGroups.childrenCount() - 1; idx >= 0; --idx)
    {
      let childObject = contactsGroups.getChild(idx)
      let groupListObject = childObject.getChild(childObject.childrenCount() - 1)
      if (groupListObject?.id == "group_" + group_name)
      {
        return idx
      }
    }
    return -1
  }

  function getGroupByName(group_name)
  {
    let contactsGroups = scene.findObject("contacts_groups")
    if (::checkObj(contactsGroups))
    {
      let groupListObject = contactsGroups.findObject("group_" + group_name)
      return groupListObject.getParent()
    }
    return null
  }

  function setSearchGroupVisibility(value)
  {
    local groupObject = getGroupByName(searchGroup)
    groupObject.show(value)
    groupObject.enable(value)
    searchGroupLastShowState = value
  }

  function onSearchEditBoxActivate(obj)
  {
    doSearch(obj)
  }

  function doSearch(editboxObj = null)
  {
    if (!editboxObj)
      editboxObj = scene.findObject("search_edit_box")
    if (!::check_obj(editboxObj))
      return

    local txt = clearBorderSymbols(editboxObj.getValue())
    txt = platformModule.cutPlayerNamePrefix(platformModule.cutPlayerNamePostfix(txt))
    if (txt == "")
      return

    let contactsGroups = scene.findObject("contacts_groups")
    if (::checkObj(contactsGroups))
    {
      let searchGroupIndex = getIndexOfGroup(searchGroup)
      if (searchGroupIndex != -1)
      {
        setSearchGroupVisibility(true)
        contactsGroups.setValue(searchGroupIndex)
        onSearch(null)
      }
    }
  }

  function onSearchEditBoxCancelEdit(obj)
  {
    if (curGroup == searchGroup)
    {
      closeSearchGroup()
      return
    }

    if (obj.getValue() == "")
      goBack()
    else
      obj.setValue("")
  }

  function onSearchEditBoxChangeValue(obj)
  {
    setSearchText(platformModule.getPlayerName(obj.getValue()), false)
    applyContactFilter()
  }

  function onContactsFocus(obj)
  {
    let isValidCurScene = ::check_obj(scene)
    if (!isValidCurScene) {
      curHoverObjId = null
      return
    }
    let newObjId = obj.isHovered() ? obj.id : null
    if (curHoverObjId == newObjId)
      return
    curHoverObjId = newObjId
    updateControlsAllowMask()
    updateConsoleButtons()
    setSearchAdviceVisibility(!::show_console_buttons && curHoverObjId == "search_edit_box")
  }

  function setSearchText(search_text, set_in_edit_box = true)
  {
    searchText = ::g_string.utf8ToLower(search_text)
    if (set_in_edit_box)
    {
      let searchEditBox = scene.findObject("search_edit_box")
      if (::checkObj(searchEditBox))
      {
        searchEditBox.setValue(search_text)
      }
    }
  }

  function applyContactFilter()
  {
    if (curGroup == ""
        || curGroup == searchGroup
        || !(curGroup in ::contacts))
      return

    foreach (idx, contact_data in ::contacts[curGroup])
    {
      let contactObjectName = "player_" + curGroup + "_" + idx
      let contactObject = scene.findObject(contactObjectName)
      if (!::checkObj(contactObject))
        continue

      local contactName = ::g_string.utf8ToLower(contact_data.name)
      contactName = platformModule.getPlayerName(contactName)
      let searchResult = searchText == "" || contactName.indexof(searchText) != null
      contactObject.show(searchResult)
      contactObject.enable(searchResult)
    }
  }

  function fillContactsList()
  {
    if (!checkScene())
      return

    let gObj = scene.findObject("contacts_groups")
    if (!gObj) return
    guiScene.setUpdatesEnabled(false, false)

    local data = ""
    let groups_array = getContactsGroups()
    foreach(gIdx, gName in groups_array)
    {
      ::contacts[gName].sort(::sortContacts)
      local activateEvent = "onPlayerMsg"
      if (::show_console_buttons || !isChatEnabled())
        activateEvent = "onPlayerMenu"
      let gData = buildPlayersList(gName)
      data += format(groupFormat, "#contacts/" + gName,
        gName == searchGroup ? searchGroupActiveTextInclude : "",
        "group_" + gName, gData, activateEvent)
    }
    guiScene.replaceContentFromText(gObj, data, data.len(), this)
    foreach (gName in groups_array)
    {
      updateContactButtonsForGroup(gName)
      if (gName == searchGroup)
        setSearchGroupVisibility(searchGroupLastShowState)
    }

    applyContactFilter()

    let selected = [-1, -1]
    foreach(gIdx, gName in groups_array)
    {
      if (gName == searchGroup && !searchGroupLastShowState)
        continue

      if (selected[0] < 0)
        selected[0] = gIdx

      if (curGroup == gName)
        selected[0] = gIdx

      let sel = updatePlayersList(gName)
      if (sel > 0)
        selected[1] = sel
    }

    if (::contacts[groups_array[selected[0]]].len() > 0)
      gObj.findObject("group_" + groups_array[selected[0]]).setValue(
              (selected[1]>=0)? selected[1] : 0)

    guiScene.setUpdatesEnabled(true, true)

    gObj.setValue(selected[0])
    onGroupSelectImpl(gObj)
  }

  function updateContactsGroup(groupName)
  {
    if (!isContactsWindowActive())
      return

    if (groupName && !(groupName in ::contacts))
    {
      if (curGroup == groupName)
        curGroup = ""

      fillContactsList()
      if (searchText == "")
        closeSearchGroup()
      return
    }

    local sel = 0
    if (groupName && groupName in ::contacts)
    {
      ::contacts[groupName].sort(::sortContacts)
      sel = fillPlayersList(groupName)
    }
    else
      foreach(group in getContactsGroups())
        if (group in ::contacts)
        {
          ::contacts[group].sort(::sortContacts)
          let selected = fillPlayersList(group)
          if (group == curGroup)
            sel = selected
        }

    if (curGroup && (!groupName || curGroup == groupName))
    {
      let gObj = scene.findObject("contacts_groups")
      let listObj = gObj.findObject("group_" + curGroup)
      if (listObj)
      {
        if (::contacts[curGroup].len() > 0)
          listObj.setValue(sel>0? sel : 0)
        onPlayerSelect(listObj)
      }
    }
  }

  function onEventContactsGroupUpdate(params)
  {
    updateContactsGroup(params?.groupName)
  }

  function onEventModalWndDestroy(params)
  {
    checkScene()
  }

  function selectCurContactGroup() {
    if (!checkScene())
      return
    let groupsObj = scene.findObject("contacts_groups")
    let value = groupsObj.getValue()
    if (value >= 0 && value < groupsObj.childrenCount())
      ::move_mouse_on_child(groupsObj.getChild(value), 0) //header
  }

  function onGroupSelectImpl(obj)
  {
    selectItemInGroup(obj, false)
    applyContactFilter()
  }

  prevGroup = -1
  function onGroupSelect(obj)
  {
    onGroupSelectImpl(obj)
    if (!::is_mouse_last_time_used() && prevGroup != obj.getValue()) {
      guiScene.applyPendingChanges(false)
      selectCurContactGroup()
    }
    prevGroup = obj.getValue()
  }

  function selectHoveredGroup() {
    let listObj = scene.findObject("contacts_groups")
    let total = listObj.childrenCount()
    for(local i = 0; i < total; i++) {
      let child = listObj.getChild(i)
      if (!child.isValid() || !child.isHovered())
        continue
      listObj.setValue(i)
      onGroupActivate(listObj)
      return
    }
  }

  function onGroupActivate(obj)
  {
    selectItemInGroup(obj, true)
    applyContactFilter()
  }

  function onGroupCancel(obj)
  {
    goBack()
  }

  onPlayerCancel = @(obj) ::is_mouse_last_time_used() ? goBack() : selectCurContactGroup()

  function onSearchButtonClick(obj)
  {
    doSearch()
  }

  function onBtnSelect(obj)
  {
    if (!checkScene())
      return

    if (curHoverObjId == "contacts_groups")
      selectHoveredGroup()
    else if (curHoverObjId == "search_edit_box")
      doSearch()
    else
    {
      let groupObj = scene.findObject("group_" + curGroup)
      if (groupObj?.isValid())
        onPlayerMenu(groupObj)
    }
  }

  function selectItemInGroup(obj, switchFocus = false)
  {
    let groups = getContactsGroups()
    let value = obj.getValue()
    if (!(value in groups))
      return

    curGroup = groups[value]

    let listObj = obj.findObject("group_" + curGroup)
    if (!::checkObj(listObj))
      return

    if (::contacts[curGroup].len() == 0)
      return

    if (listObj.getValue()<0 && ::contacts[curGroup].len() > 0)
      listObj.setValue(0)

    onPlayerSelect(listObj)
    showSceneBtn("button_invite_friend", curGroup == ::EPL_FRIENDLIST)

    if (switchFocus)
      ::move_mouse_on_child(listObj, listObj.getValue())
  }

  function onPlayerSelect(obj)
  {
    if (!obj) return

    let value = obj.getValue()
    if ((curGroup in ::contacts) && (value in ::contacts[curGroup]))
      curPlayer = ::contacts[curGroup][value]
    else
      curPlayer = null
  }

  function onPlayerMenu(obj)
  {
    let value = obj.getValue()
    if (value < 0 || value >= obj.childrenCount())
      return

    let childObj = obj.getChild(value)
    if (!::check_obj(childObj))
      return

    if (childObj?.contact_buttons_contact_uid)
      showCurPlayerRClickMenu(childObj.getPosRC())
    else if (childObj?.isButton == "yes")
      sendClickButton(childObj)
  }

  function sendClickButton(obj)
  {
    let clickName = obj?.on_click
    if (!clickName || !(clickName in this))
      return

    this[clickName]()
  }

  function onPlayerRClick(obj)
  {
    if (!checkScene() || !::check_obj(obj))
      return

    let id = obj.id
    let prefix = "player_" + curGroup + "_"
    if (id.len() <= prefix.len() || id.slice(0, prefix.len()) != prefix)
      return

    let idx = id.slice(prefix.len()).tointeger()
    if ((curGroup in ::contacts) && (idx in ::contacts[curGroup]))
    {
      let listObj = scene.findObject("group_" + curGroup)
      if (!listObj)
        return

      listObj.setValue(idx)
      showCurPlayerRClickMenu()
    }
  }

  function onCloseSearchGroupClicked(obj)
  {
    closeSearchGroup()
  }

  function closeSearchGroup()
  {
    if (!checkScene())
      return

    let contactsGroups = scene.findObject("contacts_groups")
    if (::checkObj(contactsGroups))
    {
      setSearchGroupVisibility(false)
      let searchGroupIndex = getIndexOfGroup(searchGroup)
      if (contactsGroups.getValue() == searchGroupIndex)
      {
        setSearchText("")
        let friendsGroupIndex = getIndexOfGroup(::EPL_FRIENDLIST)
        contactsGroups.setValue(friendsGroupIndex)
      }
    }
    applyContactFilter()
  }

  function setSearchAdviceVisibility(value)
  {
    foreach (idx, groupName in getContactsGroups())
    {
      let searchAdviceID = "group_" + groupName + "_search_advice"
      let searchAdviceObject = scene.findObject(searchAdviceID)
      if (::checkObj(searchAdviceObject))
      {
        searchAdviceObject.show(value)
        searchAdviceObject.enable(value)
      }
    }
  }

  function showCurPlayerRClickMenu(position = null)
  {
    playerContextMenu.showMenu(curPlayer, this,
      {
        position = position
        curContactGroup = curGroup
        onClose = function() {
          if (checkScene())
            ::move_mouse_on_child_by_value(scene.findObject("group_" + curGroup))
        }.bindenv(this)
      })
  }

  function isContactsWindowActive()
  {
    return checkScene() && ::last_contacts_scene_show;
  }

  function updateButtonInviteText(btnObj, uid)
  {
    btnObj.tooltip = ::g_squad_manager.hasApplicationInMySquad(uid)
        ? ::loc("squad/accept_membership")
        : ::loc("squad/invite_player")
  }

  function updateConsoleButtons()
  {
    if (!checkScene())
      return

    showSceneBtn("contacts_buttons_console", ::show_console_buttons)
    if (!::show_console_buttons)
      return

    let showSelectButton = curHoverObjId != null
    let btn = showSceneBtn("btn_contactsSelect", showSelectButton)
    if (showSelectButton)
      btn.setValue(::loc(curHoverObjId == "contacts_groups" ? "contacts/chooseGroup"
        : curHoverObjId == "search_edit_box" ? "contacts/search"
        : "contacts/choosePlayer"))
  }

  function onFacebookFriendsAdd()
  {
    onFacebookLoginAndAddFriends()
  }

  function editPlayerInList(obj, listName, add)
  {
    updateCurPlayer(obj)
    ::editContactMsgBox(curPlayer, listName, add)
  }

  function updateCurPlayer(button_object)
  {
    if (!::checkObj(button_object))
      return

    let contactButtonsObject = button_object.getParent().getParent()
    let contactUID = contactButtonsObject?.contact_buttons_contact_uid
    if (!contactUID)
      return

    let contact = ::getContact(contactUID)
    curPlayer = contact

    let idx = ::contacts[curGroup].indexof(contact)
    if (!checkScene() || idx == null)
      return

    let groupObject = scene.findObject("contacts_groups")
    let listObject = groupObject.findObject("group_" + curGroup)
    listObject.setValue(idx)
  }

  function onFriendAdd(obj)
  {
    editPlayerInList(obj, ::EPL_FRIENDLIST, true)
  }

  function onFriendRemove(obj)
  {
    editPlayerInList(obj, ::EPL_FRIENDLIST, false)
  }

  function onBlacklistAdd(obj)
  {
    editPlayerInList(obj, ::EPL_BLOCKLIST, true)
  }

  function onBlacklistRemove(obj)
  {
    editPlayerInList(obj, ::EPL_BLOCKLIST, false)
  }

  function onPlayerMsg(obj)
  {
    updateCurPlayer(obj)
    if (!curPlayer || !owner)
      return

    ::openChatPrivate(curPlayer.name, owner)
  }

  function onSquadInvite(obj)
  {
    updateCurPlayer(obj)

    if (curPlayer == null)
      return ::g_popups.add("", ::loc("msgbox/noChosenPlayer"))

    let uid = curPlayer.uid
    if (!::g_squad_manager.canInviteMember(uid))
      return

    let name = curPlayer.name
    if (::g_squad_manager.hasApplicationInMySquad(uid.tointeger(), name))
      ::g_squad_manager.acceptMembershipAplication(uid.tointeger())
    else
      ::g_squad_manager.inviteToSquad(uid, name)
  }

  function onUsercard(obj)
  {
    updateCurPlayer(obj)
    if (curPlayer)
      ::gui_modal_userCard(curPlayer)
  }

  function onCancelSearchEdit(obj)
  {
    if (!obj) return

    let value = obj.getValue()
    if (!value || value=="")
    {
      if (::show_console_buttons)
        onPlayerCancel(obj)
      else
        goBack()
    } else
    {
      obj.setValue("")
      if (searchShowDefaultOnReset)
      {
        fillDefaultSearchList()
        updateSearchList()
      }
    }
    searchShowNotFound = false
  }

  function getSearchObj()
  {
    return checkScene() ? scene.findObject("search_edit_box") : null
  }

  function onSearch(obj)
  {
    let sObj = getSearchObj()
    if (!sObj || searchInProgress) return
    local value = sObj.getValue()
    if (!value || value == "*")
      return
    if (::is_chat_message_empty(value))
    {
      if (searchShowDefaultOnReset)
      {
        fillDefaultSearchList()
        updateSearchList()
      }
      return
    }

    value = clearBorderSymbols(value)

    let searchGroupActiveTextObject = scene.findObject("search_group_active_text")
    let searchGroupText = ::loc($"contacts/{searchGroup}")
    searchGroupActiveTextObject.setValue($"{searchGroupText}: {value}")

    let taskId = ::find_nicks_by_prefix(value, maxSearchPlayers, true)
    if (taskId >= 0)
    {
      searchInProgress = true
      ::contacts[searchGroup] <- []
      updateSearchList()
    }
    ::g_tasker.addTask(taskId, null, ::Callback(onSearchCb, this))
  }

  function onSearchCb()
  {
    searchInProgress = false

    local searchRes = ::DataBlock()
    searchRes = ::get_nicks_find_result_blk()
    ::contacts[searchGroup] <- []

    local brokenData = false
    for (local i = 0; i < searchRes.paramCount(); i++)
    {
      let contact = ::getContact(searchRes.getParamName(i), searchRes.getParamValue(i))
      if (contact)
      {
        if (!contact.isMe() && !contact.isInFriendGroup() && platformModule.isPs4XboxOneInteractionAvailable(contact.name))
          ::contacts[searchGroup].append(contact)
      }
      else
        brokenData = true
    }

    if (brokenData)
    {
      let errText = "broken result on find_nicks_by_prefix cb: \n" + ::toString(searchRes)
      ::script_net_assert_once("broken searchCb data", errText)
    }

    updateSearchList()
    if (::show_console_buttons && curGroup == searchGroup && !::is_mouse_last_time_used() && checkScene())
      ::move_mouse_on_child_by_value(scene.findObject("group_" + searchGroup))
  }

  function updateSearchList()
  {
    if (!checkScene())
      return

    let gObj = scene.findObject("contacts_groups")
    let listObj = gObj.findObject("group_" + searchGroup)
    if (!listObj)
      return

    guiScene.setUpdatesEnabled(false, false)
    local sel = -1
    if (::contacts[searchGroup].len() > 0)
      sel = fillPlayersList(searchGroup)
    else
    {
      local data = ""
      if (searchInProgress)
        data = "animated_wait_icon { pos:t='0.5(pw-w),0.03sh'; position:t='absolute'; background-rotation:t='0' }"
      else if (searchShowNotFound)
        data = "textAreaCentered { text:t='#contacts/searchNotFound'; enable:t='no' }"
      else
      {
        fillDefaultSearchList()
        sel = fillPlayersList(searchGroup)
        data = null
      }

      if (data)
      {
        guiScene.replaceContentFromText(listObj, data, data.len(), this)
        searchShowNotFound = true
      }
    }
    guiScene.setUpdatesEnabled(true, true)

    if (curGroup == searchGroup)
    {
      if (::contacts[searchGroup].len() > 0)
        listObj.setValue(sel>0? sel : 0)
      onPlayerSelect(listObj)
    }
  }

  function fillDefaultSearchList()
  {
    ::contacts[searchGroup] <- []
  }

  function onInviteFriend()
  {
    showViralAcquisitionWnd()
  }

  function onEventContactsUpdated(params)
  {
    updateContactsGroup(null)
  }

  function onEventSquadStatusChanged(p)
  {
    updateContactsGroup(null)
  }

  function validateCurGroup()
  {
    if (!(curGroup in ::contacts))
      curGroup = ""
  }

  function onEventActiveHandlersChanged(p)
  {
    checkActiveScene()
  }

  function checkActiveScene()
  {
    if (!::checkObj(scene) || owner == null) {
      checkScene()
      return
    }

    if (owner.isSceneActiveNoModals() || scene?.isVisible())
      return

    let curScene = scene
    if (::contacts_prev_scenes.findvalue(@(v) curScene.isEqual(v.scene)) == null)
      ::contacts_prev_scenes.append({ scene = scene, show = ::last_contacts_scene_show, owner = owner })
    scene = null
    return
  }

  function onEventContactsCleared(p) {
    validateCurGroup()
  }

  getContactsGroups = @() ::contacts_groups
}
