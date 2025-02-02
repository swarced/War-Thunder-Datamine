let {IlsColor, IlsLineScale} = require("%rGui/planeState/planeToolsState.nut")
let {CompassValue} = require("%rGui/planeState/planeFlyState.nut")
let {baseLineWidth} = require("ilsConstants.nut")

let generateCompassMark = function(num, elemWidth) {
  return {
    size = [pw(20), ph(100)]
    flow = FLOW_VERTICAL
    children = [
      @() {
        watch = IlsColor
        rendObj = ROBJ_DTEXT
        color = IlsColor.value
        hplace = ALIGN_CENTER
        fontSize = 60
        font = Fonts.usa_ils
        text = num % 10 == 0 ? (num / 10).tostring() : ""
      }
      @() {
        watch = IlsColor
        size = [baseLineWidth * IlsLineScale.value, baseLineWidth * IlsLineScale.value]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        hplace = ALIGN_CENTER
      }
    ]
  }
}

let generateCompassMarkSUM = function(num, elemWidth) {
  return {
    size = [pw(20), ph(100)]
    flow = FLOW_VERTICAL
    children = [
      @() {
        watch = IlsColor
        rendObj = ROBJ_DTEXT
        color = IlsColor.value
        hplace = ALIGN_CENTER
        fontSize = 60
        font = Fonts.hud
        text = num % 10 == 0 ? (num / 10).tostring() : ""
      }
      @() {
        watch = IlsColor
        size = [baseLineWidth * 2 * IlsLineScale.value, baseLineWidth * 2 * IlsLineScale.value]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        hplace = ALIGN_CENTER
      }
    ]
  }
}

let generateCompassMarkASP = function(num, elemWidth) {
  return {
    size = [pw(20), ph(100)]
    flow = FLOW_VERTICAL
    children = [
      @() {
        watch = IlsColor
        rendObj = ROBJ_DTEXT
        color = IlsColor.value
        hplace = ALIGN_CENTER
        fontSize = 40
        font = Fonts.ussr_ils
        text = num % 10 == 0 ? (num / 10).tostring() : ""
      }
      @() {
        watch = IlsColor
        size = [baseLineWidth * 0.8 * IlsLineScale.value, baseLineWidth * 6]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        hplace = ALIGN_CENTER
      }
    ]
  }
}

let generateCompassMarkEP = function(num, elemWidth) {
  return {
    size = [pw(20), ph(100)]
    flow = FLOW_VERTICAL
    children = [
      @() {
        watch = IlsColor
        rendObj = ROBJ_DTEXT
        color = IlsColor.value
        hplace = ALIGN_CENTER
        fontSize = 40
        font = Fonts.hud
        text = num % 10 == 0 ? (num / 10).tostring() : ""
      }
      @() {
        watch = IlsColor
        size = [baseLineWidth * IlsLineScale.value, baseLineWidth * (num % 10 == 0 ? 2 : 3)]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        hplace = ALIGN_CENTER
      }
    ]
  }
}

let generateCompassMarkEP08 = function(num, elemWidth) {
  return {
    size = [pw(20), ph(100)]
    flow = FLOW_VERTICAL
    children = [
      (num % 10 == 0 ? @() {
        watch = IlsColor
        rendObj = ROBJ_DTEXT
        color = IlsColor.value
        hplace = ALIGN_CENTER
        fontSize = 50
        font = Fonts.hud
        text = num % 10 == 0 ? (num / 10).tostring() : ""
      } : null),
      (num % 10 != 0 ? @() {
        watch = IlsColor
        size = [baseLineWidth * IlsLineScale.value, baseLineWidth * 5]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        hplace = ALIGN_CENTER
      } : null)
    ]
  }
}

let generateCompassMarkShim = function(num, elemWidth) {
  return {
    size = [elemWidth < 0 ? pw(8) : pw(elemWidth), ph(100)]
    flow = FLOW_VERTICAL
    children = [
      @() {
        watch = IlsColor
        rendObj = ROBJ_DTEXT
        color = IlsColor.value
        hplace = ALIGN_CENTER
        fontSize = 40
        font = Fonts.hud
        text = num % 10 == 0 ? (num / 10).tostring() : ""
      },
      @() {
        watch = IlsColor
        size = [baseLineWidth * IlsLineScale.value, baseLineWidth * 5]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        hplace = ALIGN_CENTER
      }
    ]
  }
}

let generateCompassTCSFMark = function(num, elemWidth) {
  return {
    size = [pw(8), ph(280)]
    children = [
      @() {
        watch = IlsColor
        pos = [pw(-50), ph(80)]
        rendObj = ROBJ_DTEXT
        color = IlsColor.value
        hplace = ALIGN_CENTER
        fontSize = 50
        font = Fonts.hud
        text = num % 10 == 0 ? string.format("%02d", num / 10) : ""
      },
      @() {
        watch = IlsColor
        pos = [pw(-50), ph(num % 10 == 0 ? 90 : 92)]
        size = [baseLineWidth * IlsLineScale.value, baseLineWidth * (num % 10 == 0 ? 5 : 3)]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        hplace = ALIGN_CENTER
      }
    ]
    transform = {
      rotate = num
      pivot = [0.0, 0.0]
    }
  }
}


let generateCompassMarkJ8 = function(num, elemWidth) {
  return {
    size = [pw(20), ph(100)]
    children = [
      @() {
        watch = IlsColor
        rendObj = ROBJ_DTEXT
        color = IlsColor.value
        hplace = ALIGN_CENTER
        fontSize = 40
        font = Fonts.hud
        text = num % 10 == 0 ? (num / 10).tostring() : ""
      }
      @() {
        watch = IlsColor
        pos = [0, (num % 10 == 0 ? ph(20) : ph(26))]
        size = [baseLineWidth * 0.8 * IlsLineScale.value, baseLineWidth * (num % 10 == 0 ? 6 : 4)]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        hplace = ALIGN_CENTER
      }
    ]
  }
}

let function compass(width, generateFunc, step, is_circle = false, elemWidth = -1) {
  let children = []

  for (local i = 0; i <= (is_circle ? 1.0 : 2.0) * 360.0 / step; ++i) {

    let num = (i * step) % 360

    children.append(generateFunc(num, elemWidth))
  }

  let getOffset = @() (360 + CompassValue.value) * 0.2 * width / 5
  return is_circle ?
  {
    size = [pw(100), ph(100)]
    pos = [pw(50), ph(-170)]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        rotate = -CompassValue.value
        pivot = [0.0, 0]
      }
    }
    children = children
  } :
  {
    size = [pw(100), ph(100)]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [-getOffset() + 0.4 * width, 0]
      }
    }
    flow = FLOW_HORIZONTAL
    children = children
  }
}

let function compassWrap(width, height, pos, generateFunc, scale = 1.0, step = 5.0, is_circle = false, elemWidth = -1) {
  return {
    size = [width * 0.6 * scale, height * 0.2]
    pos = [width * (1 - 0.6 * scale) * 0.5, height * pos]
    clipChildren = true
    children = compass(width * 0.6 * scale, generateFunc, step, is_circle, elemWidth)
  }
}

return {
  compassWrap
  generateCompassMarkASP
  generateCompassMarkSUM
  generateCompassMark
  generateCompassMarkEP
  generateCompassMarkEP08
  generateCompassMarkShim
  generateCompassMarkJ8
  generateCompassTCSFMark
}
