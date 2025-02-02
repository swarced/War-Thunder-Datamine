// warning disable: -file:forbidden-function

let fonts = require("fonts")
let { reloadDargUiScript } = require("reactiveGuiCommand")

::debug_change_font_size <- function debug_change_font_size(shouldIncrease = true)
{
  let availableFonts = ::g_font.getAvailableFonts()
  let curFont = ::g_font.getCurrent()
  local idx = availableFonts.findindex(@(v) v == curFont) ?? 0
  idx = ::clamp(idx + (shouldIncrease ? 1 : -1), 0, availableFonts.len() - 1)
  if (::g_font.setCurrent(availableFonts[idx])) {
    ::handlersManager.getActiveBaseHandler().fullReloadScene()
    reloadDargUiScript(false)
  }
  dlog("Loaded fonts: " + availableFonts[idx].id)
}

local fontsAdditionalText = ""
::debug_fonts_list <- function debug_fonts_list(isActiveColor = true, needBorder = true)
{
  let getColor = @() isActiveColor ? "activeTextColor" : "commonTextColor"

  let view = {
    color = "@" + getColor()
    isActiveColor = isActiveColor
    needBorder = needBorder
    fontsAdditionalText = fontsAdditionalText

    textsList = ::u.map(fonts.getFontsList(),
      @(name) {
        id = name
        font = name
        text = name + fontsAdditionalText
      })
  }

  local handler = {
    scene = null
    guiScene = null

    function onCreate(obj)
    {
      scene = obj
      guiScene = obj.getScene()
    }

    function updateAllObjs(func)
    {
      guiScene.setUpdatesEnabled(false, false)
      foreach(id in fonts.getFontsList())
      {
        let obj = scene.findObject(id)
        if (::check_obj(obj))
          func(obj)
      }
      guiScene.setUpdatesEnabled(true, true)
    }

    function onColorChange(obj)
    {
      isActiveColor = obj.getValue()
      let color = guiScene.getConstantValue(getColor())
      updateAllObjs(function(obj) { obj.color = color })
    }

    function onBorderChange(obj)
    {
      needBorder = obj.getValue()
      let borderText = needBorder ? "yes" : "no"
      updateAllObjs(function(obj) { obj.border = borderText })
    }

    function onTextChange(obj)
    {
      let text = obj.getValue()
      fontsAdditionalText = text.len() ? "\n" + text : ""
      updateAllObjs(function(obj) { obj.setValue(obj.id + fontsAdditionalText) })
    }
  }

  debug_wnd("%gui/debugTools/fontsList.tpl", view, handler)
}