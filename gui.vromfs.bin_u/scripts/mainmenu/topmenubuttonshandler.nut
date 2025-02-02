let bhvUnseen = require("%scripts/seen/bhvUnseen.nut")
let { getButtonConfigById } = require("%scripts/mainmenu/topMenuButtons.nut")

::gui_handlers.TopMenuButtonsHandler <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = null
  sceneTplName = "%gui/mainmenu/topmenu_menuPanel"

  parentHandlerWeak = null
  sectionsStructure = null
  objForWidth = null

  GCDropdownsList = null

  maxSectionsCount = 0
  sectionsOrder = null

  ON_ESC_SECTION_OPEN = "menu"

  static function create(nestObj, parentHandler, sectionsStructure, objForWidth = null)
  {
    if (!::g_login.isLoggedIn())
      return null

    if (!::check_obj(nestObj))
      return null

    let handler = ::handlersManager.loadHandler(::gui_handlers.TopMenuButtonsHandler, {
                                           scene = nestObj
                                           parentHandlerWeak = parentHandler,
                                           sectionsStructure = sectionsStructure,
                                           objForWidth = objForWidth
                                        })
    return handler? handler.weakref() : null
  }

  function getSceneTplView()
  {
    GCDropdownsList = []
    return {
      section = getSectionsView()
    }
  }

  function initScreen()
  {
    if (parentHandlerWeak)
      parentHandlerWeak = parentHandlerWeak.weakref()

    scene.show(true)
    updateButtonsStatus()
  }

  function getMaxSectionsCount()
  {
    if (!::has_feature("SeparateTopMenuButtons"))
      return 1

    if (!::check_obj(objForWidth))
      objForWidth = scene
    if (!::check_obj(objForWidth))
      return 1

    let freeWidth = objForWidth.getSize()[0]
    let singleButtonMinWidth = guiScene.calcString("1@topMenuButtonWidth", null) || 1
    return ::max(freeWidth / singleButtonMinWidth, 1)
  }

  function initSectionsOrder()
  {
    if (sectionsOrder)
      return

    maxSectionsCount = getMaxSectionsCount()
    sectionsOrder = ::g_top_menu_sections.getSectionsOrder(sectionsStructure, maxSectionsCount)
  }

  function getSectionsView()
  {
    if (!::check_obj(scene))
      return {}

    initSectionsOrder()

    let sectionsView = []
    foreach (topMenuButtonIndex, sectionData in sectionsOrder)
    {
      let columnsCount = sectionData.buttons.len()
      let columns = []

      foreach (idx, column in sectionData.buttons)
      {
        columns.append({
          buttons = column
          addNewLine = idx != (columnsCount - 1)
          columnIndex = (idx+1)
        })
      }

      let tmId = sectionData.getTopMenuButtonDivId()
      ::u.appendOnce(tmId, GCDropdownsList)

      sectionsView.append({
        tmId = tmId
        haveTmDiscount = sectionData.haveTmDiscount
        tmDiscountId = sectionData.getTopMenuDiscountId()
        visualStyle = sectionData.visualStyle
        tmText = sectionData.getText(maxSectionsCount)
        tmImage = sectionData.getImage(maxSectionsCount)
        tmWinkImage = sectionData.getWinkImage()
        tmHoverMenuPos = sectionData.hoverMenuPos
        tmOnClick = sectionData.onClick
        forceHoverWidth = sectionData.forceHoverWidth
        isWide = sectionData.isWide
        columnsCount = columnsCount
        columns = columns
        btnName = sectionData.btnName
        isLast = topMenuButtonIndex == sectionsOrder.len() - 1
        unseenIconMainButton = getSectionUnseenIcon(columns)
      })
    }
    return sectionsView
  }

  function getSectionUnseenIcon(columns)
  {
    let unseenList = []
    foreach (column in columns)
      foreach (button in column.buttons)
      if (!button.isHidden() && !button.isVisualDisabled())
      {
        let unseenIcon = button.unseenIcon?()
        if (unseenIcon)
          unseenList.append(unseenIcon)
      }

    return unseenList.len() ? bhvUnseen.makeConfigStrByList(unseenList) : null
  }

  function onHoverSizeMove(obj)
  {
    if(obj?["class"] != "dropDown")
      obj = obj.getParent()

    let hover = obj.findObject(obj.id+"_list_hover")
    if (::check_obj(hover)) {
      let menu = obj.findObject(obj.id+"_focus")
      menu.getScene().applyPendingChanges(true)
      hover["height-end"] = menu.getSize()[1] + guiScene.calcString("@dropDownMenuBottomActivityGap", null)
    }

    base.onHoverSizeMove(obj);
  }

  function updateButtonsStatus()
  {
    let needHideVisDisabled = ::has_feature("HideDisabledTopMenuActions")
    let isInQueue = ::checkIsInQueue()
    let skipNavigation = parentHandlerWeak?.scene
      .findObject("gamercard_div")["gamercardSkipNavigation"] == "yes"

    foreach (idx, section in sectionsOrder)
    {
      let sectionId = section.getTopMenuButtonDivId()
      let sectionObj = scene.findObject(sectionId)
      if (!::check_obj(sectionObj))
        continue

      local isVisibleAnyButton = false
      foreach (column in section.buttons)
      {
        foreach (button in column)
        {
          let btnObj = sectionObj.findObject(button.id)
          if (!::checkObj(btnObj))
            continue

          local isVisualDisable = button.isVisualDisabled()
          local show = !button.isHidden(parentHandlerWeak)
          if (show && isVisualDisable)
            show = !needHideVisDisabled

          btnObj.show(show)
          btnObj.enable(show)
          isVisibleAnyButton = isVisibleAnyButton || show

          if (!show)
            continue

          isVisualDisable = isVisualDisable || (button.isInactiveInQueue && isInQueue)
          btnObj.inactiveColor = isVisualDisable? "yes" : "no"
          btnObj.tooltip = button.tooltip()
        }
      }

      if (skipNavigation)
      {
        sectionObj["skip-navigation"] = "yes"
        sectionObj.findObject($"{sectionObj.id}_btn")["skip-navigation"] = "yes"
      }

      sectionObj.show(isVisibleAnyButton)
      sectionObj.enable(isVisibleAnyButton)
    }
  }

  function hideHoverMenu(name)
  {
    let obj = getObj(name)
    if (!::check_obj(obj))
      return

    obj["_size-timer"] = "0"
    obj.setFloatProp(::dagui_propid.add_name_id("_size-timer"), 0.0)
    obj.height = "0"
  }

  function onClick(obj)
  {
    if (!::handlersManager.isHandlerValid(parentHandlerWeak))
      return

    let btn = getButtonConfigById(obj.id)
    if (btn.isDelayed)
      guiScene.performDelayed(this, function()
      {
        if (isValid())
          btn.onClickFunc(null, parentHandlerWeak)
      })
    else
      btn.onClickFunc(obj, parentHandlerWeak)
  }

  function onChangeCheckboxValue(obj)
  {
    let btn = getButtonConfigById(obj.id)
    btn.onChangeValueFunc(obj.getValue())
  }

  function switchMenuFocus()
  {
    let section = sectionsStructure.getSectionByName(ON_ESC_SECTION_OPEN)
    if (::u.isEmpty(section))
      return

    if (::show_console_buttons && section.mergeIndex >= -1)
    {
      scene.findObject("top_menu_panel_place").setValue(section.mergeIndex)
      return
    }

    let buttonObj = scene.findObject(section.getTopMenuButtonDivId())
    if (::checkObj(buttonObj))
      this[section.onClick](buttonObj)
  }

  function topmenuMenuActivate(obj)
  {
    let curVal = obj.getValue()
    if (curVal < 0)
      return

    let selObj = obj.getChild(curVal)
    if (!::checkObj(selObj))
      return
    let eventName = selObj?._on_click ?? selObj?.on_click ?? selObj?.on_change_value
    if (!eventName || !(eventName in this))
      return

    if (selObj?.on_change_value)
      selObj.setValue(!selObj.getValue())

    unstickLastDropDown()
    this[eventName](selObj)
  }

  function stickLeftDropDown(obj)  { moveDropDownFocus(obj, -1) }
  function stickRightDropDown(obj) { moveDropDownFocus(obj, 1)  }

  function moveDropDownFocus(obj, direction)
  {
    forceCloseDropDown(obj)

    local mergeIdx = -1
    foreach (idx, section in sectionsOrder)
      if (obj.sectionId == section.getTopMenuButtonDivId())
        mergeIdx = idx

    mergeIdx += direction
    if (mergeIdx < 0 || mergeIdx >= sectionsOrder.len())
    {
      ::set_dirpad_event_processed(false)
      return
    }

    let panelObj = scene.findObject("top_menu_panel_place")
    onGCDropdown(panelObj.getChild(mergeIdx))
    panelObj.setValue(mergeIdx)
  }

  function onEventGameModesAvailability(p)
  {
    doWhenActiveOnce("updateButtonsStatus")
  }

  function onEventQueueChangeState(p)
  {
    doWhenActiveOnce("updateButtonsStatus")
  }

  function onEventUpdateGamercard(p)
  {
    doWhenActiveOnce("updateButtonsStatus")
  }

  function onEventXboxMultiplayerPrivilegeUpdated(p) {
    doWhenActiveOnce("updateButtonsStatus")
  }

  function onEventActiveHandlersChanged(p)
  {
    if (!isSceneActiveNoModals())
      unstickLastDropDown()
  }
}
