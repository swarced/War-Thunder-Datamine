let bhvAvatar = require("%scripts/user/bhvAvatar.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let stdPath = require("%sqstd/path.nut")
let avatars = require("%scripts/user/avatars.nut")
let dagor_fs = require("dagor.fs")
let stdMath = require("%sqstd/math.nut")

enum avatarPlace { //higher index has more priority to show icon when same icons in the different places
  IN_GAME         = 0x01
  IN_PKG_DEV      = 0x02
  IN_MAIN_FOLDER  = 0x04
}

::debug_avatars <- function debug_avatars(filePath = "../develop/gameBase/config/avatars.blk")
{
  let blk = ::DataBlock()
  if (!blk.tryLoad(filePath))
    return "Failed to load avatars config from " + filePath

  ::handlersManager.loadHandler(::gui_handlers.DbgAvatars, { savePath = filePath, configBlk = blk })
  return "Done"
}

::gui_handlers.DbgAvatars <- class extends ::BaseGuiHandler
{
  wndType      = handlerType.MODAL
  sceneTplName = "%gui/debugTools/dbgAvatars"

  savePath = ""
  configBlk = null
  configBlkOriginal = null

  fullIconsList = null
  iconsMap = null
  mainAvatarConfig = null

  selectedAvatar = "cardicon_default"

  isInEditMode = false
  editStartPos = null
  lastMainBorderSize = null
  lastMainBorderPos = null
  shouldUpdateBorder = true

  sliders = [
    {
      id = "size"
      getValue = @() getSelAvatarBlk().size
      setValue = @(v) getSelAvatarBlk().size = v
    }
    {
      id = "posX"
      getValue = @() getSelAvatarBlk().pos.x
      setValue = @(v) getSelAvatarBlk().pos.x = v
    }
    {
      id = "posY"
      getValue = @() getSelAvatarBlk().pos.y
      setValue = @(v) getSelAvatarBlk().pos.y = v
    }
  ]

  function getSceneTplView()
  {
    mainAvatarConfig = bhvAvatar.getCurParams()
    bhvAvatar.init({
      getConfig = (@() configBlk).bindenv(this)
      intIconToString = getIconByIdx.bindenv(this)
      getIconPath = getIconPath.bindenv(this)
    })

    initAvatarsList()

    return {
      savePath = savePath
      avatars = fullIconsList.map(@(icon)
        { name = icon.name
          isPkgDev = icon.place & avatarPlace.IN_PKG_DEV
          isOnlyInGame = icon.place == avatarPlace.IN_GAME
          isOnlyInResources = !(icon.place & avatarPlace.IN_GAME)
        })
      sliders = sliders
    }
  }

  function initAvatarsList()
  {
    fullIconsList = []
    iconsMap = {}

    let mainList = ["cardicon_default", "cardicon_bot"]
    mainList.extend(avatars.getIcons())
    foreach(name in mainList)
      addAvatarConfig(name, avatarPlace.IN_GAME, mainAvatarConfig.getIconPath(name))

    let fileMask = "*.png"
    let guiPath = "../develop/gui/"
    let dirs = {
      ["menu/images/images/avatars"] = avatarPlace.IN_MAIN_FOLDER,
      ["menu/pkg_dev/images/images/avatars"] = avatarPlace.IN_PKG_DEV,
    }
    foreach(dirPath, place in dirs)
    {
      let filePaths = dagor_fs.scan_folder({root=guiPath + dirPath, vromfs = false, realfs = true, recursive = true, files_suffix=fileMask})
      foreach(path in filePaths)
        addAvatarConfig(stdPath.fileName(path).slice(0, -4), place, path)
    }
  }

  function addAvatarConfig(name, place, path)
  {
    local icon = iconsMap?[name]
    if (icon)
    {
      if (icon.place < place)
        icon.path = path
      icon.place = icon.place | place
      return
    }

    icon = {
      name = name
      place = place
      path = path
    }
    fullIconsList.append(icon)
    iconsMap[name] <- icon
  }

  function initScreen()
  {
    configBlkOriginal = ::DataBlock()
    configBlkOriginal.setFrom(configBlk)
    scene.findObject("edit_update").setUserData(this)
    setAvatar("cardicon_default")
  }

  getIconByIdx = @(idx) fullIconsList?[idx]?.name ?? ""
  getIconPath = @(name) iconsMap?[name]?.path ?? ""

  function save()
  {
    configBlk.saveToTextFile(savePath)
  }

  function saveAndExit()
  {
    save()
    base.goBack()
  }

  function goBack()
  {
    if (u.isEqual(configBlk, configBlkOriginal))
      return base.goBack()

    msgBox("save", "should save changes?",
    [
      ["yes", saveAndExit ],
      ["no", base.goBack ]
    ],
    "yes", { cancel_fn = function() {} })
  }

  function onDestroy()
  {
    bhvAvatar.init(mainAvatarConfig)
  }

  function onAvatarSelect(obj)
  {
    setAvatar(fullIconsList?[obj.getValue()]?.name)
  }

  function setAvatar(avatar)
  {
    if (!avatar)
      return

    isInEditMode = false
    selectedAvatar = avatar
    foreach(name in ["sel_name", "sel_big_icon", "sel_small_icon"])
      scene.findObject(name).setValue(selectedAvatar)
    updateEditControls()
  }

  function onSelAvatarSizeChange()
  {
    bhvAvatar.forceUpdateView(scene.findObject("sel_small_icon"))
    let listObj = scene.findObject("avatars_list")
    foreach(idx, avatar in fullIconsList)
      if (avatar.name == selectedAvatar)
        bhvAvatar.forceUpdateView(listObj.getChild(idx).findObject("small_icon"))
    updateEditControls()
  }

  function updateEditControls()
  {
    let avatarBlk = getSelAvatarBlk()
    foreach(s in sliders)
    {
      let value = s.getValue.call(this)
      scene.findObject(s.id + "_text").setValue(value.tostring())
    }

    if (shouldUpdateBorder)
    {
      let editBorder = showSceneBtn("edit_border", isInEditMode)
      let mainBorder = showSceneBtn("main_border", !isInEditMode && avatarBlk.size < 1)
      let curBorder = isInEditMode ? editBorder : mainBorder
      curBorder.pos = format("%.2fpw, %.2fph", avatarBlk.pos.x, avatarBlk.pos.y)
      curBorder.size = format("%.2fpw,%.2fph", avatarBlk.size, avatarBlk.size)
    }
  }

  function getSelAvatarBlk()
  {
    if (!(selectedAvatar in configBlk))
    {
      let blk = ::DataBlock()
      blk.pos = ::Point2(0, 0)
      blk.size = 1.0
      configBlk[selectedAvatar] <- blk
    }
    return configBlk[selectedAvatar]
  }

  roundVal = @(val) stdMath.round_by_value(::clamp(val, 0.0, 1.0), 0.01)

  function getMousePosPart()
  {
    let obj = scene.findObject("sel_big_icon")
    let coords = ::get_dagui_mouse_cursor_pos()
    let objPos = obj.getPosRC()
    let objSize = obj.getSize()
    return ::Point2(roundVal((coords[0] - objPos[0]).tofloat() / (objSize[0] || 1)),
                    roundVal((coords[1] - objPos[1]).tofloat() / (objSize[1] || 1)))
  }

  function validateCorners(pos1, pos2)
  {
    foreach(key in ["x", "y"])
      if (pos1[key] > pos2[key])
      {
        let t = pos1[key]
        pos1[key] = pos2[key]
        pos2[key] = t
      }
  }

  function onEditStart(obj)
  {
    let avatarBlk = getSelAvatarBlk()
    editStartPos = getMousePosPart()
    avatarBlk.pos = editStartPos
    avatarBlk.size = 0.0
    onSelAvatarSizeChange()
    isInEditMode = true
  }

  function updateEditSize()
  {
    let avatarBlk = getSelAvatarBlk()
    let pos1 = ::Point2(editStartPos.x, editStartPos.y)
    let pos2 = getMousePosPart()
    validateCorners(pos1, pos2)
    avatarBlk.pos = pos1
    avatarBlk.size = ::max(pos2.x - pos1.x, pos2.y - pos1.y)
  }

  function onEditUpdate(obj = null, dt = 0.0)
  {
    if (isInEditMode)
    {
      updateEditSize()
      onSelAvatarSizeChange()
    } else
      checkMainFrameMovement()
  }

  function onEditDone(obj)
  {
    if (!isInEditMode)
      return
    updateEditSize()
    isInEditMode = false
    onSelAvatarSizeChange()
  }

  function checkMainFrameMovement()
  {
    let mainBorder = scene.findObject("main_border")
    if (!mainBorder.isVisible())
      return

    let size = mainBorder.getSize()
    let pos = mainBorder.getPosRC()
    if (size[0] <= 0 || size[1] <= 0)
      return

    local hasChanges =false
    if (!u.isEqual(size, lastMainBorderSize)
      || !u.isEqual(pos, lastMainBorderPos))
    {
      let avatarBlk = getSelAvatarBlk()
      let obj = scene.findObject("sel_big_icon")
      let objPos = obj.getPos()
      let objSize = obj.getSize()

      let realPos = ::Point2(roundVal((pos[0] - objPos[0]).tofloat() / objSize[0]),
                               roundVal((pos[1] - objPos[1]).tofloat() / objSize[1]))
      if ( fabs(avatarBlk.pos.x - realPos.x) > 0.001
        || fabs(avatarBlk.pos.y - realPos.y) > 0.001)
      {
        avatarBlk.pos = realPos
        hasChanges = true
      }

      let realSize = roundVal(::max(size[0], size[1]).tofloat() / objSize[0])
      if (fabs(avatarBlk.size - realSize) > 0.001)
      {
        avatarBlk.size = realSize
        hasChanges = true
      }
    }

    lastMainBorderSize = size
    lastMainBorderPos = pos
    if (hasChanges)
    {
      let avatarBlk = getSelAvatarBlk()
      let maxSize = ::min(1.0 - avatarBlk.pos.x, 1.0 - avatarBlk.pos.y)
      if (avatarBlk.size > maxSize)
        avatarBlk.size = roundVal(maxSize)
      shouldUpdateBorder = false
      onSelAvatarSizeChange()
      shouldUpdateBorder = true
    }
  }

  function onSave()
  {
    save()
    configBlkOriginal.setFrom(configBlk)
  }

  function onReset()
  {
    let avatarBlk = getSelAvatarBlk()
    avatarBlk.size = 1.0
    avatarBlk.pos = ::Point2()
    onSelAvatarSizeChange()
  }

  function onRestore()
  {
    let avatarBlk = getSelAvatarBlk()
    let prevAvatarBlk = configBlkOriginal?[selectedAvatar]
    if (!prevAvatarBlk)
    {
      onReset()
      return
    }

    avatarBlk.setFrom(prevAvatarBlk)
    onSelAvatarSizeChange()
  }
}