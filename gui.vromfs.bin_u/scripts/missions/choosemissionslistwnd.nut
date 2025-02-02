/*
 API:
 static open(config)
   config:
     headerText - window header text
     missionsList (required) - array of missions generated by misListType
     selMissions - list of selected missions
     onApplyListCb - callbacks on missions list apply
                     called only if list was changed
*/

::gui_handlers.ChooseMissionsListWnd <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName   = "%gui/missions/chooseMissionsListWnd.blk"

  headerText = ""
  missionsList = null
  selMissions = null
  onApplyListCb = null
  choosenIcon = "#ui/gameuiskin#favorite"

  misListObj = null
  selMissionsMap = null  //{ missionName = (bool)isSelected }
  initialSelMissionsMap = null
  missionDescWeak = null
  curMission = null

  static function open(config)
  {
    let misList = ::getTblValue("missionsList", config)
    if (!::u.isArray(misList) || !misList.len())
    {
      ::script_net_assert_once(" bad_missions_list",
        "Bad missions list to choose: " + ::toString(misList))
      return
    }
    ::handlersManager.loadHandler(::gui_handlers.ChooseMissionsListWnd, config)
  }

  function initScreen()
  {
    misListObj = scene.findObject("items_list")
    scene.findObject("wnd_title").setValue(headerText)

    selMissionsMap = selMissionsToMap(missionsList, selMissions)
    initialSelMissionsMap = clone selMissionsMap
    initDescHandler()
    fillMissionsList()

    ::move_mouse_on_child_by_value(scene.findObject("items_list"))
  }

  function initDescHandler()
  {
    let descHandler = ::gui_handlers.MissionDescription.create(getObj("mission_desc"), curMission)
    registerSubHandler(descHandler)
    missionDescWeak = descHandler.weakref()
  }

  function selMissionsToMap(fullList, selList)
  {
    let res = {}
    foreach(mission in fullList)
      res[mission.id] <- false
    foreach(mission in selList)
      res[mission.id] <- true
    return res
  }

  function mapToSelectedMissions(fullList, misMap)
  {
    let res = []
    foreach(mission in fullList)
      if (::getTblValue(mission.id, misMap, false))
        res.append(mission)
    return res
  }

  function isMissionSelected(mission)
  {
    return ::getTblValue(mission.id, selMissionsMap, false)
  }

  function isAllMissionsSelected()
  {
    foreach(value in selMissionsMap)
      if (!value)
        return false
    return true
  }

  function fillMissionsList()
  {
    let view = { items = [] }
    foreach(mission in missionsList)
      view.items.append({
        id = mission.id
        itemText = mission.getNameText()
        checkBoxActionName = "onMissionCheckBox"
        isChosen = isMissionSelected(mission) ? "yes" : "no"
      })

    let data = ::handyman.renderCached("%gui/missions/missionBoxItemsList", view)
    guiScene.replaceContentFromText(misListObj, data, data.len(), this)
    misListObj.setValue(0)
  }

  function updateButtons()
  {
    let chooseBtn = showSceneBtn("btn_choose", !!curMission)
    if (curMission)
      chooseBtn.setValue(isMissionSelected(curMission) ? ::loc("misList/unselectMission") : ::loc("misList/selectMission"))

    let chooseAllText = isAllMissionsSelected() ? ::loc("misList/unselectAll") : ::loc("misList/selectAll")
    scene.findObject("btn_choose_all").setValue(chooseAllText)
  }

  function markSelected(mission, isSelected)
  {
    if (isSelected == isMissionSelected(mission))
      return

    selMissionsMap[mission.id] <- isSelected
    let checkBoxObj = misListObj.findObject("checkbox_" + mission.id)
    if (::check_obj(checkBoxObj) && checkBoxObj.getValue() != isSelected)
      checkBoxObj.setValue(isSelected)
  }

  function onMissionSelect(obj)
  {
    let mission = ::getTblValue(obj.getValue(), missionsList)
    if (mission == curMission)
      return

    curMission = mission
    if (missionDescWeak)
      missionDescWeak.setMission(curMission)
    updateButtons()
  }

  function onChooseMission()
  {
    if (!curMission)
      return

    markSelected(curMission, !isMissionSelected(curMission))
    updateButtons()
  }

  function onChooseAll()
  {
    let needSelect = !isAllMissionsSelected()
    foreach(mission in missionsList)
      markSelected(mission, needSelect)
    updateButtons()
  }

  function onMissionCheckBox(obj)
  {
    let id = ::getObjIdByPrefix(obj, "checkbox_")
    if (!id)
      return

    if (!curMission || curMission.id != id)
    {
      let idx = missionsList.findindex(@(m) m.id == id)
      if (idx == null)
        return

      misListObj.setValue(idx)
    }

    let value = obj.getValue()
    if (isMissionSelected(curMission) != obj.getValue())
    {
      markSelected(curMission, value)
      updateButtons()
    }
  }

  function afterModalDestroy()
  {
    if (onApplyListCb && !::u.isEqual(selMissionsMap, initialSelMissionsMap))
      onApplyListCb(mapToSelectedMissions(missionsList, selMissionsMap))
  }
}
