let string = require("%sqstd/string.nut")
let u = require("%sqStdLibs/helpers/u.nut")

local intIconToString = @(id) ""
local getIconPath = @(icon) icon
local getConfig = @() null

let BhvAvatar = class
{
  eventMask    = ::EV_ON_CMD
  valuePID     = ::dagui_propid.add_name_id("value")
  isFullPID    = ::dagui_propid.add_name_id("isFull")

  function onAttach(obj)
  {
    setIsFull(obj, obj?.isFull == "yes")
    if (obj?.value)
      setStringValue(obj, validateStrValue(obj.value))
    updateView(obj)
    return ::RETCODE_NOTHING
  }

  function validateStrValue(strValue)
  {
    if (strValue in getConfig())
      return strValue
    if (string.isStringInteger(strValue))
      return intIconToString(strValue.tointeger())
    return strValue
  }

  function isFull(obj) { return !!obj.getIntProp(isFullPID, 0) }
  function setIsFull(obj, newIsFull)
  {
    if (newIsFull == isFull(obj))
      return false
    obj.setIntProp(isFullPID, newIsFull ? 1 : 0)
    return true
  }

  function setStringValue(obj, strValue)
  {
    if (obj?.value == strValue)
      return false
    obj.value = strValue
    return true
  }

  function setValue(obj, newValue)
  {
    local shouldUpdate = false
    if (u.isBool(newValue))
      shouldUpdate = setIsFull(obj, newValue)
    else if (u.isInteger(newValue))
      shouldUpdate = setStringValue(obj, intIconToString(newValue))
    else if (u.isString(newValue))
      shouldUpdate = setStringValue(obj, newValue)

    if (shouldUpdate)
      updateView(obj)
  }

  function updateView(obj)
  {
    let image = obj?.value ?? ""
    let hasImage = image != ""
    obj.set_prop_latent("background-image", hasImage ? getIconPath(image) : "")
    obj.set_prop_latent("background-color", hasImage ? "#FFFFFFFF" : "#00000000")
    if (!hasImage)
      return

    if (isFull(obj))
    {
      obj.set_prop_latent("background-repeat",  "stretch")
      obj.set_prop_latent("background-position", "0")
      obj.updateRendElem()
      return
    }

    let imgBlk = getConfig()?[image]
    let size = ::clamp(imgBlk?.size || 1.0, 0.01, 1.0)
    let x = imgBlk?.pos?.x ?? 0.0
    let y = imgBlk?.pos?.y ?? 0.0
    obj.set_prop_latent("background-repeat",  "part")
    obj.set_prop_latent("background-position",
      ::format("%d,%d,%d,%d",
        (1000 * x).tointeger(), (1000 * y).tointeger(),
        (1000 * (1.0 - x - size)).tointeger(), (1000 * (1.0 - y - size)).tointeger()
    ))
    obj.updateRendElem()
  }
}

::replace_script_gui_behaviour("bhvAvatar", BhvAvatar)

return {
  init = function(params)
  {
    intIconToString   = params?.intIconToString   ?? intIconToString
    getIconPath       = params?.getIconPath       ?? getIconPath
    getConfig         = params?.getConfig         ?? getConfig
  }

  getCurParams = @() {
    intIconToString   = intIconToString
    getIconPath       = getIconPath
    getConfig         = getConfig
  }

  forceUpdateView = @(obj) BhvAvatar.updateView.call(BhvAvatar, obj)
}