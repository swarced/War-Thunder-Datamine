local scrollbar = require("reactiveGui/components/scrollbar.nut")
local {formatText} = require("reactiveGui/components/formatText.nut")
local {curPatchnote, curPatchnoteIdx, choosePatchnote, nextPatchNote, prevPatchNote,
  versions, curVersionInfo } = require("changelogState.nut")
local colors = require("reactiveGui/style/colors.nut")
local { commonTextButton } = require("reactiveGui/components/textButton.nut")
local modalWindow = require("reactiveGui/components/modalWindow.nut")
local fontsState = require("reactiveGui/style/fontsState.nut")
local JB = require("reactiveGui/control/gui_buttons.nut")
local { mkImageCompByDargKey } = require("reactiveGui/components/gamepadImgByKey.nut")
local { showConsoleButtons } = require("reactiveGui/ctrlsState.nut")

local tabStyle = {
  fillColor = {
    normal   = colors.transparent
    hover    = colors.menu.menuButtonColorHover
    active   = colors.menu.frameBackgroundColor
    current  = colors.menu.higlightFrameBgColor
  }
  textColor = {
    normal   = colors.menu.commonTextColor
    hover    = colors.menu.menuButtonTextColorHover
    active   = colors.menu.activeTextColor
    current  = colors.menu.activeTextColor
  }
}

local blockInterval = ::fpx(6)
local borderWidth = ::dp(1)
local minTabCount = 5

local function getTabColorCtor(sf, style, isCurrent) {
  if (isCurrent)        return style.current
  if (sf & S_ACTIVE)    return style.active
  if (sf & S_HOVER)     return style.hover
  return style.normal
}

local function patchnote(v) {
  local stateFlags = Watched(0)
  local isCurrent = @() curPatchnote.value.iVersion == v.iVersion
  return @() {
    watch = [stateFlags, curPatchnote]
    size = [flex(1), ::ph(100)]
    maxWidth = ::fpx(300)
    behavior = Behaviors.Button
    halign = ALIGN_CENTER
    rendObj = ROBJ_BOX
    fillColor = getTabColorCtor(stateFlags.value, tabStyle.fillColor, isCurrent())
    borderColor = colors.menu.frameBorderColor
    borderWidth = isCurrent()
      ? [0, borderWidth, borderWidth, borderWidth]
      : borderWidth
    onClick = @() choosePatchnote(v)
    onElemState = @(sf) stateFlags(sf)
    skipDirPadNav = false
    children = [{
        size = [flex(), ::ph(100)]
        maxWidth = ::fpx(300) - 2 * ::scrn_tgt(0.01)
        behavior = Behaviors.TextArea
        rendObj = ROBJ_TEXTAREA
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        color = getTabColorCtor(stateFlags.value, tabStyle.textColor, isCurrent())
        font = fontsState.get("small")
        text = v?.title ?? v.tVersion
      },
      stateFlags.value & S_HOVER ? { hotkeys = [["{0}".subst(JB.A), @() choosePatchnote(v)]] } : null
    ]
  }
}

local topBorder = @(params = {}) {
  size = [::dp(1), flex()]
  valign = ALIGN_CENTER
  rendObj = ROBJ_BOX
  fillColor = colors.transparent
  borderColor = colors.menu.frameBorderColor
  borderWidth = [borderWidth, 0 , 0 , 0]
}.__merge(params)

local patchnoteSelectorGamepadButton = @(hotkey, actionFunc) topBorder({
  size = [SIZE_TO_CONTENT, flex()]
  behavior = Behaviors.Button
  children = mkImageCompByDargKey(hotkey)
  onClick = actionFunc
  skipDirPadNav = true
})

local function getPatchoteSelectorChildren() {
  local tabCount = versions.value.len()
  local borderEmptySpace = topBorder({size = flex(::max(0, minTabCount - tabCount))})
  if (tabCount == 0)
    return borderEmptySpace

  local children = versions.value.map(patchnote)
  if (!showConsoleButtons.value)
    return children.append(borderEmptySpace)

  return [patchnoteSelectorGamepadButton("J:LB", nextPatchNote)]
    .extend(children)
    .append(patchnoteSelectorGamepadButton("J:RB", prevPatchNote))
    .append(borderEmptySpace)
}

local patchnoteSelector = @() {
  watch = versions
  size = [flex(), ::ph(100)]
  flow = FLOW_HORIZONTAL
  gap = topBorder()
  children = getPatchoteSelectorChildren()
}

local missedPatchnoteText = formatText([::loc("NoUpdateInfo", "Oops... No information yet :(")])

local seeMoreUrl = {
  t="url"
  platform="pc,ps4"
  url=::loc("url/news")
  v=::loc("visitGameSite", "See game website for more details")
  margin = [::fpx(50), 0, 0, 0]
}

local function selPatchnote(){
  local text = curVersionInfo.value ?? missedPatchnoteText
  if (::cross_call.hasFeature("AllowExternalLink")) {
    if (::type(text)!="array")
      text = [text, seeMoreUrl]
    else
      text = (clone text).append(seeMoreUrl)
  }
  return {
    watch = [curVersionInfo]
    size = flex()
    children = scrollbar.makeSideScroll({
      size = [flex(), SIZE_TO_CONTENT]
      children = formatText(text)
    })
  }
}

local function onCloseAction() {
  choosePatchnote(null)
  ::cross_call.startMainmenu()
}

local btnNext  = commonTextButton(::loc("mainmenu/btnNextItem"), nextPatchNote, {hotkeys=[["{0} | Esc".subst(JB.B)]], margin=0})
local btnClose = commonTextButton(::loc("mainmenu/btnClose"), onCloseAction, {hotkeys=[["{0} | Esc".subst(JB.B)]], margin=0})

local nextButton = @() {
  watch = [curPatchnoteIdx]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_BOX
  fillColor = colors.transparent
  borderColor = colors.menu.frameBorderColor
  borderWidth = [borderWidth, 0 , 0 , 0]
  hplace = ALIGN_RIGHT
  vplace = ALIGN_BOTTOM
  padding = [blockInterval, 0, 0, blockInterval]
  children = curPatchnoteIdx.value != 0 ? btnNext : btnClose
}

local clicksHandler = {
  size = flex(),
  eventPassThrough = true,
  skipDirPadNav = true
  behavior = Behaviors.Button
  hotkeys = [
    ["J:LB | Left", nextPatchNote],
    ["J:RB | Right", prevPatchNote]
  ]
}

local changelogRoot = {
  size = flex()
  children = [
    clicksHandler
    modalWindow({
      content = {
        size = flex()
        margin = blockInterval
        flow = FLOW_VERTICAL
        children = [
          {
            rendObj = ROBJ_BOX
            size = flex()
            fillColor = colors.menu.higlightFrameBgColor
            borderColor = colors.menu.frameBorderColor
            borderWidth = [borderWidth, borderWidth, 0, borderWidth]
            padding = blockInterval
            flow = FLOW_VERTICAL
            children = selPatchnote
          }
          {
            size = [flex(), SIZE_TO_CONTENT]
            flow = FLOW_HORIZONTAL
            valign = ALIGN_CENTER
            children = [
              patchnoteSelector
              nextButton
            ]
          }
        ]
      },
      headerParams = {
        closeBtn = { onClick = onCloseAction }
      }
    })
  ]
}

return changelogRoot
