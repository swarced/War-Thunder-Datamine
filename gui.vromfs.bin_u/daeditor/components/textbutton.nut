from "%darg/ui_imports.nut" import *
let {deep_merge} = require("%sqstd/underscore.nut")

let style = {
  text = {
    normal = {
      color = Color(200,200,200)
      transform = {}
    }
    hover = {
      color = Color(0,0,0)
    }
    active = {
      color = Color(0,0,0)
    }
  }
  box = {
    normal = {
      margin = [hdpx(1),hdpx(10)]
      borderColor = Color(200,200,200)
      borderRadius = hdpx(4)
      fillColor = Color(10,10,10)
      padding = [hdpx(4), hdpx(10)]
      transform = {}
    }
    active = {
      fillColor = Color(200,200,200)
      pos = [0, hdpx(1)]
    }
    hover = {
      fillColor = Color(255,255,255)
      borderColor = Color(155,155,255)
    }
  }
}

let function textButton(text, handler, params = {}){
  let stateFlags = Watched(0)
  let disabled = params?.disabled
  let textStyle = deep_merge(style.text, params?.textStyle ?? {})
  let boxStyle = deep_merge(style.box, params?.boxStyle ?? {})
  let textNormal = textStyle.normal
  let boxNormal = boxStyle.normal
  return function(){
    let s = stateFlags.value
    local state = "normal"
    if (disabled?.value)
      state = "disabled"
    else if (s & S_ACTIVE)
      state = "active"
    else if (s & S_HOVER)
      state = "hover"

    let textS = textStyle?[state] ?? {}
    let boxS = boxStyle?[state] ?? {}
    return {
      rendObj = ROBJ_BOX
    }.__update(boxNormal, boxS, {
      watch = [stateFlags, disabled]
      onElemState = @(sf) stateFlags(sf)
      behavior = Behaviors.Button
      hotkeys = params?.hotkeys
      onClick = handler
      children = {rendObj = ROBJ_DTEXT text}.__update(textNormal, textS)
    })
  }

}

return textButton
