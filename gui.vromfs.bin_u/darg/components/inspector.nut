from "%darg/ui_imports.nut" import *

//let {locate_element_source, sh, ph} = require("daRg")
let {format} = require("string")
let utf8 = require_optional("utf8")
let {set_clipboard_text} = require("daRg.clipboard")
let fieldsMap = require("inspectorViews.nut")
let cursors = require("simpleCursors.nut")

let shown          = persist("shown", @() Watched(false))
let wndHalign      = persist("wndHalign", @() Watched(ALIGN_RIGHT))
let pickerActive   = persist("pickerActive", @() Watched(false))
let highlight      = persist("highlight", @() Watched(null))
let animHighlight  = Watched(null)
let pickedList     = persist("pickedList", @() Watched([], FRP_DONT_CHECK_NESTED))
let viewIdx        = persist("viewIdx", @() Watched(0))

let curData        = Computed(@() pickedList.value?[viewIdx.value])

let fontSize = sh(1.5)
let valColor = Color(155,255,50)

let function textButton(text, action, isEnabled = true) {
  let stateFlags = Watched(0)

  let override = isEnabled
    ? {
        watch = stateFlags
        onElemState = isEnabled ? @(val) stateFlags.update(val) : null
        onClick = isEnabled ? action : null
      }
    : {}

  return function() {
    let sf = stateFlags.value
    let color = !isEnabled ? Color(80, 80, 80, 200)
      : (sf & S_ACTIVE)   ? Color(100, 120, 200, 255)
      : (sf & S_HOVER)    ? Color(110, 135, 220, 255)
      : (sf & S_KB_FOCUS) ? Color(110, 135, 220, 255)
                          : Color(100, 120, 160, 255)
    return {
      rendObj = ROBJ_SOLID
      size = SIZE_TO_CONTENT
      behavior = Behaviors.Button
      focusOnClick = true
      color = color
      padding = [hdpx(5), hdpx(10)]
      children = {
        rendObj = ROBJ_DTEXT
        text = text
        color = isEnabled ? 0xFFFFFFFF : 0xFFBBBBBB
      }
    }.__update(override)
  }
}

let function mkDirBtn(text, dir) {
  let isVisible = Computed(@() pickedList.value.len() > 1)
  let isEnabled = Computed(@() (viewIdx.value + dir) in pickedList.value)
  return @() {
    watch = [isVisible, isEnabled]
    children = !isVisible.value ? null
      : textButton(text, @() isEnabled.value ? viewIdx(viewIdx.value + dir) : null, isEnabled.value)
  }
}

let invAlign = @(align) align == ALIGN_LEFT ? ALIGN_RIGHT : ALIGN_LEFT
let function panelToolbar() {
  let pickBtn = textButton("Pick", @() pickerActive(true))
  let alignBtn = textButton(wndHalign.value == ALIGN_RIGHT ? "<|" : "|>", @() wndHalign(invAlign(wndHalign.value)))
  let prev = mkDirBtn("Prev", -1)
  let next = mkDirBtn("Next", 1)
  return {
    watch = wndHalign
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    padding = sh(1)
    gap = sh(0.5)
    halign = invAlign(wndHalign.value)
    children = wndHalign.value == ALIGN_RIGHT
      ? [alignBtn, pickBtn, prev, next]
      : [prev, next, pickBtn, alignBtn]
  }
}

let cutText = utf8 ? @(text, num) utf8(text).slice(0, num)
  : @(text, num) text.slice(0, num)

let mkColorCtor = @(color) @(content) {
  flow = FLOW_HORIZONTAL
  gap = sh(0.5)
  children = [
    content.__merge({ size = SIZE_TO_CONTENT })
    { rendObj = ROBJ_SOLID, size = [ph(100), ph(100)], color }
  ]
}

let mkImageCtor = @(image) @(content) {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  children = [
    content
    {
      rendObj = ROBJ_IMAGE
      maxHeight = sh(30)
      keepAspect = true
      imageValign = ALIGN_TOP
      imageHalign = ALIGN_LEFT
      image
    }
  ]
}

let IMAGE_KEYS = ["image", "fallbackImage"]

let function getPropValueTexts(desc, key, textLimit = 0) {
  let val = desc[key]
  let tp = type(val)

  local text = null
  local valCtor = fieldsMap?[key][val]

  if (val == null) {
    text = "<null>"
  } else if (tp == "array") {
    text = ", ".join(val)
  } else if (IMAGE_KEYS.contains(key)) {
    text = val.tostring()
    valCtor = mkImageCtor(val)
  } else if (tp == "integer" && key.tolower().indexof("color") != null) {
    text = "".concat("0x", format("%16X", val).slice(8))
    valCtor = mkColorCtor(val)
  } else if (tp == "userdata" || tp == "userpointer") {
    text = "<userdata/userpointer>"
  } else {
    let s = val.tostring()
    if (textLimit <= 0)
      text = s
    else {
      text = cutText(s, textLimit)
      if (text.len() + 10 < s.len())
        valCtor = $"...({utf8?(s).charCount() ?? s.len()})"
      else
        text = s
    }
  }
  return { text, valCtor }
}

let textColor = @(sf) sf & S_ACTIVE ? 0xFFFFFF00
  : sf & S_HOVER ? 0xFF80A0FF
  : 0xFFFFFFFF

let function mkPropContent(desc, key, sf) {
  let { text, valCtor } = getPropValueTexts(desc, key, 200)
  local keyValue = $"{key.tostring()} = <color={valColor}>{text}</color>"
  if (typeof valCtor == "string")
    keyValue = $"{keyValue} {valCtor}"
  local content = {
    rendObj = ROBJ_TEXTAREA
    size = [flex(), SIZE_TO_CONTENT]
    behavior = Behaviors.TextArea
    color = textColor(sf)
    fontSize
    hangingIndent = sh(3)
    text = keyValue
  }
  if (typeof valCtor == "function")
    content = valCtor?(content)
  return content
}

let function propPanel(desc) {
  local pKeys = []
  if (typeof desc == "class")
    foreach (key, _ in desc)
      pKeys.append(key)
  else
    pKeys = desc.keys()
  pKeys.sort()

  return pKeys.map(function(k) {
    let stateFlags = Watched(0)
    return @() {
      watch = stateFlags
      size = [flex(), SIZE_TO_CONTENT]
      behavior = Behaviors.Button
      onElemState = @(sf) stateFlags(sf)
      onClick = @() set_clipboard_text(getPropValueTexts(desc, k).text)
      children = mkPropContent(desc, k, stateFlags.value)
    }
  })
}

let prepareCallstackText = @(text) //add /t for line wraps
  text.replace("/", "/\t")

let function details() {
  let res = {
    watch = curData
    size = flex()
  }
  let sel = curData.value
  if (sel == null)
    return res

  let summarySF = Watched(0)
  let summaryText = @() {
    watch = summarySF
    size = flex()
    rendObj = ROBJ_TEXTAREA
    behavior = [Behaviors.TextArea, Behaviors.WheelScroll, Behaviors.Button]
    onElemState = @(sf) summarySF(sf)
    onClick = @() set_clipboard_text(sel.locationText)
    text = prepareCallstackText(sel.locationText)
    fontSize
    color = textColor(summarySF.value)
    hangingIndent = sh(3)
  }

  let bb = sel.boundingBox
  let bbText = $"\{ pos = [{bb.x}, {bb.y}], size = [{bb.width}, {bb.height}] \}"
  let bboxSF = Watched(0)
  let bbox = @() {
    watch = bboxSF
    rendObj = ROBJ_TEXTAREA
    behavior = [Behaviors.TextArea, Behaviors.Button]
    function onElemState(sf) {
      bboxSF(sf)
      animHighlight(sf & S_HOVER ? bb : null)
    }
    onDetach = @() animHighlight(null)
    onClick = @() set_clipboard_text(bbText)
    fontSize
    color = textColor(bboxSF.value)
    text = $"bbox = <color={valColor}>{bbText}</color>"
  }

  return res.__update({
    flow = FLOW_VERTICAL
    padding = [hdpx(5), hdpx(10)]
    children = [ bbox ].extend(propPanel(sel.componentDesc)).append(summaryText)
  })
}

let help = {
  rendObj = ROBJ_TEXTAREA
  size = [flex(), SIZE_TO_CONTENT]
  behavior = Behaviors.TextArea
  vplace = ALIGN_BOTTOM
  margin = [hdpx(5), hdpx(10)]
  fontSize
  text = @"L.Ctrl + L.Shift + I - switch inspector off\nL.Ctrl + L.Shift + P - switch picker on/off"
}

let hr = {
  rendObj = ROBJ_SOLID
  color = 0x333333
  size = [flex(), hdpx(1)]
}

let inspectorPanel = @() {
  watch = wndHalign
  rendObj = ROBJ_SOLID
  color = Color(0, 0, 50, 50)
  size = [sw(30), sh(100)]
  hplace = wndHalign.value
  behavior = Behaviors.Button
  clipChildren = true

  flow = FLOW_VERTICAL
  gap = hr
  children = [
    panelToolbar
    details
    help
  ]
}


let function highlightRect() {
  let res = { watch = highlight }
  let hv = highlight.value
  if (hv == null)
    return res
  return res.__update({
    rendObj = ROBJ_SOLID
    color = Color(50, 50, 0, 50)
    pos = [hv[0].x, hv[0].y]
    size = [hv[0].w, hv[0].h]

    children = {
      rendObj = ROBJ_FRAME
      color = Color(200, 0, 0, 180)
      size = [hv[0].w, hv[0].h]
    }
  })
}

let function animHighlightRect() {
  let res = {
    watch = animHighlight
    animations = [{
      prop = AnimProp.opacity, from = 0.5, to = 1.0, duration = 0.5, easing = CosineFull, play = true, loop = true
    }]
  }
  let ah = animHighlight.value
  if (ah == null)
    return res
  return res.__update({
    size = [ah.width, ah.height]
    pos = [ah.x, ah.y]
    rendObj = ROBJ_FRAME
    color = 0xFFFFFFFF
    fillColor = 0x40404040
  })
}

let function elemLocationText(elem, builder) {
  local text = "Source: unknown"

  let location = locate_element_source(elem)
  if (location)
    text = $"{location.stack}\n-------\n"
  return builder ? $"{text}\n(Function)" : $"{text}\n(Table)"
}


let elementPicker = @() {
  size = [sw(100), sh(100)]
  behavior = Behaviors.InspectPicker
  cursor = cursors.normal
  rendObj = ROBJ_SOLID
  color = Color(20,0,0,20)
  onClick = function(data) {
    pickedList((data ?? [])
      .map(@(d) {
        boundingBox = d.boundingBox
        componentDesc = d.componentDesc
        locationText = elemLocationText(d.elem, d.builder)
      }))
    viewIdx(0)
    pickerActive(false)
  }
  onChange = @(hl) highlight(hl)
  children = highlightRect
}


let function inspectorRoot() {
  let res = {
    watch = [pickerActive, shown]
    size = [sw(100), sh(100)]
    zOrder = getroottable()?.Layers.Inspector ?? 10
    skipInspection = true
  }

  if (shown.value)
    res.__update({
      cursor = cursors.normal
      children = [
        (pickerActive.value ? elementPicker : inspectorPanel),
        animHighlightRect,
        { hotkeys = [
          ["L.Ctrl L.Shift I", @() shown(false)],
          ["L.Ctrl L.Shift P", @() pickerActive(!pickerActive.value)]
        ] }
      ]
    })

  return res
}

let function inspectorToggle() {
  shown(!shown.value)
  pickerActive(false)
  pickedList([])
  viewIdx(0)
  highlight(null)
}

return {
  inspectorToggle
  inspectorRoot
}
